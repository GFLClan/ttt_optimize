local _concommand_Add = concommand.Add
local _RunConsoleCommand = RunConsoleCommand
local _surface_SetFont = (CLIENT and surface.SetFont or nil)
local _surface_SetTextPos = (CLIENT and surface.SetTextPos or nil)
local _surface_DrawText = (CLIENT and surface.DrawText or nil)
local _surface_GetTextSize = (CLIENT and surface.GetTextSize or nil)
local _LocalPlayer = (CLIENT and LocalPlayer or nil)
local _surface_SetTextColor = (CLIENT and surface.SetTextColor or nil)
local _vgui_Create = (CLIENT and vgui.Create or nil)
local _ScrH = (CLIENT and ScrH or nil)

DISGUISE = {}

local trans = LANG.GetTranslation

function DISGUISE.CreateMenu(parent)
   local dform = _vgui_Create("DForm", parent)
   dform:SetName(trans("disg_menutitle"))
   dform:StretchToParent(0,0,0,0)
   dform:SetAutoSize(false)

   local owned = _LocalPlayer():HasEquipmentItem(EQUIP_DISGUISE)

   if not owned then
      dform:Help(trans("disg_not_owned"))
      return dform
   end

   local dcheck = _vgui_Create("DCheckBoxLabel", dform)
   dcheck:SetText(trans("disg_enable"))
   dcheck:SetIndent(5)
   dcheck:SetValue(_LocalPlayer():GetNWBool("disguised", false))
   dcheck.OnChange = function(s, val)
                        _RunConsoleCommand("ttt_set_disguise", val and "1" or "0")
                     end
   dform:AddItem(dcheck)

   dform:Help(trans("disg_help1"))

   dform:Help(trans("disg_help2"))

   dform:SetVisible(true)

   return dform
end

function DISGUISE.Draw(client)
   if (not client) or (not client:IsActiveTraitor()) then return end
   if not client:GetNWBool("disguised", false) then return end

   _surface_SetFont("TabLarge")
   _surface_SetTextColor(255, 0, 0, 230)

   local text = trans("disg_hud")
   local w, h = _surface_GetTextSize(text)

   _surface_SetTextPos(36, _ScrH() - 160 - h)
   _surface_DrawText(text)
end

_concommand_Add("ttt_toggle_disguise", WEPS.DisguiseToggle)
