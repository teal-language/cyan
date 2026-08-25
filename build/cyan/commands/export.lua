local _tl_compat; if (tonumber((_VERSION or ''):match('[%d.]*$')) or 0) < 5.3 then local p, m = true, require('compat53.module'); if p then _tl_compat = m end end; local assert = _tl_compat and _tl_compat.assert or assert; local io = _tl_compat and _tl_compat.io or io; local ipairs = _tl_compat and _tl_compat.ipairs or ipairs; local pairs = _tl_compat and _tl_compat.pairs or pairs; local string = _tl_compat and _tl_compat.string or string; local table = _tl_compat and _tl_compat.table or table; local _tl_table_unpack = unpack or table.unpack

local argparse = require("argparse")
local command = require("cyan.command")
local common = require("cyan.tlcommon")
local config = require("cyan.config")
local decoration = require("cyan.decoration")
local fs = require("cyan.fs")
local graph = require("cyan.graph")
local invocation_context = require("cyan.invocation-context")
local lexical_path = require("lexical-path")
local log = require("cyan.log")
local util = require("cyan.util")

local ivalues = util.tab.ivalues
local ins = table.insert










local function includes_from_config(c)
   local flags = {}
   if c.source_dir then
      ins(flags, "-I" .. c.source_dir:to_string())
   end
   for dir in ivalues(c.include_dir) do
      ins(flags, "-I" .. dir:to_string())
   end
   if c.global_env_def then ins(flags, "--global-env-def=" .. c.global_env_def) end
   return flags
end

local function flags_from_config(c)
   local flags = { "--quiet" }
   if c.gen_target then ins(flags, "--gen-target=" .. c.gen_target) end
   if c.gen_compat then ins(flags, "--gen-compat=" .. c.gen_compat) end
   if c.feat_arity then ins(flags, "--feat-arity=" .. c.feat_arity) end

   for w in ivalues(c.disable_warnings) do
      ins(flags, "--wdisable=" .. w)
   end
   for w in ivalues(c.warning_error) do
      ins(flags, "--werror=" .. w)
   end
   return flags
end


local function minimal_mkdir_p(dag)




   local mkdirs = {}
   for node in dag:nodes_unordered() do
      assert(node.output)
      for i = 1, #node.output - 2 do
         mkdirs[node.output:sub(1, i):to_string()] = false
      end
      local last = node.output:sub(1, -2):to_string()
      if last ~= "." and mkdirs[last] ~= false then
         mkdirs[last] = true
      end
   end

   local dirs = {}
   for k, v in pairs(mkdirs) do
      if v then
         ins(dirs, k)
      end
   end
   table.sort(dirs)
   return util.tab.map(dirs, lexical_path.from_os)
end

local extension_to_format = {
   sh = "sh",
   bash = "sh",
   mk = "make",
   bat = "bat",
   ninja = "ninja",
}

local function export_format_from_path(p)
   do
      local last = p[#p]
      if not last then return end
      local lowered = last:lower()
      if lowered == "makefile" or
         lowered == "bsdmakefile" then

         return "make"
      end
      if lowered == "gnumakefile" then
         return "gmake"
      end
   end
   do
      local ext = p:extension()
      if not ext then return end
      ext = ext:lower()
      return extension_to_format[ext]
   end
end

















local function get_output_name(build_dir, src)
   local out = build_dir .. src
   local ext = out:extension(2):lower()
   if ext:lower() == "tl" then
      out[#out] = out[#out]:sub(1, -#ext - 2) .. ".lua"
   end
   return out
end

local function get_build_graph(info)
   local include = info.config.include or {}
   local exclude = info.config.exclude and { _tl_table_unpack(info.config.exclude) } or {}
   if info.abs_source_dir == info.config.loaded_from:parent() then
      ins(exclude, lexical_path.parse_pattern("tlconfig.lua"))
   end

   local dag, cycles = graph.scan_directory(info.abs_source_dir, include, exclude)
   if not dag then
      log.err(
      "Circular dependency detected in the following files:\n   ",
      _tl_table_unpack(util.tab.intersperse(cycles, "\n   ")))

   end
   return dag
end









local function gen_posix_shell(
   _file_name,
   out,
   dag,
   dirs_to_mk,
   info)

   local total = tostring(dag:node_count())

   out:write("#!/usr/bin/env sh\nset -e\nTL=${TL:-tl}\n")
   out:write("TLINCLUDE=${TLINCLUDE:-", table.concat(includes_from_config(info.config), " "), "}\n")
   out:write("TLFLAGS=${TLFLAGS:-", table.concat(flags_from_config(info.config), " "), "}\n")

   out:write([[clrln="\e[G\e[A\e[K"]], "\n")
   out:write("if test -v NO_COLOR; then clrln=; fi\n")
   out:write([[
compile(){
	if test "$2" -ot "$3"; then return; fi
	echo "[$1] TL gen $2"
	$TL gen $TLFLAGS $TLINCLUDE "$2" -o "$3"
	echo -ne $clrln
}
]])

   out:write('echo "TL        = $TL"\n')
   out:write('echo "TLFLAGS   = $TLFLAGS"\n')
   out:write('echo "TLINCLUDE = $TLINCLUDE"\n')
   out:write("echo '======================='\n")

   for dir in ivalues(dirs_to_mk) do
      out:write("echo '[", ("-"):rep(#total * 2 + 1), "] MKDIR ", dir:to_string(), "';mkdir -p ", dir:to_string(), ";echo -ne $clrln\n")
   end

   local i = 0
   for node in dag:nodes() do
      i = i + 1
      local input = (info.config.source_dir .. node.input):to_string()
      local output = node.output:to_string()
      out:write("compile '", util.str.pad_left(tostring(i), #total), "/", total, "' ", input, " ", output, "\n")
   end
end

local function gen_makefile(
   _file_name,
   out,
   dag,
   dirs_to_mk,
   info,
   posix)

   local function src_name(p)
      return "$(srcdir)/" .. p:remove_leading(info.config.source_dir):to_string()
   end
   local function obj_name(p)
      return "$(objdir)/" .. p:remove_leading(info.config.source_dir):to_string():gsub("%.tl$", ".lua")
   end
   local function checked_name(p)
      return "$(objdir)/" .. p:remove_leading(info.config.source_dir):to_string() .. ".checked"
   end
   local function dest_name(p)
      local rel = p.is_absolute and
      p:relative_to(info.abs_build_dir) or
      p:relative_to(info.config.build_dir)
      return "$(DESTDIR)/" .. rel:to_string()
   end


   local make_graph = dag:inverted_dependencies()
   local sorted = util.tab.reverse_in_place(util.tab.from(make_graph:nodes()))

   if posix then
      out:write(".POSIX:\n")
   end
   out:write(".PHONY: all check gen installdirs install uninstall clean help objdirs\n")
   out:write(".DEFAULT: all\n")
   out:write("RM ::= rm\n")
   out:write("CP ::= cp\n")
   out:write("MKDIR_P ::= mkdir -p\n")
   out:write("TL ::= tl\n")
   out:write("TLFLAGS ::= ", table.concat(flags_from_config(info.config), " "), "\n")
   out:write("TLINCLUDE ::= ", table.concat(includes_from_config(info.config), " "), "\n")
   out:write("srcdir = ", info.config.source_dir:to_string(), "\n")
   out:write("objdir = .tl\n")
   out:write("DESTDIR = ", info.config.build_dir:to_string(), "\n")
   out:write("OBJS ::= ")
   for node in ivalues(sorted) do
      out:write(" ", obj_name(node.input))
   end
   out:write("\n")
   out:write("CHECKS ::= ")
   for node in ivalues(sorted) do
      out:write(" ", checked_name(node.input))
   end
   out:write("\n")

   out:write("check: $(CHECKS)\n")
   out:write("gen: $(OBJS)\n")
   out:write("all: check gen\n")
   out:write("help:\n")
   out:write("\t@echo Generated makefile from cyan\n")
   out:write("\t@echo\n")
   out:write("\t@echo 'Tools and flags:'\n")
   out:write("\t@echo '   CP        = $(CP)'\n")
   out:write("\t@echo '   RM        = $(RM)'\n")
   out:write("\t@echo '   MKDIR_P   = $(MKDIR_P)'\n")
   out:write("\t@echo '   DESTDIR   = $(DESTDIR)'\n")
   out:write("\t@echo '   TL        = $(TL)'\n")
   out:write("\t@echo '   TLFLAGS   = $(TLFLAGS)'\n")
   out:write("\t@echo '   TLINCLUDE = $(TLINCLUDE)'\n")
   out:write("\t@echo\n")
   out:write("\t@echo 'Targets:'\n")
   out:write("\t@echo '   all         Check and compile'\n")
   out:write("\t@echo '   check       Type check files'\n")
   out:write("\t@echo '   gen         Compile files (without type checking)'\n")
   out:write("\t@echo '   help        Print this help'\n")
   out:write("\t@echo '   clean       Delete generated files'\n")
   out:write("\t@echo '   install     Check, compile, and copy to DESTDIR'\n")
   out:write("\t@echo '   uninstall   Delete files from DESTDIR'\n")

   local check_rule = "$(TL) check $(TLFLAGS) $(TLINCLUDE) $<"
   local gen_rule = "$(TL) gen --no-check $(TLFLAGS) $(TLINCLUDE) $< -o $@"

   out:write("objdirs:\n")
   for dir in ivalues(dirs_to_mk) do
      if #dir > 1 then
         out:write("\t@$(MKDIR_P) $(objdir)/", dir:sub(2):to_string(), "\n")
      end
   end

   out:write("installdirs:\n")
   for dir in ivalues(dirs_to_mk) do
      out:write("\t@$(MKDIR_P) ", dest_name(dir), "\n")
   end

   out:write("install: installdirs all\n")
   for node in ivalues(sorted) do
      out:write("\t$(CP) ", obj_name(node.input), " ", dest_name(node.output), "\n")
   end

   out:write("uninstall:")
   out:write("\n\t$(RM) -f")
   for node in ivalues(sorted) do
      out:write(" ", dest_name(node.output))
   end
   out:write("\n")

   out:write("clean:\n\t$(RM) -f $(OBJS) $(CHECKS)\n")

   for node in ivalues(sorted) do
      out:write(obj_name(node.input), ": ", src_name(node.input))
      if posix then
         out:write("\n\t@$(MKDIR_P) $(@D)\n\t@echo TL gen $<\n\t@", gen_rule)
      else
         out:write(" | objdirs")
      end
      out:write("\n")

      out:write(checked_name(node.input), ": ", src_name(node.input))
      for dep in pairs(node.dependents) do
         out:write(" ", checked_name(dep.input))
      end
      out:write("\n")

      if posix then
         out:write("\t@$(MKDIR_P) $(@D)\n\t@echo TL check $<\n\t@", check_rule, "\n\t@touch $@\n")
      end
   end

   if posix then
      return
   end

   out:write(
   checked_name((lexical_path.from_unix("%.tl"))), ": ", src_name((lexical_path.from_unix("%.tl"))),
   "\n\t@echo TL check $<\n\t@", check_rule, "\n\t@touch $@\n")

   out:write(
   obj_name((lexical_path.from_unix("%.tl"))), ": ", src_name((lexical_path.from_unix("%.tl"))),
   "\n\t@echo TL gen $<\n\t@", gen_rule, "\n")

end

local function gen_batch(
   _file_name,
   out,
   dag,
   dirs_to_mk,
   info)

   out:write("@echo off\n")

   out:write("setlocal enableextensions\n")
   out:write("set tl=%TL%\n")
   out:write("set tl_flags=%TLFLAGS%\n")
   out:write("set tl_include=%TLINCLUDE%\n")
   out:write("if [%tl%]==[] set tl=tl\n")
   out:write("if [%tl_include%]==[] set tl_include=", table.concat(includes_from_config(info.config), " "), "\n")
   out:write("if [%tl_flags%]==[] set tl_flags=", table.concat(flags_from_config(info.config), " "), "\n")

   local total = tostring(dag:node_count())



   for dir in ivalues(dirs_to_mk) do
      out:write("echo '[", ("-"):rep(#total * 2 + 1), "] MKDIR ", dir:to_string("\\"), "'\n",
      "if not exist ", dir:to_string("\\"), "\\ mkdir ", dir:to_string("\\"), "\n")
   end

   local i = 0
   for node in dag:nodes() do
      i = i + 1
      local input = (info.config.source_dir .. node.input):to_string("\\")
      local output = node.output:to_string("\\")
      out:write("echo '[", util.str.pad_left(tostring(i), #total), "/", total, "] TL gen ", input, "'\n")
      out:write("%tl% gen %tl_flags% %tl_include% ", input, " -o ", output, "\n")
   end

   out:write("endlocal\n")
end

local function gen_ninja(
   file_name,
   out,
   dag,
   dirs_to_mk,
   info)

   out:write("rule regenerate\n command = cyan export --format ninja $out\n generator = 1\n description = Rerunning cyan export\n")
   out:write("build ", file_name:to_string(), ": regenerate | ", info.config.loaded_from:to_string(), "\n")
   out:write("tlflags = ", table.concat(flags_from_config(info.config), " "), "\n")
   out:write("tlinclude = ", table.concat(includes_from_config(info.config), " "), "\n")

   local function dest_name(p)
      return (info.abs_build_dir .. p):to_string()
   end
   local function src_name(p)
      return (info.abs_source_dir .. p):to_string()
   end
   local function checked_name(p)
      return src_name(p) .. ".checked"
   end

   out:write("rule gen\n command = tl gen --no-check $tlflags $tlinclude $in -o $out\n")
   out:write(" description = TL gen $in\n")
   local is_windows = fs.path_separator == "\\"
   local cmd_c = is_windows and "cmd /c " or ""
   out:write("rule check\n command = ", cmd_c, "tl check $tlflags $tlinclude $in && touch $out\n")
   out:write(" description = TL check $in\n")

   if #dirs_to_mk > 0 then
      local mkdir_p = is_windows and "mkdir" or "mkdir -p"
      out:write("rule mkdirs\n command = ", cmd_c)
      for i, dir in ipairs(dirs_to_mk) do
         if i > 1 then
            out:write(" && ")
         end
         out:write(mkdir_p, " ", dir:to_string())
      end
      out:write("\n")
      out:write("build mkdirs: mkdirs\n")
   end

   local inverted = dag:inverted_dependencies()
   local sorted = util.tab.reverse_in_place(util.tab.from(inverted:nodes()))

   for node in ivalues(sorted) do
      out:write("build ", checked_name(node.input), ": check ", src_name(node.input))
      if next(node.dependents) then
         out:write(" |")
         for dep in pairs(node.dependents) do
            out:write(" ", checked_name(dep.input))
         end
      end
      out:write("\n")

      local output = node.output
      assert(not output.is_absolute)
      out:write("build ", dest_name(output), ": gen ", src_name(node.input))
      if next(node.dependents) or #dirs_to_mk > 0 then
         out:write(" ||")
         for dep in pairs(node.dependents) do
            out:write(" ", checked_name(dep.input))
         end
         out:write(" mkdirs")
      end
      out:write("\n")
   end
end

local function export(args, loaded_config, context)
   local format = args.format or export_format_from_path(args.file)
   if not format then
      log.err("Unable to determine format from file name ‘", args.file, "’\n(hint: use --format to manually specify one)")
      return 1
   end
   log.extra("Export format: ", format)

   local cwd = assert(fs.current_directory())
   local function ensure_absolute(p)
      if not p then return nil end
      if p.is_absolute then
         return p
      end
      return cwd .. p
   end

   local info = {
      config = loaded_config,
      abs_build_dir = ensure_absolute(args.build_dir or loaded_config.build_dir),
      abs_source_dir = ensure_absolute(args.source_dir or loaded_config.source_dir),
   }
   if not info.abs_build_dir then
      log.err("No build_dir specified. Either add it to ", decoration.file_name(loaded_config.loaded_from or "tlconfig.lua"), " or use the --build-dir (-b) option")
      return 1
   end
   if not info.abs_source_dir then
      log.err("No source_dir specified. Add it to ", decoration.file_name(loaded_config.loaded_from or "tlconfig.lua"), " or use the --source-dir (-s) option")
      return 1
   end

   do
      local include_dir = util.tab.merge_list(loaded_config.include_dir, args.include_dir)
      common.add_includes(info.abs_source_dir, include_dir)
   end

   local dag = get_build_graph(info)
   if not dag then
      return 1
   end

   for node in dag:nodes_unordered() do
      node.output = get_output_name(info.abs_build_dir, node.input)
   end
   local dirs_to_mk = minimal_mkdir_p(dag)

   local out, err = io.open(args.file:to_string(), "w")
   if not out then
      log.err("Unable to open ", context:display_path(args.file), " for export: ", err)
      return 1
   end

   local generators = {
      sh = gen_posix_shell,
      make = function(n, f, g, d, i) gen_makefile(n, f, g, d, i, true) end,
      gmake = function(n, f, g, d, i) gen_makefile(n, f, g, d, i, false) end,
      bat = gen_batch,
      ninja = gen_ninja,
   }

   generators[format](args.file, out, dag, dirs_to_mk, info)

   out:close()
   log.info("Exported build commands to ", context:display_path(args.file))
   return 0
end

command.new({
   name = "export",
   description = [[Export teal compiler commands to a file.]],
   exec = export,
   argparse = function(cmd)
      cmd:argument("file", "Export invocations of the teal compiler to the given file"):
      args(1):
      convert(lexical_path.from_os)

      local export_formats = {
         sh = true,
         make = true,
         gmake = true,
         bat = true,
         ninja = true,
      }
      cmd:option("--format", "Manually specify the format instead of determining it by file name"):
      choices(util.tab.from(util.tab.keys(export_formats)))

      command.add_check_options(cmd)

      cmd:option("-s --source-dir", "Override the source directory"):
      convert(lexical_path.from_os)
      cmd:option("-b --build-dir", "Override the build directory"):
      convert(lexical_path.from_os)
   end,
})
