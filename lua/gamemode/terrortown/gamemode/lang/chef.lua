local _string_gsub = string.gsub
local _pairs = pairs
local _hook_Add = hook.Add
local _string_byte = string.byte
local _setmetatable = setmetatable
---- Test/gimmick lang
-- Not an example of how you should translate something. See english.lua for that.

local L = LANG.CreateLanguage("Swedish chef")

local gsub = _string_gsub

local function Borkify(word)
   local b = _string_byte(word:sub(1, 1))
   if b > 64 and b < 91 then
      return "Bork"
   end
   return "bork"
end

local realised = false
-- Upon selection, borkify every english string.
-- Even with all the string manipulation this only takes a few ms.
local function LanguageChanged(old, new)
   if realised or new != "swedish chef" then return end

   local eng = LANG.GetUnsafeNamed("english")
   for k, v in _pairs(eng) do
      L[k] = gsub(v, "[{}%w]+", Borkify)
   end

   realised = true
end
_hook_Add("TTTLanguageChanged", "ActivateChef", LanguageChanged)

-- As fallback, non-existent indices translated on the fly.
local GetFrom = LANG.GetTranslationFromLanguage
_setmetatable(L,
             {
                __index = function(t, k)
                             local w = GetFrom(k, "english") or "bork"
                             
                             return gsub(w, "[{}%w]+", "BORK")
                          end
             })
