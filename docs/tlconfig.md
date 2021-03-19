# tlconfig.lua

This file describes the layout of your project by returning a table with the following fields:

| Name               | CLI Flag             | Type               | Description |
| ------------------ | -------------------- | ------------------ | ----------- |
| `build_dir`        |                      | `string`           | Where to put generated files |
| `disable_warnings` | `--wdisable`         | `{tl.WarningKind}` | Disable the provided warnings |
| `exclude`          |                      | `{string}`         | A list of [patterns](#Patterns) describing what files to exclude |
| `externals`        |                      | `{any:any}`        | Entry for external tooling to use, unused by cyan itself |
| `gen_compat`       | `--gen-compat`       | `tl.CompatMode`    | Generate compatability code for different Lua versions |
| `gen_target`       | `--gen-target`       | `tl.TargetMode`    | Minimum Lua version for generated code. One of `5.1` or `5.3` |
| `include_dir`      | `-I` `--include-dir` | `{string}`         | Add each path provided to `package.path` and `package.cpath` |
| `include`          |                      | `{string}`         | A list of [patterns](#Patterns) describing what files to include |
| `module_name`      |                      | `string`           | Replace `module_name` with `source_dir` in `require` calls |
| `preload_modules`  | `-preload`           | `{string}`         | Execute the equivalent of `require(<module>)` for each provided name |
| `scripts`          |                      | `{string}`         | A list of filenames to run as [scripts](#Scripts) |
| `source_dir`       |                      | `string`           | Where to find source files |
| `warning_error`    | `--werror`           | `{tl.WarningKind}` | Promote the provided warnings to errors |
|                    | `-q` `--quiet`       |                    | Do not print info to stdout. Errors may still be printed to stderr |

## Patterns

The `include` and `exclude` fields can have glob-like patterns in them:
- `*`: Matches any number of characters (excluding directory separators)
- `**/`: Matches any number subdirectories

In addition
- '/' is the path separator no matter what os you are on.
- setting the `source_dir` has the effect of prepending `source_dir` to all patterns.
- currently, `include` will only include `.tl` files even if the extension isn't specified.

For example:
If our project was laid out as such:
```
tlconfig.lua
src/
| foo/
| | bar.tl
| | baz.tl
| bar/
| | a/
| | | foo.tl
| | b/
| | | foo.tl
```

and our tlconfig.lua contained the following:
```lua
return {
   source_dir = "src",
   build_dir = "build",
   include = {
      "foo/*",
      "bar/**/*"
   },
   exclude = {
      "foo/bar.tl"
   }
}
```

Running `tl build` will produce the following files.
```
tlconfig.lua
src/
| foo/
| | bar.tl
| | baz.tl
| bar/
| | a/
| | | foo.tl
| | b/
| | | foo.tl
build/
| foo/
| | baz.lua
| bar/
| | a/
| | | foo.lua
| | b/
| | | foo.lua
```

Additionally, complex patterns can be used for whatever convoluted file structure we need.
```lua
return {
   include = {
      "foo/**/bar/**/baz/**/*"
   }
}
```
This will compile any `.tl` file with a sequential `foo`, `bar`, and `baz` directory in its path.

## Scripts

Scripts let you run arbitrary Lua/Teal code in the middle of commands. This is intended for things like autogenerating types/documentation/etc. Similar to `tlconfig.lua`, a script is a file that returns a table of a specific shape:

```
record
   run_on: {string}
   exec: function(string, ...: any)
end
```
`exec` is the body of the script, or what will get executed.

`run_on` is an array of what _hooks_ the script will be run on. A hook is a string of the form:
`"command_name:step"`. Currently the only hooks that exist are
 - `"build:pre"`: before scanning your source directory
 - `"build:post"`: after compiling source files, does not run when no work is done
 - `"build:file_updated"`: emitted when a source file is newer than it's compilation target, passes a `cyan.fs.Path` object that describes the path to the source file to the hook

The first argument of `exec` is the hook that was emitted by the command, along with any arbitrary data that the command chooses to call the hook with.

If you would not like to run a script, you can pass the `--no-script` flag to emit no hooks during the command.

For some more concrete examples, take a look at the `scripts/docgen.tl` and `scripts/gen_rockspec.tl` here in the cyan repo.
