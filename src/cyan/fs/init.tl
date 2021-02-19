
-- Filesystem and path management

local lfs <const> = require("lfs")
local path <const> = require("cyan.fs.path")

local Path <const> = path.Path

local fs <const> = {
   path = path,
   Path = Path,
}

function fs.current_dir(): Path
   return path.new(lfs.currentdir())
end

function fs.dir(dir: string | Path, include_dotfiles: boolean): function(): Path
   local iter <const>, data <const> = lfs.dir(
      dir is Path and dir:to_real_path() or dir as string
   ) as (function(any): (string), any)
   return function(): Path
      local p: string
      repeat p = iter(data)
      until not p
         or (include_dotfiles and p ~= "." and p ~= "..")
         or p:sub(1, 1) ~= "."

      return path.new(p)
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

function fs.scan_dir(dir: string | Path, include: {string}, exclude: {string}): function(): Path
   include = include or {}
   exclude = exclude or {}
   local function dir_iter(d: string | Path)
      for p in fs.dir(d) do
         local full <const> = d .. p
         local to_match <const> = full:copy()
         to_match:remove_leading(dir)
         if full:is_directory() then
            dir_iter(full)
         else
            local inc: boolean | number = true
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
   return coroutine.wrap(function() dir_iter(dir) end) as function(): Path
end

function fs.extension_split(p: Path | string, ndots: number): string, string
   if not p then
      return nil
   end
   local str_path <const> = p is Path and p:to_real_path() or p as string
   for n = ndots or 1, 1, -1 do
      local patt <const> = "^(.-)(" .. ("%.%a+"):rep(n) .. ")$"
      local base <const>, ext = str_path:match(patt)
      if ext then
         ext = ext:lower()
         return base, ext
      end
   end
   return str_path
end

function fs.path_concat(a: string, b: string): string
   return a .. path.separator .. b
end

function fs.search_parent_dirs(spath: string, fname: string): Path
   if lfs.attributes(fs.path_concat(spath, fname)) then
      return path.new(fs.path_concat(spath, fname))
   end
   for p in path.new(spath):ancestors() do
      local full <const> = p .. fname
      if full:exists() then
         return full
      end
   end
end

return fs

