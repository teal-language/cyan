
local common <const> = require("cyan.tlcommon")
local fs <const> = require("cyan.fs")
local util <const> = require("cyan.util")
-- local log <const> = require("cyan.log")

local values <const> = util.tab.values

local record Node
   input: fs.Path
   output: fs.Path
   modules: {string:fs.Path} -- require argument -> path found
   enum Mark
      "typecheck"
      "compile"
   end
   mark: Mark
   dependents: {Node}
end

local record Dag
   _nodes: {number:{Node}}
   _most_deps: number
end

local function mark_for_typecheck(n: Node)
   if n.mark then return end
   n.mark = "typecheck"
   for _, child in ipairs(n.dependents) do
      mark_for_typecheck(child)
   end
end

local function mark_for_compile(n: Node)
   if n.mark == "compile" then return end
   n.mark = "compile"
   for _, child in ipairs(n.dependents) do
      mark_for_typecheck(child)
   end
end

function Dag:nodes(): function(): Node
   local i = self._most_deps
   local iter = values(self._nodes[i])
   return function(): Node
      local n: Node
      while i >= 0 do
         n = iter()
         if n then
            return n
         end
         i = i - 1
         iter = values(self._nodes[i])
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

-- Iterate over nodes in order of dependents
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

function graph.scan_dir(dir: string | fs.Path, include: {string}, exclude: {string}): Dag
   local nodes_by_filename <const>: {string:Node} = {} -- file name -> Node
   local d <const>: Dag = {}
   for p in fs.scan_dir(dir, include, exclude) do
      local _, ext = fs.extension_split(p, 2)
      if ext == ".tl" then
         local full_p <const> = dir .. p
         local path <const> = full_p:to_real_path()
         local res <const> = common.parse_file(path)
         if res then
            local require_calls <const> = res.reqs
            local modules <const>: {string:fs.Path} = {}
            for _, mod_name in ipairs(require_calls) do
               modules[mod_name] = common.search_module(mod_name, true)
            end
            nodes_by_filename[path] = {
               input = full_p,
               modules = modules,
               dependents = {},
            }
         end
      end
   end

   for node in values(nodes_by_filename) do
      for mod_path in values(node.modules) do
         local dep_node = nodes_by_filename[mod_path:to_real_path()]
         if dep_node then
            table.insert(dep_node.dependents, node)
         end
      end
   end

   d._most_deps = 0
   d._nodes = setmetatable({}, {
      __index = function(self: {number:{Node}}, key: number): {Node}
         if key > d._most_deps then d._most_deps = key end
         rawset(self, key, {})
         return rawget(self, key)
      end
   })
   for node in values(nodes_by_filename) do
      table.insert(d._nodes[#node.dependents], node)
   end

   -- TODO: check for circular deps

   return setmetatable(d, { __index = Dag })
end

return graph
