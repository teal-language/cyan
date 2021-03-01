
SRC = $(wildcard src/cyan/*.tl) $(wildcard src/cyan/*/*.tl)
LUA = $(SRC:src/%.tl=build/%.lua)

TL = tl
TLFLAGS = --quiet -I src
BOOTSTRAPPER = bin/bootstrap

build/%.lua: src/%.tl
	$(TL) $(TLFLAGS) gen --check $< -o $@

default: $(LUA)

all: clean default

clean:
	rm -rf build tmp
	mkdir -p build/cyan/fs build/cyan/commands

bootstrap: default
	@echo "Initial build"
	$(BOOTSTRAPPER) build
	@echo "Replacing code"
	rm -rf build
	mv tmp build
	@echo "Building with self compiled code"
	$(BOOTSTRAPPER) build
	@echo "Replacing code"
	rm -rf build
	mv tmp build
	@echo "Final build with self compiled code"
	$(BOOTSTRAPPER) build
	rm -rf build
	mv tmp build
	busted

test: default
	busted

.PHONY: clean
