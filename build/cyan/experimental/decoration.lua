local _tl_compat; if (tonumber((_VERSION or ''):match('[%d.]*$')) or 0) < 5.3 then local p, m = true, require('compat53.module'); if p then _tl_compat = m end end; local string = _tl_compat and _tl_compat.string or string; local table = _tl_compat and _tl_compat.table or table






local ivalues = require("cyan.util").tab.ivalues
local insert = table.insert



local Color = {}







local Decoration = {}

















local Decorated = {}




local Renderer = {}

local decoration = {
   Color = Color,
   Decorated = Decorated,
   Decoration = Decoration,
   Renderer = Renderer,

   scheme = {},
}



function decoration.rgb(red, green, blue)
   return { red = red, green = green, blue = blue }
end
local rgb = decoration.rgb;



function decoration.color_copy(c)
   return { red = c.red, green = c.green, blue = c.blue }
end



function decoration.copy(to_be_copied, delta)
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
   insert(buf, ansi_control_sequence_introducer .. "0m")
end

decoration.scheme.teal = { color = rgb(0, 0xAA, 0xB4) }
decoration.scheme.cyan = {
   ansi_color = 6,
   color = rgb(0, 0xCC, 0xCC),
}
decoration.scheme.bright_cyan = {
   ansi_color = 14,
   color = rgb(0, 0xFF, 0xFF),
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



function decoration.file_name(path)
   local d = copy(decoration.scheme.file)
   d.linked_uri = ("file://%s"):format(path)
   return decoration.decorate(path, d)
end

return decoration
