std = 'lua51'
codes = true
max_line_length = false

exclude_files = {
    '**/.libraries/',
    '**/.history/',
    '**/Libs/',
    '**/libs/',
}

globals = {
    'BINDING_HEADER_DISENCHANTER',
    'Disenchanter_OnAddonCompartmentClick',
    'SLASH_DISENCHANTER1',
    'SLASH_DISENCHANTER2',
    'SlashCmdList',
}

read_globals = {
    'C_AddOns',
    'C_Container',
    'C_Cursor',
    'C_Item',
    'C_Spell',
    'C_SpellBook',
    'C_Timer',
    'C_TooltipInfo',
    'C_TradeSkillUI',
    'ChatFontNormal',
    'ClearCursor',
    'Constants',
    'CreateFrame',
    'Enum',
    'EventRegistry',
    'EXPANSION_FILTER_TEXT',
    'FILTERS',
    'GameFontHighlightSmall',
    'GameFontNormalSmall',
    'GameTooltip',
    'GetClientDisplayExpansionLevel',
    'GetCursorPosition',
    'GetExpansionLevel',
    'GetMaximumExpansionLevel',
    'GetNumExpansions',
    'GetScreenHeight',
    'GetScreenWidth',
    'GetTime',
    'HUD_EDIT_MODE_BAGS_LABEL',
    'InCombatLockdown',
    'IsMouseButtonDown',
    'ITEM_QUALITY2_DESC',
    'ITEM_QUALITY3_DESC',
    'ITEM_QUALITY4_DESC',
    'ITEM_SOULBOUND',
    'ItemLocation',
    'LibStub',
    'LootSlot',
    'GetNumLootItems',
    'MINIMAP_LABEL',
    'NONE',
    'OTHER',
    'ProfessionsFrame',
    'ProfessionsUtil',
    'QUALITY',
    'RARITY',
    'STAT_AVERAGE_ITEM_LEVEL',
    'strcmputf8i',
    'strupper',
    'UIParent',
    'UISpecialFrames',
    'UnitCastingInfo',
    'wipe',
}

files['Locales/*.lua'] = {
    ignore = {
        '211',
    },
}
