local _tl_compat; if (tonumber((_VERSION or ''):match('[%d.]*$')) or 0) < 5.3 then local p, m = pcall(require, 'compat53.module'); if p then _tl_compat = m end end; local ipairs = _tl_compat and _tl_compat.ipairs or ipairs; local pairs = _tl_compat and _tl_compat.pairs or pairs; local table = _tl_compat and _tl_compat.table or table
local common = require("teal-cli.tlcommon")
local fs = require("teal-cli.fs")

local Node = {}











local Dag = {}



local function mark_for_typecheck(n)
   if n.mark then return end
   n.mark = "typecheck"
   for _, child in ipairs(n.dependents) do
      mark_for_typecheck(child)
   end
end

local function mark_for_compile(n)
   if n.mark == "compile" then return end
   n.mark = "compile"
   for _, child in ipairs(n.dependents) do
      mark_for_typecheck(child)
   end
end

function Dag:nodes()
   local k, v
   return function()
      k, v = next(self._nodes, k)
      return v
   end
end

function Dag:mark_each(predicate)
   for n in self:nodes() do
      if predicate(n.input) then
         mark_for_compile(n)
      end
   end
end

function Dag:marked_nodes(m)
   local iter = self:nodes()
   return function()
      local n
      repeat n = iter()
      until not n or
n.mark == m
      return n
   end
end

local graph = {
   Node = Node,
   Dag = Dag,
}

function graph.scan_dir(dir, include, exclude)
   local nodes = {}
   for p in fs.scan_dir(dir, include, exclude) do
      local _, ext = fs.extension_split(p)
      if ext == ".tl" then
         local full_p = dir .. p
         local path = full_p:to_real_path()
         local res = common.parse_file(path)
         if res then
            local require_calls = res.reqs
            local modules = {}
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
   end

   for _, node in pairs(nodes) do
      for _, mod_path in pairs(node.modules) do
         local dep_node = nodes[mod_path:to_real_path()]
         if dep_node then
            table.insert(dep_node.dependents, node)
         end
      end
   end


   return setmetatable(
   {
      _nodes = nodes,
   },
   { __index = Dag })

end

return graph