local _tl_compat; if (tonumber((_VERSION or ''):match('[%d.]*$')) or 0) < 5.3 then local p, m = true, require('compat53.module'); if p then _tl_compat = m end end; local assert = _tl_compat and _tl_compat.assert or assert; local io = _tl_compat and _tl_compat.io or io; local ipairs = _tl_compat and _tl_compat.ipairs or ipairs; local math = _tl_compat and _tl_compat.math or math; local pcall = _tl_compat and _tl_compat.pcall or pcall; local string = _tl_compat and _tl_compat.string or string; local table = _tl_compat and _tl_compat.table or table
local ansi = require("cyan.ansi")
local cs = require("cyan.colorstring")
local fs = require("cyan.fs")
local log = require("cyan.log")
local util = require("cyan.util")
local keys = util.tab.keys

local info = log.create_logger(
io.stdout,
"normal",
cs.highlight({ ansi.color.bright.cyan }, "Docgen"),
cs.highlight({ ansi.color.bright.cyan }, "..."))


local has_ltreesitter, ts = pcall(require, "ltreesitter")
if not has_ltreesitter then
   log.warn("docgen requires the ltreesitter module, which lua was unable to find\n", ts)
   return
end

local has_teal_parser, teal_parser = pcall(ts.require, "teal")
if not has_teal_parser then
   log.warn("docgen requires tree-sitter-teal, which ltreesitter could not find:\n", teal_parser)
   return
end

local template_file = fs.path.new("doc-template.html")
local template = assert(fs.read(template_file:to_real_path()))

local docfile = fs.path.new("docs/index.html")


local function assertf(val, fmt, ...)
   assert(val, fmt:format(...))
end


local function html(tags)
   local flattened = {}
   for _, v in ipairs(tags) do
      if type(v) == "string" then
         if #v > 0 then
            table.insert(flattened, v)
         end
      else
         table.insert(flattened, html(v))
      end
   end
   return table.concat(flattened)
end
local function tag_wrapper(name)
   return function(content, attrs)
      if type(content) == "string" then
         content = { content }
      end
      local start = { "<", name }
      if attrs then
         local attr_keys = util.tab.from(keys(attrs))
         table.sort(attr_keys)
         for _, key in ipairs(attr_keys) do
            table.insert(start, (" %s=%s"):format(key, attrs[key]))
         end
      end
      table.insert(start, ">")
      table.insert(content, 1, start)
      table.insert(content, "</" .. name .. ">\n")
      return content
   end
end
local _h1 = tag_wrapper("h1")
local h2 = tag_wrapper("h2")
local h3 = tag_wrapper("h3")
local _h4 = tag_wrapper("h4")
local pre = tag_wrapper("pre")
local p = tag_wrapper("p")
local a = tag_wrapper("a")
local br = "<br>"
local function doc_header(content, name)
   return h3(a({ "<code>", content, "</code>" }, { name = name }))
end

local emit = setmetatable({}, {
   __newindex = function(self, name, emitter)

      rawset(self, name, function(prefix, n, out)
         assertf(prefix, "nil prefix for emitter %q", name)
         assertf(n, "nil node for emitter %q", name)
         assertf(out, "nil output for emitter %q", name)
         assertf(n:type() == name, "Wrong node type (%q) for emitter %q", n:type(), name)

         local obj_name = emitter(prefix, n, out)
         assertf(obj_name, "Emitter %q did not return object name", name)
         return obj_name
      end)
   end,
   __index = function(_, name)
      error(("No emitter for node %q"):format(name))
   end,
})

local function escape(str)
   return (str:gsub("\n\n", br):
   gsub("`(.-)`", "<code>%1</code>"):
   gsub("([\"'])([^%1]-)%1", "<code>%1%2%1</code>"))
end

local html_escape_map = {
   ["<"] = "&lt;",
   [">"] = "&gt;",
   ["'"] = "&apos;",
   ['"'] = "&quot;",
   ['&'] = "&amp;",
}

local function escape_html_chars(str)
   return str:gsub("[<>'\"&]", html_escape_map)
end

emit["function_statement"] = function(prefix, n, out)
   local sig = n:child_by_field_name("signature")
   local ret = sig:child_by_field_name("return_type")
   local typeargs = sig:child_by_field_name("typeargs")
   local name = n:child_by_field_name("name"):source()

   table.insert(
   out,
   html({
      doc_header({ name,
typeargs and escape_html_chars(typeargs:source()) or "",
sig:child_by_field_name("arguments"):source(),
(ret and ": " .. ret:source() or ""), },
      name),
      p({ escape(table.concat(prefix)) }),
   }))

   return name
end

emit["enum_declaration"] = function(prefix, n, out)
   local body = n:child_by_field_name("enum_body")
   assertf(body, "enum_body is nil for %s", tostring(n));

   local name = n:child_by_field_name("name"):source()
   local entries = {}

   for child in body:named_children() do
      table.insert(entries, child:source())
   end


   table.insert(
   out,
   html({
      doc_header({ "type ", name }, name),
      pre({ "enum ", name, br, "   ",
table.concat(entries, br .. "   "),
br,
"end ", }),
      p({ escape(table.concat(prefix)) }),
   }))


   return name
end

emit["record_declaration"] = function(prefix, n, out)
   local fields = {}
   local meta = {}
   local body = n:child_by_field_name("record_body")
   assertf(body, "record_body is nil for %s", tostring(n))

   local private_fields = {}

   for c in body:named_children() do
      if c:type() == "field" then
         local key = c:child_by_field_name("key")
         local is_string = false
         if not key then
            key = c:child_by_field_name("string_key")
            is_string = true
         end


         local is_private = key:source():sub(1, 1) == "_" or is_string and key:source():sub(2, 2) == "_"
         local t = c:child_by_field_name("type")
         table.insert(
         is_private and private_fields or fields,
         (is_string and "[%s]" or "%s"):format(key:source()) ..
         ": " .. t:source())

      elseif c:type() == "metamethod" then
         table.insert(
         meta,
         c:source())

      elseif c:type() == "record_array_type" then
         table.insert(
         fields,
         1,
         "{" .. c:child(0):source() .. "}")

      end
   end

   local obj_name = n:child_by_field_name("name"):source()

   local pre_contents = { "record ", obj_name }

   if #fields > 0 then
      table.insert(pre_contents, br .. "   " .. table.concat(fields, br .. "   "))
   end

   if #meta > 0 then
      if #fields > 0 then
         table.insert(pre_contents, br)
      end
      table.insert(pre_contents, br .. "   " .. table.concat(meta, br .. "   "))
   end

   if #private_fields > 0 then
      if #fields > 0 or #meta > 0 then
         table.insert(pre_contents, br)
      end
      table.insert(pre_contents, br .. "   <details><summary class=\"private-field-comment\">-- private fields</summary>" .. br .. "   ")
      table.insert(pre_contents, table.concat(private_fields, br .. "   "))
      table.insert(pre_contents, "</details>")
   end

   table.insert(pre_contents, br .. "end")

   table.insert(
   out,
   html({
      doc_header({ "type ", obj_name }, obj_name),
      pre(pre_contents),
      p({ escape(table.concat(prefix)) }),
   }))

   return obj_name
end

local query = teal_parser:query([[
   ((comment) @kind
     . (comment)* @docs
     . (_) @obj
     (#match? @kind "^%-%-%-@%w+$")
     (#is-not-comment? @obj)) ]]):
with({
   ["is-not-comment?"] = function(n)
      return n:type() ~= "comment"
   end,
})







local function gen_docs(filename, module_name)
   local root
   do
      local file = assert(filename, "No filename provided")
      local content = assert(fs.read(file))
      local tree = assert(teal_parser:parse_string(content))
      root = tree:root()
   end

   local docs = {}

   for match in query:match(root) do
      local kind_node = match.captures.kind
      local kind = kind_node:source():match("^%-%-%-@(%w+)")
      local comments = match.captures.docs or {}
      local obj = match.captures.obj
      if kind == "nodoc" then
         return
      end
      local lines = {}
      local content = {}
      local current_state
      local n_leading_spaces
      local function ins(str)
         if str:match("^%s*$") then return end
         table.insert(content, str)
      end
      for i, v in ipairs(comments) do
         local src = v:source()
         if not src:match("^%-%-%-") then
            break
         end
         local sub, rest = src:match("^%-%-%-@@(%w+)(.*)%s*$")

         if sub then
            if sub == "end" then
               if current_state == "table" then
                  ins("</table><p>")
               elseif current_state == "code" then
                  ins("</pre><p>")
               end
               current_state = nil
            elseif current_state then
               error("Attempt to use @@" .. sub .. " inside of @@" .. current_state)
            else
               current_state = sub
               if current_state == "table" then
                  ins("</p><table>")
                  local row = { "<tr>" }
                  for col in rest:gmatch("[^|]+") do
                     table.insert(row, "<th>" .. col .. "</th>")
                  end
                  table.insert(row, "</tr>")
                  ins(table.concat(row))
               elseif current_state == "code" then
                  ins("</p><pre>")
               end
            end
         else
            local leadingws, line = src:match("^%-%-%-(%s*)(.*)%s*$")
            if i == 1 then
               n_leading_spaces = #leadingws
            else
               line = leadingws:sub(n_leading_spaces + 1, -1) .. line
            end
            if current_state == "table" then
               local row = { "<tr>" }
               for col in line:gmatch("[^|]+") do
                  table.insert(row, "<td>" .. escape_html_chars(col) .. "</td>")
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

   local brief
   local sections = {}
   local table_of_contents = {}

   for _, d in ipairs(docs) do
      local node_kind = d.obj:type()
      if d.kind == "desc" then
         local name = emit[node_kind](d.content, d.obj, sections)
         table.insert(table_of_contents, html({
            a(name, { href = ("#%s"):format(name) }),
         }))
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
      cs.highlight(cs.colors.keyword, "---@nodoc"), " to silence this warning")

   end

   if #sections > 0 or brief then
      table.sort(sections)
      local res = {
         h2(a(module_name, { name = module_name })),
      }
      if brief then
         table.insert(res, p(brief))
      end
      table.insert(sections, 1, html(res))
      table.sort(table_of_contents)
      return table.concat(sections), table_of_contents
   end
end

local table_of_contents = {}
local table_of_contents_line_count = {}
local total_lines = 0
local output = {}
for path in fs.scan_dir("src", { "cyan/**/*" }) do
   local file = ("src" .. path):to_real_path()
   local mod = path:tostring():gsub("%.tl$", ""):gsub("/", "."):gsub("%.init$", "")
   local docs, toc = gen_docs(file, mod)
   if docs then
      info("Processed ", cs.highlight(cs.colors.file, path:tostring()))
      table.insert(table_of_contents, html({
         p({ a(mod, { href = ("#%s"):format(mod), class = "module-name" }),
br,
table.concat(toc, br), }),
      }))
      table.insert(table_of_contents_line_count, #toc)
      total_lines = total_lines + #toc
      table.insert(output, docs)
   end
end
table.sort(table_of_contents)

local columns = 3
local new_column_threshold = math.floor(total_lines / columns)

do
   local rows = 0
   for i = #table_of_contents, 1, -1 do
      rows = rows + table_of_contents_line_count[i]
      if rows >= new_column_threshold then
         table.insert(table_of_contents, i, "</td><td valign=top>")
         rows = 0
      end
   end
end

table.insert(table_of_contents, "</td>")
table.sort(output)

local final_table_of_contents = table.concat(table_of_contents)
local final_output = table.concat(output)

local final_blob = template:gsub(
"<!%-%-([%w ]+)%-%->",
function(match)
   if match == "TABLE OF CONTENTS" then
      return final_table_of_contents
   elseif match == "CONTENTS" then
      return final_output
   end

   return match
end)


local fh = assert(io.open(docfile:to_real_path(), "w"))
fh:write(final_blob)
fh:close()
info("Wrote ", cs.highlight(cs.colors.file, docfile:to_real_path()))
