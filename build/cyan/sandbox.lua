local _tl_compat; if (tonumber((_VERSION or ''):match('[%d.]*$')) or 0) < 5.3 then local p, m = true, require('compat53.module'); if p then _tl_compat = m end end; local assert = _tl_compat and _tl_compat.assert or assert; local coroutine = _tl_compat and _tl_compat.coroutine or coroutine; local debug = _tl_compat and _tl_compat.debug or debug; local load = _tl_compat and _tl_compat.load or load; local loadfile = _tl_compat and _tl_compat.loadfile or loadfile; local table = _tl_compat and _tl_compat.table or table; local _tl_table_unpack = unpack or table.unpack






local Sandbox = {}




local sandbox = {
   Sandbox = Sandbox,
}



function Sandbox:run(max_instructions, ...)
   max_instructions = max_instructions or 1000000
   local t = coroutine.create(self._fn)

   local instructions = 0
   debug.sethook(t, function()
      instructions = instructions + 1000
      if instructions > max_instructions then
         if jit then


            debug.sethook(nil, nil)
         else
            error("Exceeded maximum instructions", 2)
         end
      end
   end, "", 1000)

   local res = { coroutine.resume(t, ...) }
   if res[1] then
      table.remove(res, 1)
      self._result = res
      return true
   end

   return false, res[2] .. "\n" .. debug.traceback(t)
end

function Sandbox:result()
   return _tl_table_unpack(self._result)
end

function sandbox.new(f)
   assert(f, "sandbox.new requires a function")
   return setmetatable({ _fn = f }, { __index = Sandbox })
end


function sandbox.from_file(path, env)
   local chunk, err


   if setfenv then
      chunk, err = loadfile(path)
      if chunk then
         setfenv(chunk, env)
      end
   else
      chunk, err = loadfile(path, "t", env)
   end

   if not chunk then
      return nil, err
   end

   return sandbox.new(chunk)
end


function sandbox.from_string(s, chunkname, env)
   local chunk, err
   if loadstring then
      chunk, err = loadstring(s, chunkname)
      if chunk then
         setfenv(chunk, env)
      end
   else
      chunk, err = load(s, chunkname, "t", env)
   end

   if not chunk then
      return nil, err
   end

   return sandbox.new(chunk)
end

return sandbox
