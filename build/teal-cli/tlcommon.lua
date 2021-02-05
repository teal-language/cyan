local _tl_compat; if (tonumber((_VERSION or ''):match('[%d.]*$')) or 0) < 5.3 then local p, m = pcall(require, 'compat53.module'); if p then _tl_compat = m end end; local load = _tl_compat and _tl_compat.load or load; local string = _tl_compat and _tl_compat.string or string; local table = _tl_compat and _tl_compat.table or table; local _tl_table_unpack = unpack or table.unpack



local config = require("teal-cli.config")
local fs = require("teal-cli.fs")
local log = require("teal-cli.log")
local util = require("teal-cli.util")
local cs = require("teal-cli.colorstring")
local tl = require("tl")

local map, filter = util.tab.map, util.tab.filter


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
         return nil, lex_errs
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
   cs.colors.number, tostring(num_errors), 0,
   " ", category, (num_errors ~= 1 and "s" or ""),
   " in ",
   cs.colors.file, file, 0):
   tostring()
end

local function prettify_error(e)
   return cs.new(
   cs.colors.file, e.filename, 0,
   " ", cs.colors.number, tostring(e.y), 0,
   ":", cs.colors.number, tostring(e.x), 0,
   " ", e.msg):
   tostring()
end

function common.report_errors(logfn, errs, file, category)
   logfn(
   common.make_error_header(file, #errs, category) ..
   "\n   " ..
   table.concat(map(errs, prettify_error), "\n   "))

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
   local werrors, warnings = filter(r.warnings, function(w)
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




local preloads = {}
function common.add_to_preloads(mod)
   table.insert(preloads, mod)
end
function common.get_preloads()
   return preloads
end

local includes = {}
function common.add_to_includes(mod)
   table.insert(includes, mod)
end
function common.get_includes()
   return includes
end

function common.init_teal_env(gen_compat, gen_target)
   return tl.init_env(false, gen_compat, gen_target)
end

local pretty_print_ast = tl.pretty_print_ast
function common.compile_ast(ast)
   return pretty_print_ast(ast)
end

function common.load_config_report_errs(path)
   local c, errs, warnings = config.load(path)
   if #warnings > 0 then
      log.warn("in", tostring(path) .. "\n", table.concat(warnings, "\n"))
      return nil
   end
   if not c then
      if not errs[1]:match("No such file or directory$") then
         log.err("Error loading config from", tostring(path) .. "\n", _tl_table_unpack(errs))
      end
      return nil
   end
   return c
end

function common.type_check_and_load_file(path)
   local result, err = tl.process(path)
   if not common.report_result(path, result) then
      return nil
   end
   return load(
   pretty_print_ast(result.ast),
   path,
   "t",
   _G)

end

return common
