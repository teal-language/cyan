
-- Basically some extensions of the std lib
-- Currently these lean towards a more functional style

local str <const> = {}
local tab <const> = {}

function tab.keys<K>(t: {K:any}): function(): K
   local k: K
   return function(): K
      k = next(t, k)
      return k
   end
end

function tab.sort<T>(t: {T}, fn: function(T, T): boolean): {T}
   table.sort(t, fn)
   return t
end

function tab.values<K, V>(t: {K:V}): function(): V
   local k, v: K, V
   return function(): V
      k, v = next(t, k)
      return v
   end
end

function tab.ivalues<V>(t: {any:V}): function(): V
   local iter = ipairs(t as {V})
   return function(): V
      return select(2, iter()) as V
   end
end

function tab.from<T>(fn: function(...: any): (T), ...: any): {T}
   local t = {}
   for val in fn, ... do
      table.insert(t, val)
   end
   return t
end

function tab.map<K, V, T>(t: {K:V}, fn: function(V): T): {K:T}
   local new <const>: {K:T} = {}
   for k, v in pairs(t) do
      new[k] = fn(v)
   end
   return new
end

function tab.filter<K, V>(t: {K:V}, pred: function(V): boolean): {K:V}, {K:V}
   local pass <const>: {K:V} = {}
   local fail <const>: {K:V} = {}
   for k, v in pairs(t) do
      (pred(v) and pass or fail)[k] = v
   end
   return pass, fail
end

function str.split(s: string, del: string, no_patt: boolean): function(): string
   local idx = 0
   local prev_idx, start_idx: number, number
   return function(): string
      if not idx then return end
      idx = idx + 1
      prev_idx = idx
      start_idx, idx = s:find(del, idx, no_patt)
      if start_idx and idx and idx < start_idx then
         error("Delimiter " .. tostring(del) .. " matched the empty string", 2)
      end
      return s:sub(prev_idx, (start_idx or 0) - 1)
   end
end

local function esc_char(c: string): string
   return "%" .. c
end
function str.esc(s: string, sub: string | function(string): string | {string:string}): string, number
   return s:gsub(
      "[%^%$%(%)%%%.%[%]%*%+%-%?]",
      sub as function(string): string
         or esc_char
   )
end

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

