
local util = require("spec.util")

describe("gen command", function()
   it("should not compile when there are type errors", function()
      util.run_mock_project(finally, {
         cmd = "gen",
         args = { "foo.tl" },
         dir_structure = {
            ["foo.tl"] = [[local _x: number = "hello"]],
         },
         cmd_output_match = "Error",
         generated_files = {},
      })
   end)

   it("should compile when there are no type errors", function()
      util.run_mock_project(finally, {
         cmd = "gen",
         args = { "foo.tl" },
         dir_structure = {
            ["foo.tl"] = [[local _x: string = "hello"]]
         },
         generated_files = { "foo.lua" },
         cmd_output_match_lines = {
            [1] = "Type checked .*foo%.tl",
            [2] = "Wrote .*foo%.lua",
         },
      })
   end)
end)
