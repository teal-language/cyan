---@brief
--- A replacement for colorstring that doesn't specifically rely on ANSI
--- terminal escapes

local util <const> = require("cyan.util")
local ivalues <const>, map <const> = util.tab.ivalues, util.tab.map
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

---@desc
--- Predefined decorations used for logging, syntax highlighting errors, etc.
local enum SchemeEntry
   "black"
   "red"
   "green"
   "yellow"
   "blue"
   "magenta"
   "cyan"
   "white"

   "gray"
   "bright_red"
   "bright_green"
   "bright_yellow"
   "bright_blue"
   "bright_magenta"
   "bright_cyan"
   "bright_white"

   "teal"

   "emphasis"

   "error"
   "error_number"
   "file"
   "keyword"
   "number"
   "operator"
   "string"
   "warn"

   "affirmative"
   "negative"
end

local decoration <const> = {
   Color = Color,
   Decorated = Decorated,
   Decoration = Decoration,
   Renderer = Renderer,
   SchemeEntry = SchemeEntry,

   scheme: {SchemeEntry:Decoration} = nil,
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
   to_be_copied = to_be_copied or {}
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

---@desc
--- A convenience function to render to a buffer, then concatenate that buffer
function decoration.render_to_string(render: Renderer, plain_content: string, decor?: Decoration): string
   local buf <const> = {}
   render(buf, plain_content, decor)
   return table.concat(buf)
end

local scheme <total>: {SchemeEntry:Decoration | SchemeEntry} = {
   black = {
      ansi_color = 0,
      color = rgb(0, 0, 0),
   },
   red = {
      ansi_color = 1,
      color = rgb(200, 50, 50),
   },
   green = {
      ansi_color = 2,
      color = rgb(10, 180, 10),
   },
   yellow = {
      ansi_color = 3,
      color = rgb(230, 230, 0),
   },
   blue = {
      ansi_color = 4,
      color = rgb(30, 100, 220),
   },
   magenta = {
      ansi_color = 5,
      color = rgb(100, 30, 150),
   },
   cyan = {
      ansi_color = 6,
      color = rgb(0, 180, 200)
   },
   white = {
      ansi_color = 7,
      color = rgb(255, 255, 255)
   },

   gray = {
      ansi_color = 8,
      color = rgb(128, 128, 128),
   },
   bright_red = {
      ansi_color = 9,
      color = rgb(230, 60, 60),
   },
   bright_green = {
      ansi_color = 10,
      color = rgb(85, 255, 85),
   },
   bright_yellow = {
      ansi_color = 11,
      color = rgb(230, 230, 0),
   },
   bright_blue = {
      ansi_color = 12,
      color = rgb(60, 150, 0xff),
   },
   bright_magenta = {
      ansi_color = 13,
      color = rgb(0xff, 100, 0xff),
   },
   bright_cyan = {
      ansi_color = 14,
      color = rgb(0, 0xff, 0xff)
   },
   bright_white = {
      ansi_color = 15,
      color = rgb(0xff, 0xff, 0xff),
   },

   teal = { color = rgb(0, 0xaa, 0xb4) },

   keyword = "teal",
   file = "yellow",
   error = "red",
   error_number = "red",
   warn = "yellow",
   number = "red",
   string = "bright_yellow",
   operator = "magenta",
   emphasis = { bold = true },

   affirmative = "bright_green",
   negative = "red",
}

local function resolve_scheme_entry(value: Decoration | SchemeEntry): Decoration
   if value is SchemeEntry then
      return copy(resolve_scheme_entry(scheme[value]), nil)
   end
   return value
end

decoration.scheme = map(scheme, resolve_scheme_entry)

---@desc
--- Decorate using the default decoration for file names and a uri for the path
function decoration.file_name(path: string): Decorated
   local d <const> = copy(decoration.scheme.file, nil)
   d.linked_uri = ("file://%s"):format(path)
   return decoration.decorate(path, d)
end

return decoration
