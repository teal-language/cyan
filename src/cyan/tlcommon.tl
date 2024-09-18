
---@brief
--- Common things needed by most commands in addition to
--- wrappers around the tl api, since it isn't super stable

local config <const> = require("cyan.config")
local decoration <const> = require("cyan.decoration")
local fs <const> = require("cyan.fs")
local log <const> = require("cyan.log")
local util <const> = require("cyan.util")
local tl <const> = require("tl")

local filter <const>, ivalues <const>, set <const>
   = util.tab.filter, util.tab.ivalues, util.tab.set

local insert <const> = table.insert

---@desc
--- The result from parsing source code including the tokens, ast, calls to require, and errors
local record ParseResult
   tks: {tl.Token}
   ast: tl.Node
   reqs: {string}
   errs: {tl.Error}
end

local common <const> = {
   ParseResult = ParseResult,
}

local lex_cache <const>: {string:{{tl.Token}, {tl.Error}}} = {}

---@desc
--- reads a file, calls `tl.lex` on its contents, caches and returns the results
function common.lex_file(path: string): {tl.Token}, {tl.Error}, string
   if not lex_cache[path] then
      local src <const>, read_err <const> = fs.read(path)
      if not src then
         return nil, nil, read_err
      end
      local tks <const>, errs <const> = tl.lex(src, path) as ({tl.Token}, {tl.Error})
      lex_cache[path] = {tks, errs}
      return tks, errs
   end
   return lex_cache[path][1], lex_cache[path][2]
end

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
         local ast <const>, reqs <const> = tl.parse_program(tks, errs, path)

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

---@desc
--- Creates a nicely colored header to log errors
---
--- For example `make_error_header("foo.tl", 10, "foo error")` would produce
--- something like `10 foo errors in foo.tl` with `10` and `foo.tl` highlighted
function common.make_error_header(file: string, num_errors: integer, category: string): {string | decoration.Decorated}
   return {
      decoration.decorate(
         tostring(num_errors) .. " " .. category .. (num_errors ~= 1 and "s" or ""),
         decoration.scheme.emphasis
      ),
      " in ",
      decoration.file_name(file)
   }
end

local function count_tabs(str: string): integer
   return select(2, str:gsub("\t", "")) as integer
end

local tk_operator <const> = decoration.copy(decoration.scheme.operator, { monospace = true })
local tk_keyword <const> = decoration.copy(decoration.scheme.keyword, { monospace = true })
local tk_number <const> = decoration.copy(decoration.scheme.number, { monospace = true })
local tk_string <const> = decoration.copy(decoration.scheme.string, { monospace = true })

local decoration_by_content <const>: {string:decoration.Decoration} = {
   ["+"]        = tk_operator,
   ["*"]        = tk_operator,
   ["-"]        = tk_operator,
   ["/"]        = tk_operator,
   ["^"]        = tk_operator,
   ["&"]        = tk_operator,
   ["=="]       = tk_operator,
   ["~="]       = tk_operator,
   [">"]        = tk_operator,
   [">="]       = tk_operator,
   ["<"]        = tk_operator,
   ["<="]       = tk_operator,
   ["="]        = tk_operator,
   ["~"]        = tk_operator,
   ["#"]        = tk_operator,
   ["as"]       = tk_operator,
   ["is"]       = tk_operator,

   ["type"]     = tk_keyword,
   ["record"]   = tk_keyword,
   ["enum"]     = tk_keyword,
   ["and"]      = tk_keyword,
   ["break"]    = tk_keyword,
   ["do"]       = tk_keyword,
   ["else"]     = tk_keyword,
   ["elseif"]   = tk_keyword,
   ["end"]      = tk_keyword,
   ["false"]    = tk_keyword,
   ["for"]      = tk_keyword,
   ["function"] = tk_keyword,
   ["goto"]     = tk_keyword,
   ["if"]       = tk_keyword,
   ["in"]       = tk_keyword,
   ["local"]    = tk_keyword,
   ["nil"]      = tk_keyword,
   ["not"]      = tk_keyword,
   ["or"]       = tk_keyword,
   ["repeat"]   = tk_keyword,
   ["return"]   = tk_keyword,
   ["then"]     = tk_keyword,
   ["true"]     = tk_keyword,
   ["until"]    = tk_keyword,
   ["while"]    = tk_keyword,
}

local decoration_by_kind <const>: {string:decoration.Decoration} = {
   string  = tk_string,
   integer = tk_number,
   number  = tk_number,
}

local monospace <const>: decoration.Decoration = { monospace = true }

local function decorate_token(tk: tl.Token): decoration.Decorated
   if decoration_by_content[tk.tk] then
      return decoration.decorate(tk.tk, decoration_by_content[tk.tk])
   end
   if decoration_by_kind[tk.kind] then
      return decoration.decorate(tk.tk, decoration_by_kind[tk.kind])
   end
   return decoration.decorate(tk.tk == "$EOF$" and "" or tk.tk, monospace)
end

---@desc
--- Takes Teal or Lua code and returns a decorated string highlighting things
--- like keywords, operators, and more.
function common.syntax_highlight(s: string): {decoration.Decorated}
   local buf <const>: {decoration.Decorated} = {}
   local tks <const> = tl.lex(s, "")
   local last_x = 1
   for tk in ivalues(tks) do
      -- account for tabs
      local ts <const> = count_tabs(s:sub(last_x, tk.x - 1))
      local space_count <const> =
         (ts > 0 and 3 * ts or 0)
         + (last_x < tk.x and tk.x - last_x or 0)
      insert(buf, decoration.decorate((" "):rep(space_count), monospace))
      insert(buf, decorate_token(tk))
      last_x = tk.x + #tk.tk
   end
   return buf
end

local function prettify_error(e: tl.Error): {decoration.Decorated}
   local ln <const> = fs.get_line(e.filename, e.y)

   local tks <const> = tl.lex(ln, "")
   local err_tk <const> = {
      x = 1,
      tk = tl.get_token_at(tks, 1, e.x) or " "
   }

   local buf <const>: {decoration.Decorated | string} = {
      decoration.file_name(e.filename),
      ":", decoration.decorate(tostring(e.y), decoration.scheme.error_number),
      ":", decoration.decorate(tostring(e.x), decoration.scheme.error_number)
   }

   if e.tag then
      insert(buf, " [")
      insert(buf, decoration.decorate(e.tag, decoration.scheme.emphasis))
      insert(buf, "]")
   end

   insert(buf, "\n")

   local num_len <const> = #tostring(e.y)
   local prefix <const> = decoration.decorate((" "):rep(num_len) .. " │ ", monospace)

   insert(buf, decoration.decorate("   ", monospace))
   insert(buf, decoration.decorate(tostring(e.y), decoration.copy(decoration.scheme.number, monospace)))
   insert(buf, decoration.decorate(" │ ", monospace))
   for v in ivalues(common.syntax_highlight(ln)) do
      insert(buf, v)
   end

   insert(buf, decoration.decorate("\n   ", monospace))
   insert(buf, prefix)
   insert(buf, decoration.decorate((" "):rep(e.x + count_tabs(ln:sub(1, e.x)) * 3 - 1), monospace))
   insert(buf, decoration.decorate(("^"):rep(#err_tk.tk), decoration.copy(decoration.scheme.error, monospace)))
   insert(buf, decoration.decorate("\n   ", monospace))
   insert(buf, prefix)
   insert(buf, decoration.decorate(e.msg, decoration.scheme.error))

   for i, v in ipairs(buf) do
      if v is string then
         buf[i] = decoration.decorate(v, monospace)
      end
   end

   return buf as {decoration.Decorated}
end

---@desc
--- Logs an array of errors with nice colors and a header generated by `make_error_header`
function common.report_errors(logger: log.Logger, errs: {tl.Error}, file: string, category: string)
   logger(table.unpack(common.make_error_header(file, #errs, category)))
   for e in ivalues(errs) do
      logger:cont(table.unpack(prettify_error(e)))
   end
   logger:cont("")
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
      end
      return true
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
function common.init_teal_env(gen_compat: boolean | tl.GenCompat, gen_target: tl.GenTarget, env_def: string): tl.Env, string
   return tl.init_env(false, gen_compat, gen_target, {env_def})
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
   local result <const>, err <const> = tl.check_file(path, env)
   if not result then
      return nil, err
   end
   if not common.report_result(result, c) then
      return nil
   end

   local generated <const>, gen_err <const> = tl.generate(result.ast, tl.target_from_lua_version(_VERSION))
   if not generated then
      return nil, gen_err
   end
   return load(generated, path, "t", _G as table)
end

local found_modules: {string:fs.Path} = {}
---@desc
--- A wrapper around `tl.search_module` but, returns an `fs.Path` and will cache results
function common.search_module(name: string, search_dtl?: boolean): fs.Path
   local key <const> = name .. ":" .. (search_dtl and "t" or "f")
   if not found_modules[key] then
      local found, fd = tl.search_module(name, search_dtl)
      if found then fd:close() end
      found_modules[key] = fs.path.new(found, false)
   end
   return found_modules[key]
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

---@desc
--- Initialize a strict Teal environment, using the relevant entries of the config to modify that environment
---
--- may return `nil` and an error message if something could not be applied to the environment
function common.init_env_from_config(cfg: config.Config): tl.Env, string
   cfg = cfg or {}
   for dir in ivalues(cfg.include_dir or {}) do
      common.prepend_to_lua_path(dir)
   end

   local env, err = common.init_teal_env(cfg.gen_compat, cfg.gen_target, cfg.global_env_def)
   if not env then
      return nil, err
   end

   return env
end

return common
