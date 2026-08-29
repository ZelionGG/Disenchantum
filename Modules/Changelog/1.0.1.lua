local _, addon = ...

addon.Changelog["1.0.1"] = {
    version_string = "1.0.1",
    release_date = "2026/08/29",
    header = {
        enUS = {
            title = "Version 1.0.1 - Enchanter warning and per-character blacklist",
            text = "Warn when Disenchant is unknown, and keep the ignore list on each character instead of the whole account.",
        },
        frFR = {
            title = "Version 1.0.1 - Avertissement d'enchanteur et liste noire par personnage",
            text = "Avertit si Désenchanter n'est pas connu, et garde la liste noire par personnage au lieu du compte entier.",
        },
    },
    important = {
        enUS = {},
        frFR = {},
    },
    new = {
        enUS = {
            "Yellow warning banner when the character does not know [Disenchant], with the button kept disabled.",
        },
        frFR = {
            "Bandeau d'avertissement jaune si le personnage ne connaît pas [Désenchanter], bouton resté inactif.",
        },
    },
    bugfix = {
        enUS = {
            "Ignore list is stored per character instead of being shared across the account.",
        },
        frFR = {
            "La liste d'ignore est enregistrée par personnage au lieu d'être partagée sur le compte.",
        },
    },
    improvment = {
        enUS = {},
        frFR = {},
    },
}
