local type _ = require("busted")
local luassert <const> = require("luassert")

local temporary_files <const> = require("testing.temporary-files")
local graph <const> = require("cyan.graph")

describe("dependency graph builder", function()
   it("should properly count node dependents", function()
      temporary_files.do_in(temporary_files.write_directory(finally, {
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
         local g <const> = graph.scan_dir(".")

         local actual_order <const> = {}
         local iter <const> = g:nodes()
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
         luassert.is_nil(iter(), "more files found than expected")
         luassert.are_same(expected_order, actual_order)
      end)
   end)
end)
