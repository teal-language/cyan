
local lfs <const> = require("lfs")

local util <const> = require("teal-cli.util")

local split <const>, esc <const> = util.str.split, util.str.esc
local values <const> = util.tab.values

local record Path
   {string}

   metamethod __concat: function(Path | string, Path | string): Path
   metamethod __eq: function(Path | string, Path | string): boolean
   -- metamethod __tostring: function(Path): string
end
local PathMt <const>: metatable<Path> = {
   __index = Path,
   __name = "teal-cli.fs.path.Path",
}

local path <const> = {
   Path = Path,
   separator = package.config:sub(1, 1),
   shared_lib_ext = package.cpath:match("(%.%w+)%s*$") or ".so"
}

-- Basically the constructor for a 'raw' Path,
-- gets the path components, doesn't set the metatable
local function parse_string_path(s: string): {string}
   local new: {string} = {}
   for chunk in split(s, path.separator, true) do
      if chunk == ".." then
         if #new > 0 then
            table.remove(new)
         else
            return nil
         end
      elseif (#new > 0 and chunk ~= "") or chunk ~= "." then
         table.insert(new, chunk)
      end
   end
   return new
end

function path.new(s: string): Path
   if not s then return nil end
   local new: Path = parse_string_path(s)
   return setmetatable(new, PathMt)
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
      table.insert(p, chunk)
   end
end

function Path:is_absolute(): boolean
   if path.separator == "/" then
      return self[1] == ""
   elseif path.separator == "\\" then
      return self[1]:match("^%a:$") as boolean
   end
end

function Path:tostring(): string
   return table.concat(self, "/")
end

function Path:to_real_path(): string
   return table.concat(self, path.separator)
end

function Path:exists(): boolean
   return lfs.attributes(self:to_real_path()) ~= nil
end

function Path:append(other: string | Path)
   local p = other is string and path.new(other) or other if p:is_absolute() then
      error("Attempt to append absolute path", 2)
   end
   append_to_path(self, p)
end

function Path:prepend(other: string | Path)
   if self:is_absolute() then
      error("Attempt to prepend to absolute path", 2)
   end
   local i = 1
   for chunk in chunks(other) do
      table.insert(self, i, chunk)
      i = i + 1
   end
end

function Path:copy(): Path
   local new: Path = {}
   for i = 1, #self do
      new[i] = self[i]
   end
   return setmetatable(new, PathMt)
end

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
      return setmetatable(p, PathMt)
   end
end

function Path:is_directory(): boolean
   return lfs.attributes(self:to_real_path(), "mode") == "directory"
end

function Path:mod_time(): number
   return lfs.attributes(self:to_real_path(), "modification") as number
end

function Path:mkdir(): boolean, string
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
   return lfs.mkdir(self:to_real_path())
end

function Path:remove_leading(p: string | Path)
   local leading <const> = p is string and path.new(p) or p
   if util.xor(leading:is_absolute(), self:is_absolute()) then
      error("Attempt to mix absolute and non-absolute path", 2)
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

   return setmetatable(new, PathMt)
end

PathMt.__eq = function(a: string | Path, b: string | Path): boolean
   if rawequal(a, b) then
      return true
   end

   local pa <const> = a is string and parse_string_path(a) or a
   local pb <const> = b is string and parse_string_path(b) or b

   if rawlen(pa) ~= rawlen(pb) then
      return false
   end

   for i = 1, rawlen(pa) do
      if rawget(pa, i) ~= rawget(pb, i) then
         return false
      end
   end

   return true
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

      -- clear redundant **/, as they're technically valid, but redundant and its easier to process without them
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

local function match(p: Path, path_patt: {string}): boolean
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

   while patt_idx <= #path_patt and path_idx <= #p do
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

   return patt_idx > #path_patt
      and path_idx > #p
end

function Path:match(patt: string): boolean
   return match(self, get_patt(patt))
end

function Path:match_any(patts: {string}): boolean, number, string
   for i, patt in ipairs(patts) do
      if match(self, get_patt(patt)) then
         return true, i, patt
      end
   end
end

return path
