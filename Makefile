default: cyan rockspec

LUAROCKS_WRAPPER_DIR=.luarocks-wrapper
LUA=$(LUAROCKS_WRAPPER_DIR)/lua
LUAROCKS=$(LUAROCKS_WRAPPER_DIR)/luarocks

TL_COMPILER = lua_modules/bin/tl
TL_FLAGS = --quiet -I src

build/%.lua.checked: src/%.tl
	@echo TL check $<
	@$(TL_COMPILER) $(TL_FLAGS) check $<
	@touch $@

build/%.lua: src/%.tl | build/%.lua.checked
	@echo TL gen $<
	@$(TL_COMPILER) $(TL_FLAGS) gen --no-check $< -o $@

include deps.mk

BOOTSTRAP1 = $(LUA) bin/bootstrap --no-script
BOOTSTRAP2 = $(LUA) bin/bootstrap --no-script
BOOTSTRAP3 = $(LUA) bin/bootstrap --no-script

cyan: $(LUA_FILES) $(CHECKS)

$(LUAROCKS) $(LUA):
	mkdir -p $(LUAROCKS_WRAPPER_DIR)
	luarocks init --wrapper-dir $(LUAROCKS_WRAPPER_DIR) --local

install-dependencies: $(LUAROCKS)
	$(LUAROCKS) install inspect
	$(LUAROCKS) install ltreesitter
	$(LUAROCKS) install tl --dev
	$(LUAROCKS) install --deps-only cyan-dev-1.rockspec

all: clean install-dependencies bootstrap docs rockspec test

clean:
	rm -rf build tmp docs/index.html cyan-dev-1.rockspec

bootstrap: $(LUA_FILES)
	@echo "Initial build"
	$(BOOTSTRAP1) build
	@echo "Replacing code"
	@rm -rf build
	@mv tmp build
	@echo "Building with self compiled code"
	$(BOOTSTRAP2) build
	@echo "Replacing code"
	@rm -rf build
	@mv tmp build
	@echo "Final build with self compiled code"
	$(BOOTSTRAP3) build
	@rm -rf build
	@mv tmp build

test: default $(LUA)
	busted build/ --lua=$(LUA)

CYAN = LUA_PATH="build/?.lua;build/?/init.lua;$$LUA_PATH" $(LUA) bin/cyan

docs: docs/index.html
rockspec: cyan-dev-1.rockspec

cyan-run-%: scripts/%.tl cyan $(TL_FILES)
	@echo CYAN run $<
	@$(CYAN) run $<

lint: default cyan-run-lint
docs/index.html: $(TL_FILES) cyan-run-gen_documentation doc-template.html
cyan-dev-1.rockspec: $(TL_FILES) cyan-run-gen_rockspec
makefile_deps: $(TL_FILES) cyan-run-gen_makefile_deps

.PHONY: clean cyan
