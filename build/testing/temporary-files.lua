local _tl_compat; if (tonumber((_VERSION or ''):match('[%d.]*$')) or 0) < 5.3 then local p, m = true, require('compat53.module'); if p then _tl_compat = m end end; local assert = _tl_compat and _tl_compat.assert or assert; local io = _tl_compat and _tl_compat.io or io; local math = _tl_compat and _tl_compat.math or math; local os = _tl_compat and _tl_compat.os or os; local pairs = _tl_compat and _tl_compat.pairs or pairs; local pcall = _tl_compat and _tl_compat.pcall or pcall; local string = _tl_compat and _tl_compat.string or string; local type = type; local on_finally = require("testing.finally")
local lfs = require("lfs")





















local temp_dir = os.getenv("CYAN_TESTING_TEMP_DIR") or "/tmp/cyan_tmp"
lfs.mkdir(temp_dir)

local clean_up_temp_files = (function()
   local env = os.getenv("CYAN_TESTING_CLEANUP_TEMP_FILES")
   if env then
      return env ~= "0"
   end
   return true
end)()












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

function temporary_files.rmdir_recursive(path)
   for fname in lfs.dir(path) do
      if fname ~= ".." and fname ~= "." then
         local full = path .. "/" .. fname
         local ok, err
         if lfs.attributes(full, "mode") == "directory" then
            ok, err = temporary_files.rmdir_recursive(full)
            if not ok then
               return false, err
            end
         end
         ok, err = os.remove(full)
         if not ok then
            return false, err
         end
      end
   end
   return true
end

function temporary_files.write_directory(
   fin,
   dir_structure)

   local full_name = temporary_files.new_name() .. "/"
   assert(lfs.mkdir(full_name))

   local function traverse_dir(tree, prefix)
      assert(prefix:sub(-1, -1) == "/")
      for name, content in pairs(tree) do
         local full_item_name = prefix .. name
         if type(content) == "string" then
            local fd = io.open(full_item_name, "w")
            assert(fd)
            fd:write(content)
            fd:close()
         else
            assert(lfs.mkdir(full_item_name))
            traverse_dir(content, full_item_name .. "/")
         end
      end
   end
   traverse_dir(dir_structure, full_name)

   if clean_up_temp_files then
      on_finally(fin, function()
         assert(temporary_files.rmdir_recursive(full_name))
      end)
   end

   return full_name
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
   return dir_structure
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
