-- Each busted test may only have one `finally` callback. But we have a lot of
-- things we need to clean up when tests are over (mostly temporary files)
--
-- So we build up a queue of callbacks and run them in a single callback
--
-- Due to the way busted works (by using function environments), we need to
-- pass the original `finally` function

local ivalues <const> = require("cyan.util").tab.ivalues

local finally_queue: {function()}
return function(original_finally: function(function()), callback: function())
   if not finally_queue then
      original_finally(function()
         local queue <const> = finally_queue
         finally_queue = nil
         for f in ivalues(queue) do
            f()
         end
      end)
      finally_queue = {}
   end
   table.insert(finally_queue, callback)
end
