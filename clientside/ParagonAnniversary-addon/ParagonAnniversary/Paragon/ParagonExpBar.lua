--[[
    ParagonExpBar.lua
    Paragon experience bar for the main interface.

    Two modes, picked once at login:

    DEFAULT UI (no ElvUI)
      Works like the normal experience bar does while levelling:
      - At max level the Paragon bar takes the XP bar slot at the top of the
        main action bar (the empty "max level" strip is hidden).
      - A watched reputation ("Show as Experience Bar" in the Reputation tab)
        stacks above it, exactly where it sits above the XP bar while levelling,
        and the extra action bars, pet bar, chat and bags move up to make room.
      - Untick the setting (or below max level) and Blizzard's own layout comes
        back unchanged.

      How the action bars are made to move: Blizzard only raises them for a
      reputation bar when MainMenuExpBar is shown. While the Paragon bar owns
      the slot, MainMenuExpBar is kept shown but fully transparent and not
      clickable, so Blizzard's own positioning code does the rest. No Blizzard
      tables or protected frames are changed.

    ELVUI
      ElvUI hides the Blizzard main bar, so the Paragon bar becomes a
      free-standing ElvUI-styled bar with a mover ("Paragon Bar" in /moveui).
      It starts on top of ElvUI's experience bar (which ElvUI hides at max
      level), using the same size and orientation.

    Toggle: the "Show XP bar on main interface" checkbox in the Paragon window,
    or /paragon bar. Saved per account in ParagonAnniversaryDB.showExpBar.
]]

ParagonExpData = {
    currentXP = 0,
    maxXP = 150,
}

local mode            -- nil until set up, then "blizzard" or "elvui"
local ownsSlot = false -- true while the Paragon bar holds the Blizzard XP slot
local lastRepShown    -- watched reputation visibility last time we laid out
local framePositionsPending = false
local inLayout = false

-- ============================================================================
-- SETTINGS
-- ============================================================================

--- True if the player turned the bar on (defaults to off until the DB loads)
function Paragon_IsExpBarEnabled()
    return ParagonAnniversaryDB ~= nil and ParagonAnniversaryDB.showExpBar == true
end

--- Turns the bar on or off, saves it, and syncs the checkbox in the window
function Paragon_SetExpBarEnabled(enabled)
    if not ParagonAnniversaryDB then return end
    ParagonAnniversaryDB.showExpBar = enabled and true or false

    local checkbox = UIParagon and UIParagon.ShowMainMenuXP
    if checkbox then
        checkbox:SetChecked(ParagonAnniversaryDB.showExpBar)
    end

    ParagonExpBar_Refresh()
end

local function AtMaxLevel(level)
    level = level or UnitLevel("player")
    return level >= MAX_PLAYER_LEVEL
end

local function ShouldShow(level)
    return Paragon_IsExpBarEnabled() and AtMaxLevel(level)
end

-- ============================================================================
-- DEFAULT UI MODE
-- ============================================================================

--- Asks Blizzard to re-run its bottom-of-screen layout (action bars, chat,
--- bags). Waits until combat ends if needed, as Blizzard's own code does.
local function RequestFramePositions()
    if InCombatLockdown() then
        framePositionsPending = true
    else
        framePositionsPending = false
        UIParent_ManageFramePositions()
        if updateContainerFrameAnchors then
            updateContainerFrameAnchors()
        end
    end
end

--- Puts a watched reputation bar in the "stacked above the XP bar" layout.
--- Same settings Blizzard uses below max level (ReputationWatchBar_Update).
local function StackReputationBar()
    ReputationWatchStatusBar:SetHeight(8)
    ReputationWatchBar:ClearAllPoints()
    ReputationWatchBar:SetPoint("BOTTOM", MainMenuBar, "TOP", 0, -3)
    ReputationWatchStatusBarText:SetPoint("CENTER", ReputationWatchBarOverlayFrame, "CENTER", 0, 3)
    ReputationWatchBarTexture0:Show()
    ReputationWatchBarTexture1:Show()
    ReputationWatchBarTexture2:Show()
    ReputationWatchBarTexture3:Show()
    ReputationXPBarTexture0:Hide()
    ReputationXPBarTexture1:Hide()
    ReputationXPBarTexture2:Hide()
    ReputationXPBarTexture3:Hide()
end

--- Hides Blizzard's XP bar from view while keeping it "shown" for layout
local function MaskBlizzardExpBar()
    MainMenuExpBar:Show()
    MainMenuExpBar:SetAlpha(0)
    MainMenuExpBar:EnableMouse(false)
    MainMenuBarMaxLevelBar:Hide()
    ExhaustionTick:Hide()
end

local function UnmaskBlizzardExpBar()
    MainMenuExpBar:SetAlpha(1)
    MainMenuExpBar:EnableMouse(true)
end

--- Lays out the bottom bars for the current state. Runs after every
--- ReputationWatchBar_Update (rep gained, watched faction changed, level up)
--- and whenever the Paragon setting changes.
-- @param level number|nil New player level (PLAYER_LEVEL_UP passes it before UnitLevel updates)
local function ApplyBlizzardLayout(level)
    if mode ~= "blizzard" or inLayout then return end
    inLayout = true

    local repShown = ReputationWatchBar:IsShown() and true or false

    if ShouldShow(level) then
        MaskBlizzardExpBar()
        if repShown then
            StackReputationBar()
        end

        ParagonExpBar:ClearAllPoints()
        ParagonExpBar:SetPoint("TOP", MainMenuBar, "TOP", 0, 0)
        ParagonExpBar:Show()

        if not ownsSlot or repShown ~= lastRepShown then
            ownsSlot = true
            lastRepShown = repShown
            RequestFramePositions()
        end
    else
        ParagonExpBar:Hide()
        if ownsSlot then
            ownsSlot = false
            lastRepShown = nil
            UnmaskBlizzardExpBar()
            -- Let Blizzard put its own bars back (max level strip, rep in the XP slot)
            ReputationWatchBar_Update(level)
            RequestFramePositions()
        end
    end

    inLayout = false
end

local function SetupBlizzardMode()
    mode = "blizzard"

    -- Sit just above the (transparent) Blizzard XP bar so the mouse reaches us
    ParagonExpBar:SetFrameLevel(MainMenuExpBar:GetFrameLevel() + 1)
    ParagonExpBarOverlayFrame:SetFrameLevel(ParagonExpBar:GetFrameLevel() + 2)

    -- Re-apply our layout every time Blizzard redoes its own
    hooksecurefunc("ReputationWatchBar_Update", function(newLevel)
        ApplyBlizzardLayout(newLevel)
    end)
end

-- ============================================================================
-- ELVUI MODE
-- ============================================================================

local function SetupElvUIMode()
    mode = "elvui"

    local E = unpack(ElvUI)
    local bar = ParagonExpBar
    local statusBar = bar.StatusBar

    bar:SetParent(UIParent)
    bar:SetFrameStrata("LOW")
    bar:SetFrameLevel(5)
    ParagonExpBarOverlayFrame:SetFrameLevel(bar:GetFrameLevel() + 3)

    -- ElvUI draws its own border, so drop the Blizzard divider art
    for i = 0, 3 do
        _G["ParagonExpBarStatusBarTexture" .. i]:Hide()
    end
    ParagonExpBarStatusBarBackground:Hide()

    -- Start on ElvUI's experience bar (same size and orientation)
    local ref = _G.ElvUI_ExperienceBar
    local width, height, vertical = 400, 10, false
    if ref and ref:GetWidth() > 0 and ref:GetHeight() > 0 then
        width, height = ref:GetWidth(), ref:GetHeight()
        local refBar = ref.statusBar or ref.StatusBar
        vertical = refBar and refBar.GetOrientation and refBar:GetOrientation() == "VERTICAL"
    end

    bar:ClearAllPoints()
    if ref then
        bar:SetPoint("CENTER", ref, "CENTER", 0, 0)
    else
        bar:SetPoint("BOTTOM", UIParent, "BOTTOM", 0, 120)
    end
    bar:SetWidth(width)
    bar:SetHeight(height)

    if bar.SetTemplate then
        bar:SetTemplate("Transparent")
    end

    local inset = (E.Border or 1) + (E.Spacing or 0)
    statusBar:ClearAllPoints()
    statusBar:SetPoint("TOPLEFT", bar, "TOPLEFT", inset, -inset)
    statusBar:SetPoint("BOTTOMRIGHT", bar, "BOTTOMRIGHT", -inset, inset)
    if E.media and E.media.normTex then
        statusBar:SetStatusBarTexture(E.media.normTex)
    end
    if vertical then
        statusBar:SetOrientation("VERTICAL")
    end

    if ParagonExpBarOverlayFrameText.FontTemplate then
        ParagonExpBarOverlayFrameText:FontTemplate()
    end

    -- Movable with /moveui, position saved by ElvUI
    if E.CreateMover then
        E:CreateMover(bar, "ParagonExpBarMover", "Paragon Bar")
    end
end

-- ============================================================================
-- REFRESH / EVENTS
-- ============================================================================

--- Shows, hides and positions the bar for the current settings and level
-- @param level number|nil Player level, if known to be newer than UnitLevel
function ParagonExpBar_Refresh(level)
    if not ParagonExpBar or not mode then return end

    if mode == "blizzard" then
        ApplyBlizzardLayout(level)
    elseif ShouldShow(level) then
        ParagonExpBar:Show()
    else
        ParagonExpBar:Hide()
    end
end

function ParagonExpBar_OnLoad(self)
    self.textLocked = false
    ParagonExpBarOverlayFrameText:Hide()

    self:RegisterEvent("PLAYER_ENTERING_WORLD")
    self:RegisterEvent("PLAYER_LEVEL_UP")
    self:RegisterEvent("PLAYER_REGEN_ENABLED")
    self:RegisterEvent("CVAR_UPDATE")
end

function ParagonExpBar_OnEvent(self, event, ...)
    if event == "PLAYER_ENTERING_WORLD" then
        -- Set up once, after every addon (and ElvUI) has finished loading
        if not mode then
            if ElvUI and IsAddOnLoaded("ElvUI") then
                SetupElvUIMode()
            else
                SetupBlizzardMode()
            end
        end
        ParagonExpBar_ApplyTextSetting()
        ParagonExpBar_Update()
        ParagonExpBar_Refresh()
    elseif event == "PLAYER_LEVEL_UP" then
        ParagonExpBar_Refresh((...))
    elseif event == "PLAYER_REGEN_ENABLED" then
        if framePositionsPending then
            RequestFramePositions()
        end
    elseif event == "CVAR_UPDATE" then
        ParagonExpBar_ApplyTextSetting()
    end
end

-- ============================================================================
-- VALUES AND TEXT
-- ============================================================================

--- Pushes the current XP values into the bar and its text
function ParagonExpBar_Update()
    if not ParagonExpBar or not ParagonExpBar.StatusBar then return end

    local maxXP = ParagonExpData.maxXP
    if not maxXP or maxXP <= 0 then maxXP = 1 end

    ParagonExpBar.StatusBar:SetMinMaxValues(0, maxXP)
    ParagonExpBar.StatusBar:SetValue(ParagonExpData.currentXP or 0)
    ParagonExpBar_UpdateText()
end

function ParagonExpBar_UpdateText()
    if not ParagonExpBarOverlayFrameText then return end

    local currentXP = ParagonExpData.currentXP or 0
    local maxXP = ParagonExpData.maxXP or 0

    local Locales = GetLocaleTable and GetLocaleTable()
    local experienceText = Locales and Locales.PARAGON_EXPERIENCE_TEXT or "Paragon %d / %d (%d%%)"

    local percentage = 0
    if maxXP > 0 then
        percentage = math.floor((currentXP / maxXP) * 100)
    end

    ParagonExpBarOverlayFrameText:SetText(string.format(experienceText, currentXP, maxXP, percentage))
end

--- Called by the network layer when the server sends Paragon XP
function ParagonExpBar_SetExperience(current, max)
    ParagonExpData.currentXP = current or 0
    ParagonExpData.maxXP = max or 150
    ParagonExpBar_Update()
end

--- Follows Blizzard's "Always Show XP Text" option (Interface > Status Text)
function ParagonExpBar_ApplyTextSetting()
    if not ParagonExpBar then return end
    if GetCVar("xpBarText") == "1" then
        ShowParagonExpBarText("lock")
    else
        HideParagonExpBarText("unlock")
    end
end

function ParagonExpBar_OnEnter(self)
    ParagonExpBarOverlayFrameText:Show()
end

function ParagonExpBar_OnLeave(self)
    if not self.textLocked then
        ParagonExpBarOverlayFrameText:Hide()
    end
end

--- Show the text; "lock" keeps it on screen without hovering
function ShowParagonExpBarText(lock)
    if not ParagonExpBar then return end
    if lock then
        ParagonExpBar.textLocked = true
    end
    ParagonExpBarOverlayFrameText:Show()
end

--- Hide the text; "unlock" returns to show-on-hover
function HideParagonExpBarText(unlock)
    if not ParagonExpBar then return end
    if unlock then
        ParagonExpBar.textLocked = false
    end
    if not ParagonExpBar.textLocked then
        ParagonExpBarOverlayFrameText:Hide()
    end
end
