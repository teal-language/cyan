local util = require("spec.util")

describe("--no-script", function()
   it("should not run any scripts when provided", function()
      util.run_mock_project(finally, {
         dir_structure = {
            [util.configfile] = [[return { scripts = { "foo.lua" } }]],
            ["foo.lua"] = [[return {
               run_on = { "build:pre" },
               exec = function() print("foo!") end,
            }]],
            ["bar.tl"] = [[]]
         },
         generated_files = { "bar.lua" },
         cmd = "build",
         args = { "--no-script" },
         exit_code = 0,
         cmd_output_match_lines = {
            "Type checked.*bar",
            "Wrote.*bar%.lua",

            n = 2,
         },
      })
   end)
end)
