local AddonName = ...

local AceLocale = LibStub:GetLibrary("AceLocale-3.0")
local L = AceLocale:NewLocale(AddonName, "enUS", true, false)

-- Reference:
-- Some strings below are sourced from BlizzardInterfaceResources.
-- Source: https://github.com/Ketho/BlizzardInterfaceResources/blob/live/Resources/GlobalStrings/enUS.lua
-- @Translation Team: If you find a false positive (a string that should stay identical),
-- add `-- @no-translate` at the end of the line so the locale sync script ignores untranslated detection and stale marking when enUS changes.

-- ## Translations Start ## --

L["ADDON_NAME"] = "Disenchantum"
L["WINDOW_SUBTITLE"] = "Queue items from your bags, then click Disenchant."
L["SIDEBAR_BAGS_DESC"] = "Disenchantable items matching your filters. Right-click to blacklist."
L["WORKSPACE_QUEUE_TITLE"] = "Queue"
L["WORKSPACE_QUEUE_DESC"] = "Click an item to add it. Drag queued rows to reorder."
L["BUTTON_ADD_ALL"] = "Add all"
L["BUTTON_BLACKLIST"] = "Blacklist"
L["BUTTON_CLEAR_QUEUE"] = "Clear"
L["BUTTON_OPEN_DISENCHANTER"] = "Open Disenchantum"
L["BUTTON_ORDER_BY"] = "Order by"
L["BUTTON_GROUP_BY"] = "Group by"
L["BUTTON_CHANGELOG"] = "Changelog"
L["CHANGELOG_TITLE"] = "Changelog"
L["CHANGELOG_IMPORTANT"] = "Important"
L["CHANGELOG_NEW"] = "New"
L["CHANGELOG_BUGFIXES"] = "Bugfixes"
L["CHANGELOG_IMPROVEMENT"] = "Improvement"
L["EMPTY_CHANGELOG"] = "No changelog entries."
L["BIND_BOE"] = "BoE"
L["BIND_BOP"] = "BoP"
L["BIND_BOU"] = "BoU"
L["BIND_ACCOUNT"] = "Account"
L["SORT_NAME"] = "Alphabetical"
L["SORT_SLOT"] = "Armor type"
L["FILTER_CURRENT_EXPANSION"] = "Current expansion items"
L["FILTER_CURRENT_EXPANSION"] = "Current Expansion Items"
L["LABEL_COMPARTMENT"] = "Compartment icon"
L["LABEL_AUTO_LOOT_REAGENTS"] = "Auto loot reagents"
L["FMT_QUEUE_COUNT"] = "%d / %d"
L["FMT_SESSION_ITEMS"] = "%d disenchanted"
L["FMT_SESSION_CHIP_COUNT"] = "x%d"
L["FMT_SESSION_MORE"] = "+%d"
L["TOOLTIP_CLICK_TO_USE"] = "Click to use"
L["EMPTY_SESSION"] = "No disenchants this session."
L["FMT_CAST_REMAINING"] = "%.1fs"
L["EMPTY_BAGS"] = "No disenchantable items in bags."
L["EMPTY_SEARCH"] = "No items match your search."
L["SEARCH_CRITERIA"] = "name, ilvl, slot, bind, expansion"
L["FMT_BAGS_HIDDEN_BY_FILTERS"] = "%d disenchantable items hidden by filters. Open Filters to show them."
L["EMPTY_BLACKLIST"] = "No ignored items."
L["EMPTY_QUEUE"] = "Queue is empty. Add items from your bags."
L["CONFIRM_BLACKLIST"] = "Ignore this item? It will be hidden from Bags and Add all."
L["CONFIRM_QUEUE_CRAFTED"] = "Queue this crafted item?"
L["CONFIRM_QUEUE_CRAFTED_N"] = "Queue %d crafted items?"
L["MINIMAP_TOOLTIP"] = "Open Disenchantum"
L["WARN_NOT_ENCHANTER_TITLE"] = "This character does not have the Enchanting profession."
L["WARN_NOT_ENCHANTER_BODY"] = "Enchanting profession is required to disenchant items. The Disenchant button will stay disabled until Enchanting is learned."
L["BINDING_HEADER"] = "Disenchantum"
L["BINDING_CAST"] = "Disenchant next queued item"
