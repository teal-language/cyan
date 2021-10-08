
---@brief
--- Some wrappers/conveniences around working with ansi escape codes.
--- For example getting the length of a string that contains escape codes shouldnt include them

local ansi <const> = require("cyan.ansi")
local util <const> = require("cyan.util")
local map <const>, ivalues <const> = util.tab.map, util.tab.ivalues

---@desc
--- The main object that this library consumes and produces. It basically implements the
--- 'string' interface and can be used wherever a string is.
---
--- Colors are described as arrays of numbers that directly correspond to ANSI escape sequences
local record ColorString
   content: {string | {integer}}
   len: function(ColorString): integer
   tostring: function(ColorString): string

   metamethod __len: function(ColorString): integer
   metamethod __concat: function(ColorString | string, ColorString | string): ColorString
   -- metamethod __tostring: function(ColorString): string
end

---@desc
--- Get the length of a given `ColorString`, not counting any escape sequences.
---
--- Note that `ColorString:len() >= ColorString:tostring():len()`
function ColorString:len(): integer
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

function ColorString:insert(...: string | {integer})
   for i = 1, select("#", ...) do
      table.insert(self.content, (select(i, ...)))
   end
end

---@desc
--- surrounds a string with a color
function ColorString:surround(col: {integer})
   table.insert(self.content, 1, col)
   table.insert(self.content, 0)
end

---@desc
--- Converts a `Colorstring` to a regular string with the correct ANSI escapes
function ColorString:tostring(): string
   return table.concat(map(self.content, function(chunk: {integer} | string): string
      if chunk is string then
         return chunk
      else
         return ansi.CSI .. table.concat(map(chunk, tostring as function(integer): string), ";") .. "m"
      end
   end))
end

---@desc
--- Converts a `Colorstring` to a regular string, stripping any ANSI escapes
function ColorString:to_raw(): string
   local buf = {}
   for v in ivalues(self.content) do
      if v is string then
         table.insert(buf, v)
      end
   end
   return table.concat(buf)
end

local colorstring_mt <const>: metatable<ColorString> = {}

local colorstring <const> = {
   ColorString = ColorString,
   colors: {string:{integer}} = {}
}

---@desc
--- The `Colorstring` constructor
function colorstring.new(...: string | {integer}): ColorString
   return setmetatable({
      content = { ... }
   } as ColorString, colorstring_mt)
end

---@desc
--- Create a `Colorstring` by surrounding a string with the given ANSI color and an ANSI reset
function colorstring.highlight(hl: {integer}, str: string): ColorString
   return colorstring.new(hl, str, {0})
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

---@desc
--- The ansi escape for an arbitrary RGB foreground color
function colorstring.rgb_fg(r: integer, g: integer, b: integer): {integer, integer, integer, integer, integer}
   return {38, 2, r, g, b}
end

---@desc
--- The ansi escape for an arbitrary RGB background color
function colorstring.rgb_bg(r: integer, g: integer, b: integer): {integer, integer, integer, integer, integer}
   return {48, 2, r, g, b}
end

local cs <const> = colorstring.colors

cs.none = { 0 }
cs.emphasis = { 1 }
cs.file = { ansi.color.dark.yellow }
cs.error_number = { ansi.color.dark.red }
cs.error = { ansi.color.dark.red }
cs.warn = { ansi.color.dark.yellow }
cs.teal = colorstring.rgb_fg(0, 0xAA, 0xB4)
cs.cyan = colorstring.rgb_fg(0, 0xFF, 0xFF)

cs.keyword = cs.teal
cs.number = { ansi.color.bright.red }
cs.string = { ansi.color.bright.yellow }
cs.op = { ansi.color.dark.magenta }

cs.debug = { ansi.color.bright.red, 1 }

return colorstring
