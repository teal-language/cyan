
-- Config loading API

local tl <const> = require("tl")
local sandbox <const> = require("teal-cli.sandbox")
local util <const> = require("teal-cli.util")

local keys <const>, sort <const>, from <const> = util.tab.keys, util.tab.sort, util.tab.from

local record Config
   build_dir: string
   source_dir: string
   files: {string}
   include: {string}
   exclude: {string}
   preload_modules: {string}
   enum GenCompat
      "off"
      "optional"
      "required"
   end
   gen_compat: GenCompat
   enum GenTarget
      "5.1"
      "5.3"
   end
   gen_target: GenTarget
   disable_warnings: {tl.WarningKind}
   warning_errors: {tl.WarningKind}

   -- externals field to allow for external tools to take entries in the config
   -- without our type checking complaining
   externals: {any:any}
end

local config <const> = {
   Config = Config,
}

local function get_array_type(val: any, default: string): string
   if type(val) ~= "table" then
      return type(val)
   end
   local set = {}
   for _, v in ipairs(val as {any}) do
      set[type(v)] = true
   end
   local ts = sort(from(keys(set)))
   if #ts == 0 then
      ts[1] = default
   end
   return "{" .. table.concat(ts, "|") .. "}"
end

---@return Config the config, given that c conforms to the type
---@return {string} errors about how c doesn't conform
---@return {string} warnings about entries in c
function config.is_config(c: any): Config, {string}, {string}
   if type(c) ~= "table" then
      return nil, {"Expected table, got " .. type(c)}, {}
   end

   local valid_keys <const>: {string:string|{string:boolean}} = {
      build_dir = "string",
      source_dir = "string",

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
            local vtype <const> = get_array_type(v, valid:match("^{(.*)}$"))
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

function config.load(path_to_file: string): Config, {string}, {string}
   local b, ferr = sandbox.from_file(path_to_file, _G)
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

