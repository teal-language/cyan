---@brief
--- A replacement for colorstring that doesn't specifically rely on ANSI
--- terminal escapes

-- local util <const> = require("cyan.util")
-- local tab <const> = util.tab

local ivalues <const> = require("cyan.util").tab.ivalues
local insert <const> = table.insert

---@desc
--- A color described by rgb values in [0, 255]
local record Color
   red: integer
   green: integer
   blue: integer
end

---@desc
--- Various visual properties that could apply to some text
local record Decoration
   bold: boolean
   italic: boolean
   monospace: boolean

   linked_uri: string

   -- rgb colors
   color: Color
   background_color: Color

   -- ansi colors, 0-15
   ansi_color: integer
   ansi_background_color: integer
end

---@desc
--- A string and a decoration
local record Decorated
   plain_content: string
   decoration: Decoration
end

---@desc
--- Render the decorated contents into `out_buffer`
---
--- `Renderer`s are assumed to be stateless, and results may be cached and rearranged in the actual output
local type Renderer = function(out_buffer: {string}, plain_content: string, Decoration)

local decoration <const> = {
   Color = Color,
   Decorated = Decorated,
   Decoration = Decoration,
   Renderer = Renderer,

   scheme: {string:Decoration} = {},
}

---@desc
--- Positional constructor for `Color`
function decoration.rgb(red: integer, green: integer, blue: integer): Color
   return { red = red, green = green, blue = blue }
end
local rgb <const> = decoration.rgb

---@desc
--- Deep copy a `Color`
function decoration.color_copy(c: Color): Color
   return { red = c.red, green = c.green, blue = c.blue }
end

---@desc
--- Deep copy a `Decoration`, but copy values from `delta` when present
function decoration.copy(to_be_copied: Decoration, delta: Decoration): Decoration
   delta = delta or {}
   local result <const>: Decoration = {}
   for k in ivalues {
      "bold",
      "italic",
      "monospace",
      "linked_uri",
      "ansi_color",
      "ansi_background_color",
   } do
      (result as {string:any})[k] = (delta as {string:any})[k] == nil and (to_be_copied as {string:any})[k] or (delta as {string:any})[k]
   end

   result.color = (delta.color and decoration.color_copy(delta.color))
      or (to_be_copied.color and decoration.color_copy(to_be_copied.color))
   result.background_color = (delta.background_color and decoration.color_copy(delta.background_color))
      or (to_be_copied.background_color and decoration.color_copy(to_be_copied.background_color))

   return result
end
local copy <const> = decoration.copy

local decorated_mt <const>: metatable<Decorated> = {
   __name = "cyan.decoration.Decorated",
   __index = Decorated,
}

---@desc
--- Create a decorated string
function decoration.decorate(plain: string, decor: Decoration): Decorated
   return setmetatable({
      plain_content = plain,
      decoration = decor,
   }, decorated_mt)
end

---@desc
--- Deeply copy the decoration of a decorated string
function Decorated:copy(delta: Decoration): Decorated
   return decoration.decorate(
      self.plain_content,
      decoration.copy(self.decoration, delta)
   )
end

---@desc
--- Render text by discarding all decorations
function decoration.render_plain(buf: {string}, content: string, _decoration: Decoration)
   insert(buf, content)
end

local ansi_escape <const> = string.char(27)
local ansi_control_sequence_introducer <const> = ansi_escape .. "["
local ansi_operating_system_command <const> = ansi_escape .. "]"
local ansi_string_terminator <const> = ansi_escape .. "\\"

---@desc
--- Render decorations as ANSI escape sequences
function decoration.render_ansi(buf: {string}, content: string, decor: Decoration)
   assert(content)
   decor = decor or {}

   local starting_len <const> = #buf
   if decor.bold then
      insert(buf, ansi_control_sequence_introducer .. "1m")
   end
   if decor.italic then
      insert(buf, ansi_control_sequence_introducer .. "3m")
   end
   if decor.ansi_color then
      insert(
         buf,
         (ansi_control_sequence_introducer .. "%dm"):format(
            decor.ansi_color < 8
               and decor.ansi_color + 30
               or decor.ansi_color - 8 + 90
         )
      )
   elseif decor.color then
      insert(
         buf,
         (ansi_control_sequence_introducer .. "38;2;%d;%d;%dm"):format(
            decor.color.red or 0,
            decor.color.green or 0,
            decor.color.blue or 0
         )
      )
   end
   if decor.ansi_background_color then
      insert(
         buf,
         (ansi_control_sequence_introducer .. "%dm"):format(
            decor.ansi_background_color < 8
               and decor.ansi_background_color + 40
               or decor.ansi_background_color - 8 + 100
         )
      )
   elseif decor.background_color then
      insert(
         buf,
         (ansi_control_sequence_introducer .. "48;2;%d;%d;%dm"):format(
            decor.color.red or 0,
            decor.color.green or 0,
            decor.color.blue or 0
         )
      )
   end
   if decor.linked_uri then
      insert(
         buf,
         (ansi_operating_system_command .. "8;;%s" .. ansi_string_terminator):format(decor.linked_uri)
      )
   end
   insert(buf, content)
   if decor.linked_uri then
      insert(buf, ansi_operating_system_command .. "8;;" .. ansi_string_terminator)
   end
   if starting_len + 1 ~= #buf then
      insert(buf, ansi_control_sequence_introducer .. "0m")
   end
end

decoration.scheme.teal = { color = rgb(0, 0xAA, 0xB4) }
decoration.scheme.cyan = {
   ansi_color = 6,
   color = rgb(0, 0xCC, 0xCC)
}
decoration.scheme.bright_cyan = {
   ansi_color = 14,
   color = rgb(0, 0xFF, 0xFF)
}
decoration.scheme.yellow = {
   ansi_color = 3,
   color = rgb(230, 230, 0),
}
decoration.scheme.red = {
   ansi_color = 1,
   color = rgb(200, 50, 50),
}
decoration.scheme.green = {
   ansi_color = 2,
   color = rgb(10, 180, 10),
}
decoration.scheme.bright_green = {
   ansi_color = 10,
   color = rgb(85, 255, 85),
}
decoration.scheme.bright_red = {
   ansi_color = 9,
   color = rgb(230, 60, 60),
}
decoration.scheme.bright_yellow = {
   ansi_color = 11,
   color = rgb(230, 230, 0),
}
decoration.scheme.magenta = {
   ansi_color = 5,
   color = rgb(190, 60, 60),
}

decoration.scheme.keyword = copy(decoration.scheme.teal)
decoration.scheme.file = copy(decoration.scheme.yellow)
decoration.scheme.error = copy(decoration.scheme.red)
decoration.scheme.error_number = copy(decoration.scheme.red)
decoration.scheme.warn = copy(decoration.scheme.yellow)
decoration.scheme.number = copy(decoration.scheme.red)
decoration.scheme.string = copy(decoration.scheme.bright_yellow)
decoration.scheme.operator = copy(decoration.scheme.magenta)
decoration.scheme.emphasis = { bold = true }

decoration.scheme.affirmative = copy(decoration.scheme.bright_green)
decoration.scheme.negative = copy(decoration.scheme.red)

---@desc
--- Decorate using the default decoration for file names and a uri for the path
function decoration.file_name(path: string): Decorated
   local d <const> = copy(decoration.scheme.file)
   d.linked_uri = ("file://%s"):format(path)
   return decoration.decorate(path, d)
end

return decoration
