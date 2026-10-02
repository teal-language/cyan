.POSIX:
.PHONY: all check gen installdirs install uninstall clean help objdirs
.DEFAULT: all
RM ?= rm
CP ?= cp
MKDIR_P ?= mkdir -p
TL ?= tl
TLFLAGS ?= --quiet --gen-compat=required --feat-arity=on --werror=unused --werror=redeclaration
TLINCLUDE ?= -Isrc -Iscripts -Itypes
srcdir = src
objdir = .tl
DESTDIR = tmp
OBJS = $(objdir)/testing/batch-assertion.lua $(objdir)/cyan/util.lua $(objdir)/cyan/sandbox.lua $(objdir)/cyan/meta.lua $(objdir)/testing/finally.lua $(objdir)/spec/api/util_spec.lua $(objdir)/spec/api/sandbox_spec.lua $(objdir)/cyan/fs.lua $(objdir)/testing/temporary-files.lua $(objdir)/cyan/decoration.lua $(objdir)/spec/api/decoration_spec.lua $(objdir)/cyan/log.lua $(objdir)/cyan/invocation-context.lua $(objdir)/cyan/config.lua $(objdir)/testing/command-runners.lua $(objdir)/spec/api/config_spec.lua $(objdir)/cyan/interaction.lua $(objdir)/spec/commands/warnings_spec.lua $(objdir)/spec/commands/run_spec.lua $(objdir)/spec/commands/no_script_spec.lua $(objdir)/spec/commands/init_spec.lua $(objdir)/spec/commands/gen_spec.lua $(objdir)/spec/commands/check_spec.lua $(objdir)/spec/commands/build_spec.lua $(objdir)/cyan/tlcommon.lua $(objdir)/cyan/command.lua $(objdir)/cyan/graph.lua $(objdir)/cyan/commands/warnings.lua $(objdir)/cyan/commands/initialize.lua $(objdir)/cyan/script.lua $(objdir)/cyan/commands/run.lua $(objdir)/cyan/commands/check-gen.lua $(objdir)/spec/api/graph_spec.lua $(objdir)/cyan/commands/export.lua $(objdir)/spec/api/script_spec.lua $(objdir)/cyan/commands/build.lua $(objdir)/cyan/cli.lua
CHECKS = $(objdir)/testing/batch-assertion.tl.checked $(objdir)/cyan/util.tl.checked $(objdir)/cyan/sandbox.tl.checked $(objdir)/cyan/meta.tl.checked $(objdir)/testing/finally.tl.checked $(objdir)/spec/api/util_spec.tl.checked $(objdir)/spec/api/sandbox_spec.tl.checked $(objdir)/cyan/fs.tl.checked $(objdir)/testing/temporary-files.tl.checked $(objdir)/cyan/decoration.tl.checked $(objdir)/spec/api/decoration_spec.tl.checked $(objdir)/cyan/log.tl.checked $(objdir)/cyan/invocation-context.tl.checked $(objdir)/cyan/config.tl.checked $(objdir)/testing/command-runners.tl.checked $(objdir)/spec/api/config_spec.tl.checked $(objdir)/cyan/interaction.tl.checked $(objdir)/spec/commands/warnings_spec.tl.checked $(objdir)/spec/commands/run_spec.tl.checked $(objdir)/spec/commands/no_script_spec.tl.checked $(objdir)/spec/commands/init_spec.tl.checked $(objdir)/spec/commands/gen_spec.tl.checked $(objdir)/spec/commands/check_spec.tl.checked $(objdir)/spec/commands/build_spec.tl.checked $(objdir)/cyan/tlcommon.tl.checked $(objdir)/cyan/command.tl.checked $(objdir)/cyan/graph.tl.checked $(objdir)/cyan/commands/warnings.tl.checked $(objdir)/cyan/commands/initialize.tl.checked $(objdir)/cyan/script.tl.checked $(objdir)/cyan/commands/run.tl.checked $(objdir)/cyan/commands/check-gen.tl.checked $(objdir)/spec/api/graph_spec.tl.checked $(objdir)/cyan/commands/export.tl.checked $(objdir)/spec/api/script_spec.tl.checked $(objdir)/cyan/commands/build.tl.checked $(objdir)/cyan/cli.tl.checked
all: check gen
check: $(CHECKS)
gen: $(OBJS)
help:
	@echo Generated makefile from cyan
	@echo
	@echo 'Tools and flags:'
	@echo '   CP        = $(CP)'
	@echo '   RM        = $(RM)'
	@echo '   MKDIR_P   = $(MKDIR_P)'
	@echo '   DESTDIR   = $(DESTDIR)'
	@echo '   TL        = $(TL)'
	@echo '   TLFLAGS   = $(TLFLAGS)'
	@echo '   TLINCLUDE = $(TLINCLUDE)'
	@echo
	@echo 'Targets:'
	@echo '   all         Check and compile'
	@echo '   check       Type check files'
	@echo '   gen         Compile files (without type checking)'
	@echo '   help        Print this help'
	@echo '   clean       Delete generated files'
	@echo '   install     Check, compile, and copy to DESTDIR'
	@echo '   uninstall   Delete files from DESTDIR'
objdirs:
	@$(MKDIR_P) $(objdir)/cyan/commands
	@$(MKDIR_P) $(objdir)/spec/api
	@$(MKDIR_P) $(objdir)/spec/commands
	@$(MKDIR_P) $(objdir)/testing
installdirs:
	@$(MKDIR_P) $(DESTDIR)/cyan/commands
	@$(MKDIR_P) $(DESTDIR)/spec/api
	@$(MKDIR_P) $(DESTDIR)/spec/commands
	@$(MKDIR_P) $(DESTDIR)/testing
install: installdirs all
	@echo 'INSTALL $(DESTDIR)/testing/batch-assertion.lua'
	@$(CP) $(objdir)/testing/batch-assertion.lua $(DESTDIR)/testing/batch-assertion.lua
	@echo 'INSTALL $(DESTDIR)/cyan/util.lua'
	@$(CP) $(objdir)/cyan/util.lua $(DESTDIR)/cyan/util.lua
	@echo 'INSTALL $(DESTDIR)/cyan/sandbox.lua'
	@$(CP) $(objdir)/cyan/sandbox.lua $(DESTDIR)/cyan/sandbox.lua
	@echo 'INSTALL $(DESTDIR)/cyan/meta.lua'
	@$(CP) $(objdir)/cyan/meta.lua $(DESTDIR)/cyan/meta.lua
	@echo 'INSTALL $(DESTDIR)/testing/finally.lua'
	@$(CP) $(objdir)/testing/finally.lua $(DESTDIR)/testing/finally.lua
	@echo 'INSTALL $(DESTDIR)/spec/api/util_spec.lua'
	@$(CP) $(objdir)/spec/api/util_spec.lua $(DESTDIR)/spec/api/util_spec.lua
	@echo 'INSTALL $(DESTDIR)/spec/api/sandbox_spec.lua'
	@$(CP) $(objdir)/spec/api/sandbox_spec.lua $(DESTDIR)/spec/api/sandbox_spec.lua
	@echo 'INSTALL $(DESTDIR)/cyan/fs.lua'
	@$(CP) $(objdir)/cyan/fs.lua $(DESTDIR)/cyan/fs.lua
	@echo 'INSTALL $(DESTDIR)/testing/temporary-files.lua'
	@$(CP) $(objdir)/testing/temporary-files.lua $(DESTDIR)/testing/temporary-files.lua
	@echo 'INSTALL $(DESTDIR)/cyan/decoration.lua'
	@$(CP) $(objdir)/cyan/decoration.lua $(DESTDIR)/cyan/decoration.lua
	@echo 'INSTALL $(DESTDIR)/spec/api/decoration_spec.lua'
	@$(CP) $(objdir)/spec/api/decoration_spec.lua $(DESTDIR)/spec/api/decoration_spec.lua
	@echo 'INSTALL $(DESTDIR)/cyan/log.lua'
	@$(CP) $(objdir)/cyan/log.lua $(DESTDIR)/cyan/log.lua
	@echo 'INSTALL $(DESTDIR)/cyan/invocation-context.lua'
	@$(CP) $(objdir)/cyan/invocation-context.lua $(DESTDIR)/cyan/invocation-context.lua
	@echo 'INSTALL $(DESTDIR)/cyan/config.lua'
	@$(CP) $(objdir)/cyan/config.lua $(DESTDIR)/cyan/config.lua
	@echo 'INSTALL $(DESTDIR)/testing/command-runners.lua'
	@$(CP) $(objdir)/testing/command-runners.lua $(DESTDIR)/testing/command-runners.lua
	@echo 'INSTALL $(DESTDIR)/spec/api/config_spec.lua'
	@$(CP) $(objdir)/spec/api/config_spec.lua $(DESTDIR)/spec/api/config_spec.lua
	@echo 'INSTALL $(DESTDIR)/cyan/interaction.lua'
	@$(CP) $(objdir)/cyan/interaction.lua $(DESTDIR)/cyan/interaction.lua
	@echo 'INSTALL $(DESTDIR)/spec/commands/warnings_spec.lua'
	@$(CP) $(objdir)/spec/commands/warnings_spec.lua $(DESTDIR)/spec/commands/warnings_spec.lua
	@echo 'INSTALL $(DESTDIR)/spec/commands/run_spec.lua'
	@$(CP) $(objdir)/spec/commands/run_spec.lua $(DESTDIR)/spec/commands/run_spec.lua
	@echo 'INSTALL $(DESTDIR)/spec/commands/no_script_spec.lua'
	@$(CP) $(objdir)/spec/commands/no_script_spec.lua $(DESTDIR)/spec/commands/no_script_spec.lua
	@echo 'INSTALL $(DESTDIR)/spec/commands/init_spec.lua'
	@$(CP) $(objdir)/spec/commands/init_spec.lua $(DESTDIR)/spec/commands/init_spec.lua
	@echo 'INSTALL $(DESTDIR)/spec/commands/gen_spec.lua'
	@$(CP) $(objdir)/spec/commands/gen_spec.lua $(DESTDIR)/spec/commands/gen_spec.lua
	@echo 'INSTALL $(DESTDIR)/spec/commands/check_spec.lua'
	@$(CP) $(objdir)/spec/commands/check_spec.lua $(DESTDIR)/spec/commands/check_spec.lua
	@echo 'INSTALL $(DESTDIR)/spec/commands/build_spec.lua'
	@$(CP) $(objdir)/spec/commands/build_spec.lua $(DESTDIR)/spec/commands/build_spec.lua
	@echo 'INSTALL $(DESTDIR)/cyan/tlcommon.lua'
	@$(CP) $(objdir)/cyan/tlcommon.lua $(DESTDIR)/cyan/tlcommon.lua
	@echo 'INSTALL $(DESTDIR)/cyan/command.lua'
	@$(CP) $(objdir)/cyan/command.lua $(DESTDIR)/cyan/command.lua
	@echo 'INSTALL $(DESTDIR)/cyan/graph.lua'
	@$(CP) $(objdir)/cyan/graph.lua $(DESTDIR)/cyan/graph.lua
	@echo 'INSTALL $(DESTDIR)/cyan/commands/warnings.lua'
	@$(CP) $(objdir)/cyan/commands/warnings.lua $(DESTDIR)/cyan/commands/warnings.lua
	@echo 'INSTALL $(DESTDIR)/cyan/commands/initialize.lua'
	@$(CP) $(objdir)/cyan/commands/initialize.lua $(DESTDIR)/cyan/commands/initialize.lua
	@echo 'INSTALL $(DESTDIR)/cyan/script.lua'
	@$(CP) $(objdir)/cyan/script.lua $(DESTDIR)/cyan/script.lua
	@echo 'INSTALL $(DESTDIR)/cyan/commands/run.lua'
	@$(CP) $(objdir)/cyan/commands/run.lua $(DESTDIR)/cyan/commands/run.lua
	@echo 'INSTALL $(DESTDIR)/cyan/commands/check-gen.lua'
	@$(CP) $(objdir)/cyan/commands/check-gen.lua $(DESTDIR)/cyan/commands/check-gen.lua
	@echo 'INSTALL $(DESTDIR)/spec/api/graph_spec.lua'
	@$(CP) $(objdir)/spec/api/graph_spec.lua $(DESTDIR)/spec/api/graph_spec.lua
	@echo 'INSTALL $(DESTDIR)/cyan/commands/export.lua'
	@$(CP) $(objdir)/cyan/commands/export.lua $(DESTDIR)/cyan/commands/export.lua
	@echo 'INSTALL $(DESTDIR)/spec/api/script_spec.lua'
	@$(CP) $(objdir)/spec/api/script_spec.lua $(DESTDIR)/spec/api/script_spec.lua
	@echo 'INSTALL $(DESTDIR)/cyan/commands/build.lua'
	@$(CP) $(objdir)/cyan/commands/build.lua $(DESTDIR)/cyan/commands/build.lua
	@echo 'INSTALL $(DESTDIR)/cyan/cli.lua'
	@$(CP) $(objdir)/cyan/cli.lua $(DESTDIR)/cyan/cli.lua
uninstall:
	$(RM) -f $(DESTDIR)/testing/batch-assertion.lua $(DESTDIR)/cyan/util.lua $(DESTDIR)/cyan/sandbox.lua $(DESTDIR)/cyan/meta.lua $(DESTDIR)/testing/finally.lua $(DESTDIR)/spec/api/util_spec.lua $(DESTDIR)/spec/api/sandbox_spec.lua $(DESTDIR)/cyan/fs.lua $(DESTDIR)/testing/temporary-files.lua $(DESTDIR)/cyan/decoration.lua $(DESTDIR)/spec/api/decoration_spec.lua $(DESTDIR)/cyan/log.lua $(DESTDIR)/cyan/invocation-context.lua $(DESTDIR)/cyan/config.lua $(DESTDIR)/testing/command-runners.lua $(DESTDIR)/spec/api/config_spec.lua $(DESTDIR)/cyan/interaction.lua $(DESTDIR)/spec/commands/warnings_spec.lua $(DESTDIR)/spec/commands/run_spec.lua $(DESTDIR)/spec/commands/no_script_spec.lua $(DESTDIR)/spec/commands/init_spec.lua $(DESTDIR)/spec/commands/gen_spec.lua $(DESTDIR)/spec/commands/check_spec.lua $(DESTDIR)/spec/commands/build_spec.lua $(DESTDIR)/cyan/tlcommon.lua $(DESTDIR)/cyan/command.lua $(DESTDIR)/cyan/graph.lua $(DESTDIR)/cyan/commands/warnings.lua $(DESTDIR)/cyan/commands/initialize.lua $(DESTDIR)/cyan/script.lua $(DESTDIR)/cyan/commands/run.lua $(DESTDIR)/cyan/commands/check-gen.lua $(DESTDIR)/spec/api/graph_spec.lua $(DESTDIR)/cyan/commands/export.lua $(DESTDIR)/spec/api/script_spec.lua $(DESTDIR)/cyan/commands/build.lua $(DESTDIR)/cyan/cli.lua
clean:
	$(RM) -f $(OBJS) $(CHECKS)
$(objdir)/testing/batch-assertion.lua: $(srcdir)/testing/batch-assertion.tl
	@$(MKDIR_P) $(@D)
	@echo TL gen $<
	@$(TL) gen --no-check $(TLFLAGS) $(TLINCLUDE) $< -o $@
$(objdir)/testing/batch-assertion.tl.checked: $(srcdir)/testing/batch-assertion.tl
	@$(MKDIR_P) $(@D)
	@echo TL check $<
	@$(TL) check $(TLFLAGS) $(TLINCLUDE) $<
	@touch $@
$(objdir)/cyan/util.lua: $(srcdir)/cyan/util.tl
	@$(MKDIR_P) $(@D)
	@echo TL gen $<
	@$(TL) gen --no-check $(TLFLAGS) $(TLINCLUDE) $< -o $@
$(objdir)/cyan/util.tl.checked: $(srcdir)/cyan/util.tl
	@$(MKDIR_P) $(@D)
	@echo TL check $<
	@$(TL) check $(TLFLAGS) $(TLINCLUDE) $<
	@touch $@
$(objdir)/cyan/sandbox.lua: $(srcdir)/cyan/sandbox.tl
	@$(MKDIR_P) $(@D)
	@echo TL gen $<
	@$(TL) gen --no-check $(TLFLAGS) $(TLINCLUDE) $< -o $@
$(objdir)/cyan/sandbox.tl.checked: $(srcdir)/cyan/sandbox.tl
	@$(MKDIR_P) $(@D)
	@echo TL check $<
	@$(TL) check $(TLFLAGS) $(TLINCLUDE) $<
	@touch $@
$(objdir)/cyan/meta.lua: $(srcdir)/cyan/meta.tl
	@$(MKDIR_P) $(@D)
	@echo TL gen $<
	@$(TL) gen --no-check $(TLFLAGS) $(TLINCLUDE) $< -o $@
$(objdir)/cyan/meta.tl.checked: $(srcdir)/cyan/meta.tl
	@$(MKDIR_P) $(@D)
	@echo TL check $<
	@$(TL) check $(TLFLAGS) $(TLINCLUDE) $<
	@touch $@
$(objdir)/testing/finally.lua: $(srcdir)/testing/finally.tl
	@$(MKDIR_P) $(@D)
	@echo TL gen $<
	@$(TL) gen --no-check $(TLFLAGS) $(TLINCLUDE) $< -o $@
$(objdir)/testing/finally.tl.checked: $(srcdir)/testing/finally.tl $(objdir)/cyan/util.tl.checked
	@$(MKDIR_P) $(@D)
	@echo TL check $<
	@$(TL) check $(TLFLAGS) $(TLINCLUDE) $<
	@touch $@
$(objdir)/spec/api/util_spec.lua: $(srcdir)/spec/api/util_spec.tl
	@$(MKDIR_P) $(@D)
	@echo TL gen $<
	@$(TL) gen --no-check $(TLFLAGS) $(TLINCLUDE) $< -o $@
$(objdir)/spec/api/util_spec.tl.checked: $(srcdir)/spec/api/util_spec.tl $(objdir)/cyan/util.tl.checked
	@$(MKDIR_P) $(@D)
	@echo TL check $<
	@$(TL) check $(TLFLAGS) $(TLINCLUDE) $<
	@touch $@
$(objdir)/spec/api/sandbox_spec.lua: $(srcdir)/spec/api/sandbox_spec.tl
	@$(MKDIR_P) $(@D)
	@echo TL gen $<
	@$(TL) gen --no-check $(TLFLAGS) $(TLINCLUDE) $< -o $@
$(objdir)/spec/api/sandbox_spec.tl.checked: $(srcdir)/spec/api/sandbox_spec.tl $(objdir)/cyan/sandbox.tl.checked
	@$(MKDIR_P) $(@D)
	@echo TL check $<
	@$(TL) check $(TLFLAGS) $(TLINCLUDE) $<
	@touch $@
$(objdir)/cyan/fs.lua: $(srcdir)/cyan/fs.tl
	@$(MKDIR_P) $(@D)
	@echo TL gen $<
	@$(TL) gen --no-check $(TLFLAGS) $(TLINCLUDE) $< -o $@
$(objdir)/cyan/fs.tl.checked: $(srcdir)/cyan/fs.tl $(objdir)/cyan/util.tl.checked
	@$(MKDIR_P) $(@D)
	@echo TL check $<
	@$(TL) check $(TLFLAGS) $(TLINCLUDE) $<
	@touch $@
$(objdir)/testing/temporary-files.lua: $(srcdir)/testing/temporary-files.tl
	@$(MKDIR_P) $(@D)
	@echo TL gen $<
	@$(TL) gen --no-check $(TLFLAGS) $(TLINCLUDE) $< -o $@
$(objdir)/testing/temporary-files.tl.checked: $(srcdir)/testing/temporary-files.tl $(objdir)/testing/finally.tl.checked $(objdir)/cyan/util.tl.checked
	@$(MKDIR_P) $(@D)
	@echo TL check $<
	@$(TL) check $(TLFLAGS) $(TLINCLUDE) $<
	@touch $@
$(objdir)/cyan/decoration.lua: $(srcdir)/cyan/decoration.tl
	@$(MKDIR_P) $(@D)
	@echo TL gen $<
	@$(TL) gen --no-check $(TLFLAGS) $(TLINCLUDE) $< -o $@
$(objdir)/cyan/decoration.tl.checked: $(srcdir)/cyan/decoration.tl $(objdir)/cyan/util.tl.checked $(objdir)/cyan/fs.tl.checked
	@$(MKDIR_P) $(@D)
	@echo TL check $<
	@$(TL) check $(TLFLAGS) $(TLINCLUDE) $<
	@touch $@
$(objdir)/spec/api/decoration_spec.lua: $(srcdir)/spec/api/decoration_spec.tl
	@$(MKDIR_P) $(@D)
	@echo TL gen $<
	@$(TL) gen --no-check $(TLFLAGS) $(TLINCLUDE) $< -o $@
$(objdir)/spec/api/decoration_spec.tl.checked: $(srcdir)/spec/api/decoration_spec.tl $(objdir)/cyan/fs.tl.checked $(objdir)/cyan/decoration.tl.checked $(objdir)/cyan/util.tl.checked
	@$(MKDIR_P) $(@D)
	@echo TL check $<
	@$(TL) check $(TLFLAGS) $(TLINCLUDE) $<
	@touch $@
$(objdir)/cyan/log.lua: $(srcdir)/cyan/log.tl
	@$(MKDIR_P) $(@D)
	@echo TL gen $<
	@$(TL) gen --no-check $(TLFLAGS) $(TLINCLUDE) $< -o $@
$(objdir)/cyan/log.tl.checked: $(srcdir)/cyan/log.tl $(objdir)/cyan/fs.tl.checked $(objdir)/cyan/decoration.tl.checked $(objdir)/cyan/util.tl.checked
	@$(MKDIR_P) $(@D)
	@echo TL check $<
	@$(TL) check $(TLFLAGS) $(TLINCLUDE) $<
	@touch $@
$(objdir)/cyan/invocation-context.lua: $(srcdir)/cyan/invocation-context.tl
	@$(MKDIR_P) $(@D)
	@echo TL gen $<
	@$(TL) gen --no-check $(TLFLAGS) $(TLINCLUDE) $< -o $@
$(objdir)/cyan/invocation-context.tl.checked: $(srcdir)/cyan/invocation-context.tl $(objdir)/cyan/fs.tl.checked $(objdir)/cyan/decoration.tl.checked $(objdir)/cyan/util.tl.checked
	@$(MKDIR_P) $(@D)
	@echo TL check $<
	@$(TL) check $(TLFLAGS) $(TLINCLUDE) $<
	@touch $@
$(objdir)/cyan/config.lua: $(srcdir)/cyan/config.tl
	@$(MKDIR_P) $(@D)
	@echo TL gen $<
	@$(TL) gen --no-check $(TLFLAGS) $(TLINCLUDE) $< -o $@
$(objdir)/cyan/config.tl.checked: $(srcdir)/cyan/config.tl $(objdir)/cyan/fs.tl.checked $(objdir)/cyan/util.tl.checked $(objdir)/cyan/sandbox.tl.checked
	@$(MKDIR_P) $(@D)
	@echo TL check $<
	@$(TL) check $(TLFLAGS) $(TLINCLUDE) $<
	@touch $@
$(objdir)/testing/command-runners.lua: $(srcdir)/testing/command-runners.tl
	@$(MKDIR_P) $(@D)
	@echo TL gen $<
	@$(TL) gen --no-check $(TLFLAGS) $(TLINCLUDE) $< -o $@
$(objdir)/testing/command-runners.tl.checked: $(srcdir)/testing/command-runners.tl $(objdir)/testing/batch-assertion.tl.checked $(objdir)/testing/temporary-files.tl.checked $(objdir)/testing/finally.tl.checked $(objdir)/cyan/util.tl.checked
	@$(MKDIR_P) $(@D)
	@echo TL check $<
	@$(TL) check $(TLFLAGS) $(TLINCLUDE) $<
	@touch $@
$(objdir)/spec/api/config_spec.lua: $(srcdir)/spec/api/config_spec.tl
	@$(MKDIR_P) $(@D)
	@echo TL gen $<
	@$(TL) gen --no-check $(TLFLAGS) $(TLINCLUDE) $< -o $@
$(objdir)/spec/api/config_spec.tl.checked: $(srcdir)/spec/api/config_spec.tl $(objdir)/cyan/fs.tl.checked $(objdir)/cyan/config.tl.checked $(objdir)/cyan/util.tl.checked $(objdir)/cyan/sandbox.tl.checked
	@$(MKDIR_P) $(@D)
	@echo TL check $<
	@$(TL) check $(TLFLAGS) $(TLINCLUDE) $<
	@touch $@
$(objdir)/cyan/interaction.lua: $(srcdir)/cyan/interaction.tl
	@$(MKDIR_P) $(@D)
	@echo TL gen $<
	@$(TL) gen --no-check $(TLFLAGS) $(TLINCLUDE) $< -o $@
$(objdir)/cyan/interaction.tl.checked: $(srcdir)/cyan/interaction.tl $(objdir)/cyan/fs.tl.checked $(objdir)/cyan/decoration.tl.checked $(objdir)/cyan/util.tl.checked $(objdir)/cyan/log.tl.checked
	@$(MKDIR_P) $(@D)
	@echo TL check $<
	@$(TL) check $(TLFLAGS) $(TLINCLUDE) $<
	@touch $@
$(objdir)/spec/commands/warnings_spec.lua: $(srcdir)/spec/commands/warnings_spec.tl
	@$(MKDIR_P) $(@D)
	@echo TL gen $<
	@$(TL) gen --no-check $(TLFLAGS) $(TLINCLUDE) $< -o $@
$(objdir)/spec/commands/warnings_spec.tl.checked: $(srcdir)/spec/commands/warnings_spec.tl $(objdir)/testing/finally.tl.checked $(objdir)/testing/command-runners.tl.checked $(objdir)/testing/batch-assertion.tl.checked $(objdir)/cyan/util.tl.checked $(objdir)/testing/temporary-files.tl.checked
	@$(MKDIR_P) $(@D)
	@echo TL check $<
	@$(TL) check $(TLFLAGS) $(TLINCLUDE) $<
	@touch $@
$(objdir)/spec/commands/run_spec.lua: $(srcdir)/spec/commands/run_spec.tl
	@$(MKDIR_P) $(@D)
	@echo TL gen $<
	@$(TL) gen --no-check $(TLFLAGS) $(TLINCLUDE) $< -o $@
$(objdir)/spec/commands/run_spec.tl.checked: $(srcdir)/spec/commands/run_spec.tl $(objdir)/testing/finally.tl.checked $(objdir)/testing/command-runners.tl.checked $(objdir)/testing/batch-assertion.tl.checked $(objdir)/cyan/util.tl.checked $(objdir)/testing/temporary-files.tl.checked
	@$(MKDIR_P) $(@D)
	@echo TL check $<
	@$(TL) check $(TLFLAGS) $(TLINCLUDE) $<
	@touch $@
$(objdir)/spec/commands/no_script_spec.lua: $(srcdir)/spec/commands/no_script_spec.tl
	@$(MKDIR_P) $(@D)
	@echo TL gen $<
	@$(TL) gen --no-check $(TLFLAGS) $(TLINCLUDE) $< -o $@
$(objdir)/spec/commands/no_script_spec.tl.checked: $(srcdir)/spec/commands/no_script_spec.tl $(objdir)/testing/finally.tl.checked $(objdir)/testing/command-runners.tl.checked $(objdir)/testing/batch-assertion.tl.checked $(objdir)/cyan/util.tl.checked $(objdir)/testing/temporary-files.tl.checked
	@$(MKDIR_P) $(@D)
	@echo TL check $<
	@$(TL) check $(TLFLAGS) $(TLINCLUDE) $<
	@touch $@
$(objdir)/spec/commands/init_spec.lua: $(srcdir)/spec/commands/init_spec.tl
	@$(MKDIR_P) $(@D)
	@echo TL gen $<
	@$(TL) gen --no-check $(TLFLAGS) $(TLINCLUDE) $< -o $@
$(objdir)/spec/commands/init_spec.tl.checked: $(srcdir)/spec/commands/init_spec.tl $(objdir)/testing/finally.tl.checked $(objdir)/testing/command-runners.tl.checked $(objdir)/testing/batch-assertion.tl.checked $(objdir)/cyan/util.tl.checked $(objdir)/testing/temporary-files.tl.checked
	@$(MKDIR_P) $(@D)
	@echo TL check $<
	@$(TL) check $(TLFLAGS) $(TLINCLUDE) $<
	@touch $@
$(objdir)/spec/commands/gen_spec.lua: $(srcdir)/spec/commands/gen_spec.tl
	@$(MKDIR_P) $(@D)
	@echo TL gen $<
	@$(TL) gen --no-check $(TLFLAGS) $(TLINCLUDE) $< -o $@
$(objdir)/spec/commands/gen_spec.tl.checked: $(srcdir)/spec/commands/gen_spec.tl $(objdir)/testing/finally.tl.checked $(objdir)/testing/command-runners.tl.checked $(objdir)/testing/batch-assertion.tl.checked $(objdir)/cyan/util.tl.checked $(objdir)/testing/temporary-files.tl.checked
	@$(MKDIR_P) $(@D)
	@echo TL check $<
	@$(TL) check $(TLFLAGS) $(TLINCLUDE) $<
	@touch $@
$(objdir)/spec/commands/check_spec.lua: $(srcdir)/spec/commands/check_spec.tl
	@$(MKDIR_P) $(@D)
	@echo TL gen $<
	@$(TL) gen --no-check $(TLFLAGS) $(TLINCLUDE) $< -o $@
$(objdir)/spec/commands/check_spec.tl.checked: $(srcdir)/spec/commands/check_spec.tl $(objdir)/testing/finally.tl.checked $(objdir)/testing/command-runners.tl.checked $(objdir)/testing/batch-assertion.tl.checked $(objdir)/cyan/util.tl.checked $(objdir)/testing/temporary-files.tl.checked
	@$(MKDIR_P) $(@D)
	@echo TL check $<
	@$(TL) check $(TLFLAGS) $(TLINCLUDE) $<
	@touch $@
$(objdir)/spec/commands/build_spec.lua: $(srcdir)/spec/commands/build_spec.tl
	@$(MKDIR_P) $(@D)
	@echo TL gen $<
	@$(TL) gen --no-check $(TLFLAGS) $(TLINCLUDE) $< -o $@
$(objdir)/spec/commands/build_spec.tl.checked: $(srcdir)/spec/commands/build_spec.tl $(objdir)/testing/finally.tl.checked $(objdir)/testing/command-runners.tl.checked $(objdir)/testing/batch-assertion.tl.checked $(objdir)/cyan/util.tl.checked $(objdir)/testing/temporary-files.tl.checked
	@$(MKDIR_P) $(@D)
	@echo TL check $<
	@$(TL) check $(TLFLAGS) $(TLINCLUDE) $<
	@touch $@
$(objdir)/cyan/tlcommon.lua: $(srcdir)/cyan/tlcommon.tl
	@$(MKDIR_P) $(@D)
	@echo TL gen $<
	@$(TL) gen --no-check $(TLFLAGS) $(TLINCLUDE) $< -o $@
$(objdir)/cyan/tlcommon.tl.checked: $(srcdir)/cyan/tlcommon.tl $(objdir)/cyan/decoration.tl.checked $(objdir)/cyan/config.tl.checked $(objdir)/cyan/log.tl.checked $(objdir)/cyan/fs.tl.checked $(objdir)/cyan/util.tl.checked $(objdir)/cyan/sandbox.tl.checked
	@$(MKDIR_P) $(@D)
	@echo TL check $<
	@$(TL) check $(TLFLAGS) $(TLINCLUDE) $<
	@touch $@
$(objdir)/cyan/command.lua: $(srcdir)/cyan/command.tl
	@$(MKDIR_P) $(@D)
	@echo TL gen $<
	@$(TL) gen --no-check $(TLFLAGS) $(TLINCLUDE) $< -o $@
$(objdir)/cyan/command.tl.checked: $(srcdir)/cyan/command.tl $(objdir)/cyan/decoration.tl.checked $(objdir)/cyan/invocation-context.tl.checked $(objdir)/cyan/sandbox.tl.checked $(objdir)/cyan/fs.tl.checked $(objdir)/cyan/util.tl.checked $(objdir)/cyan/config.tl.checked
	@$(MKDIR_P) $(@D)
	@echo TL check $<
	@$(TL) check $(TLFLAGS) $(TLINCLUDE) $<
	@touch $@
$(objdir)/cyan/graph.lua: $(srcdir)/cyan/graph.tl
	@$(MKDIR_P) $(@D)
	@echo TL gen $<
	@$(TL) gen --no-check $(TLFLAGS) $(TLINCLUDE) $< -o $@
$(objdir)/cyan/graph.tl.checked: $(srcdir)/cyan/graph.tl $(objdir)/cyan/decoration.tl.checked $(objdir)/cyan/config.tl.checked $(objdir)/cyan/tlcommon.tl.checked $(objdir)/cyan/log.tl.checked $(objdir)/cyan/fs.tl.checked $(objdir)/cyan/util.tl.checked $(objdir)/cyan/sandbox.tl.checked
	@$(MKDIR_P) $(@D)
	@echo TL check $<
	@$(TL) check $(TLFLAGS) $(TLINCLUDE) $<
	@touch $@
$(objdir)/cyan/commands/warnings.lua: $(srcdir)/cyan/commands/warnings.tl
	@$(MKDIR_P) $(@D)
	@echo TL gen $<
	@$(TL) gen --no-check $(TLFLAGS) $(TLINCLUDE) $< -o $@
$(objdir)/cyan/commands/warnings.tl.checked: $(srcdir)/cyan/commands/warnings.tl $(objdir)/cyan/decoration.tl.checked $(objdir)/cyan/invocation-context.tl.checked $(objdir)/cyan/log.tl.checked $(objdir)/cyan/command.tl.checked $(objdir)/cyan/sandbox.tl.checked $(objdir)/cyan/fs.tl.checked $(objdir)/cyan/util.tl.checked $(objdir)/cyan/config.tl.checked
	@$(MKDIR_P) $(@D)
	@echo TL check $<
	@$(TL) check $(TLFLAGS) $(TLINCLUDE) $<
	@touch $@
$(objdir)/cyan/commands/initialize.lua: $(srcdir)/cyan/commands/initialize.tl
	@$(MKDIR_P) $(@D)
	@echo TL gen $<
	@$(TL) gen --no-check $(TLFLAGS) $(TLINCLUDE) $< -o $@
$(objdir)/cyan/commands/initialize.tl.checked: $(srcdir)/cyan/commands/initialize.tl $(objdir)/cyan/decoration.tl.checked $(objdir)/cyan/invocation-context.tl.checked $(objdir)/cyan/log.tl.checked $(objdir)/cyan/command.tl.checked $(objdir)/cyan/sandbox.tl.checked $(objdir)/cyan/fs.tl.checked $(objdir)/cyan/util.tl.checked $(objdir)/cyan/config.tl.checked
	@$(MKDIR_P) $(@D)
	@echo TL check $<
	@$(TL) check $(TLFLAGS) $(TLINCLUDE) $<
	@touch $@
$(objdir)/cyan/script.lua: $(srcdir)/cyan/script.tl
	@$(MKDIR_P) $(@D)
	@echo TL gen $<
	@$(TL) gen --no-check $(TLFLAGS) $(TLINCLUDE) $< -o $@
$(objdir)/cyan/script.tl.checked: $(srcdir)/cyan/script.tl $(objdir)/cyan/invocation-context.tl.checked $(objdir)/cyan/log.tl.checked $(objdir)/cyan/fs.tl.checked $(objdir)/cyan/command.tl.checked $(objdir)/cyan/util.tl.checked $(objdir)/cyan/decoration.tl.checked $(objdir)/cyan/sandbox.tl.checked $(objdir)/cyan/meta.tl.checked $(objdir)/cyan/config.tl.checked
	@$(MKDIR_P) $(@D)
	@echo TL check $<
	@$(TL) check $(TLFLAGS) $(TLINCLUDE) $<
	@touch $@
$(objdir)/cyan/commands/run.lua: $(srcdir)/cyan/commands/run.tl
	@$(MKDIR_P) $(@D)
	@echo TL gen $<
	@$(TL) gen --no-check $(TLFLAGS) $(TLINCLUDE) $< -o $@
$(objdir)/cyan/commands/run.tl.checked: $(srcdir)/cyan/commands/run.tl $(objdir)/cyan/invocation-context.tl.checked $(objdir)/cyan/log.tl.checked $(objdir)/cyan/fs.tl.checked $(objdir)/cyan/command.tl.checked $(objdir)/cyan/util.tl.checked $(objdir)/cyan/decoration.tl.checked $(objdir)/cyan/sandbox.tl.checked $(objdir)/cyan/tlcommon.tl.checked $(objdir)/cyan/config.tl.checked
	@$(MKDIR_P) $(@D)
	@echo TL check $<
	@$(TL) check $(TLFLAGS) $(TLINCLUDE) $<
	@touch $@
$(objdir)/cyan/commands/check-gen.lua: $(srcdir)/cyan/commands/check-gen.tl
	@$(MKDIR_P) $(@D)
	@echo TL gen $<
	@$(TL) gen --no-check $(TLFLAGS) $(TLINCLUDE) $< -o $@
$(objdir)/cyan/commands/check-gen.tl.checked: $(srcdir)/cyan/commands/check-gen.tl $(objdir)/cyan/invocation-context.tl.checked $(objdir)/cyan/log.tl.checked $(objdir)/cyan/fs.tl.checked $(objdir)/cyan/command.tl.checked $(objdir)/cyan/util.tl.checked $(objdir)/cyan/decoration.tl.checked $(objdir)/cyan/sandbox.tl.checked $(objdir)/cyan/tlcommon.tl.checked $(objdir)/cyan/config.tl.checked
	@$(MKDIR_P) $(@D)
	@echo TL check $<
	@$(TL) check $(TLFLAGS) $(TLINCLUDE) $<
	@touch $@
$(objdir)/spec/api/graph_spec.lua: $(srcdir)/spec/api/graph_spec.tl
	@$(MKDIR_P) $(@D)
	@echo TL gen $<
	@$(TL) gen --no-check $(TLFLAGS) $(TLINCLUDE) $< -o $@
$(objdir)/spec/api/graph_spec.tl.checked: $(srcdir)/spec/api/graph_spec.tl $(objdir)/cyan/graph.tl.checked $(objdir)/cyan/log.tl.checked $(objdir)/cyan/fs.tl.checked $(objdir)/cyan/config.tl.checked $(objdir)/cyan/util.tl.checked $(objdir)/cyan/decoration.tl.checked $(objdir)/testing/finally.tl.checked $(objdir)/cyan/sandbox.tl.checked $(objdir)/cyan/tlcommon.tl.checked $(objdir)/testing/temporary-files.tl.checked
	@$(MKDIR_P) $(@D)
	@echo TL check $<
	@$(TL) check $(TLFLAGS) $(TLINCLUDE) $<
	@touch $@
$(objdir)/cyan/commands/export.lua: $(srcdir)/cyan/commands/export.tl
	@$(MKDIR_P) $(@D)
	@echo TL gen $<
	@$(TL) gen --no-check $(TLFLAGS) $(TLINCLUDE) $< -o $@
$(objdir)/cyan/commands/export.tl.checked: $(srcdir)/cyan/commands/export.tl $(objdir)/cyan/invocation-context.tl.checked $(objdir)/cyan/graph.tl.checked $(objdir)/cyan/log.tl.checked $(objdir)/cyan/fs.tl.checked $(objdir)/cyan/command.tl.checked $(objdir)/cyan/util.tl.checked $(objdir)/cyan/decoration.tl.checked $(objdir)/cyan/sandbox.tl.checked $(objdir)/cyan/tlcommon.tl.checked $(objdir)/cyan/config.tl.checked
	@$(MKDIR_P) $(@D)
	@echo TL check $<
	@$(TL) check $(TLFLAGS) $(TLINCLUDE) $<
	@touch $@
$(objdir)/spec/api/script_spec.lua: $(srcdir)/spec/api/script_spec.tl
	@$(MKDIR_P) $(@D)
	@echo TL gen $<
	@$(TL) gen --no-check $(TLFLAGS) $(TLINCLUDE) $< -o $@
$(objdir)/spec/api/script_spec.tl.checked: $(srcdir)/spec/api/script_spec.tl $(objdir)/cyan/invocation-context.tl.checked $(objdir)/cyan/log.tl.checked $(objdir)/cyan/script.tl.checked $(objdir)/cyan/command.tl.checked $(objdir)/cyan/util.tl.checked $(objdir)/cyan/decoration.tl.checked $(objdir)/testing/finally.tl.checked $(objdir)/cyan/sandbox.tl.checked $(objdir)/cyan/meta.tl.checked $(objdir)/testing/temporary-files.tl.checked $(objdir)/cyan/config.tl.checked $(objdir)/cyan/fs.tl.checked
	@$(MKDIR_P) $(@D)
	@echo TL check $<
	@$(TL) check $(TLFLAGS) $(TLINCLUDE) $<
	@touch $@
$(objdir)/cyan/commands/build.lua: $(srcdir)/cyan/commands/build.tl
	@$(MKDIR_P) $(@D)
	@echo TL gen $<
	@$(TL) gen --no-check $(TLFLAGS) $(TLINCLUDE) $< -o $@
$(objdir)/cyan/commands/build.tl.checked: $(srcdir)/cyan/commands/build.tl $(objdir)/cyan/invocation-context.tl.checked $(objdir)/cyan/graph.tl.checked $(objdir)/cyan/log.tl.checked $(objdir)/cyan/script.tl.checked $(objdir)/cyan/config.tl.checked $(objdir)/cyan/util.tl.checked $(objdir)/cyan/decoration.tl.checked $(objdir)/cyan/sandbox.tl.checked $(objdir)/cyan/tlcommon.tl.checked $(objdir)/cyan/meta.tl.checked $(objdir)/cyan/command.tl.checked $(objdir)/cyan/fs.tl.checked
	@$(MKDIR_P) $(@D)
	@echo TL check $<
	@$(TL) check $(TLFLAGS) $(TLINCLUDE) $<
	@touch $@
$(objdir)/cyan/cli.lua: $(srcdir)/cyan/cli.tl
	@$(MKDIR_P) $(@D)
	@echo TL gen $<
	@$(TL) gen --no-check $(TLFLAGS) $(TLINCLUDE) $< -o $@
$(objdir)/cyan/cli.tl.checked: $(srcdir)/cyan/cli.tl $(objdir)/cyan/util.tl.checked $(objdir)/cyan/sandbox.tl.checked $(objdir)/cyan/commands/build.tl.checked $(objdir)/cyan/commands/check-gen.tl.checked $(objdir)/cyan/commands/run.tl.checked $(objdir)/cyan/tlcommon.tl.checked $(objdir)/cyan/fs.tl.checked $(objdir)/cyan/decoration.tl.checked $(objdir)/cyan/script.tl.checked $(objdir)/cyan/commands/export.tl.checked $(objdir)/cyan/invocation-context.tl.checked $(objdir)/cyan/command.tl.checked $(objdir)/cyan/commands/initialize.tl.checked $(objdir)/cyan/config.tl.checked $(objdir)/cyan/log.tl.checked $(objdir)/cyan/commands/warnings.tl.checked $(objdir)/cyan/graph.tl.checked $(objdir)/cyan/meta.tl.checked
	@$(MKDIR_P) $(@D)
	@echo TL check $<
	@$(TL) check $(TLFLAGS) $(TLINCLUDE) $<
	@touch $@
