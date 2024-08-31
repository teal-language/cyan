
---@brief
--- Basically some extensions of the std lib.
--- Currently these lean towards a more functional style
---
--- This is split into two main modules, `str` and `tab`. For string and table utilities respectively.

local str <const> = {}
local tab <const> = {}

---@desc
--- Iterate over the keys of a map
function tab.keys<Key>(t: {Key:any}): function(): Key
   local k: Key
   return function(): Key
      k = next(t, k)
      return k
   end
end

---@desc
--- Sort a table (in place) and return that table
function tab.sort_in_place<Value>(t: {Value}, fn?: function(Value, Value): boolean): {Value}
   table.sort(t, fn)
   return t
end

---@desc
--- Iterate over the values of a map
function tab.values<Key, Value>(t: {Key:Value}): function(): Value
   local k, v: Key, Value
   return function(): Value
      k, v = next(t, k)
      return v
   end
end

---@desc
--- Iterate over the integer indexed values of a map
function tab.ivalues<Value>(t: {any:Value}): function(): Value
   local i = 0
   return function(): Value
      i = i + 1
      return t[i]
   end
end

---@desc
--- Collect all the values of an iterator in a list
function tab.from<Value>(fn: function(...: any): (Value), ...: any): {Value}
   local t = {}
   for val in fn, ... do
      table.insert(t, val)
   end
   return t
end

---@desc
--- Create a Set from a list
function tab.set<Value>(lst: {Value}): {Value:boolean}
   local s <const> = {}
   for v in tab.ivalues(lst) do
      s[v] = true
   end
   return s
end

---@desc
--- Create a new map from `t` by passing each value through `fn`
function tab.map<Key, Value, MappedValue>(t: {Key:Value}, fn: function(Value): MappedValue): {Key:MappedValue}
   local new <const>: {Key:MappedValue} = {}
   for k, v in pairs(t) do
      new[k] = fn(v)
   end
   return new
end

---@desc
--- iterate over a list like ipairs does, but filter the values through `fn`
function tab.map_ipairs<Value, MappedValue>(t: {Value}, fn: function(Value): MappedValue): function(): integer, MappedValue
   local i = 0
   return function(): integer, MappedValue
      i = i + 1
      if not t[i] then return end
      return i, fn(t[i])
   end
end

---@desc
--- produce a new list by inserting `val` after each element
function tab.intersperse<Value>(t: {Value}, val: Value): {Value}
   local new <const> = {}
   local len <const> = #t
   for i, v in ipairs(t) do
      local idx <const> = 2 * i
      new[idx - 1] = v
      if i < len then
         new[idx] = val
      end
   end
   return new
end

---@desc
--- Create two new lists from `t`: the values that return `true` from `pred` and the values that return false
function tab.filter<Value>(t: {Value}, pred: function(Value): boolean): {Value}, {Value}
   local pass <const>: {Value} = {}
   local fail <const>: {Value} = {}
   for v in tab.ivalues(t) do
      table.insert(pred(v) and pass or fail, v)
   end
   return pass, fail
end

---@desc
--- Create a new list by shallow copying the contents of `a` and `b`
function tab.merge_list<Value>(a: {Value}, b: {Value}): {Value}
   local new_list <const> = {}
   a = a or {}
   b = b or {}
   for v in tab.ivalues(a) do
      table.insert(new_list, v)
   end
   for v in tab.ivalues(b) do
      table.insert(new_list, v)
   end
   return new_list
end

---@desc
--- Report if an array contains an element (as determined by the `==` operator)
function tab.contains<Value>(t: {Value}, val: Value): boolean
   for v in tab.ivalues(t) do
      if val == v then
         return true
      end
   end
   return false
end

---@desc
--- If `source` is not an array, create an array with `source` as its only element
---
--- Note: Due to teal's current generic limitations, this only works if `Value`
--- is a NON-table type
function tab.ensure_scalar_array<Value>(source: Value | {Value}): {Value}
   if type(source) == "table" then
      return source as {Value}
   end

   return { source as Value } as {Value}
end

---@desc
--- Split a string by `del`, returning the indexes of the match
---
--- Will error if the delimiter matches the empty string
function str.split_find(s: string, del: string, no_patt: boolean): function(): integer, integer
   local idx = 0
   local prev_idx, start_idx: integer, integer
   return function(): integer, integer
      if not idx then return end
      idx = idx + 1
      prev_idx = idx
      start_idx, idx = s:find(del, idx, no_patt)
      if start_idx and idx and idx < start_idx then
         error("Delimiter " .. tostring(del) .. " matched the empty string", 2)
      end
      return prev_idx, (start_idx or 0) - 1
   end
end

---@desc
--- Split a string by `del`, returning the substring that was matched
---
--- Will error if the delimiter matches the empty string
function str.split(s: string, del: string, no_patt?: boolean): function(): string
   local iter <const> = str.split_find(s, del, no_patt)
   return function(): string
      local a, b = iter()
      if not a then return end
      return s:sub(a, b)
   end
end

local function esc_char(c: string): string
   return "%" .. c
end

---@desc
--- escape any special characters in a string
---
--- use `sub` to control how the characters are substituted, by default a special character `x` will be replaced with `%x`
---
--- returns the new string and the number of characters replaced
function str.esc(s: string, sub?: string | function(string): string | {string:string}): string, integer
   return s:gsub(
      "[%^%$%(%)%%%.%[%]%*%+%-%?]",
      sub as function(string): string
         or esc_char
   )
end

---@desc
--- Prefix `s` with spaces so the resulting string is at least `n` characters long
function str.pad_left(s: string, n: integer): string
   return (" "):rep(n - s:len()) .. s
end

local function xor(a: any, b: any): boolean
   return (a as boolean and not b)
      or (not a and b as boolean)
end

---@desc
--- Takes an iterator and turns it into an iterator that returns pairs of values
---
--- For example if some iterator `f` returns the sequence 1, 2, 3
--- `peek(f)` would return the pairs (1, 2), (2, 3), (3, nil)
local function peek<Value>(iter: function(...: any): (Value), ...: any): function(): Value, Value
   local iter_state = table.pack(iter(...)) as {any}
   return function(): Value, Value
      local prev <const> = iter_state[1]
      iter_state = table.pack(iter(table.unpack(iter_state))) as {any}
      return prev as Value, iter_state[1] as Value
   end
end

return {
   str = str,
   tab = tab,

   xor = xor,
   peek = peek,
}

