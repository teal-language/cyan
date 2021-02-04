
-- Filesystem and path management

local util <const> = require("teal-cli.util")
local lfs <const> = require("lfs")

local split <const>, esc <const> = util.str.split, util.str.esc
local values <const> = util.tab.values

local path_separator <const> = package.config:sub(1, 1)

local record Path
   {string}

   metamethod __concat: function(Path | string, Path | string): Path
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
            return nil
         else
            table.remove(new)
         end
      elseif (#new > 0 and chunk ~= "")
         or chunk ~= "."
      then
         table.insert(new, chunk)
      end
   end
   return new
end

local function path(s: string): Path
   if not s then return nil end
   local p = parse_string_path(s)
   return setmt(p as Path, PathMt)
end

local function append_to_path(p: Path, other: Path | string)
   local iter: function(): string
   if other is string then
      iter = split(other, path_separator, true)
   else
      iter = values(other as {string})
   end
   for chunk in iter do
      table.insert(p, chunk)
   end
end

PathMt = {
   __concat = function(a: Path | string, b: Path | string): Path
      if (b is string and string_is_absolute_path(b)) or (b is Path and b:is_absolute()) then
         error("Attempt to concatenate with absolute path")
      end

      local new <const>: Path = {}
      append_to_path(new, a)
      append_to_path(new, b)

      return setmt(new, PathMt)
   end,
   __index = Path,
   __tostring = Path.tostring,
}

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

      return path(p)
   end
end

local function process_patt_chunk(s: string): string
   return s == "**"
      and "**"
      or "^" .. esc(s, function(c: string): string
         return c == "*" and ".-" or "%" .. c
      end) .. "$"
end

--- Patterns will always use '/' as a path separator
function Path:match(patt: string): boolean
   local path_patt <const> = parse_string_path(patt)

   -- clear redundant **/, as they're technically valid, but redundant and its easier to process without them
   -- /foo/bar/**/**/baz -> /foo/bar/**/baz
   for i = #path_patt, 2, -1 do
      if path_patt[i] == "**" and path_patt[i-1] == "**" then
         table.remove(path_patt, i)
      end
   end

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
         while path_idx <= #self  do
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

function fs.extension_split(path: string, ndots: number): string, string
   if not path then
      return nil
   end
   for n = ndots or 1, 1, -1 do
      local patt = "^(.-)(" .. ("%.%a+"):rep(n) .. ")$"
      local base, ext = path:match(patt)
      if ext then
         ext = ext:lower()
         return base, ext
      end
   end
   return path
end

return fs

