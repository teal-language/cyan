-- This rockspec was generated by scripts/gen_rockspec.tl
-- Do not modify this
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
   "tl >= 0.24.0",
   "luasystem >= 0.3.0",
   "lexical-path ~> 0.1",
}
build = {
   type = "builtin",
   modules = {
      ["cyan.cli"] = "build/cyan/cli.lua",
      ["cyan.command"] = "build/cyan/command.lua",
      ["cyan.commands.build"] = "build/cyan/commands/build.lua",
      ["cyan.commands.check-gen"] = "build/cyan/commands/check-gen.lua",
      ["cyan.commands.initialize"] = "build/cyan/commands/initialize.lua",
      ["cyan.commands.run"] = "build/cyan/commands/run.lua",
      ["cyan.commands.warnings"] = "build/cyan/commands/warnings.lua",
      ["cyan.config"] = "build/cyan/config.lua",
      ["cyan.decoration"] = "build/cyan/decoration.lua",
      ["cyan.fs"] = "build/cyan/fs.lua",
      ["cyan.graph"] = "build/cyan/graph.lua",
      ["cyan.interaction"] = "build/cyan/interaction.lua",
      ["cyan.log"] = "build/cyan/log.lua",
      ["cyan.meta"] = "build/cyan/meta.lua",
      ["cyan.sandbox"] = "build/cyan/sandbox.lua",
      ["cyan.script"] = "build/cyan/script.lua",
      ["cyan.tlcommon"] = "build/cyan/tlcommon.lua",
      ["cyan.util"] = "build/cyan/util.lua",
   },
   install = {
      lua = {
         ["cyan.cli"] = "src/cyan/cli.tl",
         ["cyan.command"] = "src/cyan/command.tl",
         ["cyan.commands.build"] = "src/cyan/commands/build.tl",
         ["cyan.commands.check-gen"] = "src/cyan/commands/check-gen.tl",
         ["cyan.commands.initialize"] = "src/cyan/commands/initialize.tl",
         ["cyan.commands.run"] = "src/cyan/commands/run.tl",
         ["cyan.commands.warnings"] = "src/cyan/commands/warnings.tl",
         ["cyan.config"] = "src/cyan/config.tl",
         ["cyan.decoration"] = "src/cyan/decoration.tl",
         ["cyan.fs"] = "src/cyan/fs.tl",
         ["cyan.graph"] = "src/cyan/graph.tl",
         ["cyan.interaction"] = "src/cyan/interaction.tl",
         ["cyan.log"] = "src/cyan/log.tl",
         ["cyan.meta"] = "src/cyan/meta.tl",
         ["cyan.sandbox"] = "src/cyan/sandbox.tl",
         ["cyan.script"] = "src/cyan/script.tl",
         ["cyan.tlcommon"] = "src/cyan/tlcommon.tl",
         ["cyan.util"] = "src/cyan/util.tl",
      },
      bin = {
         "bin/cyan",
      }
   }
}
