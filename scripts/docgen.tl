
local log <const> = require("cyan.log")
local fs <const> = require("cyan.fs")
local ansi <const> = require("cyan.ansi")
local cs <const> = require("cyan.colorstring")
local util <const> = require("cyan.util")
local merge_list <const> = util.tab.merge_list

local info = log.create_logger(
   io.stdout,
   cs.highlight({ansi.color.bright.cyan}, "Docgen"),
   cs.highlight({ansi.color.bright.cyan}, "...")
)

local has_ltreesitter <const>, ts <const> = pcall(require, "ltreesitter")
if not has_ltreesitter then
   log.warn("docgen requires the ltreesitter module, which lua was unable to find\n", ts as string)
   return
end

local has_teal_parser <const>, teal_parser <const> = pcall(ts.require, "teal")
if not has_teal_parser then
   log.warn("docgen requires tree-sitter-teal, which ltreesitter could not find:\n", teal_parser as string)
   return
end

local docfile <const> = fs.path.new("docs/index.html")
local type Emitter = function(prefix: {string}, object: ts.Node, output: {string}): string

local function assertf(val: any, fmt: string, ...: any)
   assert(val, fmt:format(...))
end

local type TagTree = {string | TagTree}
local function html(tags: TagTree): string
   local flattened <const>: {string} = {}
   for _, v in ipairs(tags) do
      if v is string then
         if #v > 0 then
            table.insert(flattened, v)
         end
      else
         table.insert(flattened, html(v))
      end
   end
   return table.concat(flattened)
end
local function tag_wrapper(name: string): function(string | TagTree, {string:string}): TagTree
   return function(content: string | TagTree, attrs: {string:string}): TagTree
      if content is string then
         content = { content }
      end
      local start = { "<", name }
      if attrs then
         for k, v in pairs(attrs) do
            table.insert(start, (" %s=%s"):format(k, v))
         end
      end
      table.insert(start, ">")
      table.insert(content as TagTree, 1, start)
      table.insert(content as TagTree, "</" .. name .. ">\n")
      return content as TagTree
   end
end
local h1 <const> = tag_wrapper "h1"
local h2 <const> = tag_wrapper "h2"
local _h3 <const> = tag_wrapper "h3"
local _h4 <const> = tag_wrapper "h4"
local pre <const> = tag_wrapper "pre"
local p <const> = tag_wrapper "p"
local a <const> = tag_wrapper "a"
local br <const> = "<br>"
local function doc_header(content: string | TagTree, name: string): TagTree
   return h2(a({ "<code>", content, "</code>" }, { name = name }))
end

local emit: {string:Emitter} = setmetatable({}, {
   __newindex = function(self: {string:Emitter}, name: string, emitter: Emitter)
      -- wrap all functions in these asserts
      rawset(self, name, function(prefix: {string}, n: ts.Node, out: {string}): string
         assertf(prefix, "nil prefix for emitter %q", name)
         assertf(n, "nil node for emitter %q", name)
         assertf(out, "nil output for emitter %q", name)

         assertf(n:type() == name, "Wrong node type (%q) for emitter %q", n:type(), name)

         local obj_name = emitter(prefix, n, out)
         assertf(obj_name, "Emitter %q did not return object name", name)
         return obj_name
      end)
   end,
   __index = function(_: {string:Emitter}, name: string)
      error(("No emitter for node %q"):format(name))
   end,
})

local href_prefix <const> = docfile[#docfile]
local function escape(str: string): string
   return (str:gsub("\n\n", br)
              :gsub("`(.-)`", "<code>%1</code>")
              :gsub("([\"'])([^%1]-)%1", "<code>%1%2%1</code>"))
end

local html_escape_map <const> = {
   ["<"] = "&lt;",
   [">"] = "&gt;",
}

emit["function_statement"] = function(prefix: {string}, n: ts.Node, out: {string}): string
   local sig <const> = n:child_by_field_name("signature")
   local ret <const> = sig:child_by_field_name("return_type")
   local typeargs <const> = sig:child_by_field_name("typeargs")
   local name <const> = n:child_by_field_name("name"):source()

   table.insert(
      out,
      html {
         doc_header({ name,
                      typeargs and typeargs:source():gsub("[<>]", html_escape_map) or "",
                      sig:child_by_field_name("arguments"):source(),
                      (ret and ": " .. ret:source() or ""),
                      "</code>" }, name),
         escape(table.concat(prefix))
      }
   )
   return name
end

emit["record_declaration"] = function(prefix: {string}, n: ts.Node, out: {string}): string
   local fields <const> = {}
   local meta <const> = {}
   local body <const> = n:child_by_field_name("record_body")
   if not body then
      error("record_body is nil for " .. tostring(n))
   end

   for c in body:named_children() do
      if c:type() == "record_entry" then
         local key = c:child_by_field_name("key")
         local is_string = false
         if not key then
            key = c:child_by_field_name("string_key")
            is_string = true
         end

         if key:source():sub(1, 1) ~= "_" then
            local t = c:child_by_field_name("type")
            table.insert(
               fields,
               (is_string and "[%s]" or "%s"):format(key:source())
                  .. ": " .. t:source()
            )
         end
      elseif c:type() == "metamethod" then
         table.insert(
            meta,
            c:source()
         )
      elseif c:type() == "record_array_type" then
         table.insert(
            fields,
            1,
            "{" .. c:child(0):source() .. "}"
         )
      end
   end
   local obj_name <const> = n:child_by_field_name("name"):source()
   table.insert(
      out,
      html {
         doc_header ({"type ", obj_name}, obj_name),
         pre  { "record ", obj_name, br, "   ",
                 table.concat(merge_list(meta, fields), br .. "   "),
                 br,
                "end" },
         escape(table.concat(prefix))
      }
   )
   return obj_name
end

local query <const> = teal_parser:query[[
   ((comment)+ @com
     . (_) @obj
     (#match? @com "^%-%-%-@%w+$")) ]]

local record Doc
   kind: string
   content: {string}
   obj: ts.Node
end

local function gen_docs(filename: string, module_name: string): string, {string}
   local root: ts.Node
   do
      local file <const> = assert(filename, "No filename provided")
      local content <const> = assert(fs.read(file))
      local tree <const> = assert(teal_parser:parse_string(content))
      root = tree:root()
   end

   local docs <const>: {Doc} = {}

   for match in query:match(root) do
      local caps <const> = match.captures as {ts.Node}
      local n <const> = caps[match.capture_count as integer]
      local s = n:type()
      if s ~= "comment" then
         -- obj will match comments as the query will produce EVERY match
         -- resulting in the same nodes being matched over and over
         -- this basically guarantees the match we actually care about
         local obj <const> = table.remove(caps, match.capture_count)
         local kind_node = table.remove(caps, 1)
         local kind <const> = kind_node:source():match("^%-%-%-@(%w+)")
         if kind == "nodoc" then
            return
         end
         local lines <const> = {}
         local content: {string} = {}
         local current_state: string
         local n_leading_spaces: integer
         local function ins(str: string)
            if str:match("^%s*$") then return end
            table.insert(content, str)
         end
         for i, v in ipairs(caps) do
            local src <const> = v:source()
            if not src:match("^%-%-%-") then
               break
            end
            local sub <const>, rest <const> = src:match("^%-%-%-@@(%w+)(.*)%s*$")
            -- TODO: make a proper state machine for this
            if sub then
               if sub == "end" then
                  if current_state == "table" then
                     ins("</table>")
                  elseif current_state == "code" then
                     ins("</pre>")
                  end
                  current_state = nil
               elseif current_state then
                  error("Attempt to use @@" .. sub .. " inside of @@" .. current_state)
               else
                  current_state = sub
                  if current_state == "table" then
                     ins("<table>")
                     local row <const> = { "<tr>" }
                     for col in rest:gmatch("[^|]+") do
                        table.insert(row, "<th>" .. col .. "</th>")
                     end
                     table.insert(row, "</tr>")
                     ins(table.concat(row))
                  elseif current_state == "code" then
                     ins("<pre>")
                  end
               end
            else
               local leadingws <const>, line = src:match("^%-%-%-(%s*)(.*)%s*$")
               if i == 1 then
                  n_leading_spaces = #leadingws
               else
                  line = leadingws:sub(n_leading_spaces + 1, -1) .. line
               end
               if current_state == "table" then
                  local row = { "<tr>" }
                  for col in line:gmatch("[^|]+") do
                     table.insert(row, "<td>" .. col .. "</td>")
                  end
                  table.insert(row, "</tr>")
                  ins(table.concat(row))
               elseif current_state == "code" then
                  ins(line .. "<br>")
               else
                  if line == "" and #content > 0 then
                     table.insert(lines, "<p>" .. table.concat(content, " ") .. "</p>")
                     content = {}
                  else
                     ins(line)
                  end
               end
            end
         end
         assertf(not current_state, "Unended doc block %q in %s", current_state, filename)
         table.insert(lines, "<p>" .. table.concat(content, " ") .. "</p>")
         table.insert(docs, {
            kind = kind,
            content = lines,
            obj = obj,
         })
      end
   end

   local brief: string
   local sections <const>: {string} = {}
   local table_of_contents <const>: {string} = {}

   for _, d in ipairs(docs) do
      local node_kind <const> = d.obj:type()
      if d.kind == "desc" then
         local name <const> = emit[node_kind](d.content, d.obj, sections)
         table.insert(table_of_contents, html {
            a (name, { href = ("%s#%s"):format(href_prefix, name)}),
         })
      elseif d.kind == "brief" then
         if brief then
            error("Module " .. module_name .. " contains more than one @brief directive")
         end
         brief = escape(table.concat(d.content))
      else
         log.warn("Unhandled node kind: ", node_kind)
      end
   end

   if not brief then
      log.warn(
         filename, " has no ",
         cs.highlight(cs.colors.keyword, "---@brief"), "\n   If this is intentional, use ",
         cs.highlight(cs.colors.keyword, "---@nodoc"), " to silence this warning"
      )
   end

   if #sections > 0 or brief as boolean then
      table.sort(sections)
      local res = {
         h1 (a (module_name, { name = module_name })),
      }
      if brief then
         table.insert(res, p (brief))
      end
      table.insert(sections, 1, html (res))
      table.sort(table_of_contents)
      return table.concat(sections), table_of_contents
   end
end

local table_of_contents <const> = {}
local output <const> = {}
for path in fs.scan_dir("src", {"cyan/**/*"}) do
   local file <const> = ("src" .. path):to_real_path()
   local mod <const> = path:tostring():gsub("%.tl$", ""):gsub("/", "."):gsub("%.init$", "")
   local docs <const>, toc <const> = gen_docs(file, mod)
   if docs then
      info("Processed ", cs.highlight(cs.colors.file, path:tostring()))
      table.insert(table_of_contents, html {
         p { a (mod, { href = ("%s#%s"):format(href_prefix, mod)}),
             br,
             table.concat(toc, br) }
      })
      table.insert(output, docs)
   end
end
table.sort(table_of_contents)
for i = #table_of_contents, 1, -1 do
   if i % 4 == 1 then
      table.insert(table_of_contents, i, "</td><td valign=top>")
   end
end
table.insert(table_of_contents, "</td></tr>")
table.sort(output)
local fh <const> = assert(io.open(docfile:to_real_path(), "w"))
fh:write[[
<!DOCTYPE html>
<html lang="en">
<meta charset="utf-8"/>
<style>
html {
   background-color: #16191a;
}

body {
   background-color: #181a1b;
   margin: auto;
   max-width: 70em;
   width: 90%;
   padding: 32px;
   font-family: Helvetica, Arial, sans-serif;
   color: #e8e6e3;
}

a {
   text-decoration: none;
   color: #3391ff;
   padding: 3px 3px 3px 3px;
}

a:link:hover {
   background-color: #25282A;
   border-radius: 4px;
}

h1 {
   color: #117dee;
}
h1::before {
   content: "\2756";
   padding-right: 0.5em;
}

h2 {
   color: #117dee;
}
</style>
<body>
]]
fh:write(
   html { h1 "Api Documentation",
          p "This documentation is autogenerated and may be incomplete",
          br }
)
fh:write(html { h1 "Index", "<table width='100%'><tbody>", table_of_contents, "</tbody></table>" })
fh:write(table.concat(output))
fh:write[[</body></html>]]
fh:close()
info("Wrote ", cs.highlight(cs.colors.file, docfile:to_real_path()))
