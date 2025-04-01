local _tl_compat; if (tonumber((_VERSION or ''):match('[%d.]*$')) or 0) < 5.3 then local p, m = true, require('compat53.module'); if p then _tl_compat = m end end; local coroutine = _tl_compat and _tl_compat.coroutine or coroutine; local io = _tl_compat and _tl_compat.io or io; local ipairs = _tl_compat and _tl_compat.ipairs or ipairs; local package = _tl_compat and _tl_compat.package or package; local string = _tl_compat and _tl_compat.string or string; local type = type



local lfs = require("lfs")
local util = require("cyan.util")
local lexical_path = require("lexical-path")

local fs = {
   path_separator = package.config:sub(1, 1),
   shared_lib_extension = package.cpath:match("(%.%w+)%s*$") or ".so",
}




function fs.current_directory()
   local dir, err = lfs.currentdir()
   if not dir then
      return nil, err
   end
   return (lexical_path.from_os(dir))
end





function fs.change_directory(p)
   return lfs.chdir(p:to_string())
end



function fs.exists(p)
   return lfs.attributes(p:to_string()) ~= nil
end





function fs.is_directory(p)
   local mode, err = lfs.attributes(p:to_string(), "mode")
   return mode == "directory" and true or nil, err
end



function fs.is_file(p)
   local mode, err = lfs.attributes(p:to_string(), "mode")
   return mode == "file" and true or nil, err
end





function fs.mod_time(of)
   local mod, err = lfs.attributes(of:to_string(), "modification")
   return mod, err
end



function fs.normalize(p)
   return lexical_path.from_os(p):to_string()
end





function fs.iterate_directory(dir, include_dotfiles)
   local iter, data = lfs.dir(dir:to_string())
   return function()
      local p
      repeat p = iter(data)


      until not p or
(include_dotfiles and p ~= "." and p ~= "..") or
p:sub(1, 1) ~= "."; if p then
         return (lexical_path.from_os(p))
      end end
end

local read_cache = {}





function fs.read(p)
   p = fs.normalize(p)
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




function fs.match_any(path, patterns)
   for i, pattern in ipairs(patterns) do
      if path:match(pattern) then
         return i
      end
   end
   return nil
end





function fs.scan_directory(
   dir,
   include,
   exclude,
   include_directories)

   local function ensure_pattern(x)
      if type(x) == "string" then
         return lexical_path.parse_pattern(x)
      end
      return x
   end
   local include_patterns = util.tab.map(include or {}, ensure_pattern)
   local exclude_patterns = util.tab.map(exclude or {}, ensure_pattern)

   local function matches(to_match)
      local inc = nil
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
   local function dir_iter(d)
      for p in fs.iterate_directory(d) do
         local full = d .. p
         local to_match = full:remove_leading(dir)
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
   return coroutine.wrap(function() dir_iter(dir) end)
end






function fs.search_parent_dirs(start_path, fname)
   local in_spath = start_path .. fname
   if fs.exists(in_spath) then
      return in_spath
   end

   local ancestors = util.tab.from(start_path:ancestors())
   for i = #ancestors, 1, -1 do
      local full = ancestors[i] .. fname
      if fs.exists(full) then
         return full
      end
   end
end





function fs.copy(source_path, dest_path)
   local source_contents, read_err = fs.read(source_path:to_string())
   if not source_contents then
      return false, read_err
   end
   local dest_real_path = dest_path:to_string()
   local fh, open_err = io.open(dest_real_path, "w")
   if not fh then
      return false, open_err
   end
   fh:write(source_contents)
   fh:close()
   read_cache[dest_real_path] = source_contents
   return true
end





function fs.make_parent_directories(of)
   for p in of:ancestors() do
      if fs.exists(p) then
         if not fs.is_directory(p) then
            return false, p:to_string() .. " exists and is not a directory"
         end
      else
         local succ, err = lfs.mkdir(p:to_string())
         if not succ then
            return false, err
         end
      end
   end
   return true
end





function fs.make_directory(path)
   local succ, err = fs.make_parent_directories(path)
   if succ then
      succ, err = lfs.mkdir(path:to_string())
   end
   return succ, err
end

return fs
