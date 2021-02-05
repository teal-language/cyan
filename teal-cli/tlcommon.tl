
-- Common things needed by most commands in addition to
-- wrappers around the tl api, since it isn't super stable

local config <const> = require("teal-cli.config")
local fs <const> = require("teal-cli.fs")
local log <const> = require("teal-cli.log")
local util <const> = require("teal-cli.util")
local cs <const> = require("teal-cli.colorstring")
local tl <const> = require("tl")

local map <const>, filter <const> = util.tab.map, util.tab.filter

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
function common.parse_file(path: string): ParseResult, any
   if not parse_cache[path] then
      local content <const>, err <const> = fs.read(path)
      if not content then
         return nil, err
      end
      local tks <const>, lex_errs <const> = tl.lex(content)
      if lex_errs then
         return nil, lex_errs
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

local type_check = tl.type_check as function(Node, tl.TypeCheckOptions)
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
      cs.colors.number, tostring(num_errors), 0,
      " ", category, (num_errors ~= 1 and "s" or ""),
      " in ",
      cs.colors.file, file, 0
   ):tostring()
end

local function prettify_error(e: tl.Error): string
   return cs.new(
      cs.colors.file, e.filename, 0,
      " ", cs.colors.number, tostring(e.y), 0,
      ":", cs.colors.number, tostring(e.x), 0,
      " ", e.msg
   ):tostring()
end

function common.report_errors(logfn: function(...: any), errs: {tl.Error}, file: string, category: string)
   logfn(
      common.make_error_header(file, #errs, category)
         .. "\n   "
         .. table.concat(map(errs, prettify_error), "\n   ")
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
   local werrors <const>, warnings <const> = filter(r.warnings, function(w: tl.Error): boolean
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

-- TODO: not a fan of this api, commands can just grab the arguments they need
-- from the argparse.Command.action method, and then use some util function to
-- merge the options with the config
local preloads <const>: {string} = {}
function common.add_to_preloads(mod: string)
   table.insert(preloads, mod)
end
function common.get_preloads(): {string}
   return preloads
end

local includes: {string} = {}
function common.add_to_includes(mod: string)
   table.insert(includes, mod)
end
function common.get_includes(): {string}
   return includes
end

function common.init_teal_env(gen_compat: boolean | tl.CompatMode, gen_target: tl.TargetMode): tl.Env
   return tl.init_env(false, gen_compat, gen_target)
end

local pretty_print_ast <const> = tl.pretty_print_ast as function(Node): string
function common.compile_ast(ast: Node): string
   return pretty_print_ast(ast)
end

function common.load_config_report_errs(path: string): config.Config
   local c <const>, errs <const>, warnings <const> = config.load(path)
   if #warnings > 0 then
      log.warn("in", tostring(path) .. "\n", table.concat(warnings, "\n"))
      return nil
   end
   if not c then
      if not errs[1]:match("No such file or directory$") then
         log.err("Error loading config from", tostring(path) .. "\n", table.unpack(errs))
      end
      return nil
   end
   return c
end

function common.type_check_and_load_file(path: string): function, string
   local result <const>, err <const> = tl.process(path)
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

return common

