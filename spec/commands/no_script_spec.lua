local util = require("spec.util")

describe("--no-script", function()
   it("should not run any scripts when provided", function()
      util.run_mock_project(finally, {
         dir_structure = {
            [util.configfile] = [[return { scripts = { ["build:post"] = { "foo.lua" } } }]],
            ["foo.lua"] = [[print("hello!")]],
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
