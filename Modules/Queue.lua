local _, addon = ...

local Eligibility = addon.Eligibility

local Queue = {
    entries = {},
    listeners = {},
    suppress = 0,
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

function Queue.GetQueuedGuids()
    local guids = {}
    for index = 1, #Queue.entries do
        local guid = Queue.entries[index].guid
        if guid then
            guids[guid] = true
        end
    end
    return guids
end

function Queue.GetConsumedGuids()
    return Queue.consumedGuids
end

function Queue.GetSkipGuids()
    local skip = Queue.GetQueuedGuids()
    for guid in pairs(Queue.consumedGuids) do
        skip[guid] = true
    end
    return skip
end

function Queue.MarkConsumed(guid)
    if guid then
        Queue.consumedGuids[guid] = true
    end
end

function Queue.SweepConsumed()
    for guid in pairs(Queue.consumedGuids) do
        if not Queue.FindLocationByGUID(guid) then
            Queue.consumedGuids[guid] = nil
        end
    end
end

function Queue.FindLocationByGUID(guid)
    if not guid then
        return nil
    end

    local firstBag, lastBag = Eligibility.GetBagRange()
    for bag = firstBag, lastBag do
        local numSlots = C_Container.GetContainerNumSlots(bag) or 0
        for slot = 1, numSlots do
            if Eligibility.GetItemGUID(bag, slot) == guid then
                return bag, slot
            end
        end
    end

    return nil
end

function Queue.RefreshLocations()
    local kept = {}
    for index = 1, #Queue.entries do
        local entry = Queue.entries[index]
        local bag, slot = Queue.FindLocationByGUID(entry.guid)
        if bag then
            local rebuilt = Eligibility.BuildEntry(bag, slot)
            if rebuilt then
                rebuilt.guid = entry.guid
                kept[#kept + 1] = rebuilt
            else
                entry.bag = bag
                entry.slot = slot
                kept[#kept + 1] = entry
            end
        end
    end

    local changed = #kept ~= #Queue.entries
    Queue.entries = kept
    Queue.SweepConsumed()
    return changed
end

function Queue.AddEntry(entry)
    if not entry or not entry.guid then
        return false, "invalid"
    end

    if Queue.IsQueued(entry.guid) then
        return false, "queued"
    end

    Queue.entries[#Queue.entries + 1] = entry
    notify()
    return true
end

function Queue.AddFromBag(bag, slot)
    local ok, info = Eligibility.IsItemDisenchantable(bag, slot)
    if not ok then
        return false, "ineligible"
    end

    local entry = Eligibility.BuildEntry(bag, slot, info)
    return Queue.AddEntry(entry)
end

function Queue.AddAllMatching()
    local added = 0
    local items = Eligibility.ScanBags({
        skipGuids = Queue.GetSkipGuids(),
    })
    local orderBy = "name"
    local groupBy = "none"
    if addon.db and addon.db.global and addon.db.global.bagView then
        orderBy = addon.db.global.bagView.orderBy
        groupBy = addon.db.global.bagView.groupBy
    end
    Eligibility.SortBagItems(items, orderBy, groupBy)
    Queue.Suspend()
    for index = 1, #items do
        if Queue.AddEntry(items[index]) then
            added = added + 1
        end
    end
    Queue.Resume()
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

function Queue.RemoveCurrent()
    return Queue.RemoveAt(1)
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
