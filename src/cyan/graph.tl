
---@brief
--- A utility for building directed acyclic graphs of Teal source files
---
--- This is the main driver behind the `build` command

local common <const> = require("cyan.tlcommon")
local fs <const> = require("cyan.fs")
local util <const> = require("cyan.util")

local values <const>, ivalues <const>, keys <const>, from <const>
   = util.tab.values, util.tab.ivalues, util.tab.keys, util.tab.from

---@desc
--- The nodes that are stored in the graph
local record Node
   input: fs.Path
   output: fs.Path
   modules: {string:fs.Path} -- require argument -> path found
   enum Mark
      "typecheck"
      "compile"
   end
   mark: Mark
   dependents: {Node:boolean}
end

local function make_node(input: fs.Path): Node
   return {
      input = input,
      modules = {},
      dependents = {},
   }
end

---@desc
--- The graph object
local record Dag
   _nodes_by_filename: {string:Node}
end

local function mark_for_typecheck(n: Node)
   if n.mark then return end
   n.mark = "typecheck"
   for child in keys(n.dependents) do
      mark_for_typecheck(child)
   end
end

local function mark_for_compile(n: Node)
   if n.mark == "compile" then return end
   n.mark = "compile"
   for child in keys(n.dependents) do
      mark_for_typecheck(child)
   end
end

local function make_dependent_counter(): function(Node): integer
   local cache <const>: {Node:integer} = {}
   local function count_dependents(n: Node): integer
      if cache[n] then return cache[n] end
      local deps = 0
      for v in keys(n.dependents) do
         deps = deps + count_dependents(v) + 1
      end
      cache[n] = deps
      return deps
   end
   return count_dependents
end

---@desc
--- Iterate over nodes in order of dependents
---
--- If two nodes have the same number of dependent nodes, the order of
--- iteration between those two nodes is not guaranteed
function Dag:nodes(): function(): Node
   local count <const> = make_dependent_counter()
   local most_deps = 0
   local nodes_by_deps <const>: {integer:{Node}} = setmetatable({}, {
      __index = function(self: {integer:{Node}}, key: integer): {Node}
         if key > most_deps then
            most_deps = key
         end
         local arr <const> = {}
         rawset(self, key, arr)
         return arr
      end,
   })
   for n in values(self._nodes_by_filename) do
      table.insert(nodes_by_deps[count(n)], n)
   end

   setmetatable(nodes_by_deps, nil)

   local i = most_deps
   if not nodes_by_deps[i] then
      return function(): nil end
   end
   local iter = values(nodes_by_deps[i])
   return function(): Node
      local n: Node
      while i >= 0 do
         n = iter()
         if n then
            return n
         end
         repeat i = i - 1
         until i < 0 or nodes_by_deps[i] as boolean
         if nodes_by_deps[i] then
            iter = values(nodes_by_deps[i])
         end
      end
   end
end

---@desc
--- For each node in the graph, if `predicate` returns true for that input
--- path, the node is marked for compilation, and that node's children are marked
--- for type checking
function Dag:mark_each(predicate: function(fs.Path): boolean)
   for n in self:nodes() do
      if predicate(n.input) then
         mark_for_compile(n)
      end
   end
end

---@desc
--- Iterate over every node with the given mark `m`. Iterates in order of most dependents to least
function Dag:marked_nodes(m: Node.Mark): function(): Node
   local iter = self:nodes()
   return function(): Node
      local n: Node
      repeat n = iter()
      until not n
         or n.mark == m
      return n
   end
end

local graph <const> = {
   Node = Node,
   Dag = Dag,
}

---@desc
--- Initializes an empty graph
function graph.empty(): Dag
   return setmetatable({
      _nodes_by_filename = {},
   }, { __index = Dag })
end

local function add_deps(t: {Node:boolean}, n: Node)
   for child in pairs(n.dependents) do
      if not t[child] then
         t[child] = true
         add_deps(t, child)
      end
   end
   t[n] = true
end

local function unchecked_insert(dag: Dag, f: fs.Path, in_dir: fs.Path)
   if f:is_absolute() then
      -- If a path is absolute, assume it is out of the project
      return
   end

   local real_path <const> = f:to_real_path()

   if dag._nodes_by_filename[real_path] then
      -- We already have this in the graph
      return
   end

   local res <const> = common.parse_file(real_path)
   if not res then return end
   local n <const>: Node = make_node(f)
   dag._nodes_by_filename[real_path] = n

   for mod_name in ivalues(res.reqs or {}) do
      -- We don't search for .d.tl files here because we don't want to generate
      -- anything for them
      local search_result = common.search_module(mod_name)
      if search_result then
         if in_dir and search_result:is_absolute() and search_result:is_in(in_dir) then
            search_result = search_result:relative_to(in_dir)
            assert(not search_result:is_absolute())
         end
         n.modules[mod_name] = search_result

         if not in_dir or search_result:is_in(in_dir) then
            unchecked_insert(dag, search_result, in_dir)
         end
      end
   end

   for node in values(dag._nodes_by_filename) do
      for mod_path in values(node.modules) do
         local dep_node = dag._nodes_by_filename[mod_path:to_real_path()]
         if dep_node then
            add_deps(dep_node.dependents, node)
         end
      end
   end
end

-- returns the list of filenames that depend on themselves
local function check_for_cycles(dag: Dag): {string}
   local ret = {}
   for fname, n in pairs(dag._nodes_by_filename) do
      if n.dependents[n] then
         ret[fname] = true
      end
   end
   if next(ret) then
      return from(keys(ret))
   end
end

---@desc
--- Inserts a file and its dependencies into a graph
---
--- Ignores absolute paths and non `.tl` or `.lua` files
---
--- If in_dir is provided, dependencies of the given file will not be added to
--- the graph unless they are inside of the given dir
---
--- Returns `false` if inserting the file introduced a circular dependency along
--- with a list of the filenames in the cycle
function Dag:insert_file(fstr: string | fs.Path, in_dir: string | fs.Path): boolean, {string}
   local f <const> = fstr is fs.Path
      and fstr
      or fs.path.new(fstr as string)

   assert(f, "No path given")
   unchecked_insert(self, f, fs.path.ensure(in_dir))
   local cycles <const> = check_for_cycles(self)
   if cycles then
      return false, cycles
   else
      return true
   end
end

---@desc
--- Find a node in the graph with the given path name
function Dag:find(fstr: string | fs.Path): Node
   local f <const> = fs.path.ensure(fstr)
   return self._nodes_by_filename[f:to_real_path()]
end

---@desc
--- Recursively scan a directory (using `fs.scan_dir`) and build up a graph,
--- respecting the given `include` and `exclude` patterns
---
--- Returns `nil` if a circular dependency was found, along
--- with a list of the filenames in the cycle
function graph.scan_dir(dir: string | fs.Path, include: {string}, exclude: {string}): Dag, {string}
   local d <const> = graph.empty()

   dir = fs.path.ensure(dir)
   for p in fs.scan_dir(dir, include, exclude) do
      local _, ext = fs.extension_split(p, 2)
      if ext == ".tl" or ext == ".lua" then
         unchecked_insert(d, (dir as fs.Path) .. p, dir as fs.Path)
      end
   end

   local cycles <const> = check_for_cycles(d)
   if cycles then
      return nil, cycles
   else
      return d
   end
end

return graph
