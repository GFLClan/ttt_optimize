local _vgui_Create = (CLIENT and vgui.Create or nil)
local _surface_GetTextSize = (CLIENT and surface.GetTextSize or nil)
local _file_IsDir = file.IsDir
local _math_Round = math.Round
local _string_upper = string.upper
local _surface_SetFont = (CLIENT and surface.SetFont or nil)
local _util_Decompress = util.Decompress
local _net_ReadUInt = net.ReadUInt
local _string_rep = string.rep
local _table_insert = table.insert
local _timer_Simple = timer.Simple
local _ScrW = (CLIENT and ScrW or nil)
local _net_ReadData = net.ReadData
local _util_JSONToTable = util.JSONToTable
local _math_randomseed = math.randomseed
local _surface_CreateFont = (CLIENT and surface.CreateFont or nil)
local _table_sort = table.sort
local _Material = Material
local _error = error
local _isstring = isstring
local _istable = istable
local _pairs = pairs
local _file_Write = file.Write
local _IsValid = IsValid
local _include = include
local _Color = Color
local _file_CreateDir = file.CreateDir
local _draw_RoundedBox = (CLIENT and draw.RoundedBox or nil)
local _table_SortByMember = table.SortByMember
local _concommand_Add = concommand.Add
local _net_Receive = net.Receive
local _TypeID = TypeID
local _ErrorNoHalt = ErrorNoHalt
local _tonumber = tonumber
local _math_max = math.max
local _table_Count = table.Count
local _ScrH = (CLIENT and ScrH or nil)
local _isnumber = isnumber
local _string_format = string.format
-- Game report

_include("cl_awards.lua")

local table = table
local string = string
local vgui = vgui
local pairs = _pairs

CLSCORE = {}
CLSCORE.Events = {}
CLSCORE.Scores = {}
CLSCORE.TraitorIDs = {}
CLSCORE.DetectiveIDs = {}
CLSCORE.Players = {}
CLSCORE.StartTime = 0
CLSCORE.Panel = nil

CLSCORE.EventDisplay = {}

_include("scoring_shd.lua")

local skull_icon = _Material("HUD/killicons/default")

_surface_CreateFont("WinHuge", {
   font = "Trebuchet24",
   size = 72,
   weight = 1000,
   shadow = true,
   extended = true
})

-- so much text here I'm using shorter names than usual
local T = LANG.GetTranslation
local PT = LANG.GetParamTranslation

function CLSCORE:GetDisplay(key, event)
   local displayfns = self.EventDisplay[event.id]
   if not displayfns then return end
   local keyfn = displayfns[key]
   if not keyfn then return end

   return keyfn(event)
end

function CLSCORE:TextForEvent(e)
   return self:GetDisplay("text", e)
end

function CLSCORE:IconForEvent(e)
   return self:GetDisplay("icon", e)
end

function CLSCORE:TimeForEvent(e)
   local t = e.t - self.StartTime
   if t >= 0 then
      return util.SimpleTime(t, "%02i:%02i")
   else
      return "     "
   end
end

-- Tell CLSCORE how to display an event. See cl_scoring_events for examples.
-- Pass an empty table to keep an event from showing up.
function CLSCORE.DeclareEventDisplay(event_id, event_fns)
   -- basic input vetting, can't check returned value types because the
   -- functions may be impure
   if not _tonumber(event_id) then
      _error("Event ??? display: invalid event id", 2)
   end
   if not _istable(event_fns) then
      _error(_string_format("Event %d display: no display functions found.", event_id), 2)
   end
   if not event_fns.text then
      _error(_string_format("Event %d display: no text display function found.", event_id), 2)
   end
   if not event_fns.icon then
      _error(_string_format("Event %d display: no icon and tooltip display function found.", event_id), 2)
   end

   CLSCORE.EventDisplay[event_id] = event_fns
end

function CLSCORE:FillDList(dlst)
   local events = self.Events

   for i = 1, #events do
      local e = events[i]
      local etxt = self:TextForEvent(e)
      local eicon, ttip = self:IconForEvent(e)
      local etime = self:TimeForEvent(e)

      if etxt then
         if eicon then
            local mat = eicon
            eicon = _vgui_Create("DImage")
            eicon:SetMaterial(mat)
            eicon:SetTooltip(ttip)
            eicon:SetKeepAspect(true)
            eicon:SizeToContents()
         end

         dlst:AddLine(etime, eicon, "  " .. etxt)
      end
   end
end

function CLSCORE:BuildEventLogPanel(dpanel)
   local margin = 10

   local w, h = dpanel:GetSize()

   local dlist = _vgui_Create("DListView", dpanel)
   dlist:SetPos(0, 0)
   dlist:SetSize(w, h - margin*2)
   dlist:SetSortable(true)
   dlist:SetMultiSelect(false)

   local timecol = dlist:AddColumn(T("col_time"))
   local iconcol = dlist:AddColumn("")
   local eventcol = dlist:AddColumn(T("col_event"))

   iconcol:SetFixedWidth(16)
   timecol:SetFixedWidth(40)

   -- If sortable is off, no background is drawn for the headers which looks
   -- terrible. So enable it, but disable the actual use of sorting.
   iconcol.Header:SetDisabled(true)
   timecol.Header:SetDisabled(true)
   eventcol.Header:SetDisabled(true)

   self:FillDList(dlist)
end

CLSCORE.ScorePanelNames = {
   "",
   "col_player",
   "col_role",
   "col_kills1",
   "col_kills2",
   "col_points",
   "col_team",
   "col_total"
}

CLSCORE.ScorePanelColor = _Color(150, 50, 50)

function CLSCORE:BuildScorePanel(dpanel)
   local margin = 10
   local w, h = dpanel:GetSize()

   local dlist = _vgui_Create("DListView", dpanel)
   dlist:SetPos(0, 0)
   dlist:SetSize(w, h)
   dlist:SetSortable(true)
   dlist:SetMultiSelect(false)

   local scorenames = self.ScorePanelNames

   for i = 1, #scorenames do
      local name = scorenames[i]
     
      if _isstring(name) then
         if name == "" then
            -- skull icon column
            local c = dlist:AddColumn("")
            c:SetFixedWidth(18)
         else
            dlist:AddColumn(T(name))
         end
      end
   end

   -- the type of win condition triggered is relevant for team bonus
   local wintype = WIN_NONE
   local events = self.Events

   for i = #events, 1, -1 do
      local e = self.Events[i]
      if e.id == EVENT_FINISH then
         wintype = e.win
         break
      end
   end

   local scores = self.Scores
   local nicks = self.Players
   local bonus = ScoreTeamBonus(scores, wintype)

   for id, s in pairs(scores) do
      if id != -1 then
         local was_traitor = s.was_traitor
         local role = was_traitor and T("traitor") or (s.was_detective and T("detective") or "")

         local surv = ""
         if s.deaths > 0 then
            surv = _vgui_Create("ColoredBox", dlist)
            surv:SetColor(self.ScorePanelColor)
            surv:SetBorder(false)
            surv:SetSize(18,18)

            local skull = _vgui_Create("DImage", surv)
            skull:SetMaterial(skull_icon)
            skull:SetTooltip("Dead")
            skull:SetKeepAspect(true)
            skull:SetSize(18,18)
         end

         local points_own   = KillsToPoints(s, was_traitor)
         local points_team  = (was_traitor and bonus.traitors or bonus.innos)
         local points_total = points_own + points_team

         local l = dlist:AddLine(surv, nicks[id], role, s.innos, s.traitors, points_own, points_team, points_total)

         -- center align
         for k, col in pairs(l.Columns) do
            col:SetContentAlignment(5)
         end

         -- when sorting on the column showing survival, we would get an error
         -- because images can't be sorted, so instead hack in a dummy value
         local surv_col = l.Columns[1]
         if surv_col then
            surv_col.Value = _TypeID(surv_col.Value) == TYPE_PANEL and "1" or "0"
         end
      end
   end

   dlist:SortByColumn(6)
end

function CLSCORE:AddAward(y, pw, award, dpanel)
   local nick = award.nick
   local text = award.text
   local title = _string_upper(award.title)

   local titlelbl = _vgui_Create("DLabel", dpanel)
   titlelbl:SetText(title)
   titlelbl:SetFont("TabLarge")
   titlelbl:SizeToContents()
   local tiw, tih = titlelbl:GetSize()

   local nicklbl = _vgui_Create("DLabel", dpanel)
   nicklbl:SetText(nick)
   nicklbl:SetFont("DermaDefaultBold")
   nicklbl:SizeToContents()
   local nw, nh = nicklbl:GetSize()

   local txtlbl = _vgui_Create("DLabel", dpanel)
   txtlbl:SetText(text)
   txtlbl:SetFont("DermaDefault")
   txtlbl:SizeToContents()
   local tw, th = txtlbl:GetSize()

   titlelbl:SetPos((pw - tiw) / 2, y)
   y = y + tih + 2

   local fw = nw + tw + 5
   local fx = ((pw - fw) / 2)
   nicklbl:SetPos(fx, y)
   txtlbl:SetPos(fx + nw + 5, y)

   y = y + nh

   return y
end

-- double check that we have no nils
local function ValidAward(a)
   return _istable(a) and _isstring(a.nick) and _isstring(a.text) and _isstring(a.title) and _isnumber(a.priority)
end

CLSCORE.WinTypes = {
   [WIN_INNOCENT] = {
      Text = "hilite_win_innocent",
      BoxColor = _Color(5, 190, 5, 255),
      TextColor = COLOR_WHITE,
      BackgroundColor = _Color(50, 50, 50, 255)
   },
   [WIN_TRAITOR] = {
      Text = "hilite_win_traitors",
      BoxColor = _Color(190, 5, 5, 255),
      TextColor = COLOR_WHITE,
      BackgroundColor = _Color(50, 50, 50, 255)
   }
}

-- when win is due to timeout, innocents win
CLSCORE.WinTypes[WIN_TIMELIMIT] = CLSCORE.WinTypes[WIN_INNOCENT]

-- The default wintype if no EVENT_FINISH is specified
CLSCORE.WinTypes.Default = CLSCORE.WinTypes[WIN_INNOCENT]

function CLSCORE:BuildHilitePanel(dpanel, title, starttime, endtime)
   local w, h = dpanel:GetSize()

   local numply = _table_Count(self.Players)
   local numtr = _table_Count(self.TraitorIDs)


   local bg = _vgui_Create("ColoredBox", dpanel)
   bg:SetColor(title.BackgroundColor or self.WinTypes.Default.BackgroundColor)
   bg:SetSize(w,h)
   bg:SetPos(0,0)

   local winlbl = _vgui_Create("DLabel", dpanel)
   winlbl:SetFont("WinHuge")
   winlbl:SetText( T(title.Text or self.WinTypes.Default.Text) )
   winlbl:SetTextColor(title.TextColor or self.WinTypes.Default.TextColor)
   winlbl:SizeToContents()
   local xwin = (w - winlbl:GetWide())/2
   local ywin = 30
   winlbl:SetPos(xwin, ywin)

   bg.PaintOver = function()
      _draw_RoundedBox(8, xwin - 15, ywin - 5, winlbl:GetWide() + 30, winlbl:GetTall() + 10, title.BoxColor or self.WinTypes.Default.BoxColor)
   end

   local ysubwin = ywin + winlbl:GetTall()
   local partlbl = _vgui_Create("DLabel", dpanel)

   local plytxt = PT(numtr == 1 and "hilite_players2" or "hilite_players1",
                     {numplayers = numply, numtraitors = numtr})

   partlbl:SetText(plytxt)
   partlbl:SizeToContents()
   partlbl:SetPos(xwin, ysubwin + 8)

   local timelbl = _vgui_Create("DLabel", dpanel)
   timelbl:SetText(PT("hilite_duration", {time= util.SimpleTime(endtime - starttime, "%02i:%02i")}))
   timelbl:SizeToContents()
   timelbl:SetPos(xwin + winlbl:GetWide() - timelbl:GetWide(), ysubwin + 8)

   -- Awards
   local wa = _math_Round(w * 0.9)
   local ha = h - ysubwin - 40
   local xa = (w - wa) / 2
   local ya = h - ha

   local awardp = _vgui_Create("DPanel", dpanel)
   awardp:SetSize(wa, ha)
   awardp:SetPos(xa, ya)
   awardp:SetPaintBackground(false)

   -- Before we pick awards, seed the rng in a way that is the same on all
   -- clients. We can do this using the round start time. To make it a bit more
   -- random, involve the round's duration too.
   _math_randomseed(starttime + endtime)

   -- Attempt to generate every award, then sort the succeeded ones based on
   -- priority/interestingness
   local award_choices = {}
   for k, afn in pairs(AWARDS) do
      local a = afn(self.Events, self.Scores, self.Players, self.TraitorIDs, self.DetectiveIDs)
      if ValidAward(a) then
         _table_insert(award_choices, a)
      end
   end

   local num_choices = _table_Count(award_choices)
   local max_awards = 5

   -- sort descending by priority
   _table_SortByMember(award_choices, "priority")

   -- put the N most interesting awards in the menu
   for i=1,max_awards do
      local a = award_choices[i]
      if a then
         self:AddAward((i - 1) * 42, wa, a, awardp)
      end
   end
end

function CLSCORE:ShowPanel()
   if _IsValid(self.Panel) then
      self:ClearPanel()
   end

   local margin = 15

   local dpanel = _vgui_Create("DFrame")

   local title = self.WinTypes.Default
   local starttime = self.StartTime
   local endtime = starttime
   local events = self.Events

   for i = #events, 1, -1 do
      local e = events[i]
      if e.id == EVENT_FINISH then
         endtime = e.t
         title = self.WinTypes[e.win]
         break
      end
   end

   -- size the panel based on the win text w/ 88px horizontal padding and 44px veritcal padding
   _surface_SetFont("WinHuge")
   local w, h = _surface_GetTextSize( T(title.Text or self.WinTypes.Default.Text) )

   -- w + DPropertySheet padding (8) + winlbl padding (30) + offset margin (margin * 2) + size margin (margin)
   w, h = _math_max(700, w + 38 + margin * 3), 500

   dpanel:SetSize(w, h)
   dpanel:Center()
   dpanel:SetTitle(T("report_title"))
   dpanel:SetVisible(true)
   dpanel:ShowCloseButton(true)
   dpanel:SetMouseInputEnabled(true)
   dpanel:SetKeyboardInputEnabled(true)
   dpanel.OnKeyCodePressed = util.BasicKeyHandler

   -- keep it around so we can reopen easily
   dpanel:SetDeleteOnClose(false)
   self.Panel = dpanel

   local dbut = _vgui_Create("DButton", dpanel)
   local bw, bh = 100, 25
   dbut:SetSize(bw, bh)
   dbut:SetPos(w - bw - margin, h - bh - margin/2)
   dbut:SetText(T("close"))
   dbut.DoClick = function() dpanel:Close() end

   local dsave = _vgui_Create("DButton", dpanel)
   dsave:SetSize(bw,bh)
   dsave:SetPos(margin, h - bh - margin/2)
   dsave:SetText(T("report_save"))
   dsave:SetTooltip(T("report_save_tip"))
   dsave:SetConsoleCommand("ttt_save_events")

   local dtabsheet = _vgui_Create("DPropertySheet", dpanel)
   dtabsheet:SetPos(margin, margin + 15)
   dtabsheet:SetSize(w - margin*2, h - margin*3 - bh)
   local padding = dtabsheet:GetPadding()


   -- Highlight tab
   local dtabhilite = _vgui_Create("DPanel", dtabsheet)
   dtabhilite:SetPaintBackground(false)
   dtabhilite:StretchToParent(padding,padding,padding,padding)
   self:BuildHilitePanel(dtabhilite, title, starttime, endtime)

   dtabsheet:AddSheet(T("report_tab_hilite"), dtabhilite, "icon16/star.png", false, false, T("report_tab_hilite_tip"))

   -- Event log tab
   local dtabevents = _vgui_Create("DPanel", dtabsheet)
--   dtab1:SetSize(650, 450)
   dtabevents:StretchToParent(padding, padding, padding, padding)
   self:BuildEventLogPanel(dtabevents)

   dtabsheet:AddSheet(T("report_tab_events"), dtabevents, "icon16/application_view_detail.png", false, false, T("report_tab_events_tip"))

   -- Score tab
   local dtabscores = _vgui_Create("DPanel", dtabsheet)
   dtabscores:SetPaintBackground(false)
   dtabscores:StretchToParent(padding, padding, padding, padding)
   self:BuildScorePanel(dtabscores)

   dtabsheet:AddSheet(T("report_tab_scores"), dtabscores, "icon16/user.png", false, false, T("report_tab_scores_tip"))

   dpanel:MakePopup()

   -- makepopup grabs keyboard, whereas we only need mouse
   dpanel:SetKeyboardInputEnabled(false)
end

function CLSCORE:ClearPanel()

   if _IsValid(self.Panel) then
      -- move the mouse off any tooltips and then remove the panel next tick

      -- we need this hack as opposed to just calling Remove because gmod does
      -- not offer a means of killing the tooltip, and doesn't clean it up
      -- properly on Remove
      input.SetCursorPos( _ScrW()/2, _ScrH()/2 )
      local pnl = self.Panel
      _timer_Simple(0, function() if _IsValid(pnl) then pnl:Remove() end end)
   end
end

function CLSCORE:SaveLog()
   local events = self.Events

   if events == nil or #events == 0 then
      chat.AddText(COLOR_WHITE, T("report_save_error"))
      return
   end

   local logdir = "ttt/logs"
   if not _file_IsDir(logdir, "DATA") then
      _file_CreateDir(logdir)
   end

   local logname = logdir .. "/ttt_events_" .. os.time() .. ".txt"
   local log = "Trouble in Terrorist Town - Round Events Log\n".. _string_rep("-", 50) .."\n"

   log = log .. _string_format("%s | %-25s | %s\n", " TIME", "TYPE", "WHAT HAPPENED") .. _string_rep("-", 50) .."\n"

   for i = 1, #events do
      local e = events[i]
      local etxt = self:TextForEvent(e)
      local etime = self:TimeForEvent(e)
      local _, etype = self:IconForEvent(e)
      if etxt then
         log = log .. _string_format("%s | %-25s | %s\n", etime, etype, etxt)
      end
   end

   _file_Write(logname, log)

   chat.AddText(COLOR_WHITE, T("report_save_result"), COLOR_GREEN, " /garrysmod/data/" .. logname)
end

function CLSCORE:Reset()
   self.Events = {}
   self.TraitorIDs = {}
   self.DetectiveIDs = {}
   self.Scores = {}
   self.Players = {}
   self.RoundStarted = 0

   self:ClearPanel()
end

function CLSCORE:Init(events)
   -- Get start time, traitors, detectives, scores, and nicks
   local starttime = 0
   local traitors, detectives
   local scores, nicks = {}, {}
   
   local game, selected, spawn = false, false, false
   for i = 1, #events do
      local e = events[i]
      if e.id == EVENT_GAME then
         if e.state == ROUND_ACTIVE then
            starttime = e.t

            if selected and spawn then
               break
            end

            game = true
         end
      elseif e.id == EVENT_SELECTED then
         traitors = e.traitor_ids
         detectives = e.detective_ids

         if game and spawn then
            break
         end

         selected = true
      elseif e.id == EVENT_SPAWN then
         scores[e.sid] = ScoreInit()
         nicks[e.sid] = e.ni

         if game and selected then
            break
         end

         spawn = true
      end
   end

   if traitors == nil then traitors = {} end
   if detectives == nil then detectives = {} end

   scores = ScoreEventLog(events, scores, traitors, detectives)

   self.Players = nicks
   self.Scores = scores
   self.TraitorIDs = traitors
   self.DetectiveIDs = detectives
   self.StartTime = starttime
   self.Events = events
end

function CLSCORE:ReportEvents(events)
   self:Reset()

   self:Init(events)
   self:ShowPanel()
end

function CLSCORE:Toggle()
   if _IsValid(self.Panel) then
      self.Panel:ToggleVisible()
   end
end

local function SortEvents(a, b)
   return a.t < b.t
end

local buff = ""
_net_Receive("TTT_ReportStream_Part", function()
   buff = buff .. _net_ReadData(CLSCORE.MaxStreamLength)
end)

_net_Receive("TTT_ReportStream", function()
   local events = _util_Decompress(buff .. _net_ReadData(_net_ReadUInt(16)))
   buff = ""

   if events == "" then
      _ErrorNoHalt("Round report decompression failed!\n")
   end

   events = _util_JSONToTable(events)
   if events == nil then
      _ErrorNoHalt("Round report decoding failed!\n")
   end

   _table_sort(events, SortEvents)
   CLSCORE:ReportEvents(events)
end)

_concommand_Add("ttt_save_events", function()
   CLSCORE:SaveLog()
end)
