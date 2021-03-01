local _tl_compat; if (tonumber((_VERSION or ''):match('[%d.]*$')) or 0) < 5.3 then local p, m = true, require('compat53.module'); if p then _tl_compat = m end end; local table = _tl_compat and _tl_compat.table or table
local common = require("cyan.tlcommon")
local fs = require("cyan.fs")
local util = require("cyan.util")

local values, ivalues, keys =
util.tab.values, util.tab.ivalues, util.tab.keys

local Node = {}











local function make_node(input)
   return {
      input = input,
      modules = {},
      dependents = {},
   }
end

local Dag = {}




local function mark_for_typecheck(n)
   if n.mark then return end
   n.mark = "typecheck"
   for child in keys(n.dependents) do
      mark_for_typecheck(child)
   end
end

local function mark_for_compile(n)
   if n.mark == "compile" then return end
   n.mark = "compile"
   for child in keys(n.dependents) do
      mark_for_typecheck(child)
   end
end

local function make_dependent_counter()
   local cache = {}
   local function count_dependents(n)
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

function Dag:nodes()
   local count = make_dependent_counter()
   local most_deps = 0
   local nodes_by_deps = setmetatable({}, {
      __index = function(self, key)
         if key > most_deps then
            most_deps = key
         end
         local arr = {}
         rawset(self, key, arr)
         return arr
      end,
   })
   for n in values(self._nodes_by_filename) do
      table.insert(nodes_by_deps[count(n)], n)
   end

   setmetatable(nodes_by_deps, nil)

   local i = most_deps
   local iter = values(nodes_by_deps[i])
   return function()
      local n
      while i >= 0 do
         n = iter()
         if n then
            return n
         end
         repeat i = i - 1
         until i < 0 or nodes_by_deps[i]
         if nodes_by_deps[i] then
            iter = values(nodes_by_deps[i])
         end
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

function graph.empty()
   return setmetatable({
      _nodes_by_filename = {},
   }, { __index = Dag })
end



function Dag:insert_file(fstr)
   local f = type(fstr) == "table" and
   fstr or
   fs.path.new(fstr)

   if f:is_absolute() then

      return
   end

   local real_path = f:to_real_path()

   if self._nodes_by_filename[real_path] then

      return
   end
   local _, ext = fs.extension_split(f, 2)
   if ext ~= ".tl" then

      return
   end
   local res = common.parse_file(real_path)
   if not res then return end
   local n = make_node(f)
   self._nodes_by_filename[real_path] = n

   for mod_name in ivalues(res.reqs) do

      local search_result = common.search_module(mod_name, true)
      n.modules[mod_name] = search_result
      self:insert_file(search_result)
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

function Dag:find(fstr)
   local f = type(fstr) == "table" and
   fstr or
   fs.path.new(fstr)

   return self._nodes_by_filename[f:to_real_path()]
end

function graph.scan_dir(dir, include, exclude)
   local d = graph.empty()

   for p in fs.scan_dir(dir, include, exclude) do
      local _, ext = fs.extension_split(p, 2)
      if ext == ".tl" then
         d:insert_file(dir .. p)
      end
   end



   return setmetatable(d, { __index = Dag })
end

return graph
