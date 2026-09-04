local ADDON_NAME, addon = ...

addon.name = ADDON_NAME
addon.L = LibStub:GetLibrary("AceLocale-3.0"):GetLocale(ADDON_NAME)

local L = addon.L
local Theme = addon.Theme
local MainWindow = addon.MainWindow
local SecureDisenchant = addon.SecureDisenchant

BINDING_HEADER_DISENCHANTUM = L["BINDING_HEADER"]
_G["BINDING_NAME_CLICK DisenchantumSecureButton:LeftButton"] = L["BINDING_CAST"]

local eventFrame = CreateFrame("Frame")

function addon.UpdateMinimapIcon()
    local LDBIcon = LibStub("LibDBIcon-1.0", true)
    if not LDBIcon or not addon.db then
        return
    end

    if addon.db.global.minimap.hide then
        LDBIcon:Hide(ADDON_NAME)
    else
        LDBIcon:Show(ADDON_NAME)
    end
end

function addon.UpdateCompartmentIcon()
    local LDBIcon = LibStub("LibDBIcon-1.0", true)
    if not LDBIcon or not addon.db or not LDBIcon.IsButtonCompartmentAvailable then
        return
    end
    if not LDBIcon:IsButtonCompartmentAvailable() then
        return
    end

    if addon.db.global.minimap.showInCompartment then
        LDBIcon:AddButtonToCompartment(ADDON_NAME)
    else
        LDBIcon:RemoveButtonFromCompartment(ADDON_NAME)
        addon.db.global.minimap.showInCompartment = false
    end
end

local function registerMinimap()
    local LDB = LibStub("LibDataBroker-1.1", true)
    local LDBIcon = LibStub("LibDBIcon-1.0", true)
    if not LDB or not LDBIcon then
        return
    end

    local dataObject = LDB:NewDataObject(ADDON_NAME, {
        type = "launcher",
        text = L["ADDON_NAME"],
        icon = "Interface\\AddOns\\" .. ADDON_NAME .. "\\Media\\icon.png",
        OnClick = function()
            MainWindow:Toggle()
        end,
        OnTooltipShow = function(tooltip)
            local r, g, b = Theme.UnpackColor(Theme.colors.accent)
            tooltip:AddLine(L["ADDON_NAME"], r, g, b)
            tooltip:AddLine(L["MINIMAP_TOOLTIP"], 0.9, 0.9, 0.9, true)
            tooltip:AddLine("/de", 0.65, 0.65, 0.65)
        end,
    })

    LDBIcon:Register(ADDON_NAME, dataObject, addon.db.global.minimap)
    addon.UpdateMinimapIcon()
    addon.UpdateCompartmentIcon()
end

local function registerSlashCommands()
    SLASH_DISENCHANTUM1 = "/de"
    SLASH_DISENCHANTUM2 = "/disenchantum"
    SlashCmdList.DISENCHANTUM = function()
        MainWindow:Toggle()
    end
end

local pendingItemInfoRefresh = false
local professionButton
local professionHooksRegistered = false

local function refreshRuntime()
    SecureDisenchant.ApplyCurrent()
    if SecureDisenchant.pendingLoot then
        SecureDisenchant.pendingUiRefresh = true
        return
    end
    if MainWindow.frame and MainWindow.frame:IsShown() then
        MainWindow:Refresh()
    end
end

local function scheduleItemInfoRefresh()
    if not MainWindow.frame or not MainWindow.frame:IsShown() then
        return
    end
    if SecureDisenchant.pendingLoot then
        SecureDisenchant.pendingUiRefresh = true
        return
    end
    if pendingItemInfoRefresh then
        return
    end

    pendingItemInfoRefresh = true
    C_Timer.After(0.25, function()
        pendingItemInfoRefresh = false
        if SecureDisenchant.pendingLoot then
            SecureDisenchant.pendingUiRefresh = true
            return
        end
        if MainWindow.frame and MainWindow.frame:IsShown() then
            MainWindow:Refresh()
        end
    end)
end

local function isEnchantingProfessionOpen()
    if not ProfessionsFrame or not ProfessionsFrame:IsShown() then
        return false
    end
    if ProfessionsFrame.TabSystem and not ProfessionsFrame.TabSystem:IsShown() then
        return false
    end
    if ProfessionsUtil and ProfessionsUtil.IsCraftingMinimized and ProfessionsUtil.IsCraftingMinimized() then
        return false
    end
    local info = C_TradeSkillUI and C_TradeSkillUI.GetBaseProfessionInfo and C_TradeSkillUI.GetBaseProfessionInfo()
    return info and Enum.Profession and info.profession == Enum.Profession.Enchanting
end

local function isElvUILoaded()
    if C_AddOns and C_AddOns.IsAddOnLoaded then
        local loadedOrLoading, loaded = C_AddOns.IsAddOnLoaded("ElvUI")
        if loaded or loadedOrLoading then
            return true
        end
    end
    return _G.ElvUI ~= nil
end

local function getLastVisibleProfessionTab()
    local tabSystem = ProfessionsFrame and ProfessionsFrame.TabSystem
    if not tabSystem then
        return nil
    end

    local lastTab
    if tabSystem.tabs then
        for index = 1, #tabSystem.tabs do
            local tab = tabSystem.tabs[index]
            if tab and tab:IsShown() then
                lastTab = tab
            end
        end
    end
    if lastTab then
        return lastTab
    end
    if tabSystem.GetTabButton then
        return tabSystem:GetTabButton(1)
    end
    return nil
end

-- ElvUI HandleTab insets the visible chrome inside the 32px tab
-- (Retail: TOPLEFT 3,-1/-3 and BOTTOMRIGHT -3,3). Filling the whole
-- button would cover the padding between the window and the tabs.
local function applyElvUITabChrome(button, sample)
    local chrome = button.backdrop
    if not chrome then
        return
    end

    chrome:SetFrameLevel(math.max(0, (button:GetFrameLevel() or 1) - 1))
    chrome:ClearAllPoints()

    local sampleBack = sample and sample.backdrop
    local copied = false
    if sampleBack and sampleBack.GetNumPoints then
        for index = 1, sampleBack:GetNumPoints() do
            local point, _, relativePoint, x, y = sampleBack:GetPoint(index)
            if point then
                chrome:SetPoint(point, button, relativePoint or point, x or 0, y or 0)
                copied = true
            end
        end
    end
    if not copied then
        chrome:SetPoint("TOPLEFT", button, "TOPLEFT", 3, -3)
        chrome:SetPoint("BOTTOMRIGHT", button, "BOTTOMRIGHT", -3, 3)
    end
end

local function applyProfessionTabTextColor(button)
    if button.Text and button.Text.SetTextColor then
        button.Text:SetTextColor(Theme.UnpackColor(Theme.colors.accentAlt))
    end
end

local function sizeProfessionTab(button)
    local sample = getLastVisibleProfessionTab()
    if sample and sample.Text and button.Text and sample.Text.GetFont and button.Text.SetFont then
        local fontPath, fontSize, fontFlags = sample.Text:GetFont()
        if fontPath and fontSize then
            button.Text:SetFont(fontPath, fontSize, fontFlags)
        end
    end
    applyProfessionTabTextColor(button)

    local textWidth = 0
    if button.Text and button.Text.GetStringWidth then
        textWidth = button.Text:GetStringWidth() or 0
    end
    local width = math.min(164, math.max(80, math.ceil(textWidth + 24)))
    button:SetWidth(width)
    if button.Text then
        button.Text:SetWidth(width - 10)
        if button.Text.SetWordWrap then
            button.Text:SetWordWrap(false)
        end
        if button.Text.SetMaxLines then
            button.Text:SetMaxLines(1)
        end
    end

    local xOffset = 1
    local tabSystem = ProfessionsFrame and ProfessionsFrame.TabSystem
    if tabSystem and tabSystem.spacing then
        xOffset = tabSystem.spacing
    end

    button:ClearAllPoints()
    if sample then
        button:SetPoint("TOPLEFT", sample, "TOPRIGHT", xOffset, 0)
        button:SetPoint("BOTTOMLEFT", sample, "BOTTOMRIGHT", xOffset, 0)
    elseif tabSystem then
        local height = 32
        if tabSystem.GetHeight then
            height = tabSystem:GetHeight() or height
        end
        button:SetHeight(height)
        button:SetPoint("TOPLEFT", tabSystem, "TOPRIGHT", xOffset, 0)
        button:SetPoint("BOTTOMLEFT", tabSystem, "BOTTOMRIGHT", xOffset, 0)
    end

    applyElvUITabChrome(button, sample)
end

local function styleProfessionTabElvUI(button)
    local chrome = CreateFrame("Frame", nil, button, "BackdropTemplate")
    chrome:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8X8",
        edgeFile = "Interface\\Buttons\\WHITE8X8",
        edgeSize = 1,
    })

    local backdropR, backdropG, backdropB, backdropA = 0, 0, 0, 1
    local borderR, borderG, borderB, borderA = 0, 0, 0, 1
    local elv = _G.ElvUI and _G.ElvUI[1]
    if elv and elv.media then
        local backdrop = elv.media.backdropcolor
        if type(backdrop) == "table" then
            backdropR = backdrop[1] or 0
            backdropG = backdrop[2] or 0
            backdropB = backdrop[3] or 0
            backdropA = backdrop[4] or 1
        end
        local border = elv.media.bordercolor
        if type(border) == "table" then
            borderR = border[1] or 0
            borderG = border[2] or 0
            borderB = border[3] or 0
            borderA = border[4] or 1
        end
    end
    chrome:SetBackdropColor(backdropR, backdropG, backdropB, backdropA)
    chrome:SetBackdropBorderColor(borderR, borderG, borderB, borderA)
    button.backdrop = chrome

    button.Text = button:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    button.Text:SetPoint("CENTER", button, "CENTER", 0, 0)
    button:SetFontString(button.Text)
    button:SetNormalFontObject("GameFontNormalSmall")
    button:SetHighlightFontObject("GameFontHighlightSmall")
end

local function styleProfessionTabBlizzard(button)
    if button.HandleRotation then
        button:HandleRotation()
    end
    if button.SetTabSelected then
        button:SetTabSelected(false)
    end
end

local function ensureProfessionButton()
    if professionButton or not ProfessionsFrame or not ProfessionsFrame.TabSystem then
        return
    end

    if isElvUILoaded() then
        professionButton = CreateFrame("Button", "DisenchantumProfessionButton", ProfessionsFrame)
    else
        professionButton = CreateFrame("Button", "DisenchantumProfessionButton", ProfessionsFrame, "TabSystemButtonArtTemplate")
    end
    if isElvUILoaded() then
        styleProfessionTabElvUI(professionButton)
        professionButton:SetText(L["BUTTON_OPEN_DISENCHANTER"])
    else
        professionButton:SetText(L["BUTTON_OPEN_DISENCHANTER"])
        styleProfessionTabBlizzard(professionButton)
    end
    sizeProfessionTab(professionButton)
    professionButton:SetFrameLevel((ProfessionsFrame:GetFrameLevel() or 1) + 10)
    professionButton:SetScript("OnClick", function()
        MainWindow:Open()
    end)
    professionButton:SetScript("OnEnter", function(self)
        if self.Text and self.Text.IsTruncated and self.Text:IsTruncated() then
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT", -12, -6)
            GameTooltip:SetText(self.Text:GetText() or "", 1, 1, 1)
            GameTooltip:Show()
        end
    end)
    professionButton:SetScript("OnLeave", function(self)
        applyProfessionTabTextColor(self)
        if GameTooltip then
            GameTooltip:Hide()
        end
    end)
    ProfessionsFrame.TabSystem:HookScript("OnShow", function()
        addon.UpdateProfessionButton()
    end)
    ProfessionsFrame.TabSystem:HookScript("OnHide", function()
        addon.UpdateProfessionButton()
    end)
end

function addon.UpdateProfessionButton()
    ensureProfessionButton()
    if not professionButton then
        return
    end
    professionButton:SetShown(isEnchantingProfessionOpen())
    if not professionButton:IsShown() then
        return
    end
    sizeProfessionTab(professionButton)
    C_Timer.After(0, function()
        if professionButton and professionButton:IsShown() then
            sizeProfessionTab(professionButton)
        end
    end)
end

local function registerProfessionHooks()
    if professionHooksRegistered or not EventRegistry then
        return
    end

    professionHooksRegistered = true
    EventRegistry:RegisterCallback("ProfessionsFrame.Show", addon.UpdateProfessionButton, addon)
    EventRegistry:RegisterCallback("ProfessionsFrame.Hide", addon.UpdateProfessionButton, addon)
    EventRegistry:RegisterCallback("ProfessionsFrame.TabSet", addon.UpdateProfessionButton, addon)
    addon.UpdateProfessionButton()
end

eventFrame:SetScript("OnEvent", function(_, eventName, unitTarget, _, spellID)
    if eventName == "PLAYER_LOGIN" then
        addon.InitializeDatabase()
        registerMinimap()
        registerSlashCommands()
        MainWindow:Initialize()
        SecureDisenchant.ApplyCurrent()
        registerProfessionHooks()
        return
    end

    if eventName == "ADDON_LOADED" then
        if unitTarget == "Blizzard_Professions" then
            registerProfessionHooks()
            addon.UpdateProfessionButton()
        end
        return
    end

    if eventName == "UI_SCALE_CHANGED" or eventName == "DISPLAY_SIZE_CHANGED" then
        if MainWindow.frame then
            MainWindow:ApplyWindowScale()
        end
        return
    end

    if eventName == "TRADE_SKILL_LIST_UPDATE" then
        addon.UpdateProfessionButton()
        return
    end

    if eventName == "GET_ITEM_INFO_RECEIVED" then
        scheduleItemInfoRefresh()
        return
    end

    if eventName == "LOOT_READY" or eventName == "LOOT_OPENED" then
        SecureDisenchant.TryLoot()
        return
    end

    if eventName == "LOOT_CLOSED" then
        SecureDisenchant.OnLootClosed()
        return
    end

    if eventName == "PLAYER_REGEN_ENABLED" then
        SecureDisenchant.OnLeaveCombat()
        refreshRuntime()
        return
    end

    if eventName == "PLAYER_REGEN_DISABLED" then
        SecureDisenchant.UpdateVisual()
        if MainWindow.frame and MainWindow.frame:IsShown() then
            MainWindow:RefreshQueueCount()
        end
        return
    end

    if eventName == "UPDATE_BINDINGS" then
        SecureDisenchant.UpdateHotkey()
        return
    end

    if eventName == "BAG_UPDATE_DELAYED" or eventName == "PLAYER_ENTERING_WORLD" or eventName == "SPELLS_CHANGED" then
        refreshRuntime()
        return
    end

    if unitTarget ~= "player" then
        return
    end

    if eventName == "UNIT_SPELLCAST_START" then
        SecureDisenchant.OnCastStart(spellID)
        return
    end

    if eventName == "UNIT_SPELLCAST_INTERRUPTED"
        or eventName == "UNIT_SPELLCAST_FAILED"
        or eventName == "UNIT_SPELLCAST_FAILED_QUIET"
    then
        SecureDisenchant.OnCastStop(spellID, true)
        return
    end

    if eventName == "UNIT_SPELLCAST_STOP" then
        SecureDisenchant.OnCastStop(spellID, false)
        return
    end

    if eventName == "UNIT_SPELLCAST_SUCCEEDED" then
        SecureDisenchant.OnCastSucceeded(spellID)
    end
end)

eventFrame:RegisterEvent("PLAYER_LOGIN")
eventFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
eventFrame:RegisterEvent("ADDON_LOADED")
eventFrame:RegisterEvent("UI_SCALE_CHANGED")
eventFrame:RegisterEvent("DISPLAY_SIZE_CHANGED")
eventFrame:RegisterEvent("TRADE_SKILL_LIST_UPDATE")
eventFrame:RegisterEvent("PLAYER_REGEN_ENABLED")
eventFrame:RegisterEvent("PLAYER_REGEN_DISABLED")
eventFrame:RegisterEvent("UPDATE_BINDINGS")
eventFrame:RegisterEvent("BAG_UPDATE_DELAYED")
eventFrame:RegisterEvent("SPELLS_CHANGED")
eventFrame:RegisterEvent("GET_ITEM_INFO_RECEIVED")
eventFrame:RegisterEvent("LOOT_READY")
eventFrame:RegisterEvent("LOOT_OPENED")
eventFrame:RegisterEvent("LOOT_CLOSED")
eventFrame:RegisterEvent("UNIT_SPELLCAST_START")
eventFrame:RegisterEvent("UNIT_SPELLCAST_STOP")
eventFrame:RegisterEvent("UNIT_SPELLCAST_INTERRUPTED")
eventFrame:RegisterEvent("UNIT_SPELLCAST_FAILED")
eventFrame:RegisterEvent("UNIT_SPELLCAST_FAILED_QUIET")
eventFrame:RegisterEvent("UNIT_SPELLCAST_SUCCEEDED")
