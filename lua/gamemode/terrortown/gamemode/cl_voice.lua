local _Format = Format
local _string_upper = string.upper
local _vgui_Create = (CLIENT and vgui.Create or nil)
local _concommand_Add = concommand.Add
local _math_Clamp = math.Clamp
local _surface_DrawOutlinedRect = (CLIENT and surface.DrawOutlinedRect or nil)
local _LocalPlayer = (CLIENT and LocalPlayer or nil)
local _surface_DrawRect = (CLIENT and surface.DrawRect or nil)
local _print = print
local _next = next
local _table_insert = table.insert
local _ScrW = (CLIENT and ScrW or nil)
local _player_GetByID = player.GetByID
local _isstring = isstring
local _pairs = pairs
local _GetGlobalBool = GetGlobalBool
local _net_ReadString = net.ReadString
local _surface_SetTexture = (CLIENT and surface.SetTexture or nil)
local _IsValid = IsValid
local _surface_SetDrawColor = (CLIENT and surface.SetDrawColor or nil)
local _RunConsoleCommand = RunConsoleCommand
local _Color = Color
local _hook_Add = hook.Add
local _surface_GetTextureID = (CLIENT and surface.GetTextureID or nil)
local _draw_RoundedBox = (CLIENT and draw.RoundedBox or nil)
local _GetGlobalFloat = GetGlobalFloat
local _surface_DrawTexturedRect = (CLIENT and surface.DrawTexturedRect or nil)
local _timer_Create = timer.Create
local _net_Receive = net.Receive
local _net_ReadUInt = net.ReadUInt
local _string_find = string.find
local _CurTime = CurTime
local _math_max = math.max
local _tostring = tostring
local _ScrH = (CLIENT and ScrH or nil)
local _net_ReadEntity = net.ReadEntity
local _net_ReadBit = net.ReadBit
---- Voicechat popup, radio commands, text chat stuff
local acol1 = _Color(50, 200, 255)

DEFINE_BASECLASS("gamemode_base")

local GetTranslation = LANG.GetTranslation
local GetPTranslation = LANG.GetParamTranslation
local string = string
local lwsc1,lwsc2 = _Color( 150, 150, 150 ),_Color(0, 200, 0)
local function LastWordsRecv()
   local sender = _net_ReadEntity()
   local words  = _net_ReadString()

   local was_detective = _IsValid(sender) and sender:IsDetective()
   local nick = _IsValid(sender) and sender:Nick() or "<Unknown>"

   chat.AddText(lwsc1,
                _Format("(%s) ", _string_upper(GetTranslation("last_words"))),
                was_detective and acol1 or lwsc2,
                nick,
                COLOR_WHITE,
                ": " .. words)
end
_net_Receive("TTT_LastWordsMsg", LastWordsRecv)

local col1,col2,col3,col4,col5,col6 = _Color( 20, 100, 255 ),_Color( 25, 200, 255),_Color( 255, 30, 40 ),_Color( 255, 200, 20),_Color( 255, 255, 200),_Color( 200, 255, 255)
local function RoleChatRecv()
   -- virtually always our role, but future equipment might allow listening in
   local role = _net_ReadUInt(2)
   local sender = _net_ReadEntity()
   if not _IsValid(sender) then return end

   local text = _net_ReadString()

   if role == ROLE_TRAITOR then
      chat.AddText(col3,
                   _Format("(%s) ", _string_upper(GetTranslation("traitor"))),
                   col4,
                   sender:Nick(),
                   col5,
                   ": " .. text)

   elseif role == ROLE_DETECTIVE then
      chat.AddText(col1,
                   _Format("(%s) ", _string_upper(GetTranslation("detective"))),
                   col2,
                   sender:Nick(),
                   col6,
                   ": " .. text)
   end
end
_net_Receive("TTT_RoleChat", RoleChatRecv)

-- special processing for certain special chat types
function GM:ChatText(idx, name, text, type)

   if type == "joinleave" then
      if _string_find(text, "Changed name during a round") then
         -- prevent nick from showing up
         chat.AddText(LANG.GetTranslation("name_kick"))
         return true
      end
   end

   return BaseClass.ChatText(self, idx, name, text, type)
end

local dttc = _Color(255,255,255)
-- Detectives have a blue name, in both chat and radio messages
local function AddDetectiveText(ply, text)
   chat.AddText(acol1,
                ply:Nick(),
                dttc,
                ": " .. text)
end

function GM:OnPlayerChat(ply, text, teamchat, dead)
   if not _IsValid(ply) then return BaseClass.OnPlayerChat(self, ply, text, teamchat, dead) end 
   
   if ply:IsActiveDetective() then
      AddDetectiveText(ply, text)
      return true
   end
   
   local team = ply:Team() == TEAM_SPEC
   
   if team and not dead then
      dead = true
   end
   
   if teamchat and ((not team and not ply:IsSpecial()) or team) then
      teamchat = false
   end

   return BaseClass.OnPlayerChat(self, ply, text, teamchat, dead)
end

local last_chat = ""
function GM:ChatTextChanged(text)
   last_chat = text
end

function ChatInterrupt()
   local client = _LocalPlayer()
   local id = _net_ReadUInt(32)

   local last_seen = _IsValid(client.last_id) and client.last_id:EntIndex() or 0

   local last_words = "."
   if last_chat == "" then
      if RADIO.LastRadio.t > _CurTime() - 2 then
         last_words = RADIO.LastRadio.msg
      end
   else
      last_words = last_chat
   end

   _RunConsoleCommand("_deathrec", _tostring(id), _tostring(last_seen), last_words)
end
_net_Receive("TTT_InterruptChat", ChatInterrupt)

--- Radio

RADIO = {}
RADIO.Show = false

RADIO.StoredTarget = {nick="", t=0}
RADIO.LastRadio = {msg="", t=0}

-- [key] -> command
RADIO.Commands = {
   {cmd="yes",      text="quick_yes", format=false},
   {cmd="no",       text="quick_no", format=false},
   {cmd="help",     text="quick_help", format=false},
   {cmd="imwith",   text="quick_imwith", format=true},
   {cmd="see",      text="quick_see", format=true},
   {cmd="suspect",  text="quick_suspect", format=true},
   {cmd="traitor",  text="quick_traitor", format=true},
   {cmd="innocent", text="quick_inno", format=true},
   {cmd="check",    text="quick_check", format=false}
};

local radioframe = nil

function RADIO:ShowRadioCommands(state)
   if not state then
      if radioframe and radioframe:IsValid() then
         radioframe:Remove()
         radioframe = nil

         -- don't capture keys
         self.Show = false
      end
   else
      local client = _LocalPlayer()
      if not _IsValid(client) then return end

      if not radioframe then

         local w, h = 200, 300

         radioframe = _vgui_Create("DForm")
         radioframe:SetName(GetTranslation("quick_title"))
         radioframe:SetSize(w, h)
         radioframe:SetMouseInputEnabled(false)
         radioframe:SetKeyboardInputEnabled(false)

         radioframe:CenterVertical()

         -- ASS
         radioframe.ForceResize = function(s)
                                     local w, label = 0, nil
                                     for k,v in _pairs(s.Items) do
                                        label = v:GetChild(0)
                                        if label:GetWide() > w then
                                           w = label:GetWide()
                                        end
                                     end
                                     s:SetWide(w + 20)
                                  end

         for key, command in _pairs(self.Commands) do
            local dlabel = _vgui_Create("DLabel", radioframe)
            local id = key .. ": "
            local txt = id
            if command.format then
               txt = txt .. GetPTranslation(command.text, {player = GetTranslation("quick_nobody")})
            else
               txt = txt .. GetTranslation(command.text)
            end

            dlabel:SetText(txt)
            dlabel:SetFont("TabLarge")
            dlabel:SetTextColor(COLOR_WHITE)
            dlabel:SizeToContents()

            if command.format then
               dlabel.target = nil
               dlabel.id = id
               dlabel.txt = GetTranslation(command.text)
               dlabel.Think = function(s)
                                 local tgt, v = RADIO:GetTarget()
                                 if s.target != tgt then
                                    s.target = tgt

                                    tgt = string.Interp(s.txt, {player = RADIO.ToPrintable(tgt)})
                                    if v then
                                       tgt = util.Capitalize(tgt)
                                    end

                                    s:SetText(s.id .. tgt)
                                    s:SizeToContents()
                                    radioframe:ForceResize()
                                 end
                              end
            end

            radioframe:AddItem(dlabel)
         end

         radioframe:ForceResize()
      end

      radioframe:MakePopup()

      -- grabs input on init(), which happens in makepopup
      radioframe:SetMouseInputEnabled(false)
      radioframe:SetKeyboardInputEnabled(false)

      -- capture slot keys while we're open
      self.Show = true

      _timer_Create("radiocmdshow", 3, 1,
                   function() RADIO:ShowRadioCommands(false) end)
   end
end

function RADIO:SendCommand(slotidx)
   local c = self.Commands[slotidx]
   if c then
      _RunConsoleCommand("ttt_radio", c.cmd)

      self:ShowRadioCommands(false)
   end
end

function RADIO:GetTargetType()
   if not _IsValid(_LocalPlayer()) then return end
   local trace = _LocalPlayer():GetEyeTrace(MASK_SHOT)

   if not trace or (not trace.Hit) or (not _IsValid(trace.Entity)) then return end

   local ent = trace.Entity

   if ent:IsPlayer() and  ent:IsTerror() then
      if ent:GetNWBool("disguised", false) then
         return "quick_disg", true
      else
         return ent, false
      end
   elseif ent:GetClass() == "prop_ragdoll" and CORPSE.GetPlayerNick(ent, "") != "" then

      if DetectiveMode() and not CORPSE.GetFound(ent, false) then
         return "quick_corpse", true
      else
         return ent, false
      end
   end
end


function RADIO.ToPrintable(target)
   if _isstring(target) then
      return GetTranslation(target)
   elseif _IsValid(target) then
      if target:IsPlayer() then
         return target:Nick()
      elseif target:GetClass() == "prop_ragdoll" then
         return GetPTranslation("quick_corpse_id", {player = CORPSE.GetPlayerNick(target, "A Terrorist")})
      end
   end
end

function RADIO:GetTarget()
   local client = _LocalPlayer()
   if _IsValid(client) then

      local current, vague = self:GetTargetType()
      if current then return current, vague end

      local stored = self.StoredTarget
      if stored.target and stored.t > (_CurTime() - 3) then
         return stored.target, stored.vague
      end
   end
   return "quick_nobody", true
end

function RADIO:StoreTarget()
   local current, vague = self:GetTargetType()
   if current then
      self.StoredTarget.target = current
      self.StoredTarget.vague = vague
      self.StoredTarget.t = _CurTime()
   end
end

-- Radio commands are a console cmd instead of directly sent from RADIO, because
-- this way players can bind keys to them
local function RadioCommand(ply, cmd, arg)
   if not _IsValid(ply) or #arg != 1 then
      _print("ttt_radio failed, too many arguments?")
      return
   end

   if RADIO.LastRadio.t > (_CurTime() - 0.5) then return end

   local msg_type = arg[1]
   local target, vague = RADIO:GetTarget()
   local msg_name = nil

   -- this will not be what is shown, but what is stored in case this message
   -- has to be used as last words (which will always be english for now)
   local text = nil

   for _, msg in _pairs(RADIO.Commands) do
      if msg.cmd == msg_type then
         local eng = LANG.GetTranslationFromLanguage(msg.text, "english")
         text = msg.format and string.Interp(eng, {player = RADIO.ToPrintable(target)}) or eng

         msg_name = msg.text
         break
      end
   end

   if not text then
      _print("ttt_radio failed, argument not valid radiocommand")
      return
   end

   if vague then
      text = util.Capitalize(text)
   end

   RADIO.LastRadio.t = _CurTime()
   RADIO.LastRadio.msg = text

   -- target is either a lang string or an entity
   target = _isstring(target) and target or _tostring(target:EntIndex())

   _RunConsoleCommand("_ttt_radio_send", msg_name, _tostring(target))
end

local function RadioComplete(cmd, arg)
   local c = {}
   for k, cmd in _pairs(RADIO.Commands) do
      local rcmd = "ttt_radio " .. cmd.cmd
      _table_insert(c, rcmd)
   end
   return c
end
_concommand_Add("ttt_radio", RadioCommand, RadioComplete)


local function RadioMsgRecv()
   local sender = _net_ReadEntity()
   local msg    = _net_ReadString()
   local param  = _net_ReadString()

   if not (_IsValid(sender) and sender:IsPlayer()) then return end

   GAMEMODE:PlayerSentRadioCommand(sender, msg, param)

   -- if param is a language string, translate it
   -- else it's a nickname
   local lang_param = LANG.GetNameParam(param)
   if lang_param then
      if lang_param == "quick_corpse_id" then
         -- special case where nested translation is needed
         param = GetPTranslation(lang_param, {player = _net_ReadString()})
      else
         param = GetTranslation(lang_param)
      end
   end

   local text = GetPTranslation(msg, {player = param})

   -- don't want to capitalize nicks, but everything else is fair game
   if lang_param then
      text = util.Capitalize(text)
   end

   if sender:IsDetective() then
      AddDetectiveText(sender, text)
   else
      chat.AddText(sender,
                   COLOR_WHITE,
                   ": " .. text)
   end
end
_net_Receive("TTT_RadioMsg", RadioMsgRecv)


local radio_gestures = {
   quick_yes     = ACT_GMOD_GESTURE_AGREE,
   quick_no      = ACT_GMOD_GESTURE_DISAGREE,
   quick_see     = ACT_GMOD_GESTURE_WAVE,
   quick_check   = ACT_SIGNAL_GROUP,
   quick_suspect = ACT_SIGNAL_HALT
};

function GM:PlayerSentRadioCommand(ply, name, target)
   local act = radio_gestures[name]
   if act then
      ply:AnimPerformGesture(act)
   end
end


--- voicechat stuff
VOICE = {}

local MutedState = nil

-- voice popups, copied from base gamemode and modified

g_VoicePanelList = nil

-- 255 at 100
-- 5 at 5000
local function VoiceNotifyThink(pnl)
   if not (_IsValid(pnl) and _LocalPlayer() and _IsValid(pnl.ply)) then return end
   if not (_GetGlobalBool("ttt_locational_voice", false) and (not pnl.ply:IsSpec()) and (pnl.ply != _LocalPlayer())) then return end
   if _LocalPlayer():IsActiveTraitor() && pnl.ply:IsActiveTraitor() then return end
   
   local d = _LocalPlayer():GetPos():Distance(pnl.ply:GetPos())

   pnl:SetAlpha(_math_max(-0.1 * d + 255, 15))
end

local PlayerVoicePanels = {}

local shade = _Color(0, 0, 0, 150)
local tvoice =  _Color(200, 20, 20, 255)
local dvoice = _Color(20, 20, 200, 255)
function GM:PlayerStartVoice( ply )
   local client = _LocalPlayer()
   if not _IsValid(g_VoicePanelList) or not _IsValid(client) then return end

   -- There'd be an extra one if voice_loopback is on, so remove it.
   GAMEMODE:PlayerEndVoice(ply, true)

   if not _IsValid(ply) then return end

   -- Tell server this is global
   if client == ply then
      if client:IsActiveTraitor() then
         if (not client:KeyDown(IN_SPEED)) and (not client:KeyDownLast(IN_SPEED)) then
            client.traitor_gvoice = true
            _RunConsoleCommand("tvog", "1")
         else
            client.traitor_gvoice = false
            _RunConsoleCommand("tvog", "0")
         end
      end

      VOICE.SetSpeaking(true)
   end

   local pnl = g_VoicePanelList:Add("VoiceNotify")
   pnl:Setup(ply)
   pnl:Dock(TOP)
   
   local oldThink = pnl.Think
   pnl.Think = function( self )
                  oldThink( self )
                  VoiceNotifyThink( self )
               end


   pnl.Paint = function(s, w, h)
                  if not _IsValid(s.ply) then return end
                  _draw_RoundedBox(4, 0, 0, w, h, s.Color)
                  _draw_RoundedBox(4, 1, 1, w-2, h-2, shade)
               end

   if client:IsActiveTraitor() then
      if ply == client then
         if not client.traitor_gvoice then
            pnl.Color = tvoice
         end
      elseif ply:IsActiveTraitor() then
         if not ply.traitor_gvoice then
            pnl.Color = tvoice
         end
      end
   end

   if ply:IsActiveDetective() then
      pnl.Color = dvoice
   end

   PlayerVoicePanels[ply] = pnl

   -- run ear gesture
   if not (ply:IsActiveTraitor() and (not ply.traitor_gvoice)) then
      ply:AnimPerformGesture(ACT_GMOD_IN_CHAT)
   end
end
local rvs1,rvs2 = _Color(0,200,0),_Color(200, 0, 0)
local function ReceiveVoiceState()
   local idx = _net_ReadUInt(7) + 1 -- we -1 serverside
   local state = _net_ReadBit() == 1

   -- prevent glitching due to chat starting/ending across round boundary
   if GAMEMODE.round_state != ROUND_ACTIVE then return end
   if (not _IsValid(_LocalPlayer())) or (not _LocalPlayer():IsActiveTraitor()) then return end

   local ply = _player_GetByID(idx)
   if _IsValid(ply) then
      ply.traitor_gvoice = state

      if _IsValid(PlayerVoicePanels[ply]) then
         PlayerVoicePanels[ply].Color = state and rvs1 or rvs2
      end
   end
end
_net_Receive("TTT_TraitorVoiceState", ReceiveVoiceState)

local function VoiceClean()
   for ply, pnl in _pairs( PlayerVoicePanels ) do
      if (not _IsValid(pnl)) or (not _IsValid(ply)) then
         GAMEMODE:PlayerEndVoice(ply)
      end
   end
end
_timer_Create( "VoiceClean", 10, 0, VoiceClean )


function GM:PlayerEndVoice(ply, no_reset)
   if _IsValid( PlayerVoicePanels[ply] ) then
      PlayerVoicePanels[ply]:Remove()
      PlayerVoicePanels[ply] = nil
   end

   if _IsValid(ply) and not no_reset then
      ply.traitor_gvoice = false
   end

   if ply == _LocalPlayer() then
      VOICE.SetSpeaking(false)
   end
end

local vguic = _Color(240, 240, 240, 250)
local function CreateVoiceVGUI()
    g_VoicePanelList = _vgui_Create( "DPanel" )

    g_VoicePanelList:ParentToHUD()
    g_VoicePanelList:SetPos(25, 25)
    g_VoicePanelList:SetSize(200, _ScrH() - 200)
    g_VoicePanelList:SetPaintBackground(false)

    MutedState = _vgui_Create("DLabel")
    MutedState:SetPos(_ScrW() - 200, _ScrH() - 50)
    MutedState:SetSize(200, 50)
    MutedState:SetFont("Trebuchet18")
    MutedState:SetText("")
    MutedState:SetTextColor(vguic)
    MutedState:SetVisible(false)
end
_hook_Add( "InitPostEntity", "CreateVoiceVGUI", CreateVoiceVGUI )

local MuteStates = {MUTE_NONE, MUTE_TERROR, MUTE_ALL, MUTE_SPEC}

local MuteText = {
   [MUTE_NONE]   = "",
   [MUTE_TERROR] = "mute_living",
   [MUTE_ALL]    = "mute_all",
   [MUTE_SPEC]   = "mute_specs"
};

local function SetMuteState(state)
   if MutedState then
      MutedState:SetText(_string_upper(GetTranslation(MuteText[state])))
      MutedState:SetVisible(state != MUTE_NONE)
   end
end

local mute_state = MUTE_NONE
function VOICE.CycleMuteState(force_state)
   mute_state = force_state or _next(MuteText, mute_state)

   if not mute_state then mute_state = MUTE_NONE end

   SetMuteState(mute_state)

   return mute_state
end

local battery_max = 100
local battery_min = 10
function VOICE.InitBattery()
   _LocalPlayer().voice_battery = battery_max
end

local function GetRechargeRate()
   local r = _GetGlobalFloat("ttt_voice_drain_recharge", 0.05)
   if _LocalPlayer().voice_battery < battery_min then
      r = r / 2
   end
   return r
end

local function GetDrainRate()
   if not _GetGlobalBool("ttt_voice_drain", false) then return 0 end

   if GetRoundState() != ROUND_ACTIVE then return 0 end
   local ply = _LocalPlayer()
   if (not _IsValid(ply)) or ply:IsSpec() then return 0 end

   if ply:IsAdmin() or ply:IsDetective() then
      return _GetGlobalFloat("ttt_voice_drain_admin", 0)
   else
      return _GetGlobalFloat("ttt_voice_drain_normal", 0)
   end
end

local function IsTraitorChatting(client)
   return client:IsActiveTraitor() and (not client.traitor_gvoice)
end

function VOICE.Tick()
   if not _GetGlobalBool("ttt_voice_drain", false) then return end

   local client = _LocalPlayer()
   if VOICE.IsSpeaking() and (not IsTraitorChatting(client)) then
      client.voice_battery = client.voice_battery - GetDrainRate()

      if not VOICE.CanSpeak() then
         client.voice_battery = 0
         _RunConsoleCommand("-voicerecord")
      end
   elseif client.voice_battery < battery_max then
      client.voice_battery = client.voice_battery + GetRechargeRate()
   end
end

-- Player:IsSpeaking() does not work for localplayer
function VOICE.IsSpeaking() return _LocalPlayer().speaking end
function VOICE.SetSpeaking(state) _LocalPlayer().speaking = state end

function VOICE.CanSpeak()
   if not _GetGlobalBool("ttt_voice_drain", false) then return true end

   return _LocalPlayer().voice_battery > battery_min or IsTraitorChatting(_LocalPlayer())
end

local speaker = _surface_GetTextureID("voice/icntlk_sv")
function VOICE.Draw(client)
   local b = client.voice_battery
   if b >= battery_max then return end

   local x = 25
   local y = 10
   local w = 200
   local h = 6

   if b < battery_min and _CurTime() % 0.2 < 0.1 then
      _surface_SetDrawColor(200, 0, 0, 155)
   else
      _surface_SetDrawColor(0, 200, 0, 255)
   end
   _surface_DrawOutlinedRect(x, y, w, h)

   _surface_SetTexture(speaker)
   _surface_DrawTexturedRect(5, 5, 16, 16)

   x = x + 1
   y = y + 1
   w = w - 2
   h = h - 2

   _surface_SetDrawColor(0, 200, 0, 150)
   _surface_DrawRect(x, y, w * _math_Clamp((client.voice_battery - 10) / 90, 0, 1), h)
end
