local _tl_compat; if (tonumber((_VERSION or ''):match('[%d.]*$')) or 0) < 5.3 then local p, m = true, require('compat53.module'); if p then _tl_compat = m end end; local assert = _tl_compat and _tl_compat.assert or assert; local io = _tl_compat and _tl_compat.io or io; local package = _tl_compat and _tl_compat.package or package; local pairs = _tl_compat and _tl_compat.pairs or pairs; local string = _tl_compat and _tl_compat.string or string; local table = _tl_compat and _tl_compat.table or table; local _tl_table_unpack = unpack or table.unpack; local lfs = require("lfs")

local current_dir = assert(lfs.currentdir(), "unable to get current dir")
local cyan_executable = current_dir .. "/bin/cyan"
local cmd_prefix = (function()
   local buf = { string.format("LUA_PATH=%q", package.path) }
   for i = 1, 4 do
      table.insert(buf, string.format("LUA_PATH_5_%d=%q", i, package.path))
   end

   table.insert(buf, "CYAN_DISABLE_SCRIPT_CACHE=1")


   local first_arg = 0
   while arg[first_arg - 1] do
      first_arg = first_arg - 1
   end
   table.insert(buf, arg[first_arg])
   table.insert(buf, cyan_executable)

   return table.concat(buf, " ")
end)()

local Batch = require("testing.batch-assertion")
local temporary_files = require("testing.temporary-files")

local luassert = require("luassert")















local ProjectDescription = {}













local runners = {
   ProjectDescription = ProjectDescription,
}

local function insert_into(
   destination,
   source)

   for k, v in pairs(source) do
      if type(v) == "table" then
         if not destination[k] then
            destination[k] = {}
         end
         insert_into(
         destination[k],
         v)

      else
         destination[k] = true
      end
   end
end

function runners.cyan_command(c, ...)
   return table.concat({ cmd_prefix, c, ... }, " ")
end

function runners.run_mock_project(
   fin,
   project)

   local expected_dir_structure
   if project.generated_files then
      expected_dir_structure = {}
      insert_into(expected_dir_structure, project.dir_structure)
      insert_into(expected_dir_structure, project.generated_files)
   end

   local actual_dir_name = temporary_files.write_directory(fin, project.dir_structure)

   local pd
   local actual_output
   local actual_dir_structure

   temporary_files.do_in(actual_dir_name, function()
      local cmd = runners.cyan_command(project.cmd, _tl_table_unpack(project.args or {})) .. " 2>&1"
      pd = assert(io.popen(cmd, "r"))
      actual_output = pd:read("*a")
      if expected_dir_structure then
         actual_dir_structure = temporary_files.get_dir_structure(".")
      end
   end)
   local show_output = "Full output:\n" .. actual_output

   local batch = Batch:new("Mock project")
   local _, _, code = pd:close()
   if _VERSION ~= "Lua 5.1" then
      batch:add(
      luassert.are_equal,
      project.exit_code,
      code,
      string.format("Expected exit code %d, got %d\n%s", project.exit_code, code, show_output))

   end

   if project.cmd_output_match then
      batch:add(luassert.match, project.cmd_output_match, actual_output, show_output)
   end
   if project.cmd_output_not_match then
      batch:add(luassert.not_match, project.cmd_output_not_match, actual_output, show_output)
   end
   if project.cmd_output then
      batch:add(luassert.equal, project.cmd_output, actual_output)
   end
   if project.cmd_output_match_lines then
      local i = 0
      for ln in actual_output:gmatch("[^\n]+") do
         i = i + 1
         if project.cmd_output_match_lines[i] then
            batch:add(
            luassert.match,
            project.cmd_output_match_lines[i],
            ln, 1, false, "Line " .. i .. " of output didn't match",
            show_output)

         end
      end
      if project.cmd_output_match_lines.n then
         batch:add(luassert.are_equal, project.cmd_output_match_lines.n, i)
      end
   end
   if expected_dir_structure then
      batch:add(luassert.are_same, expected_dir_structure, actual_dir_structure, "Actual directory structure is not as expected")
   end
   batch:show_on_failure("Command Output:\n" .. actual_output)
   batch:assert()
end








function runners.run_command(cmd, in_dir)
   local output
   local exit_code
   local function run()
      local pd = io.popen(cmd, "r")
      output = pd:read("*a")
      local _, _, code = pd:close()
      exit_code = code
   end
   if in_dir then
      temporary_files.do_in(in_dir, run)
   else
      run()
   end
   return output, exit_code
end

return runners
