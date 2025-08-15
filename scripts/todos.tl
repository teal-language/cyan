local argparse <const> = require("argparse")
local decoration <const> = require("cyan.decoration")
local fs <const> = require("cyan.fs")
local lexical_path <const> = require("lexical-path")
local log <const> = require("cyan.log")
local util <const> = require("cyan.util")

local pad_left <const>, ivalues <const> = util.str.pad_left, util.tab.ivalues

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

local parser <const> = argparse("todos", "detect todos in the source", nil)
parser:flag("--raw", "Output in a raw format useful for piping into other commands")
local parsed <const> = parser:parse(nil)
local raw <const> = parsed.raw as boolean

local query <const> = teal_parser:query[[ (
   ((comment) @c
    (#match? @c "[Tt][Oo][Dd][Oo]"))
) ]]

local todo <const> = log.err:copy(
   decoration.decorate("Todo", decoration.scheme.teal),
   decoration.decorate("...", decoration.scheme.teal)
)

local record Todo
   line: integer
   content: string
   tags: {string:boolean}
end
local total = 0
-- lower -> first found
local all_tags: {string:string} = {}
local to_scan <const> = lexical_path.from_os("src")
for subpath in fs.scan_directory(to_scan) do
   local path <const> = to_scan .. subpath
   local path_str <const> = path:to_string()
   local text <const> = fs.read(path_str)
   local root <const> = teal_parser:parse_string(text):root()
   local todos <const>: {Todo} = {}
   for match in query:match(root) do
      local node <const> = match.captures.c
      assert(node is ts.Node)
      local src <const> = node:source()
      local content = src:match("TODO%s*:?%s*(.*)")
      if not content or #content == 0 then
         content = src
      end
      local tags <const> = {}
      for tag in content:gmatch("#(%S+)") do
         local lowered <const> = tag:lower()
         tags[lowered] = true
         if not all_tags[lowered] then
            all_tags[lowered] = tag
         end
      end
      table.insert(todos, {
         line = node:start_point().row + 1,
         content = content,
         tags = next(tags) and tags or nil
      })
   end
   if #todos > 0 then
      if raw then
         for t in ivalues(todos) do
            io.write(path_str, ":", tostring(t.line), ":", t.content, "\n")
         end
      else
         todo(
            decoration.decorate(#todos .. " todo comment" .. (#todos == 1 and "" or "s"), decoration.scheme.emphasis),
            " in ",
            decoration.file_name(path_str)
         )
         for t in ivalues(todos) do
            todo:cont(
               "   ",
               decoration.decorate(pad_left(tostring(t.line), 4), decoration.scheme.error_number),
               " │ ", t.content
            )
         end

      end
   end
   total = total + #todos
end
if not raw then
   todo("Found ", total, " total todo comment", total == 1 and "" or "s")

   local tags <const>: {string} = util.tab.sort_in_place(util.tab.from(util.tab.values(all_tags)))
   if #tags > 0 then
      todo("Found ", #tags, " tagged categor", #tags == 1 and "y" or "ies")
      for tag in ivalues(tags) do
         todo:cont("   #", tag)
      end
   end
end
