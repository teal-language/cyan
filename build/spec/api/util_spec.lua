local _tl_compat; if (tonumber((_VERSION or ''):match('[%d.]*$')) or 0) < 5.3 then local p, m = true, require('compat53.module'); if p then _tl_compat = m end end; local string = _tl_compat and _tl_compat.string or string; local table = _tl_compat and _tl_compat.table or table

local luassert = require("luassert")
local util = require("cyan.util")
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
         for k in tab.keys({ a = 1, b = 2, c = 3 }) do
            actual[k] = true
         end
         luassert.are_same(expected, actual)
      end)
      it("sort_in_place should sort the table and return the same table", function()
         local t = { 2, 3, 1 }
         luassert.are_equal(t, tab.sort_in_place(t))
         luassert.are_same(t, { 1, 2, 3 })
      end)
      it("values should produce each value in the table", function()
         local expected = {
            a = true,
            b = true,
            [-2] = true,
         }
         local actual = {}
         for v in tab.values({ 'a', 'b', -2 }) do
            actual[v] = true
         end
         luassert.are_same(expected, actual)
      end)
      it("ivalues should produce each indexed value in the table", function()
         local expected = {
            a = true,
            b = true,
         }
         local actual = {}
         for v in tab.ivalues({ 'a', 'b', a = -2 }) do
            actual[v] = true
         end
         luassert.are_same(expected, actual)
      end)
      it("from should generate a list from an iterator", function()
         local i = 0
         local t = tab.from(function()
            i = i + 1
            if i <= 3 then
               return i
            end
         end)
         luassert.are_same({ 1, 2, 3 }, t)
      end)
      it("map should create a map from a given table and function", function()
         local t = tab.map({ 0, 1, 2 }, function(val)
            return val + 1
         end)
         luassert.are_same({ 1, 2, 3 }, t)
      end)
      it("filter should produce two lists from a given table and predicate", function()
         local pass, fail = tab.filter({ 0, 1, 2, 3, 4 }, function(val)
            return val % 2 == 0
         end)
         luassert.are_same({ 0, 2, 4 }, pass)
         luassert.are_same({ 1, 3 }, fail)
      end)
      it("#intersperse should create a new list with a value interspersed between each element", function()
         local interspersed = tab.intersperse({ 'a', 'b', 'c' }, '\n')
         luassert.are_same({ 'a', '\n', 'b', '\n', 'c' }, interspersed)
      end)
   end)
   describe("str", function()
      it("split should generate each component of the given string", function()
         local expected = { "hello,", "world", "ab", "cd", "ef" }
         for chunk in str.split("hello, world ab \n cd   ef", "%s+") do
            luassert.are_equal(table.remove(expected, 1), chunk)
         end
      end)
      it("esc should escape magic chars in the provided string", function()
         luassert.are_equal("a%*b%.c%-", (str.esc("a*b.c-")))
      end)
      it("pad_left should return a string with length >= the provided argument", function()
         for pad_length = 1, 20 do
            for in_length = 1, 20 do
               luassert.is_true(#str.pad_left(("a"):rep(in_length), pad_length) >= pad_length)
            end
         end
      end)
   end)
end)
