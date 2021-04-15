
local specfile <const> = "cyan-dev-1.rockspec"
local template <const> = [[
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

local ansi <const> = require("cyan.ansi")
local cs <const> = require("cyan.colorstring")
local fs <const> = require("cyan.fs")
local log <const> = require("cyan.log")

local info = log.create_logger(
   io.stdout,
   cs.highlight({ansi.color.dark.cyan}, "Rockspec"),
   cs.highlight({ansi.color.dark.cyan}, "...")
)

local function gen_rockspec()
   local modules <const> = {}
   local install <const> = {}
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
   local function cmp(a: {string, string}, b: {string, string}): boolean
      return a[1] < b[1]
   end
   table.sort(modules, cmp)
   table.sort(install, cmp)
   local function convert(t: {{string, string}}, indent: integer): string
      local buf = {}
      for i, v in ipairs(t) do
         buf[i] = ("%s[%q] = %q,"):format(("   "):rep(indent), v[1], v[2])
      end
      return table.concat(buf, "\n")
   end

   local fh = io.open(specfile, "w")
   fh:write(template:format(convert(modules, 2), convert(install, 3)))
   fh:close()
   info("Wrote ", cs.highlight(cs.colors.file, specfile))
end

return {
   run_on = { "build:post" },
   exec = gen_rockspec,
}
