
-- Check and gen basically do the same thing, gen just goes a step further and writes to some files
-- so to avoid writing the same file twice, just implement them both here

local argparse <const> = require("argparse")
local lfs <const> = require("lfs")

local config <const> = require("cyan.config")
local common <const> = require("cyan.tlcommon")
local command <const> = require("cyan.command")
local cs <const> = require("cyan.colorstring")
local log <const> = require("cyan.log")
local fs <const> = require("cyan.fs")
local util <const> = require("cyan.util")

local map_ipairs <const> = util.tab.map_ipairs

local function command_exec(should_compile: boolean): function(command.Command.Args): number
   return function(args: command.Command.Args): number
      local starting_dir <const> = fs.current_dir()
      local config_path <const> = fs.search_parent_dirs(lfs.currentdir(), config.filename)
      local root_dir: fs.Path
      if config_path then
         root_dir = config_path:copy()
         table.remove(root_dir)
         if not lfs.chdir(root_dir:to_real_path()) then
            log.err("Unable to chdir into root directory ", cs.highlight(cs.colors.file, root_dir:to_real_path()))
            return 1
         end
      end

      if args["output"] and #args.files ~= 1 then
         log.err("--output can only map 1 input to 1 output")
         return 1
      end

      local function get_output_filename(path: string): string
         if args["output"] then
            local p <const> = fs.path.new(args["output"] as string)
            if not p:is_absolute() then
               p:prepend(starting_dir)
            end
            return p:to_real_path()
         end
         local base, ext = fs.extension_split(path)
         if ext == ".lua" then
            return base .. ".out.lua"
         else
            return base .. ".lua"
         end
      end

      local _, _loaded_config <const>, env <const> = common.load_cfg_env_report_errs(false, args)

      local exit = 0

      local function process_file(path: fs.Path)
         local real_path <const> = path:to_real_path()
         local disp_file <const> = cs.new(cs.colors.file, real_path, {0})

         local outfile <const> = get_output_filename(real_path)
         local disp_outfile <const> = cs.new(cs.colors.file, outfile, {0})

         if not path:is_file() then
            log.err(disp_file, " is not a file")
            exit = 1
            return
         end
         local parsed <const>, perr <const> = common.parse_file(real_path)
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
         local result <const> = common.parse_result_to_tl_result(parsed)
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
         local fh <const>, err <const> = io.open(outfile, "w")
         if fh then
            fh:write(common.compile_ast(parsed.ast))
            fh:close()
            log.info("Wrote ", disp_outfile)
         else
            log.err("Unable to write to ", disp_outfile, "\n", err)
            exit = 1
         end
      end

      local function fix_path(f: string): fs.Path
         local p <const> = fs.path.new(f)
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

command.new{
   name = "check",
   description = [[Type check any number of Teal files.]],
   argparse = function(cmd: argparse.Command)
      cmd:argument("files", "The Teal source files to process.")
         :args("+")
   end,
   exec = command_exec(false),
}

command.new{
   name = "gen",
   description = [[Type check, then compile any number of Teal files into Lua files.]],
   argparse = function(cmd: argparse.Command)
      cmd:argument("files", "The Teal source files to process.")
         :args("+")

      cmd:option("-o --output", "The name of the output file")
         :args(1)
   end,
   exec = command_exec(true),
}

