local _tl_compat; if (tonumber((_VERSION or ''):match('[%d.]*$')) or 0) < 5.3 then local p, m = true, require('compat53.module'); if p then _tl_compat = m end end; local coroutine = _tl_compat and _tl_compat.coroutine or coroutine; local io = _tl_compat and _tl_compat.io or io; local ipairs = _tl_compat and _tl_compat.ipairs or ipairs; local os = _tl_compat and _tl_compat.os or os; local string = _tl_compat and _tl_compat.string or string; local table = _tl_compat and _tl_compat.table or table; local _tl_table_unpack = unpack or table.unpack

local argparse = require("argparse")
local tl = require("tl")

local command = require("cyan.command")
local common = require("cyan.tlcommon")
local config = require("cyan.config")
local cs = require("cyan.colorstring")
local fs = require("cyan.fs")
local graph = require("cyan.graph")
local log = require("cyan.log")
local script = require("cyan.script")
local util = require("cyan.util")

local ivalues = util.tab.ivalues

local function exists_and_is_dir(prefix, p)
   if not p:exists() then
      log.err(string.format("%s %q does not exist", prefix, p:to_real_path()))
      return false
   elseif not p:is_directory() then
      log.err(string.format("%s %q is not a directory", prefix, p:to_real_path()))
      return false
   end
   return true
end


local function report_dep_errors(env, source_dir)
   local ok = true
   for name in ivalues(env.loaded_order) do
      local res = env.loaded[name]
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

local function build(args, loaded_config, starting_dir)
   if not loaded_config.loaded_from then
      log.err(config.filename, " not found")
      return 1
   end

   local source_dir = fs.path.new(loaded_config.source_dir or "./")
   if not exists_and_is_dir("Source dir", source_dir) then
      return 1
   end

   local build_dir = fs.path.new(loaded_config.build_dir or "./")

   if not build_dir:exists() then
      local succ, err = build_dir:mkdir()
      if not succ then
         log.err(string.format("Failed to create build dir %q: %s", build_dir:to_real_path(), err))
         return 1
      end
   elseif not build_dir:is_directory() then
      log.err(string.format("Build dir %q is not a directory", build_dir:to_real_path()))
      return 1
   end

   local env, env_err = common.init_env_from_config(loaded_config)
   if not env then
      log.err("Could not initialize Teal environment:\n", env_err)
      return 1
   end

   if not script.emit_hook("pre") then
      return 1
   end

   local include = loaded_config.include or {}
   local exclude = loaded_config.exclude and { _tl_table_unpack(loaded_config.exclude) } or {}
   if source_dir == starting_dir then
      table.insert(exclude, "tlconfig.lua")
   end

   local dag, cycles = graph.scan_dir(source_dir, include, exclude)
   if not dag then
      log.err(
      "Circular dependency detected in the following files:\n   ",
      _tl_table_unpack(util.tab.intersperse(cycles, "\n   ")))

      return 1
   end
   local exit = 0

   log.debug("Built dependency graph")

   local function display_filename(f)
      return cs.highlight(cs.colors.file, f:relative_to(starting_dir):tostring())
   end

   local function get_output_name(src)
      local out = src:copy()
      out:remove_leading(source_dir)
      out:prepend(build_dir)
      local base, ext = fs.extension_split(out[#out])
      if ext == ".tl" then
         out[#out] = base .. ".lua"
      end
      return out
   end

   local function source_is_newer(src)
      local target = get_output_name(src)
      local newer
      if args.update_all then
         newer = true
      else
         local in_t, out_t = src:mod_time(), target:mod_time() or -1
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

   if not coroutine.wrap(function()
         dag:mark_each(source_is_newer)
         return true
      end)() then
      return exit
   end

   local to_write = {}
   local function process_node(n, compile)
      local path = n.input:to_real_path()
      local out = get_output_name(n.input)
      n.output = out
      local parsed = common.parse_file(path)
      if #parsed.errs > 0 then
         common.report_errors(log.err, parsed.errs, path, "syntax error")
         exit = 1
         return
      end

      local result = common.type_check_ast(parsed.ast, {
         filename = path,
         env = env,
      })

      if not common.report_result(result, loaded_config) then
         exit = 1
         return
      end

      log.info("Type checked ", display_filename(n.input))
      if compile then
         local ok, err = n.output:mk_parent_dirs()
         if ok then
            table.insert(to_write, { n, parsed.ast })
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
      local n, ast = node_ast[1], node_ast[2]
      local fh, err = io.open(n.output:to_real_path(), "w")
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
      local expected_files = {}
      for n in dag:nodes() do
         log.debug(n.input, " -> ", get_output_name(n.input))
         local p = get_output_name(n.input)
         p:remove_leading(build_dir)
         expected_files[p:tostring()] = true
      end

      local unexpected_files = {}
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
               local file = build_dir .. p
               local disp = display_filename(file)
               local real = file:relative_to(fs.cwd())
               local ok, err = os.remove(real:to_real_path())
               if ok then
                  log.info("Pruned file ", disp)
               else
                  log.err("Unable to prune file '", disp, "': ", err)
               end
            end
         else
            local strs = {}
            for _, p in ipairs(unexpected_files) do
               table.insert(strs, "\n   ")
               table.insert(strs, display_filename(p))
            end
            table.insert(strs, "\nhint: use `cyan build --prune` to automatically delete these files")
            log.warn("Unexpected files in build directory:", _tl_table_unpack(strs))
         end
      end
   end

   if not report_dep_errors(env, source_dir) then
      log.warn("There were errors in out of project files. Your project may not work as expected.")
   end

   return exit
end

command.new({
   name = "build",
   description = [[Build a project based on tlconfig.lua.]],
   exec = build,
   argparse = function(cmd)
      cmd:flag("-u --update-all", "Force recompilation of every file in your project.")
      cmd:flag("-c --check-only", "Only type check files.")
      cmd:flag("-p --prune", "Remove any unexpected files in the build directory.")
   end,
   script_hooks = { "pre", "post", "file_updated" },
})