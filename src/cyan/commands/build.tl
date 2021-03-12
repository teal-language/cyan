
local argparse <const> = require("argparse")
local lfs <const> = require("lfs")

local command <const> = require("cyan.command")
local common <const> = require("cyan.tlcommon")
local config <const> = require("cyan.config")
local cs <const> = require("cyan.colorstring")
local fs <const> = require("cyan.fs")
local graph <const> = require("cyan.graph")
local log <const> = require("cyan.log")
local util <const> = require("cyan.util")
local script <const> = require("cyan.script")

local ivalues <const> = util.tab.ivalues

local function exists_and_is_dir(prefix: string, p: fs.Path): boolean
   if not p:exists() then
      log.err(string.format("%s %q does not exist", prefix, p:to_real_path()))
      return false
   elseif not p:is_directory() then
      log.err(string.format("%s %q is not a directory", prefix, p:to_real_path()))
      return false
   end
   return true
end

local function emit_hook(name: string, ...: any): boolean
   local ok <const>, err <const> = script.emit_hook(name, ...)
   if not ok then
      log.err("Error in hook 'build:", name, "':\n   ", err)
      coroutine.yield(1)
   end
   return ok
end

local function build(args: command.Command.Args): number
   local starting_dir <const> = fs.current_dir()
   local config_path <const> = fs.search_parent_dirs(lfs.currentdir(), config.filename)
   if not config_path then
      log.err(config.filename, " not found")
      return 1
   end

   local root_dir <const> = config_path:copy()
   table.remove(root_dir)
   if not lfs.chdir(root_dir:to_real_path()) then
      log.err("Unable to chdir into root directory ", cs.highlight(cs.colors.file, root_dir:to_real_path()))
      return 1
   end

   local cfg_ok <const>, loaded_config <const>, env <const>
      = common.load_cfg_env_report_errs(true, args)

   if not cfg_ok then
      return 1
   end

   local source_dir <const> = fs.path.new(loaded_config.source_dir or "./")
   if not exists_and_is_dir("Source dir", source_dir) then
      return 1
   end

   local build_dir <const> = fs.path.new(loaded_config.build_dir or "./")

   if not build_dir:exists() then
      local succ <const>, err <const> = build_dir:mkdir()
      if not succ then
         log.err(string.format("Failed to create build dir %q: %s", build_dir:to_real_path(), err))
         return 1
      end
   elseif not build_dir:is_directory() then
      log.err(string.format("Build dir %q is not a directory", build_dir:to_real_path()))
      return 1
   end

   if loaded_config.scripts then
      for _, s in ipairs(loaded_config.scripts) do
         local ok, err = script.load(s)
         if not ok then
            log.err("Error loading script '", s, "':\n   ", err)
            return 1
         end
      end
   end

   emit_hook("pre")

   local include <const> = loaded_config.include or {}
   local exclude <const> = loaded_config.exclude or {}

   local dag <const> = graph.scan_dir(source_dir, include, exclude)
   local exit = 0

   local function get_output_name(src: fs.Path): fs.Path
      local out <const> = src:copy()
      out:remove_leading(source_dir)
      out:prepend(build_dir)
      local base <const> = fs.extension_split(out[#out])
      out[#out] = base .. ".lua"
      return out
   end

   local function source_is_newer(src: fs.Path): boolean
      if args.update_all then return true end
      local target <const> = get_output_name(src)
      local in_t <const>, out_t <const> = src:mod_time(), target:mod_time()
      if not out_t then
         return true
      end
      return in_t > out_t
   end

   dag:mark_each(source_is_newer)

   local function display_filename(f: fs.Path): cs.ColorString
      return cs.highlight(cs.colors.file, f:relative_to(starting_dir))
   end

   local to_write <const> = {}
   local function process_node(n: graph.Node, compile: boolean)
      local path <const> = n.input:to_real_path()
      local out <const> = get_output_name(n.input)
      n.output = out
      local parsed <const> = common.parse_file(path)
      if #parsed.errs > 0 then
         common.report_errors(log.err, parsed.errs, path, "syntax error")
         exit = 1
         return
      end

      local result <const> = common.type_check_ast(parsed.ast, {
         filename = path,
         env = env,
      })

      if common.result_has_errors(result, loaded_config) then
         exit = 1
         return
      end

      log.info("Type checked ", display_filename(n.input))
      if compile then
         local ok <const>, err <const> = n.output:mk_parent_dirs()
         if ok then
            table.insert(to_write, {n, parsed.ast})
         else
            log.err("Unable to create parent dirs to ", display_filename(n.output), ":", err)
            exit = 1
         end
      end
   end

   for n in dag:marked_nodes("typecheck") do
      process_node(n, false)
   end

   if exit ~= 0 then
      common.report_env_results(env, loaded_config)
      return exit
   end

   for n in dag:marked_nodes("compile") do
      process_node(n, true)
   end

   if exit ~= 0 then
      common.report_env_results(env, loaded_config)
      return exit
   end

   if not common.report_env_results(env, loaded_config) then
      return 1
   end

   for node_ast in ivalues(to_write) do
      local n <const>, ast <const> = node_ast[1], node_ast[2]
      local fh <const>, err <const> = io.open(n.output:to_real_path(), "w")
      if not fh then
         log.err("Error opening file", display_filename(n.output), err)
         exit = 1
      else
         fh:write(common.compile_ast(ast))
         fh:close()
         log.info("Wrote ", display_filename(n.output))
      end
   end

   if #to_write > 0 then
      emit_hook("post")
   end

   return exit
end

command.new{
   name = "build",
   description = [[Build a project based on tlconfig.lua.]],
   exec = coroutine.wrap(build) as function(command.Command.Args): (number),
   argparse = function(cmd: argparse.Command)
      cmd:flag("-u --update-all", "Force recompilation of every file in your project.")
   end,
   script_hooks = { "pre", "post" },
}

