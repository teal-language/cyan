local tl = require("tl")
local util = require("spec.util")

describe("warnings command", function()
   it("should display all warnings the compiler can generate (and display them only once)", function()
      local out = util.run_command(util.cyan_cmd("warnings"))
      assert(out)
      local kinds = {}
      for k, v in pairs(tl.warning_kinds) do
         kinds[k] = v
      end
      for ln in out:gmatch("[^\r\n]+") do
         local warning_name = ln:match("(%w+):")
         assert(warning_name)
         assert(kinds[warning_name])
         kinds[warning_name] = nil
      end
      assert.is["nil"](next(kinds))
   end)

   it("should show all warnings as disabled with '--wdisable all'", function()
      local out = util.run_command(util.cyan_cmd("warnings", "--wdisable", "all"))
      assert(out)
      local kinds = {}
      for k, v in pairs(tl.warning_kinds) do
         kinds[k] = v
      end
      for ln in out:gmatch("[^\r\n]+") do
         local warning_name = ln:match("(%w+):")
         assert(warning_name)
         assert(kinds[warning_name])
         assert(ln:match("disabled"))
         kinds[warning_name] = nil
      end
      assert.is["nil"](next(kinds))
   end)

   it("should show all warnings as errors with '--werror all'", function()
      local out = util.run_command(util.cyan_cmd("warnings", "--werror", "all"))
      assert(out)
      local kinds = {}
      for k, v in pairs(tl.warning_kinds) do
         kinds[k] = v
      end
      for ln in out:gmatch("[^\r\n]+") do
         local warning_name = ln:match("(%w+):")
         assert(warning_name)
         assert(kinds[warning_name])
         assert(ln:match("as error"))
         kinds[warning_name] = nil
      end
      assert.is["nil"](next(kinds))
   end)
end)
