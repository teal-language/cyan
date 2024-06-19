local _tl_compat; if (tonumber((_VERSION or ''):match('[%d.]*$')) or 0) < 5.3 then local p, m = true, require('compat53.module'); if p then _tl_compat = m end end; local string = _tl_compat and _tl_compat.string or string; local table = _tl_compat and _tl_compat.table or table








local Color = {}





local function rgb(red, green, blue)
   return { red = red, green = green, blue = blue }
end



local Decoration = {}















local function copy(decoration)
   return {
      bold = decoration.bold,
      italic = decoration.italic,
      monospace = decoration.monospace,
      linked_uri = decoration.linked_uri,
      ansi_color = decoration.ansi_color,
      ansi_background_color = decoration.ansi_background_color,
      color = decoration.color and {
         red = decoration.color.red,
         green = decoration.color.green,
         blue = decoration.color.blue,
      },
      background_color = decoration.background_color and {
         red = decoration.background_color.red,
         green = decoration.background_color.green,
         blue = decoration.background_color.blue,
      },
   }
end

local Decorated = {}




local Renderer = {}

local insert = table.insert
local decorated_mt = {
   __name = "cyan.decoration.Decorated",
}

local function decorate(plain, decoration)
   return setmetatable({
      plain_content = plain,
      decoration = decoration,
   }, decorated_mt)
end

local function render_plain(buf, content, _decoration)
   insert(buf, content)
end

local function render_ansi(buf, content, decoration)
   local control_sequence_introducer = string.char(27) .. "["
   local operating_system_command = string.char(27) .. "]"
   local string_terminator = string.char(27) .. "\\"
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
      decoration.ansi_color < 8 and
      decoration.ansi_color + 30 or
      decoration.ansi_color + 90))


   elseif decoration.color then
      insert(
      buf,
      (control_sequence_introducer .. "38;2;%d;%d;%dm"):format(
      tostring(decoration.color.red or 0),
      tostring(decoration.color.green or 0),
      tostring(decoration.color.blue or 0)))


   end
   if decoration.ansi_background_color then
      insert(
      buf,
      (control_sequence_introducer .. "%dm"):format(
      decoration.ansi_background_color < 8 and
      decoration.ansi_background_color + 40 or
      decoration.ansi_background_color + 100))


   elseif decoration.background_color then
      insert(
      buf,
      (control_sequence_introducer .. "48;2;%d;%d;%dm"):format(
      tostring(decoration.color.red or 0),
      tostring(decoration.color.green or 0),
      tostring(decoration.color.blue or 0)))


   end
   if decoration.linked_uri then
      insert(
      buf,
      (operating_system_command .. "8;;%s" .. string_terminator):format(decoration.linked_uri))

   end
   insert(buf, content)
   if decoration.linked_uri then
      insert(buf, operating_system_command .. "8;;" .. string_terminator)
   end
   insert(buf, control_sequence_introducer .. "0m")
end

local scheme = {
   teal = { color = rgb(0, 0xAA, 0xB4) },
   cyan = { color = rgb(0, 0xFF, 0xFF) },
   yellow = {
      ansi_color = 3,
      color = rgb(230, 230, 0),
   },
   red = {
      ansi_color = 1,
      color = rgb(200, 50, 50),
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

scheme.keyword = scheme.teal
scheme.file = scheme.yellow
scheme.error = scheme.red
scheme.error_number = scheme.red
scheme.warn = scheme.yellow
scheme.number = scheme.red
scheme.string = { ansi_color = 11 }
scheme.operator = scheme.magenta

local function file_name(path)
   local decoration = copy(scheme.file)
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
