local _tl_compat; if (tonumber((_VERSION or ''):match('[%d.]*$')) or 0) < 5.3 then local p, m = true, require('compat53.module'); if p then _tl_compat = m end end; local io = _tl_compat and _tl_compat.io or io; local string = _tl_compat and _tl_compat.string or string



local CSI = string.char(27) .. "["

local dark = {
   black = 30,
   red = 31,
   green = 32,
   yellow = 33,
   blue = 34,
   magenta = 35,
   cyan = 36,
   white = 37,
}

local bright = {
   black = 90,
   red = 91,
   green = 92,
   yellow = 93,
   blue = 94,
   magenta = 95,
   cyan = 96,
   white = 97,
}

local cursor = {}

function cursor.up(n)
   io.write(CSI, tostring(n or 1), "A")
end
function cursor.down(n)
   io.write(CSI, tostring(n or 1), "B")
end
function cursor.right(n)
   io.write(CSI, tostring(n or 1), "C")
end
function cursor.left(n)
   io.write(CSI, tostring(n or 1), "D")
end
function cursor.set_column(col)
   io.write(CSI, tostring(col or 0), "G")
end
function cursor.clear_line(n)
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
