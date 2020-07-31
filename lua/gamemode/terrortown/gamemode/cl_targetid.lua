local _render_DrawQuadEasy = (CLIENT and render.DrawQuadEasy or nil)
local _EyePos = (CLIENT and EyePos or nil)
local _surface_SetFont = (CLIENT and surface.SetFont or nil)
local _cam_Start3D = (CLIENT and cam.Start3D or nil)
local _util_TraceLine = util.TraceLine
local _surface_SetMaterial = (CLIENT and surface.SetMaterial or nil)
local _LocalPlayer = (CLIENT and LocalPlayer or nil)
local _hook_Call = hook.Call
local _EyeAngles = (CLIENT and EyeAngles or nil)
local _draw_SimpleText = (CLIENT and draw.SimpleText or nil)
local _table_Copy = table.Copy
local _surface_GetTextSize = (CLIENT and surface.GetTextSize or nil)
local _ScrW = (CLIENT and ScrW or nil)
local _player_GetAll = player.GetAll
local _surface_CreateFont = (CLIENT and surface.CreateFont or nil)
local _math_sqrt = math.sqrt
local _Material = Material
local _render_SetColorModulation = (CLIENT and render.SetColorModulation or nil)
local _render_SetMaterial = (CLIENT and render.SetMaterial or nil)
local _render_MaterialOverride = (CLIENT and render.MaterialOverride or nil)
local _surface_SetTexture = (CLIENT and surface.SetTexture or nil)
local _IsValid = IsValid
local _surface_SetDrawColor = (CLIENT and surface.SetDrawColor or nil)
local _surface_DrawText = (CLIENT and surface.DrawText or nil)
local _Color = Color
local _cam_End3D = (CLIENT and cam.End3D or nil)
local _surface_GetTextureID = (CLIENT and surface.GetTextureID or nil)
local _ipairs = ipairs
local _surface_DrawTexturedRect = (CLIENT and surface.DrawTexturedRect or nil)
local _surface_SetTextPos = (CLIENT and surface.SetTextPos or nil)
local _render_SuppressEngineLighting = (CLIENT and render.SuppressEngineLighting or nil)
local _surface_SetTextColor = (CLIENT and surface.SetTextColor or nil)
local _ScrH = (CLIENT and ScrH or nil)
local _CreateConVar = CreateConVar

local util = util
local surface = surface
local draw = draw

local GetPTranslation = LANG.GetParamTranslation
local GetRaw = LANG.GetRawTranslation

local key_params = {usekey = Key("+use", "USE"), walkkey = Key("+walk", "WALK")}

local ClassHint = {
   prop_ragdoll = {
      name= "corpse",
      hint= "corpse_hint",

      fmt = function(ent, txt) return GetPTranslation(txt, key_params) end
   }
};

-- Access for servers to display hints using their own HUD/UI.
function GM:GetClassHints()
    return ClassHint
end

-- Basic access for servers to add/modify hints. They override hints stored on
-- the entities themselves.
function GM:AddClassHint(cls, hint)
   ClassHint[cls] = _table_Copy(hint)
end


---- "T" indicator above traitors

local indicator_mat = _Material("vgui/ttt/sprite_traitor")
local indicator_col = _Color(255, 255, 255, 130)

local client, plys, ply, pos, dir, tgt
local GetPlayers = _player_GetAll

local propspec_outline = _Material("models/props_combine/portalball001_sheet")

-- using this hook instead of pre/postplayerdraw because playerdraw seems to
-- happen before certain entities are drawn, which then clip over the sprite
function GM:PostDrawTranslucentRenderables()
   client = _LocalPlayer()
   plys = GetPlayers()

   if client:GetTraitor() then

      dir = client:GetForward() * -1

      _render_SetMaterial(indicator_mat)

      for i=1, #plys do
         ply = plys[i]
         if ply:IsActiveTraitor() and ply != client then
            pos = ply:GetPos()
            pos.z = pos.z + 74

            _render_DrawQuadEasy(pos, dir, 8, 8, indicator_col, 180)
         end
      end
   end

   if client:Team() == TEAM_SPEC then
      _cam_Start3D(_EyePos(), _EyeAngles())

      for i=1, #plys do
         ply = plys[i]
         tgt = ply:GetObserverTarget()
         if _IsValid(tgt) and tgt:GetNWEntity("spec_owner", nil) == ply then
            _render_MaterialOverride(propspec_outline)
            _render_SuppressEngineLighting(true)
            _render_SetColorModulation(1, 0.5, 0)

            tgt:SetModelScale(1.05, 0)
            tgt:DrawModel()

            _render_SetColorModulation(1, 1, 1)
            _render_SuppressEngineLighting(false)
            _render_MaterialOverride(nil)
         end
      end

      _cam_End3D()
   end
end

---- Spectator labels

local function DrawPropSpecLabels(client)
   if (not client:IsSpec()) and (GetRoundState() != ROUND_POST) then return end

   _surface_SetFont("TabLarge")

   local tgt = nil
   local scrpos = nil
   local text = nil
   local w = 0
   for _, ply in _ipairs(_player_GetAll()) do
      if ply:IsSpec() then
         _surface_SetTextColor(220,200,0,120)

         tgt = ply:GetObserverTarget()

         if _IsValid(tgt) and tgt:GetNWEntity("spec_owner", nil) == ply then

            scrpos = tgt:GetPos():ToScreen()
         else
            scrpos = nil
         end
      else
         local _, healthcolor = util.HealthToString(ply:Health(), ply:GetMaxHealth())
         _surface_SetTextColor(clr(healthcolor))

         scrpos = ply:EyePos()
         scrpos.z = scrpos.z + 20

         scrpos = scrpos:ToScreen()
      end

      if scrpos and (not IsOffScreen(scrpos)) then
         text = ply:Nick()
         w, _ = _surface_GetTextSize(text)

         _surface_SetTextPos(scrpos.x - w / 2, scrpos.y)
         _surface_DrawText(text)
      end
   end
end


---- Crosshair affairs

_surface_CreateFont("TargetIDSmall2", {font = "TargetID",
                                      size = 16,
                                      weight = 1000})

local minimalist = _CreateConVar("ttt_minimal_targetid", "0", FCVAR_ARCHIVE)

local magnifier_mat = _Material("icon16/magnifier.png")
local ring_tex = _surface_GetTextureID("effects/select_ring")

local rag_color = _Color(200,200,200,255)

local GetLang = LANG.GetUnsafeLanguageTable

local MAX_TRACE_LENGTH = _math_sqrt(3) * 2 * 16384

function GM:HUDDrawTargetID()
   local client = _LocalPlayer()

   local L = GetLang()

   if _hook_Call( "HUDShouldDraw", GAMEMODE, "TTTPropSpec" ) then
      DrawPropSpecLabels(client)
   end

   local startpos = client:EyePos()
   local endpos = client:GetAimVector()
   endpos:Mul(MAX_TRACE_LENGTH)
   endpos:Add(startpos)

   local trace = _util_TraceLine({
      start = startpos,
      endpos = endpos,
      mask = MASK_SHOT,
      filter = client:GetObserverMode() == OBS_MODE_IN_EYE and {client, client:GetObserverTarget()} or client
   })
   local ent = trace.Entity
   if (not _IsValid(ent)) or ent.NoTarget then return end

   -- some bools for caching what kind of ent we are looking at
   local target_traitor = false
   local target_detective = false
   local target_corpse = false

   local text = nil
   local color = COLOR_WHITE

   -- if a vehicle, we identify the driver instead
   if _IsValid(ent:GetNWEntity("ttt_driver", nil)) then
      ent = ent:GetNWEntity("ttt_driver", nil)

      if ent == client then return end
   end

   local cls = ent:GetClass()
   local minimal = minimalist:GetBool()
   local hint = (not minimal) and (ent.TargetIDHint or ClassHint[cls])

   if ent:IsPlayer() then
      if ent:GetNWBool("disguised", false) then
         client.last_id = nil

         if client:IsTraitor() or client:IsSpec() then
            text = ent:Nick() .. L.target_disg
         else
            -- Do not show anything
            return
         end

         color = COLOR_RED
      else
         text = ent:Nick()
         client.last_id = ent
      end

      local _ -- Stop global clutter
      -- in minimalist targetID, colour nick with health level
      if minimal then
         _, color = util.HealthToString(ent:Health(), ent:GetMaxHealth())
      end

      if client:IsTraitor() and GetRoundState() == ROUND_ACTIVE then
         target_traitor = ent:IsTraitor()
      end

      target_detective = GetRoundState() > ROUND_PREP and ent:IsDetective() or false

   elseif cls == "prop_ragdoll" then
      -- only show this if the ragdoll has a nick, else it could be a mattress
      if CORPSE.GetPlayerNick(ent, false) == false then return end

      target_corpse = true

      if CORPSE.GetFound(ent, false) or not DetectiveMode() then
         text = CORPSE.GetPlayerNick(ent, "A Terrorist")
      else
         text  = L.target_unid
         color = COLOR_YELLOW
      end
   elseif not hint then
      -- Not something to ID and not something to hint about
      return
   end

   local x_orig = _ScrW() / 2.0
   local x = x_orig
   local y = _ScrH() / 2.0

   local w, h = 0,0 -- text width/height, reused several times

   if target_traitor or target_detective then
      _surface_SetTexture(ring_tex)

      if target_traitor then
         _surface_SetDrawColor(255, 0, 0, 200)
      else
         _surface_SetDrawColor(0, 0, 255, 220)
      end
      _surface_DrawTexturedRect(x-32, y-32, 64, 64)
   end

   y = y + 30
   local font = "TargetID"
   _surface_SetFont( font )

   -- Draw main title, ie. nickname
   if text then
      w, h = _surface_GetTextSize( text )

      x = x - w / 2

      _draw_SimpleText( text, font, x+1, y+1, COLOR_BLACK )
      _draw_SimpleText( text, font, x, y, color )

      -- for ragdolls searched by detectives, add icon
      if ent.search_result and client:IsDetective() then
         -- if I am detective and I know a search result for this corpse, then I
         -- have searched it or another detective has
         _surface_SetMaterial(magnifier_mat)
         _surface_SetDrawColor(200, 200, 255, 255)
         _surface_DrawTexturedRect(x + w + 5, y, 16, 16)
      end

      y = y + h + 4
   end

   -- Minimalist target ID only draws a health-coloured nickname, no hints, no
   -- karma, no tag
   if minimal then return end

   -- Draw subtitle: health or type
   local clr = rag_color
   if ent:IsPlayer() then
      text, clr = util.HealthToString(ent:Health(), ent:GetMaxHealth())

      -- HealthToString returns a string id, need to look it up
      text = L[text]
   elseif hint then
      text = GetRaw(hint.name) or hint.name
   else
      return
   end
   font = "TargetIDSmall2"

   _surface_SetFont( font )
   w, h = _surface_GetTextSize( text )
   x = x_orig - w / 2

   _draw_SimpleText( text, font, x+1, y+1, COLOR_BLACK )
   _draw_SimpleText( text, font, x, y, clr )

   font = "TargetIDSmall"
   _surface_SetFont( font )

   -- Draw second subtitle: karma
   if ent:IsPlayer() and KARMA.IsEnabled() then
      text, clr = util.KarmaToString(ent:GetBaseKarma())

      text = L[text]

      w, h = _surface_GetTextSize( text )
      y = y + h + 5
      x = x_orig - w / 2

      _draw_SimpleText( text, font, x+1, y+1, COLOR_BLACK )
      _draw_SimpleText( text, font, x, y, clr )
   end

   -- Draw key hint
   if hint and hint.hint then
      if not hint.fmt then
         text = GetRaw(hint.hint) or hint.hint
      else
         text = hint.fmt(ent, hint.hint)
      end

      w, h = _surface_GetTextSize(text)
      x = x_orig - w / 2
      y = y + h + 5
      _draw_SimpleText( text, font, x+1, y+1, COLOR_BLACK )
      _draw_SimpleText( text, font, x, y, COLOR_LGRAY )
   end

   text = nil

   if target_traitor then
      text = L.target_traitor
      clr = COLOR_RED
   elseif target_detective then
      text = L.target_detective
      clr = COLOR_BLUE
   elseif ent.sb_tag and ent.sb_tag.txt != nil then
      text = L[ ent.sb_tag.txt ]
      clr = ent.sb_tag.color
   elseif target_corpse and client:IsActiveTraitor() and CORPSE.GetCredits(ent, 0) > 0 then
      text = L.target_credits
      clr = COLOR_YELLOW
   end

   if text then
      w, h = _surface_GetTextSize( text )
      x = x_orig - w / 2
      y = y + h + 5

      _draw_SimpleText( text, font, x+1, y+1, COLOR_BLACK )
      _draw_SimpleText( text, font, x, y, clr )
   end
end
