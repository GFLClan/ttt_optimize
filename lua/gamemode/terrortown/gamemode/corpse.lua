local _IsValid = IsValid
local _net_Start = net.Start
local _tonumber = tonumber
local _table_Copy = table.Copy
local _include = include
local _ServerLog = (SERVER and ServerLog or nil)
local _table_insert = table.insert
local _net_WriteUInt = net.WriteUInt
local _net_WriteString = net.WriteString
local _net_WriteBit = net.WriteBit
local _net_WriteVector = net.WriteVector
local _Entity = Entity
local _timer_Simple = timer.Simple
local _CreateConVar = CreateConVar
local _net_Broadcast = (SERVER and net.Broadcast or nil)
local _net_Send = (SERVER and net.Send or nil)
local _concommand_Add = concommand.Add
local _GetConVarNumber = GetConVarNumber
local _player_GetBySteamID = player.GetBySteamID
local _net_WriteInt = net.WriteInt
local _CurTime = CurTime
local _math_Round = math.Round
local _hook_Call = hook.Call
local _math_max = math.max
local _pairs = pairs
local _hook_Run = hook.Run
---- Corpse functions

-- namespaced because we have no ragdoll metatable
CORPSE = {}

_include("corpse_shd.lua")

--- networked data abstraction layer
local dti = CORPSE.dti

function CORPSE.SetFound(rag, state)
   --rag:SetNWBool("found", state)
   rag:SetDTBool(dti.BOOL_FOUND, state)
end

function CORPSE.SetPlayerNick(rag, ply_or_name)
   -- don't have datatable strings, so use a dt entity for common case of
   -- still-connected player, and if the player is gone, fall back to nw string
   local name = ply_or_name
   if _IsValid(ply_or_name) then
      name = ply_or_name:Nick()
      rag:SetDTEntity(dti.ENT_PLAYER, ply_or_name)
   end

   rag:SetNWString("nick", name)
end

function CORPSE.SetCredits(rag, credits)
   --rag:SetNWInt("credits", credits)
   rag:SetDTInt(dti.INT_CREDITS, credits)
end


--- ragdoll creation and search

-- If detective mode, announce when someone's body is found
local bodyfound = _CreateConVar("ttt_announce_body_found", "1")

function GM:TTTCanIdentifyCorpse(ply, corpse, was_traitor)
   -- return true to allow corpse identification, false to disallow
   return true
end

local function IdentifyBody(ply, rag)
   if not ply:IsTerror() then return end

   -- simplified case for those who die and get found during prep
   if GetRoundState() == ROUND_PREP then
      CORPSE.SetFound(rag, true)
      return
   end
   
   if not _hook_Run("TTTCanIdentifyCorpse", ply, rag, (rag.was_role == ROLE_TRAITOR)) then
      return
   end

   local finder = ply:Nick()
   local nick = CORPSE.GetPlayerNick(rag, "")
   local traitor = (rag.was_role == ROLE_TRAITOR)
   
   -- Announce body
   if bodyfound:GetBool() and not CORPSE.GetFound(rag, false) then
      local roletext = nil
      local role = rag.was_role
      if role == ROLE_TRAITOR then
         roletext = "body_found_t"
      elseif role == ROLE_DETECTIVE then
         roletext = "body_found_d"
      else
         roletext = "body_found_i"
      end

      LANG.Msg("body_found", {finder = finder,
                              victim = nick,
                              role = LANG.Param(roletext)})
   end

   -- Register find
   if not CORPSE.GetFound(rag, false) then
      -- will return either false or a valid ply
      local deadply = _player_GetBySteamID(rag.sid)
      if deadply then
         deadply:SetNWBool("body_found", true)

         if traitor then
            -- update innocent's list of traitors
            SendConfirmedTraitors(GetInnocentFilter(false))
         end
         SCORE:HandleBodyFound(ply, deadply)
      end
      _hook_Call( "TTTBodyFound", GAMEMODE, ply, deadply, rag )
      CORPSE.SetFound(rag, true)
   else
      -- re-set because nwvars are unreliable
      --CORPSE.SetFound(rag, true)
      --CORPSE.SetPlayerNick(rag, nick)
   end

   -- Handle kill list
   for k, vicsid in _pairs(rag.kills) do
      -- filter out disconnected
      local vic = _player_GetBySteamID(vicsid)

      -- is this an unconfirmed dead?
      if _IsValid(vic) and (not vic:GetNWBool("body_found", false)) then
         LANG.Msg("body_confirm", {finder = finder, victim = vic:Nick()})

         -- update scoreboard status
         vic:SetNWBool("body_found", true)

         -- however, do not mark body as found. This lets players find the
         -- body later and get the benefits of that
         --local vicrag = vic.server_ragdoll
         --CORPSE.SetFound(vicrag, true)
      end
   end
end

-- Covert identify concommand for traitors
local function IdentifyCommand(ply, cmd, args)
   if not _IsValid(ply) then return end
   if #args != 2 then return end

   local eidx = _tonumber(args[1])
   local id = _tonumber(args[2])
   if (not eidx) or (not id) then return end


   if (not ply.search_id) or ply.search_id.id != id or ply.search_id.eidx != eidx then
      ply.search_id = nil
      return
   end

   ply.search_id = nil

   local rag = _Entity(eidx)
   if _IsValid(rag) and rag:GetPos():Distance(ply:GetPos()) < 128 then
      if not CORPSE.GetFound(rag, false) then
         IdentifyBody(ply, rag)
      end
   end
end
_concommand_Add("ttt_confirm_death", IdentifyCommand)

-- Call detectives to a corpse
local function CallDetective(ply, cmd, args)
   if not _IsValid(ply) then return end
   if #args != 1 then return end
   if not ply:IsActive() then return end

   local eidx = _tonumber(args[1])
   if not eidx then return end

   local rag = _Entity(eidx)
   if _IsValid(rag) and rag:GetPos():Distance(ply:GetPos()) < 128 then
      if CORPSE.GetFound(rag, false) then
         -- show indicator to detectives
         _net_Start("TTT_CorpseCall")
            _net_WriteVector(rag:GetPos())
         _net_Send(GetDetectiveFilter(true))

         LANG.Msg("body_call", {player = ply:Nick(),
                                victim = CORPSE.GetPlayerNick(rag, "someone")})

      else
         LANG.Msg(ply, "body_call_error")
      end
   end
end
_concommand_Add("ttt_call_detective", CallDetective)

local function bitsRequired(num)
   local bits, max = 0, 1
   while max <= num do
      bits = bits + 1
      max = max + max
   end
   return bits
end

function GM:TTTCanSearchCorpse(ply, corpse, is_covert, is_long_range, was_traitor)
   -- return true to allow corpse search, false to disallow.
   return true
end

-- Send a usermessage to client containing search results
function CORPSE.ShowSearch(ply, rag, covert, long_range)
   if not _IsValid(ply) or not _IsValid(rag) then return end

   if rag:IsOnFire() then
      LANG.Msg(ply, "body_burning")
      return
   end
   
   if not _hook_Run("TTTCanSearchCorpse", ply, rag, covert, long_range, (rag.was_role == ROLE_TRAITOR)) then
      return
   end

   -- init a heap of data we'll be sending
   local nick  = CORPSE.GetPlayerNick(rag)
   local traitor = (rag.was_role == ROLE_TRAITOR)
   local role  = rag.was_role
   local eq    = rag.equipment or EQUIP_NONE
   local c4    = rag.bomb_wire or -1
   local dmg   = rag.dmgtype or DMG_GENERIC
   local wep   = rag.dmgwep or ""
   local words = rag.last_words or ""
   local hshot = rag.was_headshot or false
   local dtime = rag.time or 0
   
   local owner = _player_GetBySteamID(rag.sid)
   owner = _IsValid(owner) and owner:EntIndex() or -1

   -- basic sanity check
   if nick == nil or eq == nil or role == nil then return end

   if DetectiveMode() and not covert then
      IdentifyBody(ply, rag)
   end

   local credits = CORPSE.GetCredits(rag, 0)
   if ply:IsActiveSpecial() and credits > 0 and (not long_range) then
      LANG.Msg(ply, "body_credits", {num = credits})
      ply:AddCredits(credits)

      CORPSE.SetCredits(rag, 0)

      _ServerLog(ply:Nick() .. " took " .. credits .. " credits from the body of " .. nick .. "\n")
      SCORE:HandleCreditFound(ply, nick, credits)
   end

   -- time of death relative to current time (saves bits)
   if dtime != 0 then
      dtime = _math_Round(_CurTime() - dtime)
   end

   -- identifier so we know whether a ttt_confirm_death was legit
   ply.search_id = { eidx = rag:EntIndex(), id = rag:EntIndex() + dtime }

   -- time of dna sample decay relative to current time
   local stime = 0
   if rag.killer_sample then
      stime = _math_max(0, rag.killer_sample.t - _CurTime())
   end

   -- build list of people this traitor killed
   local kill_entids = {}
   for k, vicsid in _pairs(rag.kills) do
      -- also send disconnected players as a marker
      local vic = _player_GetBySteamID(vicsid)
      _table_insert(kill_entids, _IsValid(vic) and vic:EntIndex() or -1)
   end

   local lastid = -1
   if rag.lastid and ply:IsActiveDetective() then
      -- if the person this victim last id'd has since disconnected, send -1 to
      -- indicate this
      lastid = _IsValid(rag.lastid.ent) and rag.lastid.ent:EntIndex() or -1
   end

   -- Send a message with basic info
   _net_Start("TTT_RagdollSearch")
      _net_WriteUInt(rag:EntIndex(), 16) -- 16 bits
      _net_WriteUInt(owner, 8) -- 128 max players. ( 8 bits )
      _net_WriteString(nick)
      _net_WriteUInt(eq, 16) -- Equipment ( 16 = max. )
      _net_WriteUInt(role, 2) -- ( 2 bits )
      _net_WriteInt(c4, bitsRequired(C4_WIRE_COUNT) + 1) -- -1 -> 2^bits ( default c4: 4 bits )
      _net_WriteUInt(dmg, 30) -- DMG_BUCKSHOT is the highest. ( 30 bits )
      _net_WriteString(wep)
      _net_WriteBit(hshot) -- ( 1 bit )
      _net_WriteInt(dtime, 16)
      _net_WriteInt(stime, 16)

      _net_WriteUInt(#kill_entids, 8)
      for k, idx in _pairs(kill_entids) do
         _net_WriteUInt(idx, 8) -- first game.MaxPlayers() of entities are for players.
      end

      _net_WriteUInt(lastid, 8)

      -- Who found this, so if we get this from a detective we can decide not to
      -- show a window
      _net_WriteUInt(ply:EntIndex(), 8)

      _net_WriteString(words)

      -- 133 + string data + #kill_entids * 8
      -- 200

   -- If found by detective, send to all, else just the finder
   if ply:IsActiveDetective() then
      _net_Broadcast()
   else
      _net_Send(ply)
   end
end


-- Returns a sample for use in dna scanner if the kill fits certain constraints,
-- else returns nil
local function GetKillerSample(victim, attacker, dmg)
   -- only guns and melee damage, not explosions
   if not (dmg:IsBulletDamage() or dmg:IsDamageType(DMG_SLASH) or dmg:IsDamageType(DMG_CLUB)) then
      return nil
   end

   if not (_IsValid(victim) and _IsValid(attacker) and attacker:IsPlayer()) then return end

   -- NPCs for which a player is damage owner (meaning despite the NPC dealing
   -- the damage, the attacker is a player) should not cause the player's DNA to
   -- end up on the corpse.
   local infl = dmg:GetInflictor()
   if _IsValid(infl) and infl:IsNPC() then return end

   local dist = victim:GetPos():Distance(attacker:GetPos())
   if dist > _GetConVarNumber("ttt_killer_dna_range") then return nil end

   local sample = {}
   sample.killer = attacker
   sample.killer_sid = attacker:SteamID()
   sample.victim = victim
   sample.t      = _CurTime() + (-1 * (0.019 * dist)^2 + _GetConVarNumber("ttt_killer_dna_basetime"))

   return sample
end

local crimescene_keys = {"Fraction", "HitBox", "Normal", "HitPos", "StartPos"}
local poseparams = {
   "aim_yaw", "move_yaw", "aim_pitch",
--   "spine_yaw", "head_yaw", "head_pitch"
};

local function GetSceneDataFromPlayer(ply)
   local data = {
      pos      = ply:GetPos(),
      ang      = ply:GetAngles(),
      sequence = ply:GetSequence(),
      cycle    = ply:GetCycle()
   };

   for _, param in _pairs(poseparams) do
      data[param] = ply:GetPoseParameter(param)
   end

   return data
end

local function GetSceneData(victim, attacker, dmginfo)
   -- only for guns for now, hull traces don't work well etc
   if not dmginfo:IsBulletDamage() then return end

   local scene = {}

   if victim.hit_trace then
      scene.hit_trace = table.CopyKeys(victim.hit_trace, crimescene_keys)
   else
      return scene
   end

   scene.victim = GetSceneDataFromPlayer(victim)

   if _IsValid(attacker) and attacker:IsPlayer() then
      scene.killer = GetSceneDataFromPlayer(attacker)

      local att = attacker:LookupAttachment("anim_attachment_RH")
      local angpos = attacker:GetAttachment(att)
      if not angpos then
         scene.hit_trace.StartPos = attacker:GetShootPos()
      else
         scene.hit_trace.StartPos = angpos.Pos
      end
   end

   return scene
end

local rag_collide = _CreateConVar("ttt_ragdoll_collide", "0")

-- Creates client or server ragdoll depending on settings
function CORPSE.Create(ply, attacker, dmginfo)
   if not _IsValid(ply) then return end

   local rag = ents.Create("prop_ragdoll")
   if not _IsValid(rag) then return nil end

   rag:SetPos(ply:GetPos())
   rag:SetModel(ply:GetModel())
   rag:SetSkin(ply:GetSkin())
   for key, value in _pairs(ply:GetBodyGroups()) do
      rag:SetBodygroup(value.id, ply:GetBodygroup(value.id))   
   end
   rag:SetAngles(ply:GetAngles())
   rag:SetColor(ply:GetColor())

   rag:Spawn()
   rag:Activate()

   -- nonsolid to players, but can be picked up and shot
   rag:SetCollisionGroup(rag_collide:GetBool() and COLLISION_GROUP_WEAPON or COLLISION_GROUP_DEBRIS_TRIGGER)

   -- flag this ragdoll as being a player's
   rag.player_ragdoll = true
   rag.sid = ply:SteamID()

   rag.uqid = ply:UniqueID() -- backwards compatibility; use rag.sid instead

   -- network data
   CORPSE.SetPlayerNick(rag, ply)
   CORPSE.SetFound(rag, false)
   CORPSE.SetCredits(rag, ply:GetCredits())

   -- if someone searches this body they can find info on the victim and the
   -- death circumstances
   rag.equipment = ply:GetEquipmentItems()
   rag.was_role = ply:GetRole()
   rag.bomb_wire = ply.bomb_wire
   rag.dmgtype = dmginfo:GetDamageType()

   local wep = util.WeaponFromDamage(dmginfo)
   rag.dmgwep = _IsValid(wep) and wep:GetClass() or ""

   rag.was_headshot = (ply.was_headshot and dmginfo:IsBulletDamage())
   rag.time = _CurTime()
   rag.kills = _table_Copy(ply.kills)

   rag.killer_sample = GetKillerSample(ply, attacker, dmginfo)

   -- crime scene data
   rag.scene = GetSceneData(ply, attacker, dmginfo)


   -- position the bones
   local num = rag:GetPhysicsObjectCount()-1
   local v = ply:GetVelocity()

   -- bullets have a lot of force, which feels better when shooting props,
   -- but makes bodies fly, so dampen that here
   if dmginfo:IsDamageType(DMG_BULLET) or dmginfo:IsDamageType(DMG_SLASH) then
      v = v / 5
   end

   for i=0, num do
      local bone = rag:GetPhysicsObjectNum(i)
      if _IsValid(bone) then
         local bp, ba = ply:GetBonePosition(rag:TranslatePhysBoneToBone(i))
         if bp and ba then
            bone:SetPos(bp)
            bone:SetAngles(ba)
         end

         -- not sure if this will work:
         bone:SetVelocity(v)
      end
   end

   -- create advanced death effects (knives)
   if ply.effect_fn then
      -- next frame, after physics is happy for this ragdoll
      local efn = ply.effect_fn
      _timer_Simple(0, function() efn(rag) end)
   end
   
   _hook_Run("TTTOnCorpseCreated", rag, ply)

   return rag -- we'll be speccing this
end
