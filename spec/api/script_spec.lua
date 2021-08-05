local util = require("spec.util")
local script = require("cyan.script")

describe("script", function()
   describe("load", function()
      it("should load a script from a given path", function()
         local dirname = util.write_tmp_dir(finally, {
            ["foo.lua"] = [[print("foo")]],
         })
         local ok, err = script.load(dirname .. util.path_sep .. "foo.lua", {})
         assert.truthy(ok)
         assert.is_nil(err)
      end)
      it("should return nil, err if a script couldn't be loaded", function()
         local ok, err = script.load("foo.lua", {})
         assert.falsy(ok)
         assert.is.string(err)
      end)
      it("should report when a .tl script has type errors", function()
         local scriptname = "foo.tl"
         local dirname = util.write_tmp_dir(finally, {
            [scriptname] = [[local x: integer = 1.2]],
         })
         local ok, err = script.load(dirname .. util.path_sep .. scriptname, {})
         assert.falsy(ok)
         assert.is.table(err)
      end)
   end)
end)
