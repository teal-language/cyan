
local util = require("spec.util")

describe("build command", function()
   it("should error out if tlconfig.lua is not present", function()
      util.run_mock_project(finally, {
         cmd = "build",
         dir_structure = {},
         cmd_output_match = "tlconfig.lua not found",
      })
   end)
end)

