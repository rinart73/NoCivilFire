--[[
Name: nocivilfire
Author: Rinart73
Description: Module for ComplexCraftOrders that connects it with NoCivilFire mod
Version: 1.2.0-1
]]

local random = math.random
local randomseed = math.randomseed
local huge = math.huge

-- API
local api

local function initialize(modAPI)
    api = modAPI
end

-- Helpers

local Argument = { Any = 1, Ship = 2, Station = 3 }

-- Target

local function targetAnyEnemy(sector, arg)
    local civilianShooting = not CraftOrders or CraftOrders.noCivilFire_civilianShooting
    local entities = {sector:getEnemies(Faction().index)}
    local entity
    for i = 1, #entities do
        entity = entities[i]
        if (arg ~= Argument.Station and entity.isShip and (not entity:getValue("is_civil") or civilianShooting)) or (arg ~= Argument.Ship and entity.isStation) then
            api:log(api.Level.Debug, "targetAnyEnemy")
            return entity
        end
    end
    api:log(api.Level.Debug, "targetAnyEnemy - nobody")
end

local function targetNearestEnemy(sector, arg)
    local civilianShooting = not CraftOrders or CraftOrders.noCivilFire_civilianShooting
    local self = Entity()
    local entities = {sector:getEnemies(Faction().index)}
    local nearestEnemy, entity, distance
    local nearestDistance = huge
    for i = 1, #entities do
        local entity = entities[i]
        if ((arg ~= Argument.Station and entity.isShip) or (arg ~= Argument.Ship and entity.isStation)) and (not entity:getValue("is_civil") or civilianShooting) then
            distance = self:getNearestDistance(entity)
            if distance < nearestDistance then
                nearestDistance = distance
                nearestEnemy = entity
            end
        end
    end
    api:log(api.Level.Debug, "targetNearestEnemy - %s", tostring, nearestEnemy)
    return nearestEnemy
end

local function targetMostHurtEnemy(sector, arg)
    local civilianShooting = not CraftOrders or CraftOrders.noCivilFire_civilianShooting
    local entities = {sector:getEnemies(Faction().index)}
    local hurtEnemy, entity, ratio
    local minHp = 2
    for i = 1, #entities do
        local entity = entities[i]
        if ((arg ~= Argument.Station and entity.isShip) or (arg ~= Argument.Ship and entity.isStation)) and (not entity:getValue("is_civil") or civilianShooting) then
            ratio = entity.durability / entity.maxDurability
            if ratio < minHp then
                minHp = ratio
                hurtEnemy = entity
            end
        end
    end
    api:log(api.Level.Debug, "targetMostHurtEnemy - %s", tostring, hurtEnemy)
    return hurtEnemy
end

local function targetLeastHurtEnemy(sector, arg)
    local civilianShooting = not CraftOrders or CraftOrders.noCivilFire_civilianShooting
    local entities = {sector:getEnemies(Faction().index)}
    local hurtEnemy, entity, ratio
    local maxHp = 0
    for i = 1, #entities do
        local entity = entities[i]
        if ((arg ~= Argument.Station and entity.isShip) or (arg ~= Argument.Ship and entity.isStation)) and (not entity:getValue("is_civil") or civilianShooting) then
            ratio = entity.durability / entity.maxDurability
            if ratio > maxHp then
                maxHp = ratio
                hurtEnemy = entity
            end
        end
    end
    api:log(api.Level.Debug, "targetLeastHurtEnemy - %s", tostring, hurtEnemy)
    return hurtEnemy
end

local function targetRandomEnemy(sector, arg)
    local civilianShooting = not CraftOrders or CraftOrders.noCivilFire_civilianShooting
    randomseed(appTimeMs()) -- for some reason randomseed doesn't work if it's placed outside of the function
    local faction = Faction()
    local entities, entity
    local ships = {}
    local stations = {}
    local rand
    if arg ~= Argument.Station then --ship or ''
        entities = {sector:getEntitiesByType(EntityType.Ship)}
        for i = 1, #entities do
            entity = entities[i]
            if faction:getRelations(entity.factionIndex) < -40000 and (not entity:getValue("is_civil") or civilianShooting) then
                ships[#ships+1] = entity
            end
        end
        if arg == Argument.Ship then -- ship
            rand = #ships > 0 and ships[random(#ships)]
            api:log(api.Level.Debug, "targetRandomEnemy(ship) - %s", tostring, rand)
            return rand
        end
    end
    --station or ''
    entities = {sector:getEntitiesByType(EntityType.Station)}
    for i = 1, #entities do
        entity = entities[i]
        if faction:getRelations(entity.factionIndex) < -40000 and (not entity:getValue("is_civil") or civilianShooting) then
            stations[#stations+1] = entity
        end
    end
    if arg == Argument.Station then -- station
        rand = #stations > 0 and stations[random(#stations)]
        api:log(api.Level.Debug, "targetRandomEnemy(station) - %s", tostring, rand)
        return rand
    end
    local totalLen = #ships + #stations
    if totalLen == 0 then
        api:log(api.Level.Debug, "targetRandomEnemy(any) - nobody")
        return
    end
    totalLen = random(totalLen)
    if totalLen > #ships then
        rand = stations[totalLen-#ships]
        api:log(api.Level.Debug, "targetRandomEnemy(any, station) - %s", tostring, rand)
        return rand
    end
    rand = ships[totalLen]
    api:log(api.Level.Debug, "targetRandomEnemy(any, ships) - %s", tostring, rand)
    return rand
end

-- Action

local function actionToggleCivilianShooting(target, arg)
    if CraftOrders then
        local result = Entity():invokeFunction("craftorders.lua", "noCivilFire_setCivilianShooting", arg == 1)
        if result ~= 0 then log(api.Level.Error, "actionToggleCivilianShooting failed with code %u", result) end
    end
end


return {
  -- Init
  initialize = initialize,
  -- Who
  Target = {
    ["Any Enemy"] = {
      func = targetAnyEnemy,
      argument = { "", "Ship", "Station" }
    },
    ["Nearest Enemy"] = {
      func = targetNearestEnemy,
      argument = { "", "Ship", "Station" }
    },
    ["Most Hurt Enemy"] = {
      func = targetMostHurtEnemy,
      argument = { "", "Ship", "Station" }
    },
    ["Least Hurt Enemy"] = {
      func = targetLeastHurtEnemy,
      argument = { "", "Ship", "Station" }
    },
    ["Random Enemy"] = {
      func = targetRandomEnemy,
      argument = { "", "Ship", "Station" },
      cache = false
    }
  },
  -- Action
  Action = {
    ["Toggle Civilian Shooting"] = {
      func = actionToggleCivilianShooting,
      argument = { "On", "Off" }
    },
  }
}