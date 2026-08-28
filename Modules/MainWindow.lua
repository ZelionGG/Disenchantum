local _, addon = ...

local Theme = addon.Theme
local Queue = addon.Queue
local Eligibility = addon.Eligibility
local SecureDisenchant = addon.SecureDisenchant
local L

local WINDOW_WIDTH = 1100
local WINDOW_HEIGHT = 780
local SIDEBAR_WIDTH = 340
local BAG_ROW_SPACING = 64
local BAG_HEADER_HEIGHT = 28
local BAG_HEADER_SPACING = 32
local QUEUE_ROW_SPACING = 64
local LIST_TOP_PADDING = 10
local ITEM_ICON_SIZE = 40
local QUEUE_DRAG_THRESHOLD = 6
local QUEUE_DOUBLE_CLICK = 0.35

local function mediaTexture(fileName)
    return "Interface\\AddOns\\" .. addon.name .. "\\Media\\" .. fileName
end

local MainWindow = {}
addon.MainWindow = MainWindow

local function showItemTooltip(owner, bag, slot, itemLink)
    if not owner or not GameTooltip then
        return
    end
    GameTooltip:SetOwner(owner, "ANCHOR_RIGHT")
    if bag and slot then
        GameTooltip:SetBagItem(bag, slot)
    elseif itemLink then
        GameTooltip:SetHyperlink(itemLink)
    end
    GameTooltip:Show()
end

local function hideTooltip()
    if GameTooltip then
        GameTooltip:Hide()
    end
end

local function colorizeByQuality(fontString, text, quality)
    fontString:SetText(text or "")
    if quality and C_Item.GetItemQualityColor then
        local r, g, b = C_Item.GetItemQualityColor(quality)
        fontString:SetTextColor(r, g, b, 1)
    else
        Theme.SetFontColor(fontString, Theme.colors.text)
    end
end

local function itemLevelText(entry)
    if entry and entry.itemLevel then
        return tostring(math.floor(entry.itemLevel + 0.5))
    end
    return ""
end

local function applyRowItemVisuals(row)
    colorizeByQuality(row.Title, row.itemName, row.quality)

    if row.Meta then
        local parts = {}
        if row.itemLevelText ~= "" then
            parts[#parts + 1] = row.itemLevelText
        end
        if row.slotText ~= "" then
            parts[#parts + 1] = row.slotText
        end
        if row.bindText ~= "" then
            parts[#parts + 1] = row.bindText
        end
        row.Meta:SetText(table.concat(parts, " · "))
        Theme.SetFontColor(row.Meta, Theme.colors.textMuted)
    end

    if row.IconWrap then
        row.IconWrap:SetQuality(row.quality)
    end
end

local function enqueueCursorItem()
    local location = C_Cursor.GetCursorItem and C_Cursor.GetCursorItem()
    if not location or not location.IsBagAndSlot or not location:IsBagAndSlot() then
        return false
    end

    local bag, slot = location:GetBagAndSlot()
    local ok = Queue.AddFromBag(bag, slot)
    if ClearCursor then
        ClearCursor()
    end
    return ok
end

function MainWindow:ApplyWindowScale()
    if not self.frame then
        return
    end

    local screenWidth = GetScreenWidth and GetScreenWidth() or WINDOW_WIDTH
    local screenHeight = GetScreenHeight and GetScreenHeight() or WINDOW_HEIGHT
    local scale = math.min(1, screenWidth / WINDOW_WIDTH, screenHeight / WINDOW_HEIGHT)
    if scale < 0.01 then
        scale = 0.01
    end
    self.frame:SetScale(scale)
end

function MainWindow.CollectSnapshot()
    return Eligibility.CollectSnapshot({
        skipGuids = Queue.GetSkipGuids(),
        countSkipGuids = Queue.GetConsumedGuids(),
    })
end

function MainWindow:RefreshQueueCount(snapshot)
    if not self.queueCount then
        return
    end

    snapshot = snapshot or MainWindow.CollectSnapshot()
    local queued = Queue.Count()
    self.queueCount:SetText((L["FMT_QUEUE_COUNT"]):format(queued, queued + #snapshot.items))
end

function MainWindow:RefreshMetrics()
    self:RefreshQueueCount()
end

function MainWindow:CloseBagMenus()
    if self.filtersOverlay then
        self.filtersOverlay:Hide()
    end
    if self.filtersButton then
        self.filtersButton:SetSelected(false)
    end
    if self.orderByButton then
        self.orderByButton:SetSelected(false)
    end
    if self.groupByButton then
        self.groupByButton:SetSelected(false)
    end
    if self.filtersPanel then
        self.filtersPanel:Hide()
    end
    if self.orderByPanel then
        self.orderByPanel:Hide()
    end
    if self.groupByPanel then
        self.groupByPanel:Hide()
    end
end

function MainWindow:CloseFiltersPanel()
    self:CloseBagMenus()
end

local BAG_MENU_ORDER_OPTIONS = { "name", "ilvl", "quality", "slot" }
local BAG_MENU_GROUP_OPTIONS = { "none", "name", "ilvl", "quality", "slot" }

local function bagMenuOptionLabel(optionKey)
    if optionKey == "none" then
        return NONE
    end
    if optionKey == "ilvl" then
        return STAT_AVERAGE_ITEM_LEVEL
    end
    if optionKey == "quality" then
        return RARITY
    end
    if optionKey == "name" then
        return L["SORT_NAME"]
    end
    return L["SORT_SLOT"]
end

local function bagViewSettings()
    addon.db.global.bagView = addon.db.global.bagView or {}
    return Eligibility.NormalizeBagView(addon.db.global.bagView)
end

function MainWindow:RefreshBagViewRadios()
    local bagView = bagViewSettings()
    if self.orderByRadios then
        for index = 1, #self.orderByRadios do
            local radio = self.orderByRadios[index]
            radio:SetCheckedState(bagView.orderBy == radio.optionKey)
        end
    end
    if self.groupByRadios then
        for index = 1, #self.groupByRadios do
            local radio = self.groupByRadios[index]
            radio:SetCheckedState(bagView.groupBy == radio.optionKey)
        end
    end
end

function MainWindow:OpenBagMenu(which)
    if not self.filtersOverlay then
        return
    end

    if which == "filters" then
        self:RefreshFilters()
    else
        self:RefreshBagViewRadios()
    end

    if self.filtersPanel then
        self.filtersPanel:SetShown(which == "filters")
    end
    if self.orderByPanel then
        self.orderByPanel:SetShown(which == "order")
    end
    if self.groupByPanel then
        self.groupByPanel:SetShown(which == "group")
    end

    self.filtersOverlay:Show()
    self.filtersOverlay:SetFrameLevel((self.frame:GetFrameLevel() or 100) + 20)
    local overlayLevel = self.filtersOverlay:GetFrameLevel()
    if self.filtersPanel then
        self.filtersPanel:SetFrameLevel(overlayLevel + 2)
    end
    if self.orderByPanel then
        self.orderByPanel:SetFrameLevel(overlayLevel + 2)
    end
    if self.groupByPanel then
        self.groupByPanel:SetFrameLevel(overlayLevel + 2)
    end
    if self.filtersButton then
        self.filtersButton:SetSelected(which == "filters")
    end
    if self.orderByButton then
        self.orderByButton:SetSelected(which == "order")
    end
    if self.groupByButton then
        self.groupByButton:SetSelected(which == "group")
    end
end

function MainWindow:OpenFiltersPanel()
    self:OpenBagMenu("filters")
end

function MainWindow:ToggleBagMenu(which)
    local panel
    if which == "filters" then
        panel = self.filtersPanel
    elseif which == "order" then
        panel = self.orderByPanel
    else
        panel = self.groupByPanel
    end
    if self.filtersOverlay and self.filtersOverlay:IsShown() and panel and panel:IsShown() then
        self:CloseBagMenus()
        return
    end
    self:OpenBagMenu(which)
end

function MainWindow:ToggleFiltersPanel()
    self:ToggleBagMenu("filters")
end

function MainWindow:CreateBagRow()
    local row = CreateFrame("Button", nil, self.bagListContent, "BackdropTemplate")
    row:SetHeight(56)
    row.variant = "subtle"
    row.isHovered = false
    Theme.UpdateButtonColors(row)

    row.IconWrap = Theme.CreateItemIcon(row, ITEM_ICON_SIZE)
    row.IconWrap:SetPoint("LEFT", row, "LEFT", 8, 0)
    row.IconWrap:EnableMouse(false)

    row.Title = Theme.CreateText(row, "", "body")
    row.Title:SetPoint("TOPLEFT", row.IconWrap, "TOPRIGHT", 10, 0)
    row.Title:SetPoint("RIGHT", row, "RIGHT", -10, 0)
    row.Title:SetJustifyH("LEFT")
    row.Title:SetWordWrap(false)
    row.Title:SetMaxLines(1)

    row.Meta = Theme.CreateText(row, "", "muted")
    row.Meta:SetPoint("TOPLEFT", row.Title, "BOTTOMLEFT", 0, -4)
    row.Meta:SetPoint("RIGHT", row, "RIGHT", -10, 0)
    row.Meta:SetWordWrap(false)
    row.Meta:SetMaxLines(1)

    row:SetScript("OnEnter", function(selfRow)
        selfRow.isHovered = true
        Theme.UpdateButtonColors(selfRow)
        applyRowItemVisuals(selfRow)
        showItemTooltip(selfRow, selfRow.bag, selfRow.slot, selfRow.itemLink)
    end)
    row:SetScript("OnLeave", function(selfRow)
        selfRow.isHovered = false
        Theme.UpdateButtonColors(selfRow)
        applyRowItemVisuals(selfRow)
        hideTooltip()
    end)
    row:SetScript("OnClick", function(selfRow)
        if selfRow.bag and selfRow.slot then
            Queue.AddFromBag(selfRow.bag, selfRow.slot)
        end
    end)
    row:SetScript("OnReceiveDrag", function()
        enqueueCursorItem()
    end)

    function row.Refresh(rowFrame, entry)
        if not entry then
            rowFrame:Hide()
            return
        end

        rowFrame.bag = entry.bag
        rowFrame.slot = entry.slot
        rowFrame.itemLink = entry.itemLink
        rowFrame.itemName = entry.itemName
        rowFrame.quality = entry.quality
        rowFrame.itemLevelText = itemLevelText(entry)
        rowFrame.slotText = entry.slotName or ""
        rowFrame.bindText = entry.bindLabel or ""
        rowFrame.IconWrap:SetIcon(entry.icon)
        Theme.UpdateButtonColors(rowFrame)
        applyRowItemVisuals(rowFrame)
        rowFrame:Show()
    end

    return row
end

function MainWindow:CreateBagHeaderRow()
    local row = CreateFrame("Frame", nil, self.bagListContent)
    row:SetHeight(BAG_HEADER_HEIGHT)
    row:EnableMouse(false)

    row.Title = Theme.CreateText(row, "", "muted")
    row.Title:SetPoint("LEFT", row, "LEFT", 8, 0)
    row.Title:SetPoint("RIGHT", row, "RIGHT", -8, 0)
    row.Title:SetWordWrap(false)
    row.Title:SetMaxLines(1)

    function row.Refresh(rowFrame, title)
        rowFrame.Title:SetText(title or "")
        rowFrame:Show()
    end

    return row
end

function MainWindow:RefreshBagList(snapshot)
    local items = (snapshot and snapshot.items) or MainWindow.CollectSnapshot().items
    local bagView = bagViewSettings()
    Eligibility.SortBagItems(items, bagView.orderBy, bagView.groupBy)
    local display = Eligibility.BuildBagDisplayList(items, bagView.groupBy)

    self.bagItemRows = self.bagItemRows or {}
    self.bagHeaderRows = self.bagHeaderRows or {}

    local itemUsed = 0
    local headerUsed = 0
    local yOffset = LIST_TOP_PADDING

    for index = 1, #display do
        local data = display[index]
        local row
        local spacing
        if data.isHeader then
            headerUsed = headerUsed + 1
            row = self.bagHeaderRows[headerUsed]
            if not row then
                row = self:CreateBagHeaderRow()
                self.bagHeaderRows[headerUsed] = row
            end
            row:Refresh(data.title)
            spacing = BAG_HEADER_SPACING
        else
            itemUsed = itemUsed + 1
            row = self.bagItemRows[itemUsed]
            if not row then
                row = self:CreateBagRow()
                self.bagItemRows[itemUsed] = row
            end
            row:Refresh(data)
            spacing = BAG_ROW_SPACING
        end

        row:ClearAllPoints()
        row:SetPoint("TOPLEFT", self.bagListContent, "TOPLEFT", 0, -yOffset)
        row:SetPoint("TOPRIGHT", self.bagListContent, "TOPRIGHT", 0, -yOffset)
        row:Show()
        yOffset = yOffset + spacing
    end

    for index = itemUsed + 1, #self.bagItemRows do
        self.bagItemRows[index]:Hide()
    end
    for index = headerUsed + 1, #self.bagHeaderRows do
        self.bagHeaderRows[index]:Hide()
    end
    if self.bagRows then
        for index = 1, #self.bagRows do
            self.bagRows[index]:Hide()
        end
    end

    self.bagEmpty:SetShown(#items == 0)
    self.bagListContent:SetHeight(math.max(1, yOffset))
    if self.bagScroll and self.bagScroll.UpdateScrollBar then
        self.bagScroll:UpdateScrollBar()
    end
end

function MainWindow.GetQueueInsertIndexFromCursor(_, row)
    if not row or not row.queueIndex then
        return nil
    end

    local scale = row:GetEffectiveScale() or 1
    local cursorY = select(2, GetCursorPosition()) / scale
    local rowTop = row:GetTop() or 0
    local rowBottom = row:GetBottom() or 0
    local midpoint = rowBottom + ((rowTop - rowBottom) * 0.5)
    if cursorY >= midpoint then
        return row.queueIndex
    end
    return row.queueIndex + 1
end

function MainWindow:UpdateQueueInsertLine()
    local line = self.queueInsertLine
    if not line then
        return
    end

    local dragState = self.queueDragState
    if not dragState then
        line:Hide()
        return
    end

    local visibleRows = {}
    for _, row in ipairs(self.queueRows or {}) do
        if row:IsShown() and row.queueIndex then
            visibleRows[#visibleRows + 1] = row
        end
    end

    if #visibleRows == 0 then
        line:Hide()
        return
    end

    local insertIndex = dragState.insertIndex or dragState.sourceIndex or 1
    if insertIndex == dragState.sourceIndex or insertIndex == (dragState.sourceIndex + 1) then
        line:Hide()
        return
    end

    if insertIndex <= 1 then
        line:ClearAllPoints()
        line:SetPoint("LEFT", self.queueContent, "TOPLEFT", 8, -math.floor(LIST_TOP_PADDING * 0.5))
        line:SetPoint("RIGHT", self.queueContent, "TOPRIGHT", -8, -math.floor(LIST_TOP_PADDING * 0.5))
        line:Show()
        return
    end

    local previousRow = visibleRows[math.min(insertIndex - 1, #visibleRows)]
    if previousRow then
        line:ClearAllPoints()
        line:SetPoint("LEFT", previousRow, "BOTTOMLEFT", 8, -3)
        line:SetPoint("RIGHT", previousRow, "BOTTOMRIGHT", -8, -3)
        line:Show()
        return
    end

    line:Hide()
end

function MainWindow:RefreshQueueDragHighlights()
    for _, row in ipairs(self.queueRows or {}) do
        if row:IsShown() then
            if self.queueDragState and row.queueIndex == self.queueDragState.sourceIndex then
                Theme.ApplySurface(row, Theme.colors.cardSoft, Theme.colors.accentSoft)
            elseif row.isHovered and not self.queueDragState then
                Theme.ApplySurface(row, Theme.colors.cardSoft, Theme.colors.accent)
            elseif row.queueIndex == 1 then
                Theme.SetCardTone(row, "success")
            else
                Theme.ApplySurface(row, Theme.colors.card, Theme.colors.borderSoft)
            end
        end
    end
    self:UpdateQueueInsertLine()
end

function MainWindow:BeginQueueDrag(row)
    if not row or not row.queueIndex then
        return
    end

    self.queueDragState = {
        sourceIndex = row.queueIndex,
        insertIndex = row.queueIndex,
        guid = row.guid,
    }
    self:RefreshQueueDragHighlights()
end

function MainWindow:UpdateQueueDragFromCursor()
    if not self.queueDragState then
        return
    end

    local visibleRows = {}
    for _, row in ipairs(self.queueRows or {}) do
        if row:IsShown() and row.queueIndex then
            visibleRows[#visibleRows + 1] = row
        end
    end
    if #visibleRows == 0 then
        return
    end

    local scale = self.queueContent:GetEffectiveScale() or 1
    local cursorY = select(2, GetCursorPosition()) / scale
    local firstRow = visibleRows[1]
    local lastRow = visibleRows[#visibleRows]
    local insertIndex

    if cursorY >= (firstRow:GetTop() or 0) then
        insertIndex = 1
    elseif cursorY <= (lastRow:GetBottom() or 0) then
        insertIndex = #visibleRows + 1
    else
        for _, row in ipairs(visibleRows) do
            local candidate = self:GetQueueInsertIndexFromCursor(row)
            if candidate then
                local rowTop = row:GetTop() or 0
                local rowBottom = row:GetBottom() or 0
                if cursorY <= rowTop and cursorY >= rowBottom then
                    insertIndex = candidate
                    break
                end
            end
        end
    end

    if insertIndex and self.queueDragState.insertIndex ~= insertIndex then
        self.queueDragState.insertIndex = insertIndex
        self:RefreshQueueDragHighlights()
    end
end

function MainWindow:EndQueueDrag()
    local dragState = self.queueDragState
    if not dragState then
        return
    end

    self.queueDragState = nil

    local insertIndex = dragState.insertIndex or dragState.sourceIndex
    if insertIndex == dragState.sourceIndex or insertIndex == dragState.sourceIndex + 1 then
        self:RefreshQueueDragHighlights()
        return
    end

    local targetIndex = insertIndex
    if insertIndex > dragState.sourceIndex then
        targetIndex = insertIndex - 1
    end

    Queue.Move(dragState.sourceIndex, math.max(1, math.min(targetIndex, Queue.Count())))
    self:RefreshQueueDragHighlights()
end

function MainWindow:CreateQueueRow(index)
    local row = Theme.CreateCard(self.queueContent, nil, 56)
    row:SetPoint("TOPLEFT", self.queueContent, "TOPLEFT", 0, -((index - 1) * QUEUE_ROW_SPACING + LIST_TOP_PADDING))
    row:SetPoint("TOPRIGHT", self.queueContent, "TOPRIGHT", 0, -((index - 1) * QUEUE_ROW_SPACING + LIST_TOP_PADDING))
    row:EnableMouse(true)

    row.IconWrap = Theme.CreateItemIcon(row, ITEM_ICON_SIZE)
    row.IconWrap:SetPoint("LEFT", row, "LEFT", 10, 0)
    row.IconWrap:EnableMouse(false)

    row.IndexLabel = Theme.CreateText(row, "", "label")
    row.IndexLabel:SetPoint("TOPLEFT", row.IconWrap, "TOPRIGHT", 10, 2)

    row.Title = Theme.CreateText(row, "", "body")
    row.Title:SetPoint("TOPLEFT", row.IndexLabel, "TOPRIGHT", 8, 0)
    row.Title:SetPoint("RIGHT", row, "RIGHT", -50, 0)
    row.Title:SetWordWrap(false)
    row.Title:SetMaxLines(1)

    row.Meta = Theme.CreateText(row, "", "muted")
    row.Meta:SetPoint("TOPLEFT", row.IndexLabel, "BOTTOMLEFT", 0, -4)
    row.Meta:SetPoint("RIGHT", row, "RIGHT", -50, 0)
    row.Meta:SetWordWrap(false)
    row.Meta:SetMaxLines(1)

    row.Delete = Theme.CreateButton(row, 24, 24, "X", "danger")
    row.Delete:SetPoint("RIGHT", row, "RIGHT", -10, 0)
    row.Delete:SetScript("OnClick", function()
        if row.queueIndex then
            Queue.RemoveAt(row.queueIndex)
        end
    end)

    row:SetScript("OnEnter", function(selfRow)
        selfRow.isHovered = true
        MainWindow:RefreshQueueDragHighlights()
        showItemTooltip(selfRow, selfRow.bag, selfRow.slot, selfRow.itemLink)
    end)
    row:SetScript("OnLeave", function(selfRow)
        selfRow.isHovered = false
        MainWindow:RefreshQueueDragHighlights()
        hideTooltip()
    end)
    row:SetScript("OnMouseDown", function(selfRow)
        local cursorX, cursorY = GetCursorPosition()
        MainWindow.queuePressState = {
            row = selfRow,
            sourceIndex = selfRow.queueIndex,
            guid = selfRow.guid,
            startX = cursorX,
            startY = cursorY,
        }
    end)
    row:SetScript("OnMouseUp", function(selfRow)
        MainWindow.queuePressState = nil
        local wasDragging = MainWindow.queueDragState ~= nil
        if wasDragging then
            MainWindow:EndQueueDrag()
            return
        end

        local now = GetTime()
        if selfRow.lastClickTime and (now - selfRow.lastClickTime) < QUEUE_DOUBLE_CLICK and selfRow.queueIndex then
            selfRow.lastClickTime = nil
            Queue.RemoveAt(selfRow.queueIndex)
            return
        end
        selfRow.lastClickTime = now
    end)
    row:SetScript("OnUpdate", function(selfRow)
        local press = MainWindow.queuePressState
        if press and press.row == selfRow and not MainWindow.queueDragState then
            local cursorX, cursorY = GetCursorPosition()
            local deltaX = cursorX - press.startX
            local deltaY = cursorY - press.startY
            if (deltaX * deltaX + deltaY * deltaY) >= (QUEUE_DRAG_THRESHOLD * QUEUE_DRAG_THRESHOLD) then
                MainWindow:BeginQueueDrag(selfRow)
            end
        end
        if MainWindow.queueDragState and selfRow:IsMouseOver() then
            MainWindow:UpdateQueueDragFromCursor()
        end
    end)
    row:SetScript("OnReceiveDrag", function()
        enqueueCursorItem()
    end)

    function row.Refresh(rowFrame, entry, displayIndex)
        if not entry then
            rowFrame:Hide()
            return
        end

        rowFrame.queueIndex = displayIndex
        rowFrame.guid = entry.guid
        rowFrame.bag = entry.bag
        rowFrame.slot = entry.slot
        rowFrame.itemLink = entry.itemLink
        rowFrame.itemName = entry.itemName
        rowFrame.quality = entry.quality
        rowFrame.itemLevelText = itemLevelText(entry)
        rowFrame.slotText = entry.slotName or ""
        rowFrame.bindText = entry.bindLabel or ""
        rowFrame.IconWrap:SetIcon(entry.icon)
        rowFrame.IndexLabel:SetText(("#%d"):format(displayIndex))
        applyRowItemVisuals(rowFrame)
        rowFrame:Show()
    end

    return row
end

function MainWindow:RefreshQueueList()
    local entries = Queue.GetEntries()
    self.queueRows = self.queueRows or {}

    for index = 1, math.max(#entries, #self.queueRows) do
        local row = self.queueRows[index]
        if not row then
            row = self:CreateQueueRow(index)
            self.queueRows[index] = row
        end

        local entry = entries[index]
        if entry then
            row:Refresh(entry, index)
        else
            row.queueIndex = nil
            row:Hide()
        end
    end

    self.queueEmpty:SetShown(#entries == 0)
    self.queueContent:SetHeight(math.max(1, LIST_TOP_PADDING + (#entries * QUEUE_ROW_SPACING)))
    if self.queueScroll and self.queueScroll.UpdateScrollBar then
        self.queueScroll:UpdateScrollBar()
    end
    self:RefreshQueueDragHighlights()
end

function MainWindow:RefreshFilters(snapshot)
    local filters = addon.db.global.filters
    snapshot = snapshot or MainWindow.CollectSnapshot()
    local qualityCounts = snapshot.qualityCounts
    local expansionCounts = snapshot.expansionCounts
    local currentExpansionCount = snapshot.currentExpansionCount
    local currentOnly = filters.currentExpansionOnly == true

    if self.filterUncommon then
        self.filterUncommon:SetCheckedState(filters.uncommon == true)
        self.filterUncommon:SetCount(qualityCounts.uncommon)
    end
    if self.filterRare then
        self.filterRare:SetCheckedState(filters.rare == true)
        self.filterRare:SetCount(qualityCounts.rare)
    end
    if self.filterEpic then
        self.filterEpic:SetCheckedState(filters.epic == true)
        self.filterEpic:SetCount(qualityCounts.epic)
    end
    if self.filterCurrentExpansion then
        self.filterCurrentExpansion:SetCheckedState(currentOnly)
        self.filterCurrentExpansion:SetCount(currentExpansionCount)
    end

    local visibleIndex = 0
    for _, row in ipairs(self.expansionFilterRows or {}) do
        local expansionID = row.expansionID
        local count = expansionCounts[expansionID] or 0
        local stored = filters.expansions[expansionID]
        if stored == nil then
            stored = filters.expansions[tostring(expansionID)]
        end
        row:SetCheckedState(stored == true)
        row:SetCount(count)
        row:SetVisualEnabled(not currentOnly)

        if count > 0 then
            visibleIndex = visibleIndex + 1
            row:ClearAllPoints()
            row:SetPoint("TOPLEFT", self.expansionFilterContent, "TOPLEFT", 0, -((visibleIndex - 1) * 28))
            row:Show()
        else
            row:Hide()
        end
    end
    if self.expansionFilterContent then
        self.expansionFilterContent:SetHeight(math.max(1, visibleIndex * 28))
    end

    if self.minimapToggle then
        self.minimapToggle:SetCheckedState(not addon.db.global.minimap.hide)
    end
    if self.compartmentToggle then
        self.compartmentToggle:SetCheckedState(addon.db.global.minimap.showInCompartment == true)
    end
end

function MainWindow:Refresh()
    if not self.frame then
        return
    end

    local snapshot = MainWindow.CollectSnapshot()
    self:RefreshFilters(snapshot)
    self:RefreshBagList(snapshot)
    self:RefreshQueueList()
    self:RefreshQueueCount(snapshot)
    SecureDisenchant.UpdateVisual()
end

function MainWindow:Toggle()
    if not self.frame then
        self:Initialize()
    end

    if self.frame:IsShown() then
        self.frame:Hide()
    else
        self:Open()
    end
end

function MainWindow:Open()
    if not self.frame then
        self:Initialize()
    end

    self.frame:Show()
    self:ApplyWindowScale()
    self:Refresh()
end

local function qualityFilterCount(filters)
    local count = 0
    if filters.uncommon then
        count = count + 1
    end
    if filters.rare then
        count = count + 1
    end
    if filters.epic then
        count = count + 1
    end
    return count
end

function MainWindow:Initialize()
    if self.frame then
        return
    end

    L = addon.L

    local frame = CreateFrame("Frame", "DisenchanterWindow", UIParent, "BackdropTemplate")
    Theme.ApplySurface(frame, Theme.colors.window, Theme.colors.border)
    frame:SetSize(WINDOW_WIDTH, WINDOW_HEIGHT)
    frame:SetPoint("CENTER")
    frame:SetMovable(true)
    frame:SetToplevel(true)
    frame:SetFrameStrata("DIALOG")
    frame:SetFrameLevel(100)
    frame:SetClampedToScreen(true)
    frame:EnableMouse(true)
    frame:RegisterForDrag("LeftButton")
    frame:SetScript("OnMouseDown", function(window)
        window:Raise()
    end)
    frame:SetScript("OnDragStart", function(window)
        window:StartMoving()
    end)
    frame:SetScript("OnDragStop", function(window)
        window:StopMovingOrSizing()
    end)
    frame:SetScript("OnShow", function(window)
        window:Raise()
        MainWindow:ApplyWindowScale()
        MainWindow:Refresh()
    end)
    frame:SetScript("OnHide", function()
        MainWindow:CloseBagMenus()
    end)
    frame:SetScript("OnReceiveDrag", function()
        enqueueCursorItem()
    end)
    frame:Hide()

    local header = Theme.CreatePanel(frame, Theme.colors.titleBar, Theme.colors.border)
    header:SetPoint("TOPLEFT", frame, "TOPLEFT", 1, -1)
    header:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -1, -1)
    header:SetHeight(56)
    header:EnableMouse(true)
    header:RegisterForDrag("LeftButton")
    header:SetScript("OnDragStart", function()
        frame:Raise()
        frame:StartMoving()
    end)
    header:SetScript("OnDragStop", function()
        frame:StopMovingOrSizing()
    end)

    local logo = header:CreateTexture(nil, "ARTWORK")
    logo:SetSize(36, 36)
    logo:SetPoint("LEFT", header, "LEFT", 14, 0)
    logo:SetTexture(mediaTexture("icon-small.png"), nil, nil, "LINEAR")

    local title = Theme.CreateText(header, L["ADDON_NAME"], "heading")
    title:SetPoint("TOPLEFT", logo, "TOPRIGHT", 10, 2)
    Theme.SetFontColor(title, Theme.colors.text)

    local subtitle = Theme.CreateText(header, L["WINDOW_SUBTITLE"], "muted")
    subtitle:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -4)

    local accentLine = Theme.CreateAccentLine(header, 180)
    accentLine:SetPoint("BOTTOMLEFT", header, "BOTTOMLEFT", 14, 0)

    local closeButton = CreateFrame("Button", nil, header)
    closeButton:SetSize(24, 24)
    closeButton:SetPoint("TOPRIGHT", header, "TOPRIGHT", -14, -10)
    closeButton.Text = Theme.CreateText(closeButton, "X", "heading")
    closeButton.Text:SetPoint("CENTER", closeButton, "CENTER", 0, -1)
    Theme.SetFontColor(closeButton.Text, Theme.colors.accent)
    closeButton:SetScript("OnEnter", function(buttonFrame)
        Theme.SetFontColor(buttonFrame.Text, Theme.colors.text)
    end)
    closeButton:SetScript("OnLeave", function(buttonFrame)
        Theme.SetFontColor(buttonFrame.Text, Theme.colors.accent)
    end)
    closeButton:SetScript("OnClick", function()
        frame:Hide()
    end)

    table.insert(UISpecialFrames, "DisenchanterWindow")
    self.frame = frame

    self.sidebar = Theme.CreatePanel(frame, Theme.colors.sidebar, Theme.colors.borderSoft)
    self.sidebar:SetPoint("TOPLEFT", frame, "TOPLEFT", 20, -74)
    self.sidebar:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", 20, 64)
    self.sidebar:SetWidth(SIDEBAR_WIDTH)

    local sidebarTitle = Theme.CreateText(self.sidebar, HUD_EDIT_MODE_BAGS_LABEL, "heading")
    sidebarTitle:SetPoint("TOPLEFT", self.sidebar, "TOPLEFT", 16, -16)

    local sidebarDesc = Theme.CreateText(self.sidebar, L["SIDEBAR_BAGS_DESC"], "muted")
    sidebarDesc:SetPoint("TOPLEFT", sidebarTitle, "BOTTOMLEFT", 0, -6)
    sidebarDesc:SetWidth(SIDEBAR_WIDTH - 32)
    sidebarDesc:SetJustifyV("TOP")

    self.filtersButton = Theme.CreateButton(self.sidebar, 96, 32, FILTERS, "secondary")
    self.filtersButton:SetPoint("TOPLEFT", self.sidebar, "TOPLEFT", 16, -72)
    self.filtersButton.Label:SetWordWrap(false)
    self.filtersButton:SetScript("OnClick", function()
        MainWindow:ToggleBagMenu("filters")
    end)

    self.orderByButton = Theme.CreateButton(self.sidebar, 96, 32, L["BUTTON_ORDER_BY"], "secondary")
    self.orderByButton:SetPoint("LEFT", self.filtersButton, "RIGHT", 8, 0)
    self.orderByButton.Label:SetWordWrap(false)
    self.orderByButton:SetScript("OnClick", function()
        MainWindow:ToggleBagMenu("order")
    end)

    self.groupByButton = Theme.CreateButton(self.sidebar, 96, 32, L["BUTTON_GROUP_BY"], "secondary")
    self.groupByButton:SetPoint("LEFT", self.orderByButton, "RIGHT", 8, 0)
    self.groupByButton:SetPoint("RIGHT", self.sidebar, "RIGHT", -16, 0)
    self.groupByButton:SetHeight(32)
    self.groupByButton.Label:SetWordWrap(false)
    self.groupByButton:SetScript("OnClick", function()
        MainWindow:ToggleBagMenu("group")
    end)

    self.addAllButton = Theme.CreateButton(self.sidebar, 148, 32, L["BUTTON_ADD_ALL"], "primary")
    self.addAllButton:SetPoint("BOTTOMLEFT", self.sidebar, "BOTTOMLEFT", 16, 16)
    self.addAllButton:SetPoint("BOTTOMRIGHT", self.sidebar, "BOTTOMRIGHT", -16, 16)
    self.addAllButton:SetHeight(32)
    self.addAllButton:SetScript("OnClick", function()
        Queue.AddAllMatching()
    end)

    self.bagScrollCard = Theme.CreatePanel(self.sidebar, Theme.colors.cardInset, Theme.colors.borderMuted)
    self.bagScrollCard:SetPoint("TOPLEFT", self.sidebar, "TOPLEFT", 16, -118)
    self.bagScrollCard:SetPoint("BOTTOMRIGHT", self.addAllButton, "TOPRIGHT", 0, 10)

    self.bagScroll, self.bagListContent = Theme.CreateStyledScrollArea(self.bagScrollCard, SIDEBAR_WIDTH - 70)
    self.bagScroll:SetPoint("TOPLEFT", self.bagScrollCard, "TOPLEFT", 8, -8)
    self.bagScroll:SetPoint("BOTTOMRIGHT", self.bagScrollCard, "BOTTOMRIGHT", -22, 10)
    self.bagScroll:HookScript("OnSizeChanged", function(_, width)
        if width and width > 0 then
            self.bagListContent:SetWidth(width)
        end
    end)

    self.bagEmpty = Theme.CreateText(self.bagScrollCard, L["EMPTY_BAGS"], "muted")
    self.bagEmpty:SetPoint("TOPLEFT", self.bagScrollCard, "TOPLEFT", 16, -16)
    self.bagEmpty:SetPoint("RIGHT", self.bagScrollCard, "RIGHT", -16, 0)
    self.bagEmpty:SetJustifyV("TOP")

    self.workspace = Theme.CreatePanel(frame, Theme.colors.workspace, Theme.colors.borderSoft)
    self.workspace:SetPoint("TOPLEFT", self.sidebar, "TOPRIGHT", 16, 0)
    self.workspace:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -20, 64)

    local queueToolbar = Theme.CreateCard(self.workspace, nil, 58)
    queueToolbar:SetPoint("TOPLEFT", self.workspace, "TOPLEFT", 16, -16)
    queueToolbar:SetPoint("TOPRIGHT", self.workspace, "TOPRIGHT", -16, -16)

    local queueTitle = Theme.CreateText(queueToolbar, L["WORKSPACE_QUEUE_TITLE"], "heading")
    queueTitle:SetPoint("TOPLEFT", queueToolbar, "TOPLEFT", 14, -10)

    self.queueCount = Theme.CreateText(queueToolbar, "", "label")
    self.queueCount:SetPoint("LEFT", queueTitle, "RIGHT", 12, 0)
    Theme.SetFontColor(self.queueCount, Theme.colors.textMuted)

    local queueDesc = Theme.CreateText(queueToolbar, L["WORKSPACE_QUEUE_DESC"], "muted")
    queueDesc:SetPoint("TOPLEFT", queueTitle, "BOTTOMLEFT", 0, -4)
    queueDesc:SetPoint("RIGHT", queueToolbar, "RIGHT", -100, 0)

    self.clearButton = Theme.CreateButton(queueToolbar, 78, 26, L["BUTTON_CLEAR_QUEUE"], "danger")
    self.clearButton:SetPoint("RIGHT", queueToolbar, "RIGHT", -14, 0)
    self.clearButton:SetScript("OnClick", function()
        Queue.Clear()
    end)

    local deButton = SecureDisenchant.EnsureButton(self.workspace)
    deButton:ClearAllPoints()
    deButton:SetPoint("BOTTOMLEFT", self.workspace, "BOTTOMLEFT", 16, 16)
    deButton:SetPoint("BOTTOMRIGHT", self.workspace, "BOTTOMRIGHT", -16, 16)
    deButton:SetHeight(48)

    self.queueScrollCard = Theme.CreatePanel(self.workspace, Theme.colors.cardInset, Theme.colors.borderMuted)
    self.queueScrollCard:SetPoint("TOPLEFT", queueToolbar, "BOTTOMLEFT", 0, -12)
    self.queueScrollCard:SetPoint("BOTTOMRIGHT", deButton, "TOPRIGHT", 0, 12)
    self.queueScrollCard:EnableMouse(true)
    self.queueScrollCard:SetScript("OnMouseUp", function()
        self:EndQueueDrag()
    end)
    self.queueScrollCard:SetScript("OnUpdate", function()
        if self.queueDragState then
            self:UpdateQueueDragFromCursor()
        end
    end)
    self.queueScrollCard:SetScript("OnReceiveDrag", function()
        enqueueCursorItem()
    end)

    self.queueScroll, self.queueContent = Theme.CreateStyledScrollArea(self.queueScrollCard, 680)
    self.queueScroll:SetPoint("TOPLEFT", self.queueScrollCard, "TOPLEFT", 8, -8)
    self.queueScroll:SetPoint("BOTTOMRIGHT", self.queueScrollCard, "BOTTOMRIGHT", -22, 10)
    self.queueScroll:HookScript("OnSizeChanged", function(_, width)
        if width and width > 0 then
            self.queueContent:SetWidth(width)
        end
    end)

    self.queueInsertLine = self.queueContent:CreateTexture(nil, "OVERLAY")
    self.queueInsertLine:SetHeight(2)
    self.queueInsertLine:SetColorTexture(Theme.UnpackColor(Theme.colors.accent))
    self.queueInsertLine:Hide()

    self.queueEmpty = Theme.CreateText(self.queueScrollCard, L["EMPTY_QUEUE"], "muted")
    self.queueEmpty:SetPoint("TOPLEFT", self.queueScrollCard, "TOPLEFT", 16, -16)
    self.queueEmpty:SetPoint("RIGHT", self.queueScrollCard, "RIGHT", -16, 0)
    self.queueEmpty:SetJustifyV("TOP")

    self.filtersOverlay = CreateFrame("Frame", nil, frame)
    self.filtersOverlay:SetAllPoints(frame)
    self.filtersOverlay:EnableMouse(true)
    self.filtersOverlay:Hide()
    self.filtersOverlay:SetScript("OnMouseDown", function()
        MainWindow:CloseBagMenus()
    end)

    self.filtersPanel = Theme.CreateCard(self.filtersOverlay, 320, 430)
    self.filtersPanel:SetPoint("TOPLEFT", self.filtersButton, "BOTTOMLEFT", 0, -8)
    self.filtersPanel:EnableMouse(true)
    self.filtersPanel:Hide()

    local qualityHeading = Theme.CreateText(self.filtersPanel, QUALITY, "heading")
    qualityHeading:SetPoint("TOPLEFT", self.filtersPanel, "TOPLEFT", 16, -14)

    local function bindQualityFilter(checkbox, key)
        checkbox:SetScript("OnClick", function(selfBox)
            local filters = addon.db.global.filters
            local nextValue = not filters[key]
            if not nextValue and qualityFilterCount(filters) <= 1 then
                selfBox:SetCheckedState(true)
                return
            end
            filters[key] = nextValue
            selfBox:SetCheckedState(nextValue)
            MainWindow:Refresh()
        end)
    end

    self.filterUncommon = Theme.CreateCheckbox(self.filtersPanel, 288, ITEM_QUALITY2_DESC)
    self.filterUncommon:SetPoint("TOPLEFT", qualityHeading, "BOTTOMLEFT", 0, -10)
    self.filterUncommon:SetHeight(26)
    bindQualityFilter(self.filterUncommon, "uncommon")

    self.filterRare = Theme.CreateCheckbox(self.filtersPanel, 288, ITEM_QUALITY3_DESC)
    self.filterRare:SetPoint("TOPLEFT", self.filterUncommon, "BOTTOMLEFT", 0, -6)
    self.filterRare:SetHeight(26)
    bindQualityFilter(self.filterRare, "rare")

    self.filterEpic = Theme.CreateCheckbox(self.filtersPanel, 288, ITEM_QUALITY4_DESC)
    self.filterEpic:SetPoint("TOPLEFT", self.filterRare, "BOTTOMLEFT", 0, -6)
    self.filterEpic:SetHeight(26)
    bindQualityFilter(self.filterEpic, "epic")

    local expansionHeading = Theme.CreateText(self.filtersPanel, EXPANSION_FILTER_TEXT, "heading")
    expansionHeading:SetPoint("TOPLEFT", self.filterEpic, "BOTTOMLEFT", 0, -16)

    self.filterCurrentExpansion = Theme.CreateCheckbox(self.filtersPanel, 288, L["FILTER_CURRENT_EXPANSION"])
    self.filterCurrentExpansion:SetPoint("TOPLEFT", expansionHeading, "BOTTOMLEFT", 0, -10)
    self.filterCurrentExpansion:SetHeight(26)
    self.filterCurrentExpansion:SetScript("OnClick", function(selfBox)
        local filters = addon.db.global.filters
        filters.currentExpansionOnly = not filters.currentExpansionOnly
        selfBox:SetCheckedState(filters.currentExpansionOnly == true)
        MainWindow:Refresh()
    end)

    local expansionScrollCard = Theme.CreatePanel(self.filtersPanel, Theme.colors.cardInset, Theme.colors.borderMuted)
    expansionScrollCard:SetPoint("TOPLEFT", self.filterCurrentExpansion, "BOTTOMLEFT", 0, -8)
    expansionScrollCard:SetPoint("BOTTOMRIGHT", self.filtersPanel, "BOTTOMRIGHT", -16, 16)

    local expansionScroll, expansionContent = Theme.CreateStyledScrollArea(expansionScrollCard, 268)
    expansionScroll:SetPoint("TOPLEFT", expansionScrollCard, "TOPLEFT", 8, -8)
    expansionScroll:SetPoint("BOTTOMRIGHT", expansionScrollCard, "BOTTOMRIGHT", -22, 8)

    self.expansionFilterRows = {}
    self.expansionFilterContent = expansionContent
    local minLevel, maxLevel = Eligibility.GetExpansionLevelRange()
    local expansionIndex = 0
    for expansionID = maxLevel, minLevel, -1 do
        local expansionName = Eligibility.GetExpansionName(expansionID)
        if expansionName then
            expansionIndex = expansionIndex + 1
            local row = Theme.CreateCheckbox(expansionContent, 260, expansionName)
            row:SetHeight(24)
            row:SetPoint("TOPLEFT", expansionContent, "TOPLEFT", 0, -((expansionIndex - 1) * 28))
            row.expansionID = expansionID
            row:SetScript("OnClick", function(selfBox)
                if addon.db.global.filters.currentExpansionOnly then
                    selfBox:SetCheckedState(addon.db.global.filters.expansions[expansionID] == true)
                    return
                end
                local expansions = addon.db.global.filters.expansions
                expansions[expansionID] = not expansions[expansionID]
                selfBox:SetCheckedState(expansions[expansionID] == true)
                MainWindow:Refresh()
            end)
            self.expansionFilterRows[expansionIndex] = row
        end
    end
    expansionContent:SetHeight(math.max(1, expansionIndex * 28))

    local function createBagViewRadioPanel(anchor, options, field)
        local height = 16 + (#options * 30)
        local panel = Theme.CreateCard(self.filtersOverlay, 188, height)
        panel:SetPoint("TOPLEFT", anchor, "BOTTOMLEFT", 0, -8)
        panel:EnableMouse(true)
        panel:Hide()

        local radios = {}
        for index = 1, #options do
            local optionKey = options[index]
            local radio = Theme.CreateCheckbox(panel, 156, bagMenuOptionLabel(optionKey))
            radio:SetHeight(24)
            radio:SetPoint("TOPLEFT", panel, "TOPLEFT", 16, -((index - 1) * 30 + 12))
            radio.optionKey = optionKey
            radio:SetScript("OnClick", function()
                local bagView = bagViewSettings()
                bagView[field] = optionKey
                MainWindow:RefreshBagViewRadios()
                MainWindow:Refresh()
            end)
            radios[index] = radio
        end

        return panel, radios
    end

    self.orderByPanel, self.orderByRadios = createBagViewRadioPanel(
        self.orderByButton,
        BAG_MENU_ORDER_OPTIONS,
        "orderBy"
    )
    self.groupByPanel, self.groupByRadios = createBagViewRadioPanel(
        self.groupByButton,
        BAG_MENU_GROUP_OPTIONS,
        "groupBy"
    )

    self.footer = Theme.CreatePanel(frame, Theme.colors.titleBar, Theme.colors.borderSoft)
    self.footer:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", 20, 16)
    self.footer:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -20, 16)
    self.footer:SetHeight(36)

    self.minimapToggle = Theme.CreateCheckbox(self.footer, 120, MINIMAP_LABEL)
    self.minimapToggle:SetPoint("RIGHT", self.footer, "RIGHT", -14, 0)
    self.minimapToggle:SetScript("OnClick", function(checkbox)
        local currentlyVisible = checkbox:GetCheckedState()
        addon.db.global.minimap.hide = currentlyVisible
        checkbox:SetCheckedState(not currentlyVisible)
        addon.UpdateMinimapIcon()
    end)

    self.compartmentToggle = Theme.CreateCheckbox(self.footer, 172, L["LABEL_COMPARTMENT"])
    self.compartmentToggle:SetPoint("RIGHT", self.minimapToggle, "LEFT", -16, 0)
    self.compartmentToggle:SetScript("OnClick", function(checkbox)
        local currentlyVisible = checkbox:GetCheckedState()
        addon.db.global.minimap.showInCompartment = not currentlyVisible
        checkbox:SetCheckedState(not currentlyVisible)
        addon.UpdateCompartmentIcon()
    end)

    local watermark = CreateFrame("Frame", nil, frame)
    watermark:SetAllPoints(frame)
    watermark:EnableMouse(false)
    watermark:SetFrameLevel((frame:GetFrameLevel() or 100) + 8)
    local watermarkTexture = watermark:CreateTexture(nil, "ARTWORK")
    watermarkTexture:SetSize(560, 560)
    watermarkTexture:SetPoint("CENTER", watermark, "CENTER", 0, -12)
    watermarkTexture:SetTexture(mediaTexture("icon.png"), nil, nil, "LINEAR")
    watermarkTexture:SetDesaturated(true)
    watermarkTexture:SetAlpha(0.025)

    self:ApplyWindowScale()
end
