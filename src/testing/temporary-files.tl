local on_finally <const> = require("testing.finally")
local lfs <const> = require("lfs")

-- Certain systems will actually write out /tmp to disk on shutdown and instead
-- run a garbage collector over it after files reach a certain age. And windows
-- is notorious for not cleaning up tmp files.
--
-- So it is likely in your best interest to mount an in memory filesystem if
-- your system does this
--
-- On linux you can do the following to mount a 50MB tmpfs: (note: a # prompt means root user)
--
--     $ mkdir $CYAN_TESTING_TEMP_DIR
--     # mount -t tmpfs -o size=50m tmpfs $CYAN_TESTING_TEMP_DIR
--
-- And unmount with
--
--     # umount $CYAN_TESTING_TEMP_DIR
--
-- On something like CI this is less important since the whole virtual machine
-- is ephemeral anyway. But if you still have a spinning disk like my old
-- machine, you may want this.

local temp_dir <const> = os.getenv("CYAN_TESTING_TEMP_DIR") or "/tmp/cyan_tmp"
lfs.mkdir(temp_dir)

local clean_up_temp_files <const> = (function(): boolean
   local env <const> = os.getenv("CYAN_TESTING_CLEANUP_TEMP_FILES")
   if env then
      return env ~= "0"
   end
   return true
end)()

-- for describing directories like so:
--
--     {
--        foo = {
--           ["bar.tl"] = "print 'hi'"
--        },
--        ["tlconfig.lua"] = [[return { source_dir = "foo" }]]
--     }
local type Directory = {string:Directory|string}
local type DirectorySet = {string:DirectorySet|boolean}

local temporary_files <const> = {
   Directory = Directory,
   DirectorySet = DirectorySet,
}

function temporary_files.new_name(): string
   local name: string
   -- This may be overly cautious, but whatever
   repeat name = (temp_dir .. "/%08x_%04x%04x"):format(os.time(), math.random(0, (2^16 - 1) as integer), math.random(0, (2^16 - 1) as integer))
   until not lfs.attributes(name)
   return name
end

function temporary_files.rmdir_recursive(path: string): boolean, string
   for fname in lfs.dir(path) do
      if fname ~= ".." and fname ~= "." then
         local full <const> = path .. "/" .. fname
         local ok, err: boolean, string
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
   fin: function(function()),
   dir_structure: Directory
): string
   local full_name <const> = temporary_files.new_name() .. "/"
   assert(lfs.mkdir(full_name))

   local function traverse_dir(tree: Directory, prefix: string)
      assert(prefix:sub(-1, -1) == "/")
      for name, content in pairs(tree) do
         local full_item_name = prefix .. name
         if content is string then
            local fd <const> = io.open(full_item_name, "w")
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

function temporary_files.get_dir_structure(dir_name: string): DirectorySet
   -- basically run `tree` and put it into a table
   local dir_structure: DirectorySet = {}
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

function temporary_files.do_in(dir: string, func: function())
   local cdir <const> = assert(lfs.currentdir())
   assert(lfs.chdir(dir), "unable to chdir into " .. dir)
   local ok <const>, err <const> = pcall(func) as (boolean, any)
   assert(lfs.chdir(cdir), "unable to chdir into " .. cdir)
   if not ok then
      error(err, 2)
   end
end

return temporary_files
