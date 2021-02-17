
local config = require("charon.config")

describe("config loading", function()
   it("should perform some simplistic type checking", function()
      local res, errs, warnings = config.is_config{
         source_dir = 10,
      }
      assert.is["nil"](res)
      assert.are.equal(errs[1], "Expected source_dir to be a string, got number")
      assert.are.same(warnings, {})
   end)

   it("should only check that `externals` is a table, but nothing inside of it", function()
      local c = {
         externals = {
            function() end,
            ["hello"] = 10,
            [{}] = {},
         }
      }
      local res, errs, warnings = config.is_config(c)
      assert.are.equal(c, res)
      assert.is["nil"](errs)
      assert.are.same(warnings, {})
   end)

   it("should warn on unknown keys", function()
      local c = {
         uhhhhh = "wat"
      }
      local res, errs, warnings = config.is_config(c)
      assert.are.equal(c, res)
      assert.is["nil"](errs)
      assert.are.same(warnings, { "Unknown key 'uhhhhh'" })
   end)
end)

