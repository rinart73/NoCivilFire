--[[
Modname: NoCivilFire
Author: Rinart73
Version: 1.2.0 (0.17.1 - 0.18.2)
Description: Prevents player/alliance ships from attacking civilians, thus saving your reputation.
This mod is serverside, optionally it can be also installed on client-side to allow players to toggle aggression towards civilian ships on and off (off by default).
]]

if onClient() then


require ("faction")
require ("stringutility")

-- register for localization
if i18n then i18n.registerMod("NoCivilFire") end

-- Init UI
local spareCiviliansCheckBox
local spareCiviliansCheckBoxId = CraftOrders.addElement("Don't attack civilians", "noCivilFire_onSpareCiviliansCheckBoxChecked", CraftOrders.ElementType.CheckBox) -- will receive row index

local function afterInitUI()
    if not CraftOrders.Elements[spareCiviliansCheckBoxId] then
        print("[NoCivilFire][ERROR]: Couldn't create UI")
        return
    end
    spareCiviliansCheckBox = CraftOrders.Elements[spareCiviliansCheckBoxId].element -- get created ui element
    invokeServerFunction("noCivilFire_sendSettingsToClient")
end
CraftOrders.registerInitUICallback(afterInitUI)

-- Callbacks

function CraftOrders.noCivilFire_onSpareCiviliansCheckBoxChecked()
    if not checkEntityInteractionPermissions(Entity(), AlliancePrivilege.FlyCrafts) then return end
    invokeServerFunction("noCivilFire_onSpareCiviliansCheckBoxChecked", spareCiviliansCheckBox.checked)
end

-- Functions

function CraftOrders.noCivilFire_receiveSettings(checked)
    if spareCiviliansCheckBox then
        spareCiviliansCheckBox:setCheckedNoCallback(checked)
    end
end

-- API

function CraftOrders.noCivilFire_setCivilianShooting(on)
    if not checkEntityInteractionPermissions(Entity(), AlliancePrivilege.FlyCrafts) then return false end
    on = not (on and true)
    if spareCiviliansCheckBox then
        spareCiviliansCheckBox:setCheckedNoCallback(on)
    end
    invokeServerFunction("noCivilFire_onSpareCiviliansCheckBoxChecked", on)
    return true
end


else -- onServer


local spareCivilians = true
local civilianFriends = {} -- save friends to be able to unfriend them when spareCivilians is set to false
local possibleFriends = {}

-- Functions

local function addCivilNeutrality(noCallbacks)
    if callingPlayer or Faction().isAIFaction then return end
    if not noCallbacks then
        Sector():registerCallback("onEntityCreate", "noCivilFire_befriendCivilianDelayed")
        Sector():registerCallback("onEntityEntered", "noCivilFire_befriendCivilian")
    end

    if not spareCivilians then return end
    local ai = ShipAI()
    local civils = {Sector():getEntitiesByScript("civilship.lua")}
    local civilIndex
    for i = 1, #civils do
        civilIndex = civils[i].index
        civilianFriends[#civilianFriends+1] = civilIndex
        ai:registerFriendEntity(civilIndex)
    end
end

local function removeCivilNeutrality()
    if callingPlayer or Faction().isAIFaction then return end
    Sector():unregisterCallback("onEntityCreate", "noCivilFire_befriendCivilianDelayed")
    Sector():unregisterCallback("onEntityEntered", "noCivilFire_befriendCivilian")
end

-- Predefined functions

local old_initialize = CraftOrders.initialize
function CraftOrders.initialize()
    if old_initialize then old_initialize() end
    if callingPlayer then return end
    if Faction().isAIFaction then return end
    local ai = ShipAI()
    if ai.state == 3 or ai.state == 9 then -- if ship is in aggressive mode
        addCivilNeutrality()
    end
end

-- removeSpecialOrders is local function, but setAIAction will do too
local old_setAIAction = CraftOrders.setAIAction
function CraftOrders.setAIAction(action, index, position)
    old_setAIAction(action, index, position)
    if Faction().isAIFaction then return end
    if callingPlayer and not checkEntityInteractionPermissions(Entity(), AlliancePrivilege.FlyCrafts) then return end
    local ai = ShipAI()
    if ai.state ~= 3 and ai.state ~= 9 then
        removeCivilNeutrality()
    else
        addCivilNeutrality()
    end
end

--[[ We need this workaround because there is no way to immediately know if NEW ship is civil (onEntityCreate fires before this attribute is applied)
 There should not be significant performance impact since this array will be not empty only when ai.state = 3/9 and new ships were just created ]]
local old_updateServer = CraftOrders.updateServer
function CraftOrders.updateServer(ms)
    if old_updateServer then old_updateServer(ms) end
    if callingPlayer then return end
    if Faction().isAIFaction then return end
    if #possibleFriends > 0 then
        if spareCivilians then
            local ai = ShipAI()
            local possibleFriend
            for i = 1, #possibleFriends do
                possibleFriend = possibleFriends[i]
                if Entity(possibleFriend):getValue("is_civil") then
                    civilianFriends[#civilianFriends+1] = possibleFriend
                    ai:registerFriendEntity(possibleFriend)
                end
            end
        end
        possibleFriends = {}
    end
end

-- Сallbacks

function CraftOrders.noCivilFire_befriendCivilianDelayed(entityIndex)
    if callingPlayer or not spareCivilians then return end
    if Entity(entityIndex).isShip then
        possibleFriends[#possibleFriends+1] = entityIndex
    end
end

function CraftOrders.noCivilFire_befriendCivilian(entityIndex)
    if not spareCivilians then return end
    local entity = Entity(entityIndex)
    if entity.isShip and entity:getValue("is_civil") then
        civilianFriends[#civilianFriends+1] = entityIndex
        ShipAI():registerFriendEntity(entityIndex)
    end
end

function CraftOrders.noCivilFire_onSpareCiviliansCheckBoxChecked(checked)
    if not checkEntityInteractionPermissions(Entity(), AlliancePrivilege.FlyCrafts) then return end
    callingPlayer = nil
    spareCivilians = checked
    CraftOrders.noCivilFire_civilianShooting = not spareCivilians
    if not checked then -- unfriend them
        local ai = ShipAI()
        for i = 1, #civilianFriends do
            ai:unregisterFriendEntity(civilianFriends[i])
        end
        civilianFriends = {}
    else -- befriend them again
        addCivilNeutrality(true)
    end
    broadcastInvokeClientFunction("noCivilFire_receiveSettings", checked)
end

-- Functions

function CraftOrders.noCivilFire_sendSettingsToClient()
    if not callingPlayer then return end
    invokeClientFunction(Player(callingPlayer), "noCivilFire_receiveSettings", spareCivilians)
end

-- Data securing

local old_secure = CraftOrders.secure
function CraftOrders.secure()
    if Faction().isAIFaction then
        return old_secure()
    else
        local data = old_secure()
        data["spareCivilians"] = spareCivilians and 1 or 0
        return data
    end
end

local old_restore = CraftOrders.restore
function CraftOrders.restore(dataIn)
    old_restore(dataIn)
    if callingPlayer or not Faction().isAIFaction then
        spareCivilians = dataIn["spareCivilians"] == nil or dataIn["spareCivilians"] == 1
        CraftOrders.noCivilFire_civilianShooting = not spareCivilians
    end
end

-- API

CraftOrders.noCivilFire_civilianShooting = false

function CraftOrders.noCivilFire_setCivilianShooting(on)
    if Faction().isAIFaction then return false end
    on = not (on and true)
    spareCivilians = on
    CraftOrders.noCivilFire_civilianShooting = not spareCivilians
    if not on then -- unfriend them
        local ai = ShipAI()
        for i = 1, #civilianFriends do
            ai:unregisterFriendEntity(civilianFriends[i])
        end
        civilianFriends = {}
    else -- befriend them again
        addCivilNeutrality(true)
    end
    broadcastInvokeClientFunction("noCivilFire_receiveSettings", on)
    return true
end


end