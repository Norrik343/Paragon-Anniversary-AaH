--[[
    Paragon Achievement Claim Module (Azeroth at Home)

    Lets a character claim Paragon experience for achievements it already has,
    using the "Claim achievements" button in the Paragon window.

    How it works:
    - Characters below MINIMUM_LEVEL_FOR_PARAGON_XP earn no Paragon experience
      (the core module's normal rule). Their achievements stay unclaimed.
    - Once at the minimum level, the button awards experience for every
      completed achievement that has not given experience yet.
    - Achievements completed at or above the minimum level give experience
      automatically (core module) and are recorded here, so they are never
      counted twice.
    - All levels gained by a claim are applied in one step, so the level-up
      animation and message play once. Milestone achievements for any levels
      skipped over are still awarded.

    Experience per achievement uses the same rules as normal play:
    - paragon_config_experience_achievement value if set, otherwise
      UNIVERSAL_ACHIEVEVEMENT_EXPERIENCE (0 there disables achievement XP)
    - EXPERIENCE_MULTIPLIER_LOW_LEVEL / _HIGH_LEVEL by Paragon level
    - BASE_MAX_EXPERIENCE x level per level (CAP_MAX_EXPERIENCE if present)
    - PARAGON_LEVEL_CAP

    Adds:
    - Client request 7 (sent by the addon's Claim button)
    - Client request 8 (claim state, sent when the Paragon window opens)
    - Server response 7 (claim state: unclaimed count, 1/0 at minimum level),
      used by the addon to grey out the Claim button
    - Table acore_ale.character_paragon_achievement_claimed (created on load)

    This file does not change any of the original module's files.
]]

local ParagonHook = require("paragon_hook")
local Config = require("paragon_config")
local Constants = require("paragon_constant")

local sf = string.format
local DB_NAME = Constants.DB_NAME
local CLAIM_REQUEST_ID = 7
local STATUS_REQUEST_ID = 8
local STATUS_RESPONSE_ID = 7
local PREFIX = "|cffffd100Paragon:|r "

-- ============================================================================
-- DATABASE
-- ============================================================================

CharDBExecute(sf([[
    CREATE TABLE IF NOT EXISTS `%s`.`character_paragon_achievement_claimed` (
        `guid` INT UNSIGNED NOT NULL,
        `achievement` INT UNSIGNED NOT NULL,
        PRIMARY KEY (`guid`, `achievement`)
    ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
]], DB_NAME))

--- Records achievements as having given Paragon experience
local function RecordClaimed(guid, achievement_ids)
    -- Insert in batches to keep each query a reasonable size
    local batch = {}
    for i, achievement_id in ipairs(achievement_ids) do
        table.insert(batch, sf("(%d, %d)", guid, achievement_id))
        if #batch == 200 or i == #achievement_ids then
            CharDBExecute(sf(
                "INSERT IGNORE INTO `%s`.`character_paragon_achievement_claimed` (guid, achievement) VALUES %s;",
                DB_NAME, table.concat(batch, ",")))
            batch = {}
        end
    end
end

-- ============================================================================
-- CONFIG HELPERS (same rules as the core module)
-- ============================================================================

local function ConfigNumber(field, default)
    return tonumber(Config:GetByField(field)) or default
end

local function IsSystemEnabled()
    return ConfigNumber("ENABLE_PARAGON_SYSTEM", 1) ~= 0
end

local function MinimumLevel()
    return ConfigNumber("MINIMUM_LEVEL_FOR_PARAGON_XP", 0)
end

--- Experience needed to go from `level` to `level + 1`
local function ExperienceForLevel(level)
    local required = ConfigNumber("BASE_MAX_EXPERIENCE", 1000) * level
    local cap = ConfigNumber("CAP_MAX_EXPERIENCE", 0)
    if cap > 0 and required > cap then
        required = cap
    end
    return required
end

--- Low/high level experience multiplier (same as paragon_anniversary.lua)
local function ExperienceMultiplier(level)
    if level < ConfigNumber("LOW_LEVEL_THRESHOLD", 5) then
        return ConfigNumber("EXPERIENCE_MULTIPLIER_LOW_LEVEL", 1.5)
    end
    if level > ConfigNumber("HIGH_LEVEL_THRESHOLD", 100) then
        return ConfigNumber("EXPERIENCE_MULTIPLIER_HIGH_LEVEL", 0.8)
    end
    return 1.0
end

--- Base experience for one achievement, before multipliers
local function AchievementExperience(achievement_id)
    local universal = ConfigNumber("UNIVERSAL_ACHIEVEVEMENT_EXPERIENCE", 0)
    if universal <= 0 then
        return 0
    end
    return tonumber(Config:GetAchievementExperience(achievement_id)) or universal
end

-- ============================================================================
-- MILESTONE ACHIEVEMENTS (same table as paragon_levelup_achievement.lua)
-- Used to award milestones for levels a claim skips over; the level the claim
-- ends on is handled by paragon_levelup_achievement.lua itself.
-- ============================================================================

local Milestones = {}
do
    local achievement_id = 70000
    for level = 1, 100, 10 do
        Milestones[level] = achievement_id
        achievement_id = achievement_id + 1
    end
    for level = 125, 500, 25 do
        Milestones[level] = achievement_id
        achievement_id = achievement_id + 1
    end
end

-- ============================================================================
-- CLAIM STATE (client request 8 -> server response 7)
-- ============================================================================

--- Number of completed achievements that have not given Paragon experience yet
local function CountUnclaimed(guid)
    local results = CharDBQuery(sf([[
        SELECT COUNT(*)
        FROM character_achievement ca
        LEFT JOIN `%s`.`character_paragon_achievement_claimed` c
            ON c.guid = ca.guid AND c.achievement = ca.achievement
        WHERE ca.guid = %d AND c.achievement IS NULL;
    ]], DB_NAME, guid))
    if not results then
        return 0
    end
    return results:GetUInt32(0)
end

--- Tells the addon whether there is anything to claim.
--- `unclaimed` can be passed in when it is already known (right after a claim,
--- the claimed records may not be written yet, so a fresh count could be wrong).
local function SendClaimStatus(player, unclaimed)
    if not player then
        return
    end
    if unclaimed == nil then
        unclaimed = CountUnclaimed(player:GetGUIDLow())
    end
    local eligible = (IsSystemEnabled() and player:GetLevel() >= MinimumLevel()) and 1 or 0
    player:SendServerResponse(ParagonHook.Addon.Prefix, STATUS_RESPONSE_ID, unclaimed, eligible)
end

function OnParagonClientClaimStatus(player, _)
    SendClaimStatus(player)
    return true
end

-- ============================================================================
-- CLAIM REQUEST (client request 7)
-- ============================================================================

function OnParagonClientClaimAchievements(player, _)
    if not player or not IsSystemEnabled() then
        return false
    end

    local paragon = player:GetData("Paragon")
    if not paragon then
        return false
    end

    local min_level = MinimumLevel()
    if player:GetLevel() < min_level then
        player:SendBroadcastMessage(sf("%sreach level %d to claim achievement experience.", PREFIX, min_level))
        SendClaimStatus(player)
        return false
    end

    local guid = player:GetGUIDLow()

    -- Completed achievements that have not given Paragon experience yet.
    -- (Achievements from the last few minutes may not be saved yet; they
    -- stay unclaimed and can be claimed later.)
    local results = CharDBQuery(sf([[
        SELECT ca.achievement
        FROM character_achievement ca
        LEFT JOIN `%s`.`character_paragon_achievement_claimed` c
            ON c.guid = ca.guid AND c.achievement = ca.achievement
        WHERE ca.guid = %d AND c.achievement IS NULL
        ORDER BY ca.date;
    ]], DB_NAME, guid))

    if not results then
        player:SendBroadcastMessage(PREFIX .. "no unclaimed achievements.")
        SendClaimStatus(player, 0)
        return false
    end

    local achievement_ids = {}
    repeat
        table.insert(achievement_ids, results:GetUInt32(0))
    until not results:NextRow()

    -- Work out the final level and experience without applying each level-up
    local level = paragon:GetLevel()
    local experience = paragon:GetExperience()
    local level_cap = ConfigNumber("PARAGON_LEVEL_CAP", 0)
    local total_experience = 0

    for _, achievement_id in ipairs(achievement_ids) do
        local gained = math.floor(AchievementExperience(achievement_id) * ExperienceMultiplier(level))
        total_experience = total_experience + gained
        experience = experience + gained

        while (level_cap == 0 or level < level_cap)
            and ExperienceForLevel(level) > 0
            and experience >= ExperienceForLevel(level) do
            experience = experience - ExperienceForLevel(level)
            level = level + 1
        end
    end

    -- Mark them claimed before applying, so a second click can't repeat them
    RecordClaimed(guid, achievement_ids)

    -- Apply: one level change = one animation and one level-up message
    local old_level = paragon:GetLevel()
    if level ~= old_level then
        paragon:SetLevel(level)
    end
    paragon:SetExperience(experience)

    -- Milestones for levels skipped over (the final level is handled elsewhere)
    for skipped = old_level + 1, level - 1 do
        local milestone = Milestones[skipped]
        if milestone and not player:HasAchieved(milestone) then
            player:SetAchievement(milestone)
        end
    end

    -- Save now so a large claim isn't lost if the server stops before logout
    player:SetData("Paragon", paragon)
    paragon:Save()

    -- Update the addon
    player:SendServerResponse(ParagonHook.Addon.Prefix, 1, paragon:GetLevel())
    player:SendServerResponse(ParagonHook.Addon.Prefix, 4, paragon:GetPoints())
    player:SendServerResponse(ParagonHook.Addon.Prefix, 2, paragon:GetExperience(), paragon:GetExperienceForNextLevel())

    local levels_gained = paragon:GetLevel() - old_level
    local levels_text = ""
    if levels_gained > 0 then
        levels_text = sf(" (+%d Paragon level%s)", levels_gained, levels_gained == 1 and "" or "s")
    end
    player:SendBroadcastMessage(sf("%sclaimed %d achievement%s for %d experience%s.",
        PREFIX, #achievement_ids, #achievement_ids == 1 and "" or "s", total_experience, levels_text))

    -- Everything found was just claimed: grey out the button
    SendClaimStatus(player, 0)

    return true
end

ParagonHook.Addon.Functions[CLAIM_REQUEST_ID] = "OnParagonClientClaimAchievements"
ParagonHook.Addon.Functions[STATUS_REQUEST_ID] = "OnParagonClientClaimStatus"
RegisterClientRequests(ParagonHook.Addon, true)

-- ============================================================================
-- EVENTS
-- ============================================================================

--- Achievements completed at or above the minimum level get experience from
--- the core module straight away; record them so a claim never repeats them.
local function OnAchievementComplete(event, player, achievement)
    if not player or not achievement or not IsSystemEnabled() then
        return
    end
    if player:GetLevel() >= MinimumLevel() then
        RecordClaimed(player:GetGUIDLow(), { achievement:GetId() })
    end
end

--- Remove claim records when a character is deleted
local function OnCharacterDelete(event, guid)
    if guid then
        CharDBExecute(sf("DELETE FROM `%s`.`character_paragon_achievement_claimed` WHERE guid = %d;", DB_NAME, guid))
    end
end

RegisterPlayerEvent(45, OnAchievementComplete)  -- PLAYER_EVENT_ON_ACHIEVEMENT_COMPLETE
RegisterPlayerEvent(2, OnCharacterDelete)       -- PLAYER_EVENT_ON_CHARACTER_DELETE
