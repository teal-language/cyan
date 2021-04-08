
-- TODO: markdown looks a little odd, should probably generate html at somepoint
local run_on = { "build:post" }

local log <const> = require("cyan.log")
local fs <const> = require("cyan.fs")
local cs <const> = require("cyan.colorstring")

local has_ltreesitter <const>, ts <const> = pcall(require, "ltreesitter")
if not has_ltreesitter then
   return {
      run_on = { "build:post" },
      exec = function()
         log.warn("docgen requires the ltreesitter module, which lua was unable to find\n", ts as string)
      end,
   }
end

local has_teal_parser <const>, teal_parser <const> = pcall(ts.require, "teal")
if not has_teal_parser then
   return {
      run_on = run_on,
      exec = function()
         log.warn("docgen requires tree-sitter-teal, which ltreesitter could not find:\n", teal_parser as string)
      end,
   }
end

local docfile <const> = fs.path.new("docs/api.md")
local type Emitter = function(prefix: {string}, object: ts.Node, output: {string})

local function assertf(val: any, fmt: string, ...: any)
   assert(val, fmt:format(...))
end

local emit: {string:Emitter} = setmetatable({}, {
   __newindex = function(self: {string:Emitter}, name: string, emitter: Emitter)
      -- wrap all functions in these asserts
      rawset(self, name, function(pre: {string}, n: ts.Node, out: {string})
         assertf(pre, "nil prefix for emitter %q", name)
         assertf(n, "nil node for emitter %q", name)
         assertf(out, "nil output for emitter %q", name)

         assertf(n:type() == name, "Wrong node type (%q) for emitter %q", n:type(), name)

         emitter(pre, n, out)
      end)
   end,
   __index = function(_: {string:Emitter}, name: string)
      error(("No emitter for node %q"):format(name))
   end,
})

emit["function_statement"] = function(prefix: {string}, n: ts.Node, out: {string})
   local sig <const> = n:child_by_field_name("signature")
   local ret <const> = sig:child_by_field_name("return_type")

   table.insert(
      out,
      "#### `"
         .. n:child_by_field_name("name"):source()
         .. sig:child_by_field_name("arguments"):source()
         .. (ret and ": " .. ret:source() or "")
         .. "`"
         .. "\n"
         .. table.concat(prefix, "\n\n")
         .. "\n\n"
   )
end

emit["record_declaration"] = function(prefix: {string}, n: ts.Node, out: {string})
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
   table.insert(
      out,
      "#### `record "
         .. n:child_by_field_name("name"):source()
         .. "`\n```\n"
         .. table.concat(meta, "\n")
         .. "\n"
         .. table.concat(fields, "\n")
         .. "\n```\n"
         .. table.concat(prefix, "\n\n")
         .. "\n\n"
   )
end

local function exec()
   local query <const> = teal_parser:query[[
      ((comment)+ @com
        . (_) @obj
        (#match? @com "^%-%-%-@%w+$")) ]]

   local record Doc
      kind: string
      content: {string}
      obj: ts.Node
   end

   local function gen_docs(filename: string, module_name: string): string
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

      local brief: string
      local sections <const>: {string} = {}

      for _, d in ipairs(docs) do
         local node_kind <const> = d.obj:type()
         if d.kind == "desc" then
            emit[node_kind](d.content, d.obj, sections)
         elseif d.kind == "brief" then
            brief = table.concat(d.content, "\n\n") .. "\n\n"
         else
            log.warn("Unhandled node kind: ", node_kind)
         end
      end

      if #sections > 0 then
         table.sort(sections)
         table.insert(sections, 1, "## `" .. module_name .. "`\n---\n\n" .. (brief or ""))

         return table.concat(sections)
      end
   end

   local output <const> = {}
   for p in fs.scan_dir("src", {"cyan/**/*"}) do
      local file <const> = ("src" .. p):to_real_path()
      local mod <const> = p:tostring():gsub("%.tl$", ""):gsub("/", "."):gsub("%.init$", "")
      local docs <const> = gen_docs(file, mod)
      if docs then
         log.info("Generated docs for ", cs.highlight(cs.colors.file, p:tostring()))
         table.insert(output, docs)
      end
   end
   table.sort(output)
   local fh <const> = assert(io.open(docfile:to_real_path(), "w"))
   fh:write(
      "# Api Documentation\n",
      "This documentation is autogenerated and may be incomplete\n\n"
   )
   fh:write(table.concat(output))
   fh:close()
   log.info("Wrote ", cs.highlight(cs.colors.file, docfile:to_real_path()))
end

return {
   run_on = { "build:post" },
   exec = exec,
}
