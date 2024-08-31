local _tl_compat; if (tonumber((_VERSION or ''):match('[%d.]*$')) or 0) < 5.3 then local p, m = true, require('compat53.module'); if p then _tl_compat = m end end; local assert = _tl_compat and _tl_compat.assert or assert; local ipairs = _tl_compat and _tl_compat.ipairs or ipairs; local pcall = _tl_compat and _tl_compat.pcall or pcall; local string = _tl_compat and _tl_compat.string or string; local table = _tl_compat and _tl_compat.table or table; local _tl_table_unpack = unpack or table.unpack; local Batch = {}







local batch_mt = { __index = Batch }

local function indent(str)
   return (str:gsub("\n", "\n   "))
end

function Batch:new(name)
   return setmetatable({
      name = name or "???",
      _on_fail = "",
   }, batch_mt)
end

function Batch:show_on_failure(to_show)
   assert(not self._on_fail)
   self._on_fail = to_show
end

function Batch:add(assert_func, ...)
   table.insert(self, { assert_func, select("#", ...), { ... } })
   return self
end

function Batch:assert()
   local errs = {}
   local passed = true
   for i, assertion in ipairs(self) do
      local ok, err = pcall(assertion[1], _tl_table_unpack(assertion[3], 1, assertion[2]))
      if not ok then
         passed = false
         table.insert(errs, indent(("[%d] %s"):format(i, tostring(err))))
      end
   end

   assert(
   passed,
   string.format(
   "Batch assertion '%s' failed:\n   %s\n%s",
   self.name,
   indent(table.concat(errs, "\n\n")),
   indent(self._on_fail)))


end

return Batch
