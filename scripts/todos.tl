local argparse <const> = require("argparse")
local log <const> = require("cyan.log")
local fs <const> = require("cyan.fs")
local cs <const> = require("cyan.colorstring")
local util <const> = require("cyan.util")
local pad_left <const>, map <const> = util.str.pad_left, util.tab.map

local has_ltreesitter <const>, ts <const> = pcall(require, "ltreesitter")
if not has_ltreesitter then
   log.warn("todos requires the ltreesitter module, which lua was unable to find\n", ts as string)
   return
end

local has_teal_parser <const>, teal_parser <const> = pcall(ts.require, "teal")
if not has_teal_parser then
   log.warn("todos requires tree-sitter-teal, which ltreesitter could not find:\n", teal_parser as string)
   return
end

local parser <const> = argparse("todos", "detect todos in the source")
parser:flag("--raw", "Output in a raw format useful for piping into other commands")
local parsed <const> = parser:parse()
local raw <const> = parsed.raw as boolean

local query <const> = teal_parser:query[[
   ((comment) @c
    (match? @c "TODO"))]]

local todo <const> = log.create_logger(
   io.stderr,
   "normal",
   cs.highlight(cs.colors.teal, "Todo"),
   cs.highlight(cs.colors.teal, "...")
)

local record Todo
   line: integer
   content: string
end
for path in fs.scan_dir(".", {"src/cyan/**/*"}) do
   local real_path <const> = path:to_real_path()
   local text <const> = fs.read(real_path)
   local root <const> = teal_parser:parse_string(text):root()
   local todos <const>: {Todo} = {}
   for match in query:match(root) do
      local node <const> = match.captures.c
      table.insert(todos, {
         line = node:start_point().row,
         content = node:source():match("TODO%s*:?%s*(.*)"),
      })
   end
   if #todos > 0 then
      if raw then
         for _, t in ipairs(todos) do
            io.write(real_path, ":", tostring(t.line), ":", t.content, "\n")
         end
      else
         todo(
            cs.highlight(cs.colors.emphasis, #todos .. " todo comment" .. (#todos == 1 and "" or "s")), " in ",
            cs.highlight(cs.colors.file, real_path),
            "\n   ",
            table.concat(map(todos, function(t: Todo): string
               return (
                  cs.highlight(cs.colors.number, pad_left(tostring(t.line), 4)) .. " | "
                  .. t.content
               ):tostring()
            end), "\n   "),
            "\n"
         )
      end
   end
end
