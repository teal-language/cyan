
local specfile <const> = "cyan-dev-1.rockspec"
local template <const> = [[
rockspec_format = "3.0"
package = "cyan"
version = "dev-1"
source = {
   url = "git://github.com/teal-language/cyan",
}
description = {
   summary = "A build system for the Teal language",
   detailed = "A build system for the Teal language along with an api for external tooling to work with Teal",
   homepage = "https://github.com/teal-language/cyan",
   license = "MIT",
   issues_url = "https://github.com/teal-language/cyan/issues",
}
dependencies = {
   "argparse",
   "luafilesystem",
   "tl ~> 0.15",
   "luasystem >= 0.3.0",
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

local decoration <const> = require("cyan.decoration")
local fs <const> = require("cyan.fs")
local log <const> = require("cyan.log")

local info <const> = log.info:copy(
   decoration.decorate("Rockspec", decoration.scheme.cyan),
   decoration.decorate("...", decoration.scheme.cyan)
)

local modules <const> = {}
local install <const> = {}
for f in fs.scan_dir("src", {"**/*"}, {"**/*.d.tl"}) do
   local f_str = f:tostring()
   local mod = f_str:sub(1, -4):gsub("/", ".")
   table.insert(install, {
      mod,
      "src/" .. f_str,
   })
   table.insert(modules, {
      mod,
      "build/" .. f_str:gsub("%.tl$", ".lua"),
   })
end
local function cmp(a: {string, string}, b: {string, string}): boolean
   return a[1] < b[1]
end
table.sort(modules, cmp)
table.sort(install, cmp)
local function convert(t: {{string, string}}, indent: integer): string
   local buf <const> = {}
   for i, v in ipairs(t) do
      buf[i] = ("%s[%q] = %q,"):format(("   "):rep(indent), v[1], v[2])
   end
   return table.concat(buf, "\n")
end

local fh <const> = io.open(specfile, "w")
fh:write(template:format(convert(modules, 2), convert(install, 3)))
fh:close()
info("Wrote ", decoration.file_name(specfile))
