local util = require("spec.util")
local script = require("cyan.script")

describe("script", function()
   describe("load", function()
      it("should load a script from a given path", function()
         util.do_in(util.write_tmp_dir(finally, {
            ["foo.lua"] = [[print("foo")]],
         }), function()
            script.register("foo.lua", "build", "pre")
            local ok, err = script.ensure_loaded_for_command("build")
            assert.truthy(ok)
            assert.is_nil(err)
         end)
      end)
      it("should return nil, err if a script couldn't be loaded", function()
         script.register("bar.lua", "check", "pre")
         local ok, err = script.ensure_loaded_for_command("check")
         assert.falsy(ok)
         assert.is.string(err)
      end)
      it("should report when a .tl script has type errors", function()
         local scriptname = "foo.tl"
         util.do_in(util.write_tmp_dir(finally, {
            [scriptname] = [[local x: integer = 1.2]],
         }), function()
            script.register(scriptname, "run", "pre")
            local ok, err = script.ensure_loaded_for_command("run")
            assert.falsy(ok)
            assert.is.table(err)
         end)
      end)
   end)
end)
