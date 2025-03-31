

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
end)
