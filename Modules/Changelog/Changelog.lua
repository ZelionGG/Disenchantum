local ADDON_NAME, addon = ...

local Theme = addon.Theme

local Changelog = {}
addon.Changelog = Changelog

local RAIL_WIDTH = 160
local RAIL_ROW_HEIGHT = 32
local RAIL_ROW_GAP = 6
local BODY_PAD = 16
local VERSION_BAR_HEIGHT = 28
local CHEVRON_SIZE = 24

local function versionToSortKey(versionString)
    local major, minor, patch = tostring(versionString or ""):match("^(%d+)%.(%d+)%.?(%d*)")
    if not major then
        return 0
    end
    return (tonumber(major) or 0) * 1000000
        + (tonumber(minor) or 0) * 10000
        + (tonumber(patch) or 0) * 100
end

local function colorHex(color)
    local r, g, b = Theme.UnpackColor(color)
    return string.format("|cff%02x%02x%02x", math.floor(r * 255 + 0.5), math.floor(g * 255 + 0.5), math.floor(b * 255 + 0.5))
end

local function colorBrackets(line, color)
    if type(line) ~= "string" then
        line = tostring(line)
    end
    local hex = colorHex(color)
    return line:gsub("%[[^%[]+%]", function(token)
        return hex .. token .. "|r"
    end)
end

function Changelog.ResolveLocale(map)
    if type(map) ~= "table" then
        return nil
    end

    local localized = map[GetLocale()]
    if type(localized) == "table" then
        if localized.title or localized.text or #localized > 0 then
            return localized
        end
    end
    return map.enUS
end

function Changelog.GetSortedVersions()
    local versions = {}
    for key, data in pairs(Changelog) do
        if type(data) == "table" and data.version_string then
            versions[#versions + 1] = key
        end
    end
    table.sort(versions, function(left, right)
        return versionToSortKey(Changelog[left].version_string) > versionToSortKey(Changelog[right].version_string)
    end)
    return versions
end

local function addonVersion()
    if C_AddOns and C_AddOns.GetAddOnMetadata then
        return C_AddOns.GetAddOnMetadata(ADDON_NAME, "Version")
    end
    return nil
end

local function defaultVersionKey()
    local versions = Changelog.GetSortedVersions()
    local current = addonVersion()
    if current and Changelog[current] and Changelog[current].version_string then
        return current
    end
    return versions[1]
end

local function setHeaderButtonSelected(selected)
    if Changelog.headerButton then
        Changelog.headerButton:SetSelected(selected)
    end
end

local function placeRule(rule, content, y)
    if not rule then
        return y
    end
    rule:ClearAllPoints()
    rule:SetPoint("TOPLEFT", content, "TOPLEFT", 0, -y)
    rule:SetPoint("TOPRIGHT", content, "TOPRIGHT", 0, -y)
    rule:Show()
    return y + 1 + 10
end

local function createRule(parent)
    local rule = parent:CreateTexture(nil, "ARTWORK")
    rule:SetHeight(1)
    rule:SetColorTexture(Theme.UnpackColor(Theme.colors.borderSoft))
    rule:Hide()
    return rule
end

local function layoutBody()
    local content = Changelog.bodyContent
    if not content then
        return
    end

    local width = math.max(80, (content:GetWidth() or 80) - 4)
    local y = 0
    for index = 1, #(Changelog.bodyLines or {}) do
        local line = Changelog.bodyLines[index]
        if line:IsShown() then
            line:SetWidth(width)
            line:SetJustifyH("LEFT")
            local height = math.max(16, line:GetStringHeight() or 16)
            line:ClearAllPoints()
            line:SetPoint("TOPLEFT", content, "TOPLEFT", 0, -y)
            line:SetPoint("TOPRIGHT", content, "TOPRIGHT", 0, -y)
            y = y + height + 8
            if index == Changelog.headerRuleIndex then
                y = placeRule(Changelog.headerRule, content, y)
            end
        end
    end

    if Changelog.headerRule and Changelog.headerRuleIndex == nil then
        Changelog.headerRule:Hide()
    end

    content:SetHeight(math.max(1, y))
    if Changelog.bodyScroll and Changelog.bodyScroll.UpdateScrollBar then
        Changelog.bodyScroll:UpdateScrollBar()
    end
end

local function acquireBodyLine(index, variant)
    Changelog.bodyLines = Changelog.bodyLines or {}
    local line = Changelog.bodyLines[index]
    if not line then
        line = Theme.CreateText(Changelog.bodyContent, "", variant)
        line:SetJustifyV("TOP")
        line:SetWordWrap(true)
        Changelog.bodyLines[index] = line
    else
        local fontObject = "GameFontHighlight"
        if variant == "heading" then
            fontObject = "GameFontNormalLarge"
        elseif variant == "label" then
            fontObject = "GameFontHighlightSmall"
        elseif variant == "muted" then
            fontObject = "GameFontDisable"
        end
        line:SetFontObject(fontObject)
        if variant == "heading" then
            Theme.SetFontColor(line, Theme.colors.accent)
        elseif variant == "label" or variant == "muted" then
            Theme.SetFontColor(line, Theme.colors.textMuted)
        else
            Theme.SetFontColor(line, Theme.colors.text)
        end
    end
    return line
end

local function selectedVersionIndex()
    local versions = Changelog.GetSortedVersions()
    for index = 1, #versions do
        if versions[index] == Changelog.selectedVersion then
            return index, versions
        end
    end
    return nil, versions
end

local function setChevronEnabled(button, enabled)
    if not button then
        return
    end
    button:SetVisualEnabled(enabled)
    button:EnableMouse(enabled)
    if enabled then
        button:Enable()
    else
        button:Disable()
        button:SetAlpha(0.35)
    end
end

local function updateChevrons()
    local index, versions = selectedVersionIndex()
    local count = #versions
    setChevronEnabled(Changelog.prevButton, index ~= nil and index < count)
    setChevronEnabled(Changelog.nextButton, index ~= nil and index > 1)
end

local function stepVersion(delta)
    local index, versions = selectedVersionIndex()
    if not index then
        return
    end
    local nextIndex = index + delta
    if nextIndex < 1 or nextIndex > #versions then
        return
    end
    Changelog.SelectVersion(versions[nextIndex])
end

local function updateVersionBar(data)
    if not Changelog.versionLabel then
        return
    end

    if type(data) ~= "table" or not data.version_string then
        Changelog.versionLabel:SetText("")
        if Changelog.versionRule then
            Changelog.versionRule:Hide()
        end
        updateChevrons()
        return
    end

    local versionLine = data.version_string
    if data.release_date and data.release_date ~= "" then
        versionLine = versionLine
            .. " "
            .. colorHex(Theme.colors.textMuted)
            .. "- "
            .. data.release_date
            .. "|r"
    end
    Changelog.versionLabel:SetText(versionLine)
    if Changelog.versionRule then
        Changelog.versionRule:Show()
    end
    updateChevrons()
end

local function addBodyLine(used, text, variant, color)
    used = used + 1
    local line = acquireBodyLine(used, variant)
    line:SetText(text or "")
    if color then
        Theme.SetFontColor(line, color)
    end
    line:Show()
    return used
end

function Changelog.SelectVersion(versionKey)
    local L = addon.L
    local data = Changelog[versionKey]
    Changelog.selectedVersion = versionKey

    for index = 1, #(Changelog.railButtons or {}) do
        local button = Changelog.railButtons[index]
        button:SetSelected(button.versionKey == versionKey)
    end

    if not Changelog.bodyContent then
        return
    end

    local used = 0
    Changelog.headerRuleIndex = nil
    updateVersionBar(data)
    if type(data) ~= "table" or not data.version_string then
        used = addBodyLine(used, (L and L["EMPTY_CHANGELOG"]) or "No changelog entries.", "muted")
    else
        local header = Changelog.ResolveLocale(data.header)

        if header and header.title and header.title ~= "" then
            used = addBodyLine(
                used,
                colorBrackets(header.title, Theme.colors.accentAlt),
                "heading",
                Theme.colors.accentAlt
            )
        end
        if header and header.text and header.text ~= "" then
            used = addBodyLine(used, colorBrackets(header.text, Theme.colors.accentAlt), "body")
        end
        Changelog.headerRuleIndex = used

        local sections = {
            { key = "important", label = (L and L["CHANGELOG_IMPORTANT"]) or "Important" },
            { key = "new", label = (L and L["CHANGELOG_NEW"]) or "New" },
            { key = "bugfix", label = (L and L["CHANGELOG_BUGFIXES"]) or "Bugfixes" },
            { key = "improvement", label = (L and L["CHANGELOG_IMPROVEMENT"]) or "Improvement" },
        }
        for index = 1, #sections do
            local section = sections[index]
            local items = Changelog.ResolveLocale(data[section.key])
            if type(items) == "table" and #items > 0 then
                used = addBodyLine(used, section.label, "heading")
                local text = ""
                for lineIndex = 1, #items do
                    text = text .. "    - " .. colorBrackets(items[lineIndex], Theme.colors.accentAlt)
                    if lineIndex < #items then
                        text = text .. "\n"
                    end
                end
                used = addBodyLine(used, text, "body")
            end
        end
    end

    for index = used + 1, #(Changelog.bodyLines or {}) do
        Changelog.bodyLines[index]:Hide()
    end

    if Changelog.bodyScroll then
        Changelog.bodyScroll:SetVerticalScroll(0)
    end
    layoutBody()
end

local function refreshRail()
    local versions = Changelog.GetSortedVersions()
    Changelog.railButtons = Changelog.railButtons or {}

    for index = 1, math.max(#versions, #Changelog.railButtons) do
        local button = Changelog.railButtons[index]
        if not button then
            button = Theme.CreateButton(Changelog.railContent, RAIL_WIDTH - 8, RAIL_ROW_HEIGHT, "", "secondary")
            button.Label:SetWordWrap(false)
            button:SetScript("OnClick", function(self)
                Changelog.SelectVersion(self.versionKey)
            end)
            Changelog.railButtons[index] = button
        end

        local versionKey = versions[index]
        if versionKey then
            local data = Changelog[versionKey]
            button.versionKey = versionKey
            button:SetText(data.version_string)
            button:ClearAllPoints()
            button:SetPoint("TOPLEFT", Changelog.railContent, "TOPLEFT", 0, -((index - 1) * (RAIL_ROW_HEIGHT + RAIL_ROW_GAP)))
            button:SetPoint("TOPRIGHT", Changelog.railContent, "TOPRIGHT", 0, -((index - 1) * (RAIL_ROW_HEIGHT + RAIL_ROW_GAP)))
            button:Show()
        else
            button.versionKey = nil
            button:Hide()
        end
    end

    Changelog.railContent:SetHeight(math.max(1, #versions * (RAIL_ROW_HEIGHT + RAIL_ROW_GAP)))
end

function Changelog.EnsureFrame(parent)
    if Changelog.overlay or not parent then
        return
    end

    local L = addon.L
    local overlay = CreateFrame("Frame", nil, parent)
    overlay:SetPoint("TOPLEFT", parent, "TOPLEFT", 20, -74)
    overlay:SetPoint("BOTTOMRIGHT", parent, "BOTTOMRIGHT", -20, 64)
    overlay:EnableMouse(true)
    overlay:Hide()
    overlay:SetScript("OnMouseDown", function()
        Changelog.Hide()
    end)
    Changelog.overlay = overlay

    local panel = Theme.CreateCard(overlay)
    panel:SetPoint("TOPLEFT", overlay, "TOPLEFT", 0, 0)
    panel:SetPoint("BOTTOMRIGHT", overlay, "BOTTOMRIGHT", 0, 0)
    panel:EnableMouse(true)
    Changelog.panel = panel

    local title = Theme.CreateText(panel, (L and L["CHANGELOG_TITLE"]) or "Changelog", "heading")
    title:SetPoint("TOPLEFT", panel, "TOPLEFT", BODY_PAD, -14)

    local railCard = Theme.CreatePanel(panel, Theme.colors.cardInset, Theme.colors.borderMuted)
    railCard:SetPoint("TOPLEFT", panel, "TOPLEFT", 12, -42)
    railCard:SetPoint("BOTTOMLEFT", panel, "BOTTOMLEFT", 12, 12)
    railCard:SetWidth(RAIL_WIDTH)
    Changelog.railScroll, Changelog.railContent = Theme.CreateStyledScrollArea(railCard, RAIL_WIDTH - 24)
    Changelog.railScroll:SetPoint("TOPLEFT", railCard, "TOPLEFT", 8, -8)
    Changelog.railScroll:SetPoint("BOTTOMRIGHT", railCard, "BOTTOMRIGHT", -16, 8)

    local bodyCard = Theme.CreatePanel(panel, Theme.colors.cardInset, Theme.colors.borderMuted)
    bodyCard:SetPoint("TOPLEFT", railCard, "TOPRIGHT", 10, 0)
    bodyCard:SetPoint("BOTTOMRIGHT", panel, "BOTTOMRIGHT", -12, 12)

    local versionBar = CreateFrame("Frame", nil, bodyCard)
    versionBar:SetPoint("TOPLEFT", bodyCard, "TOPLEFT", BODY_PAD, -10)
    versionBar:SetPoint("TOPRIGHT", bodyCard, "TOPRIGHT", -BODY_PAD, -10)
    versionBar:SetHeight(VERSION_BAR_HEIGHT)
    Changelog.versionBar = versionBar

    Changelog.nextButton = Theme.CreateButton(versionBar, CHEVRON_SIZE, CHEVRON_SIZE, ">", "secondary")
    Changelog.nextButton:SetPoint("RIGHT", versionBar, "RIGHT", 0, 0)
    Changelog.nextButton.labelOffsetX = 1
    Changelog.nextButton.labelOffsetY = 1
    Changelog.nextButton.labelColor = Theme.colors.accent
    Changelog.nextButton.Label:SetPoint("CENTER", 1, 1)
    Theme.SetFontColor(Changelog.nextButton.Label, Theme.colors.accent)
    Changelog.nextButton:SetScript("OnClick", function()
        stepVersion(-1)
    end)

    Changelog.prevButton = Theme.CreateButton(versionBar, CHEVRON_SIZE, CHEVRON_SIZE, "<", "secondary")
    Changelog.prevButton:SetPoint("RIGHT", Changelog.nextButton, "LEFT", -4, 0)
    Changelog.prevButton.labelOffsetX = 1
    Changelog.prevButton.labelOffsetY = 1
    Changelog.prevButton.labelColor = Theme.colors.accent
    Changelog.prevButton.Label:SetPoint("CENTER", 1, 1)
    Theme.SetFontColor(Changelog.prevButton.Label, Theme.colors.accent)
    Changelog.prevButton:SetScript("OnClick", function()
        stepVersion(1)
    end)

    Changelog.versionLabel = Theme.CreateText(versionBar, "", "heading")
    Changelog.versionLabel:SetPoint("LEFT", versionBar, "LEFT", 0, 0)
    Changelog.versionLabel:SetPoint("RIGHT", Changelog.prevButton, "LEFT", -8, 0)
    Changelog.versionLabel:SetWordWrap(false)

    Changelog.versionRule = createRule(bodyCard)
    Changelog.versionRule:ClearAllPoints()
    Changelog.versionRule:SetPoint("TOPLEFT", versionBar, "BOTTOMLEFT", 0, -6)
    Changelog.versionRule:SetPoint("TOPRIGHT", versionBar, "BOTTOMRIGHT", 0, -6)

    Changelog.bodyScroll, Changelog.bodyContent = Theme.CreateStyledScrollArea(bodyCard, 400)
    Changelog.bodyScroll:SetPoint("TOPLEFT", Changelog.versionRule, "BOTTOMLEFT", 0, -10)
    Changelog.bodyScroll:SetPoint("BOTTOMRIGHT", bodyCard, "BOTTOMRIGHT", -22, BODY_PAD)
    Changelog.bodyScroll:HookScript("OnSizeChanged", function(_, width)
        if width and width > 0 then
            Changelog.bodyContent:SetWidth(width)
            layoutBody()
        end
    end)

    Changelog.headerRule = createRule(Changelog.bodyContent)
end

function Changelog.Show()
    local window = addon.MainWindow and addon.MainWindow.frame
    if not window then
        return
    end

    Changelog.EnsureFrame(window)
    Changelog.overlay:SetFrameLevel((window:GetFrameLevel() or 100) + 40)
    refreshRail()

    local versions = Changelog.GetSortedVersions()
    if Changelog.selectedVersion and Changelog[Changelog.selectedVersion] then
        Changelog.SelectVersion(Changelog.selectedVersion)
    else
        Changelog.SelectVersion(defaultVersionKey())
    end

    if #versions == 0 then
        Changelog.SelectVersion(nil)
    end

    Changelog.overlay:Show()
    setHeaderButtonSelected(true)
end

function Changelog.Hide()
    if Changelog.overlay then
        Changelog.overlay:Hide()
    end
    setHeaderButtonSelected(false)
end

function Changelog.Toggle()
    if Changelog.overlay and Changelog.overlay:IsShown() then
        Changelog.Hide()
        return
    end
    Changelog.Show()
end

function Changelog.IsShown()
    return Changelog.overlay and Changelog.overlay:IsShown()
end
