local _tl_compat; if (tonumber((_VERSION or ''):match('[%d.]*$')) or 0) < 5.3 then local p, m = pcall(require, 'compat53.module'); if p then _tl_compat = m end end; local ipairs = _tl_compat and _tl_compat.ipairs or ipairs; local load = _tl_compat and _tl_compat.load or load; local package = _tl_compat and _tl_compat.package or package; local pairs = _tl_compat and _tl_compat.pairs or pairs; local string = _tl_compat and _tl_compat.string or string; local table = _tl_compat and _tl_compat.table or table




local command = require("cyan.command")
local config = require("cyan.config")
local fs = require("cyan.fs")
local log = require("cyan.log")
local util = require("cyan.util")
local cs = require("cyan.colorstring")
local tl = require("tl")

local map, filter, ivalues, set =
util.tab.map, util.tab.filter, util.tab.ivalues, util.tab.set


local Node = {}


local Token = {}








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
      local tks, errs = tl.lex(src)
      lex_cache[path] = { tks, errs }
      return tks, errs
   end
   return lex_cache[path][1], lex_cache[path][2]
end

local parse_program = tl.parse_program
local parse_cache = {}
function common.parse_file(path)
   if not parse_cache[path] then
      local tks, lex_errs, f_err = common.lex_file(path)
      if lex_errs or f_err then
         return nil, f_err or "Error lexing"
      end

      local errs = {}
      local _, ast, reqs = parse_program(tks, errs, path)

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
   return type_check(ast, opts)
end






function common.make_error_header(file, num_errors, category)
   return cs.new(
   cs.colors.emphasis, tostring(num_errors),
   " ", category, (num_errors ~= 1 and "s" or ""), { 0 },
   " in ",
   cs.colors.file, file, { 0 }):
   tostring()
end

local function highlight_token(tk)



   if cs.colors[tk.kind] then
      return cs.highlight(cs.colors[tk.kind], tk.tk):tostring()
   end
   return tk.tk == "$EOF$" and "" or tk.tk
end

local function count_tabs(str)
   return select(2, str:gsub("\t", ""))
end

local function prettify_line(s)
   local tks = tl.lex(s)
   local highlighted = {}
   local last_x = 1
   for _, tk in ipairs(tks) do

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

local function prettify_error(e)
   local ln = fs.get_line(e.filename, e.y)

   local tks = tl.lex(ln)
   local err_tk = {
      x = 1,
      tk = tl.get_token_at(tks, 1, e.x) or " ",
   }

   local str = cs.new(
   cs.colors.file, e.filename, { 0 },
   " ", cs.colors.error_number, tostring(e.y), { 0 },
   ":", cs.colors.error_number, tostring(e.x), { 0 })


   if e.tag then
      str:insert(" [", cs.colors.emphasis, e.tag, { 0 }, "]")
   end

   str:insert("\n")

   local num_len = #tostring(e.y)
   local prefix = (" "):rep(num_len) .. " | "

   str:insert(
   "   ", cs.colors.number, tostring(e.y), { 0 }, " | ", prettify_line(ln),
   "\n   ", prefix, (" "):rep(e.x + count_tabs(ln:sub(1, e.x)) * 3 - 1),
   cs.colors.error, ("^"):rep(#err_tk.tk), { 0 }, "\n   ",
   prefix, cs.colors.error, e.msg, { 0 })


   return str:tostring()
end



function common.report_errors(logfn, errs, file, category)
   logfn(
   common.make_error_header(file, #errs, category),
   "\n", table.concat(map(errs, prettify_error), "\n\n"))

end

function common.result_has_errors(r, c)
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
   local warning_error = set(c.warning_error or {})
   local werrors, warnings = filter(r.warnings or {}, function(w)
      return warning_error[w.tag]
   end)
   local function report(logfn, arr, category)
      if arr and #arr > 0 then
         common.report_errors(logfn, arr, r.filename, category)
         return false
      else
         return true
      end
   end

   report(log.warn, warnings, "warning")
   return report(log.err, werrors, "warning error") and
   report(log.err, r.type_errors, "type error")
end





function common.report_env_results(env, cfg)
   local ok = true
   for name in ivalues(env.loaded_order) do
      local res = env.loaded[name]
      ok = ok and common.report_result(res, cfg)
   end
   return ok
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

function common.type_check_and_load_file(path, env, c)
   local result, err = tl.process(path, env)
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