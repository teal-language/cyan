local _tl_compat; if (tonumber((_VERSION or ''):match('[%d.]*$')) or 0) < 5.3 then local p, m = true, require('compat53.module'); if p then _tl_compat = m end end; local ipairs = _tl_compat and _tl_compat.ipairs or ipairs; local pairs = _tl_compat and _tl_compat.pairs or pairs; local string = _tl_compat and _tl_compat.string or string; local table = _tl_compat and _tl_compat.table or table






local str = {}
local tab = {}



function tab.keys(t)
   local k
   return function()
      k = next(t, k)
      return k
   end
end



function tab.sort_in_place(t, fn)
   table.sort(t, fn)
   return t
end



function tab.values(t)
   local k, v
   return function()
      k, v = next(t, k)
      return v
   end
end



function tab.ivalues(t)
   local i = 0
   return function()
      i = i + 1
      return t[i]
   end
end



function tab.from(fn, ...)
   local t = {}
   for val in fn, ... do
      table.insert(t, val)
   end
   return t
end



function tab.set(lst)
   local s = {}
   for _, v in ipairs(lst) do
      s[v] = true
   end
   return s
end



function tab.map(t, fn)
   local new = {}
   for k, v in pairs(t) do
      new[k] = fn(v)
   end
   return new
end



function tab.map_ipairs(t, fn)
   local i = 0
   return function()
      i = i + 1
      if not t[i] then
         return
      else
         return i, fn(t[i])
      end
   end
end



function tab.intersperse(t, val)
   local new = {}
   local len = #t
   for i, v in ipairs(t) do
      local idx = 2 * i
      new[idx - 1] = v
      if i < len then
         new[idx] = val
      end
   end
   return new
end



function tab.filter(t, pred)
   local pass = {}
   local fail = {}
   for _, v in ipairs(t) do
      table.insert(pred(v) and pass or fail, v)
   end
   return pass, fail
end



function tab.merge_list(a, b)
   local new_list = {}
   a = a or {}
   b = b or {}
   for _, v in ipairs(a) do
      table.insert(new_list, v)
   end
   for _, v in ipairs(b) do
      table.insert(new_list, v)
   end
   return new_list
end



function tab.contains(t, val)
   for _, v in ipairs(t) do
      if val == v then
         return true
      end
   end
   return false
end





function str.split_find(s, del, no_patt)
   local idx = 0
   local prev_idx, start_idx
   return function()
      if not idx then return end
      idx = idx + 1
      prev_idx = idx
      start_idx, idx = s:find(del, idx, no_patt)
      if start_idx and idx and idx < start_idx then
         error("Delimiter " .. tostring(del) .. " matched the empty string", 2)
      end
      return prev_idx, (start_idx or 0) - 1
   end
end





function str.split(s, del, no_patt)
   local iter = str.split_find(s, del, no_patt)
   return function()
      local a, b = iter()
      if not a then return end
      return s:sub(a, b)
   end
end

local function esc_char(c)
   return "%" .. c
end







function str.esc(s, sub)
   return s:gsub(
   "[%^%$%(%)%%%.%[%]%*%+%-%?]",
   sub or
   esc_char)

end



function str.pad_left(s, n)
   return (" "):rep(n - s:len()) .. s
end

local function xor(a, b)
   return (a and not b) or
   (not a and b)
end

return {
   str = str,
   tab = tab,

   xor = xor,
}
