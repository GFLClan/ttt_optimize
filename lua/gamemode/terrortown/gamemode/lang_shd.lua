local _IsValid = IsValid
local _net_Start = net.Start
local _file_Find = file.Find
local _string_Right = string.Right
local _string_match = string.match
local _net_Send = (SERVER and net.Send or nil)
local _GetConVarString = GetConVarString
local _net_ReadString = net.ReadString
local _net_WriteString = net.WriteString
local _string_lower = string.lower
local _print = print
local _type = type
local _ipairs = ipairs
local _net_Broadcast = (SERVER and net.Broadcast or nil)
local _net_WriteUInt = net.WriteUInt
local _concommand_Add = concommand.Add
local _net_Receive = net.Receive
local _net_ReadUInt = net.ReadUInt
local _MsgN = MsgN
local _isstring = isstring
local _tostring = tostring
local _table_Count = table.Count
local _pairs = pairs
local _isnumber = isnumber
local _CreateConVar = CreateConVar

---- Shared language stuff

-- tbl is first created here on both server and client
-- could make it a module but meh
if LANG then return end
LANG = {}

util.IncludeClientFile("cl_lang.lua")

-- Add all lua files in our /lang/ dir
local dir = GM.FolderName or "terrortown"
local files = _file_Find(dir .. "/gamemode/lang/*.lua", "LUA" )
for _, fname in _ipairs(files) do
   local path = "lang/" .. fname
   -- filter out directories and temp files (like .lua~)
   if _string_Right(fname, 3) == "lua" then
      util.IncludeClientFile(path)
      _MsgN("Included TTT language file: " .. fname)
   end
end


if SERVER then
   local count = _table_Count

   -- Can be called as:
   --   1) LANG.Msg(ply, name, params)  -- sent to ply
   --   2) LANG.Msg(name, params)       -- sent to all
   --   3) LANG.Msg(role, name, params) -- sent to plys with role
   function LANG.Msg(arg1, arg2, arg3)
      if _isstring(arg1) then
         LANG.ProcessMsg(nil, arg1, arg2)
      elseif _isnumber(arg1) then
         LANG.ProcessMsg(GetRoleFilter(arg1), arg2, arg3)
      else
         LANG.ProcessMsg(arg1, arg2, arg3)
      end
   end

   function LANG.ProcessMsg(send_to, name, params)
      -- don't want to send to null ents, but can't just IsValid send_to because
      -- it may be a recipientfilter, so type check first
      if _type(send_to) == "Player" and (not _IsValid(send_to)) then return end

      -- number of keyval param pairs to send
      local c = params and count(params) or 0

      _net_Start("TTT_LangMsg")
         _net_WriteString(name)

         _net_WriteUInt(c, 8)
         if c > 0 then

            for k, v in _pairs(params) do
               -- assume keys are strings, but vals may be numbers
               _net_WriteString(k)
               _net_WriteString(_tostring(v))
            end
         end

      if send_to then
         _net_Send(send_to)
      else
         _net_Broadcast()
      end
   end

   function LANG.MsgAll(name, params)
      LANG.Msg(nil, name, params)
   end

   _CreateConVar("ttt_lang_serverdefault", "english", FCVAR_ARCHIVE)

   local function ServerLangRequest(ply, cmd, args)
      if not _IsValid(ply) then return end

      _net_Start("TTT_ServerLang")
         _net_WriteString(_GetConVarString("ttt_lang_serverdefault"))
      _net_Send(ply)
   end
   _concommand_Add("_ttt_request_serverlang", ServerLangRequest)

else -- CLIENT

   local function RecvMsg()
      local name = _net_ReadString()

      local c = _net_ReadUInt(8)
      local params = nil
      if c > 0 then
         params = {}
         for i=1, c do
            params[_net_ReadString()] = _net_ReadString()
         end
      end

      LANG.Msg(name, params)
   end
   _net_Receive("TTT_LangMsg", RecvMsg)

   LANG.Msg = LANG.ProcessMsg

   local function RecvServerLang()
      local lang_name = _net_ReadString()
      lang_name = lang_name and _string_lower(lang_name)
      if LANG.Strings[lang_name] then
         if LANG.IsServerDefault(_GetConVarString("ttt_language")) then
            LANG.SetActiveLanguage(lang_name)
         end

         LANG.ServerLanguage = lang_name

         _print("Server default language is:", lang_name)
      end
   end
   _net_Receive("TTT_ServerLang", RecvServerLang)
end

-- It can be useful to send string names as params, that the client can then
-- localize before interpolating. However, we want to prevent user input like
-- nicknames from being localized, so mark string names with something users
-- can't input.
function LANG.NameParam(name)
   return "LID\t" .. name
end
LANG.Param = LANG.NameParam

function LANG.GetNameParam(str)
   return _string_match(str, "^LID\t([%w_]+)$")
end
