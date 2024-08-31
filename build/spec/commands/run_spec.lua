
local command_runners = require("testing.command-runners")

describe("run command", function()
   it("should run simple files", function()
      command_runners.run_mock_project(finally, {
         cmd = "run",
         args = { "foo.tl" },
         dir_structure = {
            ["foo.tl"] = [[print("hello world")]],
         },
         cmd_output = "hello world\n",
         exit_code = 0,
      })
   end)

   it("should report type errors", function()
      command_runners.run_mock_project(finally, {
         cmd = "run",
         args = { "foo.tl" },
         dir_structure = {
            ["foo.tl"] = [[local _x: string = 10]],
         },
         cmd_output_match = "Error.*in local declaration",
         exit_code = 1,
      })
   end)

   it("should run files in a sandbox", function()
      command_runners.run_mock_project(finally, {
         cmd = "run",
         args = { "foo.tl" },
         dir_structure = {
            ["foo.tl"] = [[error("hi")]],
         },
         cmd_output_match = "Error in script",
         exit_code = 1,
      })
   end)

   it("should use tl.loader() to load tl files", function()
      command_runners.run_mock_project(finally, {
         cmd = "run",
         args = { "foo.tl" },
         dir_structure = {
            ["foo.tl"] = [[local bar = require("bar"); print(bar)]],
            ["bar.tl"] = [[return "hi"]],
         },
         cmd_output = "hi\n",
         exit_code = 0,
      })
   end)
end)
