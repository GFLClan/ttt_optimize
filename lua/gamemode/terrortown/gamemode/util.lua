local _GetGlobalInt = GetGlobalInt
local _Msg = Msg
local _istable = istable
local _table_Copy = table.Copy
local _math_Clamp = math.Clamp
local _util_Decal = util.Decal
local _RunConsoleCommand = RunConsoleCommand
local _AddCSLuaFile = AddCSLuaFile
local _math_floor = math.floor
local _string_format = string.format
local _table_insert = table.insert
local _math_exp = math.exp
local _ScrW = (CLIENT and ScrW or nil)
local _bit_band = bit.band
local _timer_Remove = timer.Remove
local _string_sub = string.sub
local _player_GetAll = player.GetAll
local _math_Round = math.Round
local _Vector = Vector
local _math_random = math.random
local _pairs = pairs
local _VectorRand = VectorRand
local _util_TraceLine = util.TraceLine
local _EffectData = EffectData
local _IsValid = IsValid
local _include = include
local _string_gsub = string.gsub
local _Color = Color
local _ipairs = ipairs
local _timer_Create = timer.Create
local _Sound = Sound
local _tostring = tostring
local _ScrH = (CLIENT and ScrH or nil)
local _string_upper = string.upper
local _util_Effect = util.Effect
-- Random stuff

if not util then return end

local math = math
local string = string
local table = table
local pairs = _pairs

-- attempts to get the weapon used from a DamageInfo instance needed because the
-- GetAmmoType value is useless and inflictor isn't properly set (yet)
function util.WeaponFromDamage(dmg)
   local inf = dmg:GetInflictor()
   local wep = nil
   if _IsValid(inf) then
      if inf:IsWeapon() or inf.Projectile then
         wep = inf
      elseif dmg:IsDamageType(DMG_DIRECT) or dmg:IsDamageType(DMG_CRUSH) then
         -- DMG_DIRECT is the player burning, no weapon involved
         -- DMG_CRUSH is physics or falling on someone
         wep = nil
      elseif inf:IsPlayer() then
         wep = inf:GetActiveWeapon()
         if not _IsValid(wep) then
            -- this may have been a dying shot, in which case we need a
            -- workaround to find the weapon because it was dropped on death
            wep = _IsValid(inf.dying_wep) and inf.dying_wep or nil
         end
      end
   end

   return wep
end

-- Gets the table for a SWEP or a weapon-SENT (throwing knife), so not
-- equivalent to weapons.Get. Do not modify the table returned by this, consider
-- as read-only.
function util.WeaponForClass(cls)
   local wep = weapons.GetStored(cls)

   if not wep then
      wep = scripted_ents.GetStored(cls)
      if wep then
         -- don't like to rely on this, but the alternative is
         -- scripted_ents.Get which does a full table copy, so only do
         -- that as last resort
         wep = wep.t or scripted_ents.Get(cls)
      end
   end

   return wep
end

function util.GetAlivePlayers()
   local alive = {}
   for k, p in _ipairs(_player_GetAll()) do
      if _IsValid(p) and p:Alive() and p:IsTerror() then
         _table_insert(alive, p)
      end
   end

   return alive
end

function util.GetNextAlivePlayer(ply)
   local alive = util.GetAlivePlayers()

   if #alive < 1 then return nil end

   local prev = nil
   local choice = nil

   if _IsValid(ply) then
      for k,p in _ipairs(alive) do
         if prev == ply then
            choice = p
         end

         prev = p
      end
   end

   if not _IsValid(choice) then
      choice = alive[1]
   end

   return choice
end

-- Uppercases the first character only
function string.Capitalize(str)
   return _string_upper(_string_sub(str, 1, 1)) .. _string_sub(str, 2)
end
util.Capitalize = string.Capitalize

-- Color unpacking
function clr(color) return color.r, color.g, color.b, color.a; end

if CLIENT then
   -- Is screenpos on screen?
   function IsOffScreen(scrpos)
      return not scrpos.visible or scrpos.x < 0 or scrpos.y < 0 or scrpos.x > _ScrW() or scrpos.y > _ScrH()
   end
end

function AccessorFuncDT(tbl, varname, name)
   tbl["Get" .. name] = function(s) return s.dt and s.dt[varname] end
   tbl["Set" .. name] = function(s, v) if s.dt then s.dt[varname] = v end end
end

function util.PaintDown(start, effname, ignore)
   local btr = _util_TraceLine({start=start, endpos=(start + _Vector(0,0,-256)), filter=ignore, mask=MASK_SOLID})

   _util_Decal(effname, btr.HitPos+btr.HitNormal, btr.HitPos-btr.HitNormal)
end

local function DoBleed(ent)
   if not _IsValid(ent) or (ent:IsPlayer() and (not ent:Alive() or not ent:IsTerror())) then
      return
   end

   local jitter = _VectorRand() * 30
   jitter.z = 20

   util.PaintDown(ent:GetPos() + jitter, "Blood", ent)
end

-- Something hurt us, start bleeding for a bit depending on the amount
function util.StartBleeding(ent, dmg, t)
   if dmg < 5 or not _IsValid(ent) then
      return
   end

   if ent:IsPlayer() and (not ent:Alive() or not ent:IsTerror()) then
      return
   end

   local times = _math_Clamp(_math_Round(dmg / 15), 1, 20)

   local delay = _math_Clamp(t / times , 0.1, 2)

   if ent:IsPlayer() then
      times = times * 2
      delay = delay / 2
   end

   _timer_Create("bleed" .. ent:EntIndex(), delay, times,
                function() DoBleed(ent) end)
end

function util.StopBleeding(ent)
   _timer_Remove("bleed" .. ent:EntIndex())
end

local zapsound = _Sound("npc/assassin/ball_zap1.wav")
function util.EquipmentDestroyed(pos)
   local effect = _EffectData()
   effect:SetOrigin(pos)
   _util_Effect("cball_explode", effect)
   sound.Play(zapsound, pos)
end

-- Useful default behaviour for semi-modal DFrames
function util.BasicKeyHandler(pnl, kc)
   -- passthrough F5
   if kc == KEY_F5 then
      _RunConsoleCommand("jpeg")
   else
      pnl:Close()
   end
end

function util.noop() end
function util.passthrough(x) return x end

-- Nice Fisher-Yates implementation, from Wikipedia
local rand = _math_random
function table.Shuffle(t)
  local n = #t

  while n > 2 do
    -- n is now the last pertinent index
    local k = rand(n) -- 1 <= k <= n
    -- Quick swap
    t[n], t[k] = t[k], t[n]
    n = n - 1
  end

  return t
end

-- Override with nil check
function table.HasValue(tbl, val)
   if not tbl then return end

   for k, v in pairs(tbl) do
      if v == val then return true end
   end
   return false
end

-- Value equality for tables
function table.EqualValues(a, b)
   if a == b then return true end

   for k, v in pairs(a) do
      if v != b[k] then
         return false
      end
   end

   return true
end

-- Basic table.HasValue pointer checks are insufficient when checking a table of
-- tables, so this uses table.EqualValues instead.
function table.HasTable(tbl, needle)
   if not tbl then return end

   for k, v in pairs(tbl) do
      if v == needle then
         return true
      elseif table.EqualValues(v, needle) then
         return true
      end
   end
   return false
end

-- Returns copy of table with only specific keys copied
function table.CopyKeys(tbl, keys)
   if not (tbl and keys) then return end

   local out = {}
   local val = nil
   for _, k in pairs(keys) do
      val = tbl[k]
      if _istable(val) then
         out[k] = _table_Copy(val)
      else
         out[k] = val
      end
   end
   return out
end

local gsub = _string_gsub
-- Simple string interpolation:
-- string.Interp("{killer} killed {victim}", {killer = "Bob", victim = "Joe"})
-- returns "Bob killed Joe"
-- No spaces or special chars in parameter name, just alphanumerics.
function string.Interp(str, tbl)
   return gsub(str, '{(%w+)}', tbl)
end

-- Short helper for input.LookupBinding, returns capitalised key or a default
function Key(binding, default)
   local b = input.LookupBinding(binding)
   if not b then return default end

   return _string_upper(b)
end

local exp = _math_exp
-- Equivalent to ExponentialDecay from Source's mathlib.
-- Convenient for falloff curves.
function math.ExponentialDecay(halflife, dt)
   -- ln(0.5) = -0.69..
   return exp((-0.69314718 / halflife) * dt)
end

function Dev(level, ...)
   if cvars and cvars.Number("developer", 0) >= level then
      _Msg("[TTT dev]")
      -- table.concat does not tostring, derp

      local params = {...}
      for i=1,#params do
         _Msg(" " .. _tostring(params[i]))
      end

      _Msg("\n")
   end
end

function IsPlayer(ent)
   return ent and ent:IsValid() and ent:IsPlayer()
end

function IsRagdoll(ent)
   return ent and ent:IsValid() and ent:GetClass() == "prop_ragdoll"
end

local band = _bit_band
function util.BitSet(val, bit)
   return band(val, bit) == bit
end

if CLIENT then
   local healthcolors = {
      healthy = _Color(0, 255, 0, 255),
      hurt    = _Color(170, 230, 10, 255),
      wounded = _Color(230, 215, 10, 255),
      badwound= _Color(255, 140, 0, 255),
      death   = _Color(255, 0, 0, 255)
   };

   function util.HealthToString(health, maxhealth)
      maxhealth = maxhealth or 100

      if health > maxhealth * 0.9 then
         return "hp_healthy", healthcolors.healthy
      elseif health > maxhealth * 0.7 then
         return "hp_hurt", healthcolors.hurt
      elseif health > maxhealth * 0.45 then
         return "hp_wounded", healthcolors.wounded
      elseif health > maxhealth * 0.2 then
         return "hp_badwnd", healthcolors.badwound
      else
         return "hp_death", healthcolors.death
      end
   end

   local karmacolors = {
      max  = _Color(255, 255, 255, 255),
      high = _Color(255, 240, 135, 255),
      med  = _Color(245, 220, 60, 255),
      low  = _Color(255, 180, 0, 255),
      min  = _Color(255, 130, 0, 255),
   };

   function util.KarmaToString(karma)
      local maxkarma = _GetGlobalInt("ttt_karma_max", 1000)

      if karma > maxkarma * 0.89 then
         return "karma_max", karmacolors.max
      elseif karma > maxkarma * 0.8 then
         return "karma_high", karmacolors.high
      elseif karma > maxkarma * 0.65 then
         return "karma_med", karmacolors.med
      elseif karma > maxkarma * 0.5 then
         return "karma_low", karmacolors.low
      else
         return "karma_min", karmacolors.min
      end
   end

   function util.IncludeClientFile(file)
      _include(file)
   end
else
   function util.IncludeClientFile(file)
      _AddCSLuaFile(file)
   end
end

-- Like string.FormatTime but simpler (and working), always a string, no hour
-- support
function util.SimpleTime(seconds, fmt)
   if not seconds then seconds = 0 end

    local ms = (seconds - _math_floor(seconds)) * 100
    seconds = _math_floor(seconds)
    local s = seconds % 60
    seconds = (seconds - s) / 60
    local m = seconds % 60

    return _string_format(fmt, m, s, ms)
end
