local modid = 'epic_showdown'
TUNING.EPIC_WORLD = {
    STRUCTURE_PROTECTION = GetModConfigData(modid..'_structure_protection') or 1,
    BGM = GetModConfigData(modid..'_BGM') or 1,
    DAMAGE = GetModConfigData(modid..'_damage') or 1,
    HEALTH = GetModConfigData(modid..'_health') or 0.5,

    ATTACK_LOCOMTE_INTERRUPT = GetModConfigData(modid..'_attack_move') or 1,

    CASTSELECT_MUSIC = GetModConfigData(modid..'_caselect_music') or 1,

    MAT_NUM = GetModConfigData(modid..'_mat') or 1,

    WALKSPEED_CHANGE = GetModConfigData(modid..'walkspeed_change') or 0,

    COMBAT_TARGET = GetModConfigData(modid..'_combat_target') or 0,

    RECIPE = GetModConfigData(modid..'_recipes') or 0
}
if TUNING.ANCIENT_HULK_HEALTH==nil then
    TUNING.ANCIENT_HULK_HEALTH = 8000
end
if TUNING.ANCIENT_HULK_DAMAGE==nil then
    TUNING.ANCIENT_HULK_DAMAGE = 200
end
if TUNING.ANCIENT_HULK_ATTACK_RANGE==nil then
    TUNING.ANCIENT_HULK_ATTACK_RANGE = 5.5
end

local EPIC = require("epic_keepsakes")
local BOSS = {}

for _, v in ipairs(EPIC) do
    table.insert(BOSS,v.name)
end

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