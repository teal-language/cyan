
local luassert = require("luassert")
local temporary_files = require("testing.temporary-files")
local script = require("cyan.script")

describe("script", function()
   describe("load", function()
      it("should load a script from a given path", function()
         temporary_files.do_in(temporary_files.write_directory(finally, {
            ["foo.lua"] = [[print("foo")]],
         }), function()
            script.register("foo.lua", "build", "pre")
            local ok, err = script.ensure_loaded_for_command("build")
            luassert.truthy(ok)
            luassert.is_nil(err)
         end)
      end)
      it("should return nil, err if a script couldn't be loaded", function()
         script.register("bar.lua", "check", "pre")
         local ok, err = script.ensure_loaded_for_command("check")
         luassert.falsy(ok)
         luassert.is_string(err)
      end)
      it("should report when a .tl script has type errors", function()
         local scriptname = "foo.tl"
         temporary_files.do_in(temporary_files.write_directory(finally, {
            [scriptname] = [[local x: integer = 1.2]],
         }), function()
            script.register(scriptname, "run", "pre")
            local ok, err = script.ensure_loaded_for_command("run")
            luassert.falsy(ok)
            luassert.is_true(
            type(err) == "string" or
            type(err) == "table")

         end)
      end)
   end)
end)
