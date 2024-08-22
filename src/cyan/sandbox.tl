
---@brief
--- Super simplistic sandboxing
--- In the future maybe could be integrated with some very simple debugging utilities
--- for now, we just offer the convenience of exiting gracefully if someone puts
--- `while true do end` in their config for some reason

local record Sandbox
   _fn: function
   _result: {any}
end

local sandbox <const> = {
   Sandbox = Sandbox,
}

global jit: any

function Sandbox:run(max_instructions: integer, ...: any): boolean, string
   max_instructions = max_instructions or 1000000
   local t = coroutine.create(self._fn)

   local instructions = 0
   debug.sethook(t, function()
      instructions = instructions + 1000
      if instructions > max_instructions then
         if jit then
            -- luajit has a "feature" with debug.sethook that causes the hook to be set on the main thread
            -- so instead of the coroutine gracefully stopping in a controlled way, cyan just errors out
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

   return false, res[2] as string .. "\n" .. debug.traceback(t)
end

function Sandbox:result(): any...
   return table.unpack(self._result)
end

function sandbox.new(f: function): Sandbox
   assert(f, "sandbox.new requires a function")
   return setmetatable({ _fn = f }, { __index = Sandbox })
end

global setfenv: function(f: function, env: {string:any})
function sandbox.from_file(path: string, env: {string:any}): Sandbox, string
   local chunk, err: function, string

   -- TODO: Can compat53 do some of this for us?
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

global loadstring: function(string, string): function, string
function sandbox.from_string(s: string, chunkname: string, env: {string:any}): Sandbox, string
   local chunk, err: function, string
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

