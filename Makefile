
SRC = $(wildcard src/cyan/*.tl) $(wildcard src/cyan/*/*.tl)
LUA = $(SRC:src/%.tl=build/%.lua)

TL = tl
TLFLAGS = --quiet -I src

build/%.lua: src/%.tl
	$(TL) $(TLFLAGS) check $< && $(TL) $(TLFLAGS) gen $< -o $@

default: $(LUA)

all: clean default

clean:
	rm -rf build tmp
	mkdir -p build/cyan/fs build/cyan/commands

bootstrap: default
	@echo "Initial build"
	bin/bootstrap build
	@echo "Replacing code"
	rm -rf build
	mv tmp build
	@echo "Building with self compiled code"
	bin/bootstrap build
	@echo "Replacing code"
	rm -rf build
	mv tmp build
	@echo "Final build with self compiled code"
	bin/bootstrap build
	rm -rf build
	mv tmp build
	busted

test: default
	busted

.PHONY: clean
