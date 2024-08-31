local type _ = require("busted")
local luassert <const> = require("luassert")
local temporary_files <const> = require("testing.temporary-files")
local command_runners <const> = require("testing.command-runners")

describe("check command", function()
   it("should do basic type checking of a single file", function()
      command_runners.run_mock_project(finally, {
         cmd = "check",
         args = { "foo.tl" },
         dir_structure = {
            ["foo.tl"] = [[local x: number = "hello"]]
         },
         cmd_output_match = "Error",
         exit_code = 1,
      })
   end)

   it("should do basic type checking of many files", function()
      command_runners.run_mock_project(finally, {
         cmd = "check",
         args = { "foo.tl", "bar.tl" },
         dir_structure = {
            ["foo.tl"] = [[local _x: number = "hello"]],
            ["bar.tl"] = [[local _x: string = "hello"]],
         },
         cmd_output_match_lines = {
            [1] = "Error.*%d.*foo%.tl",
            [7] = "Type checked.*bar%.tl",
         },
         exit_code = 1,
      })
   end)

   it("should report errors in dependencies", function()
      command_runners.run_mock_project(finally, {
         cmd = "check",
         args = { "foo.tl" },
         dir_structure = {
            ["foo.tl"] = [[require"bar"]],
            ["bar.tl"] = [[local _x: number = "hello"]],
         },
         -- cmd_output_match_lines = {
         -- },
         exit_code = 1,
      })
   end)

   it("should handle being told to type check a non-file", function()
      command_runners.run_mock_project(finally, {
         cmd = "check",
         args = { "foo" },
         dir_structure = {
            foo = {},
         },
         cmd_output_match = "is not a file",
         exit_code = 1,
      })
   end)

   it("should chdir into the root before checking", function()
      temporary_files.do_in(temporary_files.write_directory(finally, {
         ["tlconfig.lua"] = [[return {}]],
         foo = {
            ["bar.tl"] = [[require("foo.baz")]],
            ["baz.tl"] = [[return 10]],
         },
      }), function()
         -- TODO: #Subprocess
         local out = command_runners.run_command("cd foo && " .. command_runners.cyan_command("check", "bar.tl") .. " 2>&1")
         luassert.match("Type checked", out)
      end)
   end)

   it("should show type errors along with the line that they occur on", function()
      command_runners.run_mock_project(finally, {
         cmd = "check",
         args = { "foo.tl" },
         dir_structure = {
            ["foo.tl"] = [[local x: string = 10]],
         },
         cmd_output_match = [[1.-│.-local.-x: string]],
         exit_code = 1,
      })
   end)

   it("should properly report syntax errors", function()
      command_runners.run_mock_project(finally, {
         cmd = "check",
         args = { "foo.tl" },
         dir_structure = {
            ["foo.tl"] = [[print(1 != 2)]]
         },
         cmd_output_match = [[syntax error]],
         exit_code = 1,
      })
   end)

   it("should work with a relative path in the parent directory", function()
      temporary_files.do_in(temporary_files.write_directory(finally, {
         ["foo.tl"] = [[local _: integer = 1]],
         bar = {},
      }), function()
         -- TODO: #Subprocess
         local out = command_runners.run_command("cd bar && " .. command_runners.cyan_command("check", "../foo.tl") .. " 2>&1")
         luassert.match("Type checked", out)
      end)
   end)
end)
