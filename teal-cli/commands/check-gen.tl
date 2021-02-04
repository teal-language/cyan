
-- Check and gen basically do the same thing, gen just goes a step further and writes to some files
-- so to avoid writing the same file twice, just implement them both here

local tl <const> = require("tl")
local argparse <const> = require("argparse")

local common <const> = require("teal-cli.tlcommon")
local command <const> = require("teal-cli.command")
local cs <const> = require("teal-cli.colorstring")
local log <const> = require("teal-cli.log")
local fs <const> = require("teal-cli.fs")
local util <const> = require("teal-cli.util")
local config <const> = require("teal-cli.config")

local files: {string} = {}
local function add_to_argparser(cmd: argparse.Command)
   cmd:argument("files", "The Teal source files to process.")
      :args("+")
      :action(function(_: {string:string|boolean|{string}}, _name: string, fs: {string})
         files = fs
      end)
end

local function get_output_filename(path: string): string
   local base, ext = fs.extension_split(path)
   if ext == ".lua" then
      return base .. ".out.lua"
   else
      return base .. ".lua"
   end
end

local function command_exec(should_compile: boolean): function(): number
   return function(): number
      local loaded_config <const>, conferr <const> = config.load("tlconfig.lua")
      print(conferr)
      if conferr and not conferr[1]:match("No such file or directory$") then
         log.err("Unable to load config:\n   " .. table.concat(conferr, "\n   "))
         return 1
      end

      local env <const> = common.init_teal_env()
      local exit = 0

      for _, path in ipairs(files) do
         local parsed <const> = common.parse_file(path)
         if #parsed.errs > 0 then
            common.report_errors(log.err, parsed.errs, path, "syntax error")
            exit = 1
         else
            local result <const> = common.parse_result_to_tl_result(parsed)
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
                  local outfile <const> = get_output_filename(path)
                  local disp_outfile <const> = cs.new(cs.colors.file, outfile, 0)
                  local fh <const>, err <const> = io.open(outfile, "w")
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

