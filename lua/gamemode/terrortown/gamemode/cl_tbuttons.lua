local _surface_PlaySound = (CLIENT and surface.PlaySound or nil)
local _surface_SetDrawColor = (CLIENT and surface.SetDrawColor or nil)
local _RunConsoleCommand = RunConsoleCommand
local _IsValid = IsValid
local _ipairs = ipairs
local _surface_SetFont = (CLIENT and surface.SetFont or nil)
local _LocalPlayer = (CLIENT and LocalPlayer or nil)
local _surface_DrawText = (CLIENT and surface.DrawText or nil)
local _surface_GetTextureID = (CLIENT and surface.GetTextureID or nil)
local _ScrW = (CLIENT and ScrW or nil)
local _surface_DrawTexturedRect = (CLIENT and surface.DrawTexturedRect or nil)
local _net_Receive = net.Receive
local _surface_SetTextPos = (CLIENT and surface.SetTextPos or nil)
local _CurTime = CurTime
local _surface_SetTextColor = (CLIENT and surface.SetTextColor or nil)
local _Sound = Sound
local _tostring = tostring
local _table_Count = table.Count
local _pairs = pairs
local _ScrH = (CLIENT and ScrH or nil)
local _math_abs = math.abs
local _surface_SetTexture = (CLIENT and surface.SetTexture or nil)
--- Display of and interaction with ttt_traitor_button
local surface = surface
local pairs = _pairs
local math = math
local abs = _math_abs

TBHUD = {}
TBHUD.buttons = {}
TBHUD.buttons_count = 0

TBHUD.focus_ent = nil
TBHUD.focus_stick = 0

function TBHUD:Clear()
   self.buttons = {}
   self.buttons_count = 0

   self.focus_ent = nil
   self.focus_stick = 0
end

function TBHUD:CacheEnts()
   if _IsValid(_LocalPlayer()) and _LocalPlayer():IsActiveTraitor() then
      self.buttons = {}
      for _, ent in _ipairs(ents.FindByClass("ttt_traitor_button")) do
         if _IsValid(ent) then
            self.buttons[ent:EntIndex()] = ent
         end
      end
   else
      self.buttons = {}
   end

   self.buttons_count = _table_Count(self.buttons)
end

function TBHUD:PlayerIsFocused()
   return _IsValid(_LocalPlayer()) and _LocalPlayer():IsActiveTraitor() and _IsValid(self.focus_ent)
end

function TBHUD:UseFocused()
   if _IsValid(self.focus_ent) and self.focus_stick >= _CurTime() then
      _RunConsoleCommand("ttt_use_tbutton", _tostring(self.focus_ent:EntIndex()))

      self.focus_ent = nil
      return true
   else
      return false
   end
end

local confirm_sound = _Sound("buttons/button24.wav")
function TBHUD.ReceiveUseConfirm()
   _surface_PlaySound(confirm_sound)

   TBHUD:CacheEnts()
end
_net_Receive("TTT_ConfirmUseTButton", TBHUD.ReceiveUseConfirm)

local function ComputeRangeFactor(plypos, tgtpos)
   local d = tgtpos - plypos
   d = d:Dot(d)
   return d / range
end

local tbut_normal = _surface_GetTextureID("vgui/ttt/tbut_hand_line")
local tbut_focus = _surface_GetTextureID("vgui/ttt/tbut_hand_filled")
local size = 32
local mid  = size / 2
local focus_range = 25

local use_key = Key("+use", "USE")

local GetTranslation = LANG.GetTranslation
local GetPTranslation = LANG.GetParamTranslation
function TBHUD:Draw(client)
   if self.buttons_count != 0 then
      _surface_SetTexture(tbut_normal)

      -- we're doing slowish distance computation here, so lots of probably
      -- ineffective micro-optimization
      local plypos = client:GetPos()
      local midscreen_x = _ScrW() / 2
      local midscreen_y = _ScrH() / 2
      local pos, scrpos, d
      local focus_ent = nil
      local focus_d, focus_scrpos_x, focus_scrpos_y = 0, midscreen_x, midscreen_y

      -- draw icon on HUD for every button within range
      for k, but in pairs(self.buttons) do
         if _IsValid(but) and but.IsUsable then
            pos = but:GetPos()
            scrpos = pos:ToScreen()

            if (not IsOffScreen(scrpos)) and but:IsUsable() then
               d = pos - plypos
               d = d:Dot(d) / (but:GetUsableRange() ^ 2)
               -- draw if this button is within range, with alpha based on distance
               if d < 1 then
                  _surface_SetDrawColor(255, 255, 255, 200 * (1 - d))
                  _surface_DrawTexturedRect(scrpos.x - mid, scrpos.y - mid, size, size)

                  if d > focus_d then
                     local x = abs(scrpos.x - midscreen_x)
                     local y = abs(scrpos.y - midscreen_y)
                     if (x < focus_range and y < focus_range and
                         x < focus_scrpos_x and y < focus_scrpos_y) then

                        -- avoid constantly switching focus every frame causing
                        -- 2+ buttons to appear in focus, instead "stick" to one
                        -- ent for a very short time to ensure consistency
                        if self.focus_stick < _CurTime() or but == self.focus_ent then
                           focus_ent = but
                        end
                     end
                  end
               end
            end
         end

         -- draw extra graphics and information for button when it's in-focus
         if _IsValid(focus_ent) then
            self.focus_ent = focus_ent
            self.focus_stick = _CurTime() + 0.1

            local scrpos = focus_ent:GetPos():ToScreen()

            local sz = 16

            -- redraw in-focus version of icon
            _surface_SetTexture(tbut_focus)
            _surface_SetDrawColor(255, 255, 255, 200)
            _surface_DrawTexturedRect(scrpos.x - mid, scrpos.y - mid, size, size)

            -- description
            _surface_SetTextColor(255, 50, 50, 255)
            _surface_SetFont("TabLarge")

            local x = scrpos.x + sz + 10
            local y = scrpos.y - sz - 3
            _surface_SetTextPos(x, y)
            _surface_DrawText(focus_ent:GetDescription())

            y = y + 12
            _surface_SetTextPos(x, y)
            if focus_ent:GetDelay() < 0 then
               _surface_DrawText(GetTranslation("tbut_single"))
            elseif focus_ent:GetDelay() == 0 then
               _surface_DrawText(GetTranslation("tbut_reuse"))
            else
               _surface_DrawText(GetPTranslation("tbut_retime", {num = focus_ent:GetDelay()}))
            end

            y = y + 12
            _surface_SetTextPos(x, y)
            _surface_DrawText(GetPTranslation("tbut_help", {key = use_key}))
         end
      end
   end
end
