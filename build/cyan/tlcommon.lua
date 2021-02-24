local _tl_compat; if (tonumber((_VERSION or ''):match('[%d.]*$')) or 0) < 5.3 then local p, m = true, require('compat53.module'); if p then _tl_compat = m end end; local load = _tl_compat and _tl_compat.load or load; local package = _tl_compat and _tl_compat.package or package; local pairs = _tl_compat and _tl_compat.pairs or pairs; local string = _tl_compat and _tl_compat.string or string; local table = _tl_compat and _tl_compat.table or table




local command = require("cyan.command")
local config = require("cyan.config")
local fs = require("cyan.fs")
local log = require("cyan.log")
local util = require("cyan.util")
local cs = require("cyan.colorstring")
local tl = require("tl")

local map, filter, ivalues = util.tab.map, util.tab.filter, util.tab.ivalues


local Node = {}


local Token = {}








local ParseResult = {}






local common = {
   Token = Token,
   ParseResult = ParseResult,
}

local parse_cache = {}
function common.parse_file(path)
   if not parse_cache[path] then
      local content, err = fs.read(path)
      if not content then
         return nil, err
      end
      local tks, lex_errs = tl.lex(content)
      if lex_errs then
         return nil, "Error lexing"
      end

      local errs = {}
      local _, ast, reqs = tl.parse_program(tks, errs, path)

      parse_cache[path] = {
         tks = tks,
         ast = ast,
         reqs = reqs,
         errs = errs,
      }
   end
   return parse_cache[path]
end

local type_check = tl.type_check


function common.type_check_ast(ast, opts)
   type_check(ast, opts)
end



function common.parse_result_to_tl_result(pr)
   return {
      syntax_errors = pr.errs,
      warnings = {},
      unknowns = {},
      type_errors = {},
   }
end






function common.make_error_header(file, num_errors, category)
   return cs.new(
   cs.colors.emphasis, tostring(num_errors),
   " ", category, (num_errors ~= 1 and "s" or ""), { 0 },
   " in ",
   cs.colors.file, file, { 0 }):
   tostring()
end

local function prettify_error(e)
   return cs.new(
   "   ", cs.colors.file, e.filename, { 0 },
   " ", cs.colors.number, tostring(e.y), { 0 },
   ":", cs.colors.number, tostring(e.x), { 0 },
   " ", e.msg):
   tostring()
end



function common.report_errors(logfn, errs, file, category)
   logfn(
   common.make_error_header(file, #errs, category),
   "\n", table.concat(map(errs, prettify_error), "\n"))

end

local warning_errors = {}
local disabled_warnings = {}
function common.disable_warning(s)
   disabled_warnings[s] = true
end

function common.promote_warning(s)
   warning_errors[s] = true
end





function common.report_result(file, r)
   local werrors, warnings = filter(r.warnings or {}, function(w)
      return warning_errors[w.tag]
   end)
   local function report(logfn, arr, category)
      if #arr > 0 then
         common.report_errors(logfn, arr, file, category)
         return false
      else
         return true
      end
   end

   report(log.warn, warnings, "warning")
   return report(log.err, werrors, "warning error") and
   report(log.err, r.type_errors, "type error") and
   report(log.err, r.unknowns, "unknown")
end



function common.init_teal_env(gen_compat, gen_target, preload)
   return tl.init_env(false, gen_compat, gen_target, preload)
end

local pretty_print_ast = tl.pretty_print_ast
function common.compile_ast(ast)
   return pretty_print_ast(ast)
end



function common.load_config_report_errs(path, args)

   local c, errs, warnings = config.load_with_args(args)
   if #warnings > 0 then
      log.warn("in ", tostring(path), "\n", table.concat(warnings, "\n"))
      return nil
   end
   if not c then
      if not errs[1]:match("No such file or directory$") then
         log.err("Error loading config from ", tostring(path), "\n", table.concat(errs, "\n"))
      end
      return nil
   end
   return c
end

function common.type_check_and_load_file(path, env)
   local result, err = tl.process(path, env)
   if not result then
      return nil, err
   end
   if not common.report_result(path, result) then
      return nil
   end
   return load(
   pretty_print_ast(result.ast),
   path,
   "t",
   _G)

end

local found_modules = {}


function common.search_module(name, search_dtl)
   if not found_modules[name] then
      local found, fd = tl.search_module(name, search_dtl)
      if found then fd:close() end
      found_modules[name] = fs.path.new(found)
   end
   return found_modules[name]
end





function common.prepend_to_lua_path(path_str)
   if path_str:sub(-1) == fs.path.separator then
      path_str = path_str:sub(1, -2)
   end

   path_str = path_str .. fs.path.separator

   package.path = path_str .. "?.lua;" ..
   path_str .. "?" .. fs.path.separator .. "init.lua;" ..
   package.path

   package.cpath = path_str .. "?." .. fs.path.shared_lib_ext .. ";" ..
   package.cpath
end

local old_tl_search_module = tl.search_module
local substitutions = {}
function common.add_module_substitute(source_dir, mod_name)
   substitutions[source_dir] = "^" .. util.str.esc(mod_name)
end

tl.search_module = function(module_name, search_dtl)
   for src, mod in pairs(substitutions) do
      if module_name:match(mod) then
         local a, b, c = old_tl_search_module(module_name:gsub(mod, src), search_dtl)
         if a then
            return a, b, c
         end
      end
   end
   return old_tl_search_module(module_name, search_dtl)
end





function common.init_env_from_cfg(cfg)
   for dir in ivalues(cfg.include_dir or {}) do
      common.prepend_to_lua_path(dir)
   end

   if cfg.source_dir and cfg.module_name then
      common.add_module_substitute(cfg.source_dir, cfg.module_name)
   end

   local env, err = common.init_teal_env(cfg.gen_compat, cfg.gen_target, cfg.preload_modules)
   if not env then
      return nil, err
   end

   return env
end



function common.load_cfg_env_report_errs(require_config, args)
   local cfg = common.load_config_report_errs(config.filename)
   if not cfg then
      if require_config then
         return false
      else
         cfg = {}
      end
   end

   config.merge_with_args(cfg, args)

   local env, err = common.init_env_from_cfg(cfg)
   if err then
      log.err(err)
      return false
   end
   return true, cfg, env
end

return common