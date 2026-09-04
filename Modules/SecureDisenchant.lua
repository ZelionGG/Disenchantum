local _, addon = ...

local Queue = addon.Queue
local Eligibility = addon.Eligibility
local Theme = addon.Theme
local L

local DISENCHANT_SPELL_ID = addon.DISENCHANT_SPELL_ID
local BUTTON_NAME = "DisenchantumSecureButton"
local BINDING_COMMAND = "CLICK " .. BUTTON_NAME .. ":LeftButton"
-- Only auto-loot the window that opens right after our DE, not world loot.
local LOOT_PENDING_SECONDS = 2

local SecureDisenchant = {
    button = nil,
    pendingApply = false,
    allowGcdFill = false,
    pendingLoot = false,
    pendingLootUntil = 0,
    lootTaken = false,
    pendingUiRefresh = false,
}

addon.SecureDisenchant = SecureDisenchant

local Session = {
    itemsDisenchanted = 0,
    reagents = {},
    -- One record pass per loot window (LOOT_READY then LOOT_OPENED).
    lootRecorded = false,
}

addon.Session = Session

local function getButton()
    return SecureDisenchant.button
end

local function disenchantLabel()
    return Eligibility.GetSpellName() or "Disenchant"
end

local function setHoldHover(active)
    -- Keep primary hover chrome while Disenchant is casting, even if the cursor left.
    local button = getButton()
    if not button then
        return
    end
    active = active == true
    if button.holdHover == active then
        return
    end
    button.holdHover = active
    Theme.UpdateButtonColors(button)
end

function Session.Reset()
    Session.itemsDisenchanted = 0
    wipe(Session.reagents)
    Session.lootRecorded = false
    if addon.MainWindow and addon.MainWindow.RefreshSession then
        addon.MainWindow:RefreshSession()
    end
end

local reagentsList = {}

function Session.GetReagents()
    wipe(reagentsList)
    for _, entry in pairs(Session.reagents) do
        reagentsList[#reagentsList + 1] = entry
    end
    table.sort(reagentsList, function(left, right)
        if left.count ~= right.count then
            return left.count > right.count
        end
        local leftName = left.itemName or ""
        local rightName = right.itemName or ""
        if strcmputf8i then
            return strcmputf8i(leftName, rightName) < 0
        end
        return leftName < rightName
    end)
    return reagentsList
end

function Session.RecordLootWindow()
    if Session.lootRecorded then
        return
    end

    local slotCount = GetNumLootItems and GetNumLootItems() or 0
    if slotCount <= 0 then
        return
    end

    for slotIndex = 1, slotCount do
        local slotType = GetLootSlotType and GetLootSlotType(slotIndex)
        if slotType == Enum.LootSlotType.Item then
            local texture, itemName, quantity, currencyID, quality = GetLootSlotInfo(slotIndex)
            if not currencyID then
                local link = GetLootSlotLink and GetLootSlotLink(slotIndex)
                local itemID, icon
                if link then
                    itemID, _, _, _, icon = C_Item.GetItemInfoInstant(link)
                end
                if itemID then
                    local entry = Session.reagents[itemID]
                    if not entry then
                        local expansionID = select(15, C_Item.GetItemInfo(itemID))
                        if expansionID == nil and C_Item.RequestLoadItemDataByID then
                            C_Item.RequestLoadItemDataByID(itemID)
                        end
                        entry = {
                            itemID = itemID,
                            itemName = itemName,
                            itemLink = link,
                            icon = icon or texture,
                            quality = quality,
                            expansionID = expansionID,
                            count = 0,
                        }
                        Session.reagents[itemID] = entry
                    end
                    entry.count = entry.count + (quantity or 1)
                end
            end
        end
    end

    Session.lootRecorded = true
    if addon.MainWindow and addon.MainWindow.RefreshSession then
        addon.MainWindow:RefreshSession()
    end
end

function SecureDisenchant.ApplyCurrent()
    local button = getButton()
    if not button then
        return
    end

    if InCombatLockdown() then
        SecureDisenchant.pendingApply = true
        return
    end

    SecureDisenchant.pendingApply = false
    Queue.RefreshLocations()
    local entry = Queue.GetCurrent()
    local knowsSpell = Eligibility.PlayerKnowsDisenchant()

    if knowsSpell and entry and entry.bag and entry.slot then
        button:SetAttribute("type", "spell")
        button:SetAttribute("spell", DISENCHANT_SPELL_ID)
        button:SetAttribute("target-bag", entry.bag)
        button:SetAttribute("target-slot", entry.slot)
    else
        button:SetAttribute("type", nil)
        button:SetAttribute("spell", nil)
        button:SetAttribute("target-bag", nil)
        button:SetAttribute("target-slot", nil)
    end

    SecureDisenchant.UpdateVisual()
end

function SecureDisenchant.UpdateVisual()
    local button = getButton()
    if not button then
        return
    end

    L = L or addon.L
    local knowsSpell = Eligibility.PlayerKnowsDisenchant()
    local entry = Queue.GetCurrent()
    local inCombat = InCombatLockdown()
    local canUse = knowsSpell == true and entry ~= nil and not inCombat

    local label = disenchantLabel()
    if entry and entry.itemName then
        label = label .. "  ·  " .. entry.itemName
    end
    button.baseLabel = label
    button:SetText(label)

    if button.Icon then
        local icon = (entry and entry.icon) or Eligibility.GetSpellTexture()
        button.Icon:SetTexture(icon)
        button.Icon:SetDesaturated(not canUse)
        button.Icon:Show()
    end

    button:SetVisualEnabled(canUse)
    SecureDisenchant.UpdateHotkey()
end

-- GetBindingText(key, 1) / a truthy 2nd arg abbreviates (a-s-Y). Do not pass "KEY_".
local BINDING_MODIFIER_LABEL = {
    ALT = "Alt",
    LALT = "Left Alt",
    RALT = "Right Alt",
    SHIFT = "Shift",
    LSHIFT = "Left Shift",
    RSHIFT = "Right Shift",
    CTRL = "Ctrl",
    LCTRL = "Left Ctrl",
    RCTRL = "Right Ctrl",
}

local function prettyBindingToken(token)
    local upper = strupper(token)
    local modifier = BINDING_MODIFIER_LABEL[upper]
    if modifier then
        return modifier
    end
    local named = _G["KEY_" .. upper]
    if named and named ~= "" then
        return named
    end
    return token
end

local function formatBindingLabel(key)
    local parts = {}
    for token in string.gmatch(key, "[^-]+") do
        parts[#parts + 1] = prettyBindingToken(token)
    end
    if #parts == 0 then
        return ""
    end
    return "(" .. table.concat(parts, " + ") .. ")"
end

function SecureDisenchant.UpdateHotkey()
    local button = getButton()
    if not button or not button.HotKey then
        return
    end

    local key = GetBindingKey(BINDING_COMMAND)
    local text = key and formatBindingLabel(key) or ""
    if text == "" then
        button.HotKey:SetText("")
        button.HotKey:Hide()
        return
    end

    button.HotKey:SetText(text)
    button.HotKey:Show()
end

local function hideProgressFill(button)
    if button and button.cooldownFill then
        button.cooldownFill:Hide()
    end
    if button and button.baseLabel and button.Label and button.Label:GetText() ~= button.baseLabel then
        button:SetText(button.baseLabel)
    end
end

local function applyCastFill(button)
    button.cooldownFill:SetColorTexture(Theme.UnpackColor(Theme.colors.accent))
    button.cooldownFill:SetAlpha(0.55)
end

local function setProgressFill(button, ratio, isCast)
    local width = button:GetWidth() or 1
    button.cooldownFill:SetWidth(math.max(1, width * ratio))
    if button.fillIsCast ~= isCast then
        button.fillIsCast = isCast
        if isCast then
            applyCastFill(button)
        else
            button.cooldownFill:SetColorTexture(0, 0, 0, 0.45)
            button.cooldownFill:SetAlpha(1)
        end
    end
    button.cooldownFill:Show()
end

function SecureDisenchant.UpdateCooldown()
    local button = getButton()
    if not button or not button.cooldownFill then
        return
    end

    local cooldownInfo = C_Spell.GetSpellCooldown(DISENCHANT_SPELL_ID)
    if not cooldownInfo or not cooldownInfo.isActive or cooldownInfo.duration <= 0 then
        SecureDisenchant.allowGcdFill = false
        button.cooldownFill:Hide()
        return
    end

    local remaining = (cooldownInfo.startTime + cooldownInfo.duration) - GetTime()
    if remaining <= 0 then
        SecureDisenchant.allowGcdFill = false
        button.cooldownFill:Hide()
        return
    end

    setProgressFill(button, math.max(0, math.min(1, remaining / cooldownInfo.duration)), false)
end

function SecureDisenchant.UpdateProgress()
    local button = getButton()
    if not button or not button.cooldownFill then
        return
    end

    local _, _, _, startTimeMS, endTimeMS, _, _, _, spellID = UnitCastingInfo("player")
    if spellID == DISENCHANT_SPELL_ID and startTimeMS and endTimeMS then
        local remaining = (endTimeMS / 1000) - GetTime()
        local duration = (endTimeMS - startTimeMS) / 1000
        if remaining > 0 and duration > 0 then
            local elapsed = 1 - (remaining / duration)
            setProgressFill(button, math.max(0, math.min(1, elapsed)), true)
            local base = button.baseLabel or disenchantLabel()
            local fmt = (L and L["FMT_CAST_REMAINING"]) or "%.1fs"
            button:SetText(base .. "  ·  " .. fmt:format(remaining))
            setHoldHover(true)
            return
        end
    end

    setHoldHover(false)

    if button.baseLabel and button.Label and button.Label:GetText() ~= button.baseLabel then
        button:SetText(button.baseLabel)
    end

    if SecureDisenchant.allowGcdFill then
        SecureDisenchant.UpdateCooldown()
    else
        button.cooldownFill:Hide()
    end
end

function SecureDisenchant.EnsureButton(parent)
    if SecureDisenchant.button then
        return SecureDisenchant.button
    end

    L = L or addon.L
    local button = Theme.CreateButton(
        parent,
        360,
        44,
        disenchantLabel(),
        "primary",
        BUTTON_NAME,
        "SecureActionButtonTemplate"
    )
    button:RegisterForClicks("AnyUp", "AnyDown")
    if not InCombatLockdown() then
        button:SetAttribute("useOnKeyDown", false)
    end

    button.skipPlaceLabel = true

    local content = CreateFrame("Frame", nil, button)
    content:SetHeight(28)
    content:EnableMouse(false)
    button.Content = content

    button.Icon = content:CreateTexture(nil, "ARTWORK")
    button.Icon:SetSize(28, 28)
    button.Icon:SetPoint("LEFT", content, "LEFT", 0, 0)
    button.Icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    button.Icon:SetTexture(Eligibility.GetSpellTexture())

    button.Label:SetParent(content)
    button.Label:ClearAllPoints()
    button.Label:SetPoint("LEFT", button.Icon, "RIGHT", 10, 0)
    button.Label:SetJustifyH("LEFT")

    -- Sibling of Content so the centered icon+label layout does not shift.
    button.HotKey = Theme.CreateText(button, "", "label")
    button.HotKey:SetDrawLayer("OVERLAY")
    button.HotKey:SetJustifyH("RIGHT")
    button.HotKey:SetPoint("TOPRIGHT", button, "TOPRIGHT", -8, -6)
    button.HotKey:Hide()

    local function layoutContent()
        local textWidth = 0
        if button.Label.GetStringWidth then
            textWidth = button.Label:GetStringWidth() or 0
        end
        content:SetWidth(28 + 10 + textWidth)
        content:ClearAllPoints()
        content:SetPoint("CENTER", button, "CENTER", 0, button.contentPressOffset or 0)
    end
    button.LayoutContent = layoutContent

    local setText = button.SetText
    function button:SetText(value)
        setText(self, value)
        layoutContent()
    end

    button:HookScript("OnMouseDown", function(self)
        self.contentPressOffset = -1
        layoutContent()
    end)
    button:HookScript("OnMouseUp", function(self)
        self.contentPressOffset = 0
        layoutContent()
    end)

    layoutContent()

    button.cooldownFill = button:CreateTexture(nil, "ARTWORK")
    button.cooldownFill:SetDrawLayer("ARTWORK", -1)
    applyCastFill(button)
    button.fillIsCast = true
    button.cooldownFill:SetPoint("TOPLEFT", button, "TOPLEFT", 1, -1)
    button.cooldownFill:SetPoint("BOTTOMLEFT", button, "BOTTOMLEFT", 1, 1)
    button.cooldownFill:SetWidth(1)
    button.cooldownFill:Hide()

    button:SetScript("OnUpdate", function()
        SecureDisenchant.UpdateProgress()
    end)

    SecureDisenchant.button = button
    SecureDisenchant.ApplyCurrent()
    return button
end

function SecureDisenchant.OnCastStart(spellID)
    if spellID ~= DISENCHANT_SPELL_ID then
        return
    end
    SecureDisenchant.allowGcdFill = false
    hideProgressFill(getButton())
    setHoldHover(true)
    local window = addon.MainWindow
    if window and window.frame and window.frame:IsShown() then
        window:RefreshQueueCount()
    end
end

function SecureDisenchant.OnCastStop(spellID, interrupted)
    if spellID ~= DISENCHANT_SPELL_ID then
        return
    end
    if interrupted then
        SecureDisenchant.allowGcdFill = false
        hideProgressFill(getButton())
    end
    setHoldHover(false)
    local window = addon.MainWindow
    if window and window.frame and window.frame:IsShown() then
        window:RefreshQueueCount()
    end
end

function SecureDisenchant.OnCastSucceeded(spellID)
    if spellID ~= DISENCHANT_SPELL_ID then
        return
    end

    -- GCD fill only after a successful DE; interrupts must not show it.
    SecureDisenchant.allowGcdFill = true
    SecureDisenchant.pendingLoot = true
    SecureDisenchant.pendingLootUntil = GetTime() + LOOT_PENDING_SECONDS
    SecureDisenchant.lootTaken = false
    Session.lootRecorded = false
    Session.itemsDisenchanted = Session.itemsDisenchanted + 1
    if addon.MainWindow and addon.MainWindow.RefreshSession then
        addon.MainWindow:RefreshSession()
    end
    local current = Queue.GetCurrent()
    if current then
        Queue.MarkConsumed(current.guid)
        Queue.RemoveByGUID(current.guid)
    else
        SecureDisenchant.ApplyCurrent()
    end
end

local function flushPendingUiRefresh()
    if not SecureDisenchant.pendingUiRefresh then
        return
    end

    SecureDisenchant.pendingUiRefresh = false
    local window = addon.MainWindow
    if window and window.frame and window.frame:IsShown() and window.Refresh then
        window:Refresh()
    end
end

local function clearPendingLoot()
    SecureDisenchant.pendingLoot = false
    SecureDisenchant.pendingLootUntil = 0
    SecureDisenchant.lootTaken = false
    Session.lootRecorded = false
    flushPendingUiRefresh()
end

function SecureDisenchant.TryLoot()
    if not SecureDisenchant.pendingLoot then
        return
    end

    if GetTime() > (SecureDisenchant.pendingLootUntil or 0) then
        clearPendingLoot()
        return
    end

    Session.RecordLootWindow()

    if addon.db and addon.db.global and addon.db.global.autoLootReagents == false then
        return
    end

    if SecureDisenchant.lootTaken then
        return
    end

    local slotCount = GetNumLootItems and GetNumLootItems() or 0
    if slotCount <= 0 then
        return
    end

    for slotIndex = 1, slotCount do
        LootSlot(slotIndex)
    end
    SecureDisenchant.lootTaken = true
end

function SecureDisenchant.OnLootClosed()
    clearPendingLoot()
end

function SecureDisenchant.OnLeaveCombat()
    if SecureDisenchant.pendingApply then
        SecureDisenchant.ApplyCurrent()
    else
        SecureDisenchant.UpdateVisual()
    end
end

Queue.OnChanged(function()
    SecureDisenchant.ApplyCurrent()
    local window = addon.MainWindow
    if not window or not window.frame or not window.frame:IsShown() then
        return
    end
    if SecureDisenchant.pendingLoot then
        if window.RefreshQueueList then
            window:RefreshQueueList()
        end
        if window.RefreshQueueCount then
            window:RefreshQueueCount()
        end
        SecureDisenchant.UpdateVisual()
        SecureDisenchant.pendingUiRefresh = true
        return
    end
    window:Refresh()
end)
