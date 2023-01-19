
---@brief
--- Object oriented lexical path management

local lfs <const> = require("lfs")

local util <const> = require("cyan.util")

local split <const>, esc <const> = util.str.split, util.str.esc
local values <const> = util.tab.values
local xor <const> = util.xor

---@desc
--- The main path object. Basically just an array of strings with some methods and metamethods to interact with other paths
local record Path
   {string}

   metamethod __concat: function(Path | string, Path | string): Path
   metamethod __eq: function(Path | string, Path | string): boolean
   -- metamethod __tostring: function(Path): string
end
local PathMt <const>: metatable<Path> = {
   __index = Path,
   __name = "cyan.fs.path.Path",
}

local path <const> = {
   Path = Path,
   separator = package.config:sub(1, 1),
   shared_lib_ext = package.cpath:match("(%.%w+)%s*$") or ".so"
}

-- Basically the constructor for a 'raw' Path,
-- gets the path components, doesn't set the metatable
local function parse_string_path(s: string, use_os_sep: boolean): {string}
   -- TODO: I can see this breaking in the future with escaped characters
   --       like foo/bar\/baz should map to { "foo", "bar/baz" } since the \/ is escaped

   -- TODO: windows allows both \ and / as path separators
   --       test if this works on machines other than mine
   local sep <const> = use_os_sep and path.separator == "\\"
      and "[\\/]"
      or "/"
   s = s:gsub(sep .. "+", sep)
   if s == "" then
      return {}
   elseif s:sub(-1) == sep then
      s = s:sub(1, -2)
   end

   local new: {string} = {}
   for chunk in split(s, sep, true) do
      if chunk == ".." then
         if #new > 0 and new[#new] ~= ".." then
            table.remove(new)
         else
            table.insert(new, chunk)
         end
      elseif chunk ~= "." then
         table.insert(new, chunk)
      end
   end
   return new
end

local function setmt(p: {string}): Path
   return setmetatable(p as Path, PathMt)
end

---@desc
--- The `Path` constructor
---
--- By default uses '/' as a path separator
function path.new(s: string, use_os_sep: boolean): Path
   if not s then return nil end
   return setmt(parse_string_path(s, use_os_sep))
end

---@desc
--- Ensures `s` is a Path.
---
--- If s is a string, parse it into a path
--- otherwise return s unmodified
function path.ensure(s: string | Path, use_os_sep: boolean): Path
   if s is string then
      return path.new(s, use_os_sep)
   else
      return s
   end
end

local function string_is_absolute_path(p: string): boolean
   if path.separator == "/" then
      return p:sub(1, 1) == "/"
   elseif path.separator == "\\" then
      return p:match("^%a:$") as boolean
   end
end

local function chunks(p: Path | string): function(): string
   return p is string and split(p, path.separator, true)
      or values(p as {string})
end

local function append_to_path(p: Path, other: Path | string)
   for chunk in chunks(other) do
      if chunk == ".." then
         table.remove(p)
      elseif chunk ~= "." then
         table.insert(p, chunk)
      end
   end
end

---@desc
--- Modify path in place to remove any traversals that it can
---
---@@code
--- local p = path.new "foo/bar/../baz"
--- p:normalize()
--- assert(p == path.new "foo/baz")
---@@end
---
--- if a traversal can't be removed it will remain
---@@code
--- local p = path.new "../baz"
--- p:normalize()
--- assert(p == path.new "../baz")
---@@end
function Path:normalize()
   for i = #self, 1, -1 do
      if self[i] == ".." then
         table.remove(self, i)
      end
   end
end

---@desc
--- Returns whether the path is absolute
---
--- On windows, checks for paths like "C:\...", elsewhere looks for "/..."
function Path:is_absolute(): boolean
   if #self < 1 then return false end
   if path.separator == "/" then
      return self[1] == ""
   elseif path.separator == "\\" then
      return self[1]:match("^%a:$") as boolean
   end
end

---@desc
--- Convert a path to a string. Always uses '/' as a path separator. Intended for displaying purposes. For an actual path in the filesystem, use `Path:to_real_path()`
---
--- Used for the __tostring metamethod
function Path:tostring(): string
   local start <const> = self[1] == "." and 2 or 1
   return table.concat(self, "/", start)
end

---@desc
--- Convert a `Path` to a string describing a real path
function Path:to_real_path(): string
   local res <const> = table.concat(self, path.separator)
   return #res > 0 and res or "." .. path.separator
end

---@desc
--- Check if the path exists
function Path:exists(): boolean
   return lfs.attributes(self:to_real_path()) ~= nil
end

---@desc
--- Mutate the given `Path` by appending another path to it
---
--- Traversals in the `other` path will be normalized
---
---@@code
--- local p = path.new "foo/bar"
--- p:append "../baz"
--- assert(p == path.new "foo/baz")
---@@end
function Path:append(other: string | Path)
   local p = other is string and path.new(other) or other as Path
   if p:is_absolute() then
      error("Attempt to append absolute path", 2)
   end
   append_to_path(self, p)
end

---@desc
--- Mutate the given `Path` by prepending another path to it
function Path:prepend(other: string | Path)
   if self:is_absolute() then
      error("Attempt to prepend to absolute path", 2)
   end
   other = path.ensure(other)
   local other_len <const> = #other
   table.move(self, 1, #self, other_len + 1)
   for i = 1, other_len do
      self[i] = (other as Path)[i]
   end
end

---@desc
--- Modify a path in place to become an absolute path
---
--- When the path is already absolute, does nothing
---
--- Otherwise, prepends the current directory
function Path:to_absolute()
   if self:is_absolute() then
      return
   end
   self:prepend(lfs.currentdir())
end

---@desc
--- Create a copy of the given path
function Path:copy(): Path
   local new: Path = {}
   for i = 1, #self do
      new[i] = self[i]
   end
   return setmt(new)
end

---@desc
--- Iterate over the leading folders in a path
---
--- ex: `path.new("foo/bar/baz/bat"):ancestors()` will construct `Path` objects from "foo", "foo/bar", "foo/bar/baz"
function Path:ancestors(): function(): Path
   local idx = 0
   return function(): Path
      idx = idx + 1
      if idx >= #self then
         return
      end
      local p <const>: Path = {}
      for i = 1, idx do
         p[i] = self[i]
      end
      return setmt(p)
   end
end

---@desc
--- Get whether the "mode" attribute of the given path is set to "file"
function Path:is_file(): boolean
   return lfs.attributes(self:to_real_path(), "mode") == "file"
end

---@desc
--- Get whether the "mode" attribute of the given path is set to "directory"
function Path:is_directory(): boolean
   return lfs.attributes(self:to_real_path(), "mode") == "directory"
end

---@desc
--- Get the "modification" attribute of a file
function Path:mod_time(): integer
   return lfs.attributes(self:to_real_path(), "modification") as integer
end

---@desc
--- Attempt to create the leading directories of a given path
function Path:mk_parent_dirs(): boolean, string
   for p in self:ancestors() do
      if p:exists() then
         if not p:is_directory() then
            return false, p:to_real_path() .. " exists and is not a directory"
         end
      else
         local succ <const>, err <const> = lfs.mkdir(p:to_real_path())
         if not succ then
            return false, err
         end
      end
   end
   return true
end

---@desc
--- Attempt to create a directory at the given path, creating the parent directories
--- if needed. Can be seen as an equivalent to `mkdir -p`
function Path:mkdir(): boolean, string
   local succ <const>, err <const> = self:mk_parent_dirs()
   if succ then
      return lfs.mkdir(self:to_real_path())
   else
      return false, err
   end
end

---@desc
--- Mutate the given path by removing the leading parts from the given path
---
--- Will error if you attempt to mix absolute and non-absolute paths
function Path:remove_leading(p: string | Path)
   local leading <const> = p is string and path.new(p) or p as Path
   if xor(leading:is_absolute(), self:is_absolute()) then
      error(("Attempt to mix absolute and non-absolute path: (%s) and (%s)"):format(self:tostring(), leading:tostring()), 2)
   end
   local ptr = 1
   for chunk in chunks(leading) do
      if self[ptr] ~= chunk then
         break
      end
      ptr = ptr + 1
   end
   if ptr < #leading then
      return
   end
   for _ = 1, ptr - 1 do
      table.remove(self, 1)
   end
end

PathMt.__concat = function(a: Path | string, b: Path | string): Path
   if (b is string and string_is_absolute_path(b)) or (b is Path and b:is_absolute()) then
      error("Attempt to concatenate with absolute path", 2)
   end

   local new <const>: Path = {}
   append_to_path(new, a)
   append_to_path(new, b)

   return setmt(new)
end

---@desc
--- Check if two paths are equal
---
--- This function is used for the __eq metamethod with use_os_sep as false
function Path.eq(a: Path | string, b: Path | string, use_os_sep: boolean): boolean
   if a == nil then
      return false
   end
   if b == nil then
      return false
   end
   if rawequal(a, b) then
      return true
   end

   local pa <const> = a is string and path.new(a, use_os_sep) or (a as Path):copy()
   local pb <const> = b is string and path.new(b, use_os_sep) or (b as Path):copy()

   pa:to_absolute()
   pb:to_absolute()

   if rawlen(pa as {string}) ~= rawlen(pb as {string}) then
      return false
   end

   for i = 1, rawlen(pa as {string}) do
      if rawget(pa, i) ~= rawget(pb, i) then
         return false
      end
   end

   return true
end

PathMt.__eq = function(a: string | Path, b: string | Path): boolean
   return Path.eq(a, b, false)
end

PathMt.__tostring = Path.tostring

local function patt_escape_char(c: string): string
   return c == "*" and ".-" or "%" .. c
end

local function process_patt_chunk(s: string): string
   return s == "**"
      and "**"
      or "^" .. esc(s, patt_escape_char) .. "$"
end

-- Patterns will always use '/' as a path separator
local pattern_cache <const>: {string:{string}} = setmetatable({}, { __mode = "kv" })
local function get_patt(patt: string): {string}
   if not pattern_cache[patt] then
      local path_patt <const> = parse_string_path(patt)

      -- clear redundant **/, as they're technically valid, but its easier to process without them
      -- /foo/bar/**/**/baz -> /foo/bar/**/baz
      for i = #path_patt, 2, -1 do
         if path_patt[i] == "**" and path_patt[i-1] == "**" then
            table.remove(path_patt, i)
         end
      end

      for i, v in ipairs(path_patt) do
         path_patt[i] = process_patt_chunk(v)
      end

      pattern_cache[patt] = path_patt
   end
   return pattern_cache[patt]
end

local function match(p: {string}, path_patt: {string}): boolean
   local path_len <const> = #p
   local patt_len <const> = #path_patt

   local patt_idx = 1
   local path_idx = 1

   local double_glob_stack <const> = {}
   local function push_state()
      table.insert(double_glob_stack, {patt_idx, path_idx})
   end
   local function pop_state(): boolean
      local t <const> = table.remove(double_glob_stack)
      if not t then return false end
      patt_idx = t[1]
      path_idx = t[2] + 1
      return true
   end

   repeat
      while patt_idx <= patt_len and path_idx <= path_len do
         local patt_chunk <const> = path_patt[patt_idx]
         local path_chunk <const> = p[path_idx]

         if patt_chunk == "**" then
            push_state()
            patt_idx = patt_idx + 1
         elseif path_chunk:match(patt_chunk) then
            patt_idx = patt_idx + 1
            path_idx = path_idx + 1
         elseif not pop_state() then
            return false
         end
      end
   until (patt_idx > patt_len and path_idx > path_len)
      or (not pop_state())

   return patt_idx > patt_len
      and path_idx > path_len
end

---@desc
--- See if the given path matches the pattern
---
--- Path separators in patterns are always represented with '/'.
---
--- `*` characters represent any number of non-path-separator characters
---
--- `**/` represent any number of directories
function Path:match(patt: string): boolean
   return match(self, get_patt(patt))
end

---@desc
--- See if the given path matches any of the given patterns
function Path:match_any(patts: {string}): integer, string
   for i, patt in ipairs(patts) do
      if match(self, get_patt(patt)) then
         return i, patt
      end
   end
end

---@desc
--- Expresses a path in terms of another path.
--- If any relative paths are given, they are treated as though they are in the current directory
---
--- for example: `path.new("/foo/bar/baz"):relative_to(path.new("/foo/bat")) == path.new "../bar/baz"`
function Path:relative_to(other: Path): Path
   local a, b: Path, Path = self:copy(), other:copy()
   if xor(a:is_absolute(), b:is_absolute()) then
      if not a:is_absolute() then
         a = path.new(lfs.currentdir(), true) .. a
      else
         b = path.new(lfs.currentdir(), true) .. b
      end
   end
   local a_len <const> = #a
   local b_len <const> = #b
   local mismatch = false
   local idx = 0
   for i = 1, math.min(a_len, b_len) do
      if a[i] ~= b[i] then
         mismatch = true
         break
      end
      idx = i
   end
   if b_len > a_len then
      mismatch = true
   end
   local ret: {string} = {}
   if mismatch then
      for _ = 1, b_len - idx do
         table.insert(ret, "..")
      end
   end
   for i = idx + 1, a_len do
      table.insert(ret, a[i])
   end
   return setmt(ret)
end

---@desc
--- returns true if the path is inside the given directory
---
--- If relative and absolute paths are mixed, the relative path is assumed to
--- be in the current working directory (as determined by `lfs.currentdir()`)
---
--- If dirname is a `string`, a path will be constructed using `path.new` with
--- `use_os_sep`
function Path:is_in(dirname: string | Path, use_os_sep: boolean): boolean
   if not dirname then return false end
   local dir <const> = path.ensure(dirname, use_os_sep)

   local a, b = self, dir
   if xor(self:is_absolute(), dir:is_absolute()) then
      if self:is_absolute() then
         b = lfs.currentdir() .. b
      else
         a = lfs.currentdir() .. a
      end
   end
   if #b == 0 then
      return true
   end
   if #a < #b then
      return false
   end
   for i = 1, #b do
      if a[i] ~= b[i] then
         return false
      end
   end

   return true
end

return path
