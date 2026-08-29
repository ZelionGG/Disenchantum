local _, addon = ...

addon.Changelog["1.1"] = {
    version_string = "1.1",
    release_date = "2026/08/29",
    header = {
        enUS = {
            title = "Version 1.1 - Enchanter warning, per-character ignore, and bag queue drag",
            text = "Warn when Disenchant is unknown, keep the ignore list per character, and add or remove queue items with plus, double-click, or drag.",
        },
        frFR = {
            title = "Version 1.1 - Avertissement d'enchanteur, ignore par personnage et glisser-déposer",
            text = "Avertit si Désenchanter n'est pas connu, garde la liste noire par personnage, et ajoute ou retire les objets par plus, double-clic ou glisser-déposer.",
        },
    },
    important = {
        enUS = {},
        frFR = {},
    },
    new = {
        enUS = {
            "Yellow warning banner when the character does not know [Disenchant], with the button kept disabled.",
            "Add bag items with [+], [double-click], or [drag] onto the Queue (insert line). A single click no longer queues. Drag a queue tile back onto Bags to remove it from the Queue.",
        },
        frFR = {
            "Bandeau d'avertissement jaune si le personnage ne connaît pas [Désenchanter], bouton resté inactif.",
            "Ajoutez les objets de sac avec [+], un [double-clic] ou un [glisser-déposer] vers la File (ligne d'insertion). Un simple clic n'ajoutera plus dans la file. Glissez une tuile de la File vers Sacs pour la retirer de la file.",
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
        enUS = {
            "A ghost tile follows the cursor while dragging.",
        },
        frFR = {
            "Une tuile fantôme suit le curseur pendant le glisser-déposer.",
        },
    },
}
