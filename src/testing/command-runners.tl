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
   generated_files: temporary_files.Directory

   cmd_output_match: string
   cmd_output_not_match: string
   cmd_output: string
   cmd_output_match_lines: Array<string>

   exit_code: integer
end

local runners <const> = {
   ProjectDescription = ProjectDescription,
}

local function do_in(dir: string, func: function())
   local cdir <const> = assert(lfs.currentdir())
   assert(lfs.chdir(dir), "unable to chdir into " .. dir)
   local ok <const>, err <const> = pcall(func) as (boolean, any)
   assert(lfs.chdir(cdir), "unable to chdir into " .. cdir)
   if not ok then
      error(err, 2)
   end
end

-- NOTE: T can't be a table type
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

local function cyan_cmd(c: CyanCommand, ...: string): string
   return table.concat({ cmd_prefix, c, ... }, " ")
end

function runners.run_mock_project(
   finally: function(function()),
   project: ProjectDescription
)
   local expected_dir_structure: temporary_files.DirectorySet
   if project.generated_files then
      expected_dir_structure = {}
      insert_into(expected_dir_structure, project.dir_structure)
      insert_into(expected_dir_structure, project.generated_files)
   end

   local actual_dir_name <const> = temporary_files.write_directory(finally, project.dir_structure)

   local pd: FILE
   local actual_output: string
   local actual_dir_structure: temporary_files.DirectorySet

   do_in(actual_dir_name, function()
      local cmd <const> = cyan_cmd(project.cmd, table.unpack(project.args)) .. " 2>&1"
      pd = assert(io.popen(cmd, "r"))
      actual_output = pd:read("a")
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

return runners
