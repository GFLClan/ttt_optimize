local _IsValid = IsValid
local _surface_SetDrawColor = (CLIENT and surface.SetDrawColor or nil)
local _RunConsoleCommand = RunConsoleCommand
local _Color = Color
local _CreateConVar = CreateConVar
local _Format = Format
local _LocalPlayer = (CLIENT and LocalPlayer or nil)
local _surface_SetTexture = (CLIENT and surface.SetTexture or nil)
local _ScrW = (CLIENT and ScrW or nil)
local _draw_TextShadow = (CLIENT and draw.TextShadow or nil)
local _surface_GetTextureID = (CLIENT and surface.GetTextureID or nil)
local _table_insert = table.insert
local _table_Empty = table.Empty
local _surface_DrawRect = (CLIENT and surface.DrawRect or nil)
local _draw_Text = (CLIENT and draw.Text or nil)
local _concommand_Add = concommand.Add
local _table_sort = table.sort
local _CurTime = CurTime
local _math_Round = math.Round
local _tonumber = tonumber
local _tostring = tostring
local _pairs = pairs
local _ScrH = (CLIENT and ScrH or nil)
local _surface_DrawTexturedRectRotated = (CLIENT and surface.DrawTexturedRectRotated or nil)

-- we need our own weapon switcher because the hl2 one skips empty weapons

local math = math
local draw = draw
local surface = surface
local table = table

WSWITCH = {}

WSWITCH.Show = false
WSWITCH.Selected = -1
WSWITCH.NextSwitch = -1
WSWITCH.WeaponCache = {}

WSWITCH.cv = {}
WSWITCH.cv.stay = _CreateConVar("ttt_weaponswitcher_stay", "0", FCVAR_ARCHIVE)
WSWITCH.cv.fast = _CreateConVar("ttt_weaponswitcher_fast", "0", FCVAR_ARCHIVE)
WSWITCH.cv.display = _CreateConVar("ttt_weaponswitcher_displayfast", "0", FCVAR_ARCHIVE)

local delay = 0.03
local showtime = 3

local margin = 10
local width = 300
local height = 20

local barcorner = _surface_GetTextureID( "gui/corner8" )

local col_active = {
   tip = {
      [ROLE_INNOCENT]  = _Color(55, 170, 50, 255),
      [ROLE_TRAITOR]   = _Color(180, 50, 40, 255),
      [ROLE_DETECTIVE] = _Color(50, 60, 180, 255)
   },

   bg = _Color(20, 20, 20, 250),

   text_empty = _Color(200, 20, 20, 255),
   text = _Color(255, 255, 255, 255),

   shadow = 255
};

local col_dark = {
   tip = {
      [ROLE_INNOCENT]  = _Color(60, 160, 50, 155),
      [ROLE_TRAITOR]   = _Color(160, 50, 60, 155),
      [ROLE_DETECTIVE] = _Color(50, 60, 160, 155),
   },

   bg = _Color(20, 20, 20, 200),

   text_empty = _Color(200, 20, 20, 100),
   text = _Color(255, 255, 255, 100),

   shadow = 100
};

-- Draw a bar in the style of the the weapon pickup ones
local round = _math_Round
function WSWITCH:DrawBarBg(x, y, w, h, col)
   local rx = round(x - 4)
   local ry = round(y - (h / 2)-4)
   local rw = round(w + 9)
   local rh = round(h + 8)

   local b = 8 --bordersize
   local bh = b / 2

   local role = _LocalPlayer():GetRole() or ROLE_INNOCENT

   local c = col.tip[role]

   -- Draw the colour tip
   _surface_SetTexture(barcorner)

   _surface_SetDrawColor(c.r, c.g, c.b, c.a)
   _surface_DrawTexturedRectRotated( rx + bh , ry + bh, b, b, 0 ) 
   _surface_DrawTexturedRectRotated( rx + bh , ry + rh -bh, b, b, 90 ) 
   _surface_DrawRect( rx, ry+b, b, rh-b*2 )
   _surface_DrawRect( rx+b, ry, h - 4, rh )
   
   -- Draw the remainder
   -- Could just draw a full roundedrect bg and overdraw it with the tip, but
   -- I don't have to do the hard work here anymore anyway
   c = col.bg
   _surface_SetDrawColor(c.r, c.g, c.b, c.a)

   _surface_DrawRect( rx+b+h-4, ry,  rw - (h - 4) - b*2,  rh )
   _surface_DrawTexturedRectRotated( rx + rw - bh , ry + rh - bh, b, b, 180 ) 
   _surface_DrawTexturedRectRotated( rx + rw - bh , ry + bh, b, b, 270 ) 
   _surface_DrawRect( rx+rw-b,  ry+b,  b,  rh-b*2 )

end

local TryTranslation = LANG.TryTranslation
function WSWITCH:DrawWeapon(x, y, c, wep)
   if not _IsValid(wep) then return false end

   local name = TryTranslation(wep:GetPrintName() or wep.PrintName or "...")
   local cl1, am1 = wep:Clip1(), wep:Ammo1()
   local ammo = false

   -- Clip1 will be -1 if a melee weapon
   -- Ammo1 will be false if weapon has no owner (was just dropped)
   if cl1 != -1 and am1 != false then
      ammo = _Format("%i + %02i", cl1, am1)
   end

   -- Slot
   local spec = {text=wep.Slot+1, font="Trebuchet22", pos={x+4, y}, yalign=TEXT_ALIGN_CENTER, color=c.text}
   _draw_TextShadow(spec, 1, c.shadow)

   -- Name
   spec.text  = name
   spec.font  = "TimeLeft"
   spec.pos[1] = x + 10 + height
   _draw_Text(spec)

   if ammo then
      local col = c.text

      if wep:Clip1() == 0 and wep:Ammo1() == 0 then
         col = c.text_empty
      end

      -- Ammo
      spec.text   = ammo
      spec.pos[1] = _ScrW() - margin*3
      spec.xalign = TEXT_ALIGN_RIGHT
      spec.color  = col
      _draw_Text(spec)
   end

   return true
end

function WSWITCH:Draw(client)
   if not self.Show then return end

   local weps = self.WeaponCache

   local x = _ScrW() - width - margin*2
   local y = _ScrH() - (#weps * (height + margin))

   local col = col_dark
   for k, wep in _pairs(weps) do
      if self.Selected == k then
         col = col_active
      else
         col = col_dark
      end

      self:DrawBarBg(x, y, width, height, col)
      if not self:DrawWeapon(x, y, col, wep) then
         
         self:UpdateWeaponCache()
         return
      end

      y = y + height + margin
   end
end

local function SlotSort(a, b)
   return a and b and a.Slot and b.Slot and a.Slot < b.Slot
end

local function CopyVals(src, dest)
   _table_Empty(dest)
   for k, v in _pairs(src) do
      if _IsValid(v) then
         _table_insert(dest, v)
      end
   end   
end

function WSWITCH:UpdateWeaponCache()
   -- GetWeapons does not always return a proper numeric table it seems
   --   self.WeaponCache = LocalPlayer():GetWeapons()
   -- So copy over the weapon refs
   self.WeaponCache = {}
   CopyVals(_LocalPlayer():GetWeapons(), self.WeaponCache)

   _table_sort(self.WeaponCache, SlotSort)
end

function WSWITCH:SetSelected(idx)
   self.Selected = idx

   self:UpdateWeaponCache()
end

function WSWITCH:SelectNext()
   if self.NextSwitch > _CurTime() then return end
   self:Enable()

   local s = self.Selected + 1
   if s > #self.WeaponCache then
      s = 1
   end

   self:DoSelect(s)

   self.NextSwitch = _CurTime() + delay
end

function WSWITCH:SelectPrev()
   if self.NextSwitch > _CurTime() then return end
   self:Enable()

   local s = self.Selected - 1
   if s < 1 then
      s = #self.WeaponCache
   end

   self:DoSelect(s)

   self.NextSwitch = _CurTime() + delay
end

-- Select by index
function WSWITCH:DoSelect(idx)
   self:SetSelected(idx)

   if self.cv.fast:GetBool() then
      -- immediately confirm if fastswitch is on
      self:ConfirmSelection(self.cv.display:GetBool())
   end   
end

-- Numeric key access to direct slots
function WSWITCH:SelectSlot(slot)
   if not slot then return end

   self:Enable()

   self:UpdateWeaponCache()

   slot = slot - 1

   -- find which idx in the weapon table has the slot we want
   local toselect = self.Selected
   for k, w in _pairs(self.WeaponCache) do
      if w.Slot == slot then
         toselect = k
         break
      end
   end

   self:DoSelect(toselect)

   self.NextSwitch = _CurTime() + delay
end

-- Show the weapon switcher
function WSWITCH:Enable()
   if self.Show == false then
      self.Show = true

      local wep_active = _LocalPlayer():GetActiveWeapon()

      self:UpdateWeaponCache()

      -- make our active weapon the initial selection
      local toselect = 1
      for k, w in _pairs(self.WeaponCache) do
         if w == wep_active then
            toselect = k
            break
         end
      end
      self:SetSelected(toselect)
   end

   -- cache for speed, checked every Think
   self.Stay = self.cv.stay:GetBool()
end

-- Hide switcher
function WSWITCH:Disable()
   self.Show = false
end

-- Switch to the currently selected weapon
function WSWITCH:ConfirmSelection(noHide)
   if not noHide then self:Disable() end

   for k, w in _pairs(self.WeaponCache) do
      if k == self.Selected and _IsValid(w) then
         input.SelectWeapon(w)
         return
      end
   end
end

-- Allow for suppression of the attack command
function WSWITCH:PreventAttack()
   return self.Show and !self.cv.fast:GetBool()
end

function WSWITCH:Think()
   if (not self.Show) or self.Stay then return end

   -- hide after period of inaction
   if self.NextSwitch < (_CurTime() - showtime) then
      self:Disable()
   end
end

-- Instantly select a slot and switch to it, without spending time in menu
function WSWITCH:SelectAndConfirm(slot)
   if not slot then return end
   WSWITCH:SelectSlot(slot)
   WSWITCH:ConfirmSelection()
end

local function QuickSlot(ply, cmd, args)
   if (not _IsValid(ply)) or (not args) or #args != 1 then return end

   local slot = _tonumber(args[1])
   if not slot then return end

   local wep = ply:GetActiveWeapon()
   if _IsValid(wep) then
      if wep.Slot == (slot - 1) then
         _RunConsoleCommand("lastinv")
      else
         WSWITCH:SelectAndConfirm(slot)
      end
   end   
end
_concommand_Add("ttt_quickslot", QuickSlot)


local function SwitchToEquipment(ply, cmd, args)
   _RunConsoleCommand("ttt_quickslot", _tostring(7))
end
_concommand_Add("ttt_equipswitch", SwitchToEquipment)
