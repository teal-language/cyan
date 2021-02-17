
SRC = $(wildcard charon/*.tl) $(wildcard charon/*/*.tl)
LUA = $(SRC:%.tl=build/%.lua)

TL = tl
TLFLAGS = --quiet

build/%.lua: %.tl
	$(TL) $(TLFLAGS) check $<
	$(TL) $(TLFLAGS) gen $< -o $@

default: $(LUA)

all: clean default

clean:
	rm -rf build tmp
	mkdir -p build/charon/fs build/charon/commands

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

.PHONY: clean
