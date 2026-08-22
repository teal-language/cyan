local _tl_compat; if (tonumber((_VERSION or ''):match('[%d.]*$')) or 0) < 5.3 then local p, m = true, require('compat53.module'); if p then _tl_compat = m end end; local assert = _tl_compat and _tl_compat.assert or assert






local lexical_path = require("lexical-path")
local decoration = require("cyan.decoration")
local fs = require("cyan.fs")



local InvocationContext = {}







local invocation_context = {
   InvocationContext = InvocationContext,
}



function invocation_context.new(
   initial_directory,
   project_root_directory)

   assert(initial_directory, "No initial directory provided")
   assert(initial_directory.is_absolute, "Initial directory was not absolute")
   assert(project_root_directory == nil or project_root_directory.is_absolute, "Project root directory was not absolute")

   local result = {
      initial_directory = initial_directory,
      project_root_directory = project_root_directory,
   }

   return setmetatable(result, { __index = InvocationContext })
end

function InvocationContext:relative_path(p)
   return p:relative_to(self.initial_directory) or p:copy()
end

function InvocationContext:display_path(f, trailing_slash)
   return decoration.file_name(self:relative_path(f):to_string() .. (trailing_slash and fs.path_separator or ""))
end

return invocation_context
