local _tl_compat; if (tonumber((_VERSION or ''):match('[%d.]*$')) or 0) < 5.3 then local p, m = pcall(require, 'compat53.module'); if p then _tl_compat = m end end; local ipairs = _tl_compat and _tl_compat.ipairs or ipairs; local table = _tl_compat and _tl_compat.table or table



local ansi = require("teal-cli.ansi")
local map = require("teal-cli.util").tab.map

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
   elseif type(other) == "number" then
      table.insert(base.content, { other })
   else
      table.insert(base.content, other)
   end
end

function ColorString:append(...)
   for i = 1, select("#", ...) do
      append(self, (select(i, ...)))
   end
   return self
end

function ColorString:append_ansi_esc(c, ...)
   table.insert(self.content, { c, ... })
   return self
end

function ColorString:tostring()
   return table.concat(map(self.content, function(chunk)
      if type(chunk) == "string" then
         return chunk
      else
         return ansi.CSI .. table.concat(
         map(chunk, tostring),
         ";") .. "m"
      end
   end))
end

local colorstring_mt = {}
colorstring_mt.__index = ColorString
colorstring_mt.__concat = function(a, b)
   local new = setmetatable({ content = {} }, colorstring_mt)
   return new:append(a):append(b)
end
colorstring_mt.__tostring = ColorString.tostring
colorstring_mt.__len = ColorString.len

local colorstring = {
   colors = {
      file = 33,
      number = 31,
   },
}

local setmt = setmetatable
function colorstring.new(...)
   local new = setmt({
      content = {},
   }, colorstring_mt)
   return new:append(...)
end

return colorstring