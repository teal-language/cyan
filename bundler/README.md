# Bundler

The contents of this directory are concerned with bundling `cyan`, its
dependencies (`argparse`, `luafilesystem`, etc.), and the lua interpreter into
a single executable for ease of installation.

We use [Zig's build system](https://ziglang.org/learn/build-system/) as Zig
provides static binaries and makes cross-compilation trivial.

A basic outline of the `build.zig`:

 - The (pinned) dependencies are fetched
 - The Lua interpreter is built, with our C dependencies baked in (luafilesystem and luasystem)
 - `aggregate.tl` is compiled and run to produce `aggregate.c`, which
   contains the compiled bytecode of cyan and its lua dependencies (via
   `string.dump`) and the entry point
 - The executable is built for the specified target
