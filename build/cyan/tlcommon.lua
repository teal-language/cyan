local _tl_compat; if (tonumber((_VERSION or ''):match('[%d.]*$')) or 0) < 5.3 then local p, m = true, require('compat53.module'); if p then _tl_compat = m end end; local ipairs = _tl_compat and _tl_compat.ipairs or ipairs; local load = _tl_compat and _tl_compat.load or load; local package = _tl_compat and _tl_compat.package or package; local string = _tl_compat and _tl_compat.string or string; local table = _tl_compat and _tl_compat.table or table; local _tl_table_unpack = unpack or table.unpack




local config = require("cyan.config")
local decoration = require("cyan.decoration")
local fs = require("cyan.fs")
local log = require("cyan.log")
local util = require("cyan.util")
local tl = require("tl")

local filter, ivalues, set =
util.tab.filter, util.tab.ivalues, util.tab.set

local insert = table.insert



local ParseResult = {}






local common = {
   ParseResult = ParseResult,
}

local lex_cache = {}



function common.lex_file(path)
   if not lex_cache[path] then
      local src, read_err = fs.read(path)
      if not src then
         return nil, nil, read_err
      end
      local tks, errs = tl.lex(src, path)
      lex_cache[path] = { tks, errs }
      return tks, errs
   end
   return lex_cache[path][1], lex_cache[path][2]
end

local parse_cache = {}



function common.parse_file(path)
   if not parse_cache[path] then
      local tks, lex_errs, f_err = common.lex_file(path)
      if f_err then
         return nil, f_err
      end

      if #lex_errs > 0 then
         parse_cache[path] = {
            tks = tks,
            errs = lex_errs,
         }
      else
         local errs = {}
         local ast, reqs = tl.parse_program(tks, errs, path)

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






function common.make_error_header(file, num_errors, category)
   return {
      decoration.decorate(
      tostring(num_errors) .. " " .. category .. (num_errors ~= 1 and "s" or ""),
      decoration.scheme.emphasis),

      " in ",
      decoration.file_name(file),
   }
end

local function count_tabs(str)
   return select(2, str:gsub("\t", ""))
end

local tk_operator = decoration.copy(decoration.scheme.operator, { monospace = true })
local tk_keyword = decoration.copy(decoration.scheme.keyword, { monospace = true })
local tk_number = decoration.copy(decoration.scheme.number, { monospace = true })
local tk_string = decoration.copy(decoration.scheme.string, { monospace = true })

local decoration_by_content = {
   ["+"] = tk_operator,
   ["*"] = tk_operator,
   ["-"] = tk_operator,
   ["/"] = tk_operator,
   ["^"] = tk_operator,
   ["&"] = tk_operator,
   ["=="] = tk_operator,
   ["~="] = tk_operator,
   [">"] = tk_operator,
   [">="] = tk_operator,
   ["<"] = tk_operator,
   ["<="] = tk_operator,
   ["="] = tk_operator,
   ["~"] = tk_operator,
   ["#"] = tk_operator,
   ["as"] = tk_operator,
   ["is"] = tk_operator,

   ["type"] = tk_keyword,
   ["record"] = tk_keyword,
   ["enum"] = tk_keyword,
   ["and"] = tk_keyword,
   ["break"] = tk_keyword,
   ["do"] = tk_keyword,
   ["else"] = tk_keyword,
   ["elseif"] = tk_keyword,
   ["end"] = tk_keyword,
   ["false"] = tk_keyword,
   ["for"] = tk_keyword,
   ["function"] = tk_keyword,
   ["goto"] = tk_keyword,
   ["if"] = tk_keyword,
   ["in"] = tk_keyword,
   ["local"] = tk_keyword,
   ["nil"] = tk_keyword,
   ["not"] = tk_keyword,
   ["or"] = tk_keyword,
   ["repeat"] = tk_keyword,
   ["return"] = tk_keyword,
   ["then"] = tk_keyword,
   ["true"] = tk_keyword,
   ["until"] = tk_keyword,
   ["while"] = tk_keyword,
}

local decoration_by_kind = {
   string = tk_string,
   integer = tk_number,
   number = tk_number,
}

local monospace = { monospace = true }

local function decorate_token(tk)
   if decoration_by_content[tk.tk] then
      return decoration.decorate(tk.tk, decoration_by_content[tk.tk])
   end
   if decoration_by_kind[tk.kind] then
      return decoration.decorate(tk.tk, decoration_by_kind[tk.kind])
   end
   return decoration.decorate(tk.tk == "$EOF$" and "" or tk.tk, monospace)
end




function common.syntax_highlight(s)
   local buf = {}
   local tks = tl.lex(s, "")
   local last_x = 1
   for tk in ivalues(tks) do

      local ts = count_tabs(s:sub(last_x, tk.x - 1))
      local space_count =
      (ts > 0 and 3 * ts or 0) +
      (last_x < tk.x and tk.x - last_x or 0)
      insert(buf, decoration.decorate((" "):rep(space_count), monospace))
      insert(buf, decorate_token(tk))
      last_x = tk.x + #tk.tk
   end
   return buf
end

local function prettify_error(e)
   local ln = fs.get_line(e.filename, e.y)

   local tks = tl.lex(ln, "")
   local err_tk = {
      x = 1,
      tk = tl.get_token_at(tks, 1, e.x) or " ",
   }

   local buf = {
      decoration.file_name(e.filename),
      ":", decoration.decorate(tostring(e.y), decoration.scheme.error_number),
      ":", decoration.decorate(tostring(e.x), decoration.scheme.error_number),
   }

   if e.tag then
      insert(buf, " [")
      insert(buf, decoration.decorate(e.tag, decoration.scheme.emphasis))
      insert(buf, "]")
   end

   insert(buf, "\n")

   local num_len = #tostring(e.y)
   local prefix = decoration.decorate((" "):rep(num_len) .. " │ ", monospace)

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
      if type(v) == "string" then
         buf[i] = decoration.decorate(v, monospace)
      end
   end

   return buf
end



function common.report_errors(logger, errs, file, category)
   logger(_tl_table_unpack(common.make_error_header(file, #errs, category)))
   for e in ivalues(errs) do
      logger:cont(_tl_table_unpack(prettify_error(e)))
   end
   logger:cont("")
end



function common.result_has_errors(r, c)
   c = c or {}
   local warning_error = set(c.warning_error or {})
   local werrors = filter(r.warnings or {}, function(w)
      return warning_error[w.tag]
   end)

   local function has_errors(arr)
      return arr and #arr > 0
   end
   return has_errors(werrors) or has_errors(r.type_errors)
end







function common.report_result(r, c)
   if r.syntax_errors and #r.syntax_errors > 0 then
      common.report_errors(log.err, r.syntax_errors, r.filename, "syntax error")
      return false
   end

   c = c or {}
   local warning_error = set(c.warning_error or {})
   local disabled_warnings = set(c.disable_warnings or {})

   local werrors, warnings = filter(r.warnings or {}, function(w)
      return warning_error[w.tag]
   end)

   warnings = filter(warnings, function(w)
      return not disabled_warnings[w.tag]
   end)

   local function report(logger, arr, category)
      if arr and #arr > 0 then
         common.report_errors(logger, arr, r.filename, category)
         return false
      end
      return true
   end

   report(log.warn, warnings, "warning")
   local warning_errs = report(log.err, werrors, "warning error")
   local type_errs = report(log.err, r.type_errors, "type error")
   return warning_errs and type_errs
end





function common.report_env_results(env, cfg)
   cfg = cfg or {}
   local ok = true
   for name in ivalues(env.loaded_order) do
      local res = env.loaded[name]
      ok = ok and common.report_result(res, cfg)
   end
   return ok
end



function common.init_teal_env(gen_compat, gen_target, env_def)
   return tl.init_env(false, gen_compat, gen_target, { env_def })
end



function common.report_config_errors(errs, warnings)
   if warnings and #warnings > 0 then
      log.warn("in config:\n", table.concat(warnings, "\n"))
   end
   if errs and not errs[1]:match("No such file or directory$") then
      log.err("Error loading config:\n", table.concat(errs, "\n"))
      return true
   end
   return false
end

function common.type_check_and_load_file(path, env, c)
   local result, err = tl.check_file(path, env)
   if not result then
      return nil, err
   end
   if not common.report_result(result, c) then
      return nil
   end

   local generated, gen_err = tl.generate(result.ast, tl.target_from_lua_version(_VERSION))
   if not generated then
      return nil, gen_err
   end
   return load(generated, path, "t", _G)
end

local found_modules = {}


function common.search_module(name, search_dtl)
   local key = name .. ":" .. (search_dtl and "t" or "f")
   if not found_modules[key] then
      local found, fd = tl.search_module(name, search_dtl)
      if found then fd:close() end
      found_modules[key] = fs.path.new(found, false)
   end
   return found_modules[key]
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





function common.init_env_from_config(cfg)
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
