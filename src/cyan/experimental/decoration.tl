---@brief
--- A replacement for colorstring that doesn't specifically rely on ANSI
--- terminal escapes

-- local util <const> = require("cyan.util")
-- local tab <const> = util.tab

---@desc
--- A color described by rgb values in [0, 255]
local record Color
   red: integer
   green: integer
   blue: integer
end

local function rgb(red: integer, green: integer, blue: integer): Color
   return { red = red, green = green, blue = blue }
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

local function color_copy(c: Color): Color
   return { red = c.red, green = c.green, blue = c.blue }
end

local ivalues <const> = require("cyan.util").tab.ivalues

local function copy(decoration: Decoration, delta: Decoration): Decoration
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
      (result as {string:any})[k] = (delta as {string:any})[k] == nil and (decoration as {string:any})[k] or (delta as {string:any})[k]
   end

   result.color = (delta.color and color_copy(delta.color))
      or (decoration.color and color_copy(decoration.color))
   result.background_color = (delta.background_color and color_copy(delta.background_color))
      or (decoration.background_color and color_copy(decoration.background_color))

   return result
end

local record Decorated
   plain_content: string
   decoration: Decoration
end

local type Renderer = function({string}, string, Decoration)

local insert <const> = table.insert
local decorated_mt <const>: metatable<Decorated> = {
   __name = "cyan.decoration.Decorated",
}

local function decorate(plain: string, decoration: Decoration): Decorated
   return setmetatable({
      plain_content = plain,
      decoration = decoration,
   }, decorated_mt)
end

local function render_plain(buf: {string}, content: string, _decoration: Decoration)
   insert(buf, content)
end

local function render_ansi(buf: {string}, content: string, decoration: Decoration)
   local control_sequence_introducer <const> = string.char(27) .. "["
   local operating_system_command <const> = string.char(27) .. "]"
   local string_terminator <const> = string.char(27) .. "\\"
   if decoration.bold then
      insert(buf, control_sequence_introducer .. "1m")
   end
   if decoration.italic then
      insert(buf, control_sequence_introducer .. "3m")
   end
   if decoration.ansi_color then
      insert(
         buf,
         (control_sequence_introducer .. "%dm"):format(
            decoration.ansi_color < 8
               and decoration.ansi_color + 30
               or decoration.ansi_color - 8 + 90
         )
      )
   elseif decoration.color then
      insert(
         buf,
         (control_sequence_introducer .. "38;2;%d;%d;%dm"):format(
            tostring(decoration.color.red or 0),
            tostring(decoration.color.green or 0),
            tostring(decoration.color.blue or 0)
         )
      )
   end
   if decoration.ansi_background_color then
      insert(
         buf,
         (control_sequence_introducer .. "%dm"):format(
            decoration.ansi_background_color < 8
               and decoration.ansi_background_color + 40
               or decoration.ansi_background_color - 8 + 100
         )
      )
   elseif decoration.background_color then
      insert(
         buf,
         (control_sequence_introducer .. "48;2;%d;%d;%dm"):format(
            tostring(decoration.color.red or 0),
            tostring(decoration.color.green or 0),
            tostring(decoration.color.blue or 0)
         )
      )
   end
   if decoration.linked_uri then
      insert(
         buf,
         (operating_system_command .. "8;;%s" .. string_terminator):format(decoration.linked_uri)
      )
   end
   insert(buf, content)
   if decoration.linked_uri then
      insert(buf, operating_system_command .. "8;;" .. string_terminator)
   end
   insert(buf, control_sequence_introducer .. "0m")
end

local scheme: {string:Decoration} = {
   teal = { color = rgb(0, 0xAA, 0xB4) },
   cyan = {
      ansi_color = 6,
      color = rgb(0, 0xCC, 0xCC)
   },
   bright_cyan = {
      ansi_color = 14,
      color = rgb(0, 0xFF, 0xFF)
   },
   yellow = {
      ansi_color = 3,
      color = rgb(230, 230, 0),
   },
   red = {
      ansi_color = 1,
      color = rgb(200, 50, 50),
   },
   green = {
      ansi_color = 2,
      color = rgb(10, 180, 10),
   },
   bright_green = {
      ansi_color = 10,
      color = rgb(85, 255, 85),
   },
   bright_red = {
      ansi_color = 9,
      color = rgb(230, 60, 60),
   },
   bright_yellow = {
      ansi_color = 11,
      color = rgb(230, 230, 0),
   },
   magenta = {
      ansi_color = 5,
      color = rgb(190, 60, 60),
   },
}

scheme.keyword = copy(scheme.teal)
scheme.file = copy(scheme.yellow)
scheme.error = copy(scheme.red)
scheme.error_number = copy(scheme.red)
scheme.warn = copy(scheme.yellow)
scheme.number = copy(scheme.red)
scheme.string = copy(scheme.bright_yellow)
scheme.operator = copy(scheme.magenta)
scheme.emphasis = { bold = true }

scheme.affirmative = copy(scheme.bright_green)
scheme.negative = copy(scheme.red)

local function file_name(path: string): Decorated
   local decoration <const> = copy(scheme.file)
   decoration.linked_uri = ("file://%s"):format(path)
   return decorate(path, decoration)
end

return {
   Color = Color,
   Decorated = Decorated,
   Decoration = Decoration,
   Renderer = Renderer,

   decorate = decorate,
   file_name = file_name,
   copy = copy,

   render_plain = render_plain,
   render_ansi = render_ansi,

   scheme = scheme,
}
