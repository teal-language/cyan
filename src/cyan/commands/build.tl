---@nodoc

local argparse <const> = require("argparse")
local tl <const> = require("tl")

local command <const> = require("cyan.command")
local common <const> = require("cyan.tlcommon")
local config <const> = require("cyan.config")
local cs <const> = require("cyan.colorstring")
local fs <const> = require("cyan.fs")
local graph <const> = require("cyan.graph")
local log <const> = require("cyan.log")
local script <const> = require("cyan.script")
local util <const> = require("cyan.util")

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

-- in the event that an out of project dependency has a type error, we should report it
local function report_dep_errors(env: tl.Env, source_dir: fs.Path): boolean
   local ok = true
   for name in ivalues(env.loaded_order) do
      local res <const> = env.loaded[name]
      if not fs.path.new(res.filename, true):is_in(source_dir) then
         if (res.syntax_errors and #res.syntax_errors > 0) or #res.type_errors > 0 then
            if (res.syntax_errors and #res.syntax_errors > 0) then
               common.report_errors(log.err, res.syntax_errors, res.filename, "(Out of project) syntax error")
            end
            if #res.type_errors > 0 then
               common.report_errors(log.err, res.type_errors, res.filename, "(Out of project) type error")
            end
            ok = false
         end
      end
   end
   return ok
end

local function build(args: command.Args, loaded_config: config.Config, starting_dir: fs.Path): integer
   if not loaded_config then
      log.err(config.filename, " not found")
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

   local env <const>, env_err <const> = common.init_env_from_config(loaded_config)
   if not env then
      log.err("Could not initialize Teal environment:\n", env_err)
      return 1
   end

   if not script.emit_hook("pre") then
      return 1
   end

   local include <const> = loaded_config.include or {}
   local exclude <const> = loaded_config.exclude or {}

   local dag <const>, cycles <const> = graph.scan_dir(source_dir, include, exclude)
   if not dag then
      log.err(
         "Circular dependency detected in the following files:\n   ",
         table.concat(
            util.tab.map(cycles, function(fname: string): string
               return cs.highlight(cs.colors.file, fname):tostring()
            end),
            "\n   "
         )
      )
      return 1
   end
   local exit = 0

   log.debug("Built dependency graph")

   local function display_filename(f: fs.Path): cs.ColorString
      return cs.highlight(cs.colors.file, f:relative_to(starting_dir))
   end

   local function get_output_name(src: fs.Path): fs.Path
      local out <const> = src:copy()
      out:remove_leading(source_dir)
      out:prepend(build_dir)
      local base <const> = fs.extension_split(out[#out])
      out[#out] = base .. ".lua"
      return out
   end

   local function source_is_newer(src: fs.Path): boolean
      local target <const> = get_output_name(src)
      local newer: boolean
      if args.update_all then
         newer = true
      else
         local in_t <const>, out_t <const> = src:mod_time(), target:mod_time() or -1
         newer = in_t > out_t
      end
      if newer then
         log.extra("Source ", display_filename(src), " is newer than target (", display_filename(target), ")")
         if not script.emit_hook("file_updated", src:copy()) then
            exit = 1
            coroutine.yield()
         end
      end
      return newer
   end

   local res = coroutine.wrap(function(): boolean
      dag:mark_each(source_is_newer)
      return true
   end)()

   if not res then
      return exit
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

      if not common.report_result(result, loaded_config) then
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
      return exit
   end

   for n in dag:marked_nodes("compile") do
      process_node(n, true)
   end

   if exit ~= 0 then
      report_dep_errors(env, source_dir)
      return exit
   end

   if args.check_only then
      return exit
   end

   for node_ast in ivalues(to_write) do
      local n <const>, ast <const> = node_ast[1], node_ast[2]
      local fh <const>, err <const> = io.open(n.output:to_real_path(), "w")
      if not fh then
         log.err("Error opening file ", display_filename(n.output), ": ", err)
         exit = 1
      else
         fh:write(common.compile_ast(ast))
         fh:close()
         log.info("Wrote ", display_filename(n.output))
      end
   end

   if #to_write > 0 then
      if not script.emit_hook("post") then
         return 1
      end
   end

   if build_dir ~= source_dir then
      local expected_files <const> = {}
      for n in dag:nodes() do
         log.debug(n.input, " -> ", get_output_name(n.input))
         local p = get_output_name(n.input)
         p:remove_leading(build_dir)
         expected_files[p:tostring()] = true
      end

      local unexpected_files <const>: {fs.Path} = {}
      for p in fs.scan_dir(build_dir) do
         log.debug("checking if ", p:tostring(), " is expected...")
         if expected_files[p:tostring()] then
            log.debug("   yes")
         else
            log.debug("   no")
            table.insert(unexpected_files, p)
         end
      end

      if #unexpected_files > 0 then
         if args.prune then
            for _, p in ipairs(unexpected_files) do
               local file <const> = build_dir .. p
               local disp <const> = display_filename(file)
               local real <const> = file:relative_to(fs.cwd())
               local ok <const>, err <const> = os.remove(real)
               if ok then
                  log.info("Pruned file ", disp)
               else
                  log.err("Unable to prune file '", disp, "': ", err)
               end
            end
         else
            local strs <const>: {string | cs.ColorString} = {}
            for _, p in ipairs(unexpected_files) do
               table.insert(strs, "\n   ")
               table.insert(strs, display_filename(p))
            end
            table.insert(strs, "\nhint: use `cyan build --prune` to automatically delete these files")
            log.warn("Unexpected files in build directory:", table.unpack(strs))
         end
      end
   end

   if not report_dep_errors(env, source_dir) then
      log.warn("There were errors in out of project files. Your project may not work as expected.")
   end

   return exit
end

command.new{
   name = "build",
   description = [[Build a project based on tlconfig.lua.]],
   exec = build,
   argparse = function(cmd: argparse.Command)
      cmd:flag("-u --update-all", "Force recompilation of every file in your project.")
      cmd:flag("-c --check-only", "Only type check files.")
      cmd:flag("-p --prune", "Remove any unexpected files in the build directory.")
   end,
   script_hooks = { "pre", "post", "file_updated" },
}
