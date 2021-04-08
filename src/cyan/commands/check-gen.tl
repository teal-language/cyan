
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

local function command_exec(should_compile: boolean): function(command.Args): integer
   return function(args: command.Args): integer
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

      local function get_output_filename(path: fs.Path): fs.Path
         if args["output"] then
            local p <const> = fs.path.new(args["output"] as string, true)
            if not p:is_absolute() then
               p:prepend(starting_dir)
            end
            return p
         end
         local new <const> = path:copy()
         local base <const>, ext <const> = fs.extension_split(path[#path])
         if ext == ".lua" then
            new[#new] = base .. ".out.lua"
         else
            new[#new] = base .. ".lua"
         end
         return new
      end

      local _, loaded_config <const>, env <const> = common.load_cfg_env_report_errs(false, args)

      local exit = 0

      local to_write <const> = {}
      local function process_file(path: fs.Path)
         local disp_file <const> = cs.new(cs.colors.file, path:relative_to(starting_dir), {0})
         if not path:is_file() then
            log.err(disp_file, " is not a file")
            exit = 1
            return
         end

         local real_path <const> = path:to_real_path()
         local outfile <const> = get_output_filename(path)
         local disp_outfile <const> = cs.new(cs.colors.file, outfile:relative_to(starting_dir), {0})

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
         local result <const> = common.type_check_ast(parsed.ast, {
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

      local function fix_path(f: string): fs.Path
         local p <const> = fs.path.new(f, true)
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

      if not common.report_env_results(env, loaded_config) then
         exit = 1
      end

      if should_compile then
         if exit ~= 0 then return exit end

         for _, data in ipairs(to_write) do
            local fh <const>, err <const> = io.open(data.outfile:to_real_path(), "w")
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

