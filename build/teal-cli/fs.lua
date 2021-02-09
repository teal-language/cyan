local _tl_compat; if (tonumber((_VERSION or ''):match('[%d.]*$')) or 0) < 5.3 then local p, m = pcall(require, 'compat53.module'); if p then _tl_compat = m end end; local coroutine = _tl_compat and _tl_compat.coroutine or coroutine; local io = _tl_compat and _tl_compat.io or io; local ipairs = _tl_compat and _tl_compat.ipairs or ipairs; local package = _tl_compat and _tl_compat.package or package; local rawlen = _tl_compat and _tl_compat.rawlen or rawlen; local string = _tl_compat and _tl_compat.string or string; local table = _tl_compat and _tl_compat.table or table


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

function Path:exists()
   return lfs.attributes(self:to_real_path()) ~= nil
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

function fs.path(s)
   if not s then return nil end
   local p = parse_string_path(s)
   return setmt(p, PathMt)
end

local function chunks(p)
   return type(p) == "string" and split(p, path_separator, true) or
   values(p)
end

local function append_to_path(p, other)
   for chunk in chunks(other) do
      table.insert(p, chunk)
   end
end

function Path:copy()
   local new = {}
   for i = 1, #self do
      new[i] = self[i]
   end
   return setmt(new, PathMt)
end

function Path:append(other)
   local p = type(other) == "string" and fs.path(other) or other; if p:is_absolute() then
      error("Attempt to append absolute path", 2)
   end
   append_to_path(self, p)
end

function Path:prepend(other)
   if self:is_absolute() then
      error("Attempt to prepend to absolute path", 2)
   end
   local i = 1
   for chunk in chunks(other) do
      table.insert(self, i, chunk)
      i = i + 1
   end
end

function Path:ancestors()
   local idx = 0
   return function()
      idx = idx + 1
      if idx >= #self then
         return
      end
      local p = {}
      for i = 1, idx do
         p[i] = self[i]
      end
      return setmt(p, PathMt)
   end
end

function Path:is_directory()
   return lfs.attributes(self:to_real_path(), "mode") == "directory"
end

function Path:mod_time()
   return lfs.attributes(self:to_real_path(), "modification")
end

function Path:mkdir()
   for p in self:ancestors() do
      if p:exists() then
         if not p:is_directory() then
            return false, p:to_real_path() .. " exists and is not a directory"
         end
      else
         local succ, err = lfs.mkdir(p:to_real_path())
         if not succ then
            return false, err
         end
      end
   end
   return lfs.mkdir(self:to_real_path())
end

function Path:remove_leading(p)
   local leading = type(p) == "string" and fs.path(p) or p
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
   __concat = function(a, b)
      if (type(b) == "string" and string_is_absolute_path(b)) or (type(b) == "table" and b:is_absolute()) then
         error("Attempt to concatenate with absolute path", 2)
      end

      local new = {}
      append_to_path(new, a)
      append_to_path(new, b)

      return setmt(new, PathMt)
   end,
   __index = Path,
   __tostring = Path.tostring,
   __eq = function(a, b)
      if rawequal(a, b) then
         return true
      end

      local pa = type(a) == "string" and parse_string_path(a) or a
      local pb = type(b) == "string" and parse_string_path(b) or b

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

local function patt_escape_char(c)
   return c == "*" and ".-" or "%" .. c
end

local function process_patt_chunk(s)
   return s == "**" and
   "**" or
   "^" .. esc(s, patt_escape_char) .. "$"
end


local pattern_cache = setmetatable({}, { __mode = "kv" })
function Path:match(patt)
   if not pattern_cache[patt] then
      local path_patt = parse_string_path(patt)



      for i = #path_patt, 2, -1 do
         if path_patt[i] == "**" and path_patt[i - 1] == "**" then
            table.remove(path_patt, i)
         end
      end

      pattern_cache[patt] = path_patt
   end
   local path_patt = pattern_cache[patt]

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

function Path:match_any(patts)
   for i, patt in ipairs(patts) do
      if self:match(patt) then
         return true, i, patt
      end
   end
end

function fs.dir(dir, include_dotfiles)
   local iter, data = lfs.dir(
   type(dir) == "string" and dir or dir:to_real_path())

   return function()
      local p
      repeat p = iter(data)
      until not p or
(include_dotfiles and p ~= "." and p ~= "..") or
p:sub(1, 1) ~= "."

      return fs.path(p)
   end
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

function fs.scan_dir(dir, include, exclude)
   local function dir_iter(d)
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
   return coroutine.wrap(function() dir_iter(dir) end)
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

function fs.path_concat(a, b)
   return a .. path_separator .. b
end

function fs.search_parent_dirs(spath, fname)
   local chunks = parse_string_path(spath)
   for i = #chunks, 1, -1 do
      local chunk = chunks[i]
      local head = table.concat(chunks, path_separator, 1, i)
      local full_path = fs.path_concat(head, fname)
      if lfs.attributes(full_path) then
         return full_path
      end
   end
end

return fs
