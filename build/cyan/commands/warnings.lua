local _tl_compat; if (tonumber((_VERSION or ''):match('[%d.]*$')) or 0) < 5.3 then local p, m = true, require('compat53.module'); if p then _tl_compat = m end end; local table = _tl_compat and _tl_compat.table or table; local _tl_table_unpack = unpack or table.unpack




local command = require("cyan.command")
local config = require("cyan.config")
local decoration = require("cyan.decoration")
local log = require("cyan.log")
local tl = require("tl")
local util = require("cyan.util")

local pad_left = util.str.pad_left
local values, set, keys, from, sort =
util.tab.values, util.tab.set, util.tab.keys, util.tab.from, util.tab.sort_in_place

local function exec(_, c)
   local disable = set(c.disable_warnings or {})
   local err = set(c.warning_error or {})
   local longest_len = 0
   local tags = sort(from(keys(tl.warning_kinds)))
   for t in values(tags) do
      if #(t) > longest_len then
         longest_len = #(t)
      end
   end
   local buf = {}
   for t in values(tags) do
      local padded = pad_left(t, longest_len)
      table.insert(buf, padded)
      table.insert(buf, ": ")
      if disable[t] then
         table.insert(buf, decoration.decorate("disabled", decoration.scheme.red))
      elseif err[t] then
         table.insert(buf, decoration.decorate("enabled", decoration.scheme.green))
         table.insert(buf, " (as error)")
      else
         table.insert(buf, decoration.decorate("enabled", decoration.scheme.green))
      end
      table.insert(buf, "\n")
   end
   table.remove(buf)

   log.info(_tl_table_unpack(buf))
   return 0
end

command.new({
   name = "warnings",
   description = [[List all warnings the Teal compiler can produce and whether or not they are enabled.]],
   exec = exec,
})
