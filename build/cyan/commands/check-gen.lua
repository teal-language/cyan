local _tl_compat; if (tonumber((_VERSION or ''):match('[%d.]*$')) or 0) < 5.3 then local p, m = true, require('compat53.module'); if p then _tl_compat = m end end; local assert = _tl_compat and _tl_compat.assert or assert; local io = _tl_compat and _tl_compat.io or io; local string = _tl_compat and _tl_compat.string or string; local table = _tl_compat and _tl_compat.table or table




local argparse = require("argparse")

local command = require("cyan.command")
local common = require("cyan.tlcommon")
local config = require("cyan.config")
local decoration = require("cyan.decoration")
local fs = require("cyan.fs")
local invocation_context = require("cyan.invocation-context")
local lexical_path = require("lexical-path")
local log = require("cyan.log")
local tl = require("tl")
local util = require("cyan.util")

local map_ipairs, ivalues =
util.tab.map_ipairs, util.tab.ivalues

local function command_exec(should_compile)
   return function(args, loaded_config, context)
      if args["output"] and #args.files ~= 1 then
         log.err("--output can only map 1 input to 1 output")
         return 1
      end

      local function get_output_filename(path)
         if args["output"] then
            local p = lexical_path.from_os(args["output"])
            if not p.is_absolute then
               p = context.initial_directory .. p
            end
            return p
         end
         local new = path:copy()
         local ext = path:extension():lower()
         if ext == "lua" then
            new[#new] = new[#new]:sub(1, -#ext - 2) .. ".out.lua"
         else
            new[#new] = new[#new]:sub(1, -#ext - 2) .. ".lua"
         end
         return new
      end

      local env, env_err = common.init_env_from_config(loaded_config)
      if not env then
         log.err("Could not initialize Teal environment:\n", env_err)
         return 1
      end

      local exit = 0

      local current_dir = fs.current_directory()
      local function ensure_abs_path(p)
         if p.is_absolute then return p end
         return current_dir .. p
      end
      local to_write = {}
      local function process_file(path)
         local disp_file = decoration.file_name(assert(ensure_abs_path(path):relative_to(context.initial_directory)))
         if not fs.is_file(path) then
            log.err(disp_file, " is not a file")
            exit = 1
            return
         end

         local real_path = path:to_string()
         local outfile = get_output_filename(path)
         local disp_outfile = decoration.file_name((assert(ensure_abs_path(outfile):relative_to(context.initial_directory))))

         local parsed, perr = common.parse_file(real_path)
         if not parsed then
            log.err("Error parsing file ", disp_file, "\n   ", tostring(perr))
            exit = 1
            return
         end
         if #parsed.errs > 0 then
            log.debug(parsed.errs, "\n", real_path)
            common.report_errors(log.err, parsed.errs, real_path, "syntax error")
            exit = 1
            return
         end

         local result, err = tl.check(parsed.ast, real_path, {

            feat_lax = "off",
            feat_arity = loaded_config.feat_arity,

            gen_compat = loaded_config.gen_compat,
            gen_target = loaded_config.gen_target,
         }, env)
         if not result then
            log.err("Could not type check ", disp_file, ":\n   ", err)
            exit = 1
            return
         end
         if common.result_has_errors(result, loaded_config) then
            exit = 1
            return
         end
         log.info("Type checked ", disp_file)
         if not should_compile then
            return
         end
         table.insert(to_write, {
            outfile = outfile,
            disp_outfile = disp_outfile,
            output_ast = parsed.ast,
         })
      end

      local function fix_path(f)
         local p = lexical_path.from_os(f)
         if not p.is_absolute then
            p = assert((context.initial_directory .. p):relative_to(current_dir))
         end
         return p
      end

      for _, path in map_ipairs(args.files, fix_path) do
         process_file(path)
      end

      if not common.report_env_results(env, loaded_config) then
         exit = 1
      end

      if should_compile then
         if exit ~= 0 then return exit end

         for data in ivalues(to_write) do
            local fh, err = io.open(data.outfile:to_string(), "w")
            if fh then
               local generated, gen_err = tl.generate(data.output_ast, loaded_config.gen_target)
               if generated then
                  fh:write(generated, "\n")
                  fh:close()
                  log.info("Wrote ", data.disp_outfile)
               else
                  log.err("Error when generating lua for ", data.disp_outfile, "\n", gen_err)
                  exit = 1
               end
            else
               log.err("Unable to write to ", data.disp_outfile, "\n", err)
               exit = 1
            end
         end
      end

      return exit
   end
end

command.new({
   name = "check",
   description = [[Type check any number of Teal files.]],
   argparse = function(cmd)
      cmd:argument("files", "The Teal source files to process."):
      args("+")
   end,
   exec = command_exec(false),
})

command.new({
   name = "gen",
   description = [[Type check, then compile any number of Teal files into Lua files.]],
   argparse = function(cmd)
      cmd:argument("files", "The Teal source files to process."):
      args("+")

      cmd:option("-o --output", "The name of the output file"):
      args(1)
   end,
   exec = command_exec(true),
})
