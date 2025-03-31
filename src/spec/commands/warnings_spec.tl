local type _ = require("busted")
local luassert <const> = require("luassert")
local tl <const> = require("tl")
local command_runners <const> = require("testing.command-runners")
-- commands shouldn't be run within in cyan's directory tree as its own config may interfere
-- TODO: non-unixy temp dir
local temp_dir <const> = "/tmp"

describe("warnings command", function()
   it("should display all warnings the compiler can generate (and display them only once)", function()
      local out <const>, exit_code <const> = command_runners.run_command(command_runners.cyan_command("warnings"), temp_dir)
      if exit_code then
         luassert.are_equal(0, exit_code)
      end
      luassert(out)
      local kinds: {string:boolean} = {}
      for k, v in pairs(tl.warning_kinds) do
         kinds[k] = v
      end
      for ln in out:gmatch("[^\r\n]+") do
         local warning_name = ln:match("(%w+):")
         luassert(warning_name)
         luassert(kinds[warning_name])
         kinds[warning_name] = nil
      end
      luassert.is_nil((next(kinds)) as any)
   end)

   it("should show all warnings as disabled with '--wdisable all'", function()
      local out <const>, exit_code <const> = command_runners.run_command(command_runners.cyan_command("warnings", "--wdisable", "all"), temp_dir)
      if exit_code then
         luassert.are_equal(0, exit_code)
      end
      luassert(out)
      local kinds: {string:boolean} = {}
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
      luassert.is_nil((next(kinds)) as any)
   end)

   it("should show all warnings as errors with '--werror all'", function()
      local out <const>, exit_code <const> = command_runners.run_command(command_runners.cyan_command("warnings", "--werror", "all"), temp_dir)
      if exit_code then
         luassert.are_equal(0, exit_code)
      end
      luassert(out)
      local kinds: {string:any} = {}
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
      luassert.is_nil((next(kinds)) as any)
   end)
end)
