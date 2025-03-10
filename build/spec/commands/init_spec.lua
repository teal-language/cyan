
local command_runners = require("testing.command-runners")

describe("init", function()
   it("should create a tlconfig.lua in the current directory and empty src and build directories", function()
      command_runners.run_mock_project(finally, {
         cmd = "init",
         dir_structure = {},
         generated_files = {
            ["tlconfig.lua"] = true,
            src = {},
            build = {},
         },
         cmd_output_match_lines = {
            "Created directory.*src",
            "Created directory.*build",
            "Wrote.*tlconfig%.lua",
         },
         exit_code = 0,
      })
   end)
   it("should create a directory with the name provided by --source-dir", function()
      command_runners.run_mock_project(finally, {
         cmd = "init",
         args = { "--source-dir", "foo" },
         dir_structure = {},
         generated_files = {
            ["tlconfig.lua"] = true,
            foo = {},
            build = {},
         },
         cmd_output_match_lines = {
            "Created directory.*foo",
            "Created directory.*build",
            "Wrote.*tlconfig%.lua",
         },
         exit_code = 0,
      })
   end)
   it("should create a directory with the name proveded by --build-dir", function()
      command_runners.run_mock_project(finally, {
         cmd = "init",
         args = { "--build-dir", "foo" },
         dir_structure = {},
         generated_files = {
            ["tlconfig.lua"] = true,
            src = {},
            foo = {},
         },
         cmd_output_match_lines = {
            "Created directory.*src",
            "Created directory.*foo",
            "Wrote.*tlconfig%.lua",
         },
         exit_code = 0,
      })
   end)
   it("should put all generated files in the given directory", function()
      command_runners.run_mock_project(finally, {
         cmd = "init",
         args = { "foo" },
         dir_structure = {},
         generated_files = {
            foo = {
               ["tlconfig.lua"] = true,
               src = {},
               build = {},
            },
         },
         cmd_output_match_lines = {
            "Created directory.*foo",
            "Created directory.*src",
            "Created directory.*build",
            "Wrote.*tlconfig%.lua",
         },
         exit_code = 0,
      })
   end)
   it("should error if the argument file exists and is not a directory", function()
      command_runners.run_mock_project(finally, {
         cmd = "init",
         args = { "foo" },
         dir_structure = {
            foo = [[]],
         },
         generated_files = {},
         cmd_output_match_lines = {
            "exists and is not a dir",
         },
         exit_code = 1,
      })
   end)
   it("should error if the --source-dir file exists and is not a directory", function()
      command_runners.run_mock_project(finally, {
         cmd = "init",
         args = { "--source-dir", "foo" },
         dir_structure = {
            foo = [[]],
         },
         generated_files = {},
         cmd_output_match_lines = {
            "exists and is not a dir",
         },
         exit_code = 1,
      })
   end)
   it("should error if the --build-dir file exists and is not a directory", function()
      command_runners.run_mock_project(finally, {
         cmd = "init",
         args = { "--build-dir", "foo" },
         dir_structure = {
            foo = [[]],
         },
         generated_files = {
            src = {},
         },
         cmd_output_match_lines = {
            "exists and is not a dir",
         },
         exit_code = 1,
      })
   end)
   it("should error if a config file is already found", function()
      command_runners.run_mock_project(finally, {
         cmd = "init",
         args = {},
         dir_structure = {
            ["tlconfig.lua"] = [[return {}]],
         },
         generated_files = {},
         cmd_output_match_lines = {
            "Already in a project",
            "Found",
         },
         exit_code = 1,
      })
   end)
   it("should not error if a config file is already found and --force is used", function()
      command_runners.run_mock_project(finally, {
         cmd = "init",
         args = { "--force" },
         dir_structure = {
            ["tlconfig.lua"] = [[return {}]],
         },
         generated_files = {
            src = {},
            build = {},
         },
         cmd_output_match_lines = {
            "Created directory.*src",
            "Created directory.*build",
            "Wrote.*tlconfig%.lua",
         },
         exit_code = 0,
      })
   end)
end)
