
local sandbox = require("cyan.sandbox")

describe("sandbox", function()
   it("should forcefully terminate long-running functions", function()
      local box = sandbox.new(function()
         while true do
         end
      end)
      assert.falsy(box:run(100))
      assert(true)
   end)
end)
