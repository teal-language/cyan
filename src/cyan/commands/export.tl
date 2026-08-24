---@nodoc

local argparse <const> = require("argparse")
local command <const> = require("cyan.command")
local common <const> = require("cyan.tlcommon")
local config <const> = require("cyan.config")
local fs <const> = require("cyan.fs")
local graph <const> = require("cyan.graph")
local invocation_context <const> = require("cyan.invocation-context")
local lexical_path <const> = require("lexical-path")
local log <const> = require("cyan.log")
local util <const> = require("cyan.util")

local ivalues <const> = util.tab.ivalues
local ins <const> = table.insert

local enum ExportFormat
   "sh" -- POSIX shell
   "bat" -- windows batch file
   "make" -- POSIX make
   "gmake" -- GNU make
   -- "ninja" Ninja is built to be generated, seems like a good fit
   -- "rockspec"
end

local function includes_from_config(c: config.Config): {string}
   local flags <const> = {}
   if c.source_dir then
      ins(flags, "-I" .. c.source_dir:to_string())
   end
   for dir in ivalues(c.include_dir) do
      ins(flags, "-I" .. dir:to_string())
   end
   if c.global_env_def then ins(flags, "--global-env-def=" .. c.global_env_def) end
   return flags
end

local function flags_from_config(c: config.Config): {string}
   local flags <const> = { "--quiet" }
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

-- TODO: Build should use this too
local function minimal_mkdir_p(dag: graph.Dag): {lexical_path.Path}
   -- directory path set
   --   nil   : not present
   --   true  : present, need to mkdir -p
   --   false : present, but handled by child directory
   local mkdirs <const>: {string:boolean} = {}
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

   local dirs <const> = {}
   for k, v in pairs(mkdirs) do
      if v then
         ins(dirs, k)
      end
   end
   table.sort(dirs)
   return util.tab.map(dirs, lexical_path.from_os)
end

local extension_to_format <const>: {string:ExportFormat} = {
   sh = "sh",
   bash = "sh",
   mk = "make",
   bat = "bat",
}

local function export_format_from_path(p: lexical_path.Path): ExportFormat
   do
      local last <const> = p[#p]
      if not last then return end
      local lowered <const> = last:lower()
      if lowered == "makefile"
         or lowered == "bsdmakefile"
      then
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

local interface Args
   is command.CheckOptions, command.GenOptions
   where self.command == "export"

   file: lexical_path.Path
   format: ExportFormat
end

local record BuildInfo
   abs_source_dir: lexical_path.Absolute
   abs_build_dir: lexical_path.Absolute
   config: config.Config
end

local function get_output_name(info: BuildInfo, src: lexical_path.Relative): lexical_path.Path
   local out <const> = info.config.build_dir .. src
      as lexical_path.Relative
   local ext <const> = out:extension():lower()
   if ext:lower() == "tl" then
      out[#out] = out[#out]:sub(1, -#ext - 2) .. ".lua"
   end
   return out
end

local function get_build_graph(info: BuildInfo): graph.Dag
   local include <const> = info.config.include or {}
   local exclude <const> = info.config.exclude and { table.unpack(info.config.exclude) } or {}
   if info.abs_source_dir == info.config.loaded_from:parent() then
      ins(exclude, lexical_path.parse_pattern "tlconfig.lua")
   end

   local dag <const>, cycles <const> = graph.scan_directory(info.abs_source_dir, include, exclude)
   if not dag then
      log.err(
         "Circular dependency detected in the following files:\n   ",
         table.unpack(util.tab.intersperse(cycles, "\n   "))
      )
   end
   return dag
end

local function gen_posix_shell(
   out: FILE,
   dag: graph.Dag,
   dirs_to_mk: {lexical_path.Path},
   info: BuildInfo
)
   local total <const> = tostring(dag:node_count())

   out:write("#!/usr/bin/env sh\nset -e\nTL=${TL:-tl}\n")
   out:write("TLINCLUDE=${TLINCLUDE:-", table.concat(includes_from_config(info.config), " "), "}\n")
   out:write("TLFLAGS=${TLFLAGS:-", table.concat(flags_from_config(info.config), " "), "}\n")

   out:write([[clrln="\e[G\e[A\e[K"]], "\n")
   out:write("if test -v NO_COLOR; then clrln=; fi\n")
   out:write[[
compile(){
	if test "$2" -ot "$3"; then return; fi
	echo "[$1] TL gen $2"
	$TL gen $TLFLAGS $TLINCLUDE "$2" -o "$3"
	echo -ne $clrln
}
]]

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
      local input <const> = (info.config.source_dir .. node.input):to_string()
      local output <const> = node.output:to_string()
      out:write("compile '", util.str.pad_left(tostring(i), #total), "/", total, "' ", input, " ", output, "\n")
   end
end

local function gen_makefile(
   out: FILE,
   dag: graph.Dag,
   dirs_to_mk: {lexical_path.Path},
   info: BuildInfo,
   posix: boolean
)
   local function src_name(node: graph.Node): string
      return "$(srcdir)/" .. node.input:remove_leading(info.config.source_dir):to_string()
   end
   local function obj_name(p: lexical_path.Path): string
      return "$(objdir)/" .. p:remove_leading(info.config.source_dir):to_string():gsub("%.tl$", ".lua")
   end
   local function dest_name(p: lexical_path.Path): string
      local rel <const> = p.is_absolute
         and p:relative_to(info.abs_build_dir)
         or p:relative_to(info.config.build_dir)
      return "$(DESTDIR)/" .. rel:to_string()
   end

   -- We structure our build graph the exact opposite of how make does
   local make_graph <const> = dag:inverted_dependencies()
   local sorted <const> = util.tab.reverse_in_place(util.tab.from(make_graph:nodes()))

   if posix then
      out:write(".POSIX:\n")
   end
   out:write(".PHONY: all installdirs install uninstall clean help objdirs\n")
   out:write(".DEFAULT: all\n")
   out:write("RM ::= rm\n")
   out:write("CP ::= cp\n")
   out:write("MKDIR_P ::= mkdir -p\n")
   out:write("TL ::= tl\n")
   out:write("TLFLAGS ::= ", table.concat(flags_from_config(info.config), " "), "\n")
   out:write("TLINCLUDE ::= ", table.concat(includes_from_config(info.config), " "), "\n")
   out:write("srcdir = ", info.config.source_dir:to_string(), "\n")
   out:write("objdir = ", info.config.build_dir:to_string(), "\n")
   out:write("DESTDIR = ", info.config.build_dir:to_string(), "\n")
   out:write("OBJS ::= ")
   for node in ivalues(sorted) do
      out:write(" ", obj_name(node.input))
   end
   out:write("\n")

   out:write("all: $(OBJS)\n")
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
   out:write("\t@echo '   help'\n")
   out:write("\t@echo '   clean'\n")
   out:write("\t@echo '   install'\n")
   out:write("\t@echo '   uninstall'\n")

   local tl_gen_rule <const> = "$(TL) gen $(TLFLAGS) $(TLINCLUDE) $< -o $@"

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

   out:write("install: installdirs $(OBJS)\n")
   for node in ivalues(sorted) do
      out:write("\t$(CP) ", obj_name(node.input), " ", dest_name(node.output), "\n")
   end

   out:write("uninstall:")
   out:write("\n\t$(RM) -f")
   for node in ivalues(sorted) do
      out:write(" ", dest_name(node.output))
   end
   out:write("\n")

   out:write("clean:\n\t$(RM) -f $(OBJS)\n")

   for node in ivalues(sorted) do
      out:write(obj_name(node.input), ": ", src_name(node))
      for dep in pairs(node.dependents) do
         out:write(" ", src_name(dep))
      end
      if not posix then
         out:write(" | objdirs")
      end
      out:write("\n")
      if posix then
         out:write("\t", tl_gen_rule, "\n")
      end
   end

   if posix then
      return
   end

   out:write("$(objdir)/%.lua: $(srcdir)/%.tl\n\t@echo TL gen $<\n\t@", tl_gen_rule, "\n")
end

local function gen_batch(
   out: FILE,
   dag: graph.Dag,
   dirs_to_mk: {lexical_path.Path},
   info: BuildInfo
)
   out:write("@echo off\n")

   out:write("setlocal enableextensions\n")
   out:write("set tl=%TL%\n")
   out:write("set tl_flags=%TLFLAGS%\n")
   out:write("set tl_include=%TLINCLUDE%\n")
   out:write("if [%tl%]==[] set tl=tl\n")
   out:write("if [%tl_include%]==[] set tl_include=", table.concat(includes_from_config(info.config), " "), "\n")
   out:write("if [%tl_flags%]==[] set tl_flags=", table.concat(flags_from_config(info.config), " "), "\n")

   local total <const> = tostring(dag:node_count())

   -- TODO: mkdir only creates parent directories if extensions are enabled.
   -- They are enabled by default, so not a huge issue but still
   for dir in ivalues(dirs_to_mk) do
      out:write("echo '[", ("-"):rep(#total * 2 + 1), "] MKDIR ", dir:to_string("\\"), "'\n",
         "if not exist ", dir:to_string("\\"), "\\ mkdir ", dir:to_string("\\"), "\n")
   end

   local i = 0
   for node in dag:nodes() do
      i = i + 1
      local input <const> = (info.config.source_dir .. node.input):to_string("\\")
      local output <const> = node.output:to_string("\\")
      out:write("echo '[", util.str.pad_left(tostring(i), #total), "/", total, "] TL gen ", input, "'\n")
      out:write("%tl% gen %tl_flags% %tl_include% ", input, " -o ", output, "\n")
   end

   out:write("endlocal\n")
end

local function export(args: Args, loaded_config: config.Config, context: invocation_context.InvocationContext): integer
   local out <const>, err <const> = io.open(args.file:to_string(), "w")
   if not out then
      log.err("Unable to open ", context:display_path(args.file), " for export: ", err)
      return 1
   end

   local format <const> = args.format or export_format_from_path(args.file)
   if not format then
      log.err("Unable to determine format from file name ‘", args.file, "’\n(hint: use --format to manually specify one)")
      return 1
   end
   log.extra("Export format: ", format)

   local cwd <const> = assert(fs.current_directory())
   local info <total>: BuildInfo = {
      config = loaded_config,
      abs_build_dir = loaded_config.build_dir
         and cwd .. loaded_config.build_dir
         or cwd,
      abs_source_dir = loaded_config.source_dir
         and cwd .. loaded_config.source_dir
         or cwd,
   }

   do
      local include_dir <const> = util.tab.merge_list(loaded_config.include_dir, args.include_dir)
      common.add_includes(info.abs_source_dir, include_dir)
   end

   local dag <const> = get_build_graph(info)
   if not dag then
      return 1
   end

   for node in dag:nodes_unordered() do
      node.output = get_output_name(info, node.input)
   end
   local dirs_to_mk <const> = minimal_mkdir_p(dag)

   local generators <total>: {ExportFormat:function(FILE, graph.Dag, {lexical_path.Path}, BuildInfo)} = {
      sh = gen_posix_shell,
      make = function(f:FILE,g:graph.Dag,d:{lexical_path.Path}, i:BuildInfo) gen_makefile(f,g,d,i,true) end,
      gmake = function(f:FILE,g:graph.Dag,d:{lexical_path.Path}, i:BuildInfo) gen_makefile(f,g,d,i,false) end,
      bat = gen_batch,
   }

   generators[format](out, dag, dirs_to_mk, info)

   out:close()
   log.info("Exported build commands to ", context:display_path(args.file))
   return 0
end

command.new{
   name = "export",
   description = [[Export teal compiler commands to a file.]],
   exec = export,
   argparse = function(cmd: argparse.Command)
      cmd:argument("file", "Export invocations of the teal compiler to the given file")
         :args(1)
         :convert(lexical_path.from_os)

      local export_formats <total>: {ExportFormat:boolean} = {
         sh = true,
         make = true,
         gmake = true,
         bat = true,
      }
      cmd:option("--export-format", "Manually specify the format of --export instead of determining it by file name")
         :choices(util.tab.from(util.tab.keys(export_formats as {string:boolean})))

      command.add_check_options(cmd)
   end,
}
