local _, addon = ...

addon.Changelog["1.2"] = {
    version_string = "1.2",
    release_date = "2026/08/31",
    header = {
        enUS = {
            title = "Version 1.2 - Recap knowledge, bag search, and crafted filter",
            text = "Use profession knowledge from the session recap, search in the list by name or expansion, and crafted gear can now be excluded from the list.",
        },
        frFR = {
            title = "Version 1.2 - Connaissance, recherche et équipements fabriqués",
            text = "Utilisez les objets de connaissance depuis le résumé, recherchez dans la liste, et les équipements fabriqués peuvent désormais être exclus de la liste.",
        },
    },
    important = {
        enUS = {},
        frFR = {},
    },
    new = {
        enUS = {
            "Click a session recap chip that has a Use effect (such as profession knowledge) to use without searching in your bags.",
            "Click the session recap +N chip to open the rest of the session recap.",
            "Search Bags by name, item level, slot, bind, or expansion.",
            "Exclude crafted gear from the list with a [Crafted] filter.",
        },
        frFR = {
            "Cliquez un jeton du résumé de session qui a un effet Utiliser (comme la connaissance de métier) pour l'utiliser sans chercher dans vos sacs.",
            "Cliquez le jeton +N du résumé de session pour afficher le reste des composants obtenus.",
            "Recherchez dans Sacs par nom, ilvl, emplacement, lien ou extension.",
            "Les équipements fabriqués peuvent désormais être exclus de la liste avec le filtre [Équipements fabriqués].",
        },
    },
    bugfix = {
        enUS = {},
        frFR = {},
    },
    improvement = {
        enUS = {
            "The [Disenchant] button keeps icon and name centered so a click no longer jumps the label.",
        },
        frFR = {
            "Le bouton [Désenchanter] garde l'icône et le nom au centre pour qu'un clic ne fasse plus sauter le texte.",
        },
    },
}
