local _tl_compat; if (tonumber((_VERSION or ''):match('[%d.]*$')) or 0) < 5.3 then local p, m = pcall(require, 'compat53.module'); if p then _tl_compat = m end end; local io = _tl_compat and _tl_compat.io or io; local table = _tl_compat and _tl_compat.table or table



local argparse = require("argparse")
local lfs = require("lfs")

local config = require("charon.config")
local common = require("charon.tlcommon")
local command = require("charon.command")
local cs = require("charon.colorstring")
local log = require("charon.log")
local fs = require("charon.fs")
local util = require("charon.util")

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
      local starting_dir = fs.current_dir()
      local config_path = fs.search_parent_dirs(lfs.currentdir(), config.filename)
      local root_dir
      if config_path then
         root_dir = config_path:copy()
         table.remove(root_dir)
         if not lfs.chdir(root_dir:to_real_path()) then
            log.err("Unable to chdir into root directory ", cs.highlight(cs.colors.file, root_dir:to_real_path()))
            return 1
         end
      end

      local _, _loaded_config, env = common.load_and_init_env(false, config.filename, args)

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
         if not should_compile then
            return
         end
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

      local function fix_path(f)
         local p = fs.path.new(f)
         if config_path then
            if not p:is_absolute() then
               p:prepend(starting_dir)
               p:remove_leading(root_dir)
            end
         end
         return p
      end

      for _, path in map_ipairs(args.files, fix_path) do
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