
-- Check and gen basically do the same thing, gen just goes a step further and writes to some files
-- so to avoid writing the same file twice, just implement them both here

local argparse <const> = require("argparse")

local common <const> = require("teal-cli.tlcommon")
local command <const> = require("teal-cli.command")
local cs <const> = require("teal-cli.colorstring")
local log <const> = require("teal-cli.log")
local fs <const> = require("teal-cli.fs")
local util <const> = require("teal-cli.util")

local ivalues <const> = util.tab.ivalues

local function add_to_argparser(cmd: argparse.Command)
   cmd:argument("files", "The Teal source files to process.")
      :args("+")
end

local function get_output_filename(path: string): string
   local base, ext = fs.extension_split(path)
   if ext == ".lua" then
      return base .. ".out.lua"
   else
      return base .. ".lua"
   end
end

local function command_exec(should_compile: boolean): function(command.Command.Args): number
   return function(args: command.Command.Args): number
      local _, _loaded_config <const>, env <const> = common.load_and_init_env(false, "tlconfig.lua", args)

      local files <const> = args.files

      local exit = 0

      for path in ivalues(files) do
         local disp_file <const> = cs.new(cs.colors.file, path, 0)
         local parsed <const>, perr <const> = common.parse_file(path)
         if perr then
            log.err("Error parsing file ", disp_file .. "\n   " .. perr)
            exit = 1
         elseif #parsed.errs > 0 then
            common.report_errors(log.err, parsed.errs, path, "syntax error")
            exit = 1
         else
            local result <const> = common.parse_result_to_tl_result(parsed)
            common.type_check_ast(parsed.ast, {
               filename = path,
               env = env,
               result = result,
            })
            if not common.report_result(path, result) then
               exit = 1
            else
               log.info("Type checked ", cs.new(cs.colors.file, path, 0))
               if should_compile then
                  local outfile <const> = get_output_filename(path)
                  local disp_outfile <const> = cs.new(cs.colors.file, outfile, 0)
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
            end
         end
      end

      return exit
   end
end

command.new{
   name = "check",
   description = [[Type check any number of Teal files.]],
   argparse = add_to_argparser,
   exec = command_exec(false),
}

command.new{
   name = "gen",
   description = [[Type check, then compile any number of Teal files into Lua files.]],
   argparse = add_to_argparser,
   exec = command_exec(true),
}

