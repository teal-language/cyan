local _tl_compat; if (tonumber((_VERSION or ''):match('[%d.]*$')) or 0) < 5.3 then local p, m = pcall(require, 'compat53.module'); if p then _tl_compat = m end end; local io = _tl_compat and _tl_compat.io or io



local argparse = require("argparse")

local common = require("teal-cli.tlcommon")
local command = require("teal-cli.command")
local cs = require("teal-cli.colorstring")
local log = require("teal-cli.log")
local fs = require("teal-cli.fs")
local util = require("teal-cli.util")

local map_ipairs = util.tab.map_ipairs

local function add_to_argparser(cmd)
   cmd:argument("files", "The Teal source files to process."):
   args("+")
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
   return function(args)
      local _, _loaded_config, env = common.load_and_init_env(false, "tlconfig.lua", args)

      local files = args.files

      local exit = 0

      local function process_file(path)
         local real_path = path:to_real_path()
         local disp_file = cs.new(cs.colors.file, real_path, { 0 })

         local outfile = get_output_filename(real_path)
         local disp_outfile = cs.new(cs.colors.file, outfile, { 0 })

         if not path:is_file() then
            log.err(disp_file, " is not a file")
            exit = 1
            return
         end
         local parsed, perr = common.parse_file(real_path)
         if not parsed then
            log.err("Error parsing file ", disp_file .. "\n   " .. tostring(perr))
            exit = 1
            return
         end
         if #parsed.errs > 0 then
            common.report_errors(log.err, parsed.errs, real_path, "syntax error")
            exit = 1
            return
         end
         local result = common.parse_result_to_tl_result(parsed)
         common.type_check_ast(parsed.ast, {
            filename = real_path,
            env = env,
            result = result,
         })
         if not common.report_result(real_path, result) then
            exit = 1
            return
         end
         log.info("Type checked ", disp_file)
         if should_compile then
            local fh, err = io.open(outfile, "w")
            if fh then
               fh:write(common.compile_ast(parsed.ast))
               fh:close()
               log.info("Wrote ", disp_outfile)
            else
               log.err("Unable to write to ", disp_outfile, "\n", err)
               exit = 1
            end
         end
      end

      for _, path in map_ipairs(files, fs.path.new) do
         process_file(path)
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