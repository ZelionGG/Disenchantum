local AddonName = ...

local AceLocale = LibStub:GetLibrary("AceLocale-3.0")
local L = AceLocale:NewLocale(AddonName, "frFR")
if not L then
    return
end

L["ADDON_NAME"] = "Disenchanter"
L["WINDOW_SUBTITLE"] = "Mettez des objets en file, puis cliquez Désenchanter."
L["SIDEBAR_BAGS_DESC"] = "Objets désenchantables selon vos filtres. Clic droit pour ignorer."
L["WORKSPACE_QUEUE_TITLE"] = "File"
L["WORKSPACE_QUEUE_DESC"] = "Cliquez pour ajouter. Glissez les lignes pour réordonner."
L["BUTTON_ADD_ALL"] = "Tout ajouter"
L["BUTTON_BLACKLIST"] = "Liste noire"
L["BUTTON_CLEAR_QUEUE"] = "Vider"
L["BUTTON_OPEN_DISENCHANTER"] = "Ouvrir Disenchanter"
L["BUTTON_ORDER_BY"] = "Trier"
L["BUTTON_GROUP_BY"] = "Grouper"
L["BIND_BOE"] = "BoE"
L["BIND_BOP"] = "BoP"
L["BIND_BOU"] = "BoU"
L["BIND_ACCOUNT"] = "Compte"
L["SORT_NAME"] = "Alphabétique"
L["SORT_SLOT"] = "Type d'armure"
L["FILTER_CURRENT_EXPANSION"] = "Objets de l'extension actuelle"
L["LABEL_COMPARTMENT"] = "Icône compartiment"
L["LABEL_AUTO_LOOT_REAGENTS"] = "Fouille auto des composants"
L["FMT_QUEUE_COUNT"] = "%d / %d"
L["FMT_SESSION_ITEMS"] = "%d désenchantés"
L["FMT_SESSION_CHIP_COUNT"] = "x%d"
L["FMT_SESSION_MORE"] = "+%d"
L["EMPTY_SESSION"] = "Aucun désenchantement cette session."
L["FMT_CAST_REMAINING"] = "%.1fs"
L["EMPTY_BAGS"] = "Aucun objet désenchantable dans les sacs."
L["EMPTY_BLACKLIST"] = "Aucun objet ignoré."
L["EMPTY_QUEUE"] = "File vide. Ajoutez des objets depuis vos sacs."
L["CONFIRM_BLACKLIST"] = "Ignorer cet objet ? Il disparaîtra des Sacs et de Tout ajouter."
L["CONFIRM_QUEUE_CRAFTED"] = "Mettre cet objet crafté en file ?"
L["CONFIRM_QUEUE_CRAFTED_N"] = "Mettre %d objets craftés en file ?"
L["MINIMAP_TOOLTIP"] = "Ouvrir Disenchanter"
L["BINDING_HEADER"] = "Disenchanter"
L["BINDING_CAST"] = "Désenchanter l'objet suivant"
