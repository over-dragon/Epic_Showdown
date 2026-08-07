local TechTree = require("techtree")
table.insert(TechTree.AVAILABLE_TECH, "EPICORIGIN")

TECH.NONE = TechTree.Create()
for k, v in pairs(AllRecipes) do
    v.level = TechTree.Create(v.level)
end
for k, v in pairs(TUNING.PROTOTYPER_TREES) do
    TUNING.PROTOTYPER_TREES[k] = TechTree.Create(v)
end

TECH.EPICORIGIN_ONE = { EPICORIGIN = 1 }
TECH.EPICORIGIN_TWO = { EPICORIGIN = 2 }

TUNING.PROTOTYPER_TREES.EPICORIGIN_ONE = TechTree.Create({ EPICORIGIN = 1 })
TUNING.PROTOTYPER_TREES.EPICORIGIN_TWO = TechTree.Create({ EPICORIGIN = 2 })

AddPrototyperDef("epic_chaosseed", {
    icon_atlas = "images/epicorigin_filter.xml",
    icon_image = "epicorigin_filter.tex",
    is_crafting_station = true,
    -- action_str = "",
    filter_text = STRINGS.UI.CRAFTING_STATION_FILTERS.EPICORIGIN_TWO
})
---配方过滤器
AddRecipeFilter({
    name = "EPICKEEPSAKE",
    atlas = "images/epickeepsake_filter.xml",
    image = "epickeepsake_filter.tex",
    -- image_size = 256,
    -- custom_pos = false
},#CRAFTING_FILTER_DEFS+1)

local Keepsakes = require("epic_keepsakes")

---配方
for i, v in ipairs(Keepsakes) do
    AddRecipe2(v.name.."_keepsake",{Ingredient(v.mat, v.num*TUNING.EPIC_WORLD.MAT_NUM),
    Ingredient("featherpencil", 0),Ingredient("papyrus", 1),
    Ingredient(CHARACTER_INGREDIENT.HEALTH, 70), Ingredient(CHARACTER_INGREDIENT.SANITY, 70)},
    TECH.MAGIC_THREE,
    {atlas = "images/inventoryimages/"..v.name.."_keepsake.xml",
    image = v.name.."_keepsake.tex"},
    {"EPICKEEPSAKE"})

    AddRecipe2(v.name.."_origin",{Ingredient(v.mat, v.num*TUNING.EPIC_WORLD.MAT_NUM),
    Ingredient(v.name.."_keepsake", 1,"images/inventoryimages/"..v.name.."_keepsake.xml", v.name.."_keepsake.tex"),
    Ingredient(CHARACTER_INGREDIENT.HEALTH, 70), Ingredient(CHARACTER_INGREDIENT.SANITY, 70)},
    TECH.EPICORIGIN_TWO,
    {nounlock=true, station_tag = "epicorigin_station",
    atlas = "images/inventoryimages/"..v.name.."_origin.xml",
    image = v.name.."_origin.tex"})
end

-- AddRecipeToFilter("deerclops_keepsake","EPICKEEPSAKE")