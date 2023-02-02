local _tl_compat; if (tonumber((_VERSION or ''):match('[%d.]*$')) or 0) < 5.3 then local p, m = true, require('compat53.module'); if p then _tl_compat = m end end; local coroutine = _tl_compat and _tl_compat.coroutine or coroutine; local io = _tl_compat and _tl_compat.io or io; local string = _tl_compat and _tl_compat.string or string



local lfs = require("lfs")
local path = require("cyan.fs.path")
local util = require("cyan.util")

local Path = path.Path

local fs = {
   path = path,
   Path = Path,
}

local ensure = path.ensure



function fs.cwd()
   return path.new(lfs.currentdir(), true)
end



function fs.chdir(p)
   return lfs.chdir(ensure(p):to_real_path())
end





function fs.dir(dir, include_dotfiles)
   local iter, data = lfs.dir(
   ensure(dir):to_real_path())

   return function()
      local p
      repeat p = iter(data)


      until not p or
(include_dotfiles and p ~= "." and p ~= "..") or
p:sub(1, 1) ~= "."; return path.new(p)
   end
end

local read_cache = {}





function fs.read(p)
   if not read_cache[p] then
      local fh, err = io.open(p, "r")
      if not fh then
         return nil, err
      end
      read_cache[p] = fh:read("*a")
      fh:close()
   end
   return read_cache[p]
end









function fs.get_line(p, n)
   local content, err = fs.read(p)
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





function fs.scan_dir(dir, include, exclude, include_directories)
   include = include or {}
   exclude = exclude or {}
   local function matches(to_match)
      local inc = nil
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
   local function dir_iter(_d)
      local d = ensure(_d)
      for p in fs.dir(d) do

         local full = #d > 0 and d .. p or
         p
         local to_match = full:copy()
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






function fs.search_parent_dirs(start_path, fname)
   local p = ensure(start_path, true)

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





function fs.copy(source, dest)
   local source_path = ensure(source, true)
   local dest_path = ensure(dest, true)

   local source_contents, read_err = fs.read(source_path:to_real_path())
   if not source_contents then
      return false, read_err
   end
   local fh, open_err = io.open(dest_path:to_real_path(), "r")
   if not fh then
      return false, open_err
   end
   fh:write(source_contents)
   fh:close()
   return true
end

return fs
