local _timer_Remove = timer.Remove
local _timer_Start = timer.Start
local _CurTime = CurTime
local _AddCSLuaFile = AddCSLuaFile
local _player_GetHumans = player.GetHumans
local _ipairs = ipairs
local _net_Send = (SERVER and net.Send or nil)
local _SetGlobalFloat = SetGlobalFloat
local _table_HasValue = table.HasValue
local _SetGlobalBool = SetGlobalBool
local _table_remove = table.remove
local _table_insert = table.insert
local _timer_Simple = timer.Simple
local _net_Start = net.Start
local _RandomPairs = RandomPairs
local _net_WriteUInt = net.WriteUInt
local _math_randomseed = math.randomseed
local _string_sub = string.sub
local _player_GetAll = player.GetAll
local _MsgN = MsgN
local _GetConVar = GetConVar
local _GetGlobalInt = GetGlobalInt
local _Msg = Msg
local _math_Clamp = math.Clamp
local _util_AddNetworkString = (SERVER and util.AddNetworkString or nil)
local _GetConVarNumber = GetConVarNumber
local _math_random = math.random
local _ServerLog = (SERVER and ServerLog or nil)
local _timer_Exists = timer.Exists
local _concommand_Add = concommand.Add
local _Format = Format
local _string_upper = string.upper
local _IsValid = IsValid
local _include = include
local _RunConsoleCommand = RunConsoleCommand
local _hook_Remove = hook.Remove
local _timer_Stop = timer.Stop
local _SetGlobalInt = SetGlobalInt
local _GetGlobalFloat = GetGlobalFloat
local _net_Broadcast = (SERVER and net.Broadcast or nil)
local _timer_Create = timer.Create
local _math_ceil = math.ceil
local _ErrorNoHalt = ErrorNoHalt
local _hook_Call = hook.Call
local _math_max = math.max
local _math_floor = math.floor
local _CreateConVar = CreateConVar
---- Trouble in Terrorist Town

_AddCSLuaFile("cl_init.lua")
_AddCSLuaFile("shared.lua")
_AddCSLuaFile("cl_hud.lua")
_AddCSLuaFile("cl_msgstack.lua")
_AddCSLuaFile("cl_hudpickup.lua")
_AddCSLuaFile("cl_keys.lua")
_AddCSLuaFile("cl_wepswitch.lua")
_AddCSLuaFile("cl_awards.lua")
_AddCSLuaFile("cl_scoring_events.lua")
_AddCSLuaFile("cl_scoring.lua")
_AddCSLuaFile("cl_popups.lua")
_AddCSLuaFile("cl_equip.lua")
_AddCSLuaFile("equip_items_shd.lua")
_AddCSLuaFile("cl_help.lua")
_AddCSLuaFile("cl_scoreboard.lua")
_AddCSLuaFile("cl_tips.lua")
_AddCSLuaFile("cl_voice.lua")
_AddCSLuaFile("scoring_shd.lua")
_AddCSLuaFile("util.lua")
_AddCSLuaFile("lang_shd.lua")
_AddCSLuaFile("corpse_shd.lua")
_AddCSLuaFile("player_ext_shd.lua")
_AddCSLuaFile("weaponry_shd.lua")
_AddCSLuaFile("cl_radio.lua")
_AddCSLuaFile("cl_radar.lua")
_AddCSLuaFile("cl_tbuttons.lua")
_AddCSLuaFile("cl_disguise.lua")
_AddCSLuaFile("cl_transfer.lua")
_AddCSLuaFile("cl_search.lua")
_AddCSLuaFile("cl_targetid.lua")
_AddCSLuaFile("vgui/ColoredBox.lua")
_AddCSLuaFile("vgui/SimpleIcon.lua")
_AddCSLuaFile("vgui/ProgressBar.lua")
_AddCSLuaFile("vgui/ScrollLabel.lua")
_AddCSLuaFile("vgui/sb_main.lua")
_AddCSLuaFile("vgui/sb_row.lua")
_AddCSLuaFile("vgui/sb_team.lua")
_AddCSLuaFile("vgui/sb_info.lua")



_include("shared.lua")

_include("karma.lua")
_include("entity.lua")
_include("radar.lua")
_include("admin.lua")
_include("traitor_state.lua")
_include("propspec.lua")
_include("weaponry.lua")
_include("gamemsg.lua")
_include("ent_replace.lua")
_include("scoring.lua")
_include("corpse.lua")
_include("player_ext_shd.lua")
_include("player_ext.lua")
_include("player.lua")

-- Round times
_CreateConVar("ttt_roundtime_minutes", "10", FCVAR_NOTIFY)
_CreateConVar("ttt_preptime_seconds", "30", FCVAR_NOTIFY)
_CreateConVar("ttt_posttime_seconds", "30", FCVAR_NOTIFY)
_CreateConVar("ttt_firstpreptime", "60")

-- Haste mode
local ttt_haste = _CreateConVar("ttt_haste", "1", FCVAR_NOTIFY)
_CreateConVar("ttt_haste_starting_minutes", "5", FCVAR_NOTIFY)
_CreateConVar("ttt_haste_minutes_per_death", "0.5", FCVAR_NOTIFY)

-- Player Spawning
_CreateConVar("ttt_spawn_wave_interval", "0")

_CreateConVar("ttt_traitor_pct", "0.25")
_CreateConVar("ttt_traitor_max", "32")

_CreateConVar("ttt_detective_pct", "0.13", FCVAR_NOTIFY)
_CreateConVar("ttt_detective_max", "32")
_CreateConVar("ttt_detective_min_players", "8")
_CreateConVar("ttt_detective_karma_min", "600")


-- Traitor credits
_CreateConVar("ttt_credits_starting", "2")
_CreateConVar("ttt_credits_award_pct", "0.35")
_CreateConVar("ttt_credits_award_size", "1")
_CreateConVar("ttt_credits_award_repeat", "1")
_CreateConVar("ttt_credits_detectivekill", "1")

_CreateConVar("ttt_credits_alonebonus", "1")

-- Detective credits
_CreateConVar("ttt_det_credits_starting", "1")
_CreateConVar("ttt_det_credits_traitorkill", "0")
_CreateConVar("ttt_det_credits_traitordead", "1")

-- Other
_CreateConVar("ttt_use_weapon_spawn_scripts", "1")
_CreateConVar("ttt_weapon_spawn_count", "0")

_CreateConVar("ttt_round_limit", "6", FCVAR_ARCHIVE + FCVAR_NOTIFY + FCVAR_REPLICATED)
_CreateConVar("ttt_time_limit_minutes", "75", FCVAR_NOTIFY + FCVAR_REPLICATED)

_CreateConVar("ttt_idle_limit", "180", FCVAR_NOTIFY)

_CreateConVar("ttt_voice_drain", "0", FCVAR_NOTIFY)
_CreateConVar("ttt_voice_drain_normal", "0.2", FCVAR_NOTIFY)
_CreateConVar("ttt_voice_drain_admin", "0.05", FCVAR_NOTIFY)
_CreateConVar("ttt_voice_drain_recharge", "0.05", FCVAR_NOTIFY)

_CreateConVar("ttt_namechange_kick", "1", FCVAR_NOTIFY)
_CreateConVar("ttt_namechange_bantime", "10")

local ttt_detective = _CreateConVar("ttt_sherlock_mode", "1", FCVAR_ARCHIVE + FCVAR_NOTIFY)
local ttt_minply = _CreateConVar("ttt_minimum_players", "2", FCVAR_ARCHIVE + FCVAR_NOTIFY)

-- debuggery
local ttt_dbgwin = _CreateConVar("ttt_debug_preventwin", "0")

-- Localise stuff we use often. It's like Lua go-faster stripes.
local math = math
local table = table
local net = net
local player = player
local timer = timer
local util = util
local currentmap = game.GetMap()
-- Pool some network names.
_util_AddNetworkString("TTT_RoundState")
_util_AddNetworkString("TTT_RagdollSearch")
_util_AddNetworkString("TTT_GameMsg")
_util_AddNetworkString("TTT_GameMsgColor")
_util_AddNetworkString("TTT_RoleChat")
_util_AddNetworkString("TTT_TraitorVoiceState")
_util_AddNetworkString("TTT_LastWordsMsg")
_util_AddNetworkString("TTT_RadioMsg")
_util_AddNetworkString("TTT_ReportStream")
_util_AddNetworkString("TTT_ReportStream_Part")
_util_AddNetworkString("TTT_LangMsg")
_util_AddNetworkString("TTT_ServerLang")
_util_AddNetworkString("TTT_Equipment")
_util_AddNetworkString("TTT_Credits")
_util_AddNetworkString("TTT_Bought")
_util_AddNetworkString("TTT_BoughtItem")
_util_AddNetworkString("TTT_InterruptChat")
_util_AddNetworkString("TTT_PlayerSpawned")
_util_AddNetworkString("TTT_PlayerDied")
_util_AddNetworkString("TTT_CorpseCall")
_util_AddNetworkString("TTT_ClearClientState")
_util_AddNetworkString("TTT_PerformGesture")
_util_AddNetworkString("TTT_Role")
_util_AddNetworkString("TTT_RoleList")
_util_AddNetworkString("TTT_ConfirmUseTButton")
_util_AddNetworkString("TTT_C4Config")
_util_AddNetworkString("TTT_C4DisarmResult")
_util_AddNetworkString("TTT_C4Warn")
_util_AddNetworkString("TTT_ShowPrints")
_util_AddNetworkString("TTT_ScanResult")
_util_AddNetworkString("TTT_FlareScorch")
_util_AddNetworkString("TTT_Radar")
_util_AddNetworkString("TTT_Spectate")
---- Round mechanics
function GM:Initialize()
   _MsgN("Trouble In Terrorist Town gamemode initializing...")

   -- Force friendly fire to be enabled. If it is off, we do not get lag compensation.
   _RunConsoleCommand("mp_friendlyfire", "1")

   -- Default crowbar unlocking settings, may be overridden by config entity
   GAMEMODE.crowbar_unlocks = {
      [OPEN_DOOR] = true,
      [OPEN_ROT] = true,
      [OPEN_BUT] = true,
      [OPEN_NOTOGGLE]= true
   };

   -- More map config ent defaults
   GAMEMODE.force_plymodel = ""
   GAMEMODE.propspec_allow_named = true

   GAMEMODE.MapWin = WIN_NONE
   GAMEMODE.AwardedCredits = false
   GAMEMODE.AwardedCreditsDead = 0

   GAMEMODE.round_state = ROUND_WAIT
   GAMEMODE.FirstRound = true
   GAMEMODE.RoundStartTime = 0

   GAMEMODE.DamageLog = {}
   GAMEMODE.LastRole = {}
   GAMEMODE.playermodel = GetRandomPlayerModel()
   GAMEMODE.playercolor = COLOR_WHITE

   -- Delay reading of cvars until config has definitely loaded
   GAMEMODE.cvar_init = false

   _SetGlobalFloat("ttt_round_end", -1)
   _SetGlobalFloat("ttt_haste_end", -1)

   -- For the paranoid
   _math_randomseed(os.time())

   WaitForPlayers()

   if cvars.Number("sv_alltalk", 0) > 0 then
      _ErrorNoHalt("TTT WARNING: sv_alltalk is enabled. Dead players will be able to talk to living players. TTT will now attempt to set sv_alltalk 0.\n")
      _RunConsoleCommand("sv_alltalk", "0")
   end

   local cstrike = false
   for _, g in _ipairs(engine.GetGames()) do
      if g.folder == 'cstrike' then cstrike = true end
   end
   if not cstrike then
      _ErrorNoHalt("TTT WARNING: CS:S does not appear to be mounted by GMod. Things may break in strange ways. Server admin? Check the TTT readme for help.\n")
   end
end

-- Used to do this in Initialize, but server cfg has not always run yet by that
-- point.
function GM:InitCvars()
   _MsgN("TTT initializing convar settings...")

   -- Initialize game state that is synced with client
   _SetGlobalInt("ttt_rounds_left", _GetConVar("ttt_round_limit"):GetInt())
   GAMEMODE:SyncGlobals()
   KARMA.InitState()

   self.cvar_init = true
end

function GM:InitPostEntity()
   WEPS.ForcePrecache()
end

-- Convar replication is broken in gmod, so we do this.
-- I don't like it any more than you do, dear reader.
function GM:SyncGlobals()
   _SetGlobalBool("ttt_detective", ttt_detective:GetBool())
   _SetGlobalBool("ttt_haste", ttt_haste:GetBool())
   _SetGlobalInt("ttt_time_limit_minutes", _GetConVar("ttt_time_limit_minutes"):GetInt())
   _SetGlobalBool("ttt_highlight_admins", _GetConVar("ttt_highlight_admins"):GetBool())
   _SetGlobalBool("ttt_locational_voice", _GetConVar("ttt_locational_voice"):GetBool())
   _SetGlobalInt("ttt_idle_limit", _GetConVar("ttt_idle_limit"):GetInt())

   _SetGlobalBool("ttt_voice_drain", _GetConVar("ttt_voice_drain"):GetBool())
   _SetGlobalFloat("ttt_voice_drain_normal", _GetConVar("ttt_voice_drain_normal"):GetFloat())
   _SetGlobalFloat("ttt_voice_drain_admin", _GetConVar("ttt_voice_drain_admin"):GetFloat())
   _SetGlobalFloat("ttt_voice_drain_recharge", _GetConVar("ttt_voice_drain_recharge"):GetFloat())
end

function SendRoundState(state, ply)
   _net_Start("TTT_RoundState")
      _net_WriteUInt(state, 3)
   return ply and _net_Send(ply) or _net_Broadcast()
end

-- Round state is encapsulated by set/get so that it can easily be changed to
-- eg. a networked var if this proves more convenient
function SetRoundState(state)
   GAMEMODE.round_state = state

   SCORE:RoundStateChange(state)

   SendRoundState(state)
end

function GetRoundState()
   return GAMEMODE.round_state
end

local function EnoughPlayers()
   local ready = 0
   -- only count truly available players, ie. no forced specs
   for _, ply in _ipairs(_player_GetAll()) do
      if _IsValid(ply) and ply:ShouldSpawn() then
         ready = ready + 1
      end
   end
   return ready >= ttt_minply:GetInt()
end

-- Used to be in Think/Tick, now in a timer
function WaitingForPlayersChecker()
   if GetRoundState() == ROUND_WAIT then
      if EnoughPlayers() then
         _timer_Create("wait2prep", 1, 1, PrepareRound)

         _timer_Stop("waitingforply")
      end
   end
end

-- Start waiting for players
function WaitForPlayers()
   SetRoundState(ROUND_WAIT)

   if not _timer_Start("waitingforply") then
      _timer_Create("waitingforply", 2, 0, WaitingForPlayersChecker)
   end
end

-- When a player initially spawns after mapload, everything is a bit strange;
-- just making him spectator for some reason does not work right. Therefore,
-- we regularly check for these broken spectators while we wait for players
-- and immediately fix them.
function FixSpectators()
   for k, ply in _ipairs(_player_GetAll()) do
      if ply:IsSpec() and not ply:GetRagdollSpec() and ply:GetMoveType() < MOVETYPE_NOCLIP then
         ply:Spectate(OBS_MODE_ROAMING)
      end
   end
end

-- Used to be in think, now a timer
local function WinChecker()
   if GetRoundState() == ROUND_ACTIVE then
      if _CurTime() > _GetGlobalFloat("ttt_round_end", 0) then
         EndRound(WIN_TIMELIMIT)
      else
         local win = _hook_Call("TTTCheckForWin", GAMEMODE)
         if win != WIN_NONE then
            EndRound(win)
         end
      end
   end
end

local function NameChangeKick()
   if not _GetConVar("ttt_namechange_kick"):GetBool() then
      _timer_Remove("namecheck")
      return
   end

   if GetRoundState() == ROUND_ACTIVE then
      for _, ply in _ipairs(_player_GetHumans()) do
         if ply.spawn_nick then
            if ply.has_spawned and ply.spawn_nick != ply:Nick() and not _hook_Call("TTTNameChangeKick", GAMEMODE, ply) then
               local t = _GetConVar("ttt_namechange_bantime"):GetInt()
               local msg = "Changed name during a round"
               if t > 0 then
                  ply:KickBan(t, msg)
               else
                  ply:Kick(msg)
               end
            end
         else
            ply.spawn_nick = ply:Nick()
         end
      end
   end
end

function StartNameChangeChecks()
   if not _GetConVar("ttt_namechange_kick"):GetBool() then return end

   -- bring nicks up to date, may have been changed during prep/post
   for _, ply in _ipairs(_player_GetAll()) do
      ply.spawn_nick = ply:Nick()
   end

   if not _timer_Exists("namecheck") then
      _timer_Create("namecheck", 3, 0, NameChangeKick)
   end
end

function StartWinChecks()
   if not _timer_Start("winchecker") then
      _timer_Create("winchecker", 1, 0, WinChecker)
   end
end

function StopWinChecks()
   _timer_Stop("winchecker")
end

local function CleanUp()
   local et = ents.TTT
   -- if we are going to import entities, it's no use replacing HL2DM ones as
   -- soon as they spawn, because they'll be removed anyway
   et.SetReplaceChecking(not et.CanImportEntities(currentmap))

   et.FixParentedPreCleanup()

   game.CleanUpMap()

   et.FixParentedPostCleanup()

   -- Strip players now, so that their weapons are not seen by ReplaceEntities
   for k,v in _ipairs(_player_GetAll()) do
      if _IsValid(v) then
         v:StripWeapons()
      end
   end

   -- a different kind of cleanup
   _hook_Remove("PlayerSay", "ULXMeCheck")
end
local spawnimportcache = nil
local function SpawnEntities()
   local et = ents.TTT
   -- Spawn weapons from script if there is one
   local import = nil
   if spawnimportcache then
      import = spawnimportcache
   else
      import = et.CanImportEntities(currentmap)
      spawnimportcache = import
   end
   if import then
      et.ProcessImportScript(currentmap)
   else
      -- Replace HL2DM/ZM ammo/weps with our own
      et.ReplaceEntities()

      -- Populate CS:S/TF2 maps with extra guns
      et.PlaceExtraWeapons()
   end

   -- Finally, get players in there
   SpawnWillingPlayers()
end


local function StopRoundTimers()
   -- remove all timers
   _timer_Stop("wait2prep")
   _timer_Stop("prep2begin")
   _timer_Stop("end2prep")
   _timer_Stop("winchecker")
end

-- Make sure we have the players to do a round, people can leave during our
-- preparations so we'll call this numerous times
local function CheckForAbort()
   if not EnoughPlayers() then
      LANG.Msg("round_minplayers")
      StopRoundTimers()

      WaitForPlayers()
      return true
   end

   return false
end

function GM:TTTDelayRoundStartForVote()
   -- Can be used for custom voting systems
   --return true, 30
   return false
end

function PrepareRound()
   -- Check playercount
   if CheckForAbort() then return end

   local delay_round, delay_length = _hook_Call("TTTDelayRoundStartForVote", GAMEMODE)

   if delay_round then
      delay_length = delay_length or 30

      LANG.Msg("round_voting", {num = delay_length})

      _timer_Create("delayedprep", delay_length, 1, PrepareRound)
      return
   end

   -- Cleanup
   CleanUp()

   GAMEMODE.MapWin = WIN_NONE
   GAMEMODE.AwardedCredits = false
   GAMEMODE.AwardedCreditsDead = 0

   SCORE:Reset()

   -- Update damage scaling
   KARMA.RoundBegin()

   -- New look. Random if no forced model set.
   GAMEMODE.playermodel = GAMEMODE.force_plymodel == "" and GetRandomPlayerModel() or GAMEMODE.force_plymodel
   GAMEMODE.playercolor = _hook_Call("TTTPlayerColor", GAMEMODE, GAMEMODE.playermodel)

   if CheckForAbort() then return end

   -- Schedule round start
   local ptime = _GetConVar("ttt_preptime_seconds"):GetInt()
   if GAMEMODE.FirstRound then
      ptime = _GetConVar("ttt_firstpreptime"):GetInt()
      GAMEMODE.FirstRound = false
   end

   -- Piggyback on "round end" time global var to show end of phase timer
   SetRoundEnd(_CurTime() + ptime)

   _timer_Create("prep2begin", ptime, 1, BeginRound)

   -- Mute for a second around traitor selection, to counter a dumb exploit
   -- related to traitor's mics cutting off for a second when they're selected.
   _timer_Create("selectmute", ptime - 1, 1, function() MuteForRestart(true) end)

   LANG.Msg("round_begintime", {num = ptime})
   SetRoundState(ROUND_PREP)

   -- Delay spawning until next frame to avoid ent overload
   _timer_Simple(0.01, SpawnEntities)

   -- Undo the roundrestart mute, though they will once again be muted for the
   -- selectmute timer.
   _timer_Create("restartmute", 1, 1, function() MuteForRestart(false) end)

   _net_Start("TTT_ClearClientState") _net_Broadcast()

   -- In case client's cleanup fails, make client set all players to innocent role
   _timer_Simple(1, SendRoleReset)

   -- Tell hooks and map we started prep
   _hook_Call("TTTPrepareRound")

   ents.TTT.TriggerRoundStateOutputs(ROUND_PREP)
end

function SetRoundEnd(endtime)
   _SetGlobalFloat("ttt_round_end", endtime)
end

function IncRoundEnd(incr)
   SetRoundEnd(_GetGlobalFloat("ttt_round_end", 0) + incr)
end

function TellTraitorsAboutTraitors()
  local plys = _player_GetAll()

   local traitornicks = {}
   for k,v in _ipairs(plys) do
      if v:IsTraitor() then
         _table_insert(traitornicks, v:Nick())
      end
   end

   -- This is ugly as hell, but it's kinda nice to filter out the names of the
   -- traitors themselves in the messages to them
   for k,v in _ipairs(plys) do
      if v:IsTraitor() then
         if #traitornicks < 2 then
            LANG.Msg(v, "round_traitors_one")
            return
         else
            local names = ""
            for i,name in _ipairs(traitornicks) do
               if name != v:Nick() then
                  names = names .. name .. ", "
               end
            end
            names = _string_sub(names, 1, -3)
            LANG.Msg(v, "round_traitors_more", {names = names})
         end
      end
   end
end


function SpawnWillingPlayers(dead_only)
   local plys = _player_GetAll()
   local wave_delay = _GetConVar("ttt_spawn_wave_interval"):GetFloat()

   -- simple method, should make this a case of the other method once that has
   -- been tested.
   if wave_delay <= 0 or dead_only then
      for k, ply in _ipairs(plys) do
         if _IsValid(ply) then
            ply:SpawnForRound(dead_only)
         end
      end
   else
      -- wave method
      local num_spawns = #GetSpawnEnts()

      local to_spawn = {}
      for _, ply in _RandomPairs(plys) do
         if _IsValid(ply) and ply:ShouldSpawn() then
            _table_insert(to_spawn, ply)
            GAMEMODE:PlayerSpawnAsSpectator(ply)
         end
      end

      local sfn = function()
                     local c = 0
                     -- fill the available spawnpoints with players that need
                     -- spawning
                     while c < num_spawns and #to_spawn > 0 do
                        for k, ply in _ipairs(to_spawn) do
                           if _IsValid(ply) and ply:SpawnForRound() then
                              -- a spawn ent is now occupied
                              c = c + 1
                           end
                           -- Few possible cases:
                           -- 1) player has now been spawned
                           -- 2) player should remain spectator after all
                           -- 3) player has disconnected
                           -- In all cases we don't need to spawn them again.
                           _table_remove(to_spawn, k)

                           -- all spawn ents are occupied, so the rest will have
                           -- to wait for next wave
                           if c >= num_spawns then
                              break
                           end
                        end
                     end

                     _MsgN("Spawned " .. c .. " players in spawn wave.")

                     if #to_spawn == 0 then
                        _timer_Remove("spawnwave")
                        _MsgN("Spawn waves ending, all players spawned.")
                     end
                  end

      _MsgN("Spawn waves starting.")
      _timer_Create("spawnwave", wave_delay, 0, sfn)

      -- already run one wave, which may stop the timer if everyone is spawned
      -- in one go
      sfn()
   end
end

local function InitRoundEndTime()
   -- Init round values
   local endtime = _CurTime() + (_GetConVar("ttt_roundtime_minutes"):GetInt() * 60)
   if HasteMode() then
      endtime = _CurTime() + (_GetConVar("ttt_haste_starting_minutes"):GetInt() * 60)
      -- this is a "fake" time shown to innocents, showing the end time if no
      -- one would have been killed, it has no gameplay effect
      _SetGlobalFloat("ttt_haste_end", endtime)
   end

   SetRoundEnd(endtime)
end

function BeginRound()
   GAMEMODE:SyncGlobals()

   if CheckForAbort() then return end

   InitRoundEndTime()

   if CheckForAbort() then return end

   -- Respawn dumb people who died during prep
   SpawnWillingPlayers(true)

   -- Remove their ragdolls
   ents.TTT.RemoveRagdolls(true)

   if CheckForAbort() then return end

   -- Select traitors & co. This is where things really start so we can't abort
   -- anymore.
   SelectRoles()
   LANG.Msg("round_selected")
   SendFullStateUpdate()

   -- Edge case where a player joins just as the round starts and is picked as
   -- traitor, but for whatever reason does not get the traitor state msg. So
   -- re-send after a second just to make sure everyone is getting it.
   _timer_Simple(1, SendFullStateUpdate)
   _timer_Simple(10, SendFullStateUpdate)

   SCORE:HandleSelection() -- log traitors and detectives

   -- Give the StateUpdate messages ample time to arrive
   _timer_Simple(1.5, TellTraitorsAboutTraitors)
   _timer_Simple(2.5, ShowRoundStartPopup)

   -- Start the win condition check timer
   StartWinChecks()
   StartNameChangeChecks()
   _timer_Create("selectmute", 1, 1, function() MuteForRestart(false) end)

   GAMEMODE.DamageLog = {}
   GAMEMODE.RoundStartTime = _CurTime()

   -- Sound start alarm
   SetRoundState(ROUND_ACTIVE)
   LANG.Msg("round_started")
   _ServerLog("Round proper has begun...\n")

   GAMEMODE:UpdatePlayerLoadouts() -- needs to happen when round_active

   _hook_Call("TTTBeginRound")

   ents.TTT.TriggerRoundStateOutputs(ROUND_BEGIN)
end

function PrintResultMessage(type)
   _ServerLog("Round ended.\n")
   if type == WIN_TIMELIMIT then
      LANG.Msg("win_time")
      _ServerLog("Result: timelimit reached, traitors lose.\n")
   elseif type == WIN_TRAITOR then
      LANG.Msg("win_traitor")
      _ServerLog("Result: traitors win.\n")
   elseif type == WIN_INNOCENT then
      LANG.Msg("win_innocent")
      _ServerLog("Result: innocent win.\n")
   else
      _ServerLog("Result: unknown victory condition!\n")
   end
end

function CheckForMapSwitch()
   -- Check for mapswitch
   local rounds_left = _math_max(0, _GetGlobalInt("ttt_rounds_left", 6) - 1)
   _SetGlobalInt("ttt_rounds_left", rounds_left)

   local time_left = _math_max(0, (_GetConVar("ttt_time_limit_minutes"):GetInt() * 60) - _CurTime())
   local switchmap = false
   local nextmap = _string_upper(game.GetMapNext())

   if rounds_left <= 0 then
      LANG.Msg("limit_round", {mapname = nextmap})
      switchmap = true
   elseif time_left <= 0 then
      LANG.Msg("limit_time", {mapname = nextmap})
      switchmap = true
   end

   if switchmap then
      _timer_Stop("end2prep")
      _timer_Simple(15, game.LoadNextMap)
   else
      LANG.Msg("limit_left", {num = rounds_left,
                              time = _math_ceil(time_left / 60),
                              mapname = nextmap})
   end
end

function EndRound(type)
   PrintResultMessage(type)

   -- first handle round end
   SetRoundState(ROUND_POST)

   local ptime = _math_max(5, _GetConVar("ttt_posttime_seconds"):GetInt())
   LANG.Msg("win_showreport", {num = ptime})
   _timer_Create("end2prep", ptime, 1, PrepareRound)

   -- Piggyback on "round end" time global var to show end of phase timer
   SetRoundEnd(_CurTime() + ptime)

   _timer_Create("restartmute", ptime - 1, 1, function() MuteForRestart(true) end)

   -- Stop checking for wins
   StopWinChecks()

   -- We may need to start a timer for a mapswitch, or start a vote
   CheckForMapSwitch()

   KARMA.RoundEnd()

   -- now handle potentially error prone scoring stuff

   -- register an end of round event
   SCORE:RoundComplete(type)

   -- update player scores
   SCORE:ApplyEventLogScores(type)

   -- send the clients the round log, players will be shown the report
   SCORE:StreamToClients()

   -- server plugins might want to start a map vote here or something
   -- these hooks are not used by TTT internally
   _hook_Call("TTTEndRound", GAMEMODE, type)

   ents.TTT.TriggerRoundStateOutputs(ROUND_POST, type)
end

function GM:MapTriggeredEnd(wintype)
   self.MapWin = wintype
end

-- The most basic win check is whether both sides have one dude alive
function GM:TTTCheckForWin()
   if ttt_dbgwin:GetBool() then return WIN_NONE end

   if GAMEMODE.MapWin == WIN_TRAITOR or GAMEMODE.MapWin == WIN_INNOCENT then
      local mw = GAMEMODE.MapWin
      GAMEMODE.MapWin = WIN_NONE
      return mw
   end

   local traitor_alive = false
   local innocent_alive = false
   for k,v in _ipairs(_player_GetAll()) do
      if v:Alive() and v:IsTerror() then
         if v:GetTraitor() then
            traitor_alive = true
         else
            innocent_alive = true
         end
      end

      if traitor_alive and innocent_alive then
         return WIN_NONE --early out
      end
   end

   if traitor_alive and not innocent_alive then
      return WIN_TRAITOR
   elseif not traitor_alive and innocent_alive then
      return WIN_INNOCENT
   elseif not innocent_alive then
      -- ultimately if no one is alive, traitors win
      return WIN_TRAITOR
   end

   return WIN_NONE
end

local function GetTraitorCount(ply_count)
   -- get number of traitors: pct of players rounded down
   local traitor_count = _math_floor(ply_count * _GetConVar("ttt_traitor_pct"):GetFloat())
   -- make sure there is at least 1 traitor
   traitor_count = _math_Clamp(traitor_count, 1, _GetConVar("ttt_traitor_max"):GetInt())

   return traitor_count
end


local function GetDetectiveCount(ply_count)
   if ply_count < _GetConVar("ttt_detective_min_players"):GetInt() then return 0 end

   local det_count = _math_floor(ply_count * _GetConVar("ttt_detective_pct"):GetFloat())
   -- limit to a max
   det_count = _math_Clamp(det_count, 1, _GetConVar("ttt_detective_max"):GetInt())

   return det_count
end


function SelectRoles()
   local choices = {}
   local prev_roles = {
      [ROLE_INNOCENT] = {},
      [ROLE_TRAITOR] = {},
      [ROLE_DETECTIVE] = {}
   };

   if not GAMEMODE.LastRole then GAMEMODE.LastRole = {} end

   local plys = _player_GetAll()

   for k,v in _ipairs(plys) do
      -- everyone on the spec team is in specmode
      if _IsValid(v) and (not v:IsSpec()) then
         -- save previous role and sign up as possible traitor/detective

         local r = GAMEMODE.LastRole[v:SteamID()] or v:GetRole() or ROLE_INNOCENT

         _table_insert(prev_roles[r], v)

         _table_insert(choices, v)
      end

      v:SetRole(ROLE_INNOCENT)
   end

   -- determine how many of each role we want
   local choice_count = #choices
   local traitor_count = GetTraitorCount(choice_count)
   local det_count = GetDetectiveCount(choice_count)

   if choice_count == 0 then return end

   -- first select traitors
   local ts = 0
   while (ts < traitor_count) and (#choices >= 1) do
      -- select random index in choices table
      local pick = _math_random(1, #choices)

      -- the player we consider
      local pply = choices[pick]

      -- make this guy traitor if he was not a traitor last time, or if he makes
      -- a roll
      if _IsValid(pply) and
         ((not _table_HasValue(prev_roles[ROLE_TRAITOR], pply)) or (_math_random(1, 3) == 2)) then
         pply:SetRole(ROLE_TRAITOR)

         _table_remove(choices, pick)
         ts = ts + 1
      end
   end

   -- now select detectives, explicitly choosing from players who did not get
   -- traitor, so becoming detective does not mean you lost a chance to be
   -- traitor
   local ds = 0
   local min_karma = _GetConVarNumber("ttt_detective_karma_min") or 0
   while (ds < det_count) and (#choices >= 1) do

      -- sometimes we need all remaining choices to be detective to fill the
      -- roles up, this happens more often with a lot of detective-deniers
      if #choices <= (det_count - ds) then
         for k, pply in _ipairs(choices) do
            if _IsValid(pply) then
               pply:SetRole(ROLE_DETECTIVE)
            end
         end

         break -- out of while
      end


      local pick = _math_random(1, #choices)
      local pply = choices[pick]

      -- we are less likely to be a detective unless we were innocent last round
      if (_IsValid(pply) and
          ((pply:GetBaseKarma() > min_karma and
           _table_HasValue(prev_roles[ROLE_INNOCENT], pply)) or
           _math_random(1,3) == 2)) then

         -- if a player has specified he does not want to be detective, we skip
         -- him here (he might still get it if we don't have enough
         -- alternatives)
         if not pply:GetAvoidDetective() then
            pply:SetRole(ROLE_DETECTIVE)
            ds = ds + 1
         end

         _table_remove(choices, pick)
      end
   end

   GAMEMODE.LastRole = {}

   for _, ply in _ipairs(plys) do
      -- initialize credit count for everyone based on their role
      ply:SetDefaultCredits()

      -- store a steamid -> role map
      GAMEMODE.LastRole[ply:SteamID()] = ply:GetRole()
   end
end


local function ForceRoundRestart(ply, command, args)
   -- ply is nil on dedicated server console
   if (not _IsValid(ply)) or ply:IsAdmin() or ply:IsSuperAdmin() or cvars.Bool("sv_cheats", 0) then
      LANG.Msg("round_restart")

      StopRoundTimers()

      -- do prep
      PrepareRound()
   else
      ply:PrintMessage(HUD_PRINTCONSOLE, "You must be a GMod Admin or SuperAdmin on the server to use this command, or sv_cheats must be enabled.")
   end
end
_concommand_Add("ttt_roundrestart", ForceRoundRestart)

function ShowVersion(ply)
   local text = _Format("This is TTT version %s\n", GAMEMODE.Version)
   if _IsValid(ply) then
      ply:PrintMessage(HUD_PRINTNOTIFY, text)
   else
      _Msg(text)
   end
end
_concommand_Add("ttt_version", ShowVersion)
