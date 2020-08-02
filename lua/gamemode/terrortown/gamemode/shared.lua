local _IsValid = IsValid
local _include = include
local _string_gsub = string.gsub
local _string_gmatch = string.gmatch
local _string_match = string.match
local _string_byte = string.byte
local _string_Trim = string.Trim
local _Color = Color
local _getmetatable = getmetatable
local _type = type
local _setmetatable = setmetatable
local _GetConVarNumber = GetConVarNumber
local _GetGlobalBool = GetGlobalBool
local _Model = Model
local _CreateConVar = CreateConVar
local _error = error
local _math_random = math.random
local _unpack = unpack
local _hook_Call = hook.Call
local _team_SetUp = team.SetUp
local _string_find = string.find
local _ScreenScale = (CLIENT and ScreenScale or nil)
local _tonumber = tonumber
local _team_SetSpawnPoint = team.SetSpawnPoint
local _tostring = tostring
local _table_Random = table.Random
local _tobool = tobool
local _string_format = string.format
GM.Name = "Trouble in Terrorist Town"
GM.Author = "Bad King Urgrain"
GM.Website = "ttt.badking.net"
GM.Version = "shrug emoji"


GM.Customized = false

-- Round status consts
ROUND_WAIT   = 1
ROUND_PREP   = 2
ROUND_ACTIVE = 3
ROUND_POST   = 4

-- Player roles
ROLE_INNOCENT  = 0
ROLE_TRAITOR   = 1
ROLE_DETECTIVE = 2
ROLE_NONE = ROLE_INNOCENT

-- Game event log defs
EVENT_KILL        = 1
EVENT_SPAWN       = 2
EVENT_GAME        = 3
EVENT_FINISH      = 4
EVENT_SELECTED    = 5
EVENT_BODYFOUND   = 6
EVENT_C4PLANT     = 7
EVENT_C4EXPLODE   = 8
EVENT_CREDITFOUND = 9
EVENT_C4DISARM    = 10

WIN_NONE      = 1
WIN_TRAITOR   = 2
WIN_INNOCENT  = 3
WIN_TIMELIMIT = 4

-- Weapon categories, you can only carry one of each
WEAPON_NONE   = 0
WEAPON_MELEE  = 1
WEAPON_PISTOL = 2
WEAPON_HEAVY  = 3
WEAPON_NADE   = 4
WEAPON_CARRY  = 5
WEAPON_EQUIP1 = 6
WEAPON_EQUIP2 = 7
WEAPON_ROLE   = 8

WEAPON_EQUIP = WEAPON_EQUIP1
WEAPON_UNARMED = -1

-- Kill types discerned by last words
KILL_NORMAL  = 0
KILL_SUICIDE = 1
KILL_FALL    = 2
KILL_BURN    = 3

-- Entity types a crowbar might open
OPEN_NO   = 0
OPEN_DOOR = 1
OPEN_ROT  = 2
OPEN_BUT  = 3
OPEN_NOTOGGLE = 4 --movelinear

-- Mute types
MUTE_NONE = 0
MUTE_TERROR = 1
MUTE_ALL = 2
MUTE_SPEC = 1002

COLOR_WHITE  = _Color(255, 255, 255, 255)
COLOR_BLACK  = _Color(0, 0, 0, 255)
COLOR_GREEN  = _Color(0, 255, 0, 255)
COLOR_DGREEN = _Color(0, 100, 0, 255)
COLOR_RED    = _Color(255, 0, 0, 255)
COLOR_YELLOW = _Color(200, 200, 0, 255)
COLOR_LGRAY  = _Color(200, 200, 200, 255)
COLOR_BLUE   = _Color(0, 0, 255, 255)
COLOR_NAVY   = _Color(0, 0, 100, 255)
COLOR_PINK   = _Color(255,0,255, 255)
COLOR_ORANGE = _Color(250, 100, 0, 255)
COLOR_OLIVE  = _Color(100, 100, 0, 255)

local unpack = _unpack or table.unpack

local function is_callable(f)
   local tf = _type(f)
   if tf == "function" then return true end
   if tf == "table" then
      local mt = _getmetatable(f)
      return _type(mt) == "table" and is_callable(mt.__call)
   end
   return false
end

local function cache_get(cache, params)
   local node = cache
   for i = 1, #params do
      node = node and node.children
      node = node and node[params[i]]
   end
   return node and node.results or nil
end

local function cache_put(cache, params, results)
   local node = cache
   local param
   for i = 1, #params do
      param = params[i]
      node.children = node.children or {}
      node.children[param] = node.children[param] or {}
      node = node.children[param]
   end
   node.results = results
end

-- public function
local memoize = {}

function memoize.memoize(f, cache)
   cache = cache or {}

   if not is_callable(f) then
      _error(_string_format(
                  "Only functions and callable tables are memoizable. Received %s (a %s)",
                   _tostring(f), _type(f)))
   end

   return function (...)
      local params = {...}

      local results = cache_get(cache, params)
      if not results then
         results = { f(...) }
         cache_put(cache, params, results)
      end

      return unpack(results)
   end
end

_setmetatable(memoize, { __call = function(_, ...) return memoize.memoize(...) end })

_G.string.Trim = memoize(_string_Trim)
_G.string.find = memoize(_string_find)
_G.string.match = memoize(_string_match)
_G.string.gmatch = memoize(_string_gmatch)
_G.string.gsub = memoize(_string_gsub)
_G.string.byte = memoize(_string_byte)
_G._G.game.GetMap = memoize(game.GetMap)
_G._G.tonumber = memoize(_tonumber)
_G.tostring = memoize(_tostring)
_G.tobool = memoize(_tobool)

if CLIENT then
   _G.ScreenScale = memoize(_ScreenScale)
end

local _hook_Add = hook.Add
local _MsgN = MsgN
local _hook_Remove = hook.Remove
_hook_Add( "PreGamemodeLoaded", "DeleteWidgets", function()
   function widgets.PlayerTick()
   end
   _hook_Remove( "PlayerTick", "TickWidgets" )
end )


_include("util.lua")
_include("lang_shd.lua") -- uses some of util
_include("equip_items_shd.lua")

function DetectiveMode() return _GetGlobalBool("ttt_detective", false) end
function HasteMode() return _GetGlobalBool("ttt_haste", false) end

-- Create teams
TEAM_TERROR = 1
TEAM_SPEC = TEAM_SPECTATOR

function GM:CreateTeams()
   _team_SetUp(TEAM_TERROR, "Terrorists", _Color(0, 200, 0, 255), false)
   _team_SetUp(TEAM_SPEC, "Spectators", _Color(200, 200, 0, 255), true)

   -- Not that we use this, but feels good
   _team_SetSpawnPoint(TEAM_TERROR, "info_player_deathmatch")
   _team_SetSpawnPoint(TEAM_SPEC, "info_player_deathmatch")
end

-- Everyone's model
local ttt_playermodels = {
   _Model("models/player/phoenix.mdl"),
   _Model("models/player/arctic.mdl"),
   _Model("models/player/guerilla.mdl"),
   _Model("models/player/leet.mdl")
};

function GetRandomPlayerModel()
   return _table_Random(ttt_playermodels)
end

local ttt_playercolors = {
   all = {
      COLOR_WHITE,
      COLOR_BLACK,
      COLOR_GREEN,
      COLOR_DGREEN,
      COLOR_RED,
      COLOR_YELLOW,
      COLOR_LGRAY,
      COLOR_BLUE,
      COLOR_NAVY,
      COLOR_PINK,
      COLOR_OLIVE,
      COLOR_ORANGE
   },

   serious = {
      COLOR_WHITE,
      COLOR_BLACK,
      COLOR_NAVY,
      COLOR_LGRAY,
      COLOR_DGREEN,
      COLOR_OLIVE
   }
};

_CreateConVar("ttt_playercolor_mode", "1")
function GM:TTTPlayerColor(model)
   local mode = _GetConVarNumber("ttt_playercolor_mode") or 0
   if mode == 1 then
      return _table_Random(ttt_playercolors.serious)
   elseif mode == 2 then
      return _table_Random(ttt_playercolors.all)
   elseif mode == 3 then
      -- Full randomness
      return _Color(_math_random(0, 255), _math_random(0, 255), _math_random(0, 255))
   end
   -- No coloring
   return COLOR_WHITE
end

-- Kill footsteps on player and client
function GM:PlayerFootstep(ply, pos, foot, sound, volume, rf)
   if _IsValid(ply) and (ply:Crouching() or ply:GetMaxSpeed() < 150 or ply:IsSpec()) then
      -- do not play anything, just prevent normal sounds from playing
      return true
   end
end

-- Predicted move speed changes
function GM:Move(ply, mv)
   if ply:IsTerror() then
      local basemul = 1
      local slowed = false
      -- Slow down ironsighters
      local wep = ply:GetActiveWeapon()
      if _IsValid(wep) and wep.GetIronsights and wep:GetIronsights() then
         basemul = 120 / 220
         slowed = true
      end
      local mul = _hook_Call("TTTPlayerSpeedModifier", GAMEMODE, ply, slowed, mv) or 1
      mul = basemul * mul
      mv:SetMaxClientSpeed(mv:GetMaxClientSpeed() * mul)
      mv:SetMaxSpeed(mv:GetMaxSpeed() * mul)
   end
end


-- Weapons and items that come with TTT. Weapons that are not in this list will
-- get a little marker on their icon if they're buyable, showing they are custom
-- and unique to the server.
DefaultEquipment = {
   -- traitor-buyable by default
   [ROLE_TRAITOR] = {
      "weapon_ttt_c4",
      "weapon_ttt_flaregun",
      "weapon_ttt_knife",
      "weapon_ttt_phammer",
      "weapon_ttt_push",
      "weapon_ttt_radio",
      "weapon_ttt_sipistol",
      "weapon_ttt_teleport",
      "weapon_ttt_decoy",
      EQUIP_ARMOR,
      EQUIP_RADAR,
      EQUIP_DISGUISE
   },

   -- detective-buyable by default
   [ROLE_DETECTIVE] = {
      "weapon_ttt_binoculars",
      "weapon_ttt_defuser",
      "weapon_ttt_health_station",
      "weapon_ttt_stungun",
      "weapon_ttt_cse",
      "weapon_ttt_teleport",
      EQUIP_ARMOR,
      EQUIP_RADAR
   },

   -- non-buyable
   [ROLE_NONE] = {
      "weapon_ttt_confgrenade",
      "weapon_ttt_m16",
      "weapon_ttt_smokegrenade",
      "weapon_ttt_unarmed",
      "weapon_ttt_wtester",
      "weapon_tttbase",
      "weapon_tttbasegrenade",
      "weapon_zm_carry",
      "weapon_zm_improvised",
      "weapon_zm_mac10",
      "weapon_zm_molotov",
      "weapon_zm_pistol",
      "weapon_zm_revolver",
      "weapon_zm_rifle",
      "weapon_zm_shotgun",
      "weapon_zm_sledge",
      "weapon_ttt_glock"
   }
};
