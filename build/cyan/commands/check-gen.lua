local _tl_compat; if (tonumber((_VERSION or ''):match('[%d.]*$')) or 0) < 5.3 then local p, m = pcall(require, 'compat53.module'); if p then _tl_compat = m end end; local io = _tl_compat and _tl_compat.io or io; local ipairs = _tl_compat and _tl_compat.ipairs or ipairs; local table = _tl_compat and _tl_compat.table or table



local argparse = require("argparse")

local config = require("cyan.config")
local common = require("cyan.tlcommon")
local command = require("cyan.command")
local cs = require("cyan.colorstring")
local log = require("cyan.log")
local fs = require("cyan.fs")
local util = require("cyan.util")

local map_ipairs = util.tab.map_ipairs

local function command_exec(should_compile)
   return function(args, loaded_config, starting_dir)
      if args["output"] and #args.files ~= 1 then
         log.err("--output can only map 1 input to 1 output")
         return 1
      end

      local function get_output_filename(path)
         if args["output"] then
            local p = fs.path.new(args["output"], true)
            if not p:is_absolute() then
               p:prepend(starting_dir)
            end
            return p
         end
         local new = path:copy()
         local base, ext = fs.extension_split(path[#path])
         if ext == ".lua" then
            new[#new] = base .. ".out.lua"
         else
            new[#new] = base .. ".lua"
         end
         return new
      end

      local env, env_err = common.init_env_from_config(loaded_config)
      if not env then
         log.err("Could not initialize Teal environment:\n", env_err)
      end

      local exit = 0

      local current_dir = fs.cwd()
      local to_write = {}
      local function process_file(path)
         local disp_file = cs.new(cs.colors.file, path:relative_to(starting_dir), { 0 })
         if not path:is_file() then
            log.err(disp_file, " is not a file")
            exit = 1
            return
         end

         local real_path = path:to_real_path()
         local outfile = get_output_filename(path)
         local disp_outfile = cs.new(cs.colors.file, outfile:relative_to(starting_dir), { 0 })

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
         local result = common.type_check_ast(parsed.ast, {
            filename = real_path,
            env = env,
         })
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
         local p = fs.path.new(f, true)
         if not p:is_absolute() then
            p:prepend(starting_dir)
            p:remove_leading(current_dir)
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

         for _, data in ipairs(to_write) do
            local fh, err = io.open(data.outfile:to_real_path(), "w")
            if fh then
               fh:write(common.compile_ast(data.output_ast))
               fh:close()
               log.info("Wrote ", data.disp_outfile)
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