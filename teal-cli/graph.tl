
local common <const> = require("teal-cli.tlcommon")
local fs <const> = require("teal-cli.fs")

local record Node
   input: fs.Path
   output: fs.Path
   modules: {string:fs.Path}
   enum Mark
      "typecheck"
      "compile"
   end
   mark: Mark
   dependents: {Node}
end

local record Dag
   _nodes: {string:Node}
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

local function get_node(d: Dag, p: fs.Path | string): Node
   local path <const> = p is fs.Path and p:to_real_path() or p
   return d._nodes[path]
end

-- function Dag:mark_for_typecheck(p: fs.Path | string)
   -- mark_for_typecheck(get_node(self, p))
-- end

-- function Dag:mark_for_compile(p: fs.Path | string)
   -- mark_for_compile(get_node(self, p))
-- end

function Dag:nodes(): function(): Node
   local k, v: string, Node
   return function(): Node
      k, v = next(self._nodes, k)
      return v
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

function graph.scan_dir(dir: string | fs.Path, include: {string}, exclude: {string}): Dag
   local nodes <const>: {string:Node} = {}
   for p in fs.scan_dir(dir, include, exclude) do
      local full_p <const> = dir .. p
      local path <const> = full_p:to_real_path()
      local res <const> = common.parse_file(path)
      if res then
         local require_calls <const> = res.reqs
         local modules <const>: {string:fs.Path} = {}
         for _, mod_name in ipairs(require_calls) do
            modules[mod_name] = common.search_module(mod_name, true)
         end
         nodes[path] = {
            input = full_p,
            modules = modules,
            dependents = {},
         }
      end
   end

   for path, node in pairs(nodes) do
      for _, mod_path in pairs(node.modules) do
         local dep_node = nodes[mod_path:to_real_path()]
         if dep_node then
            table.insert(dep_node.dependents, node)
         end
      end
   end

   -- TODO: check for circular deps
   return setmetatable(
      {
         _nodes = nodes
      } as Dag,
      { __index = Dag } as metatable<Dag>
   )
end

return graph
