
---@brief
--- A small utility library for grabbing the ANSI escapes for colors and such

local CSI <const> = string.char(27) .. "["

local dark: {string:integer} = {
   black = 30,
   red = 31,
   green = 32,
   yellow = 33,
   blue = 34,
   magenta = 35,
   cyan = 36,
   white = 37,
}

local bright: {string:integer} = {
   black = 90,
   red = 91,
   green = 92,
   yellow = 93,
   blue = 94,
   magenta = 95,
   cyan = 96,
   white = 97,
}

local cursor <const> = {}

function cursor.up(n: integer)
   io.write(CSI, tostring(n or 1), "A")
end
function cursor.down(n: integer)
   io.write(CSI, tostring(n or 1), "B")
end
function cursor.right(n: integer)
   io.write(CSI, tostring(n or 1), "C")
end
function cursor.left(n: integer)
   io.write(CSI, tostring(n or 1), "D")
end
function cursor.set_column(col: integer)
   io.write(CSI, tostring(col or 0), "G")
end
function cursor.clear_line(n: integer)
   io.write(CSI, tostring(n or 0), "K")
end


return {
   color = {
      dark = dark,
      bright = bright,
   },
   cursor = cursor,
   CSI = CSI,
}

