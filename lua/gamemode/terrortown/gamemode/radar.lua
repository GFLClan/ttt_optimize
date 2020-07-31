local _IsValid = IsValid
local _net_Start = net.Start
local _player_GetAll = player.GetAll
local _net_WriteInt = net.WriteInt
local _table_Add = table.Add
local _CurTime = CurTime
local _math_Round = math.Round
local _net_Send = (SERVER and net.Send or nil)
local _concommand_Add = concommand.Add
local _table_insert = table.insert
local _ipairs = ipairs
local _net_WriteUInt = net.WriteUInt
-- Traitor radar functionality


-- should mirror client
local chargetime = 30

local math = math

local function RadarScan(ply, cmd, args)
   if _IsValid(ply) and ply:IsTerror() then
      if ply:HasEquipmentItem(EQUIP_RADAR) then

         if ply.radar_charge > _CurTime() then
            LANG.Msg(ply, "radar_charging")
            return
         end

         ply.radar_charge =  _CurTime() + chargetime

         local scan_ents = _player_GetAll()
         _table_Add(scan_ents, ents.FindByClass("ttt_decoy"))

         local targets = {}
         for k, p in _ipairs(scan_ents) do
            if ply == p or (not _IsValid(p)) then continue end

            if p:IsPlayer() then
               if not p:IsTerror() then continue end
               if p:GetNWBool("disguised", false) and (not ply:IsTraitor()) then continue end
            end

            local pos = p:LocalToWorld(p:OBBCenter())

            -- Round off, easier to send and inaccuracy does not matter
            pos.x = _math_Round(pos.x)
            pos.y = _math_Round(pos.y)
            pos.z = _math_Round(pos.z)

            local role = p:IsPlayer() and p:GetRole() or -1

            if not p:IsPlayer() then
               -- Decoys appear as innocents for non-traitors
               if not ply:IsTraitor() then
                  role = ROLE_INNOCENT
               end
            elseif role != ROLE_INNOCENT and role != ply:GetRole() then
               -- Detectives/Traitors can see who has their role, but not who
               -- has the opposite role.
               role = ROLE_INNOCENT
            end

            _table_insert(targets, {role=role, pos=pos})
         end

         _net_Start("TTT_Radar")
            _net_WriteUInt(#targets, 8)
            for k, tgt in _ipairs(targets) do
               _net_WriteUInt(tgt.role, 2)

               _net_WriteInt(tgt.pos.x, 32)
               _net_WriteInt(tgt.pos.y, 32)
               _net_WriteInt(tgt.pos.z, 32)
            end
         _net_Send(ply)

      else
         LANG.Msg(ply, "radar_not_owned")
      end
   end
end
_concommand_Add("ttt_radar_scan", RadarScan)
