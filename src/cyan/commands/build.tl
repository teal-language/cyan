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
   if not loaded_config.loaded_from then
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
   local exclude <const> = loaded_config.exclude and { table.unpack(loaded_config.exclude) } or {}
   if source_dir == starting_dir then
      table.insert(exclude, "tlconfig.lua")
   end
   local dont_write_lua_files <const> = source_dir == build_dir

   local dag <const>, cycles <const> = graph.scan_dir(source_dir, include, exclude)
   if not dag then
      log.err(
         "Circular dependency detected in the following files:\n   ",
         table.unpack(util.tab.intersperse(cycles, "\n   "))
      )
      return 1
   end
   local exit = 0

   log.debug("Built dependency graph")

   local function display_filename(f: fs.Path, trailing_slash: boolean): cs.ColorString
      return cs.highlight(cs.colors.file, f:relative_to(starting_dir):tostring() .. (trailing_slash and "/" or ""))
   end

   local function get_output_name(src: fs.Path): fs.Path
      local out <const> = src:copy()
      out:remove_leading(source_dir)
      out:prepend(build_dir)
      local base <const>, ext <const> = fs.extension_split(out[#out])
      if ext == ".tl" then
         out[#out] = base .. ".lua"
      end
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

   if not coroutine.wrap(function(): boolean
      dag:mark_each(source_is_newer)
      return true
   end)() then
      return exit
   end

   local to_write <const> = {}
   local function process_node(n: graph.Node, compile: boolean)
      local path <const> = n.input:to_real_path()
      local disp_path <const> = display_filename(n.input)
      local out <const> = get_output_name(n.input)
      n.output = out
      local parsed <const>, parse_err <const> = common.parse_file(path)
      if not parsed then
         log.err("Could not parse ", disp_path, ":\n   ", parse_err)
         exit = 1
         return
      end
      if #parsed.errs > 0 then
         common.report_errors(log.err, parsed.errs, path, "syntax error")
         exit = 1
         return
      end

      local result <const>, check_ast_err <const> = common.type_check_ast(parsed.ast, {
         filename = path,
         env = env,
      })
      if not result then
         log.err("Could not type check ", disp_path, ":\n   ", check_ast_err)
         exit = 1
         return
      end

      if not common.report_result(result, loaded_config) then
         exit = 1
         return
      end

      log.info("Type checked ", disp_path)
      local is_lua <const> = select(2, fs.extension_split(path)) == ".lua"
      if compile and not (is_lua and dont_write_lua_files) then
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
         local generated <const>, gen_err <const> = common.compile_ast(ast, loaded_config.gen_target)
         if generated then
            fh:write(generated, "\n")
            fh:close()
            log.info("Wrote ", display_filename(n.output))
         else
            log.err("Error when generating lua for ", display_filename(n.output), "\n", gen_err)
            exit = 1
         end
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
         for ancestor in p:ancestors() do
            expected_files[ancestor:tostring()] = true
         end
      end

      local unexpected_files <const>: {fs.Path} = {}
      local unexpected_directories <const>: {fs.Path} = {}
      for p in fs.scan_dir(build_dir, nil, nil, true) do
         log.debug("checking if ", p:tostring(), " is expected...")
         local full <const> = build_dir .. p
         local _, ignore_patt <const> = full:match_any(loaded_config.dont_prune or {})
         if ignore_patt then
            log.debug("   yes (ignored by pattern ", ignore_patt, ")")
         elseif expected_files[p:tostring()] then
            log.debug("   yes")
         else
            log.debug("   no")
            table.insert(full:is_directory() and unexpected_directories or unexpected_files, p)
         end
      end

      if #unexpected_files > 0 or #unexpected_directories > 0 then
         if args.prune then
            local cwd <const> = fs.cwd()
            local function prune(p: fs.Path, kind: string)
               local file <const> = build_dir .. p
               local disp <const> = display_filename(file)
               local real <const> = file:relative_to(cwd)
               local ok <const>, err <const> = os.remove(real:to_real_path())
               if ok then
                  log.info("Pruned ", kind, " ", disp)
               else
                  log.err("Unable to prune ", kind, " '", disp, "': ", err)
               end
            end
            for _, p in ipairs(unexpected_files) do
               prune(p, "file")
            end
            for _, p in ipairs(unexpected_directories) do
               prune(p, "directory")
            end
         else
            local strs <const>: {string | cs.ColorString} = {}
            for _, p in ipairs(unexpected_files) do
               table.insert(strs, "\n   ")
               table.insert(strs, display_filename(p))
            end
            for _, p in ipairs(unexpected_directories) do
               table.insert(strs, "\n   ")
               table.insert(strs, display_filename(p, true))
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
