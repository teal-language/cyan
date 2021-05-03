local _tl_compat; if (tonumber((_VERSION or ''):match('[%d.]*$')) or 0) < 5.3 then local p, m = pcall(require, 'compat53.module'); if p then _tl_compat = m end end; local ipairs = _tl_compat and _tl_compat.ipairs or ipairs; local pairs = _tl_compat and _tl_compat.pairs or pairs; local string = _tl_compat and _tl_compat.string or string; local table = _tl_compat and _tl_compat.table or table



local tl = require("tl")

local fs = require("cyan.fs")
local sandbox = require("cyan.sandbox")
local util = require("cyan.util")

local keys, sort, from, values =
util.tab.keys, util.tab.sort, util.tab.from, util.tab.values



local Config = {}





















local config = {
   Config = Config,

   filename = "tlconfig.lua",
}






local function get_types_in_array(val, typefn)
   typefn = typefn or type
   local set = {}
   for _, v in ipairs(val) do
      set[typefn(v)] = true
   end
   return sort(from(keys(set)))
end

local function get_array_type(val, default)
   if type(val) ~= "table" then
      return type(val)
   end
   local ts = get_types_in_array(val)
   if #ts == 0 then
      ts[1] = default
   end
   return "{" .. table.concat(ts, "|") .. "}"
end

local function get_map_type(val, default_key, default_value)
   if type(val) ~= "table" then
      return type(val)
   end

   local key_types = get_types_in_array(from(keys(val)))
   if #key_types == 0 then
      key_types[1] = default_key
   end


   local val_types = get_types_in_array(from(values(val)), get_array_type)
   if #val_types == 0 then
      val_types[1] = default_value
   end
   return "{" .. table.concat(key_types, "|") .. ":" .. table.concat(val_types, "|") .. "}"
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

      include_dir = "{string}",
      global_env_def = "string",
      scripts = "{string:{string}}",

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
            local vtype = valid:find(":") and
            get_map_type(v, valid:match("^{(.*):(.*)}$")) or
            get_array_type(v, valid:match("^{(.*)}$"))

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



function config.find()
   return fs.search_parent_dirs(fs.cwd(), config.filename)
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

return config