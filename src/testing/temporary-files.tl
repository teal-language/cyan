local on_finally <const> = require("testing.finally")
local lfs <const> = require("lfs")

local ivalues <const> = require("cyan.util").tab.ivalues

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
      return env == "1"
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

function temporary_files.write_directory(
   finally: function(function()),
   dir_structure: Directory<string>
): string
   local full_name <const> = temporary_files.new_name() .. "/"
   assert(lfs.mkdir(full_name))
   local files_to_remove <const> = {}
   local directories_to_remove <const> = {}

   local function traverse_dir(tree: Directory<string>, prefix: string)
      assert(prefix:sub(-1, -1) == "/")
      table.insert(directories_to_remove, prefix:sub(1, -2))
      for name, content in pairs(tree) do
         local full_item_name = prefix .. name
         if content is string then
            table.insert(files_to_remove, full_item_name)
            local fd <const> = io.open(full_item_name, "w")
            assert(fd)
            fd:write(content)
            fd:close()
         else
            assert(lfs.mkdir(full_item_name))
            do
               -- tl bug: Directory<string> (inferred at ...) is not a Directory<string>
               (traverse_dir as function)(content, full_item_name .. "/")
            end
         end
      end
   end
   do
      (traverse_dir as function)(dir_structure, full_name)
   end

   if clean_up_temp_files then
      on_finally(finally, function()
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

local function launder<T>(x: any): T
   return x as T
end

function temporary_files.get_dir_structure(dir_name: string): DirectorySet
   -- basically run `tree` and put it into a table
   local dir_structure: table = {}
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

return temporary_files
