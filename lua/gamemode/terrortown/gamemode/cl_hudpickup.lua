local _IsValid = IsValid
local _surface_SetDrawColor = (CLIENT and surface.SetDrawColor or nil)
local _surface_SetFont = (CLIENT and surface.SetFont or nil)
local _Color = Color
local _math_Clamp = math.Clamp
local _surface_SetTexture = (CLIENT and surface.SetTexture or nil)
local _LocalPlayer = (CLIENT and LocalPlayer or nil)
local _surface_DrawTexturedRectRotated = (CLIENT and surface.DrawTexturedRectRotated or nil)
local _surface_DrawRect = (CLIENT and surface.DrawRect or nil)
local _draw_SimpleText = (CLIENT and draw.SimpleText or nil)
local _surface_GetTextureID = (CLIENT and surface.GetTextureID or nil)
local _table_insert = table.insert
local _surface_GetTextSize = (CLIENT and surface.GetTextSize or nil)
local _ScrW = (CLIENT and ScrW or nil)
local _string_lower = string.lower
local _math_Max = math.Max
local _CurTime = CurTime
local _math_Round = math.Round
local _tonumber = tonumber
local _tostring = tostring
local _pairs = pairs
local _ScrH = (CLIENT and ScrH or nil)
local _string_upper = string.upper
local TryTranslation = LANG.TryTranslation

GM.PickupHistory = {}
GM.PickupHistoryLast = 0
GM.PickupHistoryTop = _ScrH() / 2
GM.PickupHistoryWide = 300
GM.PickupHistoryCorner  = _surface_GetTextureID( "gui/corner8" )

local pickupclr = {
   [ROLE_INNOCENT]  = _Color(55, 170, 50, 255),
   [ROLE_TRAITOR]   = _Color(180, 50, 40, 255),
   [ROLE_DETECTIVE] = _Color(50, 60, 180, 255)
}

function GM:HUDWeaponPickedUp( wep )
   if not (_IsValid(wep) and _IsValid(_LocalPlayer())) or (not _LocalPlayer():Alive()) then return end

   local name = TryTranslation(wep.GetPrintName and wep:GetPrintName() or wep:GetClass() or "Unknown Weapon Name")

   local pickup = {}
   pickup.time      = _CurTime()
   pickup.name      = _string_upper(name)
   pickup.holdtime  = 5
   pickup.font      = "DefaultBold"
   pickup.fadein    = 0.04
   pickup.fadeout   = 0.3

   local role = _LocalPlayer().GetRole and _LocalPlayer():GetRole() or ROLE_INNOCENT
   pickup.color = pickupclr[role]

   pickup.upper = true

   _surface_SetFont( pickup.font )
   local w, h = _surface_GetTextSize( pickup.name )
   pickup.height    = h
   pickup.width     = w

   if (self.PickupHistoryLast >= pickup.time) then
      pickup.time = self.PickupHistoryLast + 0.05
   end

   _table_insert( self.PickupHistory, pickup )
   self.PickupHistoryLast = pickup.time

end

function GM:HUDItemPickedUp( itemname )

   if not (_IsValid(_LocalPlayer()) and _LocalPlayer():Alive()) then return end

   local pickup = {}
   pickup.time      = _CurTime()
   -- as far as I'm aware TTT does not use any "items", so better leave this to
   -- source's localisation
   pickup.name      = "#"..itemname
   pickup.holdtime  = 5
   pickup.font      = "DefaultBold"
   pickup.fadein    = 0.04
   pickup.fadeout   = 0.3
   pickup.color     = _Color( 255, 255, 255, 255 )

   pickup.upper = false

   _surface_SetFont( pickup.font )
   local w, h = _surface_GetTextSize( pickup.name )
   pickup.height = h
   pickup.width  = w

   if self.PickupHistoryLast >= pickup.time then
      pickup.time = self.PickupHistoryLast + 0.05
   end

   _table_insert( self.PickupHistory, pickup )
   self.PickupHistoryLast = pickup.time

end

function GM:HUDAmmoPickedUp( itemname, amount )
   if not (_IsValid(_LocalPlayer()) and _LocalPlayer():Alive()) then return end

   local itemname_trans = TryTranslation(_string_lower("ammo_" .. itemname))

   if self.PickupHistory then

      local localized_name = _string_upper(itemname_trans)
      for k, v in _pairs( self.PickupHistory ) do
         if v.name == localized_name then

            v.amount = _tostring( _tonumber(v.amount) + amount )
            v.time = _CurTime() - v.fadein
            return
         end
      end
   end

   local pickup = {}
   pickup.time      = _CurTime()
   pickup.name      = _string_upper(itemname_trans)
   pickup.holdtime  = 5
   pickup.font      = "DefaultBold"
   pickup.fadein    = 0.04
   pickup.fadeout   = 0.3
   pickup.color     = _Color(205, 155, 0, 255)
   pickup.amount    = _tostring(amount)

   _surface_SetFont( pickup.font )
   local w, h = _surface_GetTextSize( pickup.name )
   pickup.height = h
   pickup.width  = w

   local w, h = _surface_GetTextSize( pickup.amount )
   pickup.xwidth = w
   pickup.width = pickup.width + w + 16

   if (self.PickupHistoryLast >= pickup.time) then
      pickup.time = self.PickupHistoryLast + 0.05
   end

   _table_insert( self.PickupHistory, pickup )
   self.PickupHistoryLast = pickup.time

end


function GM:HUDDrawPickupHistory()
   if (not self.PickupHistory) then return end

   local x, y = _ScrW() - self.PickupHistoryWide - 20, self.PickupHistoryTop
   local tall = 0
   local wide = 0

   for k, v in _pairs( self.PickupHistory ) do

      if v.time < _CurTime() then

         if (v.y == nil) then v.y = y end

         v.y = (v.y*5 + y) / 6

         local delta = (v.time + v.holdtime) - _CurTime()
         delta = delta / v.holdtime

         local alpha = 255
         local colordelta = _math_Clamp( delta, 0.6, 0.7 )

         if delta > (1 - v.fadein) then
            alpha = _math_Clamp( (1.0 - delta) * (255/v.fadein), 0, 255 )
         elseif delta < v.fadeout then
            alpha = _math_Clamp( delta * (255/v.fadeout), 0, 255 )
         end

         v.x = x + self.PickupHistoryWide - (self.PickupHistoryWide * (alpha/255))


         local rx, ry, rw, rh = _math_Round(v.x-4), _math_Round(v.y-(v.height/2)-4), _math_Round(self.PickupHistoryWide+9), _math_Round(v.height+8)
         local bordersize = 8

         _surface_SetTexture( self.PickupHistoryCorner )

         _surface_SetDrawColor( v.color.r, v.color.g, v.color.b, alpha )
         _surface_DrawTexturedRectRotated( rx + bordersize/2 , ry + bordersize/2, bordersize, bordersize, 0 )
         _surface_DrawTexturedRectRotated( rx + bordersize/2 , ry + rh -bordersize/2, bordersize, bordersize, 90 )
         _surface_DrawRect( rx, ry+bordersize,  bordersize, rh-bordersize*2 )
         _surface_DrawRect( rx+bordersize, ry, v.height - 4, rh )

         --surface.SetDrawColor( 230*colordelta, 230*colordelta, 230*colordelta, alpha )
         _surface_SetDrawColor( 20*colordelta, 20*colordelta, 20*colordelta, _math_Clamp(alpha, 0, 200) )

         _surface_DrawRect( rx+bordersize+v.height-4, ry, rw - (v.height - 4) - bordersize*2, rh )
         _surface_DrawTexturedRectRotated( rx + rw - bordersize/2 , ry + rh - bordersize/2, bordersize, bordersize, 180 )
         _surface_DrawTexturedRectRotated( rx + rw - bordersize/2 , ry + bordersize/2, bordersize, bordersize, 270 )
         _surface_DrawRect( rx+rw-bordersize, ry+bordersize, bordersize, rh-bordersize*2 )

         _draw_SimpleText( v.name, v.font, v.x+2+v.height+8, v.y - (v.height/2)+2, _Color( 0, 0, 0, alpha*0.75 ) )

         _draw_SimpleText( v.name, v.font, v.x+v.height+8, v.y - (v.height/2), _Color( 255, 255, 255, alpha ) )

         if v.amount then
            _draw_SimpleText( v.amount, v.font, v.x+self.PickupHistoryWide+2, v.y - (v.height/2)+2, _Color( 0, 0, 0, alpha*0.75 ), TEXT_ALIGN_RIGHT )
            _draw_SimpleText( v.amount, v.font, v.x+self.PickupHistoryWide, v.y - (v.height/2), _Color( 255, 255, 255, alpha ), TEXT_ALIGN_RIGHT )
         end

         y = y + (v.height + 16)
         tall = tall + v.height + 18
         wide = _math_Max( wide, v.width + v.height + 24 )

         if alpha == 0 then self.PickupHistory[k] = nil end
      end
   end

   self.PickupHistoryTop = (self.PickupHistoryTop * 5 + ( _ScrH() * 0.75 - tall ) / 2 ) / 6
   self.PickupHistoryWide = (self.PickupHistoryWide * 5 + wide) / 6
end
