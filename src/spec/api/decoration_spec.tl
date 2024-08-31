local type _ = require("busted")
local luassert <const> = require("luassert")
local decoration <const> = require("cyan.decoration")

describe("decoration api", function()
   describe("ansi rendering", function()
      it("should insert the correct escape sequences", function()
         local buf = {}
         decoration.render_ansi(buf, "hello", { ansi_color = 4 })
         decoration.render_ansi(buf, " ", {})
         decoration.render_ansi(buf, "world", { ansi_background_color = 7 })
         local result = table.concat(buf)
         local expected = "\27[34mhello\27[0m \27[47mworld\27[0m"

         luassert.are_equal(expected, result)
      end)
   end)

   describe("plain rendering", function()
      it("should not insert anything other than the contents of the strings", function()
         local buf = {}
         decoration.render_plain(buf, "hello", { ansi_color = 4 })
         decoration.render_plain(buf, " ", {})
         decoration.render_plain(buf, "world", { ansi_background_color = 7 })
         local result = table.concat(buf)

         luassert.are_equal("hello world", result)
      end)
   end)
end)
