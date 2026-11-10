--[[
    Paragon Minimum Level Points Module (Azeroth at Home)

    Characters below MINIMUM_LEVEL_FOR_PARAGON_XP (80) have no Paragon points
    to spend.

    Why: Paragon level starts at 1, and available points are
    Paragon level x POINTS_PER_LEVEL, so a new level 1 character had 1 point
    to spend.

    How it works:
    - Below the minimum level, available points are set to 0 whenever the
      window loads its data and after every stat change, so the addon shows 0.
    - Below the minimum level, the server ignores any request that raises a
      stat. Lowering stats (Reset Points) still works, so a character that
      spent a point before this module was added can get it back.
    - On reaching the minimum level, the normal points
      (Paragon level x POINTS_PER_LEVEL - points spent) are restored and sent
      to the addon.

    The total at the level cap is unchanged (1000 points at Paragon level 1000).

    This file does not change any of the original module's files.
]]

local ParagonHook = require("paragon_hook")
local Config = require("paragon_config")

local PREFIX = "|cffffd100Paragon:|r "

local function MinimumLevel()
    return tonumber(Config:GetByField("MINIMUM_LEVEL_FOR_PARAGON_XP")) or 0
end

local function IsBelowMinimum(player)
    return player and player:GetLevel() < MinimumLevel()
end

--- Normal available points: Paragon level x POINTS_PER_LEVEL - points spent
local function NormalPoints(paragon)
    local points_per_level = tonumber(Config:GetByField("POINTS_PER_LEVEL")) or 1
    return math.max(0, paragon:GetLevel() * points_per_level - paragon:GetUsedPoints())
end

local function SendPoints(player, paragon)
    player:SendServerResponse(ParagonHook.Addon.Prefix, 4, paragon:GetPoints())
end

-- ============================================================================
-- WINDOW LOAD: show 0 points below the minimum level
-- ============================================================================

local function OnBeforeClientLoadRequest(player, paragon)
    if paragon and IsBelowMinimum(player) then
        paragon:SetPoints(0)
        return { paragon }
    end
end

-- ============================================================================
-- STAT CHANGES: below the minimum level, only allow lowering stats
-- ============================================================================

local function OnBeforeClientStatisticsUpdate(player, paragon, data)
    if not paragon or not data or not IsBelowMinimum(player) then
        return
    end

    local allowed = {}
    local refused = false
    for _, change in pairs(data) do
        local current = paragon:GetStatValue(change.statId) or 0
        if change.value and change.value <= current then
            table.insert(allowed, change)
        else
            refused = true
        end
    end

    if refused then
        player:SendBroadcastMessage(string.format(
            "%sParagon points unlock at level %d.", PREFIX, MinimumLevel()))
    end

    return { paragon, allowed }
end

local function OnAfterClientStatisticsUpdate(player, paragon)
    if paragon and IsBelowMinimum(player) then
        paragon:SetPoints(0)
        player:SetData("Paragon", paragon)
        SendPoints(player, paragon)
    end
end

-- ============================================================================
-- LEVEL UP: restore the normal points on reaching the minimum level
-- ============================================================================

local function OnLevelChange(event, player, old_level)
    if not player or player:GetLevel() < MinimumLevel() then
        return
    end

    local paragon = player:GetData("Paragon")
    if not paragon then
        return -- random bots and characters without Paragon data
    end

    paragon:SetPoints(NormalPoints(paragon))
    player:SetData("Paragon", paragon)
    SendPoints(player, paragon)
end

RegisterMediatorEvent("OnBeforeClientLoadRequest", OnBeforeClientLoadRequest)
RegisterMediatorEvent("OnBeforeClientStatisticsUpdate", OnBeforeClientStatisticsUpdate)
RegisterMediatorEvent("OnAfterClientStatisticsUpdate", OnAfterClientStatisticsUpdate)
RegisterPlayerEvent(13, OnLevelChange)  -- PLAYER_EVENT_ON_LEVEL_CHANGE

print("[Paragon] Minimum level points module loaded")
