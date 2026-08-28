local _, addon = ...

addon.DISENCHANT_SPELL_ID = 13262

addon.AceDBDefaults = {
    global = {
        minimap = {
            hide = false,
            showInCompartment = true,
        },
        filters = {
            uncommon = true,
            rare = true,
            epic = false,
            currentExpansionOnly = false,
            expansions = {},
        },
        bagView = {
            orderBy = "name",
            groupBy = "none",
        },
    },
}

local function ensureExpansionFilters(filters)
    filters.expansions = filters.expansions or {}
    local expansions = filters.expansions
    local minLevel, maxLevel = 0, 11
    if addon.Eligibility and addon.Eligibility.GetExpansionLevelRange then
        minLevel, maxLevel = addon.Eligibility.GetExpansionLevelRange()
    end

    for expansionID = minLevel, maxLevel do
        local stored = expansions[expansionID]
        if stored == nil then
            stored = expansions[tostring(expansionID)]
        end
        if stored == nil then
            expansions[expansionID] = true
        else
            expansions[expansionID] = stored == true
            expansions[tostring(expansionID)] = nil
        end
    end
end

function addon.NormalizeDatabase(database)
    if type(database) ~= "table" then
        return database
    end

    database.global = database.global or {}
    database.global.minimap = database.global.minimap or {}
    if database.global.minimap.hide == nil then
        database.global.minimap.hide = false
    end
    if database.global.minimap.showInCompartment == nil then
        database.global.minimap.showInCompartment = true
    end

    database.global.filters = database.global.filters or {}
    local filters = database.global.filters
    if filters.uncommon == nil then
        filters.uncommon = true
    end
    if filters.rare == nil then
        filters.rare = true
    end
    if filters.epic == nil then
        filters.epic = false
    end
    if filters.currentExpansionOnly == nil then
        filters.currentExpansionOnly = false
    end
    ensureExpansionFilters(filters)

    database.global.bagView = database.global.bagView or {}
    if addon.Eligibility and addon.Eligibility.NormalizeBagView then
        addon.Eligibility.NormalizeBagView(database.global.bagView)
    else
        local bagView = database.global.bagView
        if bagView.orderBy ~= "name" and bagView.orderBy ~= "ilvl" and bagView.orderBy ~= "quality" and bagView.orderBy ~= "slot" then
            bagView.orderBy = "name"
        end
        if bagView.groupBy ~= "none" and bagView.groupBy ~= "name" and bagView.groupBy ~= "ilvl" and bagView.groupBy ~= "quality" and bagView.groupBy ~= "slot" then
            bagView.groupBy = "none"
        end
    end

    return database
end

function addon.InitializeDatabase()
    local AceDB = LibStub:GetLibrary("AceDB-3.0")
    local database = AceDB:New("DisenchanterDB", addon.AceDBDefaults, true)
    addon.db = database
    addon.NormalizeDatabase(database)
    return database
end
