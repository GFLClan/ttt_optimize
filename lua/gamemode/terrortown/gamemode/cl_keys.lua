local _IsValid = IsValid
local _IsFirstTimePredicted = IsFirstTimePredicted
local _RunConsoleCommand = RunConsoleCommand
local _string_sub = string.sub
local _string_find = string.find
local _GetConVar = GetConVar
local _LocalPlayer = (CLIENT and LocalPlayer or nil)
local _tonumber = tonumber
local _timer_Simple = timer.Simple
-- Key overrides for TTT specific keyboard functions

local function SendWeaponDrop()
   _RunConsoleCommand("ttt_dropweapon")

   -- Turn off weapon switch display if you had it open while dropping, to avoid
   -- inconsistencies.
   WSWITCH:Disable()
end

function GM:OnSpawnMenuOpen()
   SendWeaponDrop()
end

function GM:PlayerBindPress(ply, bind, pressed)
   if not _IsValid(ply) then return end

   if bind == "invnext" and pressed then
      if ply:IsSpec() then
         TIPS.Next()
      else
         WSWITCH:SelectNext()
      end
      return true
   elseif bind == "invprev" and pressed then
      if ply:IsSpec() then
         TIPS.Prev()
      else
         WSWITCH:SelectPrev()
      end
      return true
   elseif bind == "+attack" then
      if WSWITCH:PreventAttack() then
         if not pressed then
            WSWITCH:ConfirmSelection()
         end
         return true
      end
   elseif bind == "+sprint" then
      -- set voice type here just in case shift is no longer down when the
      -- PlayerStartVoice hook runs, which might be the case when switching to
      -- steam overlay
      ply.traitor_gvoice = false
      _RunConsoleCommand("tvog", "0")
      return true
   elseif bind == "+use" and pressed then
      if ply:IsSpec() then
         _RunConsoleCommand("ttt_spec_use")
         return true
      elseif TBHUD:PlayerIsFocused() then
         return TBHUD:UseFocused()
      end
   elseif _string_sub(bind, 1, 4) == "slot" and pressed then
      local idx = _tonumber(_string_sub(bind, 5, -1)) or 1

      -- if radiomenu is open, override weapon select
      if RADIO.Show then
         RADIO:SendCommand(idx)
      else
         WSWITCH:SelectSlot(idx)
      end
      return true
   elseif _string_find(bind, "zoom") and pressed then
      -- open or close radio
      RADIO:ShowRadioCommands(not RADIO.Show)
      return true
   elseif bind == "+voicerecord" then
      if not VOICE.CanSpeak() then
         return true
      end
   elseif bind == "gm_showteam" and pressed and ply:IsSpec() then
      local m = VOICE.CycleMuteState()
      _RunConsoleCommand("ttt_mute_team", m)
      return true
   elseif bind == "+duck" and pressed and ply:IsSpec() then
      if not _IsValid(ply:GetObserverTarget()) then
         if GAMEMODE.ForcedMouse then
            gui.EnableScreenClicker(false)
            GAMEMODE.ForcedMouse = false
         else
            gui.EnableScreenClicker(true)
            GAMEMODE.ForcedMouse = true
         end
      end
   elseif bind == "noclip" and pressed then
      if not _GetConVar("sv_cheats"):GetBool() then
         _RunConsoleCommand("ttt_equipswitch")
         return true
      end
   elseif (bind == "gmod_undo" or bind == "undo") and pressed then
      _RunConsoleCommand("ttt_dropammo")
      return true
   elseif bind == "phys_swap" and pressed then
      _RunConsoleCommand("ttt_quickslot", "5")
   end
end

-- Note that for some reason KeyPress and KeyRelease are called multiple times
-- for the same key event in multiplayer.
function GM:KeyPress(ply, key)
   if not _IsFirstTimePredicted() then return end
   if not _IsValid(ply) or ply != _LocalPlayer() then return end

   if key == IN_SPEED and ply:IsActiveTraitor() then
      _timer_Simple(0.05, function() _RunConsoleCommand("+voicerecord") end)
   end
end

function GM:KeyRelease(ply, key)
   if not _IsFirstTimePredicted() then return end
   if not _IsValid(ply) or ply != _LocalPlayer() then return end

   if key == IN_SPEED and ply:IsActiveTraitor() then
      _timer_Simple(0.05, function() _RunConsoleCommand("-voicerecord") end)
   end
end

function GM:PlayerButtonUp(ply, btn)
   if not _IsFirstTimePredicted() then return end
   -- Would be nice to clean up this whole "all key handling in massive
   -- functions" thing. oh well
   if btn == KEY_PAD_ENTER then
      WEPS.DisguiseToggle(ply)
   end
end
