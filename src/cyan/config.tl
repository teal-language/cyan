
---@brief
--- Config loading API

local tl <const> = require("tl")

local fs <const> = require("cyan.fs")
local sandbox <const> = require("cyan.sandbox")
local util <const> = require("cyan.util")

local keys <const>, sort <const>, from <const>, values <const>
   = util.tab.keys, util.tab.sort_in_place, util.tab.from, util.tab.values

---@desc
--- The config data
local record Config
   loaded_from: fs.Path

   build_dir: string
   source_dir: string
   include: {string}
   exclude: {string}
   global_env_def: string
   include_dir: {string}
   module_name: string
   scripts: {string:{string}}

   gen_compat: tl.CompatMode
   gen_target: tl.TargetMode
   disable_warnings: {tl.WarningKind}
   warning_error: {tl.WarningKind}

   -- externals field to allow for external tools to take entries in the config
   -- without our type checking complaining
   externals: {string:any}
end

local config <const> = {
   Config = Config,

   filename = "tlconfig.lua",
}

-- TODO: Get Teal itself to do this typechecking for us
--
--       Ideally, we could somehow use teal to tell us the types inferred in the config file
--       For now, we just try to make a biased `type` function that reports nicer table types

local function get_types_in_array(val: {any}, typefn: function(any): string): {string}
   typefn = typefn or type
   local set <const> = {}
   for _, v in ipairs(val) do
      set[typefn(v)] = true
   end
   return sort(from(keys(set)))
end

local function get_array_type(val: any, default: string): string
   if type(val) ~= "table" then
      return type(val)
   end
   local ts <const> = get_types_in_array(val as {any})
   if #ts == 0 then
      ts[1] = default
   end
   return "{" .. table.concat(ts, "|") .. "}"
end

local function get_map_type(val: any, default_key: string, default_value: string): string
   if type(val) ~= "table" then
      return type(val)
   end

   local key_types <const> = get_types_in_array(from(keys(val as {any:any})))
   if #key_types == 0 then
      key_types[1] = default_key
   end

   -- bias values towards array types, since we probably won't use nested maps
   local val_types <const> = get_types_in_array(from(values(val as {any:any})), get_array_type as function(any): string)
   if #val_types == 0 then
      val_types[1] = default_value
   end
   return "{" .. table.concat(key_types, "|") .. ":" .. table.concat(val_types, "|") .. "}"
end

---@desc
--- Check if `c` conforms to the `Config` type and return any errors and warnings generated from checking
function config.is_config(c: any): Config, {string}, {string}
   if type(c) ~= "table" then
      return nil, {"Expected table, got " .. type(c)}, {}
   end

   local valid_keys <const>: {string:string|{string:boolean}} = {
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

   local errs <const>: {string} = {}
   local warnings <const>: {string} = {}

   for k, v in pairs(c as {string:any}) do
      if k == "externals" then
         if type(v) ~= "table" then
            table.insert(errs, "Expected externals to be a table, got " .. type(v))
         end
      else
         local valid <const> = valid_keys[k]
         if not valid then
            table.insert(warnings, string.format("Unknown key '%s'", k))
         elseif valid is {string:boolean} then
            if not valid[v as string] then
               table.insert(errs, "Invalid value for " .. k .. ", expected one of: " .. table.concat(sort(from(keys(valid))), ", "))
            end
         else
            local vtype <const> = valid:find(":")
               and get_map_type(v, valid:match("^{(.*):(.*)}$"))
               or get_array_type(v, valid:match("^{(.*)}$"))

            if vtype ~= valid then
               table.insert(errs, string.format("Expected %s to be a %s, got %s", k, valid, vtype))
            end
         end
      end
   end

   -- TODO: check souce and build dirs for absolute paths

   local function verify_warnings(key: string)
      local arr <const> = (config as {string:{string}})[key]
      if arr then
         for _, warning in ipairs(arr) do
            if not tl.warning_kinds[warning as tl.WarningKind] then
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
      return c as Config, nil, warnings
   end
end

---@desc
--- Find `config.filename` in the current or parent directories
function config.find(): fs.Path
   return fs.search_parent_dirs(fs.cwd(), config.filename)
end

---@desc
--- Try to load `tlconfig.lua` in the current directory
function config.load(): Config, {string}, {string}
   local b, ferr = sandbox.from_file(config.filename, _G)
   if not b then
      return nil, {ferr}, {}
   end
   local ok, err = b:run()
   if not ok then
      return nil, {err}, {}
   end
   local maybe_config = b:result()
   if maybe_config == nil then
      return nil, {"file returned nil"}, {}
   end

   return config.is_config(maybe_config)
end

return config
