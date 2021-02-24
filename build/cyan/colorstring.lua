local _tl_compat; if (tonumber((_VERSION or ''):match('[%d.]*$')) or 0) < 5.3 then local p, m = true, require('compat53.module'); if p then _tl_compat = m end end; local ipairs = _tl_compat and _tl_compat.ipairs or ipairs; local table = _tl_compat and _tl_compat.table or table




local ansi = require("cyan.ansi")
local util = require("cyan.util")
local map, ivalues = util.tab.map, util.tab.ivalues






local ColorString = {}









function ColorString:len()
   local l = 0
   for _, chunk in ipairs(self.content) do
      if type(chunk) == "string" then
         l = l + #chunk
      end
   end
   return l
end

local function append(base, other)
   if type(other) == "table" then
      for _, chunk in ipairs(other.content) do
         table.insert(base.content, chunk)
      end
   else
      table.insert(base.content, other)
   end
end

function ColorString:append(...)
   for i = 1, select("#", ...) do
      append(self, (select(i, ...)))
   end
end



function ColorString:surround(col)
   table.insert(self.content, 1, col)
   table.insert(self.content, 0)
end



function ColorString:tostring()
   return table.concat(map(self.content, function(chunk)
      if type(chunk) == "string" then
         return chunk
      else
         return ansi.CSI .. table.concat(map(chunk, tostring), ";") .. "m"
      end
   end))
end

local colorstring_mt = {}

local colorstring = {
   ColorString = ColorString,
   colors = {},
}



function colorstring.new(...)
   return setmetatable({
      content = { ... },
   }, colorstring_mt)
end



function colorstring.highlight(hl, str)
   return colorstring.new(hl, str, { 0 })
end

colorstring_mt.__index = ColorString

colorstring_mt.__concat = function(a, b)
   local cs_a = type(a) == "string" and { content = { a } } or a
   local cs_b = type(b) == "string" and { content = { b } } or b
   local new_content = {}
   for val in ivalues(cs_a.content) do
      table.insert(new_content, val)
   end
   for val in ivalues(cs_b.content) do
      table.insert(new_content, val)
   end
   return setmetatable({ content = new_content }, colorstring_mt)
end

colorstring_mt.__tostring = ColorString.tostring
colorstring_mt.__len = ColorString.len



function colorstring.rgb_fg(r, g, b)
   return { 38, 2, r, g, b }
end



function colorstring.rgb_bg(r, g, b)
   return { 48, 2, r, g, b }
end

colorstring.colors.none = { 0 }
colorstring.colors.file = { 33 }
colorstring.colors.number = { 31 }
colorstring.colors.emphasis = { 1 }
colorstring.colors.teal = colorstring.rgb_fg(0, 0xAA, 0xB4)
colorstring.colors.cyan = colorstring.rgb_fg(0, 0xFF, 0xFF)

return colorstring