
---@brief
--- Common things needed by most commands in addition to
--- wrappers around the tl api, since it isn't super stable

local command <const> = require("cyan.command")
local config <const> = require("cyan.config")
local fs <const> = require("cyan.fs")
local log <const> = require("cyan.log")
local util <const> = require("cyan.util")
local cs <const> = require("cyan.colorstring")
local tl <const> = require("tl")

local map <const>, filter <const>, ivalues <const>, set <const>
   = util.tab.map, util.tab.filter, util.tab.ivalues, util.tab.set

-- tl.Node is not exposed :((((((((((
local type Node = any -- tl.Node

-- tl.Token also not exposed :((((((((
local type Token = record
   x: number
   y: number
   tk: string
   kind: string
end

---@desc
--- The result from parsing source code including the tokens, ast, calls to require, and errors
local record ParseResult
   tks: {Token}
   ast: Node
   reqs: {string}
   errs: {tl.Error}
end

local common <const> = {
   ParseResult = ParseResult,
}

local lex_cache <const>: {string:{{Token}, {Token}}} = {}
function common.lex_file(path: string): {Token}, {Token}, string
   if not lex_cache[path] then
      local src <const>, read_err <const> = fs.read(path)
      if not src then
         return nil, nil, read_err
      end
      local tks <const>, errs <const> = tl.lex(src) as ({Token}, {Token})
      lex_cache[path] = {tks, errs}
      return tks, errs
   end
   return lex_cache[path][1], lex_cache[path][2]
end

local parse_program <const> = tl.parse_program as function({Token}, {tl.Error}, string): number, Node, {string}
local parse_cache <const>: {string:ParseResult} = {}
function common.parse_file(path: string): ParseResult, string
   if not parse_cache[path] then
      local tks <const>, lex_errs <const>, f_err <const> = common.lex_file(path)
      if lex_errs as string or f_err then
         return nil, f_err or "Error lexing"
      end

      local errs <const>: {tl.Error} = {}
      local _, ast <const>, reqs <const> = parse_program(tks, errs, path)

      parse_cache[path] = {
         tks = tks,
         ast = ast,
         reqs = reqs,
         errs = errs,
      }
   end
   return parse_cache[path]
end

local type_check = tl.type_check as function(Node, tl.TypeCheckOptions): tl.Result
---@desc
--- Just type checks an ast
function common.type_check_ast(ast: Node, opts: tl.TypeCheckOptions): tl.Result
   return type_check(ast, opts)
end

---@desc
--- Creates a nicely colored header to log errors
---
--- For example `make_error_header("foo.tl", 10, "foo error")` would produce
--- something like `10 foo errors in foo.tl` with `10` and `foo.tl` highlighted
function common.make_error_header(file: string, num_errors: number, category: string): string
   return cs.new(
      cs.colors.emphasis, tostring(num_errors),
      " ", category, (num_errors ~= 1 and "s" or ""), {0},
      " in ",
      cs.colors.file, file, {0}
   ):tostring()
end

local function highlight_token(tk: Token): string
   -- TODO: dont rely on tk.kind and just keep a local map of keywords
   --       since certain 'keywords' are contextual, but discouraged
   --       from being used otherwise
   if cs.colors[tk.kind] then
      return cs.highlight(cs.colors[tk.kind], tk.tk):tostring()
   end
   return tk.tk == "$EOF$" and "" or tk.tk
end

local function count_tabs(str: string): number
   return select(2, str:gsub("\t", "")) as number
end

local function prettify_line(s: string): string
   local tks <const> = tl.lex(s) as {Token}
   local highlighted = {}
   local last_x = 1
   for _, tk in ipairs(tks) do
      -- account for tabs
      local ts = count_tabs(s:sub(last_x, tk.x - 1))
      if ts > 0 then
         local spaces = 3 * ts
         table.insert(highlighted, (" "):rep(spaces))
      end
      if last_x < tk.x then
         table.insert(highlighted, (" "):rep(tk.x - last_x))
      end
      table.insert(highlighted, highlight_token(tk))
      last_x = tk.x + #tk.tk
   end
   return table.concat(highlighted)
end

local function prettify_error(e: tl.Error): string
   local ln <const> = fs.get_line(e.filename, e.y)

   local tks <const> = tl.lex(ln)
   local err_tk <const> = {
      x = 1,
      tk = tl.get_token_at(tks, 1, e.x) or " "
   }

   local str <const> = cs.new(
      cs.colors.file, e.filename, {0},
      " ", cs.colors.error_number, tostring(e.y), {0},
      ":", cs.colors.error_number, tostring(e.x), {0}
   )

   if e.tag then
      str:insert(" [", cs.colors.emphasis, e.tag, {0}, "]")
   end

   str:insert("\n")

   local num_len <const> = #tostring(e.y)
   local prefix <const> = (" "):rep(num_len) .. " | "

   str:insert(
      "   ", cs.colors.number, tostring(e.y), {0}, " | ", prettify_line(ln),
      "\n   ", prefix, (" "):rep(e.x + count_tabs(ln:sub(1, e.x)) * 3 - 1),
      cs.colors.error, ("^"):rep(#err_tk.tk), {0}, "\n   ",
      prefix, cs.colors.error, e.msg, {0}
   )

   return str:tostring()
end

---@desc
--- Logs an array of errors with nice colors and a header generated by `make_error_header`
function common.report_errors(logfn: function(...: any), errs: {tl.Error}, file: string, category: string)
   logfn(
      common.make_error_header(file, #errs, category),
      "\n", table.concat(map(errs, prettify_error), "\n\n")
   )
end

function common.result_has_errors(r: tl.Result, c: config.Config): boolean
   local warning_error <const> = set(c.warning_error or {})
   local werrors <const> = filter(r.warnings or {}, function(w: tl.Error): boolean
      return warning_error[w.tag]
   end)

   local function has_errors(arr: {tl.Error}): boolean
      return arr and #arr > 0
   end
   return has_errors(werrors) or has_errors(r.type_errors)
end

---@desc
--- Logs all the syntax errors, warnings, type errors, etc. from a `tl.Result` with proper colors
---
--- Returns if there were any warnings or unknowns. May return `true` even if some warnings were reported
function common.report_result(r: tl.Result, c: config.Config): boolean
   local warning_error <const> = set(c.warning_error or {})
   local werrors <const>, warnings <const> = filter(r.warnings or {}, function(w: tl.Error): boolean
      return warning_error[w.tag]
   end)
   local function report(logfn: function(...: any), arr: {tl.Error}, category: string): boolean
      if arr and #arr > 0 then
         common.report_errors(logfn, arr, r.filename, category)
         return false
      else
         return true
      end
   end

   report(log.warn, warnings, "warning")
   return report(log.err, werrors, "warning error")
      and report(log.err, r.type_errors, "type error")
end

---@desc
--- Report all errors from a tl.Env
---
--- Returns false when errors were reported
function common.report_env_results(env: tl.Env, cfg: config.Config): boolean
   local ok = true
   for name in ivalues(env.loaded_order) do
      local res = env.loaded[name]
      ok = ok and common.report_result(res, cfg)
   end
   return ok
end

---@desc
--- Initialize a strict Teal environment
function common.init_teal_env(gen_compat: boolean | tl.CompatMode, gen_target: tl.TargetMode, preload: {string}): tl.Env, string
   return tl.init_env(false, gen_compat, gen_target, preload)
end

local pretty_print_ast <const> = tl.pretty_print_ast as function(Node): string
function common.compile_ast(ast: Node): string
   return pretty_print_ast(ast)
end

---@desc
--- Load a config through `cyan.load_with_args` and report the errors, returning nil if there were any errors
function common.load_config_report_errs(path: string, args: command.Command.Args): config.Config
   -- reports errors in the actual config, not if the config wasn't found
   local c <const>, errs <const>, warnings <const> = config.load_with_args(args)
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

function common.type_check_and_load_file(path: string, env: tl.Env, c: config.Config): function, string
   local result <const>, err <const> = tl.process(path, env)
   if not result then
      return nil, err
   end
   if not common.report_result(result, c) then
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
---@desc
--- A wrapper around `tl.search_module` but, returns an `fs.Path` and will cache results
function common.search_module(name: string, search_dtl: boolean): fs.Path
   if not found_modules[name] then
      local found, fd = tl.search_module(name, search_dtl)
      if found then fd:close() end
      found_modules[name] = fs.path.new(found)
   end
   return found_modules[name]
end

---@desc
--- Prepend the given string to package.path and package.cpath.
---
--- Correctly adds ?.lua and ?/init.lua to the path
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

local old_tl_search_module <const> = tl.search_module
local substitutions <const>: {string:string} = {}
function common.add_module_substitute(source_dir: string, mod_name: string)
   substitutions[source_dir] = "^" .. util.str.esc(mod_name)
end

tl.search_module = function(module_name: string, search_dtl: boolean): string, FILE, {string}
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

---@desc
--- Initialize a strict Teal environment, using the relevant entries of the config to modify that environment
---
--- may return `nil` and an error message if something could not be applied to the environment
function common.init_env_from_cfg(cfg: config.Config): tl.Env, string
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

---@desc
--- Load the config file and initialize a Teal environment using it
function common.load_cfg_env_report_errs(require_config: boolean, args: command.Command.Args): boolean, config.Config, tl.Env
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

