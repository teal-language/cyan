local _tl_compat; if (tonumber((_VERSION or ''):match('[%d.]*$')) or 0) < 5.3 then local p, m = true, require('compat53.module'); if p then _tl_compat = m end end; local table = _tl_compat and _tl_compat.table or table







local ivalues = require("cyan.util").tab.ivalues

local finally_queue
return function(original_finally, callback)
   if not finally_queue then
      original_finally(function()
         local queue = finally_queue
         finally_queue = nil
         for f in ivalues(queue) do
            f()
         end
      end)
      finally_queue = {}
   end
   table.insert(finally_queue, callback)
end
