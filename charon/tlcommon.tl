
-- Common things needed by most commands in addition to
-- wrappers around the tl api, since it isn't super stable

local command <const> = require("charon.command")
local config <const> = require("charon.config")
local fs <const> = require("charon.fs")
local log <const> = require("charon.log")
local util <const> = require("charon.util")
local cs <const> = require("charon.colorstring")
local tl <const> = require("tl")

local map <const>, filter <const>, ivalues <const> = util.tab.map, util.tab.filter, util.tab.ivalues

-- tl.Node is not exposed :((((((((((
local type Node = any -- tl.Node

-- tl.Token also not exposed :((((((((
local type Token = record
   x: number
   y: number
   tk: string
   kind: string
end

local record ParseResult
   tks: {Token}
   ast: Node
   reqs: {string}
   errs: {tl.Error}
end

local common <const> = {
   Token = Token,
   ParseResult = ParseResult,
}

local parse_cache <const>: {string:ParseResult} = {}
function common.parse_file(path: string): ParseResult, string
   if not parse_cache[path] then
      local content <const>, err <const> = fs.read(path)
      if not content then
         return nil, err
      end
      local tks <const>, lex_errs <const> = tl.lex(content)
      if lex_errs then
         return nil, "Error lexing"
      end

      local errs <const>: {tl.Error} = {}
      local _, ast <const>, reqs <const> = tl.parse_program(tks, errs, path)

      parse_cache[path] = {
         tks = tks as {Token},
         ast = ast,
         reqs = reqs,
         errs = errs,
      }
   end
   return parse_cache[path]
end

local type_check = tl.type_check as function(Node, tl.TypeCheckOptions): tl.Result
function common.type_check_ast(ast: Node, opts: tl.TypeCheckOptions)
   type_check(ast, opts)
end

function common.parse_result_to_tl_result(pr: ParseResult): tl.Result
   return {
      syntax_errors = pr.errs,
      warnings = {},
      unknowns = {},
      type_errors = {},
   }
end

function common.make_error_header(file: string, num_errors: number, category: string): string
   return cs.new(
      cs.colors.emphasis, tostring(num_errors),
      " ", category, (num_errors ~= 1 and "s" or ""), {0},
      " in ",
      cs.colors.file, file, {0}
   ):tostring()
end

local function prettify_error(e: tl.Error): string
   return cs.new(
      "   ", cs.colors.file, e.filename, {0},
      " ", cs.colors.number, tostring(e.y), {0},
      ":", cs.colors.number, tostring(e.x), {0},
      " ", e.msg
   ):tostring()
end

function common.report_errors(logfn: function(...: any), errs: {tl.Error}, file: string, category: string)
   logfn(
      common.make_error_header(file, #errs, category),
      "\n", table.concat(map(errs, prettify_error), "\n")
   )
end

local warning_errors: {tl.WarningKind:boolean} = {}
local disabled_warnings: {tl.WarningKind:boolean} = {}
function common.disable_warning(s: string)
   disabled_warnings[s as tl.WarningKind] = true
end

function common.promote_warning(s: string)
   warning_errors[s as tl.WarningKind] = true
end

function common.report_result(file: string, r: tl.Result): boolean
   local werrors <const>, warnings <const> = filter(r.warnings or {}, function(w: tl.Error): boolean
      return warning_errors[w.tag]
   end)
   local function report(logfn: function(...: any), arr: {tl.Error}, category: string): boolean
      if #arr > 0 then
         common.report_errors(logfn, arr, file, category)
         return false
      else
         return true
      end
   end

   report(log.warn, warnings, "warning")
   return report(log.err, werrors, "warning error")
      and report(log.err, r.type_errors, "type error")
      and report(log.err, r.unknowns, "unknown")
end

function common.init_teal_env(gen_compat: boolean | tl.CompatMode, gen_target: tl.TargetMode): tl.Env
   return tl.init_env(false, gen_compat, gen_target)
end

local pretty_print_ast <const> = tl.pretty_print_ast as function(Node): string
function common.compile_ast(ast: Node): string
   return pretty_print_ast(ast)
end

function common.load_config_report_errs(path: string, args: command.Command.Args): config.Config
   -- reports errors in the actual config, not if the config wasn't found
   local c <const>, errs <const>, warnings <const> = config.load_with_args(path, args)
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

function common.type_check_and_load_file(path: string, env: tl.Env): function, string
   local result <const>, err <const> = tl.process(path, env)
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
      _G as table
   )
end

local found_modules: {string:fs.Path} = {}
function common.search_module(name: string, search_dtl: boolean): fs.Path
   if not found_modules[name] then
      local found, fd = tl.search_module(name, search_dtl)
      if found then fd:close() end
      found_modules[name] = fs.path.new(found)
   end
   return found_modules[name]
end

function common.load_module_into_env(mod_name: string, env: tl.Env)
   tl.require_module(mod_name, false, env)
end

function common.prepend_to_lua_path(path_str: string)
   if path_str:sub(-1) == fs.path.separator then
      path_str = path_str:sub(1, -2)
   end

   path_str = path_str .. fs.path.separator

   package.path = path_str .. "?.lua;"
      .. path_str .. "?" .. fs.path.separator .. "init.lua;"
      .. package.path

   package.cpath = path_str .. "?." .. fs.path.shared_lib_ext .. ";"
      .. package.cpath
end

function common.apply_config_to_environment(cfg: config.Config, tl_env: tl.Env): tl.Env
   local env = tl_env or common.init_teal_env(cfg.gen_compat, cfg.gen_target)

   for dir in ivalues(cfg.include_dir or {}) do
      common.prepend_to_lua_path(dir)
   end

   for module in ivalues(cfg.preload_modules or {}) do
      common.load_module_into_env(module, env)
   end

   return env
end

function common.load_and_init_env(require_config: boolean, path_to_file: string, args: command.Command.Args, env: tl.Env): boolean, config.Config, tl.Env
   local cfg = common.load_config_report_errs(path_to_file)
   if not cfg then
      if require_config then
         return false
      else
         cfg = {}
      end
   end

   config.merge_with_args(cfg, args)
   env = common.apply_config_to_environment(cfg, env)
   return true, cfg, env
end

return common

