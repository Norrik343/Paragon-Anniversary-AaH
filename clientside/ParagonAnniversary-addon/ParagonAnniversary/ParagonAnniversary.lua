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
-- CLAIM ACHIEVEMENTS BUTTON
-- Asks the server (request 7, modules/paragon_achievement_claim.lua) to give
-- Paragon experience for achievements that haven't given any yet.
-- ============================================================================

StaticPopupDialogs["PARAGON_CLAIM_ACHIEVEMENTS"] = {
    text = "Claim Paragon experience for all of this character's unclaimed achievements?",
    button1 = YES,
    button2 = NO,
    OnAccept = function()
        SendClientRequest("ParagonAnniversary", 7)
    end,
    timeout = 0,
    whileDead = true,
    hideOnEscape = true,
    preferredIndex = 3,
}

function CreateClaimButton()
    if not UIParagon or not UIParagon.ApplyButton or UIParagonClaimButton then return end

    local claim = CreateFrame("Button", "UIParagonClaimButton", UIParagon, "BigRedThreeSliceButtonTemplate")
    claim:SetWidth(160)
    claim:SetHeight(30)
    -- Bottom-right corner, level with the Apply button (y = 10)
    claim:SetPoint("BOTTOMRIGHT", UIParagon, "BOTTOMRIGHT", -20, 10)

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
        GameTooltip:Show()
    end)
    claim:SetScript("OnLeave", function() GameTooltip:Hide() end)
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
        end
        self:UnregisterEvent("ADDON_LOADED")
    end
end)
