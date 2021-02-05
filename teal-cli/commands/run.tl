
local tl <const> = require("tl")
local argparse <const> = require("argparse")
local log <const> = require("teal-cli.log")
local command <const> = require("teal-cli.command")
local common <const> = require("teal-cli.tlcommon")
local sandbox <const> = require("teal-cli.sandbox")

local all_args: argparse.Args
local function add_to_argparser(cmd: argparse.Command)
   cmd:argument("script", "The Teal script to run.")
      :args("+")
      :action(function(args: argparse.Args, k: string, v: {string})
         all_args = args
         all_args[k] = v
      end)
end

local function run(): number
   local _cfg <const> = common.load_config_report_errs("tlconfig.lua")

   local arg_list = all_args["script"] as {string}
   -- collect all non-arguments including negative arg values
   local neg_arg = {}
   local nargs = #arg_list
   local j = #arg
   local p = nargs
   local n = 1
   while arg[j] do
      if arg[j] == arg_list[p] then
         p = p - 1
      else
         neg_arg[n] = arg[j]
         n = n + 1
      end
      j = j - 1
   end

   -- shift back all non-arguments to negative positions
   for p2, a in ipairs(neg_arg) do
      arg[-p2] = a
   end
   -- put script in arg[0] and arguments in positive positions
   for p2, a in ipairs(arg_list) do
      arg[p2 - 1] = a
   end
   -- cleanup the rest
   n = nargs
   while arg[n] do
      arg[n] = nil
      n = n + 1
   end

   local chunk <const>, err <const> = common.type_check_and_load_file(arg_list[1])
   if not chunk then
      print(chunk, err)
      return 1
   end

   tl.loader()
   local box <const> = sandbox.new(function()
      chunk(table.unpack(arg))
   end)
   local ok, err = box:run(1e9)
   if ok then
      return 0
   else
      log.err("Error in script:\n" .. err)
      return 1
   end
end

command.new{
   name = "run",
   description = [[Run a Teal script.]],
   exec = run,
   argparse = add_to_argparser,
}
