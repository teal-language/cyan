
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

local function to_path(s: string | Path, use_os_sep: boolean): Path
   return s is string
      and assert(path.new(s, use_os_sep))
      or s
end

---@desc
--- Get the current working directory as an `fs.Path`
function fs.cwd(): Path
   return path.new(lfs.currentdir(), true)
end

---@desc
--- Change the current directory to `p`
function fs.chdir(p: string | Path): boolean, string
   return lfs.chdir(to_path(p):to_real_path())
end

---@desc
--- Iterate over the given directory, returning `fs.Path` objects
---
--- By default, will not include paths that start with '.'
function fs.dir(dir: string | Path, include_dotfiles: boolean): function(): Path
   local iter <const>, data <const> = lfs.dir(
      to_path(dir):to_real_path()
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

local read_cache <const>: {string:string} = setmetatable({}, { __mode = "k" }) -- TODO: does this even do anything?
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

function fs.get_line(p: string, n: number): string, string
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
function fs.scan_dir(dir: string | Path, include: {string}, exclude: {string}): function(): Path
   include = include or {}
   exclude = exclude or {}
   local function dir_iter(_d: string | Path)
      local d <const> = to_path(_d)
      for p in fs.dir(d) do
         -- dont bother putting "./foo", just do "foo"
         local full <const> = #d > 0 and d .. p
            or p
         local to_match <const> = full:copy()
         to_match:remove_leading(dir)
         if full:is_directory() then
            dir_iter(full)
         else
            local inc: boolean | number = true
            if #include > 0 then
               inc = to_match:match_any(include)
            end
            if inc and #exclude > 0 then
               inc = not to_match:match_any(exclude)
            end
            if inc then
               coroutine.yield(to_match)
            end
         end
      end
   end
   return coroutine.wrap(function() dir_iter(dir) end) as function(): Path
end

---@brief
--- Split a path on its extension
---
--- the `ndots` argument lets you specify how many dots the extension can have
---
--- ex:
--- `fs.extension_split("foo.d.tl") == ".tl"`
---
--- `fs.extension_split("foo.d.tl", 2) == ".d.tl"`
function fs.extension_split(p: Path | string, ndots: number): string, string
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

---@brief
--- Concatenate two strings using the os path separator
function fs.path_concat(a: string, b: string): string
   return a .. path.separator .. b
end

---@brief
--- Search for a file in the parent directories of the given path
function fs.search_parent_dirs(spath: string | Path, fname: string): Path
   local p <const> = to_path(spath, true)

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

return fs

