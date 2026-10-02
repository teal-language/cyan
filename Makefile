.POSIX:
.DEFAULT: all

-include deps.mk

TL = lua_modules/bin/tl

LUAROCKS_WRAPPER_DIR = .lrw
LUA = $(LUAROCKS_WRAPPER_DIR)/lua
LUAROCKS = $(LUAROCKS_WRAPPER_DIR)/luarocks

luarocks: $(LUAROCKS) $(LUA)
$(LUAROCKS) $(LUA):
	mkdir -p $(LUAROCKS_WRAPPER_DIR)
	luarocks init --wrapper-dir $(LUAROCKS_WRAPPER_DIR) --local
install-dependencies: $(LUAROCKS)
	$(LUAROCKS) install inspect
	$(LUAROCKS) install ltreesitter
	$(LUAROCKS) install tl --dev
	$(LUAROCKS) install --deps-only cyan-dev-1.rockspec

BOOTSTRAP1 = $(LUA) bin/bootstrap --no-script
BOOTSTRAP2 = $(LUA) bin/bootstrap --no-script
BOOTSTRAP3 = $(LUA) bin/bootstrap --no-script

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

test: all $(LUA)
	busted build/ --lua=$(LUA)

CYAN = LUA_PATH="build/?.lua;build/?/init.lua;$$LUA_PATH" $(LUA) bin/cyan

lint: scripts/lint.tl $(TL_FILES)
	@echo CYAN run $<
	@$(CYAN) run $<
docs/index.html: scripts/gen_documentation.tl $(TL_FILES) doc-template.html
	@echo CYAN run $<
	@$(CYAN) run $<
cyan-dev-1.rockspec: scripts/gen_rockspec.tl src | cyan
	@echo CYAN run $<
	@$(CYAN) run $<

rockspec: cyan-dev-1.rockspec
docs: docs/index.html

.PHONY: rockspec docs lint test
