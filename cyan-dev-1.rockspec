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
      ["cyan.ansi"] = "build/cyan/ansi.lua",
      ["cyan.cli"] = "build/cyan/cli.lua",
      ["cyan.colorstring"] = "build/cyan/colorstring.lua",
      ["cyan.command"] = "build/cyan/command.lua",
      ["cyan.commands.build"] = "build/cyan/commands/build.lua",
      ["cyan.commands.check-gen"] = "build/cyan/commands/check-gen.lua",
      ["cyan.commands.initialize"] = "build/cyan/commands/initialize.lua",
      ["cyan.commands.run"] = "build/cyan/commands/run.lua",
      ["cyan.commands.warnings"] = "build/cyan/commands/warnings.lua",
      ["cyan.config"] = "build/cyan/config.lua",
      ["cyan.fs.init"] = "build/cyan/fs/init.lua",
      ["cyan.fs.path"] = "build/cyan/fs/path.lua",
      ["cyan.graph"] = "build/cyan/graph.lua",
      ["cyan.log"] = "build/cyan/log.lua",
      ["cyan.sandbox"] = "build/cyan/sandbox.lua",
      ["cyan.script"] = "build/cyan/script.lua",
      ["cyan.tlcommon"] = "build/cyan/tlcommon.lua",
      ["cyan.util"] = "build/cyan/util.lua",
   },
   install = {
      lua = {
         ["cyan.ansi"] = "src/cyan/ansi.tl",
         ["cyan.cli"] = "src/cyan/cli.tl",
         ["cyan.colorstring"] = "src/cyan/colorstring.tl",
         ["cyan.command"] = "src/cyan/command.tl",
         ["cyan.commands.build"] = "src/cyan/commands/build.tl",
         ["cyan.commands.check-gen"] = "src/cyan/commands/check-gen.tl",
         ["cyan.commands.initialize"] = "src/cyan/commands/initialize.tl",
         ["cyan.commands.run"] = "src/cyan/commands/run.tl",
         ["cyan.commands.warnings"] = "src/cyan/commands/warnings.tl",
         ["cyan.config"] = "src/cyan/config.tl",
         ["cyan.fs.init"] = "src/cyan/fs/init.tl",
         ["cyan.fs.path"] = "src/cyan/fs/path.tl",
         ["cyan.graph"] = "src/cyan/graph.tl",
         ["cyan.log"] = "src/cyan/log.tl",
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
