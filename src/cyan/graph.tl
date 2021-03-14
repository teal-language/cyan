
local common <const> = require("cyan.tlcommon")
local fs <const> = require("cyan.fs")
local util <const> = require("cyan.util")

local values <const>, ivalues <const>, keys <const>
   = util.tab.values, util.tab.ivalues, util.tab.keys

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

local record Dag
   -- This could probably be 'public'
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

-- Iterate over nodes in order of dependents
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


function Dag:mark_each(predicate: function(fs.Path): boolean)
   for n in self:nodes() do
      if predicate(n.input) then
         mark_for_compile(n)
      end
   end
end

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

function graph.empty(): Dag
   return setmetatable({
      _nodes_by_filename = {},
   }, { __index = Dag })
end

---@desc
--- Inserts a file and its dependencies into a graph
---
--- Ignores absolute paths and non `.tl` files
function Dag:insert_file(fstr: string | fs.Path)
   local f <const> = fstr is fs.Path
      and fstr
      or fs.path.new(fstr as string)
   assert(f, "No path given")
   if f:is_absolute() then
      -- If a path is absolute, assume it is out of the project
      return
   end

   local real_path <const> = f:to_real_path()

   if self._nodes_by_filename[real_path] then
      -- We already have this in the graph
      return
   end
   local _, ext <const> = fs.extension_split(f, 2)
   if ext ~= ".tl" then
      -- we dont care about non Teal stuff
      return
   end
   local res <const> = common.parse_file(real_path)
   if not res then return end
   local n <const>: Node = make_node(f)
   self._nodes_by_filename[real_path] = n

   for mod_name in ivalues(res.reqs) do
      -- TODO: should we search for .d.tl files?
      local search_result <const> = common.search_module(mod_name, true)
      if search_result then
         n.modules[mod_name] = search_result
         self:insert_file(search_result)
      end
   end

   for node in values(self._nodes_by_filename) do
      for mod_path in values(node.modules) do
         local dep_node = self._nodes_by_filename[mod_path:to_real_path()]
         if dep_node then
            dep_node.dependents[node] = true
         end
      end
   end
end

function Dag:find(fstr: string | fs.Path): Node
   local f <const> = fstr is fs.Path
      and fstr
      or fs.path.new(fstr as string)

   return self._nodes_by_filename[f:to_real_path()]
end

function graph.scan_dir(dir: string | fs.Path, include: {string}, exclude: {string}): Dag
   local d <const> = graph.empty()

   for p in fs.scan_dir(dir, include, exclude) do
      local _, ext = fs.extension_split(p, 2)
      if ext == ".tl" then
         d:insert_file(dir .. p)
      end
   end

   -- TODO: check for circular deps

   return d
end

return graph
