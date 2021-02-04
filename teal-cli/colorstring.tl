
-- Some wrappers/conveniences around working with ansi escape codes
-- For example getting the length of a string that contains escape codes shouldnt include them

local ansi <const> = require("teal-cli.ansi")
local map <const> = require("teal-cli.util").tab.map

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

local function append(base: ColorString, other: string | number | ColorString): ColorString
   if other is ColorString then
      for _, chunk in ipairs(other.content) do
         table.insert(base.content, chunk)
      end
   elseif other is number then
      table.insert(base.content, {other})
   else
      table.insert(base.content, other)
   end
end

function ColorString:append(...: string | number | ColorString): ColorString
   for i = 1, select("#", ...) do
      append(self, (select(i, ...)))
   end
   return self
end

function ColorString:append_ansi_esc(c: number, ...: number): ColorString
   table.insert(self.content, {c, ...})
   return self
end

function ColorString:tostring(): string
   return table.concat(map(self.content, function(chunk: {number} | string): string
      if chunk is string then
         return chunk
      else
         return ansi.CSI .. table.concat(
            map(chunk, tostring as function(number): string),
         ";") .. "m"
      end
   end))
end

local colorstring_mt <const>: metatable<ColorString> = {}
colorstring_mt.__index = ColorString
colorstring_mt.__concat = function(a: string | ColorString, b: string | ColorString): ColorString
   local new <const> = setmetatable({ content = {} } as ColorString, colorstring_mt)
   return new:append(a):append(b)
end
colorstring_mt.__tostring = ColorString.tostring
colorstring_mt.__len = ColorString.len

local colorstring <const> = {
   colors = {
      file = 33,
      number = 31,
   },
}

local setmt <const> = setmetatable as function<T>(T, metatable<T>): T
function colorstring.new(...: string | number | ColorString): ColorString
   local new <const> = setmt({
      content = {},
   } as ColorString, colorstring_mt)
   return new:append(...)
end

return colorstring

