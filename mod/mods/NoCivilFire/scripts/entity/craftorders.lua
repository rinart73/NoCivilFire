--[[
Modname: NoCivilFire
Author: Rinart73
Version: 1.0.0 (0.17.1+)
Description: Prevents player/alliance ships from attacking civilians, thus saving your reputation.
]]

if onServer() then

function CraftOrders.initialize()
    if ShipAI().state == 3 then -- if ship is in aggressive mode
        CraftOrders.addCivilNeutrality()
    end
end

CraftOrders.old_onAttackEnemiesButtonPressed = CraftOrders.onAttackEnemiesButtonPressed

function CraftOrders.onAttackEnemiesButtonPressed()
    CraftOrders.old_onAttackEnemiesButtonPressed()
    if ShipAI().state == 3 then -- if passed checkCaptain()
        CraftOrders.addCivilNeutrality()
    end
end

-- removeSpecialOrders is local function, but setAIAction will do too
CraftOrders.old_setAIAction = CraftOrders.setAIAction

function CraftOrders.setAIAction(action, index, position)
    CraftOrders.old_setAIAction(action, index, position)
    CraftOrders.removeCivilNeutrality()
end

--[[ We need this workaround because there is no way to immediately know if NEW ship is civil (onEntityCreate fires before this attribute is applied)
 There should not be significant performance impact since this array will be not empty only when ai.state = 3 and new ships were just created ]]
local possibleFriends = {}

function CraftOrders.updateServer()
    if Faction().isAIFaction then return end
    if #possibleFriends > 0 then
        local ai = ShipAI()
        for i = 1, #possibleFriends do
            if Entity(possibleFriends[i]):getValue("is_civil") then
                ai:registerFriendEntity(possibleFriends[i])
            end
        end
        possibleFriends = {}
    end
end

-- callbacks

function CraftOrders.befriendCivilianDelayed(entityIndex)
    if Entity(entityIndex).isShip then
        possibleFriends[#possibleFriends+1] = entityIndex
    end
end

function CraftOrders.befriendCivilian(entityIndex)
    local entity = Entity(entityIndex)
    if entity.isShip and entity:getValue("is_civil") then
        ShipAI():registerFriendEntity(entityIndex)
    end
end

-- functions

function CraftOrders.addCivilNeutrality()
    if Faction().isAIFaction then return end
    Sector():registerCallback("onEntityCreate", "befriendCivilianDelayed")
    Sector():registerCallback("onEntityEntered", "befriendCivilian")

    local ai = ShipAI()
    local civils = {Sector():getEntitiesByScript("civilship.lua")}
    for i = 1, #civils do
        ai:registerFriendEntity(civils[i].index) 
    end
end

function CraftOrders.removeCivilNeutrality()
    if Faction().isAIFaction then return end
    Sector():unregisterCallback("onEntityCreate", "befriendCivilianDelayed")
    Sector():unregisterCallback("onEntityEntered", "befriendCivilian")
end

end