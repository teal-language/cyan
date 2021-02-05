local _tl_compat; if (tonumber((_VERSION or ''):match('[%d.]*$')) or 0) < 5.3 then local p, m = pcall(require, 'compat53.module'); if p then _tl_compat = m end end; local io = _tl_compat and _tl_compat.io or io; local ipairs = _tl_compat and _tl_compat.ipairs or ipairs; local string = _tl_compat and _tl_compat.string or string; local table = _tl_compat and _tl_compat.table or table



local tl = require("tl")
local argparse = require("argparse")

local common = require("teal-cli.tlcommon")
local command = require("teal-cli.command")
local cs = require("teal-cli.colorstring")
local log = require("teal-cli.log")
local fs = require("teal-cli.fs")
local util = require("teal-cli.util")
local config = require("teal-cli.config")

local files = {}
local function add_to_argparser(cmd)
   cmd:argument("files", "The Teal source files to process."):
   args("+"):
   action(function(_, _name, fs)
      files = fs
   end)
end

local function get_output_filename(path)
   local base, ext = fs.extension_split(path)
   if ext == ".lua" then
      return base .. ".out.lua"
   else
      return base .. ".lua"
   end
end

local function command_exec(should_compile)
   return function()
      local loaded_config, conferr = config.load("tlconfig.lua")
      if conferr and not conferr[1]:match("No such file or directory$") then
         log.err("Unable to load config:\n   " .. table.concat(conferr, "\n   "))
         return 1
      end

      local env = common.init_teal_env()
      local exit = 0

      for _, path in ipairs(files) do
         local parsed = common.parse_file(path)
         if #parsed.errs > 0 then
            common.report_errors(log.err, parsed.errs, path, "syntax error")
            exit = 1
         else
            local result = common.parse_result_to_tl_result(parsed)
            common.type_check_ast(parsed.ast, {
               filename = path,
               env = env,
               result = result,

               gen_target = loaded_config and loaded_config.gen_target,
               gen_compat = loaded_config and loaded_config.gen_compat,
            })
            if not common.report_result(path, result) then
               exit = 1
            else
               log.info("Type checked", cs.new(cs.colors.file, path, 0))
               if should_compile then
                  local outfile = get_output_filename(path)
                  local disp_outfile = cs.new(cs.colors.file, outfile, 0)
                  local fh, err = io.open(outfile, "w")
                  if fh then
                     fh:write(common.compile_ast(parsed.ast))
                     fh:close()
                     log.info("Wrote", disp_outfile)
                  else
                     log.err("Unable to write to", disp_outfile .. "\n", err)
                     exit = 1
                  end
               end
            end
         end
      end

      return exit
   end
end

command.new({
   name = "check",
   description = [[Type check any number of Teal files.]],
   argparse = add_to_argparser,
   exec = command_exec(false),
})

command.new({
   name = "gen",
   description = [[Type check, then compile any number of Teal files into Lua files.]],
   argparse = add_to_argparser,
   exec = command_exec(true),
})
