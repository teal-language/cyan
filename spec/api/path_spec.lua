local util = require("spec.util")
local path = require("cyan.fs.path")
path.separator = '/'

describe("fs.path api", function()
   describe("new", function()
      it("should split a path on / no matter what path.separator is", function()
         path.separator = "teehee"
         local p = path.new("foo/bar/baz")
         assert.are.same(p, {"foo", "bar", "baz"})
      end)
      for _, sep in ipairs{'/', '\\'} do
         it("should split a path on os path separators [" .. sep .. "]", function()
            path.separator = sep
            local str = table.concat({"foo", "bar", "baz"}, sep)
            local p = path.new(str, true)
            assert.are.same({"foo", "bar", "baz"}, p)
            finally(function() path.separator = '/' end)
         end)
      end
      it("should be okay with having traversals (..)", function()
         assert.are.same({".."}, path.new(".."))
      end)
   end)
   describe("Path:is_absolute", function()
      it("should be able to check for absolute paths for unix", function()
         local p = path.new("/foo/bar")
         assert(p:is_absolute())
      end)
      it("should be able to check for absolute paths for windows", function()
         path.separator = '\\'
         local p = path.new("C:\\foo\\bar", true)
         local res = p:is_absolute()
         path.separator = '/'
         assert(res)
      end)
   end)
   describe("Path:ancestors", function()
      it("should produce the parents of the path", function()
         local p = path.new("a/b/c/d")
         local expected = {
            { "a" },
            { "a", "b" },
            { "a", "b", "c" },
         }
         local actual = {}
         for ancestor in p:ancestors() do
            table.insert(actual, ancestor)
         end
         assert.are.same(expected, actual)
      end)
   end)
   describe("Path:to_real_path", function()
      it("should concat the path with real path separators", function()
         do
            local p = path.new("foo/bar/baz")
            assert.are.equal(p:to_real_path(), "foo/bar/baz")
         end

         do
            path.separator = '\\'
            local p = path.new("foo\\bar\\baz")
            local res = p:to_real_path()
            path.separator = '/'
            assert.are.equal(res, "foo\\bar\\baz")
         end
      end)
   end)
   describe("Path:append", function()
      it("should mutate the given path by properly appending the path", function()
         local p = path.new("a/b/c")
         p:append("d/e")
         assert.are.same(p, {"a", "b", "c", "d", "e"})
         p:append(path.new("f"))
         assert.are.same(p, {"a", "b", "c", "d", "e", "f"})
      end)
   end)
   describe("Path:prepend", function()
      it("should mutate the given path by properly prepending the path", function()
         local p = path.new("a/b/c")
         p:prepend("d/e")
         assert.are.same(p, {"d", "e", "a", "b", "c"})
         p:prepend(path.new("f"))
         assert.are.same(p, {"f", "d", "e", "a", "b", "c"})
      end)
   end)
   describe("Path:remove_leading", function()
      it("should remove the leading path if it is present", function()
         do
            local p = path.new("foo/bar/baz")
            p:remove_leading("foo/bar")
            assert.are.same(p, {"baz"})
         end

         do
            local p = path.new("foo/bar/baz")
            p:remove_leading(path.new("foo/bar"))
            assert.are.same(p, {"baz"})
         end
      end)
   end)
   describe("Path:copy", function()
      it("should produce a copy of the given path", function()
         local p = path.new("a/b/c")
         local copy = p:copy()
         p[1] = "d"
         assert.are["not"].same(p, copy)
      end)
   end)
   describe("Path:match", function()
      local function assert_match(p, patt)
         assert(getmetatable(p).__name == "cyan.fs.path.Path", "p is not a Path")
         local res = p:match(patt)
         assert(res, p:tostring() .. " should have matched " .. patt)
      end

      local function assert_not_match(p, patt)
         assert(getmetatable(p).__name == "cyan.fs.path.Path", "p is not a Path")
         local res = p:match(patt)
         assert(not res, p:tostring() .. " should not have matched " .. patt)
      end

      it("should match literals with no globs", function()
         local p = path.new("foo/bar/baz")
         assert_not_match(p, "foo/bar")
         assert_match(p, "foo/bar/baz")
         assert_not_match(p, "foo/bar/bazz")
      end)
      it("should treat globs as matching non path separators", function()
         local p = path.new("foo/bar/baz")
         assert_match(p, "*/bar/baz")
         assert_match(p, "foo/*/baz")
         assert_match(p, "*/*/baz")
         assert_match(p, "f*/b*/b*z")
         assert_match(p, "*/*/*")
         assert_not_match(p, "*")
         assert_not_match(p, "foo/*")
         assert_not_match(p, "*/*")
         assert_not_match(p, "*/*/bazzz")
         assert_not_match(path.new("build/cyan/commands/blah.tl"), "build/cyan/*")
      end)
      it("should treat double globs as matching any number of directories", function()
         local p = path.new("foo/bar/baz/bat")
         assert_match(p, "**/bat")
         assert_match(p, "foo/bar/**/bat")
         assert_match(p, "foo/bar/baz/**/bat")
         assert_not_match(p, "foo/**/foo")
         assert_not_match(p, "**/baz/foo")
      end)
      it("should be able to mix globs and double globs", function()
         local p = path.new("foo/bar/baz/bat")
         assert_match(p, "foo/b*/**/bat")
         assert_match(p, "*/**/*/bat")
         assert_match(p, "*/**/bat")
         assert_match(p, "**/bat")
         assert_match(p, "**/*")
         assert_not_match(p, "**/bar/bat")
         assert_not_match(p, "foo/*/**/baz")
      end)
   end)

   describe("Path:relative_to", function()
      local function assert_eq_relative(expected, p, relative_to)
         assert.are.same(
            path.new(expected),
            path.new(p):relative_to(path.new(relative_to))
         )
      end

      it("should prepend .. as necessary", function()
         assert_eq_relative("..", "/foo/bar", "/foo/bar/baz")
         assert_eq_relative("../..", "/foo/bar", "/foo/bar/baz/bat")
      end)
      it("should append parts of the first directory as needed", function()
         assert_eq_relative("bar", "/foo/bar", "/foo")
         assert_eq_relative("bar/baz", "/foo/bar/baz", "/foo")
      end)
      it("should prepend .. and append parts of the first dir as needed", function()
         assert_eq_relative("../bar", "/foo/bar", "/foo/bat")
         assert_eq_relative("../bar/baz", "/foo/bar/baz", "/foo/bat")
         assert_eq_relative("../../bar/baz", "/bar/baz", "/foo/bat")
      end)
      it("should work with relative paths", function()
         assert_eq_relative("../bar", "foo/bar", "foo/bat")
         assert_eq_relative("../bar/baz", "foo/bar/baz", "foo/bat")
         assert_eq_relative("../../bar/baz", "bar/baz", "foo/bat")
      end)
   end)

   describe("Path:is_in", function()
      it("should work with relative paths", function()
         assert(path.new("foo/bar"):is_in("foo"))
      end)

      it("should work with absolute paths", function()
         assert(path.new("/foo/bar"):is_in("/foo"))
      end)

      it("should assume an empty path is the current dir", function()
         assert(path.new("foo"):is_in(""))
      end)
   end)
end)

