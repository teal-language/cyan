local _tl_compat; if (tonumber((_VERSION or ''):match('[%d.]*$')) or 0) < 5.3 then local p, m = true, require('compat53.module'); if p then _tl_compat = m end end; local assert = _tl_compat and _tl_compat.assert or assert; local io = _tl_compat and _tl_compat.io or io; local pairs = _tl_compat and _tl_compat.pairs or pairs; local string = _tl_compat and _tl_compat.string or string; local table = _tl_compat and _tl_compat.table or table; local _tl_table_unpack = unpack or table.unpack

local argparse = require("argparse")
local command = require("cyan.command")
local common = require("cyan.tlcommon")
local config = require("cyan.config")
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
}

local function export_format_from_path(p)
   do
      local last = p[#p]
      if not last then return end
      local lowered = last:lower()
      if lowered == "makefile" or
         lowered == "bsdmakefile" or
         lowered == "gnumakefile" then

         return "make"
      end
   end
   do
      local ext = p:extension()
      if not ext then return end
      ext = ext:lower()
      return extension_to_format[ext]
   end
end















local function get_output_name(info, src)
   local out = info.config.build_dir .. src

   local ext = out:extension():lower()
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
   out,
   dag,
   dirs_to_mk,
   info)

   out:write(".POSIX:\n")
   out:write(".PHONY: install uninstall help\n")
   out:write(".DEFAULT: help\n")
   out:write("RM ::= rm\n")
   out:write("CP ::= cp\n")
   out:write("MKDIR_P ::= mkdir -p\n")
   out:write("TL ::= tl\n")
   out:write("TLFLAGS ::= ", table.concat(flags_from_config(info.config), " "), "\n")
   out:write("TLINCLUDE ::= ", table.concat(includes_from_config(info.config), " "), "\n")
   out:write("srcdir = ", info.config.source_dir:to_string(), "\n")
   out:write("objdir = $(srcdir)\n")
   out:write("DESTDIR = ", info.config.build_dir:to_string(), "\n")

   out:write("help:\n")
   out:write("\t@echo Generated makefile from cyan\n")
   out:write("\t@echo\n")
   out:write("\t@echo 'Tools and flags:'\n")
   out:write("\t@echo '   CP        = $(CP)'\n")
   out:write("\t@echo '   RM        = $(RM)'\n")
   out:write("\t@echo '   MKDIR     = $(MKDIR)'\n")
   out:write("\t@echo '   DESTDIR   = $(DESTDIR)'\n")
   out:write("\t@echo '   TL        = $(TL)'\n")
   out:write("\t@echo '   TLFLAGS   = $(TLFLAGS)'\n")
   out:write("\t@echo '   TLINCLUDE = $(TLINCLUDE)'\n")
   out:write("\t@echo\n")
   out:write("\t@echo 'Targets:'\n")
   out:write("\t@echo '   help'\n")
   out:write("\t@echo '   install'\n")
   out:write("\t@echo '   uninstall'\n")

   local tl_gen_rule = "\t$(TL) gen $(TLFLAGS) $(TLINCLUDE) $< -o $@\n"


   local make_graph = dag:inverted_dependencies()
   local sorted = util.tab.sort_in_place(util.tab.from(make_graph:nodes_unordered()), function(a, b)
      return a.input:to_string() < b.input:to_string()
   end)

   local function src_name(node)
      return "$(srcdir)/" .. node.input:remove_leading(info.config.source_dir):to_string()
   end
   local function obj_name(node)
      return "$(objdir)/." .. node.input:to_string("_") .. ".lua"
   end
   local function dest_name(p)
      local rel = p.is_absolute and
      p:relative_to(info.abs_build_dir) or
      p:relative_to(info.config.build_dir)
      return "$(DESTDIR)/" .. rel:to_string()
   end

   out:write("install:")
   for node in ivalues(sorted) do
      out:write(" ", obj_name(node))
   end
   out:write("\n")
   for dir in ivalues(dirs_to_mk) do
      out:write("\t$(MKDIR_P) ", dest_name(dir), "\n")
   end
   for node in ivalues(sorted) do
      out:write("\t$(CP) ", obj_name(node), " ", dest_name(node.output), "\n")
   end
   out:write("\n")

   out:write("uninstall:")
   out:write("\n\t$(RM) -f")
   for node in ivalues(sorted) do
      out:write(" ", dest_name(node.output))
   end
   out:write("\n")

   for node in ivalues(sorted) do
      out:write(obj_name(node), ": ", src_name(node))
      for dep in pairs(node.dependents) do
         out:write(" ", src_name(dep))
      end
      out:write("\n", tl_gen_rule)
   end
end

local function gen_batch(
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

local function export(args, loaded_config, context)
   local out, err = io.open(args.file:to_string(), "w")
   if not out then
      log.err("Unable to open ", context:display_path(args.file), " for export: ", err)
      return 1
   end

   local format = args.format or export_format_from_path(args.file)
   if not format then
      log.err("Unable to determine format from file name ‘", args.file, "’\n(hint: use --format to manually specify one)")
      return 1
   end
   log.extra("Export format: ", format)

   local cwd = assert(fs.current_directory())
   local info = {
      config = loaded_config,
      abs_build_dir = loaded_config.build_dir and
      cwd .. loaded_config.build_dir or
      cwd,
      abs_source_dir = loaded_config.source_dir and
      cwd .. loaded_config.source_dir or
      cwd,
   }

   do
      local include_dir = util.tab.merge_list(loaded_config.include_dir, args.include_dir)
      common.add_includes(info.abs_source_dir, include_dir)
   end

   local dag = get_build_graph(info)
   if not dag then
      return 1
   end

   for node in dag:nodes_unordered() do
      node.output = get_output_name(info, node.input)
   end
   local dirs_to_mk = minimal_mkdir_p(dag)

   local generators = {
      sh = gen_posix_shell,
      make = gen_makefile,
      bat = gen_batch,
   }

   generators[format](out, dag, dirs_to_mk, info)

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
         bat = true,
      }
      cmd:option("--export-format", "Manually specify the format of --export instead of determining it by file name"):
      choices(util.tab.from(util.tab.keys(export_formats)))

      command.add_check_options(cmd)
   end,
})
