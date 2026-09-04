local _, addon = ...

local Eligibility = addon.Eligibility

local Queue = {
    entries = {},
    listeners = {},
    suppress = 0,
    -- Hide a just-disenchanted GUID from Bags until it actually leaves the bag.
    consumedGuids = {},
}

addon.Queue = Queue

local function notify()
    if Queue.suppress > 0 then
        Queue.dirty = true
        return
    end

    Queue.dirty = false
    for index = 1, #Queue.listeners do
        Queue.listeners[index]()
    end
end

function Queue.Suspend()
    Queue.suppress = Queue.suppress + 1
end

function Queue.Resume()
    Queue.suppress = math.max(0, Queue.suppress - 1)
    if Queue.suppress == 0 and Queue.dirty then
        notify()
    end
end

function Queue.OnChanged(callback)
    Queue.listeners[#Queue.listeners + 1] = callback
end

function Queue.GetEntries()
    return Queue.entries
end

function Queue.Count()
    return #Queue.entries
end

function Queue.GetCurrent()
    return Queue.entries[1]
end

function Queue.IsQueued(guid)
    if not guid then
        return false
    end

    for index = 1, #Queue.entries do
        if Queue.entries[index].guid == guid then
            return true, index
        end
    end

    return false
end

local skipGuidsScratch = {}

function Queue.FillSkipGuids(dest)
    dest = dest or skipGuidsScratch
    wipe(dest)
    for index = 1, #Queue.entries do
        local guid = Queue.entries[index].guid
        if guid then
            dest[guid] = true
        end
    end
    for guid in pairs(Queue.consumedGuids) do
        dest[guid] = true
    end
    return dest
end

function Queue.GetSkipGuids()
    return Queue.FillSkipGuids({})
end

function Queue.MarkConsumed(guid)
    if guid then
        Queue.consumedGuids[guid] = true
    end
end

function Queue.SweepConsumed(locations)
    -- Drop the hide once the item is gone (loot taken / bag update).
    locations = locations or Eligibility.IndexBagLocations()
    for guid in pairs(Queue.consumedGuids) do
        if not locations[guid] then
            Queue.consumedGuids[guid] = nil
        end
    end
end

function Queue.FindLocationByGUID(guid)
    if not guid then
        return nil
    end

    local found = Eligibility.IndexBagLocations()[guid]
    if not found then
        return nil
    end
    return found.bag, found.slot
end

function Queue.RefreshLocations()
    if #Queue.entries == 0 and not next(Queue.consumedGuids) then
        return false
    end

    local locations = Eligibility.IndexBagLocations()
    local kept = {}
    for index = 1, #Queue.entries do
        local entry = Queue.entries[index]
        local found = entry.guid and locations[entry.guid]
        if found then
            if entry.bag == found.bag and entry.slot == found.slot then
                kept[#kept + 1] = entry
            else
                local rebuilt = Eligibility.BuildEntry(found.bag, found.slot)
                if rebuilt then
                    rebuilt.guid = entry.guid
                    kept[#kept + 1] = rebuilt
                else
                    entry.bag = found.bag
                    entry.slot = found.slot
                    kept[#kept + 1] = entry
                end
            end
        end
    end

    local changed = #kept ~= #Queue.entries
    Queue.entries = kept
    Queue.SweepConsumed(locations)
    return changed
end

function Queue.AddEntry(entry)
    if not entry or not entry.guid then
        return false, "invalid"
    end

    if Eligibility.IsBlacklisted(entry.itemID) then
        return false, "blacklisted"
    end

    if Queue.IsQueued(entry.guid) then
        return false, "queued"
    end

    Queue.entries[#Queue.entries + 1] = entry
    notify()
    return true
end

-- Merchant-style item row (icon + quality name). Hover uses SetHyperlink.
-- Add-all stays on GENERIC_CONFIRMATION: there is no single item to preview.
local ITEM_CONFIRM_WHICH = "DISENCHANTUM_CONFIRM_ITEM"

StaticPopupDialogs[ITEM_CONFIRM_WHICH] = {
    text = "",
    button1 = YES,
    button2 = CANCEL,
    OnShow = function(dialog, data)
        dialog:SetText(data.text)
    end,
    OnAccept = function(_, data)
        if data.callback then
            data.callback()
        end
    end,
    OnCancel = function(_, data)
        if data.cancelCallback then
            data.cancelCallback()
        end
    end,
    hasItemFrame = 1,
    showAlert = 1,
    hideOnEscape = 1,
    timeout = 0,
    multiple = 1,
    whileDead = 1,
    wide = 1,
}

local itemConfirmData = {}

local craftBatchConfirmData = {
    referenceKey = "DisenchantumCraftedQueue",
    showAlert = true,
}

local function itemQualityColor(quality)
    if quality and C_Item.GetItemQualityColor then
        local r, g, b = C_Item.GetItemQualityColor(quality)
        return { r, g, b, 1 }
    end
    return { 1, 1, 1, 1 }
end

local function showItemConfirm(text, entry, onAccept)
    itemConfirmData.text = text
    itemConfirmData.callback = onAccept
    itemConfirmData.link = entry.itemLink
    itemConfirmData.name = entry.itemName
    itemConfirmData.texture = entry.icon
    itemConfirmData.color = itemQualityColor(entry.quality)
    itemConfirmData.count = nil
    itemConfirmData.useLinkForItemInfo = entry.itemLink ~= nil
    StaticPopup_Show(ITEM_CONFIRM_WHICH, nil, nil, itemConfirmData)
end

local function confirmCraftedBatch(count, onAccept)
    local L = addon.L
    craftBatchConfirmData.text = (L and L["CONFIRM_QUEUE_CRAFTED_N"]) or "Queue %d crafted items?"
    craftBatchConfirmData.text_arg1 = count
    craftBatchConfirmData.callback = onAccept
    craftBatchConfirmData.acceptText = YES
    craftBatchConfirmData.cancelText = CANCEL
    StaticPopup_ShowCustomGenericConfirmation(craftBatchConfirmData)
end

function Queue.AddFromBag(bag, slot)
    local ok, info = Eligibility.IsItemDisenchantable(bag, slot)
    if not ok then
        return false, "ineligible"
    end

    local entry = Eligibility.BuildEntry(bag, slot, info)
    if not entry then
        return false, "invalid"
    end

    if Eligibility.IsBlacklisted(entry.itemID) then
        return false, "blacklisted"
    end

    if Eligibility.IsCraftedEquipment(entry.itemLink or entry.itemID) then
        local L = addon.L
        showItemConfirm((L and L["CONFIRM_QUEUE_CRAFTED"]) or "Queue this crafted item?", entry, function()
            Queue.AddEntry(entry)
        end)
        return true, "pending"
    end

    return Queue.AddEntry(entry)
end

function Queue.AddAllMatching(options)
    options = options or {}
    local added = 0
    local snapshotItems = Eligibility.CollectSnapshot({
        skipGuids = Queue.FillSkipGuids(),
    }).items
    local items = {}
    for index = 1, #snapshotItems do
        items[index] = snapshotItems[index]
    end
    items = Eligibility.FilterItemsBySearch(items, options.search)
    local orderBy = "name"
    local groupBy = "none"
    if addon.db and addon.db.global and addon.db.global.bagView then
        orderBy = addon.db.global.bagView.orderBy
        groupBy = addon.db.global.bagView.groupBy
    end
    Eligibility.SortBagItems(items, orderBy, groupBy)

    local crafted = {}
    Queue.Suspend()
    for index = 1, #items do
        local item = items[index]
        if Eligibility.IsCraftedEquipment(item.itemLink or item.itemID) then
            crafted[#crafted + 1] = item
        elseif Queue.AddEntry(item) then
            added = added + 1
        end
    end
    Queue.Resume()

    if #crafted > 0 then
        confirmCraftedBatch(#crafted, function()
            Queue.Suspend()
            for index = 1, #crafted do
                Queue.AddEntry(crafted[index])
            end
            Queue.Resume()
        end)
    end

    return added
end

function Queue.RemoveAt(index)
    if not index or not Queue.entries[index] then
        return false
    end

    table.remove(Queue.entries, index)
    notify()
    return true
end

function Queue.RemoveByGUID(guid)
    local _, index = Queue.IsQueued(guid)
    if not index then
        return false
    end
    return Queue.RemoveAt(index)
end

function Queue.RequestBlacklist(entry)
    if not entry or not entry.itemID then
        return false
    end
    if Eligibility.IsBlacklisted(entry.itemID) then
        return false
    end

    local L = addon.L
    showItemConfirm((L and L["CONFIRM_BLACKLIST"]) or "Ignore this item? It will be hidden from Bags and Add all.", entry, function()
        Queue.BlacklistAdd(entry)
    end)
    return true
end

function Queue.BlacklistAdd(entry)
    if not entry or not entry.itemID or not addon.db or not addon.db.char then
        return false
    end

    addon.db.char.blacklist = addon.db.char.blacklist or {}
    addon.db.char.blacklist[entry.itemID] = {
        name = entry.itemName,
        icon = entry.icon,
        quality = entry.quality,
        itemLink = entry.itemLink,
    }

    Queue.Suspend()
    for index = #Queue.entries, 1, -1 do
        if Queue.entries[index].itemID == entry.itemID then
            table.remove(Queue.entries, index)
            Queue.dirty = true
        end
    end
    Queue.dirty = true
    Queue.Resume()
    return true
end

function Queue.BlacklistRemove(itemID)
    if not itemID or not addon.db or not addon.db.char then
        return false
    end
    local list = addon.db.char.blacklist
    if type(list) ~= "table" then
        return false
    end
    if list[itemID] == nil and list[tostring(itemID)] == nil then
        return false
    end
    list[itemID] = nil
    list[tostring(itemID)] = nil
    notify()
    return true
end

function Queue.GetBlacklistEntries()
    local entries = {}
    local list = addon.db and addon.db.char and addon.db.char.blacklist
    if type(list) ~= "table" then
        return entries
    end

    for key, data in pairs(list) do
        local itemID = tonumber(key)
        if itemID and type(data) == "table" then
            entries[#entries + 1] = {
                itemID = itemID,
                itemName = data.name,
                icon = data.icon,
                quality = data.quality,
                itemLink = data.itemLink,
            }
        end
    end

    table.sort(entries, function(left, right)
        local leftName = left.itemName or ""
        local rightName = right.itemName or ""
        if strcmputf8i then
            return strcmputf8i(leftName, rightName) < 0
        end
        return leftName < rightName
    end)
    return entries
end

function Queue.Clear()
    if #Queue.entries == 0 then
        return
    end
    wipe(Queue.entries)
    notify()
end

function Queue.Move(fromIndex, toIndex)
    if fromIndex == toIndex then
        return false
    end

    local count = #Queue.entries
    if fromIndex < 1 or fromIndex > count or toIndex < 1 or toIndex > count then
        return false
    end

    local entry = table.remove(Queue.entries, fromIndex)
    table.insert(Queue.entries, toIndex, entry)
    notify()
    return true
end
