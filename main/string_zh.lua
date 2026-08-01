STRINGS.EPIC_ACTIONS_NAMED = {
    CHOP = "砍",
    MINE = "开采",
    DIG = "挖",
    HAMMER = "敲",
    SCYTHE = "收割",
    SKILL = "技能",

    USEITEM = "使用",
    MAP_TELEPORT = "转移",
    CHARGE = "充能",
}

STRINGS.UI.CRAFTING_FILTERS["EPICKEEPSAKE"] = "信物"
STRINGS.UI.CRAFTING_STATION_FILTERS.EPICORIGIN_TWO = "本源"
STRINGS.UI.CRAFTING.NEEDSEPICORIGIN_ONE = "需要混沌魔珠才能制作"
STRINGS.UI.CRAFTING.NEEDSEPICORIGIN_TWO = "需要混沌魔珠才能制作"

local keepsakes = require("epic_keepsakes")
for i, v in ipairs(keepsakes) do
    STRINGS.NAMES[string.upper(v.name).."_KEEPSAKE"] = v.zh_name1
    STRINGS.RECIPE_DESC[string.upper(v.name).."_KEEPSAKE"] = v.zh_rec1
    STRINGS.CHARACTERS.GENERIC.DESCRIBE[string.upper(v.name).."_KEEPSAKE"] = v.zh_desc1

    STRINGS.NAMES[string.upper(v.name).."_ORIGIN"] = v.zh_name2
    STRINGS.RECIPE_DESC[string.upper(v.name).."_ORIGIN"] = v.zh_rec2
    STRINGS.CHARACTERS.GENERIC.DESCRIBE[string.upper(v.name).."_ORIGIN"] = v.zh_desc2
end

STRINGS.NAMES["EPIC_CHAOSSEED"] = "混沌魔珠"
STRINGS.RECIPE_DESC["EPIC_CHAOSSEED"] = ""
STRINGS.CHARACTERS.GENERIC.DESCRIBE["EPIC_CHAOSSEED"] = ""