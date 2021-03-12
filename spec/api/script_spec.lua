local script = require("cyan.script")

describe("script", function()
   describe("is_valid", function()
      it("should return nil when `exec` is nil", function()
         assert.is_nil((script.is_valid{}))
      end)
      it("should return nil when `exec` is not a function", function()
         assert.is_nil((script.is_valid{ exec = "hi" }))
      end)

      it("should return nil when `reads_from` is not {string}", function()
         assert.is_nil((script.is_valid{
            exec = function() end,
            reads_from = "thing"
         }))
      end)

      it("should return nil when `writes_to` is not {string}", function()
         assert.is_nil((script.is_valid{
            exec = function() end,
            writes_to = "thing"
         }))
      end)

      it("should return nil when `run_on` is not {string}", function()
         assert.is_nil((script.is_valid{
            exec = function() end,
            run_on = ""
         }))
      end)
   end)
end)
