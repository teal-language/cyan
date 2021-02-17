local util = require("charon.util")
local tab = util.tab
local str = util.str

describe("util api", function()
   describe("tab", function()
      it("keys should generate every key in the given table", function()
         local expected = {
            a = true,
            b = true,
            c = true,
         }
         local actual = {}
         for k in tab.keys{a=1, b=2, c=3} do
            actual[k] = true
         end
         assert.are.same(expected, actual)
      end)
      it("sort should sort the table and return the same table", function()
         local t = {2, 3, 1}
         assert.are.equal(t, tab.sort(t))
      end)
      it("values should produce each value in the table", function()
         local expected = {
            a = true,
            b = true,
            [-2] = true,
         }
         local actual = {}
         for v in tab.values{'a', 'b', -2} do
            actual[v] = true
         end
         assert.are.same(expected, actual)
      end)
      it("ivalues should produce each indexed value in the table", function()
         local expected = {
            a = true,
            b = true,
         }
         local actual = {}
         for v in tab.ivalues{'a', 'b', a = -2} do
            actual[v] = true
         end
         assert.are.same(expected, actual)
      end)
      it("from should generate a list from an iterator", function()
         local i = 0
         local t = tab.from(function()
            i = i + 1
            if i <= 3 then
               return i
            end
         end)
         assert.are.same({1, 2, 3}, t)
      end)
      it("map should create a map from a given table and function", function()
         local t = tab.map({0, 1, 2}, function(val)
            return val + 1
         end)
         assert.are.same({1, 2, 3}, t)
      end)
      it("filter should produce two lists from a given table and predicate", function()
         local pass, fail = tab.filter({0, 1, 2, 3, 4}, function(val)
            return val % 2 == 0
         end)
         assert.are.same({0, 2, 4}, pass)
         assert.are.same({1, 3}, fail)
      end)
   end)
   describe("str", function()
      it("split should generate each component of the given string", function()
         local expected = { "hello,", "world", "ab", "cd", "ef" }
         for chunk in str.split("hello, world ab \n cd   ef", "%s+") do
            assert.are.equal(table.remove(expected, 1), chunk)
         end
      end)
      it("esc should escape magic chars in the provided string", function()
         assert.are.equal("a%*b%.c%-", str.esc("a*b.c-"))
      end)
   end)
end)
