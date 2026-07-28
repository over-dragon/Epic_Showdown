STRINGS.EPIC_ACTIONS_NAMED = {
    CHOP = "砍",
    MINE = "开采",
    DIG = "挖",
    HAMMER = "敲",
    SCYTHE = "收割",
    SKILL = "技能",

    USEITEM = "使用",
    MAP_TELEPORT = "转移",
}

STRINGS.UI.CRAFTING_FILTERS["EPICKEEPSAKE"] = "信物"

local keepsakes = require("epic_keepsakes")
for i, v in ipairs(keepsakes) do
    STRINGS.NAMES[string.upper(v.name).."_KEEPSAKE"] = v.zh_name1
    STRINGS.RECIPE_DESC[string.upper(v.name).."_KEEPSAKE"] = v.zh_rec1
    STRINGS.CHARACTERS.GENERIC.DESCRIBE[string.upper(v.name).."_KEEPSAKE"] = v.zh_desc1
end