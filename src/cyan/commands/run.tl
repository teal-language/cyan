---@nodoc
local tl <const> = require("tl")
local argparse <const> = require("argparse")
local log <const> = require("cyan.log")

local config <const> = require("cyan.config")
local command <const> = require("cyan.command")
local common <const> = require("cyan.tlcommon")
local sandbox <const> = require("cyan.sandbox")

local function add_to_argparser(cmd: argparse.Command)
   cmd:argument("script", "The Teal script to run.")
      :args("+")
end

local function run(args: command.Args, loaded_config: config.Config): integer
   local env <const>, env_err <const> = common.init_env_from_config(loaded_config)
   if not env then
      log.err("Could not initialize Teal environment:\n", env_err)
      return 1
   end

   local arg_list <const> = args["script"] as {string}
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

   local chunk <const>, load_err <const> = common.type_check_and_load_file(arg_list[1], env, loaded_config)
   if not chunk then
      log.err("Error loading file", load_err and "\n   " .. load_err or "")
      return 1
   end

   tl.loader()
   local box <const> = sandbox.new(function()
      chunk(table.unpack(arg))
   end)

   local ok <const>, err <const> = box:run(1000000000)
   if ok then
      return 0
   else
      log.err("Error in script:\n", err)
      return 1
   end
end

command.new{
   name = "run",
   description = [[Run a Teal script.]],
   exec = run,
   argparse = add_to_argparser,
}
