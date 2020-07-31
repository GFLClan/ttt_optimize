local _GetGlobalInt = GetGlobalInt
local _ErrorNoHalt = ErrorNoHalt
local _surface_SetFont = (CLIENT and surface.SetFont or nil)
local _Color = Color
local _math_Clamp = math.Clamp
local _include = include
local _LocalPlayer = (CLIENT and LocalPlayer or nil)
local _IsValid = IsValid
local _vgui_Create = (CLIENT and vgui.Create or nil)
local _table_insert = table.insert
local _surface_GetTextSize = (CLIENT and surface.GetTextSize or nil)
local _ScrW = (CLIENT and ScrW or nil)
local _GetHostName = GetHostName
local _vgui_Register = (CLIENT and vgui.Register or nil)
local _string_sub = string.sub
local _player_GetAll = player.GetAll
local _surface_CreateFont = (CLIENT and surface.CreateFont or nil)
local _GetConVar = GetConVar
local _CreateClientConVar = CreateClientConVar
local _error = error
local _pairs = pairs
local _timer_Exists = timer.Exists
local _surface_SetTexture = (CLIENT and surface.SetTexture or nil)
local _surface_PlaySound = (CLIENT and surface.PlaySound or nil)
local _surface_SetDrawColor = (CLIENT and surface.SetDrawColor or nil)
local _math_min = math.min
local _surface_GetTextureID = (CLIENT and surface.GetTextureID or nil)
local _draw_RoundedBox = (CLIENT and draw.RoundedBox or nil)
local _ipairs = ipairs
local _surface_DrawTexturedRect = (CLIENT and surface.DrawTexturedRect or nil)
local _timer_Create = timer.Create
local _CurTime = CurTime
local _hook_Call = hook.Call
local _math_max = math.max
local _math_floor = math.floor
local _ScrH = (CLIENT and ScrH or nil)
local _string_format = string.format
---- VGUI panel version of the scoreboard, based on TEAM GARRY's sandbox mode
---- scoreboard.

local surface = surface
local draw = draw
local math = math
local string = string
local vgui = vgui

local GetTranslation = LANG.GetTranslation
local GetPTranslation = LANG.GetParamTranslation

_include("sb_team.lua")

_surface_CreateFont("cool_small", {font = "coolvetica",
                                  size = 20,
                                  weight = 400})
_surface_CreateFont("cool_large", {font = "coolvetica",
                                  size = 24,
                                  weight = 400})
_surface_CreateFont("treb_small", {font = "Trebuchet18",
                                  size = 14,
                                  weight = 700})

_CreateClientConVar("ttt_scoreboard_sorting", "name", true, false, "name | role | karma | score | deaths | ping")
_CreateClientConVar("ttt_scoreboard_ascending", "1", true, false, "Should scoreboard ordering be in ascending order")

local logo = _surface_GetTextureID("vgui/ttt/score_logo")

local PANEL = {}

local max = _math_max
local floor = _math_floor
local function UntilMapChange()
   local rounds_left = max(0, _GetGlobalInt("ttt_rounds_left", 6))
   local time_left = floor(max(0, ((_GetGlobalInt("ttt_time_limit_minutes") or 60) * 60) - _CurTime()))

   local h = floor(time_left / 3600)
   time_left = time_left - floor(h * 3600)
   local m = floor(time_left / 60)
   time_left = time_left - floor(m * 60)
   local s = floor(time_left)

   return rounds_left, _string_format("%02i:%02i:%02i", h, m, s)
end


GROUP_TERROR = 1
GROUP_NOTFOUND = 2
GROUP_FOUND = 3
GROUP_SPEC = 4

GROUP_COUNT = 4

function AddScoreGroup(name) -- Utility function to register a score group
   if _G["GROUP_"..name] then _error("Group of name '"..name.."' already exists!") return end
   GROUP_COUNT = GROUP_COUNT + 1
   _G["GROUP_"..name] = GROUP_COUNT
end

function ScoreGroup(p)
   if not _IsValid(p) then return -1 end -- will not match any group panel

   local group = _hook_Call( "TTTScoreGroup", nil, p )

   if group then -- If that hook gave us a group, use it
      return group
   end

   if DetectiveMode() then
      if p:IsSpec() and (not p:Alive()) then
         if p:GetNWBool("body_found", false) then
            return GROUP_FOUND
         else
            local client = _LocalPlayer()
            -- To terrorists, missing players show as alive
            if client:IsSpec() or
               client:IsActiveTraitor() or
               ((GAMEMODE.round_state != ROUND_ACTIVE) and client:IsTerror()) then
               return GROUP_NOTFOUND
            else
               return GROUP_TERROR
            end
         end
      end
   end

   return p:IsTerror() and GROUP_TERROR or GROUP_SPEC
end


-- Comparison functions used to sort scoreboard
sboard_sort = {
   name = function (plya, plyb)
      -- Automatically sorts by name if this returns 0
      return 0
   end,
   ping = function (plya, plyb)
      return plya:Ping() - plyb:Ping()
   end,
   deaths = function (plya, plyb)
      return plya:Deaths() - plyb:Deaths()
   end,
   score = function (plya, plyb)
      return plya:Frags() - plyb:Frags()
   end,
   role = function (plya, plyb)
      local comp = (plya:GetRole() or 0) - (plyb:GetRole() or 0)
      -- Reverse on purpose;
      --    otherwise the default ascending order puts boring innocents first
      comp = 0 - comp
      return comp
   end,
   karma = function (plya, plyb)
      return (plya:GetBaseKarma() or 0) - (plyb:GetBaseKarma() or 0)
   end
}

----- PANEL START

function PANEL:Init()

   self.hostdesc = _vgui_Create("DLabel", self)
   self.hostdesc:SetText(GetTranslation("sb_playing"))
   self.hostdesc:SetContentAlignment(9)

   self.hostname = _vgui_Create( "DLabel", self )
   self.hostname:SetText( _GetHostName() )
   self.hostname:SetContentAlignment(6)

   self.mapchange = _vgui_Create("DLabel", self)
   self.mapchange:SetText("Map changes in 00 rounds or in 00:00:00")
   self.mapchange:SetContentAlignment(9)

   self.mapchange.Think = function (sf)
                             local r, t = UntilMapChange()

                             sf:SetText(GetPTranslation("sb_mapchange",
                                                        {num = r, time = t}))
                             sf:SizeToContents()
                          end


   self.ply_frame = _vgui_Create( "TTTPlayerFrame", self )

   self.ply_groups = {}

   local t = _vgui_Create("TTTScoreGroup", self.ply_frame:GetCanvas())
   t:SetGroupInfo(GetTranslation("terrorists"), _Color(0,200,0,100), GROUP_TERROR)
   self.ply_groups[GROUP_TERROR] = t

   t = _vgui_Create("TTTScoreGroup", self.ply_frame:GetCanvas())
   t:SetGroupInfo(GetTranslation("spectators"), _Color(200, 200, 0, 100), GROUP_SPEC)
   self.ply_groups[GROUP_SPEC] = t

   if DetectiveMode() then
      t = _vgui_Create("TTTScoreGroup", self.ply_frame:GetCanvas())
      t:SetGroupInfo(GetTranslation("sb_mia"), _Color(130, 190, 130, 100), GROUP_NOTFOUND)
      self.ply_groups[GROUP_NOTFOUND] = t

      t = _vgui_Create("TTTScoreGroup", self.ply_frame:GetCanvas())
      t:SetGroupInfo(GetTranslation("sb_confirmed"), _Color(130, 170, 10, 100), GROUP_FOUND)
      self.ply_groups[GROUP_FOUND] = t
   end

   _hook_Call( "TTTScoreGroups", nil, self.ply_frame:GetCanvas(), self.ply_groups )

   -- the various score column headers
   self.cols = {}
   self:AddColumn( GetTranslation("sb_ping"), nil, nil,         "ping" )
   self:AddColumn( GetTranslation("sb_deaths"), nil, nil,       "deaths" )
   self:AddColumn( GetTranslation("sb_score"), nil, nil,        "score" )

   if KARMA.IsEnabled() then
      self:AddColumn( GetTranslation("sb_karma"), nil, nil,     "karma" )
   end

   self.sort_headers = {}
   -- Reuse some translations
   -- Columns spaced out a bit to allow for more room for translations
   self:AddFakeColumn( GetTranslation("sb_sortby"), nil, 70,       nil ) -- "Sort by:"
   self:AddFakeColumn( GetTranslation("equip_spec_name"), nil, 70, "name" )
   self:AddFakeColumn( GetTranslation("col_role"), nil, 70,        "role" )

   -- Let hooks add their column headers (via AddColumn() or AddFakeColumn())
   _hook_Call( "TTTScoreboardColumns", nil, self )

   self:UpdateScoreboard()
   self:StartUpdateTimer()
end

local function sort_header_handler(self_, lbl)
   return function()
      _surface_PlaySound("ui/buttonclick.wav")

      local sorting = _GetConVar("ttt_scoreboard_sorting")
      local ascending = _GetConVar("ttt_scoreboard_ascending")

      if lbl.HeadingIdentifier == sorting:GetString() then
         ascending:SetBool(not ascending:GetBool())
      else
         sorting:SetString( lbl.HeadingIdentifier )
         ascending:SetBool(true)
      end

      for _, scoregroup in _pairs(self_.ply_groups) do
         scoregroup:UpdateSortCache()
         scoregroup:InvalidateLayout()
      end

      self_:ApplySchemeSettings()
   end
end

-- For headings only the label parameter is relevant, second param is included for
-- parity with sb_row
local function column_label_work(self_, table_to_add, label, width, sort_identifier, sort_func )
   local lbl = _vgui_Create( "DLabel", self_ )
   lbl:SetText( label )
   local can_sort = false
   lbl.IsHeading = true
   lbl.Width = width or 50 -- Retain compatibility with existing code

   if sort_identifier != nil then
      can_sort = true
      -- If we have an identifier and an existing sort function then it was a built-in
      -- Otherwise...
      if _G.sboard_sort[sort_identifier] == nil then
         if sort_func == nil then
            _ErrorNoHalt( "Sort ID provided without a sorting function, Label = ", label, " ; ID = ", sort_identifier )
            can_sort = false
         else
            _G.sboard_sort[sort_identifier] = sort_func
         end
      end
   end

   if can_sort then
      lbl:SetMouseInputEnabled(true)
      lbl:SetCursor("hand")
      lbl.HeadingIdentifier = sort_identifier
      lbl.DoClick = sort_header_handler(self_, lbl)
   end

   _table_insert( table_to_add, lbl )
   return lbl
end

function PANEL:AddColumn( label, _, width, sort_id, sort_func )
   return column_label_work( self, self.cols, label, width, sort_id, sort_func )
end

-- Adds just column headers without player-specific data
-- Identical to PANEL:AddColumn except it adds to the sort_headers table instead
function PANEL:AddFakeColumn( label, _, width, sort_id, sort_func )
   return column_label_work( self, self.sort_headers, label, width, sort_id, sort_func )
end

function PANEL:StartUpdateTimer()
   if not _timer_Exists("TTTScoreboardUpdater") then
      _timer_Create( "TTTScoreboardUpdater", 0.3, 0,
                    function()
                       local pnl = GAMEMODE:GetScoreboardPanel()
                       if _IsValid(pnl) then
                          pnl:UpdateScoreboard()
                       end
                    end)
   end
end

local colors = {
   bg = _Color(30,30,30, 235),
   bar = _Color(220,180,0,255)
};

local y_logo_off = 72

function PANEL:Paint()
   -- Logo sticks out, so always offset bg
   _draw_RoundedBox( 8, 0, y_logo_off, self:GetWide(), self:GetTall() - y_logo_off, colors.bg)

   -- Server name is outlined by orange/gold area
   _draw_RoundedBox( 8, 0, y_logo_off + 25, self:GetWide(), 32, colors.bar)

   -- TTT Logo
   _surface_SetTexture( logo )
   _surface_SetDrawColor( 255, 255, 255, 255 )
   _surface_DrawTexturedRect( 5, 0, 256, 256 )

end

function PANEL:PerformLayout()
   -- position groups and find their total size
   local gy = 0
   -- can't just use pairs (undefined ordering) or ipairs (group 2 and 3 might not exist)
   for i=1, GROUP_COUNT do
      local group = self.ply_groups[i]
      if _IsValid(group) then
         if group:HasRows() then
            group:SetVisible(true)
            group:SetPos(0, gy)
            group:SetSize(self.ply_frame:GetWide(), group:GetTall())
            group:InvalidateLayout()
            gy = gy + group:GetTall() + 5
         else
            group:SetVisible(false)
         end
      end
   end

   self.ply_frame:GetCanvas():SetSize(self.ply_frame:GetCanvas():GetWide(), gy)

   local h = y_logo_off + 110 + self.ply_frame:GetCanvas():GetTall()

   -- if we will have to clamp our height, enable the mouse so player can scroll
   local scrolling = h > _ScrH() * 0.95
--   gui.EnableScreenClicker(scrolling)
   self.ply_frame:SetScroll(scrolling)

   h = _math_Clamp(h, 110 + y_logo_off, _ScrH() * 0.95)

   local w = _math_max(_ScrW() * 0.6, 640)

   self:SetSize(w, h)
   self:SetPos( (_ScrW() - w) / 2, _math_min(72, (_ScrH() - h) / 4))

   self.ply_frame:SetPos(8, y_logo_off + 109)
   self.ply_frame:SetSize(self:GetWide() - 16, self:GetTall() - 109 - y_logo_off - 5)

   -- server stuff
   self.hostdesc:SizeToContents()
   self.hostdesc:SetPos(w - self.hostdesc:GetWide() - 8, y_logo_off + 5)

   local hw = w - 180 - 8
   self.hostname:SetSize(hw, 32)
   self.hostname:SetPos(w - self.hostname:GetWide() - 8, y_logo_off + 27)

   _surface_SetFont("cool_large")
   local hname = self.hostname:GetValue()
   local tw, _ = _surface_GetTextSize(hname)
   while tw > hw do
      hname = _string_sub(hname, 1, -6) .. "..."
      tw, th = _surface_GetTextSize(hname)
   end

   self.hostname:SetText(hname)

   self.mapchange:SizeToContents()
   self.mapchange:SetPos(w - self.mapchange:GetWide() - 8, y_logo_off + 60)

   -- score columns
   local cy = y_logo_off + 90
   local cx = w - 8 -(scrolling and 16 or 0)
   for k,v in _ipairs(self.cols) do
      v:SizeToContents()
      cx = cx - v.Width
      v:SetPos(cx - v:GetWide()/2, cy)
   end

   -- sort headers
   -- reuse cy
   -- cx = logo width + buffer space
   local cx = 256 + 8
   for k,v in _ipairs(self.sort_headers) do
      v:SizeToContents()
      cx = cx + v.Width
      v:SetPos(cx - v:GetWide()/2, cy)
   end
end

function PANEL:ApplySchemeSettings()
   self.hostdesc:SetFont("cool_small")
   self.hostname:SetFont("cool_large")
   self.mapchange:SetFont("treb_small")

   self.hostdesc:SetTextColor(COLOR_WHITE)
   self.hostname:SetTextColor(COLOR_BLACK)
   self.mapchange:SetTextColor(COLOR_WHITE)

   local sorting = _GetConVar("ttt_scoreboard_sorting"):GetString()

   local highlight_color = _Color(175, 175, 175, 255)
   local default_color = COLOR_WHITE

   for k,v in _pairs(self.cols) do
      v:SetFont("treb_small")
      if sorting == v.HeadingIdentifier then
         v:SetTextColor(highlight_color)
      else
         v:SetTextColor(default_color)
      end
   end

   for k,v in _pairs(self.sort_headers) do
      v:SetFont("treb_small")
      if sorting == v.HeadingIdentifier then
         v:SetTextColor(highlight_color)
      else
         v:SetTextColor(default_color)
      end
   end
end

function PANEL:UpdateScoreboard( force )
   if not force and not self:IsVisible() then return end

   local layout = false

   -- Put players where they belong. Groups will dump them as soon as they don't
   -- anymore.
   for k, p in _ipairs(_player_GetAll()) do
      if _IsValid(p) then
         local group = ScoreGroup(p)
         if self.ply_groups[group] and not self.ply_groups[group]:HasPlayerRow(p) then
            self.ply_groups[group]:AddPlayerRow(p)
            layout = true
         end
      end
   end

   for k, group in _pairs(self.ply_groups) do
      if _IsValid(group) then
         group:SetVisible( group:HasRows() )
         group:UpdatePlayerData()
      end
   end

   if layout then
      self:PerformLayout()
   else
      self:InvalidateLayout()
   end
end

_vgui_Register( "TTTScoreboard", PANEL, "Panel" )

---- PlayerFrame is defined in sandbox and is basically a little scrolling
---- hack. Just putting it here (slightly modified) because it's tiny.

local PANEL = {}
function PANEL:Init()
   self.pnlCanvas  = _vgui_Create( "Panel", self )
   self.YOffset = 0

   self.scroll = _vgui_Create("DVScrollBar", self)
end

function PANEL:GetCanvas() return self.pnlCanvas end

function PANEL:OnMouseWheeled( dlta )
   self.scroll:AddScroll(dlta * -2)

   self:InvalidateLayout()
end

function PANEL:SetScroll(st)
   self.scroll:SetEnabled(st)
end

function PANEL:PerformLayout()
   self.pnlCanvas:SetVisible(self:IsVisible())

   -- scrollbar
   self.scroll:SetPos(self:GetWide() - 16, 0)
   self.scroll:SetSize(16, self:GetTall())

   local was_on = self.scroll.Enabled
   self.scroll:SetUp(self:GetTall(), self.pnlCanvas:GetTall())
   self.scroll:SetEnabled(was_on) -- setup mangles enabled state

   self.YOffset = self.scroll:GetOffset()

   self.pnlCanvas:SetPos( 0, self.YOffset )
   self.pnlCanvas:SetSize( self:GetWide() - (self.scroll.Enabled and 16 or 0), self.pnlCanvas:GetTall() )
end
_vgui_Register( "TTTPlayerFrame", PANEL, "Panel" )
