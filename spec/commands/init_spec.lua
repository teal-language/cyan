local util = require("spec.util")

describe("init", function()
   it("should create a tlconfig.lua in the current directory and empty src and build directories", function()
      util.run_mock_project(finally, {
         cmd = "init",
         dir_structure = {},
         generated_files = {
            "tlconfig.lua",
            src = {},
            build = {},
         },
         cmd_output_match_lines = {
            "Created directory.*src",
            "Created directory.*build",
            "Wrote.*" .. util.configfile,
         },
         exit_code = 0,
      })
   end)
   it("should create a directory with the name provided by --source-dir", function()
      util.run_mock_project(finally, {
         cmd = "init",
         args = { "--source-dir", "foo" },
         dir_structure = {},
         generated_files = {
            "tlconfig.lua",
            foo = {},
            build = {},
         },
         cmd_output_match_lines = {
            "Created directory.*foo",
            "Created directory.*build",
            "Wrote.*" .. util.configfile,
         },
         exit_code = 0,
      })
   end)
   it("should create a directory with the name proveded by --build-dir", function()
      util.run_mock_project(finally, {
         cmd = "init",
         args = { "--build-dir", "foo" },
         dir_structure = {},
         generated_files = {
            "tlconfig.lua",
            src = {},
            foo = {},
         },
         cmd_output_match_lines = {
            "Created directory.*src",
            "Created directory.*foo",
            "Wrote.*" .. util.configfile,
         },
         exit_code = 0,
      })
   end)
   it("should put all generated files in the given directory", function()
      util.run_mock_project(finally, {
         cmd = "init",
         args = { "foo" },
         dir_structure = {},
         generated_files = {
            foo = {
               "tlconfig.lua",
               src = {},
               build = {},
            },
         },
         cmd_output_match_lines = {
            "Created directory.*foo",
            "Created directory.*src",
            "Created directory.*build",
            "Wrote.*" .. util.configfile,
         },
         exit_code = 0,
      })
   end)
   it("should error if the argument file exists and is not a directory", function()
      util.run_mock_project(finally, {
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
      util.run_mock_project(finally, {
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
      util.run_mock_project(finally, {
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
      util.run_mock_project(finally, {
         cmd = "init",
         args = {},
         dir_structure = {
            ["tlconfig.lua"] = [[]],
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
      util.run_mock_project(finally, {
         cmd = "init",
         args = { "--force" },
         dir_structure = {
            ["tlconfig.lua"] = [[]],
         },
         generated_files = {
            src = {},
            build = {},
         },
         cmd_output_match_lines = {
            "Created directory.*src",
            "Created directory.*build",
            "Wrote.*" .. util.configfile,
         },
         exit_code = 0,
      })
   end)
end)
