
SRC = $(wildcard teal-cli/*.tl) $(wildcard teal-cli/*/*.tl)
LUA = $(SRC:%.tl=build/%.lua)

TL = ${OLD_TL}
TLFLAGS = --quiet

build/%.lua: %.tl
	$(TL) $(TLFLAGS) check $<
	$(TL) $(TLFLAGS) gen $< -o $@

default: $(LUA)

all: clean default

clean:
	rm -rf build tmp
	mkdir -p build/teal-cli/fs build/teal-cli/commands

bootstrap: default
	@echo "Initial build"
	bin/bootstrap-tl build
	@echo "Replacing code"
	rm -rf build
	mv tmp build
	@echo "Building with self compiled code"
	bin/bootstrap-tl build
	@echo "Replacing code"
	rm -rf build
	mv tmp build
	@echo "Final build with self compiled code"
	bin/bootstrap-tl build
	rm -rf build
	mv tmp build
	busted

.PHONY: clean
