local _, addon = ...

local Eligibility = {}
addon.Eligibility = Eligibility

local DISENCHANT_SPELL_ID = addon.DISENCHANT_SPELL_ID

local function getQualityKey(quality)
    if quality == Enum.ItemQuality.Uncommon then
        return "uncommon"
    end
    if quality == Enum.ItemQuality.Rare then
        return "rare"
    end
    if quality == Enum.ItemQuality.Epic then
        return "epic"
    end
    return nil
end

function Eligibility.PlayerKnowsDisenchant()
    if C_SpellBook and C_SpellBook.ContainsAnyDisenchantSpell and C_SpellBook.ContainsAnyDisenchantSpell() then
        return true
    end

    if C_SpellBook and C_SpellBook.IsSpellKnown and C_SpellBook.IsSpellKnown(DISENCHANT_SPELL_ID) then
        return true
    end

    return false
end

function Eligibility.GetSpellName()
    if C_Spell and C_Spell.GetSpellName then
        local name = C_Spell.GetSpellName(DISENCHANT_SPELL_ID)
        if name then
            return name
        end
    end
    if C_Spell and C_Spell.GetSpellInfo then
        local info = C_Spell.GetSpellInfo(DISENCHANT_SPELL_ID)
        if info then
            return info.name
        end
    end
    return nil
end

function Eligibility.GetSpellTexture()
    if C_Spell and C_Spell.GetSpellTexture then
        local iconID = C_Spell.GetSpellTexture(DISENCHANT_SPELL_ID)
        if iconID then
            return iconID
        end
    end
    return 132854
end

function Eligibility.GetCurrentExpansionLevel()
    if GetClientDisplayExpansionLevel then
        return GetClientDisplayExpansionLevel()
    end
    if GetMaximumExpansionLevel then
        return GetMaximumExpansionLevel()
    end
    if GetExpansionLevel then
        return GetExpansionLevel()
    end
    return 0
end

function Eligibility.GetExpansionLevelRange()
    -- GetItemInfo expansionID is 0-based (Classic). ToyBox lists
    -- 0 .. GetNumExpansions()-1. GetMinimumExpansionLevel is the account
    -- floor (often only the last expansions), not item origin.
    local maxLevel = 0
    if GetNumExpansions then
        maxLevel = math.max(0, GetNumExpansions() - 1)
    end
    maxLevel = math.max(maxLevel, Eligibility.GetCurrentExpansionLevel() or 0)
    if GetMaximumExpansionLevel then
        maxLevel = math.max(maxLevel, GetMaximumExpansionLevel())
    end
    return 0, maxLevel
end

function Eligibility.GetExpansionName(expansionID)
    if expansionID == nil then
        return nil
    end
    local name = _G["EXPANSION_NAME" .. expansionID]
    if type(name) == "string" and name ~= "" then
        return name
    end
    return nil
end

function Eligibility.MatchesQualityFilter(quality, filters)
    filters = filters or (addon.db and addon.db.global and addon.db.global.filters)
    if not filters then
        return false
    end

    local key = getQualityKey(quality)
    if not key then
        return false
    end

    return filters[key] == true
end

function Eligibility.MatchesExpansionFilter(expansionID, filters)
    filters = filters or (addon.db and addon.db.global and addon.db.global.filters)
    if not filters then
        return true
    end

    if expansionID == nil then
        -- Item info not loaded yet; keep the row rather than hiding it.
        return true
    end

    if filters.currentExpansionOnly then
        return expansionID == Eligibility.GetCurrentExpansionLevel()
    end

    local expansions = filters.expansions
    if type(expansions) ~= "table" then
        return true
    end

    local stored = expansions[expansionID]
    if stored == nil then
        stored = expansions[tostring(expansionID)]
    end
    return stored == true
end

local function tooltipBlocksDisenchant(bag, slot)
    -- Soulbound / vendor items that show ITEM_DISENCHANT_NOT_DISENCHANTABLE.
    if not C_TooltipInfo or not C_TooltipInfo.GetBagItem then
        return false
    end

    local blocked = _G.ITEM_DISENCHANT_NOT_DISENCHANTABLE
    if type(blocked) ~= "string" or blocked == "" then
        return false
    end

    local data = C_TooltipInfo.GetBagItem(bag, slot)
    local lines = data and data.lines
    if not lines then
        return false
    end

    for index = 1, #lines do
        local leftText = lines[index] and lines[index].leftText
        if type(leftText) == "string" and leftText:find(blocked, 1, true) then
            return true
        end
    end

    return false
end

local candidateCache = {}
local expansionByItemID = {}
local requestedItemIDs = {}

function Eligibility.InvalidateCache()
    wipe(candidateCache)
end

local function requestItemData(bag, slot, itemID)
    if itemID and requestedItemIDs[itemID] then
        return
    end
    if itemID then
        requestedItemIDs[itemID] = true
    end

    if bag and slot and C_Item.RequestLoadItemData then
        local location = ItemLocation:CreateFromBagAndSlot(bag, slot)
        if location and C_Item.DoesItemExist(location) then
            C_Item.RequestLoadItemData(location)
            return
        end
    end

    if itemID and C_Item.RequestLoadItemDataByID then
        C_Item.RequestLoadItemDataByID(itemID)
    end
end

local function getExpansionID(bag, slot, itemID)
    local cached = expansionByItemID[itemID]
    if cached ~= nil then
        return cached
    end

    local expansionID = select(15, C_Item.GetItemInfo(itemID))
    if expansionID ~= nil then
        expansionByItemID[itemID] = expansionID
        return expansionID
    end

    requestItemData(bag, slot, itemID)
    return nil
end

function Eligibility.IsDisenchantCandidate(bag, slot)
    local info = C_Container.GetContainerItemInfo(bag, slot)
    if not info or not info.itemID then
        return false, nil
    end

    local guid = Eligibility.GetItemGUID(bag, slot)
    local cached = guid and candidateCache[guid]
    if cached then
        if not cached.ok then
            return false, info
        end
        info.quality = cached.quality
        return true, info
    end

    if C_Item.IsItemKeystoneByID and C_Item.IsItemKeystoneByID(info.itemID) then
        if guid then
            candidateCache[guid] = { ok = false }
        end
        return false, info
    end

    local quality = info.quality
    if quality == nil and C_Item.GetItemQualityByID then
        quality = C_Item.GetItemQualityByID(info.itemID)
    end

    if not getQualityKey(quality) then
        if guid then
            candidateCache[guid] = { ok = false }
        end
        return false, info
    end

    local _, _, _, itemEquipLoc, _, classID = C_Item.GetItemInfoInstant(info.itemID)
    if classID ~= Enum.ItemClass.Armor and classID ~= Enum.ItemClass.Weapon then
        if guid then
            candidateCache[guid] = { ok = false }
        end
        return false, info
    end

    -- Tabards/shirts never DE and omit ITEM_DISENCHANT_NOT_DISENCHANTABLE.
    if itemEquipLoc == "INVTYPE_TABARD" or itemEquipLoc == "INVTYPE_BODY" then
        if guid then
            candidateCache[guid] = { ok = false }
        end
        return false, info
    end

    if tooltipBlocksDisenchant(bag, slot) then
        if guid then
            candidateCache[guid] = { ok = false }
        end
        return false, info
    end

    info.quality = quality
    if guid then
        candidateCache[guid] = { ok = true, quality = quality }
    end
    return true, info
end

function Eligibility.IsItemDisenchantable(bag, slot, options)
    options = options or {}
    local ok, info = Eligibility.IsDisenchantCandidate(bag, slot)
    if not ok then
        return false, info
    end

    local applyQuality = options.applyQuality ~= false
    local applyExpansion = options.applyExpansion ~= false
    local filters = options.filters

    if applyQuality and not Eligibility.MatchesQualityFilter(info.quality, filters) then
        return false, info
    end

    if applyExpansion then
        local expansionID = getExpansionID(bag, slot, info.itemID)
        if expansionID ~= nil and not Eligibility.MatchesExpansionFilter(expansionID, filters) then
            return false, info
        end
    end

    return true, info
end

function Eligibility.GetItemGUID(bag, slot)
    local location = ItemLocation:CreateFromBagAndSlot(bag, slot)
    if not location or not C_Item.DoesItemExist(location) then
        return nil
    end
    return C_Item.GetItemGUID(location)
end

function Eligibility.BuildEntry(bag, slot, info)
    info = info or C_Container.GetContainerItemInfo(bag, slot)
    if not info then
        return nil
    end

    local location = ItemLocation:CreateFromBagAndSlot(bag, slot)
    local itemLevel
    if location and C_Item.DoesItemExist(location) and C_Item.GetCurrentItemLevel then
        itemLevel = C_Item.GetCurrentItemLevel(location)
    end
    if not itemLevel and info.hyperlink and C_Item.GetDetailedItemLevelInfo then
        itemLevel = C_Item.GetDetailedItemLevelInfo(info.hyperlink)
    end

    local _, _, _, itemEquipLoc = C_Item.GetItemInfoInstant(info.itemID)
    local slotName
    if type(itemEquipLoc) == "string" and itemEquipLoc ~= "" then
        slotName = _G[itemEquipLoc]
    end
    if not slotName and location and C_Item.DoesItemExist(location) and C_Item.GetItemInventoryType then
        local inventoryType = C_Item.GetItemInventoryType(location)
        if inventoryType and C_Item.GetItemInventorySlotInfo then
            slotName = C_Item.GetItemInventorySlotInfo(inventoryType)
        end
    end

    local itemName, _, _, baseItemLevel, _, _, _, _, _, _, _, _, _, bindType = C_Item.GetItemInfo(info.itemID)
    local expansionID = getExpansionID(bag, slot, info.itemID)
    if not itemLevel then
        itemLevel = baseItemLevel
    end

    local bindLabel
    local L = addon.L
    local function bindText(key, fallback)
        if L and L[key] then
            return L[key]
        end
        return fallback
    end
    local itemBind = Enum.ItemBind
    if location and C_Item.DoesItemExist(location) and C_Item.IsBound and C_Item.IsBound(location) then
        bindLabel = ITEM_SOULBOUND or "Soulbound"
    elseif itemBind and bindType == itemBind.OnEquip then
        bindLabel = bindText("BIND_BOE", "BoE")
    elseif itemBind and bindType == itemBind.OnAcquire then
        bindLabel = bindText("BIND_BOP", "BoP")
    elseif itemBind and bindType == itemBind.OnUse then
        bindLabel = bindText("BIND_BOU", "BoU")
    elseif itemBind and bindType == itemBind.ToWoWAccount then
        bindLabel = bindText("BIND_ACCOUNT", "Account")
    elseif itemBind and (bindType == itemBind.ToBnetAccount or bindType == itemBind.ToBnetAccountUntilEquipped) then
        bindLabel = bindText("BIND_ACCOUNT", "Account")
    end

    return {
        guid = Eligibility.GetItemGUID(bag, slot),
        bag = bag,
        slot = slot,
        itemID = info.itemID,
        itemName = info.itemName or itemName,
        itemLink = info.hyperlink,
        icon = info.iconFileID,
        quality = info.quality,
        stackCount = info.stackCount or 1,
        itemLevel = itemLevel,
        slotName = slotName,
        bindLabel = bindLabel,
        expansionID = expansionID,
    }
end

function Eligibility.GetBagRange()
    local firstBag = Enum.BagIndex.Backpack
    local lastBag
    if Constants and Constants.InventoryConstants and Constants.InventoryConstants.NumBagSlots then
        lastBag = firstBag + Constants.InventoryConstants.NumBagSlots
    else
        lastBag = Enum.BagIndex.Bag_4 or 4
    end
    return firstBag, lastBag
end

function Eligibility.CollectSnapshot(options)
    options = options or {}
    -- skipGuids: omit from the bag list (queued + just consumed).
    -- countSkipGuids: still count toward filter totals until the item leaves the bag.
    local skipGuids = options.skipGuids or {}
    local countSkipGuids = options.countSkipGuids or {}
    local items = {}
    local qualityCounts = {
        uncommon = 0,
        rare = 0,
        epic = 0,
    }
    local expansionCounts = {}
    local currentExpansionCount = 0
    local currentExpansion = Eligibility.GetCurrentExpansionLevel()
    local firstBag, lastBag = Eligibility.GetBagRange()

    for bag = firstBag, lastBag do
        local numSlots = C_Container.GetContainerNumSlots(bag) or 0
        for slot = 1, numSlots do
            local ok, info = Eligibility.IsDisenchantCandidate(bag, slot)
            if ok then
                local entry = Eligibility.BuildEntry(bag, slot, info)
                if entry and entry.guid then
                    if not countSkipGuids[entry.guid] then
                        local qualityKey = getQualityKey(entry.quality)
                        if qualityKey and Eligibility.MatchesExpansionFilter(entry.expansionID) then
                            qualityCounts[qualityKey] = qualityCounts[qualityKey] + 1
                        end
                        if Eligibility.MatchesQualityFilter(entry.quality) then
                            if entry.expansionID ~= nil then
                                expansionCounts[entry.expansionID] = (expansionCounts[entry.expansionID] or 0) + 1
                            end
                            if entry.expansionID == currentExpansion then
                                currentExpansionCount = currentExpansionCount + 1
                            end
                        end
                    end

                    if not skipGuids[entry.guid]
                        and Eligibility.MatchesQualityFilter(entry.quality)
                        and Eligibility.MatchesExpansionFilter(entry.expansionID)
                    then
                        items[#items + 1] = entry
                    end
                end
            end
        end
    end

    return {
        items = items,
        qualityCounts = qualityCounts,
        expansionCounts = expansionCounts,
        currentExpansionCount = currentExpansionCount,
    }
end

local ORDER_KEYS = {
    name = true,
    ilvl = true,
    quality = true,
    slot = true,
}

local GROUP_KEYS = {
    none = true,
    name = true,
    ilvl = true,
    quality = true,
    slot = true,
}

local function compareNames(left, right)
    left = left or ""
    right = right or ""
    if strcmputf8i then
        return strcmputf8i(left, right) < 0
    end
    return left < right
end

local function firstLetter(name)
    -- string.sub(1, 1) splits UTF-8 names (frFR grouping).
    if not name or name == "" then
        return ""
    end
    local byte = name:byte(1)
    local length = 1
    if byte >= 240 then
        length = 4
    elseif byte >= 224 then
        length = 3
    elseif byte >= 192 then
        length = 2
    end
    local letter = name:sub(1, length)
    if strupper then
        letter = strupper(letter)
    else
        letter = letter:upper()
    end
    return letter
end

function Eligibility.NormalizeBagView(bagView)
    bagView = bagView or {}
    if not ORDER_KEYS[bagView.orderBy] then
        bagView.orderBy = "name"
    end
    if not GROUP_KEYS[bagView.groupBy] then
        bagView.groupBy = "none"
    end
    return bagView
end

local function compareByOrder(left, right, orderBy)
    if orderBy == "ilvl" then
        local leftLevel = left.itemLevel or 0
        local rightLevel = right.itemLevel or 0
        if leftLevel ~= rightLevel then
            return leftLevel > rightLevel
        end
    elseif orderBy == "quality" then
        local leftQuality = left.quality or 0
        local rightQuality = right.quality or 0
        if leftQuality ~= rightQuality then
            return leftQuality > rightQuality
        end
    elseif orderBy == "slot" then
        local leftSlot = left.slotName or ""
        local rightSlot = right.slotName or ""
        if leftSlot == "" and rightSlot ~= "" then
            return false
        end
        if leftSlot ~= "" and rightSlot == "" then
            return true
        end
        if leftSlot ~= rightSlot then
            return compareNames(leftSlot, rightSlot)
        end
    end
    return compareNames(left.itemName, right.itemName)
end

local function compareByGroup(left, right, groupBy)
    if groupBy == "ilvl" then
        local leftLevel = left.itemLevel or -1
        local rightLevel = right.itemLevel or -1
        if leftLevel ~= rightLevel then
            return leftLevel > rightLevel
        end
        return nil
    end

    if groupBy == "quality" then
        local leftQuality = left.quality or 0
        local rightQuality = right.quality or 0
        if leftQuality ~= rightQuality then
            return leftQuality > rightQuality
        end
        return nil
    end

    if groupBy == "slot" then
        local leftSlot = left.slotName or ""
        local rightSlot = right.slotName or ""
        if leftSlot == rightSlot then
            return nil
        end
        if leftSlot == "" then
            return false
        end
        if rightSlot == "" then
            return true
        end
        return compareNames(leftSlot, rightSlot)
    end

    local leftLetter = firstLetter(left.itemName)
    local rightLetter = firstLetter(right.itemName)
    if leftLetter == rightLetter then
        return nil
    end
    if leftLetter == "" then
        return false
    end
    if rightLetter == "" then
        return true
    end
    return compareNames(leftLetter, rightLetter)
end

function Eligibility.SortBagItems(items, orderBy, groupBy)
    if type(items) ~= "table" then
        return items
    end
    if not ORDER_KEYS[orderBy] then
        orderBy = "name"
    end
    if not GROUP_KEYS[groupBy] then
        groupBy = "none"
    end

    table.sort(items, function(left, right)
        if groupBy ~= "none" then
            local groupOrder = compareByGroup(left, right, groupBy)
            if groupOrder ~= nil then
                return groupOrder
            end
        end
        return compareByOrder(left, right, orderBy)
    end)

    return items
end

local function groupTitle(item, groupBy)
    local other = OTHER or "Other"

    if groupBy == "ilvl" then
        if item.itemLevel then
            local text = tostring(math.floor(item.itemLevel + 0.5))
            return text, text
        end
        return "", other
    end

    if groupBy == "quality" then
        local qualityKey = getQualityKey(item.quality)
        if qualityKey == "uncommon" then
            return qualityKey, ITEM_QUALITY2_DESC or "Uncommon"
        end
        if qualityKey == "rare" then
            return qualityKey, ITEM_QUALITY3_DESC or "Rare"
        end
        if qualityKey == "epic" then
            return qualityKey, ITEM_QUALITY4_DESC or "Epic"
        end
        return "other", other
    end

    if groupBy == "slot" then
        local slotName = item.slotName or ""
        if slotName ~= "" then
            return slotName, slotName
        end
        return "", other
    end

    local letter = firstLetter(item.itemName)
    if letter == "" then
        return "", other
    end
    return letter, letter
end

function Eligibility.BuildBagDisplayList(items, groupBy)
    local rows = {}
    if not GROUP_KEYS[groupBy] or groupBy == "none" then
        for index = 1, #items do
            rows[index] = items[index]
        end
        return rows
    end

    local lastKey
    for index = 1, #items do
        local item = items[index]
        local key, title = groupTitle(item, groupBy)
        if key ~= lastKey then
            rows[#rows + 1] = { isHeader = true, title = title }
            lastKey = key
        end
        rows[#rows + 1] = item
    end
    return rows
end
