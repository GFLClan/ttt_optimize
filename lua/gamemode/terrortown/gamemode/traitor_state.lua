local _concommand_Add = concommand.Add
local _net_Start = net.Start
local _player_GetAll = player.GetAll
local _net_Send = (SERVER and net.Send or nil)
local _table_Add = table.Add
local _IsValid = IsValid
local _net_Receive = net.Receive
local _tonumber = tonumber
local _net_ReadBool = net.ReadBool
local _table_insert = table.insert
local _ipairs = ipairs
local _net_Broadcast = (SERVER and net.Broadcast or nil)
local _net_WriteUInt = net.WriteUInt
function GetTraitors()
   local trs = {}
   for k,v in _ipairs(_player_GetAll()) do
      if v:GetTraitor() then _table_insert(trs, v) end
   end

   return trs
end

function CountTraitors() return #GetTraitors() end

---- Role state communication

-- Send every player their role
local function SendPlayerRoles()
   for k, v in _ipairs(_player_GetAll()) do
      _net_Start("TTT_Role")
         _net_WriteUInt(v:GetRole(), 2)
      _net_Send(v)
   end
end

local function SendRoleListMessage(role, role_ids, ply_or_rf)
   _net_Start("TTT_RoleList")
      _net_WriteUInt(role, 2)

      -- list contents
      local num_ids = #role_ids
      _net_WriteUInt(num_ids, 8)
      for i=1, num_ids do
         _net_WriteUInt(role_ids[i] - 1, 7)
      end

   if ply_or_rf then _net_Send(ply_or_rf)
   else _net_Broadcast() end
end

local function SendRoleList(role, ply_or_rf, pred)
   local role_ids = {}
   for k, v in _ipairs(_player_GetAll()) do
      if v:IsRole(role) then
         if not pred or (pred and pred(v)) then
            _table_insert(role_ids, v:EntIndex())
         end
      end
   end

   SendRoleListMessage(role, role_ids, ply_or_rf)
end

-- Tell traitors about other traitors

function SendTraitorList(ply_or_rf, pred) SendRoleList(ROLE_TRAITOR, ply_or_rf, pred) end
function SendDetectiveList(ply_or_rf) SendRoleList(ROLE_DETECTIVE, ply_or_rf) end

-- this is purely to make sure last round's traitors/dets ALWAYS get reset
-- not happy with this, but it'll do for now
function SendInnocentList(ply_or_rf)
   -- Send innocent and detectives a list of actual innocents + traitors, while
   -- sending traitors only a list of actual innocents.
   local inno_ids = {}
   local traitor_ids = {}
   for k, v in _ipairs(_player_GetAll()) do
      if v:IsRole(ROLE_INNOCENT) then
         _table_insert(inno_ids, v:EntIndex())
      elseif v:IsRole(ROLE_TRAITOR) then
         _table_insert(traitor_ids, v:EntIndex())
      end
   end

   -- traitors get actual innocent, so they do not reset their traitor mates to
   -- innocence
   SendRoleListMessage(ROLE_INNOCENT, inno_ids, GetTraitorFilter())

   -- detectives and innocents get an expanded version of the truth so that they
   -- reset everyone who is not detective
   _table_Add(inno_ids, traitor_ids)
   table.Shuffle(inno_ids)
   SendRoleListMessage(ROLE_INNOCENT, inno_ids, GetInnocentFilter())
end

function SendConfirmedTraitors(ply_or_rf)
   SendTraitorList(ply_or_rf, function(p) return p:GetNWBool("body_found") end)
end

function SendFullStateUpdate()
   SendPlayerRoles()
   SendInnocentList()
   SendTraitorList(GetTraitorFilter())
   SendDetectiveList()
   -- not useful to sync confirmed traitors here
end

function SendRoleReset(ply_or_rf)
   local plys = _player_GetAll()

   _net_Start("TTT_RoleList")
      _net_WriteUInt(ROLE_INNOCENT, 2)

      _net_WriteUInt(#plys, 8)
      for k, v in _ipairs(plys) do
         _net_WriteUInt(v:EntIndex() - 1, 7)
      end

   if ply_or_rf then _net_Send(ply_or_rf)
   else _net_Broadcast() end
end

---- Console commands

local function request_rolelist(ply)
   -- Client requested a state update. Note that the client can only use this
   -- information after entities have been initialised (e.g. in InitPostEntity).
   if GetRoundState() != ROUND_WAIT then

      SendRoleReset(ply)
      SendDetectiveList(ply)

      if ply:IsTraitor() then
         SendTraitorList(ply)
      else
         SendConfirmedTraitors(ply)
      end
   end
end
_concommand_Add("_ttt_request_rolelist", request_rolelist)

local function force_terror(ply)
   ply:SetRole(ROLE_INNOCENT)
   ply:UnSpectate()
   ply:SetTeam(TEAM_TERROR)

   ply:StripAll()

   ply:Spawn()
   ply:PrintMessage(HUD_PRINTTALK, "You are now on the terrorist team.")

   SendFullStateUpdate()
end
_concommand_Add("ttt_force_terror", force_terror, nil, nil, FCVAR_CHEAT)

local function force_traitor(ply)
   ply:SetRole(ROLE_TRAITOR)

   SendFullStateUpdate()
end
_concommand_Add("ttt_force_traitor", force_traitor, nil, nil, FCVAR_CHEAT)

local function force_detective(ply)
   ply:SetRole(ROLE_DETECTIVE)

   SendFullStateUpdate()
end
_concommand_Add("ttt_force_detective", force_detective, nil, nil, FCVAR_CHEAT)


local function force_spectate(ply, cmd, arg)
   if _IsValid(ply) then
      if #arg == 1 and _tonumber(arg[1]) == 0 then
         ply:SetForceSpec(false)
      else
         if not ply:IsSpec() then
            ply:Kill()
         end

         GAMEMODE:PlayerSpawnAsSpectator(ply)
         ply:SetTeam(TEAM_SPEC)
         ply:SetForceSpec(true)
         ply:Spawn()

         ply:SetRagdollSpec(false) -- dying will enable this, we don't want it here
      end
   end
end
_concommand_Add("ttt_spectate", force_spectate)
_net_Receive("TTT_Spectate", function(l, pl)
   force_spectate(pl, nil, { _net_ReadBool() and 1 or 0 })
end)
