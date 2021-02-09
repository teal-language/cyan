
-- Filesystem and path management

local util <const> = require("teal-cli.util")
local lfs <const> = require("lfs")

local split <const>, esc <const> = util.str.split, util.str.esc
local values <const> = util.tab.values

local path_separator <const> = package.config:sub(1, 1)

local record Path
   {string}

   metamethod __concat: function(Path | string, Path | string): Path
   metamethod __eq: function(Path | string, Path | string): boolean
   -- metamethod __tostring: function(Path): string
end

local function string_is_absolute_path(p: string): boolean
   if path_separator == "/" then
      return p:sub(1, 1) == "/"
   elseif path_separator == "\\" then
      return p:match("^%a:$") as boolean
   end
end

function Path:is_absolute(): boolean
   if path_separator == "/" then
      return self[1] == ""
   elseif path_separator == "\\" then
      return self[1]:match("^%a:$") as boolean
   end
end

function Path:tostring(): string
   return table.concat(self, "/")
end

function Path:to_real_path(): string
   return table.concat(self, path_separator)
end

function Path:exists(): boolean
   return lfs.attributes(self:to_real_path()) ~= nil
end

local fs <const> = {
   path_separator = path_separator,
   Path = Path,
}

local PathMt: metatable<Path>

-- TODO: upstream, using setmetatable gives an error of expected metatable<@a>,
-- something about the typevar not getting resolved correctly?
local setmt <const> = setmetatable as function<T>(T, metatable<T>): T

local function parse_string_path(s: string): {string}
   local new: {string} = {}
   for chunk in split(s, path_separator, true) do
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

function fs.path(s: string): Path
   if not s then return nil end
   local p <const> = parse_string_path(s)
   return setmt(p as Path, PathMt)
end

local function chunks(p: Path | string): function(): string
   return p is string and split(p, path_separator, true)
      or values(p as {string})
end

local function append_to_path(p: Path, other: Path | string)
   for chunk in chunks(other) do
      table.insert(p, chunk)
   end
end

function Path:copy(): Path
   local new: Path = {}
   for i = 1, #self do
      new[i] = self[i]
   end
   return setmt(new, PathMt)
end

function Path:append(other: string | Path)
   local p = other is string and fs.path(other) or other if p:is_absolute() then
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
      return setmt(p, PathMt)
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
   local leading <const> = p is string and fs.path(p) or p
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

PathMt = {
   __concat = function(a: Path | string, b: Path | string): Path
      if (b is string and string_is_absolute_path(b)) or (b is Path and b:is_absolute()) then
         error("Attempt to concatenate with absolute path", 2)
      end

      local new <const>: Path = {}
      append_to_path(new, a)
      append_to_path(new, b)

      return setmt(new, PathMt)
   end,
   __index = Path,
   __tostring = Path.tostring,
   __eq = function(a: string | Path, b: string | Path): boolean
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
   end,
}

local function patt_escape_char(c: string): string
   return c == "*" and ".-" or "%" .. c
end

local function process_patt_chunk(s: string): string
   return s == "**"
      and "**"
      or "^" .. esc(s, patt_escape_char) .. "$"
end

--- Patterns will always use '/' as a path separator
local pattern_cache <const>: {string:{string}} = setmetatable({}, { __mode = "kv" })
function Path:match(patt: string): boolean
   if not pattern_cache[patt] then
      local path_patt <const> = parse_string_path(patt)

      -- clear redundant **/, as they're technically valid, but redundant and its easier to process without them
      -- /foo/bar/**/**/baz -> /foo/bar/**/baz
      for i = #path_patt, 2, -1 do
         if path_patt[i] == "**" and path_patt[i-1] == "**" then
            table.remove(path_patt, i)
         end
      end

      pattern_cache[patt] = path_patt
   end
   local path_patt <const> = pattern_cache[patt]

   local patt_idx = 1
   local path_idx = 1

   while patt_idx <= #path_patt and path_idx <= #self do
      local patt_chunk <const> = process_patt_chunk(path_patt[patt_idx])
      local path_chunk = self[path_idx]

      if patt_chunk == "**" then
         local lookahead <const> = process_patt_chunk(path_patt[patt_idx + 1])
         if not lookahead then
            return false
         end
         while path_idx <= #self do
            path_idx = path_idx + 1
            if path_chunk:match(lookahead) then
               patt_idx = patt_idx + 1
               break
            end
            path_chunk = self[path_idx]
         end
         patt_idx = patt_idx + 1
      elseif path_chunk:match(patt_chunk) then
         patt_idx = patt_idx + 1
         path_idx = path_idx + 1
      else
         return false
      end
   end
   return patt_idx >= #path_patt
end

function Path:match_any(patts: {string}): boolean, number, string
   for i, patt in ipairs(patts) do
      if self:match(patt) then
         return true, i, patt
      end
   end
end

function fs.dir(dir: string | Path, include_dotfiles: boolean): function(): Path
   local iter <const>, data <const> = lfs.dir(
      dir is string and dir or dir:to_real_path()
   ) as (function(any): (string), any)
   return function(): Path
      local p: string
      repeat p = iter(data)
      until not p
         or (include_dotfiles and p ~= "." and p ~= "..")
         or p:sub(1, 1) ~= "."

      return fs.path(p)
   end
end

local read_cache <const>: {string:string} = setmetatable({}, { __mode = "k" }) -- TODO: does this even do anything?
function fs.read(path: string): string, string
   if not read_cache[path] then
      local fh <const>, err <const> = io.open(path, "r")
      if not fh then
         return nil, err
      end
      read_cache[path] = fh:read("*a")
      fh:close()
   end
   return read_cache[path]
end

function Path:read_file(): string, string
   return fs.read(self:to_real_path())
end

function fs.scan_dir(dir: string | Path, include: {string}, exclude: {string}): function(): Path
   local function dir_iter(d: string | Path)
      for p in fs.dir(d) do
         if p:is_directory() then
            dir_iter(p)
         else
            local inc = true
            if #include > 0 then
               inc = p:match_any(include)
            end
            if inc and #exclude > 0 then
               inc = not p:match_any(exclude)
            end
            if inc then
               coroutine.yield(p)
            end
         end
      end
   end
   return coroutine.wrap(function() dir_iter(dir) end) as function(): Path
end

function fs.extension_split(path: string, ndots: number): string, string
   if not path then
      return nil
   end
   for n = ndots or 1, 1, -1 do
      local patt <const> = "^(.-)(" .. ("%.%a+"):rep(n) .. ")$"
      local base <const>, ext = path:match(patt)
      if ext then
         ext = ext:lower()
         return base, ext
      end
   end
   return path
end

function fs.path_concat(a: string, b: string): string
   return a .. path_separator .. b
end

function fs.search_parent_dirs(spath: string, fname: string): string
   local chunks <const> = parse_string_path(spath)
   for i = #chunks, 1, -1 do
      local chunk <const> = chunks[i]
      local head <const> = table.concat(chunks, path_separator, 1, i)
      local full_path <const> = fs.path_concat(head, fname)
      if lfs.attributes(full_path) then
         return full_path
      end
   end
end

return fs

