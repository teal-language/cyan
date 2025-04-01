

local luassert = require("luassert")
local config = require("cyan.config")

describe("config loading", function()
   it("should perform some simplistic type checking", function()
      local res, errs, warnings = config.is_config({
         source_dir = 10,
      })
      luassert.is_nil(res)
      luassert.are_equal(errs[1], "Expected source_dir to be a string, got number")
      luassert.are_same(warnings, {})
   end)

   it("should only check that `externals` is a table, but nothing inside of it", function()
      local c = {
         externals = {},
      }
      c.externals[1] = function() end
      c.externals["hello"] = 10
      c.externals[{}] = {}

      local res, errs, warnings = config.is_config(c)
      luassert.are_equal(res.externals, c.externals)
      luassert.is_nil(errs)
      luassert.are_same(warnings, {})
   end)

   it("should warn on unknown keys", function()
      local c = {
         uhhhhh = "wat",
      }
      local res, errs, warnings = config.is_config(c)
      luassert.are_same({}, res)
      luassert.is_nil(errs)
      luassert.are_same(warnings, { "Unknown key 'uhhhhh'" })
   end)

   it("should error on absolute paths for include_dir", function()
      local c = {
         include_dir = {
            "a", "b",
            "/foo/bar",
            "c",
            "/",
         },
      }
      local res, errs, warnings = config.is_config(c)
      luassert.is_nil(res)
      luassert.are_same(errs, {
         "Expected a non-absolute path for 3rd include_dir entry, got /foo/bar",
         "Expected a non-absolute path for 5th include_dir entry, got /",
      })
      luassert.are_same(warnings, {})
   end)

   it("should error on absolute paths for source_dir", function()
      local c = { source_dir = "/a" }
      local res, errs, warnings = config.is_config(c)
      luassert.is_nil(res)
      luassert.are_same(errs, { "Expected a non-absolute path for source_dir, got /a" })
      luassert.are_same(warnings, {})
   end)

   it("should error on absolute paths for build_dir", function()
      local c = { build_dir = "/b" }
      local res, errs, warnings = config.is_config(c)
      luassert.is_nil(res)
      luassert.are_same(errs, { "Expected a non-absolute path for build_dir, got /b" })
      luassert.are_same(warnings, {})
   end)

   describe("Paths traversing outside of the current directory", function()
      it("should error when source_dir traverses outside of the current directory", function()
         local c = { source_dir = "../foo/bar" }
         local res, errs, warnings = config.is_config(c)
         luassert.is_nil(res)
         luassert.are_same(errs, { "Expected source_dir to not go outside the directory of tlconfig.lua, got ../foo/bar" })
         luassert.are_same(warnings, {})
      end)

      it("should error when build_dir traverses outside of the current directory", function()
         local c = { build_dir = "../../" }
         local res, errs, warnings = config.is_config(c)
         luassert.is_nil(res)
         luassert.are_same(errs, { "Expected build_dir to not go outside the directory of tlconfig.lua, got ../.." })
         luassert.are_same(warnings, {})
      end)

      it("should error when include_dir entries traverse outside of the current directory", function()
         local c = { include_dir = {
            "../../",
            "..",
            "a/b",
         }, }
         local res, errs, warnings = config.is_config(c)
         luassert.is_nil(res)
         luassert.are_same(errs, {
            "Expected 1st include_dir entry to not go outside the directory of tlconfig.lua, got ../..",
            "Expected 2nd include_dir entry to not go outside the directory of tlconfig.lua, got ..",
         })
         luassert.are_same(warnings, {})
      end)
   end)
end)
