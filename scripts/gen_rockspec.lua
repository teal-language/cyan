
local specfile = "cyan-dev-1.rockspec"
local template = [[
rockspec_format = "3.0"
package = "cyan"
version = "dev-1"
source = {
   url = "git+https://github.com/teal-language/cyan.git",
}
description = {
   summary = "A build system for the Teal language",
   detailed = "A build system for the Teal language",
   homepage = "https://github.com/teal-language/cyan",
   license = "MIT",
   issues_url = "https://github.com/teal-language/cyan/issues",
}
dependencies = {
   "argparse",
   "luafilesystem",
   "tl",
}
build = {
   type = "builtin",
   modules = {
%s
   },
   install = {
      lua = {
%s
      },
      bin = {
         "bin/cyan",
      }
   }
}
]]

local fs = require("cyan.fs")
local util = require("cyan.util")
local map = util.tab.map

local function gen_rockspec()
   local modules = {}
   local install = {}
   for f in fs.scan_dir("src", {"**/*"}) do
      local mod = f:tostring():sub(1, -4):gsub("/", ".")
      local p = f:tostring()
      table.insert(install, {
         mod,
         "src/" .. p,
      })
      table.insert(modules, {
         mod,
         "build/" .. p:gsub("%.tl$", ".lua"),
      })
   end
   local function cmp(a, b)
      return a[1] < b[1]
   end
   table.sort(modules, cmp)
   table.sort(install, cmp)
   local function convert(t, indent)
      local buf = {}
      for i, v in ipairs(t) do
         buf[i] = ("%s[%q] = %q,"):format(("   "):rep(indent), v[1], v[2])
      end
      return table.concat(buf, "\n")
   end

   local fh = io.open(specfile, "w")
   fh:write(template:format(convert(modules, 2), convert(install, 3)))
   fh:close()
end

return {
   writes_to = { specfile },
   run_on = { "build:post" },
   exec = gen_rockspec,
}
