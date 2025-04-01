local _tl_compat; if (tonumber((_VERSION or ''):match('[%d.]*$')) or 0) < 5.3 then local p, m = true, require('compat53.module'); if p then _tl_compat = m end end; local table = _tl_compat and _tl_compat.table or table
local luassert = require("luassert")
local lexical_path = require("lexical-path")

local temporary_files = require("testing.temporary-files")
local graph = require("cyan.graph")

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
         local g = graph.scan_directory((lexical_path.from_os(".")))

         local actual_order = {}
         local iter = g:nodes()
         for n in iter do
            table.insert(actual_order, n.input:to_string())
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
