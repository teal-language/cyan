local util = require("spec.util")
local script = require("cyan.script")

describe("script", function()
   describe("is_valid", function()
      it("should return nil when `exec` is nil", function()
         assert.is_nil((script.is_valid{}))
      end)
      it("should return nil when `exec` is not a function", function()
         assert.is_nil((script.is_valid{ exec = "hi" }))
      end)

      it("should return nil when `reads_from` is not {string}", function()
         assert.is_nil((script.is_valid{
            exec = function() end,
            run_on = {},
            reads_from = "thing"
         }))
      end)

      it("should return nil when `writes_to` is not {string}", function()
         assert.is_nil((script.is_valid{
            exec = function() end,
            run_on = {},
            writes_to = "thing"
         }))
      end)

      it("should return nil when `run_on` is not {string}", function()
         assert.is_nil((script.is_valid{
            exec = function() end,
            run_on = ""
         }))
      end)
   end)

   describe("io safety", function()
      it("io.open should return nil when opening a file not in reads_from", function()
         util.run_mock_project(finally, {
            dir_structure = {
               [util.configfile] = [[return { scripts = { "foo.lua" } }]],
               ["foo.lua"] = [[return {
                  run_on = { "build:pre" },
                  exec = function() assert(io.open("blah", "r") == nil) end,
               }]],
            },
            cmd = "build",
            exit_code = 0,
         })
      end)
      it("io.open should return a file handle when opening a file in reads_from", function()
         util.run_mock_project(finally, {
            dir_structure = {
               [util.configfile] = [[return { scripts = { "foo.lua" } }]],
               ["foo.lua"] = [[return {
                  run_on = { "build:pre" },
                  reads_from = { "foo.lua" },
                  exec = function() assert(io.open("foo.lua", "r")) end,
               }]],
            },
            cmd = "build",
            exit_code = 0,
         })
      end)
      it("io.open should return nil when opening a file not in writes_to", function()
         util.run_mock_project(finally, {
            dir_structure = {
               [util.configfile] = [[return { scripts = { "foo.lua" } }]],
               ["foo.lua"] = [[return {
                  run_on = { "build:pre" },
                  exec = function() assert(io.open("blah", "w") == nil) end,
               }]],
            },
            cmd = "build",
            exit_code = 0,
         })
      end)
      it("io.open should return a file handle when opening a file in writes_to", function()
         util.run_mock_project(finally, {
            dir_structure = {
               [util.configfile] = [[return { scripts = { "foo.lua" } }]],
               ["foo.lua"] = [[return {
                  run_on = { "build:pre" },
                  writes_to = { "blah" },
                  exec = function() assert(io.open("blah", "w")) end,
               }]],
            },
            cmd = "build",
            exit_code = 0,
         })
      end)
   end)
end)
