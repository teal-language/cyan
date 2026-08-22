---@brief
--- An invocation context contains what would be global variables that are
--- concerned with how cyan was invoked. Things like the initial directory are
--- kept here so that paths may be displayed relative to it despite some
--- commands changing the directory of the process.

-- local fs <const> = require("cyan.fs")
local lexical_path <const> = require("lexical-path")
local decoration <const> = require("cyan.decoration")
local fs <const> = require("cyan.fs")

---@desc
--- The context itself.
local record InvocationContext
   --- The directory cyan was invoked from
   initial_directory: lexical_path.Absolute

   --- The directory that contained `tlconfig.lua`
   project_root_directory: lexical_path.Absolute
end

local invocation_context <const> = {
   InvocationContext = InvocationContext,
}

---@desc
--- Create a new context, asserting any invariants.
function invocation_context.new(
   initial_directory: lexical_path.Absolute,
   project_root_directory: lexical_path.Absolute
): InvocationContext
   assert(initial_directory, "No initial directory provided")
   assert(initial_directory.is_absolute, "Initial directory was not absolute")
   assert(project_root_directory == nil or project_root_directory.is_absolute, "Project root directory was not absolute")

   local result <total>: InvocationContext = {
      initial_directory = initial_directory,
      project_root_directory = project_root_directory,
   }

   return setmetatable(result, { __index = InvocationContext })
end

function InvocationContext:relative_path(p: lexical_path.Path): lexical_path.Path
   return p:relative_to(self.initial_directory) or p:copy()
end

function InvocationContext:display_path(f: lexical_path.Path, trailing_slash?: boolean): decoration.Decorated
   return decoration.file_name(self:relative_path(f):to_string() .. (trailing_slash and fs.path_separator or ""))
end

return invocation_context
