local _tl_compat; if (tonumber((_VERSION or ''):match('[%d.]*$')) or 0) < 5.3 then local p, m = true, require('compat53.module'); if p then _tl_compat = m end end; local assert = _tl_compat and _tl_compat.assert or assert
local sandbox = require("cyan.sandbox")

describe("sandbox", function()
   (jit and pending or it)("should forcefully terminate long-running functions", function()
      local box = sandbox.new(function()
         for _ = 1, 1000 do
         end
      end)

      assert(not box:run(100))
   end)
end)
