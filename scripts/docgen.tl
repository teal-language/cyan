
local log <const> = require("cyan.log")
local fs <const> = require("cyan.fs")

local has_ltreesitter <const>, ts <const> = pcall(require, "ltreesitter")
if not has_ltreesitter then
   log.err("docgen requires the ltreesitter module")
   os.exit(1)
end

local has_teal_parser, teal_parser <const> = pcall(ts.require, "teal")
if not has_teal_parser then
   log.err("docgen requires tree-sitter-teal, which ltreesitter could not find")
   os.exit(1)
end


if false then
   -- TODO
   for p in fs.scan_dir(".", {"src/cyan/**/*"}) do
      print(p)
   end

   return
end

local root: ts.Node
do
   local file <const> = assert(..., "No filename provided")
   local content <const> = assert(fs.read(file))
   local tree <const> = assert(teal_parser:parse_string(content))
   root = tree:root()
end

local record Doc
   kind: string
   content: {string}
   obj: ts.Node
end

local docs <const>: {Doc} = {}

collectgarbage("stop")
for match in teal_parser
   :query[[ (
      (comment)+ @com
      . (_) @obj
      (#match? @com "^%-%-%-@%w+$")) ]]
   :match(root)
do
   local caps <const> = match.captures as {ts.Node}
   local n <const> = caps[match.capture_count]
   local s = n:type()
   if s ~= "comment" then
      -- obj will match comments as the query will produce EVERY match
      -- resulting in the same nodes being matched over and over
      -- this basically guarantees the match we actually care about
      local obj <const> = table.remove(caps, match.capture_count)
      local kind_node = table.remove(caps, 1)
      local kind <const> = kind_node:source():match("^%-%-%-@(%w+)")
      local lines <const> = {}
      local content: {string} = {}
      for _, v in ipairs(caps) do
         local src <const> = v:source()
         if not src:match("^%-%-%-") then
            break
         end
         local line <const> = src:match("^%-%-%-%s*(.*)%s*$")
         if line == "" then
            table.insert(lines, table.concat(content, " "))
            content = {}
         else
            table.insert(content, line)
         end
      end
      table.insert(lines, table.concat(content, " "))
      table.insert(docs, {
         kind = kind,
         content = lines,
         obj = obj,
      })
   end
end

for _, d in ipairs(docs) do
   local node_kind <const> = d.obj:type()
   if d.kind == "desc" then
      if node_kind == "function_statement" then
         local sig <const> = d.obj:child_by_field_name("signature")
         local ret <const> = sig:child_by_field_name("return_type")

         io.write(
            "### `",
            d.obj:child_by_field_name("name"):source(),
            sig:child_by_field_name("arguments"):source(),
            ret and ": " .. ret:source() or "",
            "`",
            "\n",
            table.concat(d.content, "\n\n"),
            "\n\n"
         )
      elseif node_kind == "record_declaration" then
         io.write(
            "### record `",
            d.obj:child_by_field_name("name"):source(),
            "`\n",
            table.concat(d.content, "\n\n"),
            "\n\n"
         )
      end
   elseif d.kind ~= "brief" then
      io.stderr:write("Unhandled node kind: ", node_kind, "\n")
   end
end
