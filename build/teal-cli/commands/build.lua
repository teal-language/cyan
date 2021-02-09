local _tl_compat; if (tonumber((_VERSION or ''):match('[%d.]*$')) or 0) < 5.3 then local p, m = pcall(require, 'compat53.module'); if p then _tl_compat = m end end; local io = _tl_compat and _tl_compat.io or io; local string = _tl_compat and _tl_compat.string or string; local table = _tl_compat and _tl_compat.table or table
local lfs = require("lfs")

local command = require("teal-cli.command")
local common = require("teal-cli.tlcommon")
local cs = require("teal-cli.colorstring")
local fs = require("teal-cli.fs")
local graph = require("teal-cli.graph")
local log = require("teal-cli.log")
local util = require("teal-cli.util")

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

local function build(args)
   local config_path = fs.search_parent_dirs(lfs.currentdir(), "tlconfig.lua")
   if not config_path then
      log.err("tlconfig.lua not found")
      return 1
   end

   local cfg_ok, loaded_config, env = common.load_and_init_env(true, config_path:to_real_path(), args)
   if not cfg_ok then
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

   local include = loaded_config.include or {}
   local exclude = loaded_config.exclude or {}

   local dag = graph.scan_dir(source_dir, include, exclude)

   local exit = 0
   local function get_output_name(src)
      local out = src:copy()
      out:remove_leading(source_dir)
      out:prepend(build_dir)
      local base = fs.extension_split(out[#out])
      out[#out] = base .. ".lua"
      return out
   end

   local function source_is_newer(src)
      local target = get_output_name(src)
      local in_t, out_t = src:mod_time(), target:mod_time()
      if not out_t then
         return true
      end
      return in_t > out_t
   end

   dag:mark_each(source_is_newer)

   for n in dag:marked_nodes("typecheck") do
      local path = n.input:to_real_path()
      local parsed = common.parse_file(path)
      if parsed then
         local result = common.parse_result_to_tl_result(parsed)
         common.type_check_ast(parsed.ast, {
            filename = path,
            env = env,
            result = result,
         })
         if not common.report_result(path, result) then
            exit = 1
         else
            log.info("Type checked", cs.new(cs.colors.file, n.input:tostring(), 0))
         end
      else
         exit = 1
      end
   end

   local to_write = {}
   if exit == 0 then
      for n in dag:marked_nodes("compile") do
         local path = n.input:to_real_path()
         local out = get_output_name(n.input)
         n.output = out
         local parsed = common.parse_file(path)
         if parsed then
            local result = common.parse_result_to_tl_result(parsed)
            common.type_check_ast(parsed.ast, {
               filename = path,
               env = env,
               result = result,
            })
            if not common.report_result(path, result) then
               exit = 1
            else
               local ok, err = n.output:mk_parent_dirs()
               if ok then
                  log.info("Type checked", cs.new(cs.colors.file, n.input:tostring(), 0))
                  table.insert(to_write, { n, parsed.ast })
               else
                  log.err("Unable to create parent dirs to", cs.new(cs.colors.file, n.output:tostring(), 0), ":", err)
                  exit = 1
               end
            end
         else
            exit = 1
         end
      end
   end

   if exit == 0 then
      for node_ast in ivalues(to_write) do
         local n, ast = node_ast[1], node_ast[2]
         local fh, err = io.open(n.output:to_real_path(), "w")
         if not fh then
            log.err("Error opening file", cs.new(cs.colors.file, n.output:to_real_path(), 0), err)
            exit = 1
         else
            fh:write(common.compile_ast(ast))
            fh:close()
            log.info("Wrote", cs.new(cs.colors.file, n.output:to_real_path(), 0))
         end
      end
   end

   return exit
end

command.new({
   name = "build",
   description = [[Build a project based on tlconfig.lua.]],
   exec = build,
})