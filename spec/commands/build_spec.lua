
local util = require("spec.util")

describe("build command", function()
   it("should error out if tlconfig.lua is not present", function()
      util.run_mock_project(finally, {
         cmd = "build",
         dir_structure = {},
         cmd_output_match = util.configfile .. " not found",
         exit_code = 1,
      })
   end)
   it("should put generated files in build_dir", function()
      util.run_mock_project(finally, {
         cmd = "build",
         dir_structure = {
            [util.configfile] = [[return { build_dir = "build" }]],
            ["foo.tl"] = [[]],
            ["bar.tl"] = [[]],
            build = {},
         },
         generated_files = {
            build = {
               "foo.lua",
               "bar.lua",
            },
         },
         exit_code = 0,
      })
   end)
   it("should report syntax errors", function()
      util.run_mock_project(finally, {
         cmd = "build",
         dir_structure = {
            [util.configfile] = [[return {}]],
            ["foo.tl"] = [[a b c]],
         },
         generated_files = {},
         exit_code = 1,
         output_match = "syntax error",
      })
   end)
   it("should only compile .tl files", function()
      util.run_mock_project(finally, {
         cmd = "build",
         dir_structure = {
            [util.configfile] = [[return {}]],
            ["foo.tl"] = [[]],
            ["bar.lua"] = [[]],
            ["baz.py"] = [[]],
            ["bat.d.tl"] = [[]],
         },
         generated_files = {
            "foo.lua",
         },
         exit_code = 0,
      })
   end)
   it("should create directories if they don't exist", function()
      util.run_mock_project(finally, {
         cmd = "build",
         dir_structure = {
            [util.configfile] = [[return { build_dir = "foo/bar/baz" }]],
            ["foo.tl"] = [[]],
         },
         generated_files = {
            foo = { bar = { baz = { "foo.lua" } } },
         },
         exit_code = 0,
      })
   end)
   it("should error out if build_dir exists and is not a directory", function()
      util.run_mock_project(finally, {
         cmd = "build",
         dir_structure = {
            [util.configfile] = [[return { build_dir = "build" }]],
            ["build"] = [[uh oh]],
         },
         cmd_output_match = [[Build dir "build" is not a directory]],
         exit_code = 1,
      })
   end)
   it("should error out if source_dir exists and is not a directory", function()
      util.run_mock_project(finally, {
         cmd = "build",
         dir_structure = {
            [util.configfile] = [[return { source_dir = "src" }]],
            ["src"] = [[uh oh]],
         },
         cmd_output_match = [[Source dir "src" is not a directory]],
         exit_code = 1,
      })
   end)
   it("should not compile any files if anything has a type error", function()
      util.run_mock_project(finally, {
         cmd = "build",
         dir_structure = {
            [util.configfile] = [[return {}]],
            ["foo.tl"] = [[local x: string = 10]],
            ["bar.tl"] = [[local x: number = 10]],
         },
         generated_files = {},
         exit_code = 1,
      })
   end)
   it("should create parent directories to files in the build dir", function()
      util.run_mock_project(finally, {
         cmd = "build",
         dir_structure = {
            [util.configfile] = [[return { build_dir = "foo" }]],
            foo = {},
            a = { b = { ["c.tl"] = [[]] } },
         },
         generated_files = {
            foo = { a = { b = { "c.lua" } } },
         },
         exit_code = 0,
      })
   end)
   it("should be able to resolve requires with `module_name` and `source_dir` set", function()
      util.run_mock_project(finally, {
         cmd = "build",
         dir_structure = {
            [util.configfile] = [[return { source_dir = "src", module_name = "foo", build_dir = "build" }]],
            src = {
               ["bar.tl"] = [[return 10]],
               ["baz.tl"] = [[local x: number = require("foo.bar")]],
            },
            generated_files = {
               build = {
                  "bar.lua",
                  "baz.lua",
               }
            },
         },
         exit_code = 0,
      })
   end)
   it("should not error when there are no files to process", function()
      util.run_mock_project(finally, {
         cmd = "build",
         dir_structure = {
            [util.configfile] = [[return { }]],
         },
         exit_code = 0,
      })
   end)
   describe("script hooks", function()
      it("should emit a build:pre hook before doing any actions", function()
         util.run_mock_project(function() end, {
            cmd = "build",
            dir_structure = {
               [util.configfile] = [[ return {
                  scripts = { "foo.lua" },
               } ]],
               ["foo.lua"] = [[ return {
                  run_on = { "build:pre" },
                  exec = function() print("foo") end,
               } ]],
            },
            output_match = "foo",
            generated_files = { },
            exit_code = 0,
         })
      end)
      it("should emit a build:post hook after building", function()
         util.run_mock_project(function() end, {
            cmd = "build",
            dir_structure = {
               [util.configfile] = [[ return {
                  scripts = { "foo.lua" },
                  source_dir = "src",
                  build_dir = "build",
               } ]],
               src = { ["foo.tl"] = "" },
               build = {},
               ["foo.lua"] = [[ return {
                  run_on = { "build:post" },
                  exec = function() print("after") end,
               } ]],
            },
            cmd_output_match_lines = {
               "Type checked.*foo",
               "Wrote.*foo",
               "after",
            },
            generated_files = { build = { "foo.lua" } },
            exit_code = 0,
         })
      end)
      it("should not emit a build:post hook when there is nothing to do", function()
         util.run_mock_project(function() end, {
            cmd = "build",
            dir_structure = {
               [util.configfile] = [[ return {
                  scripts = { "foo.lua" },
               } ]],
               ["foo.lua"] = [[ return {
                  run_on = { "build:post" },
                  exec = function() print("after") end,
               } ]],
            },
            cmd_output = "",
            exit_code = 0,
         })
      end)
   end)
end)

