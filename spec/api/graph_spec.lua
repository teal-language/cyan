
local util = require("spec.util")
local graph = require("cyan.graph")

describe("dependency graph builder", function()
   it("should properly count node dependents", function()
      util.do_in(util.write_tmp_dir(finally, {
         ["foo.tl"] = [[]],
         ["bar.tl"] = [[require"foo"]],
         ["baz.tl"] = [[require"bar"]],
      }), function()
         local g = graph.scan_dir(".")
         local iter = g:nodes()
         local expected_order = {"foo.tl", "bar.tl", "baz.tl"}
         local actual_order = {
            iter().input:to_real_path(),
            iter().input:to_real_path(),
            iter().input:to_real_path(),
         }
         assert.is["nil"](iter(), "more than three files found")
         assert.are.same(expected_order, actual_order)
      end)
   end)
end)
