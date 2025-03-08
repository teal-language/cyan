local decoration <const> = require("cyan.decoration")
local fs <const> = require("cyan.fs")
local log <const> = require("cyan.log")
local util <const> = require("cyan.util")
local keys <const> = util.tab.keys

local info = log.create_logger(
   io.stdout,
   "normal",
   decoration.decorate("Docgen", decoration.scheme.bright_cyan),
   decoration.decorate("...", decoration.scheme.bright_cyan)
)

local has_ltreesitter <const>, ts <const> = pcall(require, "ltreesitter")
if not has_ltreesitter then
   log.warn("docgen requires the ltreesitter module, which lua was unable to find\n", ts as string)
   return
end

local has_teal_parser <const>, teal_parser <const> = pcall(ts.require, "parser/teal", "teal")
if not has_teal_parser then
   log.warn("docgen requires tree-sitter-teal, which ltreesitter could not find:\n", teal_parser as string)
   return
end

local template_file <const> = fs.path.new("doc-template.html", false)
local template <const> = assert(fs.read(template_file:to_real_path()))

local docfile <const> = fs.path.new("docs/index.html", false)
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
local function tag_wrapper(name: string): function(string | TagTree, ?{string:string}): TagTree
   return function(content: string | TagTree, attrs?: {string:string}): TagTree
      if content is string then
         content = { content }
      end
      local start = { "<", name }
      if attrs then
         local attr_keys <const> = util.tab.from(keys(attrs))
         table.sort(attr_keys)
         for _, key in ipairs(attr_keys) do
            table.insert(start, (" %s=%s"):format(key, attrs[key]))
         end
      end
      table.insert(start, ">")
      table.insert(content as TagTree, 1, start)
      table.insert(content as TagTree, "</" .. name .. ">\n")
      return content as TagTree
   end
end
local _h1 <const> = tag_wrapper "h1"
local h2 <const> = tag_wrapper "h2"
local h3 <const> = tag_wrapper "h3"
local _h4 <const> = tag_wrapper "h4"
local _pre <const> = tag_wrapper "pre"
local p <const> = tag_wrapper "p"
local a <const> = tag_wrapper "a"
local br <const> = "<br>"
local function bullet_header(content: string | TagTree, name: string): TagTree
   return h3(a({ "<code class=bulleted>", content, "</code>" }, { name = name }))
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

local function escape(str: string): string
   return (str:gsub("\n\n", br)
              :gsub("`(.-)`", "<code>%1</code>")
              :gsub("([\"'])([^%1]-)%1", "<code>%1%2%1</code>"))
end

local html_escape_map <const> = {
   ["<"] = "&lt;",
   [">"] = "&gt;",
   ["'"] = "&apos;",
   ['"'] = "&quot;",
   ['&'] = "&amp;",
}

local function escape_html_chars(str: string): string, integer
   return str:gsub("[<>'\"&]", html_escape_map)
end

local function begin_signature_and_description(name: string, keyword: string): {string}
   local data = {
      "<div class=description>",
      "<pre class=signature><code>",
      "<code class=keyword>", assert(keyword), "</code> ", assert(name),
   }

   return data
end

local function end_signature_and_description(
   name: string,
   link_name: string,
   data: {string},
   content: string | TagTree
): string
   return html {
      bullet_header(name, link_name),
      data,
      "</code></pre>",
      content,
      "</div>",
   }
end

emit["function_statement"] = function(prefix: {string}, n: ts.Node, out: {string}): string
   local sig <const> = n:child_by_field_name("signature")
   local ret <const> = sig:child_by_field_name("return_type")
   local typeargs <const> = sig:child_by_field_name("typeargs")
   local name <const> = n:child_by_field_name("name"):source()

   local data = begin_signature_and_description(name, "function")
   local first = true

   if typeargs then
      table.insert(data, (escape_html_chars "<"))
      for child in typeargs:named_children() do
         if not first then
            table.insert(data, ", ")
         end
         table.insert(data, "<code class=parameter-type>")
         table.insert(data, child:source())
         table.insert(data, "</code>")
         first = false
      end
      table.insert(data, (escape_html_chars ">"))
   end

   table.insert(data, "(")

   first = true
   for child in sig:child_by_field_name("arguments"):named_children() do
      local parameter_name <const> = child:child_by_field_name("name")
      local ty <const> = assert(child:child_by_field_name("type")):source()
      if not first then
         table.insert(data, ",")
      end
      table.insert(data, "\n\t<code class=parameter-name>")
      table.insert(data, parameter_name and parameter_name:source() or "...")
      table.insert(data, "</code>: <code class=parameter-type>")
      table.insert(data, ty)
      table.insert(data, "</code>")

      first = false
   end

   table.insert(data, first and ")" or "\n)")

   if ret then
      table.insert(data, ": ")
      first = true
      for t in ret:named_children() do
         if not first then
            table.insert(data, ", ")
         end
         table.insert(data, "<code class=parameter-type>" .. t:source() .. "</code>")
         first = false
      end
   end

   table.insert(
      out,
      end_signature_and_description(
         (name:match(":") and "method " or "function ") .. name,
         name,
         data,
         p { escape(table.concat(prefix)) }
      )
   )
   return name
end

emit["enum_declaration"] = function(prefix: {string}, n: ts.Node, out: {string}): string
   local body <const> = n:child_by_field_name("enum_body")
   assertf(body, "enum_body is nil for %s", tostring(n));

   local name <const> = n:child_by_field_name("name"):source()

   local data = begin_signature_and_description(name, "enum")
   table.insert(data, "\n")

   for child in body:named_children() do
      table.insert(data, "\t<code class=string>" .. child:source() .. "</code>\n")
   end

   table.insert(data, "<code class=keyword>end</code>")

   table.insert(
      out,
      end_signature_and_description("type " .. name, name, data, p { escape(table.concat(prefix)) })
   )

   return name
end

emit["record_declaration"] = function(prefix: {string}, n: ts.Node, out: {string}): string
   local meta <const> = {}
   local body <const> = n:child_by_field_name("record_body")
   assertf(body, "record_body is nil for %s", tostring(n))

   local fields <const>: {string} = {}
   local private_fields <const>: {string} = {}

   for c in body:named_children() do
      if c:type() == "field" then
         local key = c:child_by_field_name("key")
         local is_string = false
         if not key then
            key = c:child_by_field_name("string_key")
            is_string = true
         end

         -- FIXME: properly parse out the key when it is a string
         local is_private <const> = key:source():sub(1, 1) == "_" or is_string and key:source():sub(2, 2) == "_"
         local t = c:child_by_field_name("type")
         table.insert(
            is_private and private_fields or fields,
            (is_string and "[%s]" or "%s"):format(key:source())
               .. ": <code class=parameter-type>" .. t:source() .. "</code>"
         )
      elseif c:type() == "metamethod" then
         table.insert(
            meta,
            "<code class=keyword>metamethod</code> "
               .. c:child_by_field_name("name"):source()
               .. ": <code class=parameter-type>"
               .. c:child_by_field_name("type"):source()
               .. "</code>"
         )
      elseif c:type() == "record_array_type" then
         table.insert(
            fields,
            1,
            "<code class=parameter-type>{" .. c:child(0):source() .. "}</code>"
         )
      end
   end

   local obj_name <const> = n:child_by_field_name("name"):source()

   local data = begin_signature_and_description(obj_name, "record")

   if #fields > 0 then
      table.insert(data, "\n\t" .. table.concat(fields, "\n\t"))
   end

   if #meta > 0 then
      if #fields > 0 then
         table.insert(data, "\n")
      end
      table.insert(data, "\n\t" .. table.concat(meta, "\n\t"))
   end

   if #private_fields > 0 then
      if #fields > 0 or #meta > 0 then
         table.insert(data, br)
      end
      table.insert(data, "\n<details><summary class=\"private-field-comment\">\t-- private fields (click to show)</summary>\n\t")
      table.insert(data, table.concat(private_fields, "\n\t"))
      table.insert(data, "</details>")
   end

   table.insert(data, "\n<code class=keyword>end</code>")

   table.insert(
      out,
      end_signature_and_description("type " .. obj_name, obj_name, data, p { escape(table.concat(prefix)) })
   )
   return obj_name
end

emit["type_declaration"] = function(prefix: {string}, n: ts.Node, out: {string}): string
   local obj_name <const> = n:child_by_field_name("name"):source()
   local data = begin_signature_and_description(obj_name, "type")
   local value <const> = n:child_by_field_name("value")

   -- TODO: This could be rendered better
   table.insert(data, "<code class=parameter-type>")
   table.insert(data, value:source())
   table.insert(data, "</code>")

   table.insert(
      out,
      end_signature_and_description("type " .. obj_name, obj_name, data, p { escape(table.concat(prefix)) })
   )

   return obj_name
end

local query <const> = teal_parser:query[[
   ((comment) @kind
     . (comment)* @docs
     . (_) @obj
     (#match? @kind "^%-%-%-@%w+$")
     (#is-not-comment? @obj)) ]]
   :with {
      ["is-not-comment?"] = function(n: ts.Node): boolean
         return n:type() ~= "comment"
      end,
   }

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
      local tree <const> = assert(teal_parser:parse_string(content, nil))
      root = tree:root()
   end

   local docs <const>: {Doc} = {}

   local match_iter = query.match as function(ts.Query, ts.Node): (function(): ts.Match)

   for match in match_iter(query, root) do
      local kind_node <const> = match.captures.kind as ts.Node
      local kind <const> = kind_node:source():match("^%-%-%-@(%w+)")
      local comments <const> = match.captures.docs as {ts.Node} or {}
      local obj <const> = match.captures.obj as ts.Node
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
      for i, v in ipairs(comments) do
         local src <const> = v:source()
         if not src:match("^%-%-%-") then
            break
         end
         local sub <const>, rest <const> = src:match("^%-%-%-@@(%w+)(.*)%s*$")
         -- TODO: make a proper state machine for this
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
                  local row <const> = { "<tr>" }
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
            local leadingws <const>, line = src:match("^%-%-%-(%s*)(.*)%s*$")
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

   local brief: string
   local sections <const>: {string} = {}
   local table_of_contents <const>: {string} = {}

   for _, d in ipairs(docs) do
      local node_kind <const> = d.obj:type()
      if d.kind == "desc" then
         local name <const> = emit[node_kind](d.content, d.obj, sections)
         table.insert(table_of_contents, html {
            a (name, { href = ("#%s"):format(name) }),
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
         decoration.decorate("---@brief", decoration.scheme.keyword),
         "\n   If this is intentional, use ",
         decoration.decorate("---@nodoc", decoration.scheme.keyword),
         " to silence this warning"
      )
   end

   if #sections > 0 or brief as boolean then
      table.sort(sections)
      local res: {string | TagTree} = {
         h2 (a (module_name, { name = module_name })),
      }
      if brief then
         table.insert(res, p(brief))
      end
      table.insert(sections, 1, html (res))
      table.sort(table_of_contents)
      return table.concat(sections), table_of_contents
   end
end

local table_of_contents <const> = {}
local table_of_contents_line_count <const>: {integer} = {}
local total_lines = 0
local output <const> = {}
for path in fs.scan_dir("src", {"cyan/**/*"}) do
   local file <const> = ("src" .. path):to_real_path()
   local mod <const> = path:tostring():gsub("%.tl$", ""):gsub("/", "."):gsub("%.init$", "")
   local docs <const>, toc <const> = gen_docs(file, mod)
   if docs then
      info("Processed ", decoration.file_name(path:tostring()))
      table.insert(table_of_contents, html {
         p { a (mod, { href = ("#%s"):format(mod), class = "module-name" }),
             br,
             table.concat(toc, br) }
      })
      table.insert(table_of_contents_line_count, #toc)
      total_lines = total_lines + #toc
      table.insert(output, docs)
   end
end
table.sort(table_of_contents)

local columns <const> = 3
local new_column_threshold <const> = math.floor(total_lines / columns)

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

local final_table_of_contents <const> = table.concat(table_of_contents)
local final_output <const> = table.concat(output)

local final_blob <const> = template:gsub(
   "<!%-%-([%w ]+)%-%->",
   function(match: string): string
      if match == "TABLE OF CONTENTS" then
         return final_table_of_contents
      elseif match == "CONTENTS" then
         return final_output
      end

      return match
   end
)

local fh <const>: FILE = io.open(docfile:to_real_path(), "w")
fh:write(final_blob)
fh:close()
info("Wrote ", decoration.file_name(docfile:to_real_path()))
