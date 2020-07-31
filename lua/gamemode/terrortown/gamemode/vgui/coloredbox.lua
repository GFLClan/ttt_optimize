local _Color = Color
local _surface_SetDrawColor = (CLIENT and surface.SetDrawColor or nil)
local _AccessorFunc = AccessorFunc
-- Removed in GM13, still need it
local PANEL = {}
_AccessorFunc( PANEL, "m_bBorder", "Border" )
_AccessorFunc( PANEL, "m_Color", "Color" )

function PANEL:Init()
    self:SetBorder( true )
    self:SetColor( _Color( 0, 255, 0, 255 ) )
end

function PANEL:Paint()
    _surface_SetDrawColor( self.m_Color.r, self.m_Color.g, self.m_Color.b, 255 )
    self:DrawFilledRect()
end

function PANEL:PaintOver()
    if not self.m_bBorder then return end

    _surface_SetDrawColor( 0, 0, 0, 255 )
    self:DrawOutlinedRect()
end
derma.DefineControl( "ColoredBox", "", PANEL, "DPanel" )
