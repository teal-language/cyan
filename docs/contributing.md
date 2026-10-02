# Cyan contribution guide

Make sure to take a glance at the [code of conduct](../CODE_OF_CONDUCT.md) before opening an issue/pr.

## Compiling
This project has a `Makefile`. Use it.
 - `make`: use `tl gen --check` to compile each source file
 - `make bootstrap`: `make`, then see if `cyan` can compile itself properly
 - `make test`: run the test suite

There are additional binaries in the `bin` folder that don't get installed and are just used for development.
 - `local-cyan`: use `tl.loader()` to compile `cyan` on the fly - use this for more rapid development and small tweaks
 - `bootstrap`: similar to `cyan`, just alters the path so the makefile knows where to find the built code to use for bootstrapping

### Warnings + Warning Errors
Cyan has `unused` and `redeclaration` promoted to errors since these type of warnings are arguably the most common and a large source of bugs. So it should not compile while there are any of these. Furthermore, ideally any pull requests should not have any warnings.

## Style guide

Cyan (mostly) follows the [Luarocks Style guide](https://github.com/luarocks/lua-style-guide), with some extensions to accomodate Teal's extra features. See [the style-guide for details](./style-guide.md)

## Testing
Cyan uses [busted](https://olivinelabs.com/busted/) for testing. Currently the test suite only runs on \*nix. (Hopefully we will have a more portable solution to how we run tests soon)

## Documentation Generation
The Api documentation is generated using the [ltreesitter module](https://github.com/euclidianAce/ltreesitter) along with [tree-sitter-teal](https://github.com/euclidianAce/tree-sitter-teal) via the [`docgen.tl` script](../scripts/docgen.tl)

