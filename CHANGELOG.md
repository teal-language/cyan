# 0.3.0
2023-02-01

Closely following Teal's 0.15.0 release, changes in both the `tl` api and `cyan` apis warrant a new release.

CLI Features:
 - build: let the `--prune` option delete empty directories
 - tlconfig: add `dont_prune` option
   Certain teal applications will commit things to the build directory to make
   shipping things easier, but the warning about unexpected files in the build
   directory is annoying for this use case and the `--prune` option itself was
   more cumbersome since it would delete the wanted files. This new option
   allows for this use case.
 - warning errors and regular errors will now be reported together rather than
   only reporting warning errors

API Features:
 - loggers are now callable tables rather than just functions and have more
   fine grained control over when newlines and continuations are emitted.
   See the commit 69fae786 for details, or the generated documentation.

API Documentation:
 - "private" fields (i.e. fields that start with an underscore) are shown in documentation (under a `<details>` tag)
 - The color scheme of the documentation is now better. (When I originally made
   it, my dark reader extension was warping my view of the colors. This is now
   fixed)
 - Many minor internal changes to how the docs are generated. Such as using an
   html template rather than generating everything with a script
 - Some aesthetic changes to how docs are presented

Fixes:
 - build: Don't write lua files when `source_dir` == `build_dir`
   Since generated lua will erase things like comments, this could be very cumbersome.
 - build+gen: add a newline to the end of generated files
   To line up with the behavior of `tl`
 - `tlcommon.report_result` will no longer short circuit when reporting warning errors and type errors
 - `tlcommon` accomodates the changes to the tl api
 - `util.tab.merge_list` did not return the correct table and would just return the first argument
 - ci: deduplicate running ci on pull requests from inside the repo
 - `tlcommon.report_result` ignored syntax errors and the documentation lied about it, so syntax errors in scripts are now properly reported

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
