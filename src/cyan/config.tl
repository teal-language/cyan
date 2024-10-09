
---@brief
--- Config loading API

local tl <const> = require("tl")

local fs <const> = require("cyan.fs")
local sandbox <const> = require("cyan.sandbox")
local util <const> = require("cyan.util")

local keys <const>, sort <const>, from <const>, values <const>, ivalues <const>
   = util.tab.keys, util.tab.sort_in_place, util.tab.from, util.tab.values, util.tab.ivalues

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

   dont_prune: {string}

   -- { Command Name -> { Hook Name -> File(s) } }
   scripts: {string:{string:string|{string}}}

   feat_arity: tl.Feat
   gen_compat: tl.GenCompat
   gen_target: tl.GenTarget
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

local function get_types_in_array(val: {any}, typefn: function(any): string): {string}
   typefn = typefn or type
   local set <const> = {}
   for v in ivalues(val) do
      set[typefn(v)] = true
   end
   return sort(from(keys(set)))
end

local function get_array_type(val: any, default: string): string
   if type(val) ~= "table" then
      return type(val)
   end
   local ts <const> = get_types_in_array(val as {any}, nil)
   if #ts == 0 then
      ts[1] = default
   end
   return "{" .. table.concat(ts, " | ") .. "}"
end

local function get_map_type(val: table, default_key: string, default_value: string): string, string
   local key_types <const> = get_types_in_array(from(keys(val as {any:any})), nil)
   if #key_types == 0 then
      key_types[1] = default_key
   end

   -- bias values towards array types, since we probably won't use nested maps
   local val_types <const> = get_types_in_array(from(values(val as {any:any})), get_array_type as function(any): string)
   if #val_types == 0 then
      val_types[1] = default_value
   end
   return table.concat(key_types, " | "), table.concat(val_types, " | ")
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

   local errs <const>: {string} = {}
   local warnings <const>: {string} = {}

   for k, v in pairs(c as {string:any}) do
      if k == "externals" then
         if type(v) ~= "table" then
            table.insert(errs, "Expected externals to be a table, got " .. type(v))
         end
      elseif k == "scripts" then
         -- {string:{string:string|{string}}} is a bit much for our ad hoc checking functions
         -- just check manually
         if type(v) ~= "table" then
            table.insert(errs, "Expected scripts to be {string : {string : string | {string}}}, got " .. type(v))
         end

         for script_key, value in pairs(v as table) do
            if not script_key is string then
               table.insert(errs, "Expected scripts to be {string : {string : string | {string}}}, got non-string key: " .. tostring(script_key))
               break
            end
            if not value is table then
               table.insert(errs, "Expected scripts to be {string : {string : string | {string}}}, got {string : " .. tostring(type(value)) .. "}")
               break
            end
            local key_type, value_type = get_map_type(value as table, "string", "string | {string}")
            if key_type ~= "string"
               or not (
                  value_type == "string"
                     or value_type == "{string}"
                     or value_type == "string | {string}"
               )
            then
               table.insert(
                  errs,
                  "Expected scripts to be {string: {string : string | {string}}}, got {string : {"
                     .. key_type
                     .. " : "
                     .. value_type
                     .. "}}"
               )
               break
            end
         end
      else
         local valid <const> = valid_keys[k]
         if not valid then
            table.insert(warnings, string.format("Unknown key '%s'", k))
         elseif valid is {string:boolean} then
            if not valid[v as string] then
               -- TODO(tl bug): inlining this call produces this error?
               -- src/cyan/config.tl:161:117: argument 1: in map key: got string | number, expected string
               local sorted <const> = sort(from(keys(valid)))
               table.insert(errs, "Invalid value for " .. k .. ", expected one of: " .. table.concat(sorted, ", "))
            end
         else
            local vtype <const> = get_array_type(v, valid:match("^{(.*)}$"))

            if vtype ~= valid then
               table.insert(errs, string.format("Expected %s to be a %s, got %s", k, valid, vtype))
            end
         end
      end
   end

   local function verify_non_absolute_path(key: string)
      local val = (c as {string:string})[key]
      if type(val) ~= "string" then
         -- error already generated an error or wasn't provided
         return
      end
      local as_path = fs.path.new(val, false)
      if as_path:is_absolute() then
         table.insert(errs, string.format("Expected a non-absolute path for %s, got %s", key, as_path:to_real_path()))
      end
   end
   verify_non_absolute_path("source_dir")
   verify_non_absolute_path("build_dir")

   local function verify_warnings(key: string)
      local arr <const> = (c as {string:{string}})[key]
      if arr then
         for warning in ivalues(arr) do
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
   end

   return c as Config, nil, warnings
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
   local ok, err = b:run(nil)
   if not ok then
      return nil, {err}, {}
   end
   local maybe_config = b:result()
   if maybe_config == nil then
      return nil, {"file returned nil"}, {}
   end

   local cfg <const>, errs <const>, warnings <const> = config.is_config(maybe_config)
   if cfg then
      cfg.loaded_from = fs.cwd() .. config.filename
   end
   return cfg, errs, warnings
end

return config
