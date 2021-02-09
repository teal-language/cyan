
# TODO: This is super slow garbage since we cant preserve all the setup that tl does inbetween invocations
#       So rewrite this in lua... later

SRC = $(wildcard teal-cli/*.tl) $(wildcard teal-cli/*/*.tl)
LUA = $(SRC:%.tl=build/%.lua)

TL = tl
TLFLAGS = --quiet

build/%.lua: %.tl
	$(TL) $(TLFLAGS) check $<
	$(TL) $(TLFLAGS) gen $< -o $@

default: $(LUA)

all: clean default

clean:
	rm -rf build
	mkdir -p build/teal-cli/fs build/teal-cli/commands

.PHONY: clean
