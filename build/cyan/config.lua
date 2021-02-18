local _tl_compat; if (tonumber((_VERSION or ''):match('[%d.]*$')) or 0) < 5.3 then local p, m = pcall(require, 'compat53.module'); if p then _tl_compat = m end end; local ipairs = _tl_compat and _tl_compat.ipairs or ipairs; local pairs = _tl_compat and _tl_compat.pairs or pairs; local string = _tl_compat and _tl_compat.string or string; local table = _tl_compat and _tl_compat.table or table


local tl = require("tl")
local sandbox = require("cyan.sandbox")
local util = require("cyan.util")
local command = require("cyan.command")

local keys, sort, from = util.tab.keys, util.tab.sort, util.tab.from

local Config = {}



















local config = {
   Config = Config,

   filename = "tlconfig.lua",
}

local function get_array_type(val, default)
   if type(val) ~= "table" then
      return type(val)
   end
   local set = {}
   for _, v in ipairs(val) do
      set[type(v)] = true
   end
   local ts = sort(from(keys(set)))
   if #ts == 0 then
      ts[1] = default
   end
   return "{" .. table.concat(ts, "|") .. "}"
end




function config.is_config(c)
   if type(c) ~= "table" then
      return nil, { "Expected table, got " .. type(c) }, {}
   end

   local valid_keys = {
      build_dir = "string",
      source_dir = "string",
      module_name = "string",

      include = "{string}",
      exclude = "{string}",
      files = "{string}",

      include_dir = "{string}",
      preload_modules = "{string}",

      gen_compat = { ["off"] = true, ["optional"] = true, ["required"] = true },
      gen_target = { ["5.1"] = true, ["5.3"] = true },

      disable_warnings = "{string}",
      warning_error = "{string}",
   }

   local errs = {}
   local warnings = {}

   for k, v in pairs(c) do
      if k == "externals" then
         if type(v) ~= "table" then
            table.insert(errs, "Expected externals to be a table, got " .. type(v))
         end
      else
         local valid = valid_keys[k]
         if not valid then
            table.insert(warnings, string.format("Unknown key '%s'", k))
         elseif type(valid) == "table" then
            if not valid[v] then
               table.insert(errs, "Invalid value for " .. k .. ", expected one of: " .. table.concat(sort(from(keys(valid))), ", "))
            end
         else
            local vtype = get_array_type(v, valid:match("^{(.*)}$"))
            if vtype ~= valid then
               table.insert(errs, string.format("Expected %s to be a %s, got %s", k, valid, vtype))
            end
         end
      end
   end



   local function verify_warnings(key)
      local arr = (config)[key]
      if arr then
         for _, warning in ipairs(arr) do
            if not tl.warning_kinds[warning] then
               table.insert(errs, string.format("Unknown warning in %s: %q", key, warning))
            end
         end
      end
   end
   verify_warnings("disable_warnings")
   verify_warnings("warning_error")

   if #errs > 0 then
      return nil, errs, warnings
   else
      return c, nil, warnings
   end
end

function config.load()
   local b, ferr = sandbox.from_file(config.filename, _G)
   if not b then
      return nil, { ferr }, {}
   end
   local ok, err = b:run()
   if not ok then
      return nil, { err }, {}
   end
   local maybe_config = b:result()
   if maybe_config == nil then
      return nil, { "file returned nil" }, {}
   end

   return config.is_config(maybe_config)
end

local function merge_list(a, b)
   a = a or {}
   b = b or {}
   for _, v in ipairs(b) do
      table.insert(a, v)
   end
   return a
end

function config.merge_with_args(cfg, args)
   args = args or {}

   cfg.include_dir = merge_list(cfg.include_dir, args.include_dir)
   cfg.disable_warnings = merge_list(cfg.disable_warnings, args.wdisable)
   cfg.warning_errors = merge_list(cfg.warning_errors, args.werror)
   cfg.preload_modules = merge_list(cfg.preload_modules, args.preload)

   cfg.gen_compat = args.gen_compat or cfg.gen_compat
   cfg.gen_target = args.gen_target or cfg.gen_target
end

function config.load_with_args(args)
   local cfg, err, warnings = config.load()
   if not cfg then
      return nil, err, {}
   end
   config.merge_with_args(cfg, args)
   return cfg, nil, warnings
end

return config
