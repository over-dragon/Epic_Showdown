STRINGS.EPIC_ACTIONS_NAMED = {
    CHOP = "Chop",
    MINE = "Mine",
    DIG = "Dig",
    HAMMER = "Hammer",
    SCYTHE = "Scythe",
    SKILL = "Skill",

    USEITEM = "Use",
    MAP_TELEPORT = "Teleport",
    CHARGE = "Charge",
}

STRINGS.UI.CRAFTING_FILTERS["EPICKEEPSAKE"] = "Keepsake"
STRINGS.UI.CRAFTING_STATION_FILTERS.EPICORIGIN_TWO = "Essence"
STRINGS.UI.CRAFTING.NEEDSEPICORIGIN_ONE = "Requires Chaos Pearl to craft"
STRINGS.UI.CRAFTING.NEEDSEPICORIGIN_TWO = "Requires Chaos Pearl to craft"

local keepsakes = require("epic_keepsakes")
for i, v in ipairs(keepsakes) do
    STRINGS.NAMES[string.upper(v.name).."_KEEPSAKE"] = v.en_name1
    STRINGS.RECIPE_DESC[string.upper(v.name).."_KEEPSAKE"] = v.en_rec1
    STRINGS.CHARACTERS.GENERIC.DESCRIBE[string.upper(v.name).."_KEEPSAKE"] = v.en_desc1

    STRINGS.NAMES[string.upper(v.name).."_ORIGIN"] = v.en_name2
    STRINGS.RECIPE_DESC[string.upper(v.name).."_ORIGIN"] = v.en_rec2
    STRINGS.CHARACTERS.GENERIC.DESCRIBE[string.upper(v.name).."_ORIGIN"] = v.en_desc2
end

STRINGS.NAMES["EPIC_CHAOSSEED"] = "Chaos Pearl"
STRINGS.CHARACTERS.GENERIC.DESCRIBE["EPIC_CHAOSSEED"] = "It has stolen the power of the Shadow and the Moon."