local _tl_compat; if (tonumber((_VERSION or ''):match('[%d.]*$')) or 0) < 5.3 then local p, m = true, require('compat53.module'); if p then _tl_compat = m end end; local assert = _tl_compat and _tl_compat.assert or assert; local string = _tl_compat and _tl_compat.string or string; local table = _tl_compat and _tl_compat.table or table



local util = require("cyan.util")
local ivalues, map = util.tab.ivalues, util.tab.map
local insert = table.insert



local Color = {}







local Decoration = {}

















local Decorated = {}








local Renderer = {}



local SchemeEntry = {}



































local decoration = {
   Color = Color,
   Decorated = Decorated,
   Decoration = Decoration,
   Renderer = Renderer,
   SchemeEntry = SchemeEntry,

   scheme = nil,
}



function decoration.rgb(red, green, blue)
   return { red = red, green = green, blue = blue }
end
local rgb = decoration.rgb



function decoration.color_copy(c)
   return { red = c.red, green = c.green, blue = c.blue }
end



function decoration.copy(to_be_copied, delta)
   to_be_copied = to_be_copied or {}
   delta = delta or {}
   local result = {}
   for k in ivalues({
         "bold",
         "italic",
         "monospace",
         "linked_uri",
         "ansi_color",
         "ansi_background_color",
      }) do
      (result)[k] = (delta)[k] == nil and (to_be_copied)[k] or (delta)[k]
   end

   result.color = (delta.color and decoration.color_copy(delta.color)) or
   (to_be_copied.color and decoration.color_copy(to_be_copied.color))
   result.background_color = (delta.background_color and decoration.color_copy(delta.background_color)) or
   (to_be_copied.background_color and decoration.color_copy(to_be_copied.background_color))

   return result
end
local copy = decoration.copy

local decorated_mt = {
   __name = "cyan.decoration.Decorated",
   __index = Decorated,
}



function decoration.decorate(plain, decor)
   return setmetatable({
      plain_content = plain,
      decoration = decor,
   }, decorated_mt)
end



function Decorated:copy(delta)
   return decoration.decorate(
   self.plain_content,
   decoration.copy(self.decoration, delta))

end



function decoration.render_plain(buf, content, _decoration)
   insert(buf, content)
end

local ansi_escape = string.char(27)
local ansi_control_sequence_introducer = ansi_escape .. "["
local ansi_operating_system_command = ansi_escape .. "]"
local ansi_string_terminator = ansi_escape .. "\\"



function decoration.render_ansi(buf, content, decor)
   assert(content)
   decor = decor or {}

   local starting_len = #buf
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
      decor.ansi_color < 8 and
      decor.ansi_color + 30 or
      decor.ansi_color - 8 + 90))


   elseif decor.color then
      insert(
      buf,
      (ansi_control_sequence_introducer .. "38;2;%d;%d;%dm"):format(
      decor.color.red or 0,
      decor.color.green or 0,
      decor.color.blue or 0))


   end
   if decor.ansi_background_color then
      insert(
      buf,
      (ansi_control_sequence_introducer .. "%dm"):format(
      decor.ansi_background_color < 8 and
      decor.ansi_background_color + 40 or
      decor.ansi_background_color - 8 + 100))


   elseif decor.background_color then
      insert(
      buf,
      (ansi_control_sequence_introducer .. "48;2;%d;%d;%dm"):format(
      decor.color.red or 0,
      decor.color.green or 0,
      decor.color.blue or 0))


   end
   if decor.linked_uri then
      insert(
      buf,
      (ansi_operating_system_command .. "8;;%s" .. ansi_string_terminator):format(decor.linked_uri))

   end
   insert(buf, content)
   if decor.linked_uri then
      insert(buf, ansi_operating_system_command .. "8;;" .. ansi_string_terminator)
   end
   if starting_len + 1 ~= #buf then
      insert(buf, ansi_control_sequence_introducer .. "0m")
   end
end



function decoration.render_to_string(render, plain_content, decor)
   local buf = {}
   render(buf, plain_content, decor)
   return table.concat(buf)
end

local scheme = {
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
      color = rgb(0, 180, 200),
   },
   white = {
      ansi_color = 7,
      color = rgb(255, 255, 255),
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
      color = rgb(0, 0xff, 0xff),
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

local function resolve_scheme_entry(value)
   if type(value) == "string" then
      return copy(resolve_scheme_entry(scheme[value]), nil)
   end
   return value
end

decoration.scheme = map(scheme, resolve_scheme_entry)



function decoration.file_name(path)
   local d = copy(decoration.scheme.file, nil)
   d.linked_uri = ("file://%s"):format(path)
   return decoration.decorate(path, d)
end

return decoration
