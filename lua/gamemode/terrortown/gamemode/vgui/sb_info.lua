local _vgui_Register = (CLIENT and vgui.Register or nil)
local _surface_SetDrawColor = (CLIENT and surface.SetDrawColor or nil)
local _SortedPairsByMemberValue = SortedPairsByMemberValue
local _Color = Color
local _IsValid = IsValid
local _surface_DrawOutlinedRect = (CLIENT and surface.DrawOutlinedRect or nil)
local _vgui_Create = (CLIENT and vgui.Create or nil)
local _pairs = pairs
local _ipairs = ipairs

---- Player info panel, based on sandbox scoreboard's infocard

local vgui = vgui

local GetTranslation = LANG.GetTranslation
local GetPTranslation = LANG.GetParamTranslation


--- Base stuff
local PANEL = {}

function PANEL:Init()
   self.Player = nil

   --self:SetMouseInputEnabled(false)
end

function PANEL:SetPlayer(ply)
   self.Player = ply
   self:UpdatePlayerData()
end

function PANEL:UpdatePlayerData()
   -- override me
end

function PANEL:Paint()
   return true
end

_vgui_Register("TTTScorePlayerInfoBase", PANEL, "Panel")

--- Dead player search results

local PANEL = {}

function PANEL:Init()
   self.List = _vgui_Create("DPanelSelect", self)
   self.List:EnableHorizontal(true)

   if self.List.VBar then
      self.List.VBar:Remove()
      self.List.VBar = nil
   end

   self.Scroll = _vgui_Create("DHorizontalScroller", self.List)

   self.Help = _vgui_Create("DLabel", self)
   self.Help:SetText(GetTranslation("sb_info_help"))
   self.Help:SetFont("treb_small")
   self.Help:SetVisible(false)
end

function PANEL:PerformLayout()
   self:SetSize(self:GetWide(), 75)

   self.List:SetPos(0, 0)
   self.List:SetSize(self:GetWide(), 70)
   self.List:SetSpacing(1)
   self.List:SetPadding(2)
   self.List:SetPaintBackground(false)

   self.Scroll:StretchToParent(3,3,3,3)

   self.Help:SizeToContents()
   self.Help:SetPos(5, 5)
end

function PANEL:UpdatePlayerData()
   if not _IsValid(self.Player) then return end
   if not self.Player.search_result then
      self.Help:SetVisible(true)
      return
   end

   self.Help:SetVisible(false)

   if self.Search == self.Player.search_result then return end

   self.List:Clear(true)
   self.Scroll.Panels = {}

   local search_raw = self.Player.search_result

   -- standard search result preproc
   local search = PreprocSearch(search_raw)

   -- wipe some stuff we don't need, like id
   search.nick = nil

   -- Create table of SimpleIcons, each standing for a piece of search
   -- information.
   for t, info in _SortedPairsByMemberValue(search, "p") do
      local ic = nil

      -- Certain items need a special icon conveying additional information
      if t == "lastid" then
         ic = _vgui_Create("SimpleIconAvatar", self.List)
         ic:SetPlayer(info.ply)
         ic:SetAvatarSize(24)
      elseif t == "dtime" then
         ic = _vgui_Create("SimpleIconLabelled", self.List)
         ic:SetIconText(info.text_icon)
      else
         ic = _vgui_Create("SimpleIcon", self.List)
      end

      ic:SetIconSize(64)
      ic:SetIcon(info.img)

      ic:SetTooltip(info.text)

      ic.info_type = t

      self.List:AddPanel(ic)
      self.Scroll:AddPanel(ic)
   end

   self.Search = search_raw

   self.List:InvalidateLayout()
   self.Scroll:InvalidateLayout()

   self:PerformLayout()
end


_vgui_Register("TTTScorePlayerInfoSearch", PANEL, "TTTScorePlayerInfoBase")

--- Living player, tags etc

local tags = {
   {txt="sb_tag_friend", color=COLOR_GREEN},
   {txt="sb_tag_susp",   color=COLOR_YELLOW},
   {txt="sb_tag_avoid",  color=_Color(255, 150, 0, 255)},
   {txt="sb_tag_kill",   color=COLOR_RED},
   {txt="sb_tag_miss",   color=_Color(130, 190, 130, 255)}
};

local PANEL = {}

function PANEL:Init()
   self.TagButtons = {}

   for k, tag in _ipairs(tags) do
      self.TagButtons[k] = _vgui_Create("TagButton", self)
      self.TagButtons[k]:SetupTag(tag)
   end

   --self:SetMouseInputEnabled(false)
end

function PANEL:SetPlayer(ply)
   self.Player = ply

   for _, btn in _pairs(self.TagButtons) do
      btn:SetPlayer(ply)
   end

   self:InvalidateLayout()
end

function PANEL:ApplySchemeSettings()

end

function PANEL:UpdateTag()
   self:GetParent():UpdatePlayerData()

   self:GetParent():SetOpen(false)
end

function PANEL:PerformLayout()
   self:SetSize(self:GetWide(), 30)

   local margin = 10
   local x = 250 --29
   local y = 0

   for k, btn in _ipairs(self.TagButtons) do
      btn:SetPos(x, y)
      btn:SetCursor("hand")
      btn:SizeToContents()
      btn:PerformLayout()
      x = x + btn:GetWide() + margin
   end
end

_vgui_Register("TTTScorePlayerInfoTags", PANEL, "TTTScorePlayerInfoBase")

--- Tag button
local PANEL = {}

function PANEL:Init()
   self.Player = nil

   self:SetText("")
   self:SetMouseInputEnabled(true)
   self:SetKeyboardInputEnabled(false)

   self:SetTall(20)

   self:SetPaintBackgroundEnabled(false)
   self:SetPaintBorderEnabled(false)

   self:SetPaintBackground(false)
   self:SetDrawBorder(false)

   self:SetFont("treb_small")
   self:SetTextColor(self.Tag and self.Tag.color or COLOR_WHITE)
end

function PANEL:SetPlayer(ply)
   self.Player = ply
end

function PANEL:SetupTag(tag)
   self.Tag = tag

   self.Color = tag.color
   self.Text = tag.txt

   self:SetTextColor(self.Tag and self.Tag.color or COLOR_WHITE)
end

function PANEL:PerformLayout()
   self:SetText(self.Tag and GetTranslation(self.Tag.txt) or "")
   self:SizeToContents()
   self:SetContentAlignment(5)
   self:SetSize(self:GetWide() + 10, self:GetTall() + 3)
end

function PANEL:DoRightClick()
   if _IsValid(self.Player) then
      self.Player.sb_tag = nil

      self:GetParent():UpdateTag()
   end
end

function PANEL:DoClick()
   if _IsValid(self.Player) then
      if self.Player.sb_tag == self.Tag then
         self.Player.sb_tag = nil
      else
         self.Player.sb_tag = self.Tag
      end

      self:GetParent():UpdateTag()
   end
end


local select_color = _Color(255, 200, 0, 255)
function PANEL:PaintOver()
   if self.Player and self.Player.sb_tag == self.Tag then
      _surface_SetDrawColor(255,200,0,255)
      _surface_DrawOutlinedRect(0, 0, self:GetWide(), self:GetTall())
   end
end

_vgui_Register("TagButton", PANEL, "DButton")
