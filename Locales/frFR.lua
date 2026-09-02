local AddonName = ...

local AceLocale = LibStub:GetLibrary("AceLocale-3.0")
local L = AceLocale:NewLocale(AddonName, "frFR", false, false)
if not L then return end

-- Reference:
-- Some strings below are sourced from BlizzardInterfaceResources.
-- Source: https://github.com/Ketho/BlizzardInterfaceResources/blob/live/Resources/GlobalStrings/frFR.lua
-- @Translation Team: If you find a false positive (a string that should stay identical),
-- add `-- @no-translate` at the end of the line so the locale sync script ignores untranslated detection and stale marking when enUS changes.

L["ADDON_NAME"] = "Disenchantum" -- @no-translate
L["WINDOW_SUBTITLE"] = "Mettez des objets en file, puis cliquez Désenchanter."
L["SIDEBAR_BAGS_DESC"] = "Objets désenchantables selon vos filtres. Clic droit pour l'ajouter à la liste noire."
L["WORKSPACE_QUEUE_TITLE"] = "File"
L["WORKSPACE_QUEUE_DESC"] = "Cliquez pour ajouter. Glissez les lignes pour réordonner."
L["BUTTON_ADD_ALL"] = "Tout ajouter"
L["BUTTON_BLACKLIST"] = "Liste noire"
L["BUTTON_CLEAR_QUEUE"] = "Vider"
L["BUTTON_OPEN_DISENCHANTER"] = "Ouvrir Disenchantum"
L["BUTTON_ORDER_BY"] = "Trier"
L["BUTTON_GROUP_BY"] = "Grouper"
L["BUTTON_CHANGELOG"] = "Notes de mise à jour" -- @no-translate
L["CHANGELOG_TITLE"] = "Notes de mise à jour"
L["CHANGELOG_IMPORTANT"] = "Important" -- @no-translate
L["CHANGELOG_NEW"] = "Nouveautés"
L["CHANGELOG_BUGFIXES"] = "Corrections"
L["CHANGELOG_IMPROVEMENT"] = "Améliorations"
L["EMPTY_CHANGELOG"] = "Aucune note de version."
L["BIND_BOE"] = "LqE"
L["BIND_BOP"] = "LqR"
L["BIND_BOU"] = "LqU"
L["BIND_ACCOUNT"] = "Compte"
L["SORT_NAME"] = "Alphabétique"
L["SORT_SLOT"] = "Type d'armure"
L["FILTER_CURRENT_EXPANSION"] = "Objets de l'extension actuelle"
L["FILTER_CRAFTED"] = "Craftés"
L["FILTER_EXCLUDE_CRAFTED"] = "Exclure les objets craftés"
L["LABEL_COMPARTMENT"] = "Icône compartiment"
L["LABEL_AUTO_LOOT_REAGENTS"] = "Fouille auto des composants"
L["FMT_QUEUE_COUNT"] = "%d / %d" -- @no-translate
L["FMT_SESSION_ITEMS"] = "%d désenchantés"
L["FMT_SESSION_CHIP_COUNT"] = "x%d" -- @no-translate
L["FMT_SESSION_MORE"] = "+%d" -- @no-translate
L["TOOLTIP_CLICK_TO_USE"] = "Cliquer pour utiliser"
L["EMPTY_SESSION"] = "Aucun désenchantement cette session."
L["FMT_CAST_REMAINING"] = "%.1fs" -- @no-translate
L["EMPTY_BAGS"] = "Aucun objet désenchantable dans les sacs."
L["EMPTY_SEARCH"] = "Aucun objet ne correspond à votre recherche."
L["SEARCH_CRITERIA"] = "nom, ilvl, slot, lien, extension"
L["FMT_BAGS_HIDDEN_BY_FILTERS"] = "%d objets désenchantables masqués par les filtres. Ouvrez Filtres pour les afficher."
L["EMPTY_BLACKLIST"] = "Aucun objet ignoré."
L["EMPTY_QUEUE"] = "File vide. Ajoutez des objets depuis vos sacs."
L["CONFIRM_BLACKLIST"] = "Ignorer cet objet ? Il disparaîtra des Sacs et de Tout ajouter."
L["CONFIRM_QUEUE_CRAFTED"] = "Mettre cet objet crafté en file ?"
L["CONFIRM_QUEUE_CRAFTED_N"] = "Mettre %d objets craftés en file ?"
L["MINIMAP_TOOLTIP"] = "Ouvrir Disenchantum"
L["WARN_NOT_ENCHANTER_TITLE"] = "Ce personnage n'a pas la profession Enchantement."
L["WARN_NOT_ENCHANTER_BODY"] = "La profession Enchantement est requise pour désenchanter les objets. Le bouton Désenchanter restera inactif tant que la profession Enchantement n'est pas apprise."
L["BINDING_HEADER"] = "Disenchantum" -- @no-translate
L["BINDING_CAST"] = "Désenchanter l'objet suivant"
