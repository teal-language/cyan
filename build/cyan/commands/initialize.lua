local _tl_compat; if (tonumber((_VERSION or ''):match('[%d.]*$')) or 0) < 5.3 then local p, m = pcall(require, 'compat53.module'); if p then _tl_compat = m end end; local io = _tl_compat and _tl_compat.io or io; local ipairs = _tl_compat and _tl_compat.ipairs or ipairs; local string = _tl_compat and _tl_compat.string or string; local table = _tl_compat and _tl_compat.table or table


local argparse = require("argparse")

local command = require("cyan.command")
local config = require("cyan.config")
local fs = require("cyan.fs")
local log = require("cyan.log")

local function exec(args)
   local directory = fs.path.new(args.directory or "./")
   local source = fs.path.new(args.source_dir or "src")
   local build = fs.path.new(args.build_dir or "build")

   if source:is_absolute() then
      log.err("Source directory should not be absolute (", source:to_real_path(), ")")
      return 1
   end
   if build:is_absolute() then
      log.err("Build directory should not be absolute (", build:to_real_path(), ")")
      return 1
   end

   local function try_mkdir(p)
      if p:exists() then
         if not p:is_directory() then
            log.err(p:to_real_path(), " exists and is not a directory")
            return false
         end
      else
         local ok, err = p:mkdir()
         if ok then
            log.info("Created directory ", p:to_real_path())
            return true
         else
            log.err("Unable to create directory ", p:to_real_path(), ":\n   ", err)
            return false
         end
      end
      return true
   end

   for _, p in ipairs({ directory, directory .. source, directory .. build }) do
      if not try_mkdir(p) then
         return 1
      end
   end

   local indent = "   "
   local config_content = { "return {\n" }
   local function ins(indentation, s, ...)
      table.insert(config_content, indent:rep(indentation))
      table.insert(config_content, string.format(s, ...))
   end

   ins(1, "source_dir = %q,\n", source:tostring())
   ins(1, "build_dir = %q,\n", build:tostring())
   ins(0, "}")

   local config_path = (directory .. config.filename):to_real_path()
   local fh, err = io.open(config_path, "w")
   if not fh then
      log.err("Unable to open ", config_path, ":\n", err)
      return 1
   end
   fh:write(table.concat(config_content))
   fh:close()
   log.info("Wrote ", config_path)

   return 0
end

command.new({
   name = "init",
   exec = exec,
   description = [[Initialize a Teal project.]],
   argparse = function(cmd)
      cmd:argument("directory", "The name of the directory of the new project, defaults to current directory"):
      args("?")

      cmd:option("-s --source-dir", "The name of the source directory."):
      args(1)

      cmd:option("-b --build-dir", "The name of the build directory."):
      args(1)
   end,
})