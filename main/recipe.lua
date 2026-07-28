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
    AddRecipe2(v.name.."_keepsake",{Ingredient(v.mat, 0),
    Ingredient("featherpencil", 0),Ingredient("papyrus", 1),
    Ingredient(CHARACTER_INGREDIENT.HEALTH, 70), Ingredient(CHARACTER_INGREDIENT.SANITY, 70)},
    TECH.MAGIC_THREE,
    {atlas = "images/inventoryimages/"..v.name.."_keepsake.xml",
    image = v.name.."_keepsake.tex"},
    {"EPICKEEPSAKE"})
end

-- AddRecipeToFilter("deerclops_keepsake","EPICKEEPSAKE")