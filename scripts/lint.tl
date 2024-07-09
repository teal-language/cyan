local common <const> = require("cyan.tlcommon")
local decoration <const> = require("cyan.experimental.decoration")
local fs <const> = require("cyan.fs")
local log <const> = require("cyan.log")
local util <const> = require("cyan.util")


local function lint()
   local info <const> = log.info:copy(
      decoration.decorate("Lint Info", decoration.scheme.bright_green),
      decoration.decorate("...", decoration.scheme.bright_green)
   )
   local warn <const> = log.warn:copy(
      decoration.decorate("Lint Error", decoration.scheme.warn),
      decoration.decorate("...", decoration.scheme.warn)
   )

   local has_ltreesitter <const>, ts <const> = pcall(require, "ltreesitter")
   if not has_ltreesitter then
      warn("lint requires the ltreesitter module, which lua was unable to find\n", ts as string)
      return
   end

   local has_teal_parser <const>, teal_parser <const> = pcall(ts.require, "teal")
   if not has_teal_parser then
      warn("lint requires tree-sitter-teal, which ltreesitter could not find:\n", teal_parser as string)
      return
   end

   local record Point -- one based, ts.Point is zero based
      row: integer
      column: integer
   end
   local function to_one_indexed(p: ts.Point): Point
      return { row = p.row + 1, column = p.column + 1 }
   end

   local record Error
      location: Point
      what: string
      helpful_message: string
   end
   local errors: {Error}

   local query <const> = teal_parser:query [[
      ((if_statement condition: (_)
         [ (return_statement) (break) ] @return
         .
         [ (elseif_block) (else_block) ] @else)
       (#else-after-diverge @else @return))

      (((elseif_block condition: (_)
         [ (return_statement) (break) ] @return . )
         .
         [ (elseif_block) (else_block) ] @else)
       (#else-after-diverge @else @return))

      ((var_declaration
         (var_declarators
            (var (identifier) @name) @declarator)
         (expressions
            (function_call
               called_object: (identifier) @req
               (_))))

        (#eq? @req "require")
        (#require-should-be-const @name @declarator))

      ((generic_for_statement
         variable: (identifier) @underscore
         iterator: (function_call called_object: (identifier) @ipairs))

       (#eq? @underscore "_")
       (#eq? @ipairs "ipairs")
       (#use-ivalues-to-ignore-key @ipairs))

      ((identifier) @id
       (#match? @id "^[_a-z].*[a-z][A-Z]")
       (#use-snake-case @id))

      ((number) @num
       (#match? @num "^0x")
       (#check-hex-case @num))
   ]]:with {
      ["else-after-diverge"] = function(else_: ts.Node, ret_or_break: ts.Node)
         local start = else_:start_point()
         local name = ret_or_break:name() == "break" and "break" or "return"
         table.insert(errors, {
            location = to_one_indexed(start),
            what = "else-after-diverge",
            helpful_message = else_:name() == "elseif_block"
               and "This elseif is directly after a " .. name .. " and could be simplified to a new if statement"
               or "This else is directly after a " .. name .. " and could be removed"
         })
      end,

      ["require-should-be-const"] = function(name: ts.Node, declarator: ts.Node)
         local attr = declarator:child_by_field_name("attribute")
         if not attr or attr:source() ~= "const" then
            local start = name:start_point()
            table.insert(errors, {
               location = to_one_indexed(start),
               what = "require-should-be-const",
               helpful_message = "Required modules should be annotated as <const>",
            })
         end
      end,

      ["use-ivalues-to-ignore-key"] = function(ipairs_node: ts.Node)
         local start = ipairs_node:start_point()
         table.insert(errors, {
            location = to_one_indexed(start),
            what = "use-ivalues-to-ignore-key",
            helpful_message = "cyan.util.tab provides the ivalues function to discard keys from ipairs",
         })
      end,

      ["use-snake-case"] = function(id: ts.Node)
         local start = id:start_point()
         table.insert(errors, {
            location = to_one_indexed(start),
            what = "use-snake-case",
            helpful_message = "This codebase uses snake_case for variable names, and PascalCase for types",
         })
      end,
      ["check-hex-case"] = function(num: ts.Node)
         if not num:source():match("[A-F]") then
            return
         end
         local start = num:start_point()
         table.insert(errors, {
            location = to_one_indexed(start),
            what = "use-lower-case-for-hex",
            helpful_message = "This codebase uses lower case for hexadecimal digits",
         })
      end,
   }

   local total_errors = 0
   local counts: {string:integer} = {}

   for path in fs.scan_dir(".", {"src/cyan/**/*"}) do
      errors = {}
      local real_path <const> = path:to_real_path()
      local disp_path <const> = decoration.file_name(real_path)
      local text <const> = fs.read(real_path)
      local root <const> = teal_parser:parse_string(text):root()
      query:exec(root)
      total_errors = total_errors + #errors
      if #errors > 0 then
         warn(table.unpack(common.make_error_header(real_path, #errors, "lint")))
         for err in util.tab.values(errors) do
            counts[err.what] = 1 + (counts[err.what] or 0)
            warn:cont(
               disp_path, ":", err.location.row, ":", err.location.column, " [", decoration.decorate(err.what, decoration.scheme.emphasis),
               "]\n         ┌"
            )

            for line_number in util.tab.values{ err.location.row - 1, err.location.row, err.location.row + 1 } do
               if line_number > 0 then
                  local line <const> = fs.get_line(real_path, line_number)
                  warn:cont(
                     line_number == err.location.row
                        and decoration.decorate(">>> ", decoration.scheme.error)
                        or decoration.decorate("    ", {}),
                     decoration.decorate(util.str.pad_left(tostring(line_number), 4), decoration.scheme.number),
                     " │ ",
                     table.unpack(common.syntax_highlight(line))
                  )
               end
            end

            warn:cont(
               "         │\n",
               "         └ ", decoration.decorate(err.helpful_message, decoration.scheme.error), "\n"
            )
         end
      else
         info("Checked ", decoration.file_name(real_path))
      end
   end

   if total_errors == 0 then
      info("Lint passed")
   else
      warn("Found a total of ", decoration.decorate(total_errors .. " lint" .. (total_errors ~= 1 and "s" or ""), decoration.scheme.emphasis))
      for k, v in pairs(counts) do
         warn:cont("   [", decoration.decorate(k, decoration.scheme.emphasis), "] = ", v)
      end
   end
end

lint()
