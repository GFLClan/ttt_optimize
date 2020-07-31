local _IsValid = IsValid
local _vgui_Create = (CLIENT and vgui.Create or nil)
local _player_GetAll = player.GetAll
local _RunConsoleCommand = RunConsoleCommand
local _ipairs = ipairs
local _LocalPlayer = (CLIENT and LocalPlayer or nil)

--- Credit transfer tab for equipment menu
local GetTranslation = LANG.GetTranslation
function CreateTransferMenu(parent)
   local dform = _vgui_Create("DForm", parent)
   dform:SetName(GetTranslation("xfer_menutitle"))
   dform:StretchToParent(0,0,0,0)
   dform:SetAutoSize(false)

   if _LocalPlayer():GetCredits() <= 0 then
      dform:Help(GetTranslation("xfer_no_credits"))
      return dform
   end

   local bw, bh = 100, 20
   local dsubmit = _vgui_Create("DButton", dform)
   dsubmit:SetSize(bw, bh)
   dsubmit:SetDisabled(true)
   dsubmit:SetText(GetTranslation("xfer_send"))

   local selected_sid = nil

   local dpick = _vgui_Create("DComboBox", dform)
   dpick.OnSelect = function(s, idx, val, data)
                       if data then
                          selected_sid = data
                          dsubmit:SetDisabled(false)
                       end
                    end

   dpick:SetWide(250)

   -- fill combobox
   local r = _LocalPlayer():GetRole()
   for _, p in _ipairs(_player_GetAll()) do
      if _IsValid(p) and p:IsActiveRole(r) and p != _LocalPlayer() then
         dpick:AddChoice(p:Nick(), p:SteamID())
      end
   end

   -- select first player by default
   if dpick:GetOptionText(1) then dpick:ChooseOptionID(1) end

   dsubmit.DoClick = function(s)
                        if selected_sid then
                           _RunConsoleCommand("ttt_transfer_credits", selected_sid, "1")
                        end
                     end

   dsubmit.Think = function(s)
                      if _LocalPlayer():GetCredits() < 1 then
                         s:SetDisabled(true)
                      end
                   end

   dform:AddItem(dpick)
   dform:AddItem(dsubmit)

   dform:Help(LANG.GetParamTranslation("xfer_help", {role = _LocalPlayer():GetRoleString()}))

   return dform
end
