
local tl <const> = require("tl")
local argparse <const> = require("argparse")
local lfs <const> = require("lfs")

local command <const> = require("teal-cli.command")
local common <const> = require("teal-cli.tlcommon")
local config <const> = require("teal-cli.config")
local cs <const> = require("teal-cli.colorstring")
local fs <const> = require("teal-cli.fs")
local graph <const> = require("teal-cli.graph")
local log <const> = require("teal-cli.log")
local util <const> = require("teal-cli.util")

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

local function build(args: command.Command.Args): number
   local config_path <const> = fs.search_parent_dirs(lfs.currentdir(), "tlconfig.lua")
   if not config_path then
      log.err("tlconfig.lua not found")
      return 1
   end

   local loaded_config <const>, conferr <const> = config.load("tlconfig.lua")
   if conferr and not conferr[1]:match("No such file or directory$") then
      log.err("Unable to load config:\n   " .. table.concat(conferr, "\n   "))
      return 1
   end

   local source_dir <const> = fs.path(loaded_config.source_dir or "./")
   if not exists_and_is_dir("Source dir", source_dir) then
      return 1
   end

   local build_dir <const> = fs.path(loaded_config.build_dir or "./")

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

   local include <const> = loaded_config.include or {}
   local exclude <const> = loaded_config.exclude or {}

   local dag <const> = graph.scan_dir(source_dir, include, exclude)

   local function get_output_name(src: fs.Path): fs.Path
      local out <const> = src:copy()
      out:remove_leading(source_dir)
      out:prepend(build_dir)
      local base, ext = fs.extension_split(out[#out])
      out[#out] = base .. ".lua"
      return out
   end

   local function source_is_newer(src: fs.Path): boolean
      local target <const> = get_output_name(src)
      local in_t, out_t = src:mod_time(), target:mod_time()
      if not out_t then
         return true
      end
      return in_t > out_t
   end

   dag:mark_each(source_is_newer)

   local env <const> = common.init_teal_env(loaded_config.gen_compat, loaded_config.gen_target)

   -- TODO: preload modules and add to include paths before scanning dir

   local exit = 0
   for n in dag:marked_nodes("typecheck") do
      local path <const> = n.input:to_real_path()
      local parsed <const> = common.parse_file(path)
      if parsed then
         local result <const> = common.parse_result_to_tl_result(parsed)
         common.type_check_ast(parsed.ast, {
            filename = path,
            env = env,
            result = result,
         })
         if not common.report_result(path, result) then
            exit = 1
         else
            log.info("Type checked", cs.new(cs.colors.file, path, 0))
         end
      else
         exit = 1
      end
   end

   local to_write <const> = {}
   if exit == 0 then
      for n in dag:marked_nodes("compile") do
         local path <const> = n.input:to_real_path()
         local out <const> = get_output_name(n.input)
         n.output = out
         local parsed <const> = common.parse_file(path)
         if parsed then
            local result <const> = common.parse_result_to_tl_result(parsed)
            common.type_check_ast(parsed.ast, {
               filename = path,
               env = env,
               result = result,
            })
            if not common.report_result(path, result) then
               exit = 1
            else
               log.info("Type checked", cs.new(cs.colors.file, path, 0))
               table.insert(to_write, {n, parsed.ast})
            end
         else
            exit = 1
         end
      end
   end

   if exit == 0 then
      for _, node_ast in ipairs(to_write) do
         local n <const>, ast <const> = node_ast[1], node_ast[2]
         local fh <const>, err <const> = io.open(n.output:to_real_path(), "w")
         if not fh then
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

command.new{
   name = "build",
   description = [[Build a project based on tlconfig.lua.]],
   exec = build,
}

