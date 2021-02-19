
-- Some wrappers/conveniences around working with ansi escape codes
-- For example getting the length of a string that contains escape codes shouldnt include them

local ansi <const> = require("cyan.ansi")
local util <const> = require("cyan.util")
local map <const>, ivalues <const> = util.tab.map, util.tab.ivalues

local record ColorString
   -- This basically implements the 'string interface'

   content: {string | {number}}
   len: function(ColorString): number
   tostring: function(ColorString): string

   metamethod __len: function(ColorString): number
   metamethod __concat: function(ColorString | string, ColorString | string): ColorString
   -- metamethod __tostring: function(ColorString): string
end

function ColorString:len(): number
   local l = 0
   for _, chunk in ipairs(self.content) do
      if chunk is string then
         l = l + #chunk
      end
   end
   return l
end

local function append(base: ColorString, other: string | ColorString)
   if other is ColorString then
      for _, chunk in ipairs(other.content) do
         table.insert(base.content, chunk)
      end
   else
      table.insert(base.content, other)
   end
end

function ColorString:append(...: string | ColorString)
   for i = 1, select("#", ...) do
      append(self, (select(i, ...)))
   end
end

function ColorString:surround(col: {number})
   table.insert(self.content, 1, col)
   table.insert(self.content, 0)
end

function ColorString:tostring(): string
   return table.concat(map(self.content, function(chunk: {number} | string): string
      if chunk is string then
         return chunk
      else
         return ansi.CSI .. table.concat(map(chunk, tostring as function(number): string), ";") .. "m"
      end
   end))
end

local colorstring_mt <const>: metatable<ColorString> = {}

local function new(...: string | {number}): ColorString
   return setmetatable({
      content = { ... }
   } as ColorString, colorstring_mt)
end

local function highlight(hl: {number}, str: string): ColorString
   return new(hl, str, {0})
end

colorstring_mt.__index = ColorString

colorstring_mt.__concat = function(a: string | ColorString, b: string | ColorString): ColorString
   local cs_a <const>: ColorString = a is string and { content = {a} } as ColorString or a as ColorString
   local cs_b <const>: ColorString = b is string and { content = {b} } as ColorString or b as ColorString
   local new_content <const> = {}
   for val in ivalues(cs_a.content) do
      table.insert(new_content, val)
   end
   for val in ivalues(cs_b.content) do
      table.insert(new_content, val)
   end
   return setmetatable({ content = new_content } as ColorString, colorstring_mt)
end

colorstring_mt.__tostring = ColorString.tostring
colorstring_mt.__len = ColorString.len

local function rgb_fg(r: number, g: number, b: number): {number, number, number, number, number}
   return {38, 2, r, g, b}
end

local function rgb_bg(r: number, g: number, b: number): {number, number, number, number, number}
   return {48, 2, r, g, b}
end

local colorstring <const> = {
   ColorString = ColorString,
   colors = {
      none = {0},
      file = {33},
      number = {31},
      emphasis = {1},
      teal = rgb_fg(0, 0xAA, 0xB4),
      cyan = rgb_fg(0, 0xFF, 0xFF),
   },

   rgb_fg = rgb_fg,
   rgb_bg = rgb_bg,

   new = new,
   highlight = highlight,
}

return colorstring

