local _tl_compat; if (tonumber((_VERSION or ''):match('[%d.]*$')) or 0) < 5.3 then local p, m = pcall(require, 'compat53.module'); if p then _tl_compat = m end end; local ipairs = _tl_compat and _tl_compat.ipairs or ipairs; local table = _tl_compat and _tl_compat.table or table
local common = require("cyan.tlcommon")
local fs = require("cyan.fs")
local util = require("cyan.util")


local values = util.tab.values

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
   local i = self._most_deps
   local iter = values(self._nodes[i])
   return function()
      local n
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
n.mark == m; return n
   end
end

local graph = {
   Node = Node,
   Dag = Dag,
}

function graph.scan_dir(dir, include, exclude)
   local nodes_by_filename = {}
   local d = {}
   for p in fs.scan_dir(dir, include, exclude) do
      local _, ext = fs.extension_split(p, 2)
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
      __index = function(self, key)
         if key > d._most_deps then d._most_deps = key end
         rawset(self, key, {})
         return rawget(self, key)
      end,
   })
   for node in values(nodes_by_filename) do
      table.insert(d._nodes[#node.dependents], node)
   end



   return setmetatable(d, { __index = Dag })
end

return graph