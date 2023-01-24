
---@brief
--- Filesystem and path management

local lfs <const> = require("lfs")
local path <const> = require("cyan.fs.path")
local util <const> = require("cyan.util")

local Path <const> = path.Path

local fs <const> = {
   path = path,
   Path = Path,
}

local ensure <const> = path.ensure

---@desc
--- Get the current working directory as an `fs.Path`
function fs.cwd(): Path
   return path.new(lfs.currentdir(), true)
end

---@desc
--- Change the current directory to `p`
function fs.chdir(p: string | Path): boolean, string
   return lfs.chdir(ensure(p):to_real_path())
end

---@desc
--- Iterate over the given directory, returning `fs.Path` objects
---
--- By default, will not include paths that start with '.'
function fs.dir(dir: string | Path, include_dotfiles: boolean): function(): Path
   local iter <const>, data <const> = lfs.dir(
      ensure(dir):to_real_path()
   ) as (function(any): (string), any)
   return function(): Path
      local p: string
      repeat p = iter(data)
      until not p
         or (include_dotfiles and p ~= "." and p ~= "..")
         or p:sub(1, 1) ~= "."

      return path.new(p)
   end
end

local read_cache <const>: {string:string} = {}
---@desc
--- Open a file, read it, close the file, return the contents or `nil` and an error if it couldn't be opened
---
--- Additionally caches results so multiple locations can read the same file for minimal cost.
--- There is currently no way to clear out this cache.
function fs.read(p: string): string, string
   if not read_cache[p] then
      local fh <const>, err <const> = io.open(p, "r")
      if not fh then
         return nil, err
      end
      read_cache[p] = fh:read("*a")
      fh:close()
   end
   return read_cache[p]
end

---@desc
--- Gets line `n` of a file.
---
--- if the file is less than `n` lines, returns `nil`
---
--- if there was an error opening the file, returns `nil`, err
---
--- Uses `fs.read()` internally, which caches reads
function fs.get_line(p: string, n: integer): string, string
   local content <const>, err <const> = fs.read(p)
   if err then
      return nil, err
   end

   local l = 1
   for a, b in util.str.split_find(content, "\n", true) do
      if l == n then
         return content:sub(a, b)
      end
      l = l + 1
   end
end

---@desc
--- Recursively iterate over the files in a directory, following the provided `include` and `exclude` patterns
---
--- For information on path patterns, see the `Path:match()` method
function fs.scan_dir(dir: string | Path, include: {string}, exclude: {string}, include_directories: boolean): function(): Path
   include = include or {}
   exclude = exclude or {}
   local function matches(to_match: Path): boolean
      local inc: number = nil
      if #include > 0 then
         inc = to_match:match_any(include)
      else
         inc = 0
      end
      if inc and #exclude > 0 then
         return not to_match:match_any(exclude)
      end
      return inc ~= nil
   end
   local function dir_iter(_d: string | Path)
      local d <const> = ensure(_d)
      for p in fs.dir(d) do
         -- dont bother putting "./foo", just do "foo"
         local full <const> = #d > 0 and d .. p
            or p
         local to_match <const> = full:copy()
         to_match:remove_leading(dir)
         if full:is_directory() then
            if include_directories and matches(to_match) then
               coroutine.yield(to_match)
            end
            dir_iter(full)
         else
            if matches(to_match) then
               coroutine.yield(to_match)
            end
         end
      end
   end
   return coroutine.wrap(function() dir_iter(dir) end) as function(): Path
end

---@desc
--- Split a path on its extension. Forces the extension to be lowercase.
---
--- the `ndots` argument lets you specify the upper limit of how many dots the
--- extension can have
---
--- ex:
---@@code
--- fs.extension_split("foo.d.tl") => "foo.d", ".tl"
--- fs.extension_split("foo.d.tl", 2) => "foo", ".d.tl"
--- fs.extension_split("foo.D.TL", 2) => "foo", ".d.tl"
---@@end
function fs.extension_split(p: Path | string, ndots: integer): string, string
   if not p then
      return nil
   end
   local str_path <const> = p is Path and p:to_real_path() or p as string
   for n = ndots or 1, 1, -1 do
      local patt <const> = "^(.-)(" .. ("%.%a+"):rep(n) .. ")$"
      local base <const>, ext = str_path:match(patt)
      if ext then
         ext = ext:lower()
         return base, ext
      end
   end
   return str_path
end

---@desc
--- Concatenate two strings using the os path separator
function fs.path_concat(a: string, b: string): string
   return a .. path.separator .. b
end

---@desc
--- Search for a file in the parent directories of the given path. Returns the path of the file found.
---
--- e.g. if `file.txt` is in `/foo/bar`, then
--- `fs.search_parent_dirs("/foo/bar/baz", "file.txt") == path.new "/foo/bar/file.txt"`
function fs.search_parent_dirs(start_path: string | Path, fname: string): Path
   local p <const> = ensure(start_path, true)

   local in_spath <const> = p .. fname
   if in_spath:exists() then
      return in_spath
   end

   local ancestors <const> = util.tab.from(p:ancestors())
   for i = #ancestors, 1, -1 do
      local full <const> = ancestors[i] .. fname
      if full:exists() then
         return full
      end
   end
end

---@desc
--- Copy a file
---
--- uses `fs.read` internally to get and cache the contents of `source`
function fs.copy(source: string | Path, dest: string | Path): boolean, string
   local source_path <const> = ensure(source, true)
   local dest_path <const> = ensure(dest, true)

   local source_contents <const>, read_err <const> = fs.read(source_path:to_real_path())
   if not source_contents then
      return false, read_err
   end
   local fh <const>, open_err <const> = io.open(dest_path:to_real_path(), "r")
   if not fh then
      return false, open_err
   end
   fh:write(source_contents)
   fh:close()
   return true
end

return fs
