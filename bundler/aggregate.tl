local argparse <const> = require("argparse")
local decoration <const> = require("cyan.decoration")
local fs <const> = require("cyan.fs")
local lexical_path <const> = require("lexical-path")
local log <const> = require("cyan.log")

local info <const> = log.info:copy(
   decoration.decorate("Aggregate", decoration.scheme.green),
   decoration.decorate("...", decoration.scheme.green)
)

--local err <const> = log.err:copy(
--   decoration.decorate("Aggregate", decoration.scheme.red),
--   decoration.decorate("...", decoration.scheme.red)
--)

local parser <const> = argparse("aggregate", "Produce an aggregate C file with compiled bytecode of lua dependencies")

parser:argument("cyan",         "Directory of cyan's compiled lua files"):convert(lexical_path.from_os)
parser:argument("lexical_path", "Directory of lexical-path's lua files") :convert(lexical_path.from_os)
parser:argument("inspect",      "Directory of inspect's lua files")      :convert(lexical_path.from_os)
parser:argument("argparse",     "Directory of argparse's lua files")     :convert(lexical_path.from_os)
parser:argument("system",       "Directory of system's lua files")       :convert(lexical_path.from_os)
parser:argument("teal",         "Directory of teals's lua files")        :convert(lexical_path.from_os)
parser:option("--target-path")
      :argname("<target.c>")
      :default("aggregate.c")
      :convert(lexical_path.from_os)

local Path = lexical_path.Path

local interface Args
   cyan:         Path
   lexical_path: Path
   inspect:      Path
   argparse:     Path
   system:       Path
   teal:         Path
   target_path:  Path
end

local args = parser:parse() as Args

local ti <const> = table.insert

local dumped: string
do
   local buf = {}
   local function emit_line(content: string)
      if #content == 0 then return end
      ti(buf, content)
      ti(buf, "\n")
   end

   local function add_lua_module(require_arg: string, path: string, direct?: boolean)
      info("Adding lua module ", require_arg, " from ", decoration.file_name(path))
      local f = assert(io.open(path, "r"))
      if not direct then
         emit_line(("package.preload[%q] = function(...)"):format(require_arg))
      end
      for line in f:lines() do
         emit_line(line)
      end
      if not direct then
         emit_line("end")
      end
      f:close()
   end

   for file in fs.scan_directory(args.cyan, {"cyan/**/*.lua"}, {"cyan/cli.lua"}) do
      local to_require <const> = file:extension_split():to_string(".")
      add_lua_module(to_require, (args.cyan .. file):to_string())
   end

   for file in fs.scan_directory(args.teal, {"teal/**/*.lua"}) do
      local to_require <const> = file:extension_split():to_string(".")
      add_lua_module(to_require, (args.teal .. file):to_string())
   end
   add_lua_module("tl", (args.teal .. "tl.lua"):to_string())
   add_lua_module("argparse", (args.argparse .. "src/argparse.lua"):to_string())
   add_lua_module("lexical-path", (args.lexical_path .. "build/lexical-path.lua"):to_string())
   add_lua_module("inspect", (args.inspect .. "inspect.lua"):to_string())
   add_lua_module("system", (args.system .. "system/init.lua"):to_string())

   add_lua_module("cyan.cli", (args.cyan .. "cyan/cli.lua"):to_string(), true)

   dumped = string.dump((assert(load(table.concat(buf), "@<bundled-lua>", "t"))), true)
end

assert(fs.make_parent_directories(args.target_path))
local out <const> = assert(io.open(args.target_path:to_string(), "w"))

out:write("unsigned char const lua_bytecode[] = {\n")
local row_size = 128
for i = 1, #dumped, row_size do
   for j = i, i+row_size-1 do
      local c <const> = dumped:sub(j, j)
      if #c == 0 then break end
      out:write(c:byte(), ",")
   end
   out:write("\n")
end

out:write [[};
#include <lua.h>
#include <lualib.h>
#include <lauxlib.h>
#include "lfs.h"
]]

-- TODO: I'd like to basically include lua's main to give the user a way to run lua programs
-- if (argc>=2 and strcmp("lua", argv[1])==0)
--    return lua_main(argc + 1, argv + 1);

out:write [[

int main(int argc, char **argv) {
   lua_State *L = luaL_newstate();
   if (!L) {
      fprintf(stderr, "Not enough memory to start lua vm\n");
      return 1;
   }
   int exit_code = 0;

   luaL_openlibs(L);
   luaL_requiref(L, "lfs", luaopen_lfs, 0);
   lua_pop(L, 1);

   int luaopen_system_core(lua_State *L);
   luaL_requiref(L, "system.core", luaopen_system_core, 0);
   lua_pop(L, 1);

   lua_createtable(L, argc, 0);
   for (int i = 0; i < argc; ++i) {
      lua_pushstring(L, argv[i]);
      lua_rawseti(L, -2, i);
   }
   lua_setglobal(L, "arg");

   switch (luaL_loadbufferx(L, lua_bytecode, sizeof lua_bytecode, "@<bundled-lua>", "b")) {
   case LUA_OK: break;
   case LUA_ERRMEM:
      fprintf(stderr, "Not enough memory to start lua\n");
      exit_code = 2;
      goto done;
   case LUA_ERRSYNTAX: {
      const char *msg = lua_tostring(L, -1);
      fprintf(stderr, "Internal error, bundled lua had a syntax error: %s\n", msg ? msg : "No error message provided");
      exit_code = 2;
      goto done;
   }
   default: {
      const char *msg = lua_tostring(L, -1);
      fprintf(stderr, "Internal error, bundled lua had an error: %s\n", msg ? msg : "No error message provided");
      exit_code = 1;
      goto done;
   }
   }

   for (int i = 1; i < argc; ++i)
      lua_pushstring(L, argv[i]);
   if (lua_pcall(L, argc - 1, LUA_MULTRET, 0) != LUA_OK) {
      const char *msg = lua_tostring(L, -1);
      fprintf(stderr, "Internal error, bundled lua had an error: %s\n", msg ? msg : "No error message provided");
      exit_code = 1;
      goto done;
   }

done:
   lua_close(L);
   return exit_code;
}]]

out:close()

info("Wrote ", decoration.file_name(args.target_path))
