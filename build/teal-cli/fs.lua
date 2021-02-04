local _tl_compat; if (tonumber((_VERSION or ''):match('[%d.]*$')) or 0) < 5.3 then local p, m = pcall(require, 'compat53.module'); if p then _tl_compat = m end end; local io = _tl_compat and _tl_compat.io or io; local package = _tl_compat and _tl_compat.package or package; local string = _tl_compat and _tl_compat.string or string; local table = _tl_compat and _tl_compat.table or table


local util = require("teal-cli.util")
local lfs = require("lfs")

local split, esc = util.str.split, util.str.esc
local values = util.tab.values

local path_separator = package.config:sub(1, 1)

local Path = {}






local function string_is_absolute_path(p)
   if path_separator == "/" then
      return p:sub(1, 1) == "/"
   elseif path_separator == "\\" then
      return p:match("^%a:$")
   end
end

function Path:is_absolute()
   if path_separator == "/" then
      return self[1] == ""
   elseif path_separator == "\\" then
      return self[1]:match("^%a:$")
   end
end

function Path:tostring()
   return table.concat(self, "/")
end

function Path:to_real_path()
   return table.concat(self, path_separator)
end

local fs = {
   path_separator = path_separator,
   Path = Path,
}

local PathMt



local setmt = setmetatable

local function parse_string_path(s)
   local new = {}
   for chunk in split(s, path_separator, true) do
      if chunk == ".." then
         if #new > 0 then
            return nil
         else
            table.remove(new)
         end
      elseif (#new > 0 and chunk ~= "") or
         chunk ~= "." then

         table.insert(new, chunk)
      end
   end
   return new
end

local function path(s)
   if not s then return nil end
   local p = parse_string_path(s)
   return setmt(p, PathMt)
end

local function append_to_path(p, other)
   local iter
   if type(other) == "string" then
      iter = split(other, path_separator, true)
   else
      iter = values(other)
   end
   for chunk in iter do
      table.insert(p, chunk)
   end
end

PathMt = {
   __concat = function(a, b)
      if (type(b) == "string" and string_is_absolute_path(b)) or (type(b) == "table" and b:is_absolute()) then
         error("Attempt to concatenate with absolute path")
      end

      local new = {}
      append_to_path(new, a)
      append_to_path(new, b)

      return setmt(new, PathMt)
   end,
   __index = Path,
   __tostring = Path.tostring,
}

function fs.dir(dir, include_dotfiles)
   local iter, data = lfs.dir(
   type(dir) == "string" and dir or dir:to_real_path())

   return function()
      local p
      repeat p = iter(data)
      until not p or
(include_dotfiles and p ~= "." and p ~= "..") or
p:sub(1, 1) ~= "."

      return path(p)
   end
end

local function process_patt_chunk(s)
   return s == "**" and
   "**" or
   "^" .. esc(s, function(c)
      return c == "*" and ".-" or "%" .. c
   end) .. "$"
end


function Path:match(patt)
   local path_patt = parse_string_path(patt)



   for i = #path_patt, 2, -1 do
      if path_patt[i] == "**" and path_patt[i - 1] == "**" then
         table.remove(path_patt, i)
      end
   end

   local patt_idx = 1
   local path_idx = 1

   while patt_idx <= #path_patt and path_idx <= #self do
      local patt_chunk = process_patt_chunk(path_patt[patt_idx])
      local path_chunk = self[path_idx]

      if patt_chunk == "**" then
         local lookahead = process_patt_chunk(path_patt[patt_idx + 1])
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

local read_cache = setmetatable({}, { __mode = "k" })
function fs.read(path)
   if not read_cache[path] then
      local fh, err = io.open(path, "r")
      if not fh then
         return nil, err
      end
      read_cache[path] = fh:read("*a")
      fh:close()
   end
   return read_cache[path]
end

function Path:read_file()
   return fs.read(self:to_real_path())
end

function fs.extension_split(path, ndots)
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
