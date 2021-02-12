
local util = {}

local tl = require("tl")
local assert = require("luassert")
local lfs = require("lfs")

local current_dir = assert(lfs.currentdir(), "unable to get current dir")
local tl_executable = current_dir .. "/bin/tl"

local t_unpack = unpack or table.unpack

util.tl_executable = tl_executable

--------------------------------------------------------------------------------
-- 'finally' queue - each Busted test can trigger only one 'finally' callback.
-- We build a queue of callbacks to run and nest them into one main 'finally'
-- callback. Instead of using `finally(function() ... end`, do
-- `on_finally(finally, function() ... end)`. We need to pass the original
-- 'finally` around due to the way Busted deals with function environments.
--------------------------------------------------------------------------------

local finally_queue

local function on_finally(finally, cb)
   if not finally_queue then
      finally(function()
         for _, f in ipairs(finally_queue) do
            f()
         end
         finally_queue = nil
      end)
      finally_queue = {}
   end
   table.insert(finally_queue, cb)
end

--------------------------------------------------------------------------------

function util.do_in(dir, func, ...)
   local cdir = assert(lfs.currentdir())
   assert(lfs.chdir(dir), "unable to chdir into " .. dir)
   local res = {pcall(func, ...)}
   assert(lfs.chdir(cdir), "unable to chdir into " .. cdir)
   if not table.remove(res, 1) then
      error(res[1], 2)
   end
   return t_unpack(res)
end

function util.mock_io(finally, filemap)
   assert(type(finally) == "function")
   assert(type(filemap) == "table")

   local io_open = io.open
   on_finally(finally, function() io.open = io_open end)
   io.open = function (filename, mode)
      local ps = {}
      for p in filename:gmatch("[^/]+") do
         table.insert(ps, p)
      end

      -- try to find suffixes in filemap, from shortest to longest
      local basename
      for i = #ps, 1, -1 do
         basename = table.concat(ps, "/", i)
         if filemap[basename] then
            break
         end
      end

      if filemap[basename] then
         -- Return a stub file handle
         return {
            read = function (_, format)
               if format == "*a" then
                  return filemap[basename]   -- Return fake file content
               else
                  error("Not implemented!")  -- Implement other modes if needed
               end
            end,
            close = function () end,
         }
      else
         return io_open(filename, mode)
      end
   end
end

local function unindent(code)
   assert(type(code) == "string")

   return code:gsub("[ \t]+", " "):gsub("\n[ \t]+", "\n"):gsub("^%s+", ""):gsub("%s+$", "")
end

local function indent(str)
   assert(type(str) == "string")
   return (str:gsub("\n", "\n   "))
end

local Batch = {}
function Batch:new(name)
   return setmetatable({ name = name }, { __index = self })
end

function Batch:add(assert_func, ...)
   table.insert(self, { fn = assert_func, nargs = select("#", ...), args = {...} })
   return self
end

function Batch:assert()
   local err_batch = {}
   local passed = true
   for i, assertion in ipairs(self) do
      local ok, err = pcall(assertion.fn, t_unpack(assertion.args, 1, assertion.nargs))
      if not ok then
         passed = false
         table.insert(err_batch, indent("[" .. i .. "] " .. tostring(err)))
      end
   end
   assert(passed, string.format("batch assertion '%s' failed:\n   %s", self.name, indent(table.concat(err_batch, "\n\n"))))
end

local valid_commands = {
   gen = true,
   check = true,
   run = true,
   build = true,
}
local cmd_prefix = { string.format("LUA_PATH=%q", package.path) }
for i = 1, 4 do
   table.insert(cmd_prefix, string.format("LUA_PATH_5_%d=%q", i, package.path))
end

local first_arg = 0
while arg[first_arg - 1] do
   first_arg = first_arg - 1
end
util.lua_interpreter = arg[first_arg]

table.insert(cmd_prefix, util.lua_interpreter) -- Lua interpreter used by Busted
table.insert(cmd_prefix, tl_executable)
cmd_prefix = table.concat(cmd_prefix, " ")
function util.tl_cmd(name, ...)
   assert(name, "no command provided")
   assert(valid_commands[name], "not a valid command: tl " .. tostring(name))

   local pre_command_args = {}
   local first = ...
   local has_pre_commands = false
   if type(first) == "table" then
      pre_command_args = first
      has_pre_commands = true
   end
   local cmd = {
      cmd_prefix,
      table.concat(pre_command_args, " "),
      name,
   }
   for i = (has_pre_commands and 2) or 1 , select("#", ...) do
      table.insert(cmd, string.format("%q", select(i, ...)))
   end
   table.insert(cmd, " ")

   return table.concat(cmd, " ")
end

math.randomseed(os.time())
lfs.mkdir("/tmp/teal_tmp")
local function tmpname()
   local name
   -- This may be overly cautious, but whatever
   repeat name = ("/tmp/teal_tmp/tl_%08x_%08x"):format(os.time(), math.random(0, 2^32 - 1))
   until not lfs.attributes(name)
   return name
end
function util.write_tmp_file(finally, content, ext)
   assert(type(finally) == "function")
   assert(type(content) == "string")
   ext = ext or "tl"

   local full_name = tmpname() .. "." .. ext

   local fd = assert(io.open(full_name, "w"))
   fd:write(content)
   fd:close()

   on_finally(finally, function()
      os.remove(full_name)
      if not ext then
         os.remove((full_name:gsub("%.tl$", ".lua")))
      end
   end)

   return full_name
end

function util.write_tmp_dir(finally, dir_structure)
   assert(type(finally) == "function")
   assert(type(dir_structure) == "table")

   local full_name = tmpname() .. "/"
   assert(lfs.mkdir(full_name))
   local function traverse_dir(tree, prefix)
      prefix = prefix or full_name
      for name, content in pairs(tree) do
         if type(content) == "table" then
            assert(lfs.mkdir(prefix .. name))
            traverse_dir(content, prefix .. name .. "/")
         else
            local fd = io.open(prefix .. name, "w")
            fd:write(content)
            fd:close()
         end
      end
   end
   traverse_dir(dir_structure)
   on_finally(finally, function()
      os.execute("rm -r " .. full_name)
   end)
   return full_name
end

function util.get_dir_structure(dir_name)
   -- basically run `tree` and put it into a table
   local dir_structure = {}
   for fname in lfs.dir(dir_name) do
      if fname ~= ".." and fname ~= "." then
         if lfs.attributes(dir_name .. "/" .. fname, "mode") == "directory" then
            dir_structure[fname] = util.get_dir_structure(dir_name .. "/" .. fname)
         else
            dir_structure[fname] = true
         end
      end
   end
   return dir_structure
end

local function insert_into(tab, files)
   for k, v in pairs(files) do
      if type(k) == "number" then
         tab[v] = true
      elseif type(v) == "string" then
         tab[k] = true
      elseif type(v) == "table" then
         if not tab[k] then
            tab[k] = {}
         end
         insert_into(tab[k], v)
      end
   end
end

function util.run_mock_project(finally, t, use_folder)
   assert(type(finally) == "function")
   assert(type(t) == "table")
   assert(type(t.cmd) == "string", "tl <cmd> not given")
   assert(valid_commands[t.cmd], "Invalid command tl " .. tostring(t.cmd))
   assert(type(t.exit_code) == "number", "missing exit_code")

   local actual_dir_name = use_folder or util.write_tmp_dir(finally, t.dir_structure)
   local expected_dir_structure
   if t.generated_files then
      expected_dir_structure = {}
      insert_into(expected_dir_structure, t.dir_structure)
      insert_into(expected_dir_structure, t.generated_files)
   end

   local pd, actual_output, actual_dir_structure
   util.do_in(actual_dir_name, function()
      local cmd = util.tl_cmd(t.cmd, t.pre_args or {}, t_unpack(t.args or {})) .. "2>&1"
      pd = assert(io.popen(cmd, "r"))
      actual_output = pd:read("*a")
      if expected_dir_structure then
         actual_dir_structure = util.get_dir_structure(".")
      end
   end)

   local batch = Batch:new("mock project")
   local _status, _exit, code = pd:close()
   local show_output = "Full output: " .. actual_output
   batch:add(assert.are.equal, t.exit_code, code, string.format("Expected exit code %d, got %d\n%s", t.exit_code, code, show_output))

   if t.cmd_output_match then
      batch:add(assert.match, t.cmd_output_match, actual_output, show_output)
   end
   if t.cmd_output then
      batch:add(assert.are.equal, t.cmd_output, actual_output)
   end
   if t.cmd_output_match_lines then
      local i = 0
      for ln in actual_output:gmatch("[^\n]*") do
         i = i + 1
         if t.cmd_output_match_lines[i] then
            batch:add(assert.match, t.cmd_output_match_lines[i], ln, 1, false, "Line " .. i .. " of output didn't match", show_output)
         end
      end
   end
   if expected_dir_structure then
      batch:add(assert.are.same, expected_dir_structure, actual_dir_structure, "Actual directory structure is not as expected")
   end

   batch:assert()
end

function util.read_file(name)
   assert(type(name) == "string")

   local fd = assert(io.open(name, "r"))
   local output = fd:read("*a")
   fd:close()
   return output
end

function util.assert_popen_close(want1, want2, want3, ret1, ret2, ret3)
   assert(want1 == nil or type(want1) == "boolean")
   assert(type(want2) == "string")
   assert(type(want3) == "number")

   if _VERSION == "Lua 5.3" then
      Batch:new("popen close")
         :add(assert.same, want1, ret1)
         :add(assert.same, want2, ret2)
         :add(assert.same, want3, ret3)
         :assert()
   end
end

function util.run_command(cmd)
   local pd = io.popen(cmd, "r")
   local output = pd:read("*a")
   return output, pd:close()
end

return util
