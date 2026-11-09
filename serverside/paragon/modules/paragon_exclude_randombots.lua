--[[
    Paragon Random Bot Exclusion Module (Azeroth at Home)

    Stops mod-playerbots random bots from using the Paragon system.

    How it works:
    - At login, paragon_hook.lua raises the OnBeforePlayerStatLoad event and
      uses the callback it returns to finish loading Paragon data.
    - For random bot accounts, this module returns a callback that does
      nothing, so the bot never gets Paragon data in memory.
    - Everything in the module checks for Paragon data first, so random bots:
      earn no Paragon experience (kills, quests, achievements, skills),
      get no stat bonuses, are not saved at logout, and cannot claim.
    - All other accounts (players and their altbots) load normally.

    Random bots are recognised by account name: every random bot account
    starts with mod-playerbots' Playerbots.RandomBotAccountPrefix
    (playerbots.conf). The check ignores upper/lower case.

    This file does not change any of the original module's files.
]]

-- Must match Playerbots.RandomBotAccountPrefix in playerbots.conf
local RANDOM_BOT_ACCOUNT_PREFIX = "rndbot"

local prefix_lower = string.lower(RANDOM_BOT_ACCOUNT_PREFIX)

local function IsRandomBot(player)
    local account_name = player:GetAccountName()
    if not account_name then
        return false
    end
    return string.sub(string.lower(account_name), 1, #prefix_lower) == prefix_lower
end

-- Replaces the normal "finish loading" step for random bots
local function SkipParagonLoad(guid_low, paragon)
    return false
end

local function OnBeforePlayerStatLoad(player, paragon)
    if player and IsRandomBot(player) then
        -- Returned as a list: { paragon, callback }
        return { paragon, SkipParagonLoad }
    end
    -- Anyone else: return nothing, so the normal values are used
end

RegisterMediatorEvent("OnBeforePlayerStatLoad", OnBeforePlayerStatLoad)
