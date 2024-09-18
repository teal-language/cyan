local _tl_compat; if (tonumber((_VERSION or ''):match('[%d.]*$')) or 0) < 5.3 then local p, m = true, require('compat53.module'); if p then _tl_compat = m end end; local coroutine = _tl_compat and _tl_compat.coroutine or coroutine; local io = _tl_compat and _tl_compat.io or io; local os = _tl_compat and _tl_compat.os or os; local pairs = _tl_compat and _tl_compat.pairs or pairs; local string = _tl_compat and _tl_compat.string or string; local table = _tl_compat and _tl_compat.table or table; local _tl_table_unpack = unpack or table.unpack

local argparse = require("argparse")
local tl = require("tl")

local command = require("cyan.command")
local common = require("cyan.tlcommon")
local config = require("cyan.config")
local decoration = require("cyan.decoration")
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
   end
   if not p:is_directory() then
      log.err(string.format("%s %q is not a directory", prefix, p:to_real_path()))
      return false
   end
   return true
end


local function report_dep_errors(env, source_dir)
   local ok = true
   for name in ivalues(env.loaded_order) do
      local res = env.loaded[name]
      if not fs.path.new(res.filename, true):is_in(source_dir, false) then
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

   local source_dir = fs.path.new(loaded_config.source_dir or "./", false)
   if not exists_and_is_dir("Source dir", source_dir) then
      return 1
   end

   local build_dir = fs.path.new(loaded_config.build_dir or "./", false)

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
   local dont_write_lua_files = source_dir == build_dir

   local dag, cycles = graph.scan_dir(source_dir, include, exclude)
   if not dag then
      log.err(
      "Circular dependency detected in the following files:\n   ",
      _tl_table_unpack(util.tab.intersperse(cycles, "\n   ")))

      return 1
   end
   local exit = 0

   if log.debug:should_log() then
      log.debug("Built dependency graph")
      for k, v in pairs(dag._nodes_by_filename) do
         if not next(v.dependents) then
            log.debug:cont("   ", k, " has no dependents")
         else
            log.debug:cont("   ", k, " has dependents:")
            for dependent in pairs(v.dependents) do
               log.debug:cont("      ", dependent.input:tostring())
            end
         end
      end
   end

   local function display_filename(f, trailing_slash)
      return decoration.file_name(f:relative_to(starting_dir):tostring() .. (trailing_slash and "/" or ""))
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

   local type_check_options = {
      feat_lax = "off",
      feat_arity = loaded_config.feat_arity,

      gen_compat = loaded_config.gen_compat,
      gen_target = loaded_config.gen_target,
   }

   local to_write = {}
   local function process_node(n, compile)
      local path = n.input:to_real_path()
      local disp_path = display_filename(n.input)
      log.debug("processing node of ", disp_path, " for ", compile and "compilation" or "type check")
      local out = get_output_name(n.input)
      n.output = out
      local parsed, parse_err = common.parse_file(path)
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

      local result, check_ast_err = tl.check(parsed.ast, path, type_check_options, env)
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
      if args.check_only then
         return
      end

      local is_lua = select(2, fs.extension_split(path)) == ".lua"
      if compile and not (is_lua and dont_write_lua_files) then
         local ok, err = n.output:mk_parent_dirs()
         if ok then
            table.insert(to_write, { n, parsed.ast })
         else
            log.err("Unable to create parent dirs to ", display_filename(n.output), ":", err)
            exit = 1
         end
      end
   end

   for n in dag:marked_nodes() do
      process_node(n, n.mark == "compile")
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
         local generated, gen_err = tl.generate(ast, loaded_config.gen_target)
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
      local expected_files = {}
      for n in dag:nodes() do
         log.debug(n.input, " -> ", get_output_name(n.input))
         local p = get_output_name(n.input)
         p:remove_leading(build_dir)
         expected_files[p:tostring()] = true
         for ancestor in p:ancestors() do
            expected_files[ancestor:tostring()] = true
         end
      end

      local unexpected_files = {}
      local unexpected_directories = {}
      for p in fs.scan_dir(build_dir, nil, nil, true) do
         log.debug("checking if ", p:tostring(), " is expected...")
         local full = build_dir .. p
         local _, ignore_patt = full:match_any(loaded_config.dont_prune or {})
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
            local cwd = fs.cwd()
            local function prune(p, kind)
               local file = build_dir .. p
               local disp = display_filename(file)
               local real = file:relative_to(cwd)
               local ok, err = os.remove(real:to_real_path())
               if ok then
                  log.info("Pruned ", kind, " ", disp)
               else
                  log.err("Unable to prune ", kind, " '", disp, "': ", err)
               end
            end
            for p in ivalues(unexpected_files) do
               prune(p, "file")
            end
            for p in ivalues(unexpected_directories) do
               prune(p, "directory")
            end
         else
            local strs = {}
            for p in ivalues(unexpected_files) do
               table.insert(strs, "\n   ")
               table.insert(strs, display_filename(p))
            end
            for p in ivalues(unexpected_directories) do
               table.insert(strs, "\n   ")
               table.insert(strs, display_filename(p, true))
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
