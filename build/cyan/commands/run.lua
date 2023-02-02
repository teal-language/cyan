local _tl_compat; if (tonumber((_VERSION or ''):match('[%d.]*$')) or 0) < 5.3 then local p, m = true, require('compat53.module'); if p then _tl_compat = m end end; local ipairs = _tl_compat and _tl_compat.ipairs or ipairs; local table = _tl_compat and _tl_compat.table or table; local _tl_table_unpack = unpack or table.unpack
local tl = require("tl")
local argparse = require("argparse")
local log = require("cyan.log")

local config = require("cyan.config")
local command = require("cyan.command")
local common = require("cyan.tlcommon")
local sandbox = require("cyan.sandbox")

local function add_to_argparser(cmd)
   cmd:argument("script", "The Teal script to run."):
   args("+")
end

local function run(args, loaded_config)
   local env, env_err = common.init_env_from_config(loaded_config)
   if not env then
      log.err("Could not initialize Teal environment:\n", env_err)
      return 1
   end

   local arg_list = args["script"]

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


   for p2, a in ipairs(neg_arg) do
      arg[-p2] = a
   end

   for p2, a in ipairs(arg_list) do
      arg[p2 - 1] = a
   end

   n = nargs
   while arg[n] do
      arg[n] = nil
      n = n + 1
   end

   local chunk, load_err = common.type_check_and_load_file(arg_list[1], env, loaded_config)
   if not chunk then
      log.err("Error loading file", load_err and "\n   " .. load_err or "")
      return 1
   end

   tl.loader()
   local box = sandbox.new(function()
      chunk(_tl_table_unpack(arg))
   end)

   local ok, err = box:run(1000000000)
   if ok then
      return 0
   else
      log.err("Error in script:\n", err)
      return 1
   end
end

command.new({
   name = "run",
   description = [[Run a Teal script.]],
   exec = run,
   argparse = add_to_argparser,
})
