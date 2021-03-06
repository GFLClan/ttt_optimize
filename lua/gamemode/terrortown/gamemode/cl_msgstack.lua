local _surface_GetTextSize = (CLIENT and surface.GetTextSize or nil)
local _draw_GetFontHeight = (CLIENT and draw.GetFontHeight or nil)
local _surface_SetFont = (CLIENT and surface.SetFont or nil)
local _Color = Color
local _math_Clamp = math.Clamp
local _table_Copy = table.Copy
local _ipairs = ipairs
local _pairs = pairs
local _print = print
local _next = next
local _table_insert = table.insert
local _draw_RoundedBox = (CLIENT and draw.RoundedBox or nil)
local _ScrW = (CLIENT and ScrW or nil)
local _net_Receive = net.Receive
local _net_ReadUInt = net.ReadUInt
local _CurTime = CurTime
local _Sound = Sound
local _string_Explode = string.Explode
local _draw_TextShadow = (CLIENT and draw.TextShadow or nil)
local _net_ReadString = net.ReadString
local _net_ReadBit = net.ReadBit
---- HUD stuff similar to weapon/ammo pickups but for game status messages

-- This is some of the oldest TTT code, and some of the first Lua code I ever
-- wrote. It's not the greatest.

MSTACK = {}

MSTACK.msgs = {}
MSTACK.last = 0

-- Localise some libs
local table = table
local surface = surface
local draw = draw
local pairs = _pairs

-- Constants for configuration
local msgfont = "DefaultBold"

local margin = 6
local msg_width = 400

local text_width = msg_width - (margin * 3) -- three margins for a little more room

local text_height = _draw_GetFontHeight(msgfont)

local top_y = margin
local top_x = _ScrW() - margin - msg_width

local staytime = 12
local max_items = 8

local fadein = 0.1
local fadeout = 0.6

local movespeed = 2

-- Text colors to render the messages in
local msgcolors = {
   traitor_text = COLOR_RED,
   generic_text = COLOR_WHITE,

   generic_bg = _Color(0, 0, 0, 200)
};

-- Total width we take up on screen, for other elements to read
MSTACK.width = msg_width + margin

function MSTACK:AddColoredMessage(text, clr)
   local item = {}
   item.text = text
   item.col = clr
   item.bg  = msgcolors.generic_bg

   self:AddMessageEx(item)
end

function MSTACK:AddColoredBgMessage(text, bg_clr)
   local item = {}
   item.text = text
   item.col  = msgcolors.generic_text
   item.bg   = bg_clr

   self:AddMessageEx(item)
end

-- Internal
function MSTACK:AddMessageEx(item)
   item.col = _table_Copy(item.col or msgcolors.generic_text)
   item.col.a_max = item.col.a

   item.bg  = _table_Copy(item.bg or msgcolors.generic_bg)
   item.bg.a_max = item.bg.a

   item.text = self:WrapText(item.text, text_width)
   -- Height depends on number of lines, which is equal to number of table
   -- elements of the wrapped item.text
   item.height = (#item.text * text_height) + (margin * (1 + #item.text))

   item.time = _CurTime()
   item.sounded = false
   item.move_y = -item.height

   -- Stagger the fading a bit
   if self.last > (item.time - 1) then
      item.time = self.last + 1 --item.time + 1
   end

   -- Insert at the top
   _table_insert(self.msgs, 1, item)

   self.last = item.time
end

-- Add a given message to the stack, will be rendered in a different color if it
-- is a special traitor-only message that traitors should pay attention to.
-- Use the newer AddColoredMessage if you want special colours.
function MSTACK:AddMessage(text, traitor_only)
   self:AddColoredBgMessage(text, traitor_only and msgcolors.traitor_bg or msgcolors.generic_bg)
end

-- Oh joy, I get to write my own wrapping function. Thanks Lua!
-- Splits a string into a table of strings that are under the given width.
function MSTACK:WrapText(text, width)
   _surface_SetFont(msgfont)

   -- Any wrapping required?
   local w, _ = _surface_GetTextSize(text)
   if w <= width then
      return {text} -- Nope, but wrap in table for uniformity
   end
   
   local lines = {""}
   for i, wrd in _ipairs(_string_Explode(" ", text)) do -- No spaces means you're screwed
      local l = #lines
      local added = lines[l] .. " " .. wrd
      w, _ = _surface_GetTextSize(added)

      if w > text_width then
         -- New line needed
         _table_insert(lines, wrd)
      else
         -- Safe to tack it on
         lines[l] = added
      end
   end

   return lines
end

local msg_sound = _Sound("Hud.Hint")
local base_spec = {
   font = msgfont,
   xalign = TEXT_ALIGN_CENTER,
   yalign = TEXT_ALIGN_TOP
};

function MSTACK:Draw(client)
   if _next(self.msgs) == nil then return end -- fast empty check

   local running_y = top_y
   for k, item in pairs(self.msgs) do
      if item.time < _CurTime() then
         if item.sounded == false then
            client:EmitSound(msg_sound, 80, 250)
            item.sounded = true
         end

         -- Apply move effects to y
         local y = running_y + margin + item.move_y

         item.move_y = (item.move_y < 0) and item.move_y + movespeed or 0

         local delta = (item.time + staytime) - _CurTime()
         delta = delta / staytime -- pct of staytime left

         -- Hurry up if we have too many
         if k >= max_items then
            delta = delta / 2
         end

         local alpha = 255
         -- These somewhat arcane delta and alpha equations are from gmod's
         -- HUDPickup stuff
         if delta > 1 - fadein then
            alpha = _math_Clamp( (1.0 - delta) * (255 / fadein), 0, 255)
         elseif delta < fadeout then
            alpha = _math_Clamp( delta * (255 / fadeout), 0, 255)
         end

         local height = item.height

         -- Background box
         item.bg.a = _math_Clamp(alpha, 0, item.bg.a_max)
         _draw_RoundedBox(8, top_x, y, msg_width, height, item.bg)

         -- Text
         item.col.a = _math_Clamp(alpha, 0, item.col.a_max)

         local spec = base_spec
         spec.color = item.col

         for i = 1, #item.text do
            spec.text=item.text[i]

            local tx = top_x + (msg_width / 2)
            local ty = y + margin + (i - 1) * (text_height + margin)
            spec.pos={tx, ty}

            _draw_TextShadow(spec, 1, alpha)
         end

         if alpha == 0 then
            self.msgs[k] = nil
         end

         running_y = y + height
      end
   end
end

-- Game state message channel
local function ReceiveGameMsg()
   local text = _net_ReadString()
   local special = _net_ReadBit() == 1

   _print(text)

   MSTACK:AddMessage(text, special)
end
_net_Receive("TTT_GameMsg", ReceiveGameMsg)

local function ReceiveCustomMsg()
   local text = _net_ReadString()
   local clr = _Color(255, 255, 255)

   clr.r = _net_ReadUInt(8)
   clr.g = _net_ReadUInt(8)
   clr.b = _net_ReadUInt(8)

   _print(text)

   MSTACK:AddColoredMessage(text, clr)
end
_net_Receive("TTT_GameMsgColor", ReceiveCustomMsg)
