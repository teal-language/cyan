
---@brief
--- Config loading API

local tl <const> = require("tl")
local sandbox <const> = require("cyan.sandbox")
local util <const> = require("cyan.util")
local command <const> = require("cyan.command")

local keys <const>, sort <const>, from <const> = util.tab.keys, util.tab.sort, util.tab.from

---@desc
--- The config data
local record Config
   build_dir: string
   source_dir: string
   include: {string}
   exclude: {string}
   preload_modules: {string}
   include_dir: {string}
   module_name: string
   scripts: {string}

   gen_compat: tl.CompatMode
   gen_target: tl.TargetMode
   disable_warnings: {tl.WarningKind}
   warning_error: {tl.WarningKind}

   -- externals field to allow for external tools to take entries in the config
   -- without our type checking complaining
   externals: {any:any}
end

local config <const> = {
   Config = Config,

   filename = "tlconfig.lua",
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
      preload_modules = "{string}",
      scripts = "{string}",

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

local function merge_list<T>(a: {T}, b: {T}): {T}
   a = a or {}
   b = b or {}
   for _, v in ipairs(b) do
      table.insert(a, v)
   end
   return a
end

---@desc
--- Merge the relevant entries of the provided command arguments into the provided config table
function config.merge_with_args(cfg: Config, args: command.Command.Args)
   args = args or {}

   cfg.include_dir = merge_list(cfg.include_dir, args.include_dir)
   cfg.disable_warnings = merge_list(cfg.disable_warnings, args.wdisable as {tl.WarningKind})
   cfg.warning_error = merge_list(cfg.warning_error, args.werror as {tl.WarningKind})
   cfg.preload_modules = merge_list(cfg.preload_modules, args.preload)

   cfg.gen_compat = args.gen_compat or cfg.gen_compat
   cfg.gen_target = args.gen_target or cfg.gen_target
end

function config.load_with_args(args: command.Command.Args): Config, {string}, {string}
   local cfg <const>, err <const>, warnings <const> = config.load()
   if not cfg then
      return nil, err, {}
   end
   config.merge_with_args(cfg, args)
   return cfg, nil, warnings
end

return config

