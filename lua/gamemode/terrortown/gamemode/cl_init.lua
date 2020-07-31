local _net_SendToServer = (CLIENT and net.SendToServer or nil)
local _net_Start = net.Start
local _RunConsoleCommand = RunConsoleCommand
local _Color = Color
local _net_WriteBool = net.WriteBool
local _include = include
local _LocalPlayer = (CLIENT and LocalPlayer or nil)
local _timer_Create = timer.Create
local _surface_PlaySound = (CLIENT and surface.PlaySound or nil)
local _net_ReadUInt = net.ReadUInt
local _print = print
local _player_GetByID = player.GetByID
local _timer_Simple = timer.Simple
local _ipairs = ipairs
local _CurTime = CurTime
local _GetGlobalInt = GetGlobalInt
local _concommand_Add = concommand.Add
local _net_Receive = net.Receive
local _player_GetAll = player.GetAll
local _surface_CreateFont = (CLIENT and surface.CreateFont or nil)
local _GetConVar = GetConVar
local _MsgN = MsgN
local _Msg = Msg
local _hook_Call = hook.Call
local _Sound = Sound
local _IsValid = IsValid
local _table_Random = table.Random
local _GetGlobalBool = GetGlobalBool
local _CreateConVar = CreateConVar
local _net_ReadBit = net.ReadBit
_include("shared.lua")

-- Define GM12 fonts for compatibility
_surface_CreateFont("DefaultBold", {font = "Tahoma",
                                   size = 13,
                                   weight = 1000})
_surface_CreateFont("TabLarge",    {font = "Tahoma",
                                   size = 13,
                                   weight = 700,
                                   shadow = true, antialias = false})
_surface_CreateFont("Trebuchet22", {font = "Trebuchet MS",
                                   size = 22,
                                   weight = 900})

_include("corpse_shd.lua")
_include("player_ext_shd.lua")
_include("weaponry_shd.lua")

_include("vgui/ColoredBox.lua")
_include("vgui/SimpleIcon.lua")
_include("vgui/ProgressBar.lua")
_include("vgui/ScrollLabel.lua")

_include("cl_radio.lua")
_include("cl_disguise.lua")
_include("cl_transfer.lua")
_include("cl_targetid.lua")
_include("cl_search.lua")
_include("cl_radar.lua")
_include("cl_tbuttons.lua")
_include("cl_scoreboard.lua")
_include("cl_tips.lua")
_include("cl_help.lua")
_include("cl_hud.lua")
_include("cl_msgstack.lua")
_include("cl_hudpickup.lua")
_include("cl_keys.lua")
_include("cl_wepswitch.lua")
_include("cl_scoring.lua")
_include("cl_scoring_events.lua")
_include("cl_popups.lua")
_include("cl_equip.lua")
_include("cl_voice.lua")

function GM:Initialize()
   _MsgN("TTT Client initializing...")

   GAMEMODE.round_state = ROUND_WAIT

   LANG.Init()

   self.BaseClass:Initialize()
end

function GM:InitPostEntity()
   _MsgN("TTT Client post-init...")

   _net_Start("TTT_Spectate")
     _net_WriteBool(_GetConVar("ttt_spectator_mode"):GetBool())
   _net_SendToServer()

   if not game.SinglePlayer() then
      _timer_Create("idlecheck", 5, 0, CheckIdle)
   end

   -- make sure player class extensions are loaded up, and then do some
   -- initialization on them
   if _IsValid(_LocalPlayer()) and _LocalPlayer().GetTraitor then
      GAMEMODE:ClearClientState()
   end

   _timer_Create("cache_ents", 1, 0, GAMEMODE.DoCacheEnts)

   _RunConsoleCommand("_ttt_request_serverlang")
   _RunConsoleCommand("_ttt_request_rolelist")
end

function GM:DoCacheEnts()
   RADAR:CacheEnts()
   TBHUD:CacheEnts()
end

function GM:HUDClear()
   RADAR:Clear()
   TBHUD:Clear()
end

KARMA = {}
function KARMA.IsEnabled() return _GetGlobalBool("ttt_karma", false) end

function GetRoundState() return GAMEMODE.round_state end

local function RoundStateChange(o, n)
   if n == ROUND_PREP then
      -- prep starts
      GAMEMODE:ClearClientState()
      GAMEMODE:CleanUpMap()

      -- show warning to spec mode players
      if _GetConVar("ttt_spectator_mode"):GetBool() and _IsValid(_LocalPlayer())then
         LANG.Msg("spec_mode_warning")
      end

      -- reset cached server language in case it has changed
      _RunConsoleCommand("_ttt_request_serverlang")
   elseif n == ROUND_ACTIVE then
      -- round starts
      VOICE.CycleMuteState(MUTE_NONE)

      CLSCORE:ClearPanel()

      -- people may have died and been searched during prep
      for _, p in _ipairs(_player_GetAll()) do
         p.search_result = nil
      end

      -- clear blood decals produced during prep
      _RunConsoleCommand("r_cleardecals")

      GAMEMODE.StartingPlayers = #util.GetAlivePlayers()
   elseif n == ROUND_POST then
      _RunConsoleCommand("ttt_cl_traitorpopup_close")
   end

   -- stricter checks when we're talking about hooks, because this function may
   -- be called with for example o = WAIT and n = POST, for newly connecting
   -- players, which hooking code may not expect
   if n == ROUND_PREP then
      -- can enter PREP from any phase due to ttt_roundrestart
      _hook_Call("TTTPrepareRound", GAMEMODE)
   elseif (o == ROUND_PREP) and (n == ROUND_ACTIVE) then
      _hook_Call("TTTBeginRound", GAMEMODE)
   elseif (o == ROUND_ACTIVE) and (n == ROUND_POST) then
      _hook_Call("TTTEndRound", GAMEMODE)
   end

   -- whatever round state we get, clear out the voice flags
   for k,v in _ipairs(_player_GetAll()) do
      v.traitor_gvoice = false
   end
end

_concommand_Add("ttt_print_playercount", function() _print(GAMEMODE.StartingPlayers) end)

--- optional sound cues on round start and end
_CreateConVar("ttt_cl_soundcues", "0", FCVAR_ARCHIVE)

local cues = {
   _Sound("ttt/thump01e.mp3"),
   _Sound("ttt/thump02e.mp3")
};
local function PlaySoundCue()
   if _GetConVar("ttt_cl_soundcues"):GetBool() then
      _surface_PlaySound(_table_Random(cues))
   end
end

GM.TTTBeginRound = PlaySoundCue
GM.TTTEndRound = PlaySoundCue

--- usermessages

local function ReceiveRole()
   local client = _LocalPlayer()
   local role = _net_ReadUInt(2)

   -- after a mapswitch, server might have sent us this before we are even done
   -- loading our code
   if not client.SetRole then return end

   client:SetRole(role)

   _Msg("You are: ")
   if client:IsTraitor() then _MsgN("TRAITOR")
   elseif client:IsDetective() then _MsgN("DETECTIVE")
   else _MsgN("INNOCENT") end
end
_net_Receive("TTT_Role", ReceiveRole)

local function ReceiveRoleList()
   local role = _net_ReadUInt(2)
   local num_ids = _net_ReadUInt(8)

   for i=1, num_ids do
      local eidx = _net_ReadUInt(7) + 1 -- we - 1 worldspawn=0

      local ply = _player_GetByID(eidx)
      if _IsValid(ply) and ply.SetRole then
         ply:SetRole(role)

         if ply:IsTraitor() then
            ply.traitor_gvoice = false -- assume traitorchat by default
         end
      end
   end
end
_net_Receive("TTT_RoleList", ReceiveRoleList)

-- Round state comm
local function ReceiveRoundState()
   local o = GetRoundState()
   GAMEMODE.round_state = _net_ReadUInt(3)

   if o != GAMEMODE.round_state then
      RoundStateChange(o, GAMEMODE.round_state)
   end

   _MsgN("Round state: " .. GAMEMODE.round_state)
end
_net_Receive("TTT_RoundState", ReceiveRoundState)

-- Cleanup at start of new round
function GM:ClearClientState()
   GAMEMODE:HUDClear()

   local client = _LocalPlayer()
   if not client.SetRole then return end -- code not loaded yet

   client:SetRole(ROLE_INNOCENT)

   client.equipment_items = EQUIP_NONE
   client.equipment_credits = 0
   client.bought = {}
   client.last_id = nil
   client.radio = nil
   client.called_corpses = {}

   VOICE.InitBattery()

   for _, p in _ipairs(_player_GetAll()) do
      if _IsValid(p) then
         p.sb_tag = nil
         p:SetRole(ROLE_INNOCENT)
         p.search_result = nil
      end
   end

   VOICE.CycleMuteState(MUTE_NONE)
   _RunConsoleCommand("ttt_mute_team_check", "0")

   if GAMEMODE.ForcedMouse then
      gui.EnableScreenClicker(false)
   end
end
_net_Receive("TTT_ClearClientState", GM.ClearClientState)

function GM:CleanUpMap()
   -- Ragdolls sometimes stay around on clients. Deleting them can create issues
   -- so all we can do is try to hide them.
   for _, ent in _ipairs(ents.FindByClass("prop_ragdoll")) do
      if _IsValid(ent) and CORPSE.GetPlayerNick(ent, "") != "" then
         ent:SetNoDraw(true)
         ent:SetSolid(SOLID_NONE)
         ent:SetColor(_Color(0,0,0,0))

         -- Horrible hack to make targetid ignore this ent, because we can't
         -- modify the collision group clientside.
         ent.NoTarget = true
      end
   end

   -- This cleans up decals since GMod v100
   game.CleanUpMap()
end

-- server tells us to call this when our LocalPlayer has spawned
local function PlayerSpawn()
   local as_spec = _net_ReadBit() == 1
   if as_spec then
      TIPS.Show()
   else
      TIPS.Hide()
   end
end
_net_Receive("TTT_PlayerSpawned", PlayerSpawn)

local function PlayerDeath()
   TIPS.Show()
end
_net_Receive("TTT_PlayerDied", PlayerDeath)

function GM:ShouldDrawLocalPlayer(ply) return false end

local view = {origin = vector_origin, angles = angle_zero, fov=0}
function GM:CalcView( ply, origin, angles, fov )
   view.origin = origin
   view.angles = angles
   view.fov    = fov

   -- first person ragdolling
   if ply:Team() == TEAM_SPEC and ply:GetObserverMode() == OBS_MODE_IN_EYE then
      local tgt = ply:GetObserverTarget()
      if _IsValid(tgt) and (not tgt:IsPlayer()) then
         -- assume if we are in_eye and not speccing a player, we spec a ragdoll
         local eyes = tgt:LookupAttachment("eyes") or 0
         eyes = tgt:GetAttachment(eyes)
         if eyes then
            view.origin = eyes.Pos
            view.angles = eyes.Ang
         end
      end
   end


   local wep = ply:GetActiveWeapon()
   if _IsValid(wep) then
      local func = wep.CalcView
      if func then
         view.origin, view.angles, view.fov = func( wep, ply, origin*1, angles*1, fov )
      end
   end

   return view
end

function GM:AddDeathNotice() end
function GM:DrawDeathNotice() end

function GM:Tick()
   local client = _LocalPlayer()
   if _IsValid(client) then
      if client:Alive() and client:Team() != TEAM_SPEC then
         WSWITCH:Think()
         RADIO:StoreTarget()
      end

      VOICE.Tick()
   end
end


-- Simple client-based idle checking
local idle = {ang = nil, pos = nil, mx = 0, my = 0, t = 0}
function CheckIdle()
   local client = _LocalPlayer()
   if not _IsValid(client) then return end

   if not idle.ang or not idle.pos then
      -- init things
      idle.ang = client:GetAngles()
      idle.pos = client:GetPos()
      idle.mx = gui.MouseX()
      idle.my = gui.MouseY()
      idle.t = _CurTime()

      return
   end

   if GetRoundState() == ROUND_ACTIVE and client:IsTerror() and client:Alive() then
      local idle_limit = _GetGlobalInt("ttt_idle_limit", 300) or 300
      if idle_limit <= 0 then idle_limit = 300 end -- networking sucks sometimes


      if client:GetAngles() != idle.ang then
         -- Normal players will move their viewing angles all the time
         idle.ang = client:GetAngles()
         idle.t = _CurTime()
      elseif gui.MouseX() != idle.mx or gui.MouseY() != idle.my then
         -- Players in eg. the Help will move their mouse occasionally
         idle.mx = gui.MouseX()
         idle.my = gui.MouseY()
         idle.t = _CurTime()
      elseif client:GetPos():Distance(idle.pos) > 10 then
         -- Even if players don't move their mouse, they might still walk
         idle.pos = client:GetPos()
         idle.t = _CurTime()
      elseif _CurTime() > (idle.t + idle_limit) then
         _RunConsoleCommand("say", "(AUTOMATED MESSAGE) I have been moved to the Spectator team because I was idle/AFK.")

         _timer_Simple(0.3, function()
                              _RunConsoleCommand("ttt_spectator_mode", 1)
                               _net_Start("TTT_Spectate")
                                 _net_WriteBool(true)
                               _net_SendToServer()
                              _RunConsoleCommand("ttt_cl_idlepopup")
                           end)
      elseif _CurTime() > (idle.t + (idle_limit / 2)) then
         -- will repeat
         LANG.Msg("idle_warning")
      end
   end
end

function GM:OnEntityCreated(ent)
   -- Make ragdolls look like the player that has died
   if ent:IsRagdoll() then
      local ply = CORPSE.GetPlayer(ent)

      if _IsValid(ply) then
         -- Only copy any decals if this ragdoll was recently created
         if ent:GetCreationTime() > _CurTime() - 1 then
            ent:SnatchModelInstance(ply)
         end

         -- Copy the color for the PlayerColor matproxy
         local playerColor = ply:GetPlayerColor()
         ent.GetPlayerColor = function()
            return playerColor
         end
      end
   end

   return self.BaseClass.OnEntityCreated(self, ent)
end
