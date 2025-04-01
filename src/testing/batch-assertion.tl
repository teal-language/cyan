local luassert <const> = require("luassert")

local record Batch
   {{function(...: any), integer, {any}}}

   name: string

   _on_fail: string
end

local batch_mt <const>: metatable<Batch> = { __index = Batch }

local function indent(str: string): string
   return (str:gsub("\n", "\n   "))
end

function Batch:new(name: string): Batch
   return setmetatable({
      name = name or "???",
      _on_fail = nil,
   }, batch_mt)
end

function Batch:show_on_failure(to_show: string)
   assert(not self._on_fail, "Internal error: show_on_failure called multiple times")
   self._on_fail = to_show
end

function Batch:add(assert_func: function(...: any), ...): Batch
   table.insert(self, { assert_func, select("#", ...), {...} })
   return self
end

function Batch:assert()
   local errs = {}
   local passed = true
   for i, assertion in ipairs(self) do
      local ok <const>, err <const> = pcall(assertion[1], table.unpack(assertion[3], 1, assertion[2])) as (boolean, any)
      if not ok then
         passed = false
         table.insert(errs, indent(("[%d] %s"):format(i, tostring(err))))
      end
   end

   luassert.is_true(
      passed,
      string.format(
         "Batch assertion '%s' failed:\n   %s\n%s",
         self.name,
         indent(table.concat(errs, "\n\n")),
         indent(self._on_fail)
      )
   )
end

return Batch
