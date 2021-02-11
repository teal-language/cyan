local _tl_compat; if (tonumber((_VERSION or ''):match('[%d.]*$')) or 0) < 5.3 then local p, m = pcall(require, 'compat53.module'); if p then _tl_compat = m end end; local coroutine = _tl_compat and _tl_compat.coroutine or coroutine; local io = _tl_compat and _tl_compat.io or io; local string = _tl_compat and _tl_compat.string or string


local lfs = require("lfs")
local path = require("teal-cli.fs.path")

local Path = path.Path

local fs = {
   path = path,
   Path = Path,
}

function fs.dir(dir, include_dotfiles)
   local iter, data = lfs.dir(
   type(dir) == "string" and dir or dir:to_real_path())

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

function fs.scan_dir(dir, include, exclude)
   local function dir_iter(d)
      for p in fs.dir(d) do
         local full = d .. p
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
   local str_path = type(p) == "string" and p or p:to_real_path()
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
   if lfs.attributes(fs.path_concat(spath, fname)) then
      return path.new(fs.path_concat(spath, fname))
   end
   for p in path.new(spath):ancestors() do
      local full = p .. fname
      if full:exists() then
         return full
      end
   end
end

return fs