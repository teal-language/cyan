local _tl_compat; if (tonumber((_VERSION or ''):match('[%d.]*$')) or 0) < 5.3 then local p, m = true, require('compat53.module'); if p then _tl_compat = m end end; local pairs = _tl_compat and _tl_compat.pairs or pairs; local string = _tl_compat and _tl_compat.string or string; local table = _tl_compat and _tl_compat.table or table



local tl = require("tl")

local fs = require("cyan.fs")
local sandbox = require("cyan.sandbox")
local util = require("cyan.util")

local keys, sort, from, values, ivalues =
util.tab.keys, util.tab.sort_in_place, util.tab.from, util.tab.values, util.tab.ivalues



local Config = {}

























local config = {
   Config = Config,

   filename = "tlconfig.lua",
}

local function get_types_in_array(val, typefn)
   typefn = typefn or type
   local set = {}
   for v in ivalues(val) do
      set[typefn(v)] = true
   end
   return sort(from(keys(set)))
end

local function get_array_type(val, default)
   if type(val) ~= "table" then
      return type(val)
   end
   local ts = get_types_in_array(val, nil)
   if #ts == 0 then
      ts[1] = default
   end
   return "{" .. table.concat(ts, " | ") .. "}"
end

local function get_map_type(val, default_key, default_value)
   local key_types = get_types_in_array(from(keys(val)), nil)
   if #key_types == 0 then
      key_types[1] = default_key
   end


   local val_types = get_types_in_array(from(values(val)), get_array_type)
   if #val_types == 0 then
      val_types[1] = default_value
   end
   return table.concat(key_types, " | "), table.concat(val_types, " | ")
end



function config.is_config(c)
   if type(c) ~= "table" then
      return nil, { "Expected table, got " .. type(c) }, {}
   end

   local valid_keys = {
      build_dir = "string",
      source_dir = "string",

      include = "{string}",
      exclude = "{string}",

      dont_prune = "{string}",

      include_dir = "{string}",
      global_env_def = "string",
      scripts = "{string : {string : (string | {string}) }}",

      feat_arity = { ["off"] = true, ["on"] = true },
      gen_compat = { ["off"] = true, ["optional"] = true, ["required"] = true },
      gen_target = { ["5.1"] = true, ["5.3"] = true, ["5.4"] = true },

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
      elseif k == "scripts" then


         if type(v) ~= "table" then
            table.insert(errs, "Expected scripts to be {string : {string : string | {string}}}, got " .. type(v))
         end

         for script_key, value in pairs(v) do
            if not (type(script_key) == "string") then
               table.insert(errs, "Expected scripts to be {string : {string : string | {string}}}, got non-string key: " .. tostring(script_key))
               break
            end
            if not (type(value) == "table") then
               table.insert(errs, "Expected scripts to be {string : {string : string | {string}}}, got {string : " .. tostring(type(value)) .. "}")
               break
            end
            local key_type, value_type = get_map_type(value, "string", "string | {string}")
            if key_type ~= "string" or
               not (
               value_type == "string" or
               value_type == "{string}" or
               value_type == "string | {string}") then


               table.insert(
               errs,
               "Expected scripts to be {string: {string : string | {string}}}, got {string : {" ..
               key_type ..
               " : " ..
               value_type ..
               "}}")

               break
            end
         end
      else
         local valid = valid_keys[k]
         if not valid then
            table.insert(warnings, string.format("Unknown key '%s'", k))
         elseif type(valid) == "table" then
            if not valid[v] then


               local sorted = sort(from(keys(valid)))
               table.insert(errs, "Invalid value for " .. k .. ", expected one of: " .. table.concat(sorted, ", "))
            end
         else
            local vtype = get_array_type(v, valid:match("^{(.*)}$"))

            if vtype ~= valid then
               table.insert(errs, string.format("Expected %s to be a %s, got %s", k, valid, vtype))
            end
         end
      end
   end

   local function verify_non_absolute_path(key)
      local val = (c)[key]
      if type(val) ~= "string" then

         return
      end
      local as_path = fs.path.new(val, false)
      if as_path:is_absolute() then
         table.insert(errs, string.format("Expected a non-absolute path for %s, got %s", key, as_path:to_real_path()))
      end
   end
   verify_non_absolute_path("source_dir")
   verify_non_absolute_path("build_dir")

   local function verify_warnings(key)
      local arr = (c)[key]
      if arr then
         for warning in ivalues(arr) do
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
   end

   return c, nil, warnings
end



function config.find()
   return fs.search_parent_dirs(fs.cwd(), config.filename)
end



function config.load()
   local b, ferr = sandbox.from_file(config.filename, _G)
   if not b then
      return nil, { ferr }, {}
   end
   local ok, err = b:run(nil)
   if not ok then
      return nil, { err }, {}
   end
   local maybe_config = b:result()
   if maybe_config == nil then
      return nil, { "file returned nil" }, {}
   end

   local cfg, errs, warnings = config.is_config(maybe_config)
   if cfg then
      cfg.loaded_from = fs.cwd() .. config.filename
   end
   return cfg, errs, warnings
end

return config
