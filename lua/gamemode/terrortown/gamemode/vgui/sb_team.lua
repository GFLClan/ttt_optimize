local _IsValid = IsValid
local _surface_SetDrawColor = (CLIENT and surface.SetDrawColor or nil)
local _surface_SetFont = (CLIENT and surface.SetFont or nil)
local _Color = Color
local _surface_DrawText = (CLIENT and surface.DrawText or nil)
local _include = include
local _surface_GetTextSize = (CLIENT and surface.GetTextSize or nil)
local _surface_DrawRect = (CLIENT and surface.DrawRect or nil)
local _GetConVar = GetConVar
local _vgui_Create = (CLIENT and vgui.Create or nil)
local _table_insert = table.insert
local _draw_RoundedBox = (CLIENT and draw.RoundedBox or nil)
local _ipairs = ipairs
local _string_lower = string.lower
local _vgui_Register = (CLIENT and vgui.Register or nil)
local _surface_SetTextPos = (CLIENT and surface.SetTextPos or nil)
local _table_sort = table.sort
local _surface_SetTextColor = (CLIENT and surface.SetTextColor or nil)
local _table_Count = table.Count
local _pairs = pairs
---- Unlike sandbox, we have teams to deal with, so here's an extra panel in the
---- hierarchy that handles a set of player rows belonging to its team.

_include("sb_row.lua")

local PANEL = {}

function PANEL:Init()
   self.name = "Unnamed"

   self.color = COLOR_WHITE

   self.rows = {}
   self.rowcount = 0

   self.rows_sorted = {}

   self.group = "spec"
end

function PANEL:SetGroupInfo(name, color, group)
   self.name = name
   self.color = color
   self.group = group
end

local bgcolor = _Color(20,20,20, 150)
function PANEL:Paint()
   -- Darkened background
   _draw_RoundedBox(8, 0, 0, self:GetWide(), self:GetTall(), bgcolor)

   _surface_SetFont("treb_small")

   -- Header bg
   local txt = self.name .. " (" .. self.rowcount .. ")"
   local w, h = _surface_GetTextSize(txt)
   _draw_RoundedBox(8, 0, 0, w + 24, 20, self.color)

   -- Shadow
   _surface_SetTextPos(11, 11 - h/2)
   _surface_SetTextColor(0,0,0, 200)
   _surface_DrawText(txt)

   -- Text
   _surface_SetTextPos(10, 10 - h/2)
   _surface_SetTextColor(255,255,255,255)
   _surface_DrawText(txt)

   -- Alternating row background
   local y = 24
   for i, row in _ipairs(self.rows_sorted) do
      if (i % 2) != 0 then
         _surface_SetDrawColor(75,75,75, 100)
         _surface_DrawRect(0, y, self:GetWide(), row:GetTall())
      end

      y = y + row:GetTall() + 1
   end

   -- Column darkening
   local scr = sboard_panel.ply_frame.scroll.Enabled and 16 or 0
   _surface_SetDrawColor(0,0,0, 80)
   if sboard_panel.cols then
      local cx = self:GetWide() - scr
      for k,v in _ipairs(sboard_panel.cols) do
         cx = cx - v.Width
         if k % 2 == 1 then -- Draw for odd numbered columns
            _surface_DrawRect(cx-v.Width/2, 0, v.Width, self:GetTall())
         end
      end
   else
      -- If columns are not setup yet, fall back to darkening the areas for the
      -- default columns
      _surface_DrawRect(self:GetWide() - 175 - 25 - scr, 0, 50, self:GetTall())
      _surface_DrawRect(self:GetWide() - 75 - 25 - scr, 0, 50, self:GetTall())
   end
end

function PANEL:AddPlayerRow(ply)
   if ScoreGroup(ply) == self.group and not self.rows[ply] then
      local row = _vgui_Create("TTTScorePlayerRow", self)
      row:SetPlayer(ply)
      self.rows[ply] = row
      self.rowcount = _table_Count(self.rows)

      -- must force layout immediately or it takes its sweet time to do so
      self:PerformLayout()
   end
end

function PANEL:HasPlayerRow(ply)
   return self.rows[ply] != nil
end

function PANEL:HasRows()
   return self.rowcount > 0
end

local strlower = _string_lower
function PANEL:UpdateSortCache()
   self.rows_sorted = {}

   for _, row in _pairs(self.rows) do
      _table_insert(self.rows_sorted, row)
   end

   _table_sort(self.rows_sorted, function(rowa, rowb)
      local plya = rowa:GetPlayer()
      local plyb = rowb:GetPlayer()

      if not _IsValid(plya) then return false end
      if not _IsValid(plyb) then return true end

      local sort_mode = _GetConVar("ttt_scoreboard_sorting"):GetString()
      local sort_func = sboard_sort[sort_mode]

      local comp = 0
      if sort_func != nil then
         comp = sort_func(plya, plyb)
      end

      local ret = true

      if comp != 0 then
         ret = comp > 0
      else
         ret = strlower(plya:GetName()) > strlower(plyb:GetName())
      end

      if _GetConVar("ttt_scoreboard_ascending"):GetBool() then
         ret = not ret
      end

      return ret
   end)
end

function PANEL:UpdatePlayerData()
   local to_remove = {}
   for k,v in _pairs(self.rows) do
      -- Player still belongs in this group?
      if _IsValid(v) and _IsValid(v:GetPlayer()) and ScoreGroup(v:GetPlayer()) == self.group then
         v:UpdatePlayerData()
      else
         -- can't remove now, will break pairs
         _table_insert(to_remove, k)
      end
   end

   if #to_remove == 0 then return end

   for k,ply in _pairs(to_remove) do
      local pnl = self.rows[ply]
      if _IsValid(pnl) then
         pnl:Remove()
      end

      self.rows[ply] = nil
   end
   self.rowcount = _table_Count(self.rows)

   self:UpdateSortCache()

   self:InvalidateLayout()
end


function PANEL:PerformLayout()
   if self.rowcount < 1 then
      self:SetVisible(false)
      return
   end

   self:SetSize(self:GetWide(), 30 + self.rowcount + self.rowcount * SB_ROW_HEIGHT)

   -- Sort and layout player rows
   self:UpdateSortCache()

   local y = 24
   for k, v in _ipairs(self.rows_sorted) do
      v:SetPos(0, y)
      v:SetSize(self:GetWide(), v:GetTall())

      y = y + v:GetTall() + 1
   end

   self:SetSize(self:GetWide(), 30 + (y - 24))
end

_vgui_Register("TTTScoreGroup", PANEL, "Panel")
