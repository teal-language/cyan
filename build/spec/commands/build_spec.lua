local _tl_compat; if (tonumber((_VERSION or ''):match('[%d.]*$')) or 0) < 5.3 then local p, m = true, require('compat53.module'); if p then _tl_compat = m end end; local package = _tl_compat and _tl_compat.package or package; local string = _tl_compat and _tl_compat.string or string
local command_runners = require("testing.command-runners")

describe("build command", function()
   it("should error out if tlconfig.lua is not present", function()
      command_runners.run_mock_project(finally, {
         cmd = "build",
         dir_structure = {},
         cmd_output_match = "tlconfig.lua not found",
         exit_code = 1,
      })
   end)
   it("should put generated files in build_dir", function()
      command_runners.run_mock_project(finally, {
         cmd = "build",
         dir_structure = {
            ["tlconfig.lua"] = [[return { build_dir = "build" }]],
            ["foo.tl"] = [[]],
            ["bar.tl"] = [[]],
            build = {},
         },
         generated_files = {
            build = {
               ["foo.lua"] = true,
               ["bar.lua"] = true,
            },
         },
         exit_code = 0,
      })
   end)
   it("should report syntax errors", function()
      command_runners.run_mock_project(finally, {
         cmd = "build",
         dir_structure = {
            ["tlconfig.lua"] = [[return {}]],
            ["foo.tl"] = [[a b c]],
         },
         generated_files = {},
         exit_code = 1,
         cmd_output_match = "syntax error",
      })
   end)
   it("should only compile .tl files", function()
      command_runners.run_mock_project(finally, {
         cmd = "build",
         dir_structure = {
            ["tlconfig.lua"] = [[return {}]],
            ["foo.tl"] = [[]],
            ["bar.lua"] = [[]],
            ["baz.py"] = [[]],
            ["bat.d.tl"] = [[]],
         },
         generated_files = {
            ["foo.lua"] = true,
         },
         exit_code = 0,
      })
   end)
   it("should create directories if they don't exist", function()
      command_runners.run_mock_project(finally, {
         cmd = "build",
         dir_structure = {
            ["tlconfig.lua"] = [[return { build_dir = "foo/bar/baz" }]],
            ["foo.tl"] = [[]],
         },
         generated_files = {
            foo = { bar = { baz = { ["foo.lua"] = true } } },
         },
         exit_code = 0,
      })
   end)
   it("should error out if build_dir exists and is not a directory", function()
      command_runners.run_mock_project(finally, {
         cmd = "build",
         dir_structure = {
            ["tlconfig.lua"] = [[return { build_dir = "build" }]],
            ["build"] = [[uh oh]],
         },
         cmd_output_match = [[Build dir "build" is not a directory]],
         exit_code = 1,
      })
   end)
   it("should error out if source_dir exists and is not a directory", function()
      command_runners.run_mock_project(finally, {
         cmd = "build",
         dir_structure = {
            ["tlconfig.lua"] = [[return { source_dir = "src" }]],
            ["src"] = [[uh oh]],
         },
         cmd_output_match = [[Source dir "src" is not a directory]],
         exit_code = 1,
      })
   end)
   local abs_path = package.config:sub(1, 1) == "\\" and
   "C:\\foo\\bar" or
   "/foo/bar"
   it("should error out if source_dir is absolute", function()
      command_runners.run_mock_project(finally, {
         cmd = "build",
         dir_structure = {
            ["tlconfig.lua"] = ([[return { source_dir = %q }]]):format(abs_path),
         },
         cmd_output_match = [[Expected a non%-absolute path]],
         exit_code = 1,
      })
   end)
   it("should error out if build_dir is absolute", function()
      command_runners.run_mock_project(finally, {
         cmd = "build",
         dir_structure = {
            ["tlconfig.lua"] = ([[return { build_dir = %q }]]):format(abs_path),
         },
         cmd_output_match = [[Expected a non%-absolute path]],
         exit_code = 1,
      })
   end)
   it("should not compile any files if anything has a type error", function()
      command_runners.run_mock_project(finally, {
         cmd = "build",
         dir_structure = {
            ["tlconfig.lua"] = [[return {}]],
            ["foo.tl"] = [[local x: string = 10]],
            ["bar.tl"] = [[local x: number = 10]],
         },
         generated_files = {},
         exit_code = 1,
      })
   end)
   it("should create parent directories to files in the build dir", function()
      command_runners.run_mock_project(finally, {
         cmd = "build",
         dir_structure = {
            ["tlconfig.lua"] = [[return { build_dir = "foo" }]],
            foo = {},
            a = { b = { ["c.tl"] = [[]] } },
         },
         generated_files = {
            foo = { a = { b = { ["c.lua"] = true } } },
         },
         exit_code = 0,
      })
   end)
   it("should not error when there are no files to process", function()
      command_runners.run_mock_project(finally, {
         cmd = "build",
         dir_structure = {
            ["tlconfig.lua"] = [[return { }]],
         },
         exit_code = 0,
      })
   end)
   it("should not warn from out of project files", function()
      command_runners.run_mock_project(finally, {
         cmd = "build",
         dir_structure = {
            ["tlconfig.lua"] = [[return {
               source_dir = "src",
               build_dir = "build",
               warning_error = { "unused" }
            }]],
            ["foo.tl"] = [[ local x: number; return {} ]],
            src = {
               ["bar.tl"] = [[ require"foo" ]],
            },
            build = {},
         },
         generated_files = {
            build = {
               ["bar.lua"] = true,
            },
         },
         exit_code = 0,
      })
   end)
   it("should detect circular dependencies", function()
      command_runners.run_mock_project(finally, {
         cmd = "build",
         dir_structure = {
            ["tlconfig.lua"] = [[return {}]],
            ["a.tl"] = [[require "b"]],
            ["b.tl"] = [[require "c"]],
            ["c.tl"] = [[require "a"]],
         },
         generated_files = {},
         exit_code = 1,
         cmd_output_match = [[Circular dependency]],
      })
   end)
   it("should report when there are unexpected files in the build directory", function()
      command_runners.run_mock_project(finally, {
         cmd = "build",
         dir_structure = {
            ["tlconfig.lua"] = [[return { build_dir = "build", source_dir = "src" }]],
            build = {
               ["baz.txt"] = [[]],
            },
            src = {
               ["foo.tl"] = [[]],
               ["bar.tl"] = [[]],
            },
         },
         generated_files = {
            build = { ["foo.lua"] = true, ["bar.lua"] = true },
         },
         exit_code = 0,
         cmd_output_match = [[Unexpected files in build directory]],
      })
   end)
   it("should copy lua files from the source directory to the build directory", function()
      command_runners.run_mock_project(finally, {
         cmd = "build",
         dir_structure = {
            ["tlconfig.lua"] = [[return { build_dir = "build", source_dir = "src" }]],
            build = {},
            src = {
               ["foo.lua"] = [[print "foo"]],
               ["bar.tl"] = [[print "bar"]],
            },
         },
         exit_code = 0,
         generated_files = {
            build = { ["foo.lua"] = true, ["bar.lua"] = true },
         },
      })
   end)
   it("should NOT copy .d.tl files from the source directory to the build directory", function()
      command_runners.run_mock_project(finally, {
         cmd = "build",
         dir_structure = {
            ["tlconfig.lua"] = [[return { build_dir = "build", source_dir = "src" }]],
            build = {},
            src = {
               ["a.tl"] = [[require "b"]],
               ["b.d.tl"] = [[]],
            },
         },
         exit_code = 0,
         generated_files = {
            build = { ["a.lua"] = true },
         },
      })
   end)
   describe("script hooks", function()
      it("should emit a build:pre hook before doing any actions", function()
         command_runners.run_mock_project(finally, {
            cmd = "build",
            dir_structure = {
               ["tlconfig.lua"] = [[ return {
                  scripts = { build = { pre = "foo.lua" } },
               } ]],
               ["foo.lua"] = [[print"foo"]],
            },
            cmd_output_match = "foo",
            generated_files = {},
            exit_code = 0,
         })
      end)
      it("should emit a build:post hook after building", function()
         command_runners.run_mock_project(finally, {
            cmd = "build",
            dir_structure = {
               ["tlconfig.lua"] = [[ return {
                  scripts = { build = { post = "foo.lua" } },
                  source_dir = "src",
                  build_dir = "build",
               } ]],
               src = { ["foo.tl"] = "" },
               build = {},
               ["foo.lua"] = [[print"after"]],
            },
            cmd_output_match_lines = {
               "Type checked.*foo",
               "Wrote.*foo",
               "after",
            },
            generated_files = { build = { ["foo.lua"] = true } },
            exit_code = 0,
         })
      end)
      it("should not emit a build:post hook when there is nothing to do", function()
         command_runners.run_mock_project(finally, {
            cmd = "build",
            dir_structure = {
               ["tlconfig.lua"] = [[ return {
                  scripts = { build = { post = "foo.lua" } },
               } ]],
               ["foo.lua"] = [[print"after"]],
            },
            cmd_output = "",
            exit_code = 0,
         })
      end)
   end)
   describe("--global-env-def", function()
      it("it should load the given file before type checking", function()
         command_runners.run_mock_project(finally, {
            cmd = "build",
            dir_structure = {
               ["tlconfig.lua"] = [[return { global_env_def = "types" }]],
               ["types.d.tl"] = [[
                  global record Foo
                     bar: integer
                  end
               ]],
               ["main.tl"] = [[local x: integer = Foo.bar; print(x)]],
            },
            generated_files = { ["main.lua"] = true },
            exit_code = 0,
         })
      end)
      it("it should gracefully exit when the env def cannot be loaded", function()
         command_runners.run_mock_project(finally, {
            cmd = "build",
            dir_structure = {
               ["tlconfig.lua"] = [[return { global_env_def = "file-that-doesnt-exist" }]],
               ["main.tl"] = [[local x: integer = Foo.bar; print(x)]],
            },
            exit_code = 1,
            cmd_output_match = [[could not predefine]],
         })
      end)
   end)
   describe("--check-only flag", function()
      it("should not write any files", function()
         command_runners.run_mock_project(finally, {
            cmd = "build",
            args = { "--check-only" },
            dir_structure = {
               ["tlconfig.lua"] = [[return {}]],
               ["foo.tl"] = "local x: integer = 1; print(x)",
            },
            exit_code = 0,
            cmd_output_match = "Type checked.*foo",
            cmd_output_not_match = "Wrote",
         })
      end)
   end)
   describe("--prune flag", function()
      it("should delete unexpected files from the build directory", function()
         command_runners.run_mock_project(finally, {
            cmd = "build",
            args = { "--prune" },
            dir_structure = {
               ["tlconfig.lua"] = [[return { build_dir = "build" }]],
               build = {
                  ["foo.txt"] = [[]],
               },
               ["bar.tl"] = [[print 'hello']],
            },
            exit_code = 0,
            cmd_output_match_lines = {
               "Type checked.*bar%.tl",
               "Wrote.*bar%.lua",
               "Pruned.*foo%.txt",
            },
         })
      end)
      it("should delete unexpected directories from the build directory", function()
         command_runners.run_mock_project(finally, {
            cmd = "build",
            args = { "--prune" },
            dir_structure = {
               ["tlconfig.lua"] = [[return { build_dir = "build" }]],
               build = {
                  foo = {
                     ["foo.txt"] = [[]],
                  },
               },
               ["bar.tl"] = [[print 'hello']],
            },
            exit_code = 0,
            cmd_output_match_lines = {
               "Type checked.*bar%.tl",
               "Wrote.*bar%.lua",
               "Pruned.*foo/foo%.txt",
            },
         })
      end)
   end)
   describe("--source-dir", function()
      it("should override the directory with the source files in it", function()
         command_runners.run_mock_project(finally, {
            cmd = "build",
            args = { "--source-dir", "other" },
            dir_structure = {
               ["tlconfig.lua"] = [[return { source_dir = "src" }]],
               src = {},
               other = { ["foo.tl"] = "return 2" },
            },
            exit_code = 0,
            generated_files = { ["foo.lua"] = true },
         })
      end)
   end)
   describe("--build-dir", function()
      it("should override the directory with the generated files in it", function()
         command_runners.run_mock_project(finally, {
            cmd = "build",
            args = { "--build-dir", "other" },
            dir_structure = {
               ["tlconfig.lua"] = [[return { source_dir = "src" }]],
               src = { ["foo.tl"] = "return 2" },
               build = {},
               other = {},
            },
            exit_code = 0,
            generated_files = { other = { ["foo.lua"] = true } },
         })
      end)
   end)
   describe("#tlconfig ignore_files", function()
      it("should not warn about ignored files in the build directory", function()
         command_runners.run_mock_project(finally, {
            cmd = "build",
            args = {},
            dir_structure = {
               ["tlconfig.lua"] = [[return { source_dir = "src", build_dir = "build", dont_prune = { "build/to-ignore.txt" } }]],
               src = { ["foo.tl"] = [[print "hey"]] },
               build = { ["to-ignore.txt"] = "hi" },
            },
            exit_code = 0,
            generated_files = { build = { ["foo.lua"] = true } },
            cmd_output_not_match = "%-%-prune",
         })
      end)
   end)
   it("should not write lua files when source_dir == build_dir", function()
      local foo_contents = [[
-- comment
print "hi"
]]
      command_runners.run_mock_project(finally, {
         cmd = "build",
         args = {},
         dir_structure = {
            ["tlconfig.lua"] = [[return { source_dir = "dir", build_dir = "dir" }]],
            dir = {
               ["foo.lua"] = foo_contents,
            },
         },
         exit_code = 0,
         cmd_output_not_match = "Wrote",
      })
   end)
end)
