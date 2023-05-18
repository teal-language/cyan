local _tl_compat; if (tonumber((_VERSION or ''):match('[%d.]*$')) or 0) < 5.3 then local p, m = true, require('compat53.module'); if p then _tl_compat = m end end; local io = _tl_compat and _tl_compat.io or io; local ipairs = _tl_compat and _tl_compat.ipairs or ipairs; local string = _tl_compat and _tl_compat.string or string


local log = require("cyan.log")
local cs = require("cyan.colorstring")
local ansi = require("cyan.ansi")

local interaction = {}

local affirmative = { ansi.color.dark.green }
local negative = { ansi.color.dark.red }

local yesses = { "yes", "yeah", "yea", "ye", "y" }
local nos = { "no", "nope", "n" }

local function title_case(s)
   return s:sub(1, 1):upper() .. s:sub(2, -1):lower()
end

local function to_string_set(list)
   local result = {}
   for _, v in ipairs(list) do
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

   local y = cs.highlight(
   affirmative,
   default and title_case(affirm[1]) or affirm[1]:lower())

   local n = cs.highlight(
   negative,
   default and deny[1]:lower() or title_case(deny[1]))

   local prompt_str = prompt .. " [" .. y .. "/" .. n .. "]: "

   local affirm_set = to_string_set(affirm)
   local deny_set = to_string_set(deny)

   while true do
      logger:nonl(prompt_str)
      logger.stream:flush()
      local input = io.read("*l"):lower()

      if #input == 0 then
         logger:cont(
         "Defaulting to ",
         default and
         cs.highlight(affirmative, title_case(affirm[1])) or
         cs.highlight(negative, title_case(deny[1])))

         return default or false
      end

      if affirm_set[input] then
         return true
      elseif deny_set[input] then
         return false
      end
   end
end

return interaction
