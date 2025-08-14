local ivalues <const> = require("cyan.util").tab.ivalues
local lexical_path <const> = require("lexical-path")

local record Dependency
   name: string
   url: string
end

local deps: {Dependency} = {
   { name = "argparse", url = "https://raw.githubusercontent.com/teal-language/teal-types/master/types/argparse/argparse.d.tl" },
   { name = "lfs",      url = "https://raw.githubusercontent.com/teal-language/teal-types/master/types/luafilesystem/lfs.d.tl" },
   { name = "busted",   url = "https://raw.githubusercontent.com/teal-language/teal-types/refs/heads/master/types/busted/busted.d.tl" },

   -- TODO: these make heavy use of arity
   -- { name = "luassert", url = "https://raw.githubusercontent.com/teal-language/teal-types/refs/heads/master/types/luassert/luassert/assert.d.tl" },

   -- TODO: actually upload this
   -- { name = "system",   url = "https://raw.githubusercontent.com/teal-language/teal-types/master/types/luasystem/system.d.tl" },
}

local fs <const> = require("cyan.fs")
local log <const> = require("cyan.log")
local decoration <const> = require("cyan.decoration")
local interaction <const> = require("cyan.interaction")

local types_path <const> = lexical_path.from_os("types")

local dep_info  <const> = log.create_logger(io.stdout, "normal", decoration.decorate("Dep Info",  decoration.scheme.teal),  decoration.decorate("...", decoration.scheme.teal))
local dep_warn  <const> = log.create_logger(io.stderr, "normal", decoration.decorate("Dep Warn",  decoration.scheme.warn),  decoration.decorate("...", decoration.scheme.warn))
local dep_err   <const> = log.create_logger(io.stderr, nil,      decoration.decorate("Dep Warn",  decoration.scheme.error), decoration.decorate("...", decoration.scheme.error))
local dep_extra <const> = log.create_logger(io.stderr, "extra",  decoration.decorate("Dep *Info", decoration.scheme.teal),  decoration.decorate("...", decoration.scheme.teal))

if os.getenv("CYAN_DONT_CHECK_DEPS") then
   dep_extra("CYAN_DONT_CHECK_DEPS environment variable is defined, not checking for teal-types dependencies")
   return
end

local force_update <const> = os.getenv("CYAN_FORCE_UPDATE_DEPS") ~= nil
-- TODO: really need a subprocess module
local cmd_str <const> = os.getenv("CYAN_FETCH_CMD") or "wget --quiet -O %FILE% %URL%"

do
   local not_defined <const> = decoration.decorate("not defined", decoration.scheme.gray) as string
   dep_extra(
      "Relevant environment variables:\n"
      .. "     CYAN_DONT_CHECK_DEPS = ", os.getenv("CYAN_DONT_CHECK_DEPS") or not_defined, "\n"
      .. "   CYAN_FORCE_UPDATE_DEPS = ", os.getenv("CYAN_FORCE_UPDATE_DEPS") or not_defined, "\n"
      .. "           CYAN_FETCH_CMD = ", os.getenv("CYAN_FETCH_CMD") or not_defined, "\n"
      .. "                  default = wget -O %FILE% %URL%\n"
      .. "\nIn CYAN_FETCH_CMD, %FILE% and %URL% get substituted with the desired file and url when running the command."
   )
end

if not fs.exists(types_path) then
   dep_warn("Directory ", decoration.file_name(types_path:to_string()), " does not exist, attempting to create it")
   local ok <const>, err <const> = fs.make_directory(types_path)
   if not ok then
      dep_err("Unable to create directory ", decoration.file_name(types_path:to_string()), ":\n   ", err)
      os.exit(1)
   end
   dep_extra("Created directory ", decoration.file_name(types_path:to_string()))
elseif not fs.is_directory(types_path) then
   dep_err(decoration.file_name(types_path:to_string()), " was expected to be a directory, but is not")
   os.exit(1)
end

-- types_path exists and is a directory

local record FetchPair
   destination: lexical_path.Path
   url: string
end
local to_be_fetched <const>: {FetchPair} = {}
local missing_str <const>: {string | decoration.Decorated} = { "Missing dependencies:" }

for dep in ivalues(deps) do
   local result_path = types_path:copy() .. (dep.name .. ".d.tl")

   if force_update or not fs.exists(result_path) then
      table.insert(to_be_fetched, { destination = result_path, url = dep.url })
      table.insert(missing_str, "\n   ")
      table.insert(missing_str, decoration.file_name(result_path:to_string()))
      table.insert(missing_str, " from " .. dep.url)
   end
end

if #to_be_fetched == 0 then
   return
end

dep_warn(table.unpack(missing_str))

if not interaction.yes_no_prompt("Download dependencies?") then
   dep_warn([[Not downloading dependencies

You will need to download them manually to the expected paths or have them in
your LUA_PATH. If they are already in your LUA_PATH, set the
CYAN_DONT_CHECK_DEPS environment variable to skip running this script.]])
   os.exit(1)
end

local dep_cmd <const> = log.create_logger(io.stdout, "normal", decoration.decorate("Cmd Out", decoration.scheme.teal), decoration.decorate("...", decoration.scheme.teal))

local function run_cmd(cmd: string, max_log_lines?: integer): boolean, integer, {string}
	max_log_lines = max_log_lines or math.huge as integer
   local display_cmd <const> = decoration.decorate(cmd, decoration.scheme.magenta)
   dep_info("Running command ", display_cmd)
   local p <const>, popen_err <const> = io.popen(cmd)
   if not p then
      dep_err("Failed to run command ", display_cmd, "\n   ", popen_err)
      return false
   end
	local res <const>: {string} = {}
	local ln = p:read("*l")
	while ln do
		if #res < max_log_lines then
			if res[1] then
				dep_cmd:cont("   ", ln)
			else
				dep_cmd("   ", ln)
			end
      elseif #res == max_log_lines then
         dep_cmd:cont("   ", decoration.decorate("... (truncated)", decoration.scheme.gray))
		end
		table.insert(res, ln)
		ln = p:read("*l")
	end
	local ok <const>, pclose_err <const>, exit_code <const> = p:close() as (boolean, string, integer)

   if not ok or exit_code ~= 0 then
      dep_err("Command ", display_cmd, " exited abnormally (with exit code ", exit_code, ")\n   ", pclose_err)

      local out_filename <const> = "dep-cmd-output.txt"
      local f <const> = io.open(out_filename, "w")
      if f then
         f:write(table.concat(res, "\n"))
         f:close()
         dep_err:cont("   Command output written to ", decoration.file_name(lexical_path.from_os(out_filename):to_string()))
      end

      return false, exit_code
   end

	return true, exit_code, res
end

for dep in ivalues(to_be_fetched) do
   local cmd <const> = cmd_str:gsub("%%%w+%%", function(match: string): string
      if match == "%URL%" then
         return dep.url
      end
      if match == "%FILE%" then
         return dep.destination:to_string()
      end
      return match
   end)
   if not run_cmd(cmd) then
      os.exit(1)
   end
end
