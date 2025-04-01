
---@brief
--- Filesystem and path management

local lfs <const> = require("lfs")
local util <const> = require("cyan.util")
local lexical_path <const> = require("lexical-path")

local fs <const> = {
   path_separator = package.config:sub(1, 1),
   shared_lib_extension = package.cpath:match("(%.%w+)%s*$") or ".so"
}

---@desc
--- On success returns the current working directory as a lexical path. On
--- error returns nil and an error message
function fs.current_directory(): lexical_path.Path, string
   local dir <const>, err <const> = lfs.currentdir()
   if not dir then
      return nil, err
   end
   return (lexical_path.from_os(dir))
end

---@desc
--- Attempt to change the current directory to the directory referred to by the
--- given path. On success returns true. On failure returns nil and an error
--- message.
function fs.change_directory(p: lexical_path.Path): boolean, string
   return lfs.chdir(p:to_string())
end

---@desc
--- Attempt to see if the path referred to by `p` exists.
function fs.exists(p: lexical_path.Path): boolean
   return lfs.attributes(p:to_string()) ~= nil
end

---@desc
--- Return if the file referred to by the given path is a directory.
---
--- On failure, returns nil and an error message
function fs.is_directory(p: lexical_path.Path): boolean, string
   local mode <const>, err <const> = lfs.attributes(p:to_string(), "mode")
   return mode == "directory" and true or nil, err
end

---@desc
--- Return if the file referred to by the given path is a regular file
function fs.is_file(p: lexical_path.Path): boolean, string
   local mode <const>, err <const> = lfs.attributes(p:to_string(), "mode")
   return mode == "file" and true or nil, err
end

---@desc
--- Returns the modification time of the file referred to by the given path
---
--- In case of an error, returns nil, and an error message
function fs.mod_time(of: lexical_path.Path): integer, string
    local mod <const>, err <const> = lfs.attributes(of:to_string(), "modification")
    return mod, err
end

---@desc
--- Normalizes a given path via the `lexical_path` library
function fs.normalize(p: string): string
   return lexical_path.from_os(p):to_string()
end

---@desc
--- Iterate over the given directory, returning `lexical_path.Path` objects
---
--- By default, will not include paths that start with '.'
function fs.iterate_directory(dir: lexical_path.Path, include_dotfiles?: boolean): function(): lexical_path.Path
   local iter <const>, data <const> = lfs.dir(dir:to_string()) as (function(any): (string), any)
   return function(): lexical_path.Path
      local p: string
      repeat p = iter(data)
      until not p
         or (include_dotfiles and p ~= "." and p ~= "..")
         or p:sub(1, 1) ~= "."
      if p then
         return (lexical_path.from_os(p))
      end
   end
end

local read_cache <const>: {string:string} = {}
---@desc
--- Open a file, read it, close the file, return the contents or `nil` and an error if it couldn't be opened
---
--- Additionally caches results so multiple locations can read the same file for minimal cost.
--- There is currently no way to clear out this cache.
function fs.read(p: string): string, string
   p = fs.normalize(p)
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
--- If the given path matches any of the patterns in `patterns`, returns the index of the matched pattern
--- otherwise returns `nil`
function fs.match_any(path: lexical_path.Path, patterns: {string | lexical_path.Pattern}): integer
   for i, pattern in ipairs(patterns) do
      if path:match(pattern) then
         return i
      end
   end
   return nil
end

---@desc
--- Recursively iterate over the files in a directory, following the provided `include` and `exclude` patterns
---
--- For information on path patterns, see the lexical-path module's documentation
function fs.scan_directory(
   dir: lexical_path.Path,
   include?: {string | lexical_path.Pattern},
   exclude?: {string | lexical_path.Pattern},
   include_directories?: boolean
): function(): lexical_path.Path
   local function ensure_pattern(x: string | lexical_path.Pattern): lexical_path.Pattern
      if x is string then
         return lexical_path.parse_pattern(x)
      end
      return x
   end
   local include_patterns <const>: {lexical_path.Pattern} = util.tab.map(include or {}, ensure_pattern)
   local exclude_patterns <const>: {lexical_path.Pattern} = util.tab.map(exclude or {}, ensure_pattern)

   local function matches(to_match: lexical_path.Path): boolean
      local inc: integer = nil
      if #include_patterns > 0 then
         inc = fs.match_any(to_match, include_patterns)
      else
         inc = 0
      end
      if inc and #exclude_patterns > 0 then
         return not fs.match_any(to_match, exclude_patterns)
      end
      return inc ~= nil
   end
   local function dir_iter(d: lexical_path.Path)
      for p in fs.iterate_directory(d) do
         local full <const> = d .. p
         local to_match <const> = full:remove_leading(dir)
         if fs.is_directory(full) then
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
   return coroutine.wrap(function() dir_iter(dir) end) as function(): lexical_path.Path
end

---@desc
--- Search for a file in the parent directories of the given path. Returns the path of the file found.
---
--- e.g. if `file.txt` is in `/foo/bar`, then
--- `fs.search_parent_dirs("/foo/bar/baz", "file.txt") == path.new "/foo/bar/file.txt"`
function fs.search_parent_dirs(start_path: lexical_path.Path, fname: string): lexical_path.Path
   local in_spath <const> = start_path .. fname
   if fs.exists(in_spath) then
      return in_spath
   end

   local ancestors <const> = util.tab.from(start_path:ancestors())
   for i = #ancestors, 1, -1 do
      local full <const> = ancestors[i] .. fname
      if fs.exists(full) then
         return full
      end
   end
end

---@desc
--- Copy a file
---
--- uses `fs.read` internally to get and cache the contents of `source`
function fs.copy(source_path: lexical_path.Path, dest_path: lexical_path.Path): boolean, string
   local source_contents <const>, read_err <const> = fs.read(source_path:to_string())
   if not source_contents then
      return false, read_err
   end
   local dest_real_path <const> = dest_path:to_string()
   local fh <const>, open_err <const> = io.open(dest_real_path, "w")
   if not fh then
      return false, open_err
   end
   fh:write(source_contents)
   fh:close()
   read_cache[dest_real_path] = source_contents
   return true
end

---@desc
--- For each ancestor of the given path, `mkdir` that path
---
--- In unixy terms, this is roughly `mkdir -p path/..`
function fs.make_parent_directories(of: lexical_path.Path): boolean, string
   for p in of:ancestors() do
      if fs.exists(p) then
         if not fs.is_directory(p) then
            return false, p:to_string() .. " exists and is not a directory"
         end
      else
         local succ <const>, err <const> = lfs.mkdir(p:to_string())
         if not succ then
            return false, err
         end
      end
   end
   return true
end

---@desc
--- Create a directory with the given path, creating any ancestor directories
---
--- In unixy terms, this is `mkdir -p`
function fs.make_directory(path: lexical_path.Path): boolean, string
   local succ, err = fs.make_parent_directories(path)
   if succ then
      succ, err = lfs.mkdir(path:to_string())
   end
   return succ, err
end

return fs
