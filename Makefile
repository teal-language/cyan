
SRC = \
      $(wildcard src/cyan/*.tl) \
      $(wildcard src/cyan/*/*.tl) \
      $(wildcard src/spec/*.tl) \
      $(wildcard src/spec/*/*.tl) \
      $(wildcard src/testing/*.tl)
LUA = $(SRC:src/%.tl=build/%.lua)

TL = tl
TLFLAGS = --quiet -I src
BOOTSTRAP1= bin/bootstrap --no-script
BOOTSTRAP2= bin/bootstrap --no-script
BOOTSTRAP3= bin/bootstrap --no-script

build/%.lua: src/%.tl
	$(TL) $(TLFLAGS) gen --check $< -o $@

default: cyan rockspec
cyan: build_directories $(LUA)

build_directories:
	mkdir -p build/cyan/{fs,commands,experimental} build/spec/{api,commands} build/testing

all: clean bootstrap docs rockspec test

clean:
	rm -rf build tmp docs/index.html cyan-dev-1.rockspec

bootstrap: build/cyan/fs build/cyan/experimental build/cyan/commands $(LUA)
	@echo "Initial build"
	$(BOOTSTRAP1) build
	@echo "Replacing code"
	rm -rf build
	mv tmp build
	@echo "Building with self compiled code"
	$(BOOTSTRAP2) build
	@echo "Replacing code"
	rm -rf build
	mv tmp build
	@echo "Final build with self compiled code"
	$(BOOTSTRAP3) build
	rm -rf build
	mv tmp build

test: default
	busted build/

lint: default
	./bin/cyan run scripts/lint.tl

docs: docs/index.html
rockspec: cyan-dev-1.rockspec

docs/index.html: $(SRC) cyan scripts/gen_documentation.tl doc-template.html
	./bin/cyan run scripts/gen_documentation.tl

cyan-dev-1.rockspec: $(SRC) scripts/gen_rockspec.tl
	./bin/cyan run scripts/gen_rockspec.tl

.PHONY: clean
