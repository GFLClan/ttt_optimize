local _IsValid = IsValid
local _net_Start = net.Start
local _isentity = isentity
local _string_len = string.len
local _string_match = string.match
local _table_concat = table.concat
local _string_Trim = string.Trim
local _team_GetName = team.GetName
local _net_WriteString = net.WriteString
local _net_WriteBit = net.WriteBit
local _Entity = Entity
local _table_insert = table.insert
local _team_Valid = team.Valid
local _ipairs = ipairs
local _net_Broadcast = (SERVER and net.Broadcast or nil)
local _net_WriteUInt = net.WriteUInt
local _concommand_Add = concommand.Add
local _string_sub = string.sub
local _player_GetAll = player.GetAll
local _net_Send = (SERVER and net.Send or nil)
local _GetConVar = GetConVar
local _CurTime = CurTime
local _hook_Call = hook.Call
local _tonumber = tonumber
local _math_random = math.random
local _string_Explode = string.Explode
local _CreateConVar = CreateConVar
local _net_WriteEntity = net.WriteEntity
---- Communicating game state to players

local net = net
local string = string
local table = table
local ipairs = _ipairs
local IsValid = _IsValid

-- NOTE: most uses of the Msg functions here have been moved to the LANG
-- functions. These functions are essentially deprecated, though they won't be
-- removed and can safely be used by SWEPs and the like.

function GameMsg(msg)
   _net_Start("TTT_GameMsg")
      _net_WriteString(msg)
      _net_WriteBit(false)
   _net_Broadcast()
end

function CustomMsg(ply_or_rf, msg, clr)
   clr = clr or COLOR_WHITE

   _net_Start("TTT_GameMsgColor")
      _net_WriteString(msg)
      _net_WriteUInt(clr.r, 8)
      _net_WriteUInt(clr.g, 8)
      _net_WriteUInt(clr.b, 8)
   if ply_or_rf then _net_Send(ply_or_rf)
   else _net_Broadcast() end
end

-- Basic status message to single player or a recipientfilter
function PlayerMsg(ply_or_rf, msg, traitor_only)
   _net_Start("TTT_GameMsg")
      _net_WriteString(msg)
      _net_WriteBit(traitor_only)
   if ply_or_rf then _net_Send(ply_or_rf)
   else _net_Broadcast() end
end

-- Traitor-specific message that will appear in a special color
function TraitorMsg(ply_or_rfilter, msg)
   PlayerMsg(ply_or_rfilter, msg, true)
end

-- Traitorchat
local function RoleChatMsg(sender, role, msg)
   _net_Start("TTT_RoleChat")
      _net_WriteUInt(role, 2)
      _net_WriteEntity(sender)
      _net_WriteString(msg)
   _net_Send(GetRoleFilter(role))
end


-- Round start info popup
function ShowRoundStartPopup()
   for k, v in ipairs(_player_GetAll()) do
      if IsValid(v) and v:Team() == TEAM_TERROR and v:Alive() then
         v:ConCommand("ttt_cl_startpopup")
      end
   end
end

local function GetPlayerFilter(pred)
   local filter = {}
   for k, v in ipairs(_player_GetAll()) do
      if IsValid(v) and pred(v) then
         _table_insert(filter, v)
      end
   end
   return filter
end

function GetTraitorFilter(alive_only)
   return GetPlayerFilter(function(p) return p:GetTraitor() and (not alive_only or p:IsTerror()) end)
end

function GetDetectiveFilter(alive_only)
   return GetPlayerFilter(function(p) return p:IsDetective() and (not alive_only or p:IsTerror()) end)
end

function GetInnocentFilter(alive_only)
   return GetPlayerFilter(function(p) return (not p:IsTraitor()) and (not alive_only or p:IsTerror()) end)
end

function GetRoleFilter(role, alive_only)
   return GetPlayerFilter(function(p) return p:IsRole(role) and (not alive_only or p:IsTerror()) end)
end

---- Communication control
_CreateConVar("ttt_limit_spectator_chat", "1", FCVAR_ARCHIVE + FCVAR_NOTIFY)
_CreateConVar("ttt_limit_spectator_voice", "1", FCVAR_ARCHIVE + FCVAR_NOTIFY)

function GM:PlayerCanSeePlayersChat(text, team_only, listener, speaker)
   if (not IsValid(listener)) then return false end
   if (not IsValid(speaker)) then
      if _isentity(speaker) then
         return true
      else
         return false
      end
   end

   local sTeam = speaker:Team() == TEAM_SPEC
   local lTeam = listener:Team() == TEAM_SPEC

   if (GetRoundState() != ROUND_ACTIVE) or   -- Round isn't active
   (not _GetConVar("ttt_limit_spectator_chat"):GetBool()) or   -- Spectators can chat freely
   (not DetectiveMode()) or   -- Mumbling
   (not sTeam and ((team_only and not speaker:IsSpecial()) or (not team_only))) or   -- If someone alive talks (and not a special role in teamchat's case)
   (not sTeam and team_only and speaker:GetRole() == listener:GetRole()) or
   (sTeam and lTeam) then   -- If the speaker and listener are spectators
      return true
   end

   return false
end

local mumbles = {"mumble", "mm", "hmm", "hum", "mum", "mbm", "mble", "ham", "mammaries", "political situation", "mrmm", "hrm",
"uzbekistan", "mumu", "cheese export", "hmhm", "mmh", "mumble", "mphrrt", "mrh", "hmm", "mumble", "mbmm", "hmml", "mfrrm"}

-- While a round is active, spectators can only talk among themselves. When they
-- try to speak to all players they could divulge information about who killed
-- them. So we mumblify them. In detective mode, we shut them up entirely.
function GM:PlayerSay(ply, text, team_only)
   if not IsValid(ply) then return text or "" end

   if GetRoundState() == ROUND_ACTIVE then
      local team = ply:Team() == TEAM_SPEC
      if team and not DetectiveMode() then
         local filtered = {}
         for k, v in ipairs(_string_Explode(" ", text)) do
            -- grab word characters and whitelisted interpunction
            -- necessary or leetspeek will be used (by trolls especially)
            local word, interp = _string_match(v, "(%a*)([%.,;!%?]*)")
            if word != "" then
               _table_insert(filtered, mumbles[_math_random(1, #mumbles)] .. interp)
            end
         end

         -- make sure we have something to say
         if table.IsEmpty(filtered) then
            _table_insert(filtered, mumbles[_math_random(1, #mumbles)])
         end

         _table_insert(filtered, 1, "[MUMBLED]")
         return _table_concat(filtered, " ")
      elseif team_only and not team and ply:IsSpecial() then
        RoleChatMsg(ply, ply:GetRole(), text)
       return ""
      end
   end

   return text or ""
end


-- Mute players when we are about to run map cleanup, because it might cause
-- net buffer overflows on clients.
local mute_all = false
function MuteForRestart(state)
   mute_all = state
end


local loc_voice = _CreateConVar("ttt_locational_voice", "0")

-- Of course voice has to be limited as well
function GM:PlayerCanHearPlayersVoice(listener, speaker)
   -- Enforced silence
   if mute_all then
      return false, false
   end

   if (not IsValid(speaker)) or (not IsValid(listener)) or (listener == speaker) then
      return false, false
   end

   -- limited if specific convar is on, or we're in detective mode
   local limit = DetectiveMode() or _GetConVar("ttt_limit_spectator_voice"):GetBool()

   -- Spectators should not be heard by living players during round
   if speaker:IsSpec() and (not listener:IsSpec()) and limit and GetRoundState() == ROUND_ACTIVE then
      return false, false
   end

   -- Specific mute
   if listener:IsSpec() and listener.mute_team == speaker:Team() or listener.mute_team == MUTE_ALL then
      return false, false
   end

   -- Specs should not hear each other locationally
   if speaker:IsSpec() and listener:IsSpec() then
      return true, false
   end

   -- Traitors "team"chat by default, non-locationally
   if speaker:IsActiveTraitor() then
      if speaker.traitor_gvoice then
         return true, loc_voice:GetBool()
      elseif listener:IsActiveTraitor() then
         return true, false
      else
         -- unless traitor_gvoice is true, normal innos can't hear speaker
         return false, false
      end
   end

   return true, (loc_voice:GetBool() and GetRoundState() != ROUND_POST)
end

local function SendTraitorVoiceState(speaker, state)
   -- send umsg to living traitors that this is traitor-only talk
   local rf = GetTraitorFilter(true)

   -- make it as small as possible, to get there as fast as possible
   -- we can fit it into a mere byte by being cheeky.
   _net_Start("TTT_TraitorVoiceState")
      _net_WriteUInt(speaker:EntIndex() - 1, 7) -- player ids can only be 1-128
      _net_WriteBit(state)
   if rf then _net_Send(rf)
   else _net_Broadcast() end
end


local function TraitorGlobalVoice(ply, cmd, args)
   if not IsValid(ply) or not ply:IsActiveTraitor() then return end
   if #args != 1 then return end
   local state = _tonumber(args[1])

   ply.traitor_gvoice = (state == 1)

   SendTraitorVoiceState(ply, ply.traitor_gvoice)
end
_concommand_Add("tvog", TraitorGlobalVoice)

local function MuteTeam(ply, cmd, args)
   if not IsValid(ply) then return end
   if not (#args == 1 and _tonumber(args[1])) then return end
   if not ply:IsSpec() then
      ply.mute_team = -1
      return
   end

   local t = _tonumber(args[1])
   ply.mute_team = t

   if t == MUTE_ALL then
      ply:ChatPrint("All muted.")
   elseif t == MUTE_NONE or t == TEAM_UNASSIGNED or not _team_Valid(t) then
      ply:ChatPrint("None muted.")
   else
      ply:ChatPrint(_team_GetName(t) .. " muted.")
   end
end
_concommand_Add("ttt_mute_team", MuteTeam)

local ttt_lastwords = _CreateConVar("ttt_lastwords_chatprint", "0")

local LastWordContext = {
   [KILL_NORMAL] = "",
   [KILL_SUICIDE] = " *kills self*",
   [KILL_FALL] = " *SPLUT*",
   [KILL_BURN] = " *crackle*"
};

local function LastWordsMsg(ply, words)
   -- only append "--" if there's no ending interpunction
   local final = _string_match(words, "[\\.\\!\\?]$") != nil

   -- add optional context relating to death type
   local context = LastWordContext[ply.death_type] or ""

   _net_Start("TTT_LastWordsMsg")
      _net_WriteEntity(ply)
      _net_WriteString(words .. (final and "" or "--") .. context)
   _net_Broadcast()
end

local function LastWords(ply, cmd, args)
   if IsValid(ply) and (not ply:Alive()) and #args > 1 then
      local id = _tonumber(args[1])
      if id and ply.last_words_id and id == ply.last_words_id then
         -- never allow multiple last word stuff
         ply.last_words_id = nil

         -- we will be storing this on the ragdoll
         local rag = ply.server_ragdoll
         if not (IsValid(rag) and rag.player_ragdoll) then
            rag = nil
         end

         --- last id'd person
         local last_seen = _tonumber(args[2])
         if last_seen then
            local ent = _Entity(last_seen)
            if IsValid(ent) and ent:IsPlayer() and rag and (not rag.lastid) then
               rag.lastid = {ent=ent, t=_CurTime()}
            end
         end

         --- last words
         local words = _string_Trim(args[3])

         -- nothing of interest
         if _string_len(words) < 2 then return end

         -- ignore admin commands
         local firstchar = _string_sub(words, 1, 1)
         if firstchar == "!" or firstchar == "@" or firstchar == "/" then return end


         if ttt_lastwords:GetBool() or ply.death_type == KILL_FALL then
            LastWordsMsg(ply, words)
         end

         if rag and (not rag.last_words) then
            rag.last_words = words
         end
      else
         ply.last_words_id = nil
      end
   end
end
_concommand_Add("_deathrec", LastWords)

-- Override or hook in plugin for spam prevention and whatnot. Return true
-- to block a command.
function GM:TTTPlayerRadioCommand(ply, msg_name, msg_target)
   if ply.LastRadioCommand and ply.LastRadioCommand > (_CurTime() - 0.5) then return true end
   ply.LastRadioCommand = _CurTime()
end

local function RadioCommand(ply, cmd, args)
   if IsValid(ply) and ply:IsTerror() and #args == 2 then
      local msg_name = args[1]
      local msg_target = args[2]

      local name = ""
      local rag_name = nil

      if _tonumber(msg_target) then
         -- player or corpse ent idx
         local ent = _Entity(_tonumber(msg_target))
         if IsValid(ent) then
            if ent:IsPlayer() then
               name = ent:Nick()
            elseif ent:GetClass() == "prop_ragdoll" then
               name = LANG.NameParam("quick_corpse_id")
               rag_name = CORPSE.GetPlayerNick(ent, "A Terrorist")
            end
         end

         msg_target = ent
      else
         -- lang string
         name = LANG.NameParam(msg_target)
      end

      if _hook_Call("TTTPlayerRadioCommand", GAMEMODE, ply, msg_name, msg_target) then
         return
      end

      _net_Start("TTT_RadioMsg")
         _net_WriteEntity(ply)
         _net_WriteString(msg_name)
         _net_WriteString(name)
         if rag_name then
            _net_WriteString(rag_name)
         end
      _net_Broadcast()
   end
end
_concommand_Add("_ttt_radio_send", RadioCommand)
