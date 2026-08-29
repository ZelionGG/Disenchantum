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
local BAG_CRAFTED_ICON_SIZE = 16
local QUEUE_CRAFTED_ICON_SIZE = 24
local BAG_CRAFTED_ICON_GAP = 4
local BAG_TITLE_RIGHT_INSET = 50
local BAG_TITLE_CRAFTED_INSET = BAG_TITLE_RIGHT_INSET + BAG_CRAFTED_ICON_SIZE + BAG_CRAFTED_ICON_GAP
local SESSION_CHIP_SIZE = 28
local SESSION_CHIP_GAP = 6
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

local REAGENT_TOOLTIP_ICON = {
    width = 14,
    height = 14,
    anchor = Enum.TooltipTextureAnchor and Enum.TooltipTextureAnchor.LeftCenter or nil,
    margin = { left = 0, right = 6, top = 0, bottom = 0 },
}

local function getCraftingQualityInfo(itemIDOrLink)
    if not itemIDOrLink or not C_TradeSkillUI then
        return nil
    end
    local info
    if C_TradeSkillUI.GetItemReagentQualityInfo then
        info = C_TradeSkillUI.GetItemReagentQualityInfo(itemIDOrLink)
    end
    if not info and C_TradeSkillUI.GetItemCraftedQualityInfo then
        info = C_TradeSkillUI.GetItemCraftedQualityInfo(itemIDOrLink)
    end
    return info
end

local function createCraftedIcon(parent, size, atlas)
    local icon = parent:CreateTexture(nil, "OVERLAY")
    icon:SetAtlas(atlas or "UI-HUD-Minimap-CraftingOrder-Up")
    icon:SetSize(size, size)
    icon:Hide()
    return icon
end

local function groupReagentsByExpansion(reagents)
    local groupsByID = {}
    local order = {}
    for index = 1, #reagents do
        local entry = reagents[index]
        local expansionID = entry.expansionID
        if expansionID == nil and entry.itemID then
            expansionID = select(15, C_Item.GetItemInfo(entry.itemID))
            entry.expansionID = expansionID
        end
        local key = expansionID
        if key == nil then
            key = "other"
        end
        local group = groupsByID[key]
        if not group then
            group = {
                key = key,
                expansionID = expansionID,
                entries = {},
            }
            groupsByID[key] = group
            order[#order + 1] = group
        end
        group.entries[#group.entries + 1] = entry
    end

    table.sort(order, function(left, right)
        if left.expansionID == nil then
            return false
        end
        if right.expansionID == nil then
            return true
        end
        return left.expansionID > right.expansionID
    end)

    for index = 1, #order do
        table.sort(order[index].entries, function(left, right)
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
    end

    return order
end

local function hideTooltip()
    if GameTooltip then
        GameTooltip:Hide()
    end
end

local function showSessionTooltip(owner)
    if not owner or not GameTooltip then
        return
    end

    L = L or addon.L
    local session = addon.Session
    local itemCount = (session and session.itemsDisenchanted) or 0
    local reagents = (session and session.GetReagents and session.GetReagents()) or {}
    if itemCount == 0 and #reagents == 0 then
        return
    end

    GameTooltip:SetOwner(owner, "ANCHOR_TOP")
    GameTooltip:AddLine((L["FMT_SESSION_ITEMS"]):format(itemCount))

    local groups = groupReagentsByExpansion(reagents)
    for groupIndex = 1, #groups do
        local group = groups[groupIndex]
        local heading = Eligibility.GetExpansionName(group.expansionID) or OTHER
        local hr, hg, hb = Theme.UnpackColor(Theme.colors.accent)
        if groupIndex > 1 then
            GameTooltip:AddLine(" ")
        end
        GameTooltip:AddLine(heading, hr, hg, hb)

        for index = 1, #group.entries do
            local entry = group.entries[index]
            local r, g, b = 1, 1, 1
            if entry.quality and C_Item.GetItemQualityColor then
                r, g, b = C_Item.GetItemQualityColor(entry.quality)
            end
            local name = entry.itemName or ""
            local craftingInfo = getCraftingQualityInfo(entry.itemLink or entry.itemID)
            if craftingInfo and craftingInfo.iconSmall and CreateAtlasMarkup then
                name = CreateAtlasMarkup(craftingInfo.iconSmall, 16, 16) .. " " .. name
            end
            GameTooltip:AddDoubleLine(
                name,
                (L["FMT_SESSION_CHIP_COUNT"]):format(entry.count or 0),
                r,
                g,
                b,
                1,
                1,
                1
            )
            if GameTooltip.AddTexture and entry.icon then
                GameTooltip:AddTexture(entry.icon, REAGENT_TOOLTIP_ICON)
            end
        end
    end
    GameTooltip:Show()
end

local function itemLevelText(entry)
    if entry and entry.itemLevel then
        return tostring(math.floor(entry.itemLevel + 0.5))
    end
    return ""
end

local function applyRowItemVisuals(row)
    row.Title:SetText(row.itemName or "")
    if row.quality and C_Item.GetItemQualityColor then
        local r, g, b = C_Item.GetItemQualityColor(row.quality)
        row.Title:SetTextColor(r, g, b, 1)
    else
        Theme.SetFontColor(row.Title, Theme.colors.text)
    end

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

    if row.CraftedIcon then
        local crafted = Eligibility.IsCraftedEquipment(row.itemLink)
        if row.Delete then
            row.CraftedIcon:SetShown(crafted)
        elseif crafted then
            row.Title:SetPoint("RIGHT", row, "RIGHT", -BAG_TITLE_CRAFTED_INSET, 0)
            local shownWidth = math.min(row.Title:GetStringWidth() or 0, row.Title:GetWidth() or 0)
            row.CraftedIcon:ClearAllPoints()
            row.CraftedIcon:SetPoint("LEFT", row.Title, "LEFT", shownWidth + BAG_CRAFTED_ICON_GAP, 0)
            row.CraftedIcon:Show()
        else
            row.Title:SetPoint("RIGHT", row, "RIGHT", -BAG_TITLE_RIGHT_INSET, 0)
            row.CraftedIcon:Hide()
        end
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
        countSkipGuids = Queue.consumedGuids,
    })
end

function MainWindow:AcquireSessionChip(index)
    local chip = self.sessionChipPool[index]
    if chip then
        return chip
    end

    chip = CreateFrame("Button", nil, self.sessionChips)
    chip:SetSize(SESSION_CHIP_SIZE + 2, SESSION_CHIP_SIZE + 2)

    chip.IconWrap = Theme.CreateItemIcon(chip, SESSION_CHIP_SIZE)
    chip.IconWrap:SetAllPoints(chip)
    chip.IconWrap:EnableMouse(false)

    chip.Count = chip.IconWrap:CreateFontString(nil, "OVERLAY", "NumberFontNormal")
    chip.Count:SetPoint("BOTTOMRIGHT", chip.IconWrap, "BOTTOMRIGHT", -1, 1)
    chip.Count:SetJustifyH("RIGHT")

    chip:SetScript("OnEnter", function(selfChip)
        if selfChip.isOverflow then
            showSessionTooltip(selfChip)
        else
            showItemTooltip(selfChip, nil, nil, selfChip.itemLink)
        end
    end)
    chip:SetScript("OnLeave", hideTooltip)

    self.sessionChipPool[index] = chip
    return chip
end

function MainWindow:RefreshSession()
    if not self.sessionCard or not self.sessionCountHit then
        return
    end

    L = L or addon.L
    local session = addon.Session
    local itemCount = (session and session.itemsDisenchanted) or 0
    self.sessionCount:SetText((L["FMT_SESSION_ITEMS"]):format(itemCount))
    local countWidth = math.max(72, (self.sessionCount:GetStringWidth() or 72) + 4)
    self.sessionCountHit:SetSize(countWidth, 22)

    local reagents = (session and session.GetReagents and session.GetReagents()) or {}
    local hasReagents = #reagents > 0
    self.sessionEmpty:SetShown(itemCount == 0 and not hasReagents)
    self.sessionChips:SetShown(hasReagents)

    local chipWidth = SESSION_CHIP_SIZE + 2
    local stride = chipWidth + SESSION_CHIP_GAP
    local available = self.sessionChips:GetWidth() or 0
    local shown = #reagents
    local overflow = 0
    if available > 0 and #reagents > 0 then
        local maxChips = math.max(1, math.floor((available + SESSION_CHIP_GAP) / stride))
        if #reagents > maxChips then
            shown = math.max(0, maxChips - 1)
            overflow = #reagents - shown
        end
    end

    local pool = self.sessionChipPool
    for index = 1, shown do
        local entry = reagents[index]
        local chip = self:AcquireSessionChip(index)
        chip.isOverflow = false
        chip.itemLink = entry.itemLink
        chip.IconWrap.Texture:Show()
        chip.IconWrap:SetIcon(entry.icon)
        chip.IconWrap:SetQuality(entry.quality)
        local craftingInfo = getCraftingQualityInfo(entry.itemLink or entry.itemID)
        chip.IconWrap:SetCraftingQuality(craftingInfo and craftingInfo.iconInventory)
        chip.Count:ClearAllPoints()
        chip.Count:SetPoint("BOTTOMRIGHT", chip.IconWrap, "BOTTOMRIGHT", -1, 1)
        chip.Count:SetText((L["FMT_SESSION_CHIP_COUNT"]):format(entry.count))
        chip:ClearAllPoints()
        chip:SetPoint("LEFT", self.sessionChips, "LEFT", (index - 1) * stride, 0)
        chip:Show()
    end

    local used = shown
    if overflow > 0 then
        used = shown + 1
        local chip = self:AcquireSessionChip(used)
        chip.isOverflow = true
        chip.itemLink = nil
        chip.IconWrap.Texture:Hide()
        chip.IconWrap:SetQuality(nil)
        chip.IconWrap:SetCraftingQuality(nil)
        chip.Count:ClearAllPoints()
        chip.Count:SetPoint("CENTER", chip.IconWrap, "CENTER", 0, 0)
        chip.Count:SetText((L["FMT_SESSION_MORE"]):format(overflow))
        chip:ClearAllPoints()
        chip:SetPoint("LEFT", self.sessionChips, "LEFT", shown * stride, 0)
        chip:Show()
    end

    for index = used + 1, #pool do
        pool[index]:Hide()
    end
end

function MainWindow:RefreshQueueCount(snapshot)
    if not self.queueCount then
        return
    end

    snapshot = snapshot or MainWindow.CollectSnapshot()
    local queued = Queue.Count()
    self.queueCount:SetText((L["FMT_QUEUE_COUNT"]):format(queued, queued + #snapshot.items))
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
    if self.blacklistButton then
        self.blacklistButton:SetSelected(false)
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
    if self.blacklistPanel then
        self.blacklistPanel:Hide()
    end
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
    elseif which == "blacklist" then
        self:RefreshBlacklistList()
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
    if self.blacklistPanel then
        self.blacklistPanel:SetShown(which == "blacklist")
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
    if self.blacklistPanel then
        self.blacklistPanel:SetFrameLevel(overlayLevel + 2)
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
    if self.blacklistButton then
        self.blacklistButton:SetSelected(which == "blacklist")
    end
end

function MainWindow:ToggleBagMenu(which)
    local panel
    if which == "filters" then
        panel = self.filtersPanel
    elseif which == "order" then
        panel = self.orderByPanel
    elseif which == "blacklist" then
        panel = self.blacklistPanel
    else
        panel = self.groupByPanel
    end
    if self.filtersOverlay and self.filtersOverlay:IsShown() and panel and panel:IsShown() then
        self:CloseBagMenus()
        return
    end
    self:OpenBagMenu(which)
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
    row.Title:SetPoint("RIGHT", row, "RIGHT", -BAG_TITLE_RIGHT_INSET, 0)
    row.Title:SetJustifyH("LEFT")
    row.Title:SetWordWrap(false)
    row.Title:SetMaxLines(1)

    row.CraftedIcon = createCraftedIcon(row, BAG_CRAFTED_ICON_SIZE)

    row.Meta = Theme.CreateText(row, "", "muted")
    row.Meta:SetPoint("TOPLEFT", row.Title, "BOTTOMLEFT", 0, -4)
    row.Meta:SetPoint("RIGHT", row, "RIGHT", -BAG_TITLE_RIGHT_INSET, 0)
    row.Meta:SetWordWrap(false)
    row.Meta:SetMaxLines(1)

    row.Add = Theme.CreateButton(row, 24, 24, "+", "secondary")
    row.Add:SetPoint("RIGHT", row, "RIGHT", -10, 0)
    -- Larger "+" sits a bit low in 24px; nudge Y more than X.
    row.Add.labelOffsetX = 1
    row.Add.labelOffsetY = 2
    row.Add.Label:ClearAllPoints()
    row.Add.Label:SetPoint("CENTER", 1, 2)
    row.Add.labelColor = Theme.colors.accent
    Theme.SetFontColor(row.Add.Label, Theme.colors.accent)
    local plusFont, plusSize, plusFlags = row.Add.Label:GetFont()
    if plusFont then
        row.Add.Label:SetFont(plusFont, (plusSize or 14) + 2, plusFlags)
    end
    row.Add:SetScript("OnClick", function()
        if row.bag and row.slot then
            Queue.AddFromBag(row.bag, row.slot)
        end
    end)

    row:RegisterForClicks("LeftButtonUp", "RightButtonUp")
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
    row:SetScript("OnClick", function(selfRow, mouseButton)
        if mouseButton == "RightButton" then
            hideTooltip()
            Queue.RequestBlacklist({
                itemID = selfRow.itemID,
                itemName = selfRow.itemName,
                itemLink = selfRow.itemLink,
                icon = selfRow.icon,
                quality = selfRow.quality,
            })
        end
    end)
    row:SetScript("OnMouseDown", function(selfRow, button)
        if button ~= "LeftButton" then
            return
        end
        local cursorX, cursorY = GetCursorPosition()
        MainWindow.bagPressState = {
            row = selfRow,
            bag = selfRow.bag,
            slot = selfRow.slot,
            guid = selfRow.guid,
            startX = cursorX,
            startY = cursorY,
        }
    end)
    row:SetScript("OnMouseUp", function(selfRow, button)
        MainWindow.bagPressState = nil
        if MainWindow.queueDragState then
            MainWindow:EndQueueDrag()
            return
        end
        if MainWindow.bagDragState then
            MainWindow:EndBagDrag()
            return
        end
        if button ~= "LeftButton" then
            return
        end

        local now = GetTime()
        if selfRow.lastClickTime and (now - selfRow.lastClickTime) < QUEUE_DOUBLE_CLICK and selfRow.bag and selfRow.slot then
            selfRow.lastClickTime = nil
            Queue.AddFromBag(selfRow.bag, selfRow.slot)
            return
        end
        selfRow.lastClickTime = now
    end)
    row:SetScript("OnUpdate", function(selfRow)
        local press = MainWindow.bagPressState
        if press and press.row == selfRow and not MainWindow.bagDragState then
            local cursorX, cursorY = GetCursorPosition()
            local deltaX = cursorX - press.startX
            local deltaY = cursorY - press.startY
            if (deltaX * deltaX + deltaY * deltaY) >= (QUEUE_DRAG_THRESHOLD * QUEUE_DRAG_THRESHOLD) then
                MainWindow:BeginBagDrag(selfRow)
            end
        end
        if MainWindow.queueDragState then
            if not IsMouseButtonDown("LeftButton") then
                MainWindow:EndQueueDrag()
                return
            end
            MainWindow:UpdateQueueDragFromCursor()
            return
        end
        if MainWindow.bagDragState then
            if not IsMouseButtonDown("LeftButton") then
                MainWindow:EndBagDrag()
                return
            end
            MainWindow:UpdateQueueDragFromCursor()
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

        rowFrame.guid = entry.guid
        rowFrame.bag = entry.bag
        rowFrame.slot = entry.slot
        rowFrame.itemLink = entry.itemLink
        rowFrame.itemID = entry.itemID
        rowFrame.icon = entry.icon
        rowFrame.itemName = entry.itemName
        rowFrame.quality = entry.quality
        rowFrame.itemLevelText = itemLevelText(entry)
        rowFrame.slotText = entry.slotName or ""
        rowFrame.bindText = entry.bindLabel or ""
        rowFrame.IconWrap:SetIcon(entry.icon)
        Theme.UpdateButtonColors(rowFrame)
        rowFrame:Show()
        applyRowItemVisuals(rowFrame)
    end

    return row
end

function MainWindow:CreateBlacklistRow()
    local row = Theme.CreateCard(self.blacklistListContent, nil, 48)
    row:EnableMouse(true)

    row.IconWrap = Theme.CreateItemIcon(row, 32)
    row.IconWrap:SetPoint("LEFT", row, "LEFT", 8, 0)
    row.IconWrap:EnableMouse(false)

    row.Title = Theme.CreateText(row, "", "body")
    row.Title:SetPoint("LEFT", row.IconWrap, "RIGHT", 10, 0)
    row.Title:SetPoint("RIGHT", row, "RIGHT", -44, 0)
    row.Title:SetJustifyH("LEFT")
    row.Title:SetWordWrap(false)
    row.Title:SetMaxLines(1)

    row.Delete = Theme.CreateButton(row, 24, 24, "X", "danger")
    row.Delete:SetPoint("RIGHT", row, "RIGHT", -10, 0)
    row.Delete.labelOffsetX = 1
    row.Delete.labelOffsetY = 1
    row.Delete.Label:SetPoint("CENTER", 1, 1)
    row.Delete:SetScript("OnClick", function()
        if row.itemID then
            Queue.BlacklistRemove(row.itemID)
        end
    end)

    row:SetScript("OnEnter", function(selfRow)
        showItemTooltip(selfRow, nil, nil, selfRow.itemLink)
    end)
    row:SetScript("OnLeave", hideTooltip)

    function row.Refresh(rowFrame, entry)
        if not entry then
            rowFrame:Hide()
            return
        end

        rowFrame.itemID = entry.itemID
        rowFrame.itemLink = entry.itemLink
        rowFrame.itemName = entry.itemName
        rowFrame.quality = entry.quality
        rowFrame.IconWrap:SetIcon(entry.icon)
        applyRowItemVisuals(rowFrame)
        rowFrame:Show()
    end

    return row
end

function MainWindow:RefreshBlacklistList()
    if not self.blacklistButton then
        return
    end

    local entries = Queue.GetBlacklistEntries()
    if self.blacklistCount then
        if #entries > 0 then
            self.blacklistCount:SetText(("(%d)"):format(#entries))
        else
            self.blacklistCount:SetText("")
        end
    end

    if not self.blacklistListContent then
        return
    end
    self.blacklistRows = self.blacklistRows or {}

    for index = 1, math.max(#entries, #self.blacklistRows) do
        local row = self.blacklistRows[index]
        if not row then
            row = self:CreateBlacklistRow()
            self.blacklistRows[index] = row
        end

        local entry = entries[index]
        if entry then
            row:SetPoint("TOPLEFT", self.blacklistListContent, "TOPLEFT", 0, -((index - 1) * 56))
            row:SetPoint("TOPRIGHT", self.blacklistListContent, "TOPRIGHT", 0, -((index - 1) * 56))
            row:Refresh(entry)
        else
            row:Hide()
        end
    end

    self.blacklistListContent:SetHeight(math.max(1, #entries * 56))
    if self.blacklistEmpty then
        self.blacklistEmpty:SetShown(#entries == 0)
    end
    if self.blacklistScroll and self.blacklistScroll.UpdateScrollBar then
        self.blacklistScroll:UpdateScrollBar()
    end
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
    snapshot = snapshot or MainWindow.CollectSnapshot()
    local items = snapshot.items
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

    if #items == 0 then
        local hiddenByFilters = snapshot.hiddenByFilters or 0
        if hiddenByFilters > 0 then
            self.bagEmpty:SetText((L["FMT_BAGS_HIDDEN_BY_FILTERS"]):format(hiddenByFilters))
        else
            self.bagEmpty:SetText(L["EMPTY_BAGS"])
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

    local dragState = self.queueDragState or self.bagDragState
    if not dragState then
        line:Hide()
        return
    end
    if (self.bagDragState or self.queueDragState) and not self:IsCursorOverQueue() then
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
        if self.bagDragState then
            line:ClearAllPoints()
            line:SetPoint("LEFT", self.queueContent, "TOPLEFT", 8, -math.floor(LIST_TOP_PADDING * 0.5))
            line:SetPoint("RIGHT", self.queueContent, "TOPRIGHT", -8, -math.floor(LIST_TOP_PADDING * 0.5))
            line:Show()
            return
        end
        line:Hide()
        return
    end

    local insertIndex = dragState.insertIndex or dragState.sourceIndex or 1
    local sourceIndex = dragState.sourceIndex
    if sourceIndex and (insertIndex == sourceIndex or insertIndex == sourceIndex + 1) then
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
                Theme.ApplySurface(row, Theme.colors.cardSoft, Theme.colors.accentAlt)
            elseif row.queueIndex == 1 then
                Theme.SetCardTone(row, "accent")
            else
                Theme.ApplySurface(row, Theme.colors.card, Theme.colors.borderSoft)
            end
        end
    end
    self:UpdateQueueInsertLine()
    self:UpdateBagsDropHighlight()
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
    self:ShowDragGhost(row)
    self:RefreshQueueDragHighlights()
end

function MainWindow:UpdateQueueDragFromCursor()
    local dragState = self.queueDragState or self.bagDragState
    if not dragState then
        return
    end

    local visibleRows = {}
    for _, row in ipairs(self.queueRows or {}) do
        if row:IsShown() and row.queueIndex then
            visibleRows[#visibleRows + 1] = row
        end
    end
    if #visibleRows == 0 then
        if self.bagDragState and self.bagDragState.insertIndex ~= 1 then
            self.bagDragState.insertIndex = 1
        end
        self:UpdateQueueInsertLine()
        self:UpdateBagsDropHighlight()
        self:UpdateDragGhostPosition()
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

    if insertIndex and dragState.insertIndex ~= insertIndex then
        dragState.insertIndex = insertIndex
        self:RefreshQueueDragHighlights()
    else
        self:UpdateQueueInsertLine()
    end
    self:UpdateBagsDropHighlight()
    self:UpdateDragGhostPosition()
end

function MainWindow:IsCursorOverQueue()
    return self.queueScrollCard and self.queueScrollCard:IsMouseOver()
end

function MainWindow:IsCursorOverBags()
    return self.bagScrollCard and self.bagScrollCard:IsMouseOver()
end

function MainWindow:UpdateBagsDropHighlight()
    local card = self.bagScrollCard
    local overlay = self.bagDropHighlight
    if not card or not overlay then
        return
    end

    local active = self.queueDragState and self:IsCursorOverBags()
    if active then
        Theme.ApplySurface(card, Theme.colors.cardInset, Theme.colors.accent)
        overlay:Show()
    else
        Theme.ApplySurface(card, Theme.colors.cardInset, Theme.colors.borderMuted)
        overlay:Hide()
    end
end

function MainWindow:EnsureDragGhost()
    if self.dragGhost then
        return self.dragGhost
    end

    local ghost = Theme.CreateCard(UIParent, 220, 56)
    ghost:SetFrameStrata("TOOLTIP")
    ghost:EnableMouse(false)
    ghost:SetAlpha(0.88)
    ghost:Hide()

    ghost.IconWrap = Theme.CreateItemIcon(ghost, ITEM_ICON_SIZE)
    ghost.IconWrap:SetPoint("LEFT", ghost, "LEFT", 8, 0)
    ghost.IconWrap:EnableMouse(false)

    ghost.Title = Theme.CreateText(ghost, "", "body")
    ghost.Title:SetPoint("TOPLEFT", ghost.IconWrap, "TOPRIGHT", 8, 0)
    ghost.Title:SetPoint("RIGHT", ghost, "RIGHT", -10, 0)
    ghost.Title:SetJustifyH("LEFT")
    ghost.Title:SetWordWrap(false)
    ghost.Title:SetMaxLines(1)

    ghost.Meta = Theme.CreateText(ghost, "", "muted")
    ghost.Meta:SetPoint("TOPLEFT", ghost.Title, "BOTTOMLEFT", 0, -4)
    ghost.Meta:SetPoint("RIGHT", ghost, "RIGHT", -10, 0)
    ghost.Meta:SetWordWrap(false)
    ghost.Meta:SetMaxLines(1)

    self.dragGhost = ghost
    return ghost
end

function MainWindow:ShowDragGhost(row)
    if not row then
        return
    end

    local ghost = self:EnsureDragGhost()
    ghost.itemName = row.itemName
    ghost.quality = row.quality
    ghost.itemLink = row.itemLink
    ghost.itemLevelText = row.itemLevelText or ""
    ghost.slotText = row.slotText or ""
    ghost.bindText = row.bindText or ""
    local icon = row.icon
    if not icon and row.IconWrap and row.IconWrap.Texture then
        icon = row.IconWrap.Texture:GetTexture()
    end
    if icon then
        ghost.IconWrap:SetIcon(icon)
    end
    applyRowItemVisuals(ghost)
    ghost:Show()
    self:UpdateDragGhostPosition()
end

function MainWindow:UpdateDragGhostPosition()
    local ghost = self.dragGhost
    if not ghost or not ghost:IsShown() then
        return
    end

    local scale = ghost:GetEffectiveScale() or 1
    local cursorX, cursorY = GetCursorPosition()
    ghost:ClearAllPoints()
    ghost:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", (cursorX / scale) + 16, (cursorY / scale) - 8)
end

function MainWindow:HideDragGhost()
    if self.dragGhost then
        self.dragGhost:Hide()
    end
end

function MainWindow:BeginBagDrag(row)
    if not row or not row.bag or not row.slot then
        return
    end

    self.bagDragState = {
        bag = row.bag,
        slot = row.slot,
        guid = row.guid,
        insertIndex = Queue.Count() + 1,
    }
    self:ShowDragGhost(row)
    self:RefreshQueueDragHighlights()
end

function MainWindow:EndBagDrag()
    local dragState = self.bagDragState
    self.bagPressState = nil
    if not dragState then
        return
    end

    self.bagDragState = nil
    self:HideDragGhost()
    local overQueue = self:IsCursorOverQueue()
    self:RefreshQueueDragHighlights()
    if not overQueue or not dragState.bag or not dragState.slot then
        return
    end

    local ok, reason = Queue.AddFromBag(dragState.bag, dragState.slot)
    if not ok or reason == "pending" then
        return
    end

    local insertIndex = dragState.insertIndex or Queue.Count()
    local count = Queue.Count()
    if insertIndex >= 1 and insertIndex < count then
        Queue.Move(count, insertIndex)
    end
end

function MainWindow:EndQueueDrag()
    local dragState = self.queueDragState
    if not dragState then
        return
    end

    self.queueDragState = nil
    self:HideDragGhost()

    if self:IsCursorOverBags() then
        Queue.RemoveAt(dragState.sourceIndex)
        self:RefreshQueueDragHighlights()
        return
    end

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
    -- GameFontHighlight "X" sits low and left in 24px.
    row.Delete.labelOffsetX = 1
    row.Delete.labelOffsetY = 1
    row.Delete.Label:SetPoint("CENTER", 1, 1)

    row.CraftedIcon = createCraftedIcon(row, QUEUE_CRAFTED_ICON_SIZE, "UI-HUD-Minimap-CraftingOrder-Up-2x")
    row.CraftedIcon:SetPoint("CENTER", row, "CENTER", 0, 0)

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
        if MainWindow.bagDragState then
            MainWindow:EndBagDrag()
            return
        end
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
        if MainWindow.queueDragState then
            if not IsMouseButtonDown("LeftButton") then
                MainWindow:EndQueueDrag()
                return
            end
            MainWindow:UpdateQueueDragFromCursor()
            return
        end
        if MainWindow.bagDragState then
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
        rowFrame.icon = entry.icon
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

    for index, row in ipairs(self.expansionFilterRows or {}) do
        local expansionID = row.expansionID
        local count = expansionCounts[expansionID] or 0
        local stored = filters.expansions[expansionID]
        if stored == nil then
            stored = filters.expansions[tostring(expansionID)]
        end
        row:SetCheckedState(stored == true)
        row:SetCount(count)
        row:SetVisualEnabled(not currentOnly)
        row:ClearAllPoints()
        row:SetPoint("TOPLEFT", self.expansionFilterContent, "TOPLEFT", 0, -((index - 1) * 28))
        row:Show()
    end
    if self.expansionFilterContent then
        self.expansionFilterContent:SetHeight(math.max(1, #(self.expansionFilterRows or {}) * 28))
    end

    if self.minimapToggle then
        self.minimapToggle:SetCheckedState(not addon.db.global.minimap.hide)
    end
    if self.compartmentToggle then
        self.compartmentToggle:SetCheckedState(addon.db.global.minimap.showInCompartment == true)
    end
    if self.autoLootToggle then
        self.autoLootToggle:SetCheckedState(addon.db.global.autoLootReagents ~= false)
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
    self:RefreshSession()
    self:RefreshBlacklistList()
    self:RefreshEnchanterWarning()
    SecureDisenchant.UpdateVisual()
end

function MainWindow:RefreshEnchanterWarning()
    if not self.enchanterWarning or not self.sidebar then
        return
    end

    if Eligibility.PlayerKnowsDisenchant() then
        self.enchanterWarning:Hide()
        self.sidebar:ClearAllPoints()
        self.sidebar:SetPoint("TOPLEFT", self.frame, "TOPLEFT", 20, -74)
        self.sidebar:SetPoint("BOTTOMLEFT", self.frame, "BOTTOMLEFT", 20, 64)
        return
    end

    self.enchanterWarning:Show()
    self.sidebar:ClearAllPoints()
    self.sidebar:SetPoint("TOPLEFT", self.enchanterWarning, "BOTTOMLEFT", 0, -12)
    self.sidebar:SetPoint("BOTTOMLEFT", self.frame, "BOTTOMLEFT", 20, 64)
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

function MainWindow:Initialize()
    if self.frame then
        return
    end

    L = addon.L

    local frame = CreateFrame("Frame", "DisenchantumWindow", UIParent, "BackdropTemplate")
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
        if addon.Changelog then
            addon.Changelog.Hide()
        end
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
    subtitle:SetJustifyH("LEFT")
    subtitle:SetWordWrap(false)

    local accentLine = header:CreateTexture(nil, "BORDER")
    Theme.ApplyGradient(accentLine, "HORIZONTAL", Theme.colors.accent, Theme.colors.accentAlt)
    accentLine:SetSize(180, 2)
    accentLine:SetPoint("BOTTOMLEFT", header, "BOTTOMLEFT", 14, 0)

    local closeButton = CreateFrame("Button", nil, header)
    closeButton:SetSize(24, 24)
    closeButton:SetPoint("RIGHT", header, "RIGHT", -14, 0)
    closeButton.Text = Theme.CreateText(closeButton, "X", "heading")
    closeButton.Text:SetPoint("CENTER", closeButton, "CENTER", 0, -1)
    Theme.SetFontColor(closeButton.Text, Theme.colors.accentAlt)
    closeButton:SetScript("OnEnter", function(buttonFrame)
        Theme.SetFontColor(buttonFrame.Text, Theme.colors.text)
    end)
    closeButton:SetScript("OnLeave", function(buttonFrame)
        Theme.SetFontColor(buttonFrame.Text, Theme.colors.accentAlt)
    end)
    closeButton:SetScript("OnClick", function()
        frame:Hide()
    end)

    self.changelogButton = Theme.CreateButton(header, 118, 26, L["BUTTON_CHANGELOG"], "secondary")
    self.changelogButton:SetPoint("RIGHT", closeButton, "LEFT", -16, 0)
    self.changelogButton.Label:SetWordWrap(false)
    self.changelogButton:SetScript("OnClick", function()
        MainWindow:CloseBagMenus()
        addon.Changelog.Toggle()
    end)
    subtitle:SetPoint("RIGHT", self.changelogButton, "LEFT", -12, 0)

    table.insert(UISpecialFrames, "DisenchantumWindow")
    self.frame = frame

    self.enchanterWarning = Theme.CreateCard(frame, nil, 56)
    self.enchanterWarning:SetPoint("TOPLEFT", frame, "TOPLEFT", 20, -74)
    self.enchanterWarning:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -20, -74)
    Theme.SetCardTone(self.enchanterWarning, "warning")

    local warningIcon = self.enchanterWarning:CreateTexture(nil, "ARTWORK")
    warningIcon:SetSize(32, 32)
    warningIcon:SetPoint("LEFT", self.enchanterWarning, "LEFT", 12, 0)
    warningIcon:SetTexture("Interface\\DialogFrame\\UI-Dialog-Icon-AlertNew")

    local warningText = CreateFrame("Frame", nil, self.enchanterWarning)
    warningText:SetPoint("LEFT", warningIcon, "RIGHT", 10, 0)
    warningText:SetPoint("RIGHT", self.enchanterWarning, "RIGHT", -14, 0)

    local warningTitle = Theme.CreateText(warningText, L["WARN_NOT_ENCHANTER_TITLE"], "heading")
    warningTitle:SetPoint("TOPLEFT", warningText, "TOPLEFT", 0, 0)
    warningTitle:SetPoint("RIGHT", warningText, "RIGHT", 0, 0)
    Theme.SetFontColor(warningTitle, Theme.colors.warning)

    local warningBody = Theme.CreateText(warningText, L["WARN_NOT_ENCHANTER_BODY"], "muted")
    warningBody:SetPoint("TOPLEFT", warningTitle, "BOTTOMLEFT", 0, -3)
    warningBody:SetPoint("RIGHT", warningText, "RIGHT", 0, 0)
    warningBody:SetWordWrap(true)

    local function layoutWarningText()
        local titleHeight = warningTitle:GetStringHeight() or 0
        local bodyHeight = warningBody:GetStringHeight() or 0
        warningText:SetHeight(math.max(1, titleHeight + 3 + bodyHeight))
    end
    self.enchanterWarning:HookScript("OnShow", layoutWarningText)
    layoutWarningText()

    self.enchanterWarning:Hide()

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

    self.blacklistButton = Theme.CreateButton(self.sidebar, 148, 32, L["BUTTON_BLACKLIST"], "secondary")
    self.blacklistButton:SetPoint("BOTTOMLEFT", self.addAllButton, "TOPLEFT", 0, 8)
    self.blacklistButton:SetPoint("BOTTOMRIGHT", self.addAllButton, "TOPRIGHT", 0, 8)
    self.blacklistButton:SetHeight(32)
    self.blacklistButton.Label:SetWordWrap(false)
    self.blacklistCount = Theme.CreateText(self.blacklistButton, "", "label")
    self.blacklistCount:SetPoint("RIGHT", self.blacklistButton, "RIGHT", -12, 0)
    self.blacklistCount:SetJustifyH("RIGHT")
    Theme.SetFontColor(self.blacklistCount, Theme.colors.textMuted)
    self.blacklistButton:SetScript("OnClick", function()
        MainWindow:ToggleBagMenu("blacklist")
    end)

    self.bagScrollCard = Theme.CreatePanel(self.sidebar, Theme.colors.cardInset, Theme.colors.borderMuted)
    self.bagScrollCard:SetPoint("TOPLEFT", self.sidebar, "TOPLEFT", 16, -118)
    self.bagScrollCard:SetPoint("BOTTOMRIGHT", self.blacklistButton, "TOPRIGHT", 0, 10)
    self.bagScrollCard:EnableMouse(true)
    self.bagScrollCard:SetScript("OnMouseUp", function()
        if self.queueDragState then
            self:EndQueueDrag()
        end
    end)
    self.bagScrollCard:SetScript("OnUpdate", function()
        if self.queueDragState then
            if not IsMouseButtonDown("LeftButton") then
                self:EndQueueDrag()
                return
            end
            self:UpdateQueueDragFromCursor()
        end
    end)

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
    self.bagEmpty:SetWordWrap(true)

    self.bagDropHighlight = CreateFrame("Frame", nil, self.bagScrollCard, "BackdropTemplate")
    self.bagDropHighlight:SetAllPoints(self.bagScrollCard)
    self.bagDropHighlight:EnableMouse(false)
    self.bagDropHighlight:SetFrameLevel((self.bagScrollCard:GetFrameLevel() or 1) + 20)
    Theme.ApplySurface(self.bagDropHighlight, { 0.12, 0.28, 0.34, 0.28 }, Theme.colors.accent)
    self.bagDropHighlight:Hide()

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

    self.sessionCard = Theme.CreateCard(self.workspace, nil, 44)
    self.sessionCard:SetPoint("BOTTOMLEFT", deButton, "TOPLEFT", 0, 10)
    self.sessionCard:SetPoint("BOTTOMRIGHT", deButton, "TOPRIGHT", 0, 10)

    self.sessionCountHit = CreateFrame("Button", nil, self.sessionCard)
    self.sessionCountHit:SetPoint("LEFT", self.sessionCard, "LEFT", 12, 0)
    self.sessionCountHit:SetSize(72, 22)
    self.sessionCountHit:SetScript("OnEnter", function(hit)
        showSessionTooltip(hit)
    end)
    self.sessionCountHit:SetScript("OnLeave", hideTooltip)

    self.sessionCount = Theme.CreateText(self.sessionCountHit, "", "label")
    self.sessionCount:SetAllPoints(self.sessionCountHit)
    self.sessionCount:SetJustifyH("LEFT")
    self.sessionCount:SetWordWrap(false)
    Theme.SetFontColor(self.sessionCount, Theme.colors.textMuted)

    self.sessionReset = Theme.CreateButton(self.sessionCard, 96, 26, RESET, "secondary")
    self.sessionReset:SetPoint("RIGHT", self.sessionCard, "RIGHT", -10, 0)
    self.sessionReset:SetScript("OnClick", function()
        addon.Session.Reset()
    end)

    self.autoLootToggle = Theme.CreateCheckbox(self.sessionCard, 168, L["LABEL_AUTO_LOOT_REAGENTS"])
    self.autoLootToggle:SetPoint("RIGHT", self.sessionReset, "LEFT", -4, 0)
    self.autoLootToggle:SetScript("OnClick", function(checkbox)
        local currentlyEnabled = checkbox:GetCheckedState()
        addon.db.global.autoLootReagents = not currentlyEnabled
        checkbox:SetCheckedState(not currentlyEnabled)
    end)

    self.sessionEmpty = Theme.CreateText(self.sessionCard, L["EMPTY_SESSION"], "muted")
    self.sessionEmpty:SetPoint("LEFT", self.sessionCountHit, "RIGHT", 12, 0)
    self.sessionEmpty:SetPoint("RIGHT", self.autoLootToggle, "LEFT", -10, 0)
    self.sessionEmpty:SetJustifyH("LEFT")
    self.sessionEmpty:SetWordWrap(false)

    self.sessionChips = CreateFrame("Frame", nil, self.sessionCard)
    self.sessionChips:SetPoint("LEFT", self.sessionCountHit, "RIGHT", 12, 0)
    self.sessionChips:SetPoint("RIGHT", self.autoLootToggle, "LEFT", -10, 0)
    self.sessionChips:SetHeight(SESSION_CHIP_SIZE + 2)
    self.sessionChips:SetClipsChildren(true)
    self.sessionChipPool = {}
    self.sessionChips:HookScript("OnSizeChanged", function()
        if MainWindow._refreshingSession then
            return
        end
        MainWindow._refreshingSession = true
        MainWindow:RefreshSession()
        MainWindow._refreshingSession = false
    end)

    self.queueScrollCard = Theme.CreatePanel(self.workspace, Theme.colors.cardInset, Theme.colors.borderMuted)
    self.queueScrollCard:SetPoint("TOPLEFT", queueToolbar, "BOTTOMLEFT", 0, -12)
    self.queueScrollCard:SetPoint("BOTTOMRIGHT", self.sessionCard, "TOPRIGHT", 0, 12)
    self.queueScrollCard:EnableMouse(true)
    self.queueScrollCard:SetScript("OnMouseUp", function()
        if self.bagDragState then
            self:EndBagDrag()
            return
        end
        self:EndQueueDrag()
    end)
    self.queueScrollCard:SetScript("OnUpdate", function()
        if self.bagDragState then
            if not IsMouseButtonDown("LeftButton") then
                self:EndBagDrag()
                return
            end
            self:UpdateQueueDragFromCursor()
            return
        end
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
    Theme.ApplyGradient(self.queueInsertLine, "HORIZONTAL", Theme.colors.accent, Theme.colors.accentAlt)
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
            local enabled = 0
            if filters.uncommon then
                enabled = enabled + 1
            end
            if filters.rare then
                enabled = enabled + 1
            end
            if filters.epic then
                enabled = enabled + 1
            end
            if not nextValue and enabled <= 1 then
                -- Keep at least one quality selected.
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

    self.blacklistPanel = Theme.CreateCard(self.filtersOverlay, SIDEBAR_WIDTH - 32, 320)
    self.blacklistPanel:SetPoint("BOTTOMLEFT", self.blacklistButton, "TOPLEFT", 0, 8)
    self.blacklistPanel:EnableMouse(true)
    self.blacklistPanel:Hide()

    self.blacklistHeading = Theme.CreateText(self.blacklistPanel, L["BUTTON_BLACKLIST"], "heading")
    self.blacklistHeading:SetPoint("TOPLEFT", self.blacklistPanel, "TOPLEFT", 16, -14)

    self.blacklistScroll, self.blacklistListContent = Theme.CreateStyledScrollArea(self.blacklistPanel, SIDEBAR_WIDTH - 70)
    self.blacklistScroll:SetPoint("TOPLEFT", self.blacklistPanel, "TOPLEFT", 8, -42)
    self.blacklistScroll:SetPoint("BOTTOMRIGHT", self.blacklistPanel, "BOTTOMRIGHT", -22, 10)
    self.blacklistScroll:EnableMouse(true)
    self.blacklistScroll:HookScript("OnSizeChanged", function(_, width)
        if width and width > 0 then
            self.blacklistListContent:SetWidth(width)
        end
    end)
    self.blacklistRows = {}

    self.blacklistEmpty = Theme.CreateText(self.blacklistPanel, L["EMPTY_BLACKLIST"], "muted")
    self.blacklistEmpty:SetPoint("TOPLEFT", self.blacklistHeading, "BOTTOMLEFT", 0, -12)
    self.blacklistEmpty:SetPoint("RIGHT", self.blacklistPanel, "RIGHT", -16, 0)
    self.blacklistEmpty:SetJustifyV("TOP")

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

    addon.Changelog.headerButton = self.changelogButton
    addon.Changelog.EnsureFrame(frame)

    self:ApplyWindowScale()
end
