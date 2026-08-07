local modid = 'epic_showdown'
TUNING.EPIC_WORLD = {
    STRUCTURE_PROTECTION = GetModConfigData(modid..'_structure_protection') or 1,
    BGM = GetModConfigData(modid..'_BGM') or 1,
    DAMAGE = GetModConfigData(modid..'_damage') or 1,
    HEALTH = GetModConfigData(modid..'_health') or 0.5,

    ATTACK_LOCOMTE_INTERRUPT = GetModConfigData(modid..'_attack_move') or 1,

    CASTSELECT_MUSIC = GetModConfigData(modid..'_caselect_music') or 1,

    MAT_NUM = GetModConfigData(modid..'_mat') or 1
}

local BOSS = {
    "antlion",
    "bearger",
    "beequeen",
    "daywalker",
    "daywalker2",
    "deerclops",
    "dragonfly",
    "malbatross",
    "moose",
    "mutatedbearger",
    "mutateddeerclops",
    "mutatedwarg",
    "alterguardian_phase1",
    "alterguardian_phase2",
    "alterguardian_phase3",
    "stalker_atrium"
}
if TheNet:GetPVPEnabled() then
    local pvp_game_mode = GetModConfigData(modid..'_keepsake')

    if pvp_game_mode~=0 then
        local origin = pvp_game_mode==1 and "_keepsake" or "_origin"
        local random_index = math.random(1, #BOSS)
        local picked_boss = BOSS[random_index]
        for k, v in pairs(TUNING.GAMEMODE_STARTING_ITEMS.DEFAULT) do
            table.insert(v,picked_boss..origin)
        end
    end
end
TUNING.GAMEMODE_STARTING_ITEMS.DEFAULT.REGENT = TUNING.GAMEMODE_STARTING_ITEMS.DEFAULT.REGENT or {}
for i, v in ipairs(BOSS) do
    table.insert(TUNING.GAMEMODE_STARTING_ITEMS.DEFAULT.REGENT,v.."_keepsake")
    TUNING.STARTING_ITEM_IMAGE_OVERRIDE[v.."_keepsake"] = {	atlas = "images/inventoryimages/"..v.."_keepsake.xml",	image = v.."_keepsake.tex"}
    table.insert(TUNING.GAMEMODE_STARTING_ITEMS.DEFAULT.REGENT,v.."_origin")
    TUNING.STARTING_ITEM_IMAGE_OVERRIDE[v.."_origin"] = {	atlas = "images/inventoryimages/"..v.."_origin.xml",	image = v.."_origin.tex"}
end