local type _ = require("busted")
local sandbox <const> = require("cyan.sandbox")

describe("sandbox", function()
   (jit and pending or it)("should forcefully terminate long-running functions", function()
      local box = sandbox.new(function()
         for _ = 1, 1000 do
         end
      end)

      assert(not box:run(100))
   end)
end)
