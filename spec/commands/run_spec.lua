
local util = require("spec.util")

describe("run command", function()
   it("should run simple files", function()
      util.run_mock_project(finally, {
         cmd = "run",
         args = { "foo.tl" },
         dir_structure = {
            ["foo.tl"] = [[print("hello world")]],
         },
         cmd_output = "hello world\n",
      })
   end)

   it("should report type errors", function()
      util.run_mock_project(finally, {
         cmd = "run",
         args = { "foo.tl" },
         dir_structure = {
            ["foo.tl"] = [[local _x: string = 10]],
         },
         cmd_output_match = "Error.*in local declaration",
      })
   end)

   it("should run files in a sandbox", function()
      util.run_mock_project(finally, {
         cmd = "run",
         args = { "foo.tl" },
         dir_structure = {
            ["foo.tl"] = [[error("hi")]],
         },
         cmd_output_match = "Error in script",
      })
   end)

   it("should use tl.loader() to load tl files", function()
      util.run_mock_project(finally, {
         cmd = "run",
         args = { "foo.tl" },
         dir_structure = {
            ["foo.tl"] = [[print(require("bar"))]],
            ["bar.tl"] = [[return "hi"]],
         },
         cmd_output = "hi\n"
      })
   end)
end)
