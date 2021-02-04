
local sandbox = require("teal-cli.sandbox")

describe("sandbox", function()
   it("should forcefully terminate long-running functions", function()
      local box = sandbox.new(function()
         while true do
         end
      end)
      box:run(100)
      assert(true)
   end)
   pending("should load a given file with the given environment")
end)
