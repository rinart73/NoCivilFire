--[[
Modname: NoCivilFire
Author: Rinart73
Version: 1.1.0 (0.17.1+)
Description: Prevents player/alliance ships from attacking civilians, thus saving your reputation.
This mod is serverside, optionally it can be also installed on client-side to allow players to toggle aggression towards civilian ships on and off (off by default).
]]

if onClient() then


local lang = getCurrentLanguage()
local spareCiviliansText = { en = "Don't attack civilians", ru = "Не атаковать гражданских" }
spareCiviliansText = spareCiviliansText[lang] and spareCiviliansText[lang] or spareCiviliansText["en"]

local spareCiviliansCheckBox

function CraftOrders.initUI()

    local res = getResolution()
    local size = vec2(250, 330)

    local menu = ScriptUI()
    local window = menu:createWindow(Rect(res * 0.5 - size * 0.5, res * 0.5 + size * 0.5))
    menu:registerWindow(window, "Orders"%_t)

    window.caption = "Craft Orders"%_t
    window.showCloseButton = 1
    window.moveable = 1

    local splitter = UIHorizontalMultiSplitter(Rect(window.size), 10, 10, 8)

    window:createButton(splitter:partition(0), "Idle"%_t, "onIdleButtonPressed")
    window:createButton(splitter:partition(1), "Passive"%_t, "onPassiveButtonPressed")
    window:createButton(splitter:partition(2), "Guard This Position"%_t, "onGuardButtonPressed")
    window:createButton(splitter:partition(3), "Patrol Sector"%_t, "onPatrolButtonPressed")
    window:createButton(splitter:partition(4), "Escort Me"%_t, "onEscortMeButtonPressed")
    window:createButton(splitter:partition(5), "Attack Enemies"%_t, "onAttackEnemiesButtonPressed")
    window:createButton(splitter:partition(6), "Mine"%_t, "onMineButtonPressed")
    window:createButton(splitter:partition(7), "Salvage"%_t, "onSalvageButtonPressed")
    
    spareCiviliansCheckBox = window:createCheckBox(splitter:partition(8), spareCiviliansText, "onSpareCiviliansCheckBoxClicked")

    invokeServerFunction("sendSettingsToClient") -- request checkbox status
end

function CraftOrders.onSpareCiviliansCheckBoxClicked()
    invokeServerFunction("onSpareCiviliansCheckBoxClicked", spareCiviliansCheckBox.checked)
end

function CraftOrders.receiveSettings(checked)
    spareCiviliansCheckBox:setCheckedNoCallback(checked)
end


else -- onServer


CraftOrders.spareCivilians = true

local civilianFriends = {} -- save friends to be able to unfriend them when CraftOrders.spareCivilians is set to false

function CraftOrders.initialize()
    if ShipAI().state == 3 then -- if ship is in aggressive mode
        CraftOrders.addCivilNeutrality()
    end
end

-- removeSpecialOrders is local function, but setAIAction will do too
CraftOrders.old_setAIAction = CraftOrders.setAIAction

function CraftOrders.setAIAction(action, index, position)
    CraftOrders.old_setAIAction(action, index, position)
    if ShipAI().state ~= 3 then
        CraftOrders.removeCivilNeutrality()
    else
        CraftOrders.addCivilNeutrality()
    end
end

--[[ We need this workaround because there is no way to immediately know if NEW ship is civil (onEntityCreate fires before this attribute is applied)
 There should not be significant performance impact since this array will be not empty only when ai.state = 3 and new ships were just created ]]
local possibleFriends = {}

function CraftOrders.updateServer()
    if Faction().isAIFaction then return end
    if #possibleFriends > 0 then
        if CraftOrders.spareCivilians then
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

-- callbacks

function CraftOrders.befriendCivilianDelayed(entityIndex)
    if not CraftOrders.spareCivilians then return end
    if Entity(entityIndex).isShip then
        possibleFriends[#possibleFriends+1] = entityIndex
    end
end

function CraftOrders.befriendCivilian(entityIndex)
    if not CraftOrders.spareCivilians then return end
    local entity = Entity(entityIndex)
    if entity.isShip and entity:getValue("is_civil") then
        civilianFriends[#civilianFriends+1] = entityIndex
        ShipAI():registerFriendEntity(entityIndex)
    end
end

function CraftOrders.onSpareCiviliansCheckBoxClicked(checked)
    CraftOrders.spareCivilians = checked
    if not checked then -- unfriend them
        local ai = ShipAI()
        for i = 1, #civilianFriends do
            ai:unregisterFriendEntity(civilianFriends[i])
        end
        civilianFriends = {}
    else -- befriend them again
        CraftOrders.addCivilNeutrality(true)
    end
end

-- functions

function CraftOrders.addCivilNeutrality(noCallbacks)
    if Faction().isAIFaction then return end
    if not noCallbacks then
        Sector():registerCallback("onEntityCreate", "befriendCivilianDelayed")
        Sector():registerCallback("onEntityEntered", "befriendCivilian")
    end

    if not CraftOrders.spareCivilians then return end
    local ai = ShipAI()
    local civils = {Sector():getEntitiesByScript("civilship.lua")}
    local civilIndex
    for i = 1, #civils do
        civilIndex = civils[i].index
        civilianFriends[#civilianFriends+1] = civilIndex
        ai:registerFriendEntity(civilIndex)
    end
end

function CraftOrders.removeCivilNeutrality()
    if Faction().isAIFaction then return end
    Sector():unregisterCallback("onEntityCreate", "befriendCivilianDelayed")
    Sector():unregisterCallback("onEntityEntered", "befriendCivilian")
end

function CraftOrders.sendSettingsToClient()
    broadcastInvokeClientFunction("receiveSettings", CraftOrders.spareCivilians)
end

-- data securing

CraftOrders.old_secure = CraftOrders.secure

function CraftOrders.secure()
    if Faction().isAIFaction then
        return CraftOrders.old_secure()
    else
        local data = CraftOrders.old_secure()
        data["spareCivilians"] = CraftOrders.spareCivilians and 1 or 0
        return data
    end
end

CraftOrders.old_restore = CraftOrders.restore

function CraftOrders.restore(dataIn)
    CraftOrders.old_restore(dataIn)
    if not Faction().isAIFaction then
        CraftOrders.spareCivilians = dataIn["spareCivilians"] == nil or dataIn["spareCivilians"] == 1
    end
end


end