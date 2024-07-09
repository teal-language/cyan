local _tl_compat; if (tonumber((_VERSION or ''):match('[%d.]*$')) or 0) < 5.3 then local p, m = true, require('compat53.module'); if p then _tl_compat = m end end; local io = _tl_compat and _tl_compat.io or io; local string = _tl_compat and _tl_compat.string or string


local log = require("cyan.log")
local util = require("cyan.util")
local decoration = require("cyan.decoration")

local ivalues = util.tab.ivalues

local interaction = {}

local affirmative = decoration.scheme.affirmative
local negative = decoration.scheme.negative

local yesses = { "yes", "yeah", "yea", "ye", "y" }
local nos = { "no", "nope", "n" }

local function title_case(s)
   return s:sub(1, 1):upper() .. s:sub(2, -1):lower()
end

local function to_string_set(list)
   local result = {}
   for v in ivalues(list) do
      result[v:lower()] = true
   end
   return result
end








function interaction.yes_no_prompt(
   prompt,
   logger,
   default,
   affirm,
   deny)

   logger = logger or log.info
   affirm = affirm or yesses
   deny = deny or nos

   local y = decoration.decorate(
   default and title_case(affirm[1]) or affirm[1]:lower(),
   affirmative)

   local n = decoration.decorate(
   default and deny[1]:lower() or title_case(deny[1]),
   negative)

   local affirm_set = to_string_set(affirm)
   local deny_set = to_string_set(deny)

   while true do
      logger:nonl(prompt, " [", y, "/", n, "]: ")
      logger.stream:flush()
      local input = io.read("*l"):lower()

      if #input == 0 then
         logger:cont(
         "Defaulting to ",
         default and
         decoration.decorate(title_case(affirm[1]), affirmative) or
         decoration.decorate(title_case(deny[1]), negative))

         return default or false
      end

      if affirm_set[input] then
         return true
      end
      if deny_set[input] then
         return false
      end
   end
end

return interaction
