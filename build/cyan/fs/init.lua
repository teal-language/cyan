local _tl_compat; if (tonumber((_VERSION or ''):match('[%d.]*$')) or 0) < 5.3 then local p, m = pcall(require, 'compat53.module'); if p then _tl_compat = m end end; local assert = _tl_compat and _tl_compat.assert or assert; local coroutine = _tl_compat and _tl_compat.coroutine or coroutine; local io = _tl_compat and _tl_compat.io or io; local string = _tl_compat and _tl_compat.string or string



local lfs = require("lfs")
local path = require("cyan.fs.path")
local util = require("cyan.util")

local Path = path.Path

local fs = {
   path = path,
   Path = Path,
}

local function to_path(s, use_os_sep)
   return type(s) == "string" and
   assert(path.new(s, use_os_sep)) or
   s
end



function fs.current_dir()
   return path.new(lfs.currentdir(), true)
end





function fs.dir(dir, include_dotfiles)
   local iter, data = lfs.dir(
   to_path(dir):to_real_path())

   return function()
      local p
      repeat p = iter(data)


      until not p or
(include_dotfiles and p ~= "." and p ~= "..") or
p:sub(1, 1) ~= "."; return path.new(p)
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

function fs.get_line(path, n)
   local content, err = fs.read(path)
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



function fs.scan_dir(dir, include, exclude)
   include = include or {}
   exclude = exclude or {}
   local function dir_iter(_d)
      local d = to_path(_d)
      for p in fs.dir(d) do

         local full = #d > 0 and d .. p or
         p
         local to_match = full:copy()
         to_match:remove_leading(dir)
         if full:is_directory() then
            dir_iter(full)
         else
            local inc = true
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
   return coroutine.wrap(function() dir_iter(dir) end)
end










function fs.extension_split(p, ndots)
   if not p then
      return nil
   end
   local str_path = type(p) == "table" and p:to_real_path() or p
   for n = ndots or 1, 1, -1 do
      local patt = "^(.-)(" .. ("%.%a+"):rep(n) .. ")$"
      local base, ext = str_path:match(patt)
      if ext then
         ext = ext:lower()
         return base, ext
      end
   end
   return str_path
end



function fs.path_concat(a, b)
   return a .. path.separator .. b
end



function fs.search_parent_dirs(spath, fname)
   local p = to_path(spath, true)

   local in_spath = p .. fname
   if in_spath:exists() then
      return in_spath
   end

   local ancestors = util.tab.from(p:ancestors())
   for i = #ancestors, 1, -1 do
      local full = ancestors[i] .. fname
      if full:exists() then
         return full
      end
   end
end

return fs