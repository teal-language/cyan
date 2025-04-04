local lfs <const> = require("lfs")

local current_dir <const> = assert(lfs.currentdir(), "unable to get current dir")
local cyan_executable <const> = current_dir .. "/bin/cyan"
local cmd_prefix <const> = (function(): string
   local buf <const> = { string.format("LUA_PATH=%q", package.path) }
   for i = 1, 4 do
      table.insert(buf, string.format("LUA_PATH_5_%d=%q", i, package.path))
   end

   -- find the lua interpreter
   local first_arg = 0
   while arg[first_arg - 1] do
      first_arg = first_arg - 1
   end
   table.insert(buf, arg[first_arg])
   table.insert(buf, cyan_executable)

   return table.concat(buf, " ")
end)()

local Batch <const> = require("testing.batch-assertion")
local temporary_files <const> = require("testing.temporary-files")

local luassert <const> = require("luassert")

local enum CyanCommand
   "gen"
   "check"
   "run"
   "build"
   "init"
   "warnings"
end

local record Array<T>
   {T}
   n: integer
end

local record ProjectDescription
   cmd: CyanCommand
   args: {string}
   dir_structure: temporary_files.Directory
   generated_files: temporary_files.DirectorySet

   cmd_output_match: string
   cmd_output_not_match: string
   cmd_output: string
   cmd_output_match_lines: Array<string>

   exit_code: integer
end

local runners <const> = {
   ProjectDescription = ProjectDescription,
}

local function insert_into(
   destination: temporary_files.DirectorySet,
   source: temporary_files.Directory
)
   for k, v in pairs(source) do
      if type(v) == "table" then
         if not destination[k] then
            destination[k] = {}
         end
         insert_into(
            destination[k] as temporary_files.DirectorySet,
            v as temporary_files.Directory
         )
      else
         destination[k] = true
      end
   end
end

function runners.cyan_command(c: CyanCommand, ...: string): string
   return table.concat({ cmd_prefix, c, ... }, " ")
end

function runners.run_mock_project(
   fin: function(function()),
   project: ProjectDescription
)
   local expected_dir_structure: temporary_files.DirectorySet
   if project.generated_files then
      expected_dir_structure = {}
      insert_into(expected_dir_structure, project.dir_structure)
      insert_into(expected_dir_structure, project.generated_files as temporary_files.Directory)
   end

   local actual_dir_name <const> = temporary_files.write_directory(fin, project.dir_structure)

   local pd: FILE
   local actual_output: string
   local actual_dir_structure: temporary_files.DirectorySet

   temporary_files.do_in(actual_dir_name, function()
      local cmd <const> = runners.cyan_command(project.cmd, table.unpack(project.args or {})) .. " 2>&1"
      pd = assert(io.popen(cmd, "r"))
      actual_output = pd:read("*a")
      if expected_dir_structure then
         actual_dir_structure = temporary_files.get_dir_structure(".")
      end
   end)
   local show_output <const> = "Full output:\n" .. actual_output

   local batch <const> = Batch:new("Mock project")
   local _, _, code <const> = pd:close()
   if _VERSION ~= "Lua 5.1" then
      batch:add(
         luassert.are_equal,
         project.exit_code,
         code,
         string.format("Expected exit code %d, got %d\n%s", project.exit_code, code, show_output)
      )
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
               show_output
            )
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

-- TODO: #Subprocess
--
-- We should have a proper subprocess module to get stdout and stderr
-- for now, the returned exit code may be nil due to luajit's behavior
--
-- see:
-- https://github.com/LuaJIT/LuaJIT/blob/97813fb924edf822455f91a5fbbdfdb349e5984f/src/lib_io.c#L105-L107
function runners.run_command(cmd: string, in_dir?: string): string, integer
   local output: string
   local exit_code: integer
   local function run(): string, integer
      local pd <const> = io.popen(cmd, "r")
      output = pd:read("*a")
      local _, _, code = pd:close()
      exit_code = code as integer
   end
   if in_dir then
      temporary_files.do_in(in_dir, run)
   else
      run()
   end
   return output, exit_code
end

return runners
