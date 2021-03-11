
---@brief
--- Basically some extensions of the std lib
--- Currently these lean towards a more functional style

local str <const> = {}
local tab <const> = {}

---@desc
--- Iterate over the keys of a map
function tab.keys<K>(t: {K:any}): function(): K
   local k: K
   return function(): K
      k = next(t, k)
      return k
   end
end

---@desc
--- Sort a table (in place) and return that table
function tab.sort<T>(t: {T}, fn: function(T, T): boolean): {T}
   table.sort(t, fn)
   return t
end

---@desc
--- Iterate over the values of a map
function tab.values<K, V>(t: {K:V}): function(): V
   local k, v: K, V
   return function(): V
      k, v = next(t, k)
      return v
   end
end

---@desc
--- Iterate over the integer indexed values of a map
function tab.ivalues<V>(t: {any:V}): function(): V
   local i = 0
   return function(): V
      i = i + 1
      return t[i]
   end
end

---@desc
--- Collect all the values of an iterator in a list
function tab.from<T>(fn: function(...: any): (T), ...: any): {T}
   local t = {}
   for val in fn, ... do
      table.insert(t, val)
   end
   return t
end

---@desc
--- Create a Set from a list
function tab.set<T>(lst: {T}): {T:boolean}
   local s <const> = {}
   for _, v in ipairs(lst) do
      s[v] = true
   end
   return s
end

---@desc
--- Create a Set from a list
function tab.map<K, V, T>(t: {K:V}, fn: function(V): T): {K:T}
   local new <const>: {K:T} = {}
   for k, v in pairs(t) do
      new[k] = fn(v)
   end
   return new
end

---@desc
--- iterate over a list like ipairs does, but filter the values through `fn`
function tab.map_ipairs<T, K>(t: {T}, fn: function(T): K): function(): number, K
   local i = 0
   return function(): number, K
      i = i + 1
      if not t[i] then
         return
      else
         return i, fn(t[i])
      end
   end
end

---@desc
--- Create two new lists from `t`: the values that return `true` from `pred` and the values that return false
function tab.filter<T>(t: {T}, pred: function(T): boolean): {T}, {T}
   local pass <const>: {T} = {}
   local fail <const>: {T} = {}
   for _, v in ipairs(t) do
      table.insert(pred(v) and pass or fail, v)
   end
   return pass, fail
end

---@desc
--- Split a string by `del`, returning the indexes of the match
---
--- Will error if the delimiter matches the empty string
function str.split_find(s: string, del: string, no_patt: boolean): function(): number, number
   local idx = 0
   local prev_idx, start_idx: number, number
   return function(): number, number
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
function str.split(s: string, del: string, no_patt: boolean): function(): string
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
function str.esc(s: string, sub: string | function(string): string | {string:string}): string, number
   return s:gsub(
      "[%^%$%(%)%%%.%[%]%*%+%-%?]",
      sub as function(string): string
         or esc_char
   )
end

---@desc
--- Prefix `s` with spaces so the resulting string is at least `n` characters long
function str.pad_left(s: string, n: number): string
   return (" "):rep(n - #s) .. s
end

local function xor(a: any, b: any): boolean
   return (a as boolean and not b)
      or (not a and b as boolean)
end

return {
   str = str,
   tab = tab,

   xor = xor,
}

