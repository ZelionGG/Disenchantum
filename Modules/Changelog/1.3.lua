local _, addon = ...

addon.Changelog["1.3"] = {
    version_string = "1.3",
    release_date = "2026/10/18",
    header = {
        enUS = {
            title = "Version 1.3 - Keybind on the button and a gradient name",
            text = "Version 1.3 shows the [Disenchant] keybind on the button, and fades the addon name from turquoise to violet. This update also fixes the minimap tooltip, keeps a disabled [Disenchant] button from shifting its label, shows the crafted hammer on blacklist rows, refreshes the lists only after loot finishes, and updates the TOC for patch 12.1.5.",
        },
        frFR = {
            title = "Version 1.3 - Raccourci sur le bouton et nom en dégradé",
            text = "La version 1.3 affiche le raccourci [Désenchanter] sur le bouton, et fait passer le nom de l'addon du turquoise au violet. Cette mise à jour corrige aussi l'infobulle de la minicarte, empêche un bouton [Désenchanter] inactif de décaler son texte, affiche le marteau d'équipement fabriqué sur les lignes de la liste noire, ne rafraîchit les listes qu'une fois le butin terminé, et met à jour le TOC pour le patch 12.1.5.",
        },
    },
    important = {
        enUS = {},
        frFR = {},
    },
    new = {
        enUS = {
            "The [Disenchant] button now shows its keybind, and the binding has its own [Disenchantum] category in Key Bindings.",
            "The addon name now fades from turquoise to violet in the window title, on the minimap button, in the addon compartment, and on the professions tab.",
        },
        frFR = {
            "Le bouton [Désenchanter] affiche désormais son raccourci, et le raccourci a sa propre catégorie [Disenchantum] dans les raccourcis clavier.",
            "Le nom de l'addon passe désormais du turquoise au violet dans le titre de la fenêtre, sur le bouton de minicarte, dans le compartiment d'addons et sur l'onglet des métiers.",
        },
    },
    bugfix = {
        enUS = {
            "The minimap and compartment tooltip is visible again.",
            "A disabled [Disenchant] button no longer shifts its label on click.",
            "Blacklist rows now show the crafted hammer after the item name.",
        },
        frFR = {
            "L'infobulle de la minicarte et du compartiment est de nouveau visible.",
            "Un bouton [Désenchanter] inactif ne décale plus son texte au clic.",
            "Les lignes de la liste noire affichent désormais le marteau d'équipement fabriqué après le nom de l'objet.",
        },
    },
    improvement = {
        enUS = {
            "The lists wait until loot finishes before refreshing, so a disenchant pass stays smoother.",
            "TOC bump for patch [12.1.5].",
        },
        frFR = {
            "Les listes attendent la fin du butin avant de se rafraîchir, pour qu'une série de désenchantements reste plus fluide.",
            "Mise à jour du TOC pour le patch [12.1.5].",
        },
    },
}