local _IsValid = IsValid
local _surface_SetDrawColor = (CLIENT and surface.SetDrawColor or nil)
local _surface_DrawText = (CLIENT and surface.DrawText or nil)
local _math_Clamp = math.Clamp
local _hook_Add = hook.Add
local _surface_SetFont = (CLIENT and surface.SetFont or nil)
local _LocalPlayer = (CLIENT and LocalPlayer or nil)
local _net_ReadFloat = net.ReadFloat
local _net_ReadUInt = net.ReadUInt
local _net_ReadVector = net.ReadVector
local _surface_GetTextureID = (CLIENT and surface.GetTextureID or nil)
local _Entity = Entity
local _surface_GetTextSize = (CLIENT and surface.GetTextSize or nil)
local _ScrW = (CLIENT and ScrW or nil)
local _RunConsoleCommand = RunConsoleCommand
local _surface_DrawTexturedRect = (CLIENT and surface.DrawTexturedRect or nil)
local _timer_Create = timer.Create
local _math_ceil = math.ceil
local _table_insert = table.insert
local _surface_SetTextPos = (CLIENT and surface.SetTextPos or nil)
local _net_Receive = net.Receive
local _CurTime = CurTime
local _vgui_Create = (CLIENT and vgui.Create or nil)
local _surface_SetTextColor = (CLIENT and surface.SetTextColor or nil)
local _math_max = math.max
local _Vector = Vector
local _table_Count = table.Count
local _pairs = pairs
local _ScrH = (CLIENT and ScrH or nil)
local _net_ReadInt = net.ReadInt
local _surface_SetTexture = (CLIENT and surface.SetTexture or nil)
local _net_ReadBit = net.ReadBit
-- Traitor radar rendering

local render = render
local surface = surface
local string = string
local player = player
local math = math

RADAR = {}
RADAR.targets = {}
RADAR.enable = false
RADAR.duration = 30
RADAR.endtime = 0
RADAR.bombs = {}
RADAR.bombs_count = 0
RADAR.repeating = true
RADAR.samples = {}
RADAR.samples_count = 0

RADAR.called_corpses = {}

function RADAR:EndScan()
   self.enable = false
   self.endtime = _CurTime()
end

function RADAR:Clear()
   self:EndScan()
   self.bombs = {}
   self.samples = {}

   self.bombs_count = 0
   self.samples_count = 0
end

function RADAR:Timeout()
   self:EndScan()

   if self.repeating and _LocalPlayer() and _LocalPlayer():IsActiveSpecial() and _LocalPlayer():HasEquipmentItem(EQUIP_RADAR) then
      _RunConsoleCommand("ttt_radar_scan")
   end
end

-- cache stuff we'll be drawing
function RADAR.CacheEnts()
   -- also do some corpse cleanup here
   for k, corpse in _pairs(RADAR.called_corpses) do
      if (corpse.called + 45) < _CurTime() then
         RADAR.called_corpses[k] = nil -- will make # inaccurate, no big deal
      end
   end

   if RADAR.bombs_count == 0 then return end

   -- Update bomb positions for those we know about
   for idx, b in _pairs(RADAR.bombs) do
      local ent = _Entity(idx)
      if _IsValid(ent) then
         b.pos = ent:GetPos()
      end
   end
end

function RADAR.Bought(is_item, id)
   if is_item and id == EQUIP_RADAR then
      _RunConsoleCommand("ttt_radar_scan")
   end
end
_hook_Add("TTTBoughtItem", "RadarBoughtItem", RADAR.Bought)

local function DrawTarget(tgt, size, offset, no_shrink)
   local scrpos = tgt.pos:ToScreen() -- sweet
   local sz = (IsOffScreen(scrpos) and (not no_shrink)) and size/2 or size

   scrpos.x = _math_Clamp(scrpos.x, sz, _ScrW() - sz)
   scrpos.y = _math_Clamp(scrpos.y, sz, _ScrH() - sz)
   
   if IsOffScreen(scrpos) then return end

   _surface_DrawTexturedRect(scrpos.x - sz, scrpos.y - sz, sz * 2, sz * 2)

   -- Drawing full size?
   if sz == size then
      local text = _math_ceil(_LocalPlayer():GetPos():Distance(tgt.pos))
      local w, h = _surface_GetTextSize(text)

      -- Show range to target
      _surface_SetTextPos(scrpos.x - w/2, scrpos.y + (offset * sz) - h/2)
      _surface_DrawText(text)

      if tgt.t then
         -- Show time
         text = util.SimpleTime(tgt.t - _CurTime(), "%02i:%02i")
         w, h = _surface_GetTextSize(text)

         _surface_SetTextPos(scrpos.x - w / 2, scrpos.y + sz / 2)
         _surface_DrawText(text)
      elseif tgt.nick then
         -- Show nickname
         text = tgt.nick
         w, h = _surface_GetTextSize(text)

         _surface_SetTextPos(scrpos.x - w / 2, scrpos.y + sz / 2)
         _surface_DrawText(text)
      end
   end
end

local indicator   = _surface_GetTextureID("effects/select_ring")
local c4warn      = _surface_GetTextureID("vgui/ttt/icon_c4warn")
local sample_scan = _surface_GetTextureID("vgui/ttt/sample_scan")
local det_beacon  = _surface_GetTextureID("vgui/ttt/det_beacon")

local GetPTranslation = LANG.GetParamTranslation
local FormatTime = util.SimpleTime

local near_cursor_dist = 180

function RADAR:Draw(client)
   if not client then return end

   _surface_SetFont("HudSelectionText")

   -- C4 warnings
   if self.bombs_count != 0 and client:IsActiveTraitor() then
      _surface_SetTexture(c4warn)
      _surface_SetTextColor(200, 55, 55, 220)
      _surface_SetDrawColor(255, 255, 255, 200)

      for k, bomb in _pairs(self.bombs) do
         DrawTarget(bomb, 24, 0, true)
      end
   end

   -- Corpse calls
   if client:IsActiveDetective() and #self.called_corpses then
      _surface_SetTexture(det_beacon)
      _surface_SetTextColor(255, 255, 255, 240)
      _surface_SetDrawColor(255, 255, 255, 230)

      for k, corpse in _pairs(self.called_corpses) do
         DrawTarget(corpse, 16, 0.5)
      end
   end

   -- Samples
   if self.samples_count != 0 then
      _surface_SetTexture(sample_scan)
      _surface_SetTextColor(200, 50, 50, 255)
      _surface_SetDrawColor(255, 255, 255, 240)

      for k, sample in _pairs(self.samples) do
         DrawTarget(sample, 16, 0.5, true)
      end
   end

   -- Player radar
   if (not self.enable) or (not client:IsActiveSpecial()) then return end

   _surface_SetTexture(indicator)

   local remaining = _math_max(0, RADAR.endtime - _CurTime())
   local alpha_base = 50 + 180 * (remaining / RADAR.duration)

   local mpos = _Vector(_ScrW() / 2, _ScrH() / 2, 0)

   local role, alpha, scrpos, md
   for k, tgt in _pairs(RADAR.targets) do
      alpha = alpha_base

      scrpos = tgt.pos:ToScreen()
      if not scrpos.visible then
         continue
      end
      md = mpos:Distance(_Vector(scrpos.x, scrpos.y, 0))
      if md < near_cursor_dist then
         alpha = _math_Clamp(alpha * (md / near_cursor_dist), 40, 230)
      end

      role = tgt.role or ROLE_INNOCENT
      if role == ROLE_TRAITOR then
         _surface_SetDrawColor(255, 0, 0, alpha)
         _surface_SetTextColor(255, 0, 0, alpha)

      elseif role == ROLE_DETECTIVE then
         _surface_SetDrawColor(0, 0, 255, alpha)
         _surface_SetTextColor(0, 0, 255, alpha)

      elseif role == 3 then -- decoys
         _surface_SetDrawColor(150, 150, 150, alpha)
         _surface_SetTextColor(150, 150, 150, alpha)

      else
         _surface_SetDrawColor(0, 255, 0, alpha)
         _surface_SetTextColor(0, 255, 0, alpha)
      end

      DrawTarget(tgt, 24, 0)
   end

   -- Time until next scan
   _surface_SetFont("TabLarge")
   _surface_SetTextColor(255, 0, 0, 230)

   local text = GetPTranslation("radar_hud", {time = FormatTime(remaining, "%02i:%02i")})
   local w, h = _surface_GetTextSize(text)

   _surface_SetTextPos(36, _ScrH() - 140 - h)
   _surface_DrawText(text)
end

local function ReceiveC4Warn()
   local idx = _net_ReadUInt(16)
   local armed = _net_ReadBit() == 1

   if armed then
      local pos = _net_ReadVector()
      local etime = _net_ReadFloat()

      RADAR.bombs[idx] = {pos=pos, t=etime}
   else
      RADAR.bombs[idx] = nil
   end

   RADAR.bombs_count = _table_Count(RADAR.bombs)
end
_net_Receive("TTT_C4Warn", ReceiveC4Warn)

local function ReceiveCorpseCall()
   local pos = _net_ReadVector()
   _table_insert(RADAR.called_corpses, {pos = pos, called = _CurTime()})
end
_net_Receive("TTT_CorpseCall", ReceiveCorpseCall)

local function ReceiveRadarScan()
   local num_targets = _net_ReadUInt(8)

   RADAR.targets = {}
   for i=1, num_targets do
      local r = _net_ReadUInt(2)

      local pos = _Vector()
      pos.x = _net_ReadInt(32)
      pos.y = _net_ReadInt(32)
      pos.z = _net_ReadInt(32)

      _table_insert(RADAR.targets, {role=r, pos=pos})
   end

   RADAR.enable = true
   RADAR.endtime = _CurTime() + RADAR.duration

   _timer_Create("radartimeout", RADAR.duration + 1, 1,
                function() RADAR:Timeout() end)
end
_net_Receive("TTT_Radar", ReceiveRadarScan)

local GetTranslation = LANG.GetTranslation
function RADAR.CreateMenu(parent, frame)
   local w, h = parent:GetSize()

   local dform = _vgui_Create("DForm", parent)
   dform:SetName(GetTranslation("radar_menutitle"))
   dform:StretchToParent(0,0,0,0)
   dform:SetAutoSize(false)

   local owned = _LocalPlayer():HasEquipmentItem(EQUIP_RADAR)

   if not owned then
      dform:Help(GetTranslation("radar_not_owned"))
      return dform
   end

   local bw, bh = 100, 25
   local dscan = _vgui_Create("DButton", dform)
   dscan:SetSize(bw, bh)
   dscan:SetText(GetTranslation("radar_scan"))
   dscan.DoClick = function(s)
                      s:SetDisabled(true)
                      _RunConsoleCommand("ttt_radar_scan")
                      frame:Close()
                   end
   dform:AddItem(dscan)

   local dlabel = _vgui_Create("DLabel", dform)
   dlabel:SetText(GetPTranslation("radar_help", {num = RADAR.duration}))
   dlabel:SetWrap(true)
   dlabel:SetTall(50)
   dform:AddItem(dlabel)

   local dcheck = _vgui_Create("DCheckBoxLabel", dform)
   dcheck:SetText(GetTranslation("radar_auto"))
   dcheck:SetIndent(5)
   dcheck:SetValue(RADAR.repeating)
   dcheck.OnChange = function(s, val)
                        RADAR.repeating = val
                     end
   dform:AddItem(dcheck)

   dform.Think = function(s)
                    if RADAR.enable or not owned then
                       dscan:SetDisabled(true)
                    else
                       dscan:SetDisabled(false)
                    end
                 end

   dform:SetVisible(true)

   return dform
end
