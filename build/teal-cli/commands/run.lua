local _tl_compat; if (tonumber((_VERSION or ''):match('[%d.]*$')) or 0) < 5.3 then local p, m = pcall(require, 'compat53.module'); if p then _tl_compat = m end end; local ipairs = _tl_compat and _tl_compat.ipairs or ipairs; local table = _tl_compat and _tl_compat.table or table; local _tl_table_unpack = unpack or table.unpack
local tl = require("tl")
local argparse = require("argparse")
local log = require("teal-cli.log")
local command = require("teal-cli.command")
local common = require("teal-cli.tlcommon")
local sandbox = require("teal-cli.sandbox")

local all_args
local function add_to_argparser(cmd)
   cmd:argument("script", "The Teal script to run."):
   args("+"):
   action(function(args, k, v)
      all_args = args
      all_args[k] = v
   end)
end

local function run()
   local _cfg = common.load_config_report_errs("tlconfig.lua")

   local arg_list = all_args["script"]

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

   local chunk, err = common.type_check_and_load_file(arg_list[1])
   if not chunk then
      return 1
   end

   tl.loader()
   local box = sandbox.new(function()
      chunk(_tl_table_unpack(arg))
   end)

   local ok, err = box:run(1e9)
   if ok then
      return 0
   else
      log.err("Error in script:\n" .. err)
      return 1
   end
end

command.new({
   name = "run",
   description = [[Run a Teal script.]],
   exec = run,
   argparse = add_to_argparser,
})
