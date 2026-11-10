--[[
    ParagonAnniversary.lua
    Addon glue for the Paragon Anniversary UI when loaded as an addon instead
    of a FrameXML patch.

    - Minimap button (left-click toggles the window, drag to move it)
    - "Unspent points" badge on the minimap button
    - /paragon slash command and a key binding (Key Bindings > Paragon Anniversary)
    - /paragon preview: fills the window with sample stats, client side only

    The original patch defined ToggleParagonFrame() and the
    ParagonMicroButton_* notification functions in a modified copy of
    Blizzard's MainMenuBarMicroButtons.lua. The Paragon code only calls those
    functions if they exist, so defining them here drives the minimap badge.
]]

local ICON = "Interface\\Icons\\spell_holy_powerinfusion"
local previewActive = false

-- Key binding labels (shown in the Key Bindings menu)
BINDING_HEADER_PARAGONANNIVERSARY = "Paragon Anniversary"
BINDING_NAME_PARAGONANNIVERSARY_TOGGLE = "Toggle Paragon window"

local function Print(msg)
    DEFAULT_CHAT_FRAME:AddMessage("|cffffd100Paragon:|r " .. msg)
end

-- ============================================================================
-- WINDOW TOGGLE
-- ============================================================================

function ToggleParagonFrame()
    if not UIParagon then return end
    if UIParagon:IsShown() then
        UIParagon:Hide()
    else
        UIParagon:Show()
    end
end

-- ============================================================================
-- MINIMAP BUTTON
-- ============================================================================

local button = CreateFrame("Button", "ParagonMinimapButton", Minimap)
button:SetWidth(31)
button:SetHeight(31)
button:SetFrameStrata("MEDIUM")
button:SetFrameLevel(8)
button:RegisterForClicks("LeftButtonUp", "RightButtonUp")
button:RegisterForDrag("LeftButton")
button:SetHighlightTexture("Interface\\Minimap\\UI-Minimap-ZoomButton-Highlight")

local background = button:CreateTexture(nil, "BACKGROUND")
background:SetWidth(20)
background:SetHeight(20)
background:SetTexture("Interface\\Minimap\\UI-Minimap-Background")
background:SetPoint("TOPLEFT", 7, -5)

local icon = button:CreateTexture(nil, "ARTWORK")
icon:SetWidth(17)
icon:SetHeight(17)
icon:SetTexture(ICON)
icon:SetTexCoord(0.05, 0.95, 0.05, 0.95)
icon:SetPoint("TOPLEFT", 7, -6)

local border = button:CreateTexture(nil, "OVERLAY")
border:SetWidth(53)
border:SetHeight(53)
border:SetTexture("Interface\\Minimap\\MiniMap-TrackingBorder")
border:SetPoint("TOPLEFT")

-- Badge lives on its own child frame so it draws above the border
local badgeFrame = CreateFrame("Frame", nil, button)
badgeFrame:SetAllPoints(button)
badgeFrame:SetFrameLevel(button:GetFrameLevel() + 2)
local badge = badgeFrame:CreateTexture(nil, "OVERLAY")
badge:SetWidth(14)
badge:SetHeight(14)
badge:SetTexture("Interface\\Buttons\\UI-GroupLoot-Coin-Up")
badge:SetPoint("TOPRIGHT", -2, -2)
badgeFrame:Hide()

local function GetAvailablePoints()
    return (ParagonData and ParagonData.availablePoints) or 0
end

local function UpdatePosition()
    local angle = math.rad(ParagonAnniversaryDB.minimapAngle or 200)
    local radius = (Minimap:GetWidth() / 2) + 10
    button:ClearAllPoints()
    button:SetPoint("CENTER", Minimap, "CENTER", math.cos(angle) * radius, math.sin(angle) * radius)
end

local function OnDragUpdate()
    local mx, my = Minimap:GetCenter()
    local cx, cy = GetCursorPosition()
    local scale = Minimap:GetEffectiveScale()
    cx, cy = cx / scale, cy / scale
    ParagonAnniversaryDB.minimapAngle = math.deg(math.atan2(cy - my, cx - mx))
    UpdatePosition()
end

button:SetScript("OnDragStart", function(self)
    self:LockHighlight()
    self:SetScript("OnUpdate", OnDragUpdate)
end)

button:SetScript("OnDragStop", function(self)
    self:UnlockHighlight()
    self:SetScript("OnUpdate", nil)
end)

button:SetScript("OnClick", function(self, mouseButton)
    ToggleParagonFrame()
end)

button:SetScript("OnEnter", function(self)
    GameTooltip:SetOwner(self, "ANCHOR_LEFT")
    GameTooltip:AddLine("Paragon", 1, 0.82, 0)
    local points = GetAvailablePoints()
    if points > 0 then
        GameTooltip:AddLine(points .. (points == 1 and " unspent point" or " unspent points"), 0.2, 1, 0.2)
    end
    if previewActive then
        GameTooltip:AddLine("Preview mode (sample data, close the window to exit)", 1, 0.5, 0.25)
    end
    GameTooltip:AddLine("Click: open / close", 1, 1, 1)
    GameTooltip:AddLine("Drag: move around the minimap", 0.7, 0.7, 0.7)
    GameTooltip:Show()
end)

button:SetScript("OnLeave", function()
    GameTooltip:Hide()
end)

-- ============================================================================
-- NOTIFICATION BADGE (called by the Paragon network/interface code)
-- ============================================================================

function ParagonMicroButton_UpdateNotification()
    local windowOpen = UIParagon and UIParagon:IsShown()
    if GetAvailablePoints() > 0 and not windowOpen then
        badgeFrame:Show()
    else
        badgeFrame:Hide()
    end
end

function ParagonMicroButton_OnLevelUp()
    ParagonMicroButton_UpdateNotification()
end

-- ============================================================================
-- PREVIEW MODE (client only, nothing is saved on the server)
-- Shows the chosen stat layout (5 categories, 20 stats).
-- ============================================================================

--- True while /paragon preview is showing sample data (used to block Apply)
function Paragon_IsPreviewActive()
    return previewActive
end

local function Stat(statType, value, iconPath, assigned)
    return { type = statType, value = value, icon = iconPath, assigned = assigned, limit = 255 }
end

local function StartPreview()
    if not UIParagon then return end

    wipe(ParagonData.categories)
    wipe(ParagonData.stats)
    wipe(PendingChanges.stats)

    -- Same categories, IDs, order and icons as paragon_stats_setup.sql
    local sample = {
        [1] = { name = "Primary Stats", statistics = {
            [1]  = Stat("UNIT_MODS", "STAT_STRENGTH",  "Interface/Icons/Spell_Nature_Strength", 20),
            [2]  = Stat("UNIT_MODS", "STAT_AGILITY",   "Interface/Icons/Ability_Rogue_Sprint", 0),
            [3]  = Stat("UNIT_MODS", "STAT_STAMINA",   "Interface/Icons/Spell_Holy_WordFortitude", 15),
            [4]  = Stat("UNIT_MODS", "STAT_INTELLECT", "Interface/Icons/Spell_Holy_MagicalSentry", 0),
            [5]  = Stat("UNIT_MODS", "STAT_SPIRIT",    "Interface/Icons/Spell_Holy_DivineSpirit", 0),
            [6]  = Stat("UNIT_MODS", "ARMOR",          "Interface/Icons/INV_Chest_Plate01", 10),
        }},
        [2] = { name = "Melee", statistics = {
            [7]  = Stat("COMBAT_RATING", "HIT_MELEE",   "Interface/Icons/Ability_Warrior_Riposte", 0),
            [8]  = Stat("COMBAT_RATING", "CRIT_MELEE",  "Interface/Icons/Ability_CriticalStrike", 8),
            [9]  = Stat("COMBAT_RATING", "HASTE_MELEE", "Interface/Icons/Spell_Nature_Bloodlust", 0),
        }},
        [3] = { name = "Ranged", statistics = {
            [10] = Stat("COMBAT_RATING", "HIT_RANGED",   "Interface/Icons/Ability_Marksmanship", 0),
            [11] = Stat("COMBAT_RATING", "CRIT_RANGED",  "Interface/Icons/Ability_TrueShot", 0),
            [12] = Stat("COMBAT_RATING", "HASTE_RANGED", "Interface/Icons/Ability_Hunter_RunningShot", 0),
        }},
        [4] = { name = "Spell", statistics = {
            [13] = Stat("COMBAT_RATING", "HIT_SPELL",   "Interface/Icons/Spell_Arcane_Blast", 0),
            [14] = Stat("COMBAT_RATING", "CRIT_SPELL",  "Interface/Icons/Spell_Fire_FireBolt02", 0),
            [15] = Stat("COMBAT_RATING", "HASTE_SPELL", "Interface/Icons/Spell_Nature_Lightning", 0),
        }},
        [5] = { name = "Resistances", statistics = {
            [16] = Stat("UNIT_MODS", "RESISTANCE_FIRE",   "Interface/Icons/spell_fire_moltenblood", 5),
            [17] = Stat("UNIT_MODS", "RESISTANCE_NATURE", "Interface/Icons/spell_nature_wispsplodegreen", 0),
            [18] = Stat("UNIT_MODS", "RESISTANCE_FROST",  "Interface/Icons/spell_frost_wisp", 0),
            [19] = Stat("UNIT_MODS", "RESISTANCE_SHADOW", "Interface/Icons/spell_holy_prayerofshadowprotection", 0),
            [20] = Stat("UNIT_MODS", "RESISTANCE_ARCANE", "Interface/Icons/spell_nature_wispsplode", 0),
        }},
    }

    previewActive = true
    UIParagon_OnReceiveAllData(nil, { sample })
    UIParagon_OnClientReceiveLevel(nil, { 42 })
    UIParagon_OnClientReceiveXP(nil, { 650, 1000 })
    UIParagon_OnReceiveAvailablePoints(nil, { 15 })

    UIParagon:Show()
    Print("preview mode on. Sample data only; close window to exit.")
end

--- Leaves preview mode and reloads the character's real values from the server
-- Called when the Paragon window is closed while the preview is showing
local function StopPreview()
    if not previewActive then return end
    previewActive = false
    wipe(PendingChanges.stats)

    -- Same request the window sends when it first loads (Hook ID: 1); the server
    -- answers with the real level, experience, stats and available points
    SendClientRequest("ParagonAnniversary", 1)
    Print("preview mode off. original values restored.")
end

-- ============================================================================
-- CLAIM ACHIEVEMENTS BUTTON (bottom left)
-- Asks the server (request 7, modules/paragon_achievement_claim.lua) to give
-- Paragon experience for achievements that haven't given any yet.
-- The server reports the claim state (response 7, after request 8 or a claim):
-- the button is greyed out when there is nothing left to claim, or the
-- character is below the minimum level.
-- ============================================================================

local claimState = { unclaimed = nil, eligible = nil }

StaticPopupDialogs["PARAGON_CLAIM_ACHIEVEMENTS"] = {
    text = "Claim Paragon experience for all of this character's unclaimed achievements?",
    button1 = YES,
    button2 = NO,
    OnAccept = function()
        -- Grey out straight away so it can't be clicked twice while the
        -- server works; the server's status reply sets the final state
        if UIParagonClaimButton then UIParagonClaimButton:Disable() end
        SendClientRequest("ParagonAnniversary", 7)
    end,
    timeout = 0,
    whileDead = true,
    hideOnEscape = true,
    preferredIndex = 3,
}

--- Enables or greys out the Claim button from the last known claim state
local function UpdateClaimButton()
    local claim = UIParagonClaimButton
    if not claim then return end

    -- Unknown state (no reply yet): leave it clickable, the server still checks
    if claimState.unclaimed == nil
        or (claimState.eligible and claimState.unclaimed > 0) then
        claim:Enable()
        claim.Text:SetTextColor(1, 0.82, 0)
    else
        claim:Disable()
        claim.Text:SetTextColor(0.5, 0.5, 0.5)
    end
end

--- Server response 7: claim state
-- @param args table {unclaimed achievement count, 1 if at the minimum level else 0}
function UIParagon_OnReceiveClaimStatus(_, args)
    if not args then return end
    claimState.unclaimed = tonumber(args[1]) or 0
    claimState.eligible = tonumber(args[2]) == 1
    UpdateClaimButton()
end

function CreateClaimButton()
    if not UIParagon or not UIParagon.ApplyButton or UIParagonClaimButton then return end

    local claim = CreateFrame("Button", "UIParagonClaimButton", UIParagon, "BigRedThreeSliceButtonTemplate")
    claim:SetWidth(160)
    claim:SetHeight(30)
    -- Bottom-left corner, level with the Apply button (y = 10)
    claim:SetPoint("BOTTOMLEFT", UIParagon, "BOTTOMLEFT", 20, 10)
    -- Keep tooltips working while the button is greyed out
    if claim.SetMotionScriptsWhileDisabled then
        claim:SetMotionScriptsWhileDisabled(true)
    end

    claim.Text = claim:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    claim.Text:SetPoint("CENTER", 0, 0)
    claim.Text:SetText("Claim Achievements")

    claim:SetScript("OnClick", function()
        PlaySound("igMainMenuOptionCheckBoxOn")
        if previewActive then
            Print("claiming is not available in preview mode.")
            return
        end
        StaticPopup_Show("PARAGON_CLAIM_ACHIEVEMENTS")
    end)

    claim:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_TOP")
        GameTooltip:SetText("Claim Achievements", 1, 1, 1)
        GameTooltip:AddLine("Gives Paragon experience for achievements this character completed before it could earn Paragon experience. Each achievement can only be claimed once.", nil, nil, nil, true)
        if claimState.unclaimed ~= nil then
            if not claimState.eligible then
                GameTooltip:AddLine("Not available until this character can earn Paragon experience.", 1, 0.3, 0.3, true)
            elseif claimState.unclaimed == 0 then
                GameTooltip:AddLine("All achievements have been claimed.", 0.5, 0.5, 0.5, true)
            else
                GameTooltip:AddLine(string.format("%d unclaimed achievement%s.", claimState.unclaimed,
                    claimState.unclaimed == 1 and "" or "s"), 0.3, 1, 0.3, true)
            end
        end
        GameTooltip:Show()
    end)
    claim:SetScript("OnLeave", function() GameTooltip:Hide() end)

    UpdateClaimButton()
end

--- Asks the server for the claim state (request 8); not in preview mode
local function RequestClaimStatus()
    if previewActive then return end
    SendClientRequest("ParagonAnniversary", 8)
end

-- ============================================================================
-- RESET POINTS BUTTON (bottom right)
-- Sets every stat back to 0 through the normal stat request (request 2), which
-- refunds the points on the server, then reloads the window (request 1).
-- No server-side changes are needed.
-- ============================================================================

--- Returns the stats with points in them, as stat request entries set to 0
local function BuildResetChanges()
    local changes = {}
    for categoryId, stats in pairs(ParagonData and ParagonData.stats or {}) do
        for _, stat in ipairs(stats) do
            if (stat.value or 0) > 0 then
                table.insert(changes, { categoryId = categoryId, statId = stat.id, value = 0 })
            end
        end
    end
    return changes
end

local function ResetPoints()
    local changes = BuildResetChanges()

    -- Drop any changes not applied yet, and their highlight
    for _, change in pairs(PendingChanges.stats) do
        UIParagon_MarkStatAsModified(change.categoryId, change.statId, false)
    end
    wipe(PendingChanges.stats)

    if #changes == 0 then
        Print("no points are spent, nothing to reset.")
        SendClientRequest("ParagonAnniversary", 1)
        return
    end

    SendClientRequest("ParagonAnniversary", 2, changes)
    -- Reload level, stats and points so the window shows the refunded state
    SendClientRequest("ParagonAnniversary", 1)
    Print("all Paragon points refunded.")
end

StaticPopupDialogs["PARAGON_RESET_POINTS"] = {
    text = "Reset all Paragon points? Every stat goes back to 0 and all spent points are refunded.",
    button1 = YES,
    button2 = NO,
    OnAccept = function() ResetPoints() end,
    timeout = 0,
    whileDead = true,
    hideOnEscape = true,
    preferredIndex = 3,
}

function CreateResetButton()
    if not UIParagon or not UIParagon.ApplyButton or UIParagonResetButton then return end

    local reset = CreateFrame("Button", "UIParagonResetButton", UIParagon, "BigRedThreeSliceButtonTemplate")
    reset:SetWidth(160)
    reset:SetHeight(30)
    -- Bottom-right corner, level with the Apply button (y = 10)
    reset:SetPoint("BOTTOMRIGHT", UIParagon, "BOTTOMRIGHT", -20, 10)

    reset.Text = reset:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    reset.Text:SetPoint("CENTER", 0, 0)
    reset.Text:SetText("Reset Points")

    reset:SetScript("OnClick", function()
        PlaySound("igMainMenuOptionCheckBoxOn")
        if previewActive then
            Print("resetting is not available in preview mode.")
            return
        end
        StaticPopup_Show("PARAGON_RESET_POINTS")
    end)

    reset:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_TOP")
        GameTooltip:SetText("Reset Points", 1, 1, 1)
        GameTooltip:AddLine("Sets every Paragon stat back to 0 and refunds all spent points.", nil, nil, nil, true)
        GameTooltip:Show()
    end)
    reset:SetScript("OnLeave", function() GameTooltip:Hide() end)
end

-- ============================================================================
-- SLASH COMMAND
-- ============================================================================

SLASH_PARAGONANNIVERSARY1 = "/paragon"
SlashCmdList["PARAGONANNIVERSARY"] = function(msg)
    msg = string.lower(msg or "")
    if msg == "preview" then
        StartPreview()
    elseif msg == "minimap" then
        ParagonAnniversaryDB.hideMinimap = not ParagonAnniversaryDB.hideMinimap
        if ParagonAnniversaryDB.hideMinimap then
            button:Hide()
            Print("minimap button hidden. Type /paragon minimap to show it again.")
        else
            button:Show()
            Print("minimap button shown.")
        end
    elseif msg == "help" then
        Print("/paragon - open or close the window")
        Print("/paragon preview - fill the window with sample stats (client only)")
        Print("/paragon minimap - show or hide the minimap button")
    else
        ToggleParagonFrame()
    end
end

-- ============================================================================
-- STARTUP
-- ============================================================================

local events = CreateFrame("Frame")
events:RegisterEvent("ADDON_LOADED")
events:SetScript("OnEvent", function(self, event, arg1)
    if event == "ADDON_LOADED" and arg1 == "ParagonAnniversary" then
        ParagonAnniversaryDB = ParagonAnniversaryDB or {}
        if ParagonAnniversaryDB.minimapAngle == nil then
            ParagonAnniversaryDB.minimapAngle = 200
        end
        UpdatePosition()
        if ParagonAnniversaryDB.hideMinimap then
            button:Hide()
        end

        -- Make the window draggable. Its frame template turns dragging on in
        -- OnLoad, but UIParagon replaces that OnLoad with its own, so the
        -- original never registers for drag.
        if UIParagon then
            -- Draw above action bars (MEDIUM strata) so they can't show
            -- through the window; dialogs and tooltips still go on top
            UIParagon:SetFrameStrata("HIGH")
            UIParagon:SetToplevel(true)

            UIParagon:SetMovable(true)
            UIParagon:EnableMouse(true)
            UIParagon:SetClampedToScreen(true)
            UIParagon:RegisterForDrag("LeftButton")
            UIParagon:SetScript("OnDragStart", function(self) self:StartMoving() end)
            UIParagon:SetScript("OnDragStop", function(self) self:StopMovingOrSizing() end)
        end

        -- Keep the badge in sync with the window
        if UIParagon then
            UIParagon:HookScript("OnShow", ParagonMicroButton_UpdateNotification)
            UIParagon:HookScript("OnHide", ParagonMicroButton_UpdateNotification)

            -- Closing the window ends the preview and restores the real values
            UIParagon:HookScript("OnHide", StopPreview)

            CreateClaimButton()
            CreateResetButton()

            -- Refresh the Claim button state each time the window opens
            UIParagon:HookScript("OnShow", RequestClaimStatus)
        end
        self:UnregisterEvent("ADDON_LOADED")
    end
end)
