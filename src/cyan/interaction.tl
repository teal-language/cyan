---@brief
--- Module for handling when input from the user is needed

local log <const> = require("cyan.log")
local util <const> = require("cyan.util")
local decoration <const> = require("cyan.decoration")

local ivalues <const> = util.tab.ivalues

local interaction <const> = {}

local affirmative <const> = decoration.scheme.affirmative
local negative <const> = decoration.scheme.negative

local yesses <const> = { "yes", "yeah", "yea", "ye", "y" }
local nos <const> = { "no", "nope", "n" }

local function title_case(s: string): string
   return s:sub(1, 1):upper() .. s:sub(2, -1):lower()
end

local function to_string_set(list: {string}): {string:boolean}
   local result <const> = {}
   for v in ivalues(list) do
      result[v:lower()] = true
   end
   return result
end

---@desc
--- Ask the user to affirm or deny a given prompt. The user input will be
--- compared against the given `affirm` and `deny` lists (case-insensitive), with
--- defaults used if they are not provided.
---
--- The given logger will be used to print the prompt, and `log.info` if none
--- is provided.
function interaction.yes_no_prompt(
   prompt: string | decoration.Decorated,
   logger?: log.Logger,
   default?: boolean,
   affirm?: {string},
   deny?: {string}
): boolean
   logger = logger or log.info
   affirm = affirm or yesses
   deny = deny or nos

   local y <const> = decoration.decorate(
      default and title_case(affirm[1]) or affirm[1]:lower(),
      affirmative
   )
   local n <const> = decoration.decorate(
      default and deny[1]:lower() or title_case(deny[1]),
      negative
   )
   local affirm_set <const> = to_string_set(affirm)
   local deny_set <const> = to_string_set(deny)

   while true do
      logger:nonl(prompt, " [", y, "/", n, "]: ")
      logger.stream:flush()
      local input = io.read("*l"):lower()

      if #input == 0 then
         logger:cont(
            "Defaulting to ",
            default
               and decoration.decorate(title_case(affirm[1]), affirmative)
               or decoration.decorate(title_case(deny[1]), negative)
         )
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
