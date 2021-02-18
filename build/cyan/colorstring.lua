local _tl_compat; if (tonumber((_VERSION or ''):match('[%d.]*$')) or 0) < 5.3 then local p, m = pcall(require, 'compat53.module'); if p then _tl_compat = m end end; local ipairs = _tl_compat and _tl_compat.ipairs or ipairs; local table = _tl_compat and _tl_compat.table or table



local ansi = require("cyan.ansi")
local util = require("cyan.util")
local map, ivalues = util.tab.map, util.tab.ivalues

local setmt = setmetatable

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

local function new(...)
   return setmt({
      content = { ... },
   }, colorstring_mt)
end

local function highlight(hl, str)
   return new(hl, str, { 0 })
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
   return setmt({ content = new_content }, colorstring_mt)
end

colorstring_mt.__tostring = ColorString.tostring
colorstring_mt.__len = ColorString.len

local function rgb_fg(r, g, b)
   return { 38, 2, r, g, b }
end

local function rgb_bg(r, g, b)
   return { 48, 2, r, g, b }
end

local colorstring = {
   colors = {
      none = { 0 },
      file = { 33 },
      number = { 31 },
      emphasis = { 1 },
      teal = rgb_fg(0, 0xAA, 0xB4),
   },

   rgb_fg = rgb_fg,
   rgb_bg = rgb_bg,

   new = new,
   highlight = highlight,
}

return colorstring