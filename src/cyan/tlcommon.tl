
---@brief
--- Common things needed by most commands in addition to
--- wrappers around the tl api, since it isn't super stable

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
   x: integer
   y: integer
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

local lex_cache <const>: {string:{{Token}, {tl.Error}}} = {}

---@desc
--- reads a file, calls `tl.lex` on its contents, caches and returns the results
function common.lex_file(path: string): {Token}, {tl.Error}, string
   if not lex_cache[path] then
      local src <const>, read_err <const> = fs.read(path)
      if not src then
         return nil, nil, read_err
      end
      local tks <const>, errs <const> = tl.lex(src, path) as ({Token}, {tl.Error})
      lex_cache[path] = {tks, errs}
      return tks, errs
   end
   return lex_cache[path][1], lex_cache[path][2]
end

local parse_program <const> = tl.parse_program as function({Token}, {tl.Error}, string): (Node, {string})
local parse_cache <const>: {string:ParseResult} = {}

---@desc
--- calls `lex_file`, parses the token stream, caches and returns the results
function common.parse_file(path: string): ParseResult, string
   if not parse_cache[path] then
      local tks <const>, lex_errs <const>, f_err <const> = common.lex_file(path)
      if f_err then
         return nil, f_err
      end

      if #lex_errs > 0 then
         parse_cache[path] = {
            tks = tks,
            errs = lex_errs,
         }
      else
         local errs <const>: {tl.Error} = {}
         local ast <const>, reqs <const> = parse_program(tks, errs, path)

         parse_cache[path] = {
            tks = tks,
            ast = ast,
            reqs = reqs,
            errs = errs,
         }
      end
   end
   return parse_cache[path]
end

local type_check <const> = tl.type_check as function(Node, tl.TypeCheckOptions): (tl.Result, string)
---@desc
--- Just type checks an ast
function common.type_check_ast(ast: Node, opts: tl.TypeCheckOptions): tl.Result, string
   return type_check(ast, opts)
end

---@desc
--- Creates a nicely colored header to log errors
---
--- For example `make_error_header("foo.tl", 10, "foo error")` would produce
--- something like `10 foo errors in foo.tl` with `10` and `foo.tl` highlighted
function common.make_error_header(file: string, num_errors: integer, category: string): cs.ColorString
   return cs.new(
      cs.colors.emphasis, tostring(num_errors),
      " ", category, (num_errors ~= 1 and "s" or ""), {0},
      " in ",
      cs.colors.file, file, {0}
   )
end

local highlights_by_kind <const>: {string:{integer}} = {
   string = cs.colors.string,
   integer = cs.colors.number,
   number = cs.colors.number,
}

local highlights_by_content <const>: {string:{integer}} = {
   ["+"] = cs.colors.op,
   ["*"] = cs.colors.op,
   ["-"] = cs.colors.op,
   ["/"] = cs.colors.op,
   ["^"] = cs.colors.op,
   ["&"] = cs.colors.op,
   ["=="] = cs.colors.op,
   ["~="] = cs.colors.op,
   [">"] = cs.colors.op,
   [">="] = cs.colors.op,
   ["<"] = cs.colors.op,
   ["<="] = cs.colors.op,
   ["="] = cs.colors.op,
   ["~"] = cs.colors.op,

   ["type"] = cs.colors.keyword,
   ["record"] = cs.colors.keyword,
   ["enum"] = cs.colors.keyword,
   ["and"] = cs.colors.keyword,
   ["break"] = cs.colors.keyword,
   ["do"] = cs.colors.keyword,
   ["else"] = cs.colors.keyword,
   ["elseif"] = cs.colors.keyword,
   ["end"] = cs.colors.keyword,
   ["false"] = cs.colors.keyword,
   ["for"] = cs.colors.keyword,
   ["function"] = cs.colors.keyword,
   ["goto"] = cs.colors.keyword,
   ["if"] = cs.colors.keyword,
   ["in"] = cs.colors.keyword,
   ["local"] = cs.colors.keyword,
   ["nil"] = cs.colors.keyword,
   ["not"] = cs.colors.keyword,
   ["or"] = cs.colors.keyword,
   ["repeat"] = cs.colors.keyword,
   ["return"] = cs.colors.keyword,
   ["then"] = cs.colors.keyword,
   ["true"] = cs.colors.keyword,
   ["until"] = cs.colors.keyword,
   ["while"] = cs.colors.keyword,
}

local function highlight_token(tk: Token): cs.ColorString
   if highlights_by_content[tk.tk] then
      return cs.highlight(highlights_by_content[tk.tk], tk.tk)
   elseif highlights_by_kind[tk.kind] then
      return cs.highlight(highlights_by_kind[tk.kind], tk.tk)
   end
   return cs.new(tk.tk == "$EOF$" and "" or tk.tk)
end

local function count_tabs(str: string): integer
   return select(2, str:gsub("\t", "")) as integer
end

local function prettify_line(s: string): cs.ColorString
   local tks <const> = tl.lex(s) as {Token}
   local highlighted <const> = cs.new()
   local last_x = 1
   for _, tk in ipairs(tks) do
      -- account for tabs
      local ts = count_tabs(s:sub(last_x, tk.x - 1))
      if ts > 0 then
         local spaces = 3 * ts
         highlighted:append((" "):rep(spaces))
      end
      if last_x < tk.x then
         highlighted:append((" "):rep(tk.x - last_x))
      end
      highlighted:append(highlight_token(tk))
      last_x = tk.x + #tk.tk
   end
   return highlighted
end

local function prettify_error(e: tl.Error): cs.ColorString
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

   str:insert("   ", cs.colors.number, tostring(e.y), {0}, " | ")
   str:append(prettify_line(ln))
   str:insert(
      "\n   ", prefix, (" "):rep(e.x + count_tabs(ln:sub(1, e.x)) * 3 - 1),
      cs.colors.error, ("^"):rep(#err_tk.tk), {0}, "\n   ",
      prefix, cs.colors.error, e.msg, {0}
   )

   return str
end

---@desc
--- Logs an array of errors with nice colors and a header generated by `make_error_header`
function common.report_errors(logger: log.Logger, errs: {tl.Error}, file: string, category: string)
   logger(
      common.make_error_header(file, #errs, category),
      "\n",
      table.unpack(util.tab.intersperse(map(errs, prettify_error), "\n\n" as cs.ColorString))
   )
end

---@desc
--- Returns whether or not the result has errors. Doesn't print/log anything
function common.result_has_errors(r: tl.Result, c: config.Config): boolean
   c = c or {}
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
--- Returns false if there were any errors. This includs warnings that were
--- promoted to errors and doesn't include warnings that were not promoted to
--- errors.
function common.report_result(r: tl.Result, c: config.Config): boolean
   if r.syntax_errors and #r.syntax_errors > 0 then
      common.report_errors(log.err, r.syntax_errors, r.filename, "syntax error")
      return false
   end

   c = c or {}
   local warning_error <const> = set(c.warning_error or {})
   local disabled_warnings <const> = set(c.disable_warnings or {})

   local werrors <const>, warnings = filter(r.warnings or {}, function(w: tl.Error): boolean
      return warning_error[w.tag]
   end)

   warnings = filter(warnings, function(w: tl.Error): boolean
      return not disabled_warnings[w.tag]
   end)

   local function report(logger: log.Logger, arr: {tl.Error}, category: string): boolean
      if arr and #arr > 0 then
         common.report_errors(logger, arr, r.filename, category)
         return false
      else
         return true
      end
   end

   report(log.warn, warnings, "warning")
   local warning_errs <const> = report(log.err, werrors, "warning error")
   local type_errs <const> = report(log.err, r.type_errors, "type error")
   return warning_errs and type_errs
end

---@desc
--- Report all errors from a tl.Env
---
--- Returns false when errors were reported
function common.report_env_results(env: tl.Env, cfg: config.Config): boolean
   cfg = cfg or {}
   local ok = true
   for name in ivalues(env.loaded_order) do
      local res = env.loaded[name]
      ok = ok and common.report_result(res, cfg)
   end
   return ok
end

---@desc
--- Initialize a strict Teal environment
function common.init_teal_env(gen_compat: boolean | tl.CompatMode, gen_target: tl.TargetMode, env_def: string): tl.Env, string
   return tl.init_env(false, gen_compat, gen_target, {env_def})
end

local pretty_print_ast <const> = tl.pretty_print_ast as function(Node, tl.TargetMode): (string, string)
function common.compile_ast(ast: Node, mode: tl.TargetMode): string, string
   return pretty_print_ast(ast, mode)
end

---@desc
--- use `log.warn` and `log.err` to report errors and warnings from `config.load`
function common.report_config_errors(errs: {string}, warnings: {string}): boolean
   if warnings and #warnings > 0 then
      log.warn("in config:\n", table.concat(warnings, "\n"))
   end
   if errs and not errs[1]:match("No such file or directory$") then
      log.err("Error loading config:\n", table.concat(errs, "\n"))
      return true
   end
   return false
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
function common.init_env_from_config(cfg: config.Config): tl.Env, string
   cfg = cfg or {}
   for dir in ivalues(cfg.include_dir or {}) do
      common.prepend_to_lua_path(dir)
   end

   if cfg.source_dir and cfg.module_name then
      common.add_module_substitute(cfg.source_dir, cfg.module_name)
   end

   local env, err = common.init_teal_env(cfg.gen_compat, cfg.gen_target, cfg.global_env_def)
   if not env then
      return nil, err
   end

   return env
end

return common
