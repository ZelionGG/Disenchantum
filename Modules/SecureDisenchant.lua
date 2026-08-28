local _, addon = ...

local Queue = addon.Queue
local Eligibility = addon.Eligibility
local Theme = addon.Theme
local L

local DISENCHANT_SPELL_ID = addon.DISENCHANT_SPELL_ID
local BUTTON_NAME = "DisenchanterSecureButton"
local LOOT_PENDING_SECONDS = 2

local SecureDisenchant = {
    button = nil,
    pendingApply = false,
    allowGcdFill = false,
    pendingLoot = false,
    pendingLootUntil = 0,
}

addon.SecureDisenchant = SecureDisenchant

local function getButton()
    return SecureDisenchant.button
end

local function formatRemaining(remaining)
    local text = (L and L["FMT_CAST_REMAINING"]) or "%.1fs"
    return text:format(remaining)
end

local function disenchantLabel()
    return Eligibility.GetSpellName() or "Disenchant"
end

local function setHoldHover(active)
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

local function refreshQueueCount()
    local window = addon.MainWindow
    if window and window.frame and window.frame:IsShown() then
        window:RefreshQueueCount()
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

    if entry and entry.bag and entry.slot then
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
    Theme.ApplyGradient(button.cooldownFill, "VERTICAL", Theme.colors.accentDim, Theme.colors.accentAlt)
    button.cooldownFill:SetAlpha(0.85)
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
            button:SetText(base .. "  ·  " .. formatRemaining(remaining))
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

    button.Icon = button:CreateTexture(nil, "ARTWORK")
    button.Icon:SetSize(28, 28)
    button.Icon:SetPoint("LEFT", button, "LEFT", 10, 0)
    button.Icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    button.Icon:SetTexture(Eligibility.GetSpellTexture())

    button.Label:ClearAllPoints()
    button.Label:SetPoint("LEFT", button.Icon, "RIGHT", 10, 0)
    button.Label:SetPoint("RIGHT", button, "RIGHT", -12, 0)
    button.Label:SetJustifyH("LEFT")

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
    refreshQueueCount()
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
    refreshQueueCount()
end

function SecureDisenchant.OnCastSucceeded(spellID)
    if spellID ~= DISENCHANT_SPELL_ID then
        return
    end

    SecureDisenchant.allowGcdFill = true
    SecureDisenchant.pendingLoot = true
    SecureDisenchant.pendingLootUntil = GetTime() + LOOT_PENDING_SECONDS
    local current = Queue.GetCurrent()
    if current then
        Queue.MarkConsumed(current.guid)
        Queue.RemoveByGUID(current.guid)
    else
        Queue.RefreshLocations()
        SecureDisenchant.ApplyCurrent()
    end
end

function SecureDisenchant.TryLoot()
    if not SecureDisenchant.pendingLoot then
        return
    end

    if GetTime() > (SecureDisenchant.pendingLootUntil or 0) then
        SecureDisenchant.pendingLoot = false
        return
    end

    local slotCount = GetNumLootItems and GetNumLootItems() or 0
    for slotIndex = 1, slotCount do
        LootSlot(slotIndex)
    end
end

function SecureDisenchant.OnLootClosed()
    SecureDisenchant.pendingLoot = false
    SecureDisenchant.pendingLootUntil = 0
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
    if addon.MainWindow and addon.MainWindow.frame and addon.MainWindow.frame:IsShown() then
        addon.MainWindow:Refresh()
    end
end)
