---@brief
--- An invocation context contains what would be global variables that are
--- concerned with how cyan was invoked. Things like the initial directory are
--- kept here so that paths may be displayed relative to it despite some
--- commands changing the directory of the process.

-- local fs <const> = require("cyan.fs")
local lexical_path <const> = require("lexical-path")

---@desc
--- The context itself.
local record InvocationContext
   --- The directory cyan was invoked from
   ---
   --- Should be absolute
   initial_directory: lexical_path.Path

   --- The directory that contained `tlconfig.lua`
   ---
   --- If present, should be absolute
   project_root_directory: lexical_path.Path
end

local invocation_context <const> = {
   InvocationContext = InvocationContext,
}

---@desc
--- Create a new context, asserting any invariants.
function invocation_context.new(
   initial_directory: lexical_path.Path,
   project_root_directory: lexical_path.Path
): InvocationContext
   assert(initial_directory, "No initial directory provided")
   assert(initial_directory.is_absolute, "Initial directory was not absolute")
   assert(project_root_directory == nil or project_root_directory.is_absolute, "Project root directory was not absolute")

   local result <total>: InvocationContext = {
      initial_directory = initial_directory,
      project_root_directory = project_root_directory,
   }

   return result
end

return invocation_context
