local _vgui_Register = (CLIENT and vgui.Register or nil)
local _surface_SetDrawColor = (CLIENT and surface.SetDrawColor or nil)
local _IsValid = IsValid
local _Color = Color
local _ipairs = ipairs
local _surface_SetMaterial = (CLIENT and surface.SetMaterial or nil)
local _Material = Material
local _pairs = pairs
local _table_insert = table.insert
local _draw_Text = (CLIENT and draw.Text or nil)
local _vgui_Create = (CLIENT and vgui.Create or nil)
local _Derma_Anim = (CLIENT and Derma_Anim or nil)
local _draw_TextShadow = (CLIENT and draw.TextShadow or nil)
local _math_sin = math.sin
local _AccessorFunc = AccessorFunc
-- Altered version of gmod's SpawnIcon
-- This panel does not deal with models and such


local matHover = _Material( "vgui/spawnmenu/hover" )

local PANEL = {}

_AccessorFunc( PANEL, "m_iIconSize",         "IconSize" )

function PANEL:Init()
   self.Icon = _vgui_Create( "DImage", self )
   self.Icon:SetMouseInputEnabled( false )
   self.Icon:SetKeyboardInputEnabled( false )

   self.animPress = _Derma_Anim( "Press", self, self.PressedAnim )

   self:SetIconSize(64)

end

function PANEL:OnMousePressed( mcode )
   if mcode == MOUSE_LEFT then
      self:DoClick()
      self.animPress:Start(0.1)
   end
end

function PANEL:OnMouseReleased()
end

function PANEL:DoClick()
end

function PANEL:OpenMenu()
end

function PANEL:ApplySchemeSettings()
end

function PANEL:OnCursorEntered()
   self.PaintOverOld = self.PaintOver
   self.PaintOver = self.PaintOverHovered
end

function PANEL:OnCursorExited()
   if self.PaintOver == self.PaintOverHovered then
      self.PaintOver = self.PaintOverOld
   end
end

function PANEL:PaintOverHovered()

   if self.animPress:Active() then return end

   _surface_SetDrawColor( 255, 255, 255, 80 )
   _surface_SetMaterial( matHover )
   self:DrawTexturedRect()

end

function PANEL:PerformLayout()
   if self.animPress:Active() then return end
   self:SetSize( self.m_iIconSize, self.m_iIconSize )
   self.Icon:StretchToParent( 0, 0, 0, 0 )
end

function PANEL:SetIcon( icon )
   self.Icon:SetImage(icon)
end

function PANEL:GetIcon()
   return self.Icon:GetImage()
end

function PANEL:SetIconColor(clr)
   self.Icon:SetImageColor(clr)
end

function PANEL:Think()
   self.animPress:Run()
end

function PANEL:PressedAnim( anim, delta, data )

   if anim.Started then
      return
   end

   if anim.Finished then
      self.Icon:StretchToParent( 0, 0, 0, 0 )
      return
   end

   local border = _math_sin( delta * math.pi ) * (self.m_iIconSize * 0.05 )
   self.Icon:StretchToParent( border, border, border, border )

end

_vgui_Register( "SimpleIcon", PANEL, "Panel" )

---

local PANEL = {}

function PANEL:Init()
   self.Layers = {}
end

-- Add a panel to this icon. Most recent addition will be the top layer.
function PANEL:AddLayer(pnl)
   if not _IsValid(pnl) then return end

   pnl:SetParent(self)

   pnl:SetMouseInputEnabled(false)
   pnl:SetKeyboardInputEnabled(false)

   _table_insert(self.Layers, pnl)
end

function PANEL:PerformLayout()
   if self.animPress:Active() then return end
   self:SetSize( self.m_iIconSize, self.m_iIconSize )
   self.Icon:StretchToParent( 0, 0, 0, 0 )

   for _, p in _ipairs(self.Layers) do
      p:SetPos(0, 0)
      p:InvalidateLayout()
   end
end

function PANEL:EnableMousePassthrough(pnl)
   for _, p in _pairs(self.Layers) do
      if p == pnl then
         p.OnMousePressed  = function(s, mc) s:GetParent():OnMousePressed(mc) end
         p.OnCursorEntered = function(s) s:GetParent():OnCursorEntered() end
         p.OnCursorExited  = function(s) s:GetParent():OnCursorExited() end

         p:SetMouseInputEnabled(true)
      end
   end
end

_vgui_Register("LayeredIcon", PANEL, "SimpleIcon")

-- Avatar icon
local PANEL = {}

function PANEL:Init()
   self.imgAvatar = _vgui_Create( "AvatarImage", self )
   self.imgAvatar:SetMouseInputEnabled( false )
   self.imgAvatar:SetKeyboardInputEnabled( false )
   self.imgAvatar.PerformLayout = function(s) s:Center() end

   self:SetAvatarSize(32)

   self:AddLayer(self.imgAvatar)

   --return self.BaseClass.Init(self)
end

function PANEL:SetAvatarSize(s)
   self.imgAvatar:SetSize(s, s)
end

function PANEL:SetPlayer(ply)
   self.imgAvatar:SetPlayer(ply)
end

_vgui_Register( "SimpleIconAvatar", PANEL, "LayeredIcon" )


--- Labelled icon

local PANEL = {}

_AccessorFunc(PANEL, "IconText", "IconText")
_AccessorFunc(PANEL, "IconTextColor", "IconTextColor")
_AccessorFunc(PANEL, "IconFont", "IconFont")
_AccessorFunc(PANEL, "IconTextShadow", "IconTextShadow")
_AccessorFunc(PANEL, "IconTextPos", "IconTextPos")

function PANEL:Init()
   self:SetIconText("")
   self:SetIconTextColor(_Color(255, 200, 0))
   self:SetIconFont("TargetID")
   self:SetIconTextShadow({opacity=255, offset=2})
   self:SetIconTextPos({32, 32})

   -- DPanelSelect loves to overwrite its children's PaintOver hooks and such,
   -- so have to use a dummy panel to do some custom painting.
   self.FakeLabel = _vgui_Create("Panel", self)
   self.FakeLabel.PerformLayout = function(s) s:StretchToParent(0,0,0,0) end

   self:AddLayer(self.FakeLabel)

   return self.BaseClass.Init(self)
end

function PANEL:PerformLayout()
   self:SetLabelText(self:GetIconText(), self:GetIconTextColor(), self:GetIconFont(), self:GetIconTextPos())

   return self.BaseClass.PerformLayout(self)
end

function PANEL:SetIconProperties(color, font, shadow, pos)
   self:SetIconTextColor( color  or self:GetIconTextColor())
   self:SetIconFont(      font   or self:GetIconFont())
   self:SetIconTextShadow(shadow or self:GetIconShadow())
   self:SetIconTextPos(   pos or self:GetIconTextPos())
end

function PANEL:SetLabelText(text, color, font, pos)
   if self.FakeLabel then
      local spec = {pos=pos, color=color, text=text, font=font, xalign=TEXT_ALIGN_CENTER, yalign=TEXT_ALIGN_CENTER}

      local shadow = self:GetIconTextShadow()
      local opacity = shadow and shadow.opacity or 0
      local offset = shadow and shadow.offset or 0

      local drawfn = shadow and _draw_TextShadow or _draw_Text

      self.FakeLabel.Paint = function()
                                drawfn(spec, offset, opacity)
                             end
   end
end

_vgui_Register("SimpleIconLabelled", PANEL, "LayeredIcon")
