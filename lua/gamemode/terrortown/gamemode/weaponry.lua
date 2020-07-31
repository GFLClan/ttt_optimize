local _VectorRand = VectorRand
local _net_Start = net.Start
local _hook_Run = hook.Run
local _tonumber = tonumber
local _math_Clamp = math.Clamp
local _SafeRemoveEntity = SafeRemoveEntity
local _concommand_Add = concommand.Add
local _table_insert = table.insert
local _table_HasValue = table.HasValue
local _net_WriteString = net.WriteString
local _net_Send = (SERVER and net.Send or nil)
local _Entity = Entity
local _timer_Simple = timer.Simple
local _util_TraceEntity = util.TraceEntity
local _ErrorNoHalt = ErrorNoHalt
local _net_WriteUInt = net.WriteUInt
local _timer_Remove = timer.Remove
local _util_PrecacheModel = util.PrecacheModel
local _player_GetAll = player.GetAll
local _GetConVar = GetConVar
local _Vector = Vector
local _istable = istable
local _pairs = pairs
local _timer_Exists = timer.Exists
local _IsValid = IsValid
local _include = include
local _net_WriteBit = net.WriteBit
local _print = print
local _ipairs = ipairs
local _util_QuickTrace = util.QuickTrace
local _timer_Create = timer.Create
local _player_GetBySteamID = player.GetBySteamID
local _MsgN = MsgN
local _hook_Call = hook.Call
local _tostring = tostring
local _string_Explode = string.Explode
local _tobool = tobool
local _CreateConVar = CreateConVar

_include("weaponry_shd.lua") -- inits WEPS tbl

---- Weapon system, pickup limits, etc

local IsEquipment = WEPS.IsEquipment

-- Prevent players from picking up multiple weapons of the same type etc
function GM:PlayerCanPickupWeapon(ply, wep)
   if not _IsValid(wep) or not _IsValid(ply) then return end
   if ply:IsSpec() then return false end

   -- Disallow picking up for ammo
   if ply:HasWeapon(wep:GetClass()) then
      return false
   elseif not ply:CanCarryWeapon(wep) then
      return false
   elseif IsEquipment(wep) and wep.IsDropped and (not ply:KeyDown(IN_USE)) then
      return false
   end

   local tr = _util_TraceEntity({start=wep:GetPos(), endpos=ply:GetShootPos(), mask=MASK_SOLID}, wep)
   if tr.Fraction == 1.0 or tr.Entity == ply then
      wep:SetPos(ply:GetShootPos())
   end

   return true
end

-- Cache role -> default-weapons table
local loadout_weapons = nil
local function GetLoadoutWeapons(r)
   if not loadout_weapons then
      local tbl = {
         [ROLE_INNOCENT] = {},
         [ROLE_TRAITOR]  = {},
         [ROLE_DETECTIVE]= {}
      };

      for k, w in _pairs(weapons.GetList()) do
         if w and _istable(w.InLoadoutFor) then
            for _, wrole in _pairs(w.InLoadoutFor) do
               _table_insert(tbl[wrole], WEPS.GetClass(w))
            end
         end
      end

      loadout_weapons = tbl
   end

   return loadout_weapons[r]
end

-- Give player loadout weapons he should have for his role that he does not have
-- yet
local function GiveLoadoutWeapons(ply)
   local r = GetRoundState() == ROUND_PREP and ROLE_INNOCENT or ply:GetRole()
   local weps = GetLoadoutWeapons(r)
   if not weps then return end

   for _, cls in _pairs(weps) do
      if not ply:HasWeapon(cls) and ply:CanCarryType(WEPS.TypeForWeapon(cls)) then
         ply:Give(cls)
      end
   end
end

local function HasLoadoutWeapons(ply)
   if ply:IsSpec() then return true end

   local r = GetRoundState() == ROUND_PREP and ROLE_INNOCENT or ply:GetRole()
   local weps = GetLoadoutWeapons(r)
   if not weps then return true end


   for _, cls in _pairs(weps) do
      if not ply:HasWeapon(cls) and ply:CanCarryType(WEPS.TypeForWeapon(cls)) then
         return false
      end
   end

   return true
end

-- Give loadout items.
local function GiveLoadoutItems(ply)
   local items = EquipmentItems[ply:GetRole()]
   if items then
      for _, item in _pairs(items) do
         if item.loadout and item.id then
            ply:GiveEquipmentItem(item.id)
         end
      end
   end
end

-- Quick hack to limit hats to models that fit them well
local Hattables = { "phoenix.mdl", "arctic.mdl", "Group01", "monk.mdl" }
local function CanWearHat(ply)
   local path = _string_Explode("/", ply:GetModel())
   if #path == 1 then path = _string_Explode("\\", path) end

   return _table_HasValue(Hattables, path[3])
end

_CreateConVar("ttt_detective_hats", "0")
-- Just hats right now
local function GiveLoadoutSpecial(ply)
   if ply:IsActiveDetective() and _GetConVar("ttt_detective_hats"):GetBool() and CanWearHat(ply) then

      if not _IsValid(ply.hat) then
         local hat = ents.Create("ttt_hat_deerstalker")
         if not _IsValid(hat) then return end

         hat:SetPos(ply:GetPos() + _Vector(0,0,70))
         hat:SetAngles(ply:GetAngles())

         hat:SetParent(ply)

         ply.hat = hat

         hat:Spawn()
      end
   else
      _SafeRemoveEntity(ply.hat)

      ply.hat = nil
   end
end

-- Sometimes, in cramped map locations, giving players weapons fails. A timer
-- calling this function is used to get them the weapons anyway as soon as
-- possible.
local function LateLoadout(id)
   local ply = _Entity(id)
   if not _IsValid(ply) or not ply:IsPlayer() then
      _timer_Remove("lateloadout" .. id)
      return
   end

   if not HasLoadoutWeapons(ply) then
      GiveLoadoutWeapons(ply)

      if HasLoadoutWeapons(ply) then
         _timer_Remove("lateloadout" .. id)
      end
   end
end

-- Note that this is called both when a player spawns and when a round starts
function GM:PlayerLoadout( ply )
   if _IsValid(ply) and (not ply:IsSpec()) then
      -- clear out equipment flags
      ply:ResetEquipment()

      -- give default items
      GiveLoadoutItems(ply)

      -- hand out weaponry
      GiveLoadoutWeapons(ply)

      GiveLoadoutSpecial(ply)

      if not HasLoadoutWeapons(ply) then
         _MsgN("Could not spawn all loadout weapons for " .. ply:Nick() .. ", will retry.")
         _timer_Create("lateloadout" .. ply:EntIndex(), 1, 0,
                      function() LateLoadout(ply:EntIndex()) end)
      end
   end
end

function GM:UpdatePlayerLoadouts()
   for _, ply in _ipairs(_player_GetAll()) do
      _hook_Call("PlayerLoadout", GAMEMODE, ply)
   end
end

---- Weapon dropping

function WEPS.DropNotifiedWeapon(ply, wep, death_drop)
   if _IsValid(ply) and _IsValid(wep) then
      -- Hack to tell the weapon it's about to be dropped and should do what it
      -- must right now
      if wep.PreDrop then
         wep:PreDrop(death_drop)
      end

      -- PreDrop might destroy weapon
      if not _IsValid(wep) then return end

      -- Tag this weapon as dropped, so that if it's a special weapon we do not
      -- auto-pickup when nearby.
      wep.IsDropped = true

      ply:DropWeapon(wep)

      wep:PhysWake()

      -- After dropping a weapon, always switch to holstered, so that traitors
      -- will never accidentally pull out a traitor weapon
      ply:SelectWeapon("weapon_ttt_unarmed")
   end
end

local function DropActiveWeapon(ply)
   if not _IsValid(ply) then return end

   local wep = ply:GetActiveWeapon()

   if not _IsValid(wep) then return end

   if wep.AllowDrop == false then
      return
   end

   local tr = _util_QuickTrace(ply:GetShootPos(), ply:GetAimVector() * 32, ply)

   if tr.HitWorld then
      LANG.Msg(ply, "drop_no_room")
      return
   end

   ply:AnimPerformGesture(ACT_ITEM_PLACE)

   WEPS.DropNotifiedWeapon(ply, wep)
end
_concommand_Add("ttt_dropweapon", DropActiveWeapon)

local function DropActiveAmmo(ply)
   if not _IsValid(ply) then return end

   local wep = ply:GetActiveWeapon()
   if not _IsValid(wep) then return end

   if not wep.AmmoEnt then return end

   local amt = wep:Clip1()
   if amt < 1 or amt <= (wep.Primary.ClipSize * 0.25) then
      LANG.Msg(ply, "drop_no_ammo")
      return
   end

   local pos, ang = ply:GetShootPos(), ply:EyeAngles()
   local dir = (ang:Forward() * 32) + (ang:Right() * 6) + (ang:Up() * -5)

   local tr = _util_QuickTrace(pos, dir, ply)
   if tr.HitWorld then return end

   wep:SetClip1(0)

   ply:AnimPerformGesture(ACT_ITEM_GIVE)

   local box = ents.Create(wep.AmmoEnt)
   if not _IsValid(box) then return end

   box:SetPos(pos + dir)
   box:SetOwner(ply)
   box:Spawn()

   box:PhysWake()

   local phys = box:GetPhysicsObject()
   if _IsValid(phys) then
      phys:ApplyForceCenter(ang:Forward() * 1000)
      phys:ApplyForceOffset(_VectorRand(), vector_origin)
   end

   box.AmmoAmount = amt

   _timer_Simple(2, function()
                      if _IsValid(box) then
                         box:SetOwner(nil)
                      end
                   end)
end
_concommand_Add("ttt_dropammo", DropActiveAmmo)


-- Give a weapon to a player. If the initial attempt fails due to heisenbugs in
-- the map, keep trying until the player has moved to a better spot where it
-- does work.
local function GiveEquipmentWeapon(sid, cls)
   -- Referring to players by SteamID because a player may disconnect while his
   -- unique timer still runs, in which case we want to be able to stop it. For
   -- that we need its name, and hence his SteamID.
   local ply = _player_GetBySteamID(sid)
   local tmr = "give_equipment" .. sid

   if (not _IsValid(ply)) or (not ply:IsActiveSpecial()) then
      _timer_Remove(tmr)
      return
   end

   -- giving attempt, will fail if we're in a crazy spot in the map or perhaps
   -- other glitchy cases
   local w = ply:Give(cls)

   if (not _IsValid(w)) or (not ply:HasWeapon(cls)) then
      if not _timer_Exists(tmr) then
         _timer_Create(tmr, 1, 0, function() GiveEquipmentWeapon(sid, cls) end)
      end

      -- we will be retrying
   else
      -- can stop retrying, if we were
      _timer_Remove(tmr)

      if w.WasBought then
         -- some weapons give extra ammo after being bought, etc
         w:WasBought(ply)
      end
   end
end

local function HasPendingOrder(ply)
   return _timer_Exists("give_equipment" .. _tostring(ply:SteamID()))
end

function GM:TTTCanOrderEquipment(ply, id, is_item)
   --- return true to allow buying of an equipment item, false to disallow
   return true
end

-- Equipment buying
local function OrderEquipment(ply, cmd, args)
   if not _IsValid(ply) or #args != 1 then return end

   if not (ply:IsActiveTraitor() or ply:IsActiveDetective()) then return end

   -- no credits, can't happen when buying through menu as button will be off
   if ply:GetCredits() < 1 then return end

   -- it's an item if the arg is an id instead of an ent name
   local id = args[1]
   local is_item = _tonumber(id)
   
   if not _hook_Run("TTTCanOrderEquipment", ply, id, is_item) then return end

   -- we use weapons.GetStored to save time on an unnecessary copy, we will not
   -- be modifying it
   local swep_table = (not is_item) and weapons.GetStored(id) or nil

   -- some weapons can only be bought once per player per round, this used to be
   -- defined in a table here, but is now in the SWEP's table
   if swep_table and swep_table.LimitedStock and ply:HasBought(id) then
      LANG.Msg(ply, "buy_no_stock")
      return
   end

   local received = false

   if is_item then
      id = _tonumber(id)

      -- item whitelist check
      local allowed = GetEquipmentItem(ply:GetRole(), id)

      if not allowed then
         _print(ply, "tried to buy item not buyable for his class:", id)
         return
      end

      -- ownership check and finalise
      if id and EQUIP_NONE < id then
         if not ply:HasEquipmentItem(id) then
            ply:GiveEquipmentItem(id)
            received = true
         end
      end
   elseif swep_table then
      -- weapon whitelist check
      if not _table_HasValue(swep_table.CanBuy, ply:GetRole()) then
         _print(ply, "tried to buy weapon his role is not permitted to buy")
         return
      end

      -- if we have a pending order because we are in a confined space, don't
      -- start a new one
      if HasPendingOrder(ply) then
         LANG.Msg(ply, "buy_pending")
         return
      end

      -- no longer restricted to only WEAPON_EQUIP weapons, just anything that
      -- is whitelisted and carryable
      if ply:CanCarryWeapon(swep_table) then
         GiveEquipmentWeapon(ply:SteamID(), id)

         received = true
      end
   end

   if received then
      ply:SubtractCredits(1)
      LANG.Msg(ply, "buy_received")

      ply:AddBought(id)

      _timer_Simple(0.5,
                   function()
                      if not _IsValid(ply) then return end
                      _net_Start("TTT_BoughtItem")
                      _net_WriteBit(is_item)
                      if is_item then
                         _net_WriteUInt(id, 16)
                      else
                         _net_WriteString(id)
                      end
                      _net_Send(ply)
                   end)

      _hook_Call("TTTOrderedEquipment", GAMEMODE, ply, id, is_item)
   end
end
_concommand_Add("ttt_order_equipment", OrderEquipment)

function GM:TTTToggleDisguiser(ply, state)
   -- Can be used to prevent players from using this button.
   -- return true to prevent it.
end

local function SetDisguise(ply, cmd, args)
   if not _IsValid(ply) or not ply:IsActiveTraitor() then return end

   if ply:HasEquipmentItem(EQUIP_DISGUISE) then
      local state = #args == 1 and _tobool(args[1])
      if _hook_Run("TTTToggleDisguiser", ply, state) then return end

      ply:SetNWBool("disguised", state)
      LANG.Msg(ply, state and "disg_turned_on" or "disg_turned_off")
   end
end
_concommand_Add("ttt_set_disguise", SetDisguise)

local function CheatCredits(ply)
   if _IsValid(ply) then
      ply:AddCredits(10)
   end
end
_concommand_Add("ttt_cheat_credits", CheatCredits, nil, nil, FCVAR_CHEAT)

local function TransferCredits(ply, cmd, args)
   if (not _IsValid(ply)) or (not ply:IsActiveSpecial()) then return end
   if #args != 2 then return end

   local sid = _tostring(args[1])
   local credits = _tonumber(args[2])
   if sid and credits then
      local target = _player_GetBySteamID(sid)
      if (not _IsValid(target)) or (not target:IsActiveSpecial()) or (target:GetRole() ~= ply:GetRole()) or (target == ply) then
         LANG.Msg(ply, "xfer_no_recip")
         return
      end

      if ply:GetCredits() < credits then
         LANG.Msg(ply, "xfer_no_credits")
         return
      end

      credits = _math_Clamp(credits, 0, ply:GetCredits())
      if credits == 0 then return end

      ply:SubtractCredits(credits)
      target:AddCredits(credits)

      LANG.Msg(ply, "xfer_success", {player=target:Nick()})
      LANG.Msg(target, "xfer_received", {player = ply:Nick(), num = credits})
   end
end
_concommand_Add("ttt_transfer_credits", TransferCredits)

-- Protect against non-TTT weapons that may break the HUD
function GM:WeaponEquip(wep)
   if _IsValid(wep) then
      -- only remove if they lack critical stuff
      if not wep.Kind then
         wep:Remove()
         _ErrorNoHalt("Equipped weapon " .. wep:GetClass() .. " is not compatible with TTT\n")
      end
   end
end

-- non-cheat developer commands can reveal precaching the first time equipment
-- is bought, so trigger it at the start of a round instead
function WEPS.ForcePrecache()
   for k, w in _ipairs(weapons.GetList()) do
      if w.WorldModel then
         _util_PrecacheModel(w.WorldModel)
      end
      if w.ViewModel then
         _util_PrecacheModel(w.ViewModel)
      end
   end
end
