local _tl_compat; if (tonumber((_VERSION or ''):match('[%d.]*$')) or 0) < 5.3 then local p, m = true, require('compat53.module'); if p then _tl_compat = m end end; local assert = _tl_compat and _tl_compat.assert or assert; local ipairs = _tl_compat and _tl_compat.ipairs or ipairs; local pairs = _tl_compat and _tl_compat.pairs or pairs; local string = _tl_compat and _tl_compat.string or string; local table = _tl_compat and _tl_compat.table or table; local type = type



local tl = require("tl")

local fs = require("cyan.fs")
local sandbox = require("cyan.sandbox")
local util = require("cyan.util")
local lexical_path = require("lexical-path")

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

local function copy(x, no_tables)
   if type(x) == "table" then
      assert(not no_tables)
      local result = {}
      for k, v in pairs(x) do
         result[copy(k, true)] = copy(v)
      end
      return result
   end
   return x
end

local function ordinal_indicator(n)
   local mod_100 = n % 100
   if 11 <= mod_100 and mod_100 <= 13 then
      return "th"
   end

   local digit = n % 10
   if digit == 1 then return "st" end
   if digit == 2 then return "nd" end
   if digit == 3 then return "rd" end
   return "th"
end







local function check_path(p)
   local as_path, norm = lexical_path.from_unix(p)
   if as_path.is_absolute then return as_path, "absolute" end
   if norm ~= "normal" then return as_path, "non-normal" end
   if as_path[1] == ".." then return as_path, "traversal" end
   return as_path
end



function config.is_config(c_in)
   if type(c_in) ~= "table" then
      return nil, { "Expected table, got " .. type(c_in) }, {}
   end
   local c = c_in

   local valid_keys = {
      build_dir = "string",
      source_dir = "string",

      include = "{string}",
      exclude = "{string}",

      dont_prune = "{string}",

      include_dir = "{string}",
      global_env_def = "string",
      scripts = "{ string : { string : (string | {string}) } }",

      feat_arity = { ["off"] = true, ["on"] = true },
      gen_compat = { ["off"] = true, ["optional"] = true, ["required"] = true },
      gen_target = { ["5.1"] = true, ["5.3"] = true, ["5.4"] = true },

      disable_warnings = "{string}",
      warning_error = "{string}",

      externals = "{string:any}",
   }

   local errs = {}
   local warnings = {}

   local result = {}

   local function to_path(src, for_what)
      local as_path, bad = check_path(src)

      if bad == "absolute" then
         table.insert(errs, string.format("Expected a non-absolute path for %s, got %s", for_what, as_path:to_string("/")))
      elseif bad == "non-normal" then
         table.insert(errs, string.format("Expected a normalized path for %s, %s should be %s", for_what, src, as_path:to_string("/")))
      elseif bad == "traversal" then
         table.insert(errs, string.format("Expected %s to not go outside the directory of %s, got %s", for_what, config.filename, as_path:to_string("/")))
      end

      return as_path
   end

   for k, v in pairs(c) do
      if k == "externals" then
         if type(v) ~= "table" then
            table.insert(errs, "Expected externals to be a table, got " .. type(v))
         end
      elseif k == "scripts" then


         if type(v) ~= "table" then
            table.insert(errs, "Expected scripts to be {string : {string : string | {string}}}, got " .. type(v))
         end

         result.scripts = {}

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
            result.scripts[script_key] = {}
            for hook_name, path_or_paths in pairs(value) do
               if type(hook_name) == "string" then
                  local t = {}
                  result.scripts[script_key][hook_name] = t
                  local paths = type(path_or_paths) == "table" and path_or_paths or { path_or_paths }
                  for i, path in ipairs(paths) do
                     if type(path) == "string" then
                        t[i] = to_path(path, ("%s%s %s hook"):format(i, ordinal_indicator(i), hook_name))
                     end
                  end
               end
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
      local as_path = to_path(val, key);
      (result)[key] = as_path
   end
   verify_non_absolute_path("source_dir")
   verify_non_absolute_path("build_dir")

   if c.include_dir then
      result.include_dir = {}
      for i, v in ipairs(c.include_dir) do
         if type(v) == "string" then
            result.include_dir[i] = to_path(v, ("%s%s include_dir entry"):format(i, ordinal_indicator(i)))
         end
      end
   end

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

   if c.source_dir and type(c.source_dir) == "string" and c.include_dir and type(c.include_dir) == "table" then
      for included in ivalues(c.include_dir) do
         if c.source_dir == included then
            table.insert(warnings, "source_dir is included by default and does not need to be in include_dir")
            break
         end
      end
   end

   if #errs > 0 then
      return nil, errs, warnings
   end

   result.externals = c.externals

   if type(c.include) == "table" then
      result.include = {}
      for i, patt in ipairs(c.include) do
         if type(patt) == "string" then
            result.include[i] = lexical_path.parse_pattern(patt)
         end
      end
   end

   if type(c.exclude) == "table" then
      result.exclude = {}
      for i, patt in ipairs(c.exclude) do
         if type(patt) == "string" then
            result.exclude[i] = lexical_path.parse_pattern(patt)
         end
      end
   end

   for k in pairs(valid_keys) do
      if (result)[k] == nil then
         (result)[k] = copy(c[k])
      end
   end

   return result, nil, warnings
end



function config.find()
   return fs.search_parent_dirs(fs.current_directory(), config.filename)
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
      cfg.loaded_from = fs.current_directory() .. config.filename
   end
   return cfg, errs, warnings
end

return config
