
local util = require("spec.util")
local graph = require("cyan.graph")

describe("dependency graph builder", function()
   it("should properly count node dependents", function()
      util.do_in(util.write_tmp_dir(finally, {
         ["a.tl"] = [[]],
         ["b.tl"] = [[require"a"]],
         ["c.tl"] = [[require"b"]],
         ["d.tl"] = [[require"c"]],
         ["e.tl"] = [[require"d"]],
         ["f.tl"] = [[require"e"]],
         ["g.tl"] = [[require"f"]],
         ["h.tl"] = [[require"g"]],
         ["i.tl"] = [[require"h"]],
         ["j.tl"] = [[require"i"]],
      }), function()
         local g = graph.scan_dir(".")
         local iter = g:nodes()

         local actual_order = {}
         local iter = g:nodes()
         for n in iter do
            table.insert(actual_order, n.input:to_real_path())
         end

         local expected_order = {
            "a.tl",
            "b.tl",
            "c.tl",
            "d.tl",
            "e.tl",
            "f.tl",
            "g.tl",
            "h.tl",
            "i.tl",
            "j.tl",
         }
         assert.is["nil"](iter(), "more files found than expected")
         assert.are.same(expected_order, actual_order)
      end)
   end)
end)
