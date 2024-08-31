local _tl_compat; if (tonumber((_VERSION or ''):match('[%d.]*$')) or 0) < 5.3 then local p, m = true, require('compat53.module'); if p then _tl_compat = m end end; local pairs = _tl_compat and _tl_compat.pairs or pairs; local string = _tl_compat and _tl_compat.string or string
local luassert = require("luassert")
local tl = require("tl")
local command_runners = require("testing.command-runners")

describe("warnings command", function()
   it("should display all warnings the compiler can generate (and display them only once)", function()
      local out, exit_code = command_runners.run_command(command_runners.cyan_command("warnings"))
      luassert.are_equal(exit_code, 0)
      luassert(out)
      local kinds = {}
      for k, v in pairs(tl.warning_kinds) do
         kinds[k] = v
      end
      for ln in out:gmatch("[^\r\n]+") do
         local warning_name = ln:match("(%w+):")
         luassert(warning_name)
         luassert(kinds[warning_name])
         kinds[warning_name] = nil
      end
      luassert.is_nil((next(kinds)))
   end)

   it("should show all warnings as disabled with '--wdisable all'", function()
      local out, exit_code = command_runners.run_command(command_runners.cyan_command("warnings", "--wdisable", "all"))
      luassert.are_equal(exit_code, 0)
      luassert(out)
      local kinds = {}
      for k, v in pairs(tl.warning_kinds) do
         kinds[k] = v
      end
      for ln in out:gmatch("[^\r\n]+") do
         local warning_name = ln:match("(%w+):")
         luassert(warning_name)
         luassert(kinds[warning_name])
         luassert(ln:match("disabled"))
         kinds[warning_name] = nil
      end
      luassert.is_nil((next(kinds)))
   end)

   it("should show all warnings as errors with '--werror all'", function()
      local out, exit_code = command_runners.run_command(command_runners.cyan_command("warnings", "--werror", "all"))
      luassert.are_equal(exit_code, 0)
      luassert(out)
      local kinds = {}
      for k, v in pairs(tl.warning_kinds) do
         kinds[k] = v
      end
      for ln in out:gmatch("[^\r\n]+") do
         local warning_name = ln:match("(%w+):")
         luassert(warning_name)
         luassert(kinds[warning_name])
         luassert(ln:match("as error"))
         kinds[warning_name] = nil
      end
      luassert.is_nil((next(kinds)))
   end)
end)
