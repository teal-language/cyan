# 0.2.0
2022-08-21

Closely following the `tl` 0.14.0 release, `cyan` has been accumulating enough features to warrant a new release.

CLI Features:
 - from `tl` add the `--global-env-def` flag
 - `build` will now detect circular dependencies
 - `cyan` will no longer print ANSI escape codes when not running in a tty or when [`$NO_COLOR`](https://no-color.org) is defined
 - `build --check-only` does a dry-run of the build, doing everything up to lua file generation
 - `--verbosity` flag for logging
 - `build` will now warn when there are unexpected files in the build directory
 - `build --prune` will remove any unexpected files that are detected in the build directory
 - changed how scripts are loaded via `tlconfig.lua`. This is a breaking change, see the documentation for details
 - added `build --source-dir` and `build --build-dir` from `tl build`
 - lua files from the source directory are now copied to the build directory
  - `tlconfig.lua` is excluded from this when the source directory is the root of the project
 - support for lua 5.4 features in `tl`, used via the `--gen-target 5.4` flag

API Features:
 - `fs.path`: now allows paths to be relative (i.e. they can contain `..`)
 - add `fs.copy`: reads the contents of a file and writes it to another file
 - add `fs.Path:to_absolute()`
 - `sandbox`: now allows passing arguments to the given function

Fixes:
 - `--werror all` and `--wdisable all` actually work properly now
 - `build`, `check`, and `gen` will now stop when a teal environment can not be properly initialized
 - the `log` module used to wrongly assume some input would always be a string
 - `integer` support in teal means we basically never use `number` anywhere
 - syntax errors from invalid tokens are now properly reported
 - the `cyan.config` module now actually sets the `loaded_from` field

# 0.1.0
2021-06-28

First release!

Main features:
 - Incremental `build` command
 - Nicely formatted error messages
 - Programmatic api for loading `tlconfig.lua` for other tools to consume
 - Drop in replacement for `tl`
