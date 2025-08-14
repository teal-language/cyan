---@nodoc

-- create some directories and a tlconfig.lua pointing at those directories

local argparse <const> = require("argparse")

local command <const> = require("cyan.command")
local config <const> = require("cyan.config")
local decoration <const> = require("cyan.decoration")
local fs <const> = require("cyan.fs")
local invocation_context <const> = require("cyan.invocation-context")
local lexical_path <const> = require("lexical-path")
local log <const> = require("cyan.log")
local util <const> = require("cyan.util")

local ivalues <const> = util.tab.ivalues

local function exec(args: command.Args, loaded_config: config.Config, context: invocation_context.InvocationContext): integer
   if not args.force and loaded_config.loaded_from then
         log.err(
            "Already in a project!\n   Found config file at ",
            decoration.file_name((assert(loaded_config.loaded_from:relative_to(context.initial_directory))))
         )
         return 1
   end

   -- TODO: #ConfigPaths
   local directory <const> = lexical_path.from_os(args.directory or ".")
   local source <const> = lexical_path.from_os(args.source_dir or "src")
   local build <const> = lexical_path.from_os(args.build_dir or "build")

   if source.is_absolute then
      log.err("Source directory should not be absolute (", decoration.file_name(source), ")")
      return 1
   end
   if build.is_absolute then
      log.err("Build directory should not be absolute (", decoration.file_name(build), ")")
      return 1
   end

   local function try_mkdir(p: lexical_path.Path): boolean
      if fs.exists(p) then
         if not fs.is_directory(p) then
            log.err(decoration.file_name(p), " exists and is not a directory")
            return false
         end
      else
         local ok, err = fs.make_directory(p)
         if ok then
            log.info("Created directory ", decoration.file_name(p))
            return true
         end
         log.err("Unable to create directory ", decoration.file_name(p), ":\n   ", err)
         return false
      end
      return true
   end

   for p in ivalues{directory, directory .. source, directory .. build} do
      if not try_mkdir(p) then
         return 1
      end
   end

   local indent <const> = "   "
   local config_content <const> = { "return {\n" }
   local function ins(indentation: integer, s: string, ...: any)
      table.insert(config_content, indent:rep(indentation))
      table.insert(config_content, string.format(s, ...))
   end

   ins(1, "build_dir = %q,\n", build:to_string("/"))
   ins(1, "source_dir = %q,\n", source:to_string("/"))
   local function add_str_array(name: string, arr: {string})
      if #arr == 0 then
         return
      end
      ins(1, "%s = {\n", name)
      for entry in ivalues(arr) do
         ins(2, "%q,\n", entry)
      end
      ins(1, "},\n", name)
   end
   add_str_array("include_dir", args.include_dir)
   add_str_array("disable_warnings", args.wdisable)
   add_str_array("warning_error", args.werror)

   ins(0, "}")

   local config_path <const> = directory .. config.filename
   local fh <const>, err <const> = io.open(config_path:to_string(), "w")
   if not fh then
      log.err("Unable to open ", decoration.file_name(config_path), ":\n", err)
      return 1
   end
   fh:write(table.concat(config_content))
   fh:close()
   log.info("Wrote ", decoration.file_name(config_path))

   return 0
end

command.new{
   name = "init",
   exec = exec,
   description = [[Initialize a Teal project.]],
   argparse = function(cmd: argparse.Command)
      cmd:argument("directory", "The name of the directory of the new project, defaults to current directory.")
         :args("?")

      cmd:option("-s --source-dir", "The name of the source directory.")
         :args(1)

      cmd:option("-b --build-dir", "The name of the build directory.")
         :args(1)

      cmd:option("-f --force", "Force initialization, even if you are in a subdirectory of an existing project.")
         :args(0)
   end,
}
