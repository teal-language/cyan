local type _ = require("busted")
local command_runners <const> = require("testing.command-runners")

describe("gen command", function()
   it("should not compile when there are type errors", function()
      command_runners.run_mock_project(finally, {
         cmd = "gen",
         args = { "foo.tl" },
         dir_structure = {
            ["foo.tl"] = [[local _x: number = "hello"]],
         },
         cmd_output_match = "Error",
         generated_files = {},
         exit_code = 1,
      })
   end)

   it("should compile when there are no type errors", function()
      command_runners.run_mock_project(finally, {
         cmd = "gen",
         args = { "foo.tl" },
         dir_structure = {
            ["foo.tl"] = [[local _x: string = "hello"]]
         },
         generated_files = { ["foo.lua"] = true },
         cmd_output_match_lines = {
            [1] = "Type checked .*foo%.tl",
            [2] = "Wrote .*foo%.lua",
         },
         exit_code = 0,
      })
   end)

   describe("--output", function()
      it("should map a single input to a single output", function()
         command_runners.run_mock_project(finally, {
            cmd = "gen",
            args = { "foo.tl", "-o", "bar.lua" },
            dir_structure = {
               ["foo.tl"] = [[]],
            },
            generated_files = { ["bar.lua"] = true },
            cmd_output_match_lines = {
               [1] = "Type checked .*foo%.tl",
               [2] = "Wrote .*bar%.lua",
            },
            exit_code = 0,
         })
      end)

      it("should error with multiple inputs", function()
         command_runners.run_mock_project(finally, {
            cmd = "gen",
            args = { "foo.tl", "bar.tl", "-o", "baz.lua" },
            dir_structure = {
               ["foo.tl"] = [[]],
               ["bar.tl"] = [[]],
            },
            generated_files = {},
            cmd_output_match = "1 output",
            exit_code = 1,
         })
      end)
   end)

end)
