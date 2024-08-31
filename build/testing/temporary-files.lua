local _tl_compat; if (tonumber((_VERSION or ''):match('[%d.]*$')) or 0) < 5.3 then local p, m = true, require('compat53.module'); if p then _tl_compat = m end end; local assert = _tl_compat and _tl_compat.assert or assert; local io = _tl_compat and _tl_compat.io or io; local math = _tl_compat and _tl_compat.math or math; local os = _tl_compat and _tl_compat.os or os; local pairs = _tl_compat and _tl_compat.pairs or pairs; local pcall = _tl_compat and _tl_compat.pcall or pcall; local string = _tl_compat and _tl_compat.string or string; local table = _tl_compat and _tl_compat.table or table; local on_finally = require("testing.finally")
local lfs = require("lfs")

local ivalues = require("cyan.util").tab.ivalues





















local temp_dir = os.getenv("CYAN_TESTING_TEMP_DIR") or "/tmp/cyan_tmp"
lfs.mkdir(temp_dir)

local clean_up_temp_files = (function()
   local env = os.getenv("CYAN_TESTING_CLEANUP_TEMP_FILES")
   if env then
      return env == "1"
   end
   return true
end)()









local Directory = {}
local DirectorySet = {}

local temporary_files = {
   Directory = Directory,
   DirectorySet = DirectorySet,
}

function temporary_files.new_name()
   local name

   repeat name = (temp_dir .. "/%08x_%04x%04x"):format(os.time(), math.random(0, (2 ^ 16 - 1)), math.random(0, (2 ^ 16 - 1)))
   until not lfs.attributes(name)
   return name
end

function temporary_files.write_directory(
   fin,
   dir_structure)

   local full_name = temporary_files.new_name() .. "/"
   assert(lfs.mkdir(full_name))
   local files_to_remove = {}
   local directories_to_remove = {}

   local function traverse_dir(tree, prefix)
      assert(prefix:sub(-1, -1) == "/")
      table.insert(directories_to_remove, prefix:sub(1, -2))
      for name, content in pairs(tree) do
         local full_item_name = prefix .. name
         if type(content) == "string" then
            table.insert(files_to_remove, full_item_name)
            local fd = io.open(full_item_name, "w")
            assert(fd)
            fd:write(content)
            fd:close()
         else
            assert(lfs.mkdir(full_item_name))
            do

               (traverse_dir)(content, full_item_name .. "/")
            end
         end
      end
   end
   do
      (traverse_dir)(dir_structure, full_name)
   end

   if clean_up_temp_files then
      on_finally(fin, function()
         for file_name in ivalues(files_to_remove) do
            assert(os.remove(file_name))
         end

         for i = #directories_to_remove, 1, -1 do
            assert(lfs.rmdir(directories_to_remove[i]))
         end
      end)
   end

   return full_name
end

local function launder(x)
   return x
end

function temporary_files.get_dir_structure(dir_name)

   local dir_structure = {}
   for fname in lfs.dir(dir_name) do
      if fname ~= ".." and fname ~= "." then
         if lfs.attributes(dir_name .. "/" .. fname, "mode") == "directory" then
            dir_structure[fname] = temporary_files.get_dir_structure(dir_name .. "/" .. fname)
         else
            dir_structure[fname] = true
         end
      end
   end
   return launder(dir_structure)
end

function temporary_files.do_in(dir, func)
   local cdir = assert(lfs.currentdir())
   assert(lfs.chdir(dir), "unable to chdir into " .. dir)
   local ok, err = pcall(func)
   assert(lfs.chdir(cdir), "unable to chdir into " .. cdir)
   if not ok then
      error(err, 2)
   end
end

return temporary_files
