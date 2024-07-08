local decoration = require("cyan.experimental.decoration")

describe("decoration api", function()
   describe("ansi rendering", function()
      it("should insert the correct escape sequences", function()
         local buf = {}
         decoration.render_ansi(buf, "hello", { ansi_color = 4 })
         decoration.render_ansi(buf, " ", {})
         decoration.render_ansi(buf, "world", { ansi_background_color = 7 })
         local result = table.concat(buf)
         local expected = "\x1b[34mhello\x1b[0m \x1b[47mworld\x1b[0m"

         assert.are.equal(expected, result)
      end)
   end)

   describe("plain rendering", function()
      it("should not insert anything other than the contents of the strings", function()
         local buf = {}
         decoration.render_plain(buf, "hello", { ansi_color = 4 })
         decoration.render_plain(buf, " ", {})
         decoration.render_plain(buf, "world", { ansi_background_color = 7 })
         local result = table.concat(buf)

         assert.are.equal("hello world", result)
      end)
   end)
end)
