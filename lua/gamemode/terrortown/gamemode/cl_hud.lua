local _IsValid = IsValid
local _surface_SetDrawColor = (CLIENT and surface.SetDrawColor or nil)
local _GetGlobalFloat = GetGlobalFloat
local _Color = Color
local _math_Clamp = math.Clamp
local _ScrW = (CLIENT and ScrW or nil)
local _LocalPlayer = (CLIENT and LocalPlayer or nil)
local _draw_SimpleText = (CLIENT and draw.SimpleText or nil)
local _string_format = string.format
local _surface_DrawTexturedRectRotated = (CLIENT and surface.DrawTexturedRectRotated or nil)
local _surface_GetTextureID = (CLIENT and surface.GetTextureID or nil)
local _draw_RoundedBox = (CLIENT and draw.RoundedBox or nil)
local _surface_DrawRect = (CLIENT and surface.DrawRect or nil)
local _math_ceil = math.ceil
local _surface_CreateFont = (CLIENT and surface.CreateFont or nil)
local _CurTime = CurTime
local _CreateClientConVar = CreateClientConVar
local _hook_Call = hook.Call
local _math_max = math.max
local _tostring = tostring
local _ScrH = (CLIENT and ScrH or nil)
local _surface_SetTexture = (CLIENT and surface.SetTexture or nil)
-- HUD HUD HUD

local table = table
local surface = surface
local draw = draw
local math = math
local string = string

local GetTranslation = LANG.GetTranslation
local GetPTranslation = LANG.GetParamTranslation
local GetLang = LANG.GetUnsafeLanguageTable
local interp = string.Interp

-- Fonts
_surface_CreateFont("TraitorState", {font = "Trebuchet24",
                                    size = 28,
                                    weight = 1000})
_surface_CreateFont("TimeLeft",     {font = "Trebuchet24",
                                    size = 24,
                                    weight = 800})
_surface_CreateFont("HealthAmmo",   {font = "Trebuchet24",
                                    size = 24,
                                    weight = 750})
-- Color presets
local bg_colors = {
   background_main = _Color(0, 0, 10, 200),

   noround = _Color(100,100,100,200),
   traitor = _Color(200, 25, 25, 200),
   innocent = _Color(25, 200, 25, 200),
   detective = _Color(25, 25, 200, 200)
};

local health_colors = {
   border = COLOR_WHITE,
   background = _Color(100, 25, 25, 222),
   fill = _Color(200, 50, 50, 250)
};

local ammo_colors = {
   border = COLOR_WHITE,
   background = _Color(20, 20, 5, 222),
   fill = _Color(205, 155, 0, 255)
};


-- Modified RoundedBox
local Tex_Corner8 = _surface_GetTextureID( "gui/corner8" )
local function RoundedMeter( bs, x, y, w, h, color)
   _surface_SetDrawColor(clr(color))

   _surface_DrawRect( x+bs, y, w-bs*2, h )
   _surface_DrawRect( x, y+bs, bs, h-bs*2 )

   _surface_SetTexture( Tex_Corner8 )
   _surface_DrawTexturedRectRotated( x + bs/2 , y + bs/2, bs, bs, 0 )
   _surface_DrawTexturedRectRotated( x + bs/2 , y + h -bs/2, bs, bs, 90 )

   if w > 14 then
      _surface_DrawRect( x+w-bs, y+bs, bs, h-bs*2 )
      _surface_DrawTexturedRectRotated( x + w - bs/2 , y + bs/2, bs, bs, 270 )
      _surface_DrawTexturedRectRotated( x + w - bs/2 , y + h - bs/2, bs, bs, 180 )
   else
      _surface_DrawRect( x + _math_max(w-bs, bs), y, bs/2, h )
   end

end

---- The bar painting is loosely based on:
---- http://wiki.garrysmod.com/?title=Creating_a_HUD

-- Paints a graphical meter bar
local function PaintBar(x, y, w, h, colors, value)
   -- Background
   -- slightly enlarged to make a subtle border
   _draw_RoundedBox(8, x-1, y-1, w+2, h+2, colors.background)

   -- Fill
   local width = w * _math_Clamp(value, 0, 1)

   if width > 0 then
      RoundedMeter(8, x, y, width, h, colors.fill)
   end
end

local roundstate_string = {
   [ROUND_WAIT]   = "round_wait",
   [ROUND_PREP]   = "round_prep",
   [ROUND_ACTIVE] = "round_active",
   [ROUND_POST]   = "round_post"
};

-- Returns player's ammo information
local function GetAmmo(ply)
   local weap = ply:GetActiveWeapon()
   if not weap or not ply:Alive() then return -1 end

   local ammo_inv = weap:Ammo1() or 0
   local ammo_clip = weap:Clip1() or 0
   local ammo_max = weap.Primary.ClipSize or 0

   return ammo_clip, ammo_max, ammo_inv
end

local function DrawBg(x, y, width, height, client)
   -- Traitor area sizes
   local th = 30
   local tw = 170

   -- Adjust for these
   y = y - th
   height = height + th

   -- main bg area, invariant
   -- encompasses entire area
   _draw_RoundedBox(8, x, y, width, height, bg_colors.background_main)

   -- main border, traitor based
   local col = bg_colors.innocent
   if GAMEMODE.round_state != ROUND_ACTIVE then
      col = bg_colors.noround
   elseif client:GetTraitor() then
      col = bg_colors.traitor
   elseif client:GetDetective() then
      col = bg_colors.detective
   end

   _draw_RoundedBox(8, x, y, tw, th, col)
end

local sf = surface
local dr = draw

local function ShadowedText(text, font, x, y, color, xalign, yalign)

   dr.SimpleText(text, font, x+2, y+2, COLOR_BLACK, xalign, yalign)

   dr.SimpleText(text, font, x, y, color, xalign, yalign)
end

local margin = 10

-- Paint punch-o-meter
local function PunchPaint(client)
   local L = GetLang()
   local punch = client:GetNWFloat("specpunches", 0)

   local width, height = 200, 25
   local x = _ScrW() / 2 - width/2
   local y = margin/2 + height

   PaintBar(x, y, width, height, ammo_colors, punch)

   local color = bg_colors.background_main

   dr.SimpleText(L.punch_title, "HealthAmmo", _ScrW() / 2, y, color, TEXT_ALIGN_CENTER)

   dr.SimpleText(L.punch_help, "TabLarge", _ScrW() / 2, margin, COLOR_WHITE, TEXT_ALIGN_CENTER)

   local bonus = client:GetNWInt("bonuspunches", 0)
   if bonus != 0 then
      local text
      if bonus < 0 then
         text = interp(L.punch_bonus, {num = bonus})
      else
         text = interp(L.punch_malus, {num = bonus})
      end

      dr.SimpleText(text, "TabLarge", _ScrW() / 2, y * 2, COLOR_WHITE, TEXT_ALIGN_CENTER)
   end
end

local key_params = { usekey = Key("+use", "USE") }

local function SpecHUDPaint(client)
   local L = GetLang() -- for fast direct table lookups

   -- Draw round state
   local x       = margin
   local height  = 32
   local width   = 250
   local round_y = _ScrH() - height - margin

   -- move up a little on low resolutions to allow space for spectator hints
   if _ScrW() < 1000 then round_y = round_y - 15 end

   local time_x = x + 170
   local time_y = round_y + 4

   _draw_RoundedBox(8, x, round_y, width, height, bg_colors.background_main)
   _draw_RoundedBox(8, x, round_y, time_x - x, height, bg_colors.noround)

   local text = L[ roundstate_string[GAMEMODE.round_state] ]
   ShadowedText(text, "TraitorState", x + margin, round_y, COLOR_WHITE)

   -- Draw round/prep/post time remaining
   local text = util.SimpleTime(_math_max(0, _GetGlobalFloat("ttt_round_end", 0) - _CurTime()), "%02i:%02i")
   ShadowedText(text, "TimeLeft", time_x + margin, time_y, COLOR_WHITE)

   local tgt = client:GetObserverTarget()
   if _IsValid(tgt) and tgt:IsPlayer() then
      ShadowedText(tgt:Nick(), "TimeLeft", _ScrW() / 2, margin, COLOR_WHITE, TEXT_ALIGN_CENTER)

   elseif _IsValid(tgt) and tgt:GetNWEntity("spec_owner", nil) == client then
      PunchPaint(client)
   else
      ShadowedText(interp(L.spec_help, key_params), "TabLarge", _ScrW() / 2, margin, COLOR_WHITE, TEXT_ALIGN_CENTER)
   end
end

local ttt_health_label = _CreateClientConVar("ttt_health_label", "0", true)

local function InfoPaint(client)
   local L = GetLang()

   local width = 250
   local height = 90

   local x = margin
   local y = _ScrH() - margin - height

   DrawBg(x, y, width, height, client)

   local bar_height = 25
   local bar_width = width - (margin*2)

   -- Draw health
   local health = _math_max(0, client:Health())
   local health_y = y + margin

   PaintBar(x + margin, health_y, bar_width, bar_height, health_colors, health/client:GetMaxHealth())

   ShadowedText(_tostring(health), "HealthAmmo", bar_width, health_y, COLOR_WHITE, TEXT_ALIGN_RIGHT, TEXT_ALIGN_RIGHT)

   if ttt_health_label:GetBool() then
      local health_status = util.HealthToString(health, client:GetMaxHealth())
      _draw_SimpleText(L[health_status], "TabLarge", x + margin*2, health_y + bar_height/2, COLOR_WHITE, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
   end

   -- Draw ammo
   if client:GetActiveWeapon().Primary then
      local ammo_clip, ammo_max, ammo_inv = GetAmmo(client)
      if ammo_clip != -1 then
         local ammo_y = health_y + bar_height + margin
         PaintBar(x+margin, ammo_y, bar_width, bar_height, ammo_colors, ammo_clip/ammo_max)
         local text = _string_format("%i + %02i", ammo_clip, ammo_inv)

         ShadowedText(text, "HealthAmmo", bar_width, ammo_y, COLOR_WHITE, TEXT_ALIGN_RIGHT, TEXT_ALIGN_RIGHT)
      end
   end

   -- Draw traitor state
   local round_state = GAMEMODE.round_state

   local traitor_y = y - 30
   local text = nil
   if round_state == ROUND_ACTIVE then
      text = L[ client:GetRoleStringRaw() ]
   else
      text = L[ roundstate_string[round_state] ]
   end

   ShadowedText(text, "TraitorState", x + margin + 73, traitor_y, COLOR_WHITE, TEXT_ALIGN_CENTER)

   -- Draw round time
   local is_haste = HasteMode() and round_state == ROUND_ACTIVE
   local is_traitor = client:IsActiveTraitor()

   local endtime = _GetGlobalFloat("ttt_round_end", 0) - _CurTime()

   local text
   local font = "TimeLeft"
   local color = COLOR_WHITE
   local rx = x + margin + 170
   local ry = traitor_y + 3

   -- Time displays differently depending on whether haste mode is on,
   -- whether the player is traitor or not, and whether it is overtime.
   if is_haste then
      local hastetime = _GetGlobalFloat("ttt_haste_end", 0) - _CurTime()
      if hastetime < 0 then
         if (not is_traitor) or (_math_ceil(_CurTime()) % 7 <= 2) then
            -- innocent or blinking "overtime"
            text = L.overtime
            font = "Trebuchet18"

            -- need to hack the position a little because of the font switch
            ry = ry + 5
            rx = rx - 3
         else
            -- traitor and not blinking "overtime" right now, so standard endtime display
            text  = util.SimpleTime(_math_max(0, endtime), "%02i:%02i")
            color = COLOR_RED
         end
      else
         -- still in starting period
         local t = hastetime
         if is_traitor and _math_ceil(_CurTime()) % 6 < 2 then
            t = endtime
            color = COLOR_RED
         end
         text = util.SimpleTime(_math_max(0, t), "%02i:%02i")
      end
   else
      -- bog standard time when haste mode is off (or round not active)
      text = util.SimpleTime(_math_max(0, endtime), "%02i:%02i")
   end

   ShadowedText(text, font, rx, ry, color)

   if is_haste then
      dr.SimpleText(L.hastemode, "TabLarge", x + margin + 165, traitor_y - 8)
   end

end

-- Paints player status HUD element in the bottom left
function GM:HUDPaint()
   local client = _LocalPlayer()

   if _hook_Call( "HUDShouldDraw", GAMEMODE, "TTTTargetID" ) then
       _hook_Call( "HUDDrawTargetID", GAMEMODE )
   end
   
   if _hook_Call( "HUDShouldDraw", GAMEMODE, "TTTMStack" ) then
       MSTACK:Draw(client)
   end

   if (not client:Alive()) or client:Team() == TEAM_SPEC then
      if _hook_Call( "HUDShouldDraw", GAMEMODE, "TTTSpecHUD" ) then
          SpecHUDPaint(client)
      end

      return
   end

   if _hook_Call( "HUDShouldDraw", GAMEMODE, "TTTRadar" ) then
       RADAR:Draw(client)
   end
   
   if _hook_Call( "HUDShouldDraw", GAMEMODE, "TTTTButton" ) then
       TBHUD:Draw(client)
   end
   
   if _hook_Call( "HUDShouldDraw", GAMEMODE, "TTTWSwitch" ) then
       WSWITCH:Draw(client)
   end

   if _hook_Call( "HUDShouldDraw", GAMEMODE, "TTTVoice" ) then
       VOICE.Draw(client)
   end
   
   if _hook_Call( "HUDShouldDraw", GAMEMODE, "TTTDisguise" ) then
       DISGUISE.Draw(client)
   end

   if _hook_Call( "HUDShouldDraw", GAMEMODE, "TTTPickupHistory" ) then
       _hook_Call( "HUDDrawPickupHistory", GAMEMODE )
   end

   -- Draw bottom left info panel
   if _hook_Call( "HUDShouldDraw", GAMEMODE, "TTTInfoPanel" ) then
       InfoPaint(client)
   end
end

-- Hide the standard HUD stuff
local hud = {["CHudHealth"] = true, ["CHudBattery"] = true, ["CHudAmmo"] = true, ["CHudSecondaryAmmo"] = true}
function GM:HUDShouldDraw(name)
   if hud[name] then return false end

   return self.BaseClass.HUDShouldDraw(self, name)
end
