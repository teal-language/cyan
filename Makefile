default: cyan rockspec

LUAROCKS_WRAPPER_DIR=.luarocks-wrapper
LUA=$(LUAROCKS_WRAPPER_DIR)/lua
LUAROCKS=$(LUAROCKS_WRAPPER_DIR)/luarocks

TL_COMPILER = lua_modules/bin/tl
TL_FLAGS = --quiet -I src

build/%.lua: src/%.tl
	@echo TL $<
	@$(TL_COMPILER) $(TL_FLAGS) gen --check $< -o $@

include deps.mk

BOOTSTRAP1 = bin/bootstrap --no-script
BOOTSTRAP2 = bin/bootstrap --no-script
BOOTSTRAP3 = bin/bootstrap --no-script

cyan: $(LUA_FILES)

$(LUAROCKS) $(LUA):
	mkdir -p $(LUAROCKS_WRAPPER_DIR)
	luarocks init --wrapper-dir $(LUAROCKS_WRAPPER_DIR) --local

deps: $(LUAROCKS)
	$(LUAROCKS) install inspect
	$(LUAROCKS) install --deps-only cyan-dev-1.rockspec

all: clean deps bootstrap docs rockspec test

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

lint: default
	bin/cyan run scripts/lint.tl

docs: docs/index.html
rockspec: cyan-dev-1.rockspec

docs/index.html: $(TL_FILES) cyan scripts/gen_documentation.tl doc-template.html
	bin/cyan run scripts/gen_documentation.tl

cyan-dev-1.rockspec: $(TL_FILES) cyan scripts/gen_rockspec.tl
	bin/cyan run scripts/gen_rockspec.tl

.PHONY: clean
