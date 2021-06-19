# Cyan contribution guide

Make sure to take a glance at the [code of conduct](../CODE_OF_CONDUCT.md) before opening an issue/pr.

## Code Style
Like Teal itself, Cyan (mostly) follows the [Luarocks Style guide](https://github.com/luarocks/lua-style-guide), with some extensions to accomodate Teal's extra features

Each bullet may contain one of these words, treat them as meaning the following:
 - `Always`: 99% of the time you should do this
 - `Prefer`: Generally use this, but there are cases where you shouldn't
 - `Avoid`: Generally don't use this, but there are cases where you should
 - `Never`: 99% of the time you shouldn't do this

### Formatting
 - [Indent with 3 spaces](https://github.com/luarocks/lua-style-guide#indentation-and-formatting)
 - Unix line endings
Both of the above are in the `.editorconfig` file of this repository. I'd reccommend you find an editor/plugin that automatically adheres to it.

### Doc Comments
 Teal currently doesn't have an 'official' or widespread doc-comment format. Currently we use a [custom script](#documentation-generation) to generate the [api docs](./index.html). There are currently only 2 directives:
 - `@brief`
   - One per file, a brief summary of what that file does/contains
 - `@desc`
   - Documents the piece of code under it, giving a description. Currently only supports function and record declarations. The script will emit a warning when it doesn't know how to document a certain piece of code.
   - These should briefly describe _what_ something is or does, not necessarily _how_ it does it, unless that is relevant. (For example: You should document when a function modifies its arguments)

Additionally there are 2 subdirectives to control how the output is formatted. Subdirectives start with `---@@` (note that there is no space between the `---` and `@@`) and define a block until the corresponding `---@@end` is found:
 - `@@code`: place the block in a `<pre>` tag and append `<br>` to each line
 - `@@table`: create a `<table>` of data. `|` is used to separate columns. If you define a row on the same line as this directive it will be used as the header.

### Variables
 - Variables and functions should be `snake_case`
 - Types should be `PascalCase`
 - Prefer `<const>` variables when applicable. Make use of the 'ternary' `x and y or z` when possible, but be reasonable, if something should be abstracted to a function or using a mutable variable makes the code more readable do that instead.

```
local x <const> = y < -1
   and 1
   or 2

```
 - Never use `global` (unless working around a missing annotation of the stdlib)
 - Try to limit variables to the smallest scope possible
   - This usually involves wrapping things like `pcall` in `do end` blocks

```
-- bad
local function thing()
   local ok, err = pcall(func)
   if not ok then
      print(err)
      return
   end
   -- neither ok nor err are ever used beyond this point
   -- ...
end

-- good
local function thing()
   do
      local ok, err = pcall(func)
      if not ok then
         print(err)
         return
      end
   end
   -- ...
end

```
 - Never use `as` when a plain annotation will do. This is similar to how casting `malloc` in C can hide errors.

```
-- bad
local my_tuple = { "a", "b" } as {string, string} -- If the value is changed later
                                                  -- the type system won't report mistakes

-- good
local my_tuple: {string, string} = { "a", "b" } -- tuples are subtypes of arrays
                                                -- so this annotation is safe
```

### Strings
 - Always use `"double quotes"` except when the string contains double quotes

### Tables
 - Always use `,` as a field separator
 - When a table literal is defined over multiple lines, always use a trailing comma. Otherwise don't

```
local a = { 1, 2, 3 }
local b = {
   "a",
   "b",
   "c",
}
```
 - For `record`s, prefer `.` indexing
 - For maps, prefer `[]` indexing

### Functions
 - Return early and return often. Do validation of arguments and neccesary calculations early, returning an error if they don't conform. This helps keep code flatter.

```
-- bad
local function do_things(x: integer, y: integer): number, string
   if x > 0 then
      -- do some calculations/work with x
      if y < 0 then
         -- more calculations
         return x / y
      else
         return nil, "argument 2: expected negative integer"
      end
   else
      return nil, "argument 1: expected positive integer"
   end
end

-- better
local function do_things(x: integer, y: integer): number, string
   if x <= 0 then
      return nil, "argument 1: expected positive integer"
   end

   -- do some calculations/work with x

   if y >= 0 then
      return nil, "argument 2: expected negative integer"
   end

   -- more calculations

   return x / y
end

-- best
local function do_things(x: integer, y: integer): number, string
   if x <= 0 then
      return nil, "argument 1: expected positive integer"
   end
   if y >= 0 then
      return nil, "argument 2: expected negative integer"
   end

   return x / y
end

```
 - If a signature is getting long, split each argument to its own indented line, with the closing paren on its own line at the same indent level as the `function` keyword

```
local function foo(
   w: string
   x: number,
   y: number,
   z: integer
): number
   -- ...
end
```

### Types
 - Avoid using parenthesis in types unless it clarifies an ambiguity

```
-- bad
local function foo(): (number, string)
end

-- ok, but could be a mistake
local function bar(): function(): number, string
end

-- good
local function foo(): number, string
end

local function bar(): (function(): number), string
end
```
 - When annotating arguments and returns of higher order functions, prefer having the `function` inside the parens. This is consistent with Lua semantics as an expression wrapped in parens is adjusted to one result, so types like `(function(): number, string)` should be easier to recognize as a _single_ type.
 - Function types are checked structurally, don't hesitate to use a type alias if a signature for a callback is complex or hard to read

```
-- bad
local function fn_that_has_callback(fn: (function(string, integer): any, string), data: any)
end

-- good
local type Callback = function(string, integer): any, string
local function fn_that_has_callback(fn: Callback, data: string)
end
```
   - But, if this is a public function to an api, make sure that the `Callback` type is documented and/or exposed

 - If a public function can consume or produce a record type, that record type should also be public. This allows users of your API to annotate nil or uninitialized variables or construct the record over multiple statements.

```
-- bad
local api <const> = {}

local record Foo
   -- ...
end

function api.func(f: Foo)
   -- ...
end

return api


-- good

local record Foo
   -- ...
end

local api <const> = {
   Foo = Foo,
}

function api.func(f: Foo)
   -- ...
end

return api
```
With the `good` version, consumers of the API can now annotate variables without being forced to initialize them

```
local my_foo: api.Foo
do
   -- do some calculations
   my_foo = result_of_calculations
end
```
Without exposing a type, it is _extremely hard_ for users of the api to interact with anything that has to do with that type

 - When type checking manually, prefer the `is` operator to manually calling `type()`

### Generics

 - When declaring generic types, avoid using single letter type variables. The name of the type variable should at least vaguely describe what the type represents:

```
-- bad
local type Mapper = function<A, B>({A}): {B}

-- good
local type Mapper = function<Value, Mapped>({Value}): Mapped
```

### Working Around the Type System
Sometimes Teal's type system isn't powerful or expressive enough to annotate common Lua code. Workarounds should be done in isolation
 - Wrap type unsafe/unsound code either in it's own function or a `do end` block.
   - think of this as analogous to Rust's `unsafe` blocks - abstract the unsafe operation into a type-safe interface
   - for example a generic `copy` function might have the following implementation

```
local function copy<T>(x: T): T
   if not x is table then
      return x
   end
   -- beyond here we know that x is a table,
   -- but the type system doesn't
   local cpy: table = {}
   for k, v in pairs(x as table) do
      cpy[copy(k)] = copy(v)
   end
   return cpy as T
end
```
This function is full of type-unsafe casts, but the interface it provides is type-safe. And that is the arguably the most important takeaway, an API should have a safe interface, but is allowed to have unsafe internals.
If something is too hard to work around then consider dropping down to Lua and writing a definition file.

### Modules
 - Prefer initializing the module near the top of the file, and `return`ing the module as the last line. For shorter modules this matters less.

```
local mod <const> = {}

-- define module things here

return mod
```

### Modules That Contain Types
 - Prefer declaring modules as tables rather than records. Since we can't define records inside of tables, define them locally then initialize the module with them. Forward declare non-function entries as needed.

```
-- bad

local record mod
   record Foo
      x: integer
      y: number
   end
   foo_impl: Foo
end

-- ...

return mod

-- good
local record Foo
   x: integer
   y: number
end

local mod <const> = {
   Foo = Foo,
   foo_impl: Foo = nil,
}

-- ...

return mod
```

### Spacing
 - Always include a space after `--`, `---`, `---@brief/desc`, and commas
 - Always put spaces after commas
 - Always surround `=` with spaces
 - If an expression spans multiple lines, prefer to start lines with binary operators and indent for as long as the expression continues. (Here 'binary operators' includes things like indexing with `.` or `:`)

```
-- bad
local x = y and
z or a + b
* c

local long_str = "abcd" ..
"efgh" ..
"ijkl" ..
"mnop"

foo:bar():baz()
:bat()

-- good
local x = y
   and z
   or a + b * c

local long_str = "abcd"
   .. "efgh"
   .. "ijkl"
   .. "mnop"

f:bar()
   :baz()
   :bat()
```
- Additionally, you may align consecutive `:` indexing with spaces

```
f:bar()
 :baz()
 :bat()
```

### OOP / Records with methods
 - 'Classes' should be defined in the simple self-`__index` or "record as prototype" style that the type system understands. But should not use the `__call` method as a constructor

```
local record Foo
end

function new_foo(): Foo
end

function Foo:do_something()
end
```

## Compiling
This project has a `Makefile`. Use it.
 - `make`: use `tl gen --check` to compile each source file
 - `make bootstrap`: `make`, then see if `cyan` can compile itself properly, then run the test suite

There are additional binaries in the `bin` folder that don't get installed and are just used for development.
 - `local-cyan`: use `tl.loader()` to compile `cyan` on the fly - use this for more rapid development and small tweaks
 - `bootstrap`: similar to `cyan`, just alters the path so the makefile knows where to find the built code to use for bootstrapping

### Warnings + Warning Errors
Cyan has `unused` and `redeclaration` promoted to errors since these type of warnings are arguably the most common and a large source of bugs. So it should not compile while there are any of these. Furthermore, ideally any pull requests should not have any warnings.

## Testing
Cyan uses [busted](https://olivinelabs.com/busted/) for testing. Currently the test suite only runs on \*nix. (Hopefully we will have a more portable solution to how we run tests soon)

## Documentation Generation
The Api documentation is generated using the [ltreesitter module](https://github.com/euclidianAce/ltreesitter) along with [tree-sitter-teal](https://github.com/euclidianAce/tree-sitter-teal) via the [`docgen.tl` script](../scripts/docgen.tl)

