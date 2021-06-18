# Cyan

A build system for the Teal language

[![test](https://github.com/teal-language/cyan/actions/workflows/test.yml/badge.svg)](https://github.com/teal-language/cyan/actions/workflows/test.yml)

# Commands

 - `check`: type check one or more Teal files
 - `gen`: type check and compile one or more Teal files
 - `run`: type check and run a Teal script in a sandbox
 - `build`: build a project based on `tlconfig.lua`
 - `init`: initialize a Teal project

## API

The output of all the commands is much nicer for humans than it is for computers. If you'd like the output of commands, or to be able to load a config file in your own tooling, we provide a small api.

Auto-generated documentation can be found [here](https://teal-language.github.io/cyan/).

## tlconfig.lua

For a quick start, just run `cyan init` to get a barebones `tlconfig.lua`. For a more in depth explanation of the config options, documentation can be found [here](docs/tlconfig.md).
