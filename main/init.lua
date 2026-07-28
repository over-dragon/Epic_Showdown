GLOBAL.setmetatable(env,{__index=function(t,k) return GLOBAL.rawget(GLOBAL,k) end})

Assets = {
    Asset("ANIM", "anim/epic_castselect_icons.zip"),
    Asset("IMAGE","images/epickeepsake_filter.tex"),
	Asset("ATLAS", "images/epickeepsake_filter.xml"),
    Asset("IMAGE","images/headframe.tex"),
	Asset("ATLAS", "images/headframe.xml"),
}

PrefabFiles = {
    "epic_casting_fx",
    "epickeepsakes",
    "antlion_sand_spike",
    "epic_corpse",
    "epic_buffs",
    "epic_daywalker_head_fx",
    "epic_alterguardian_laser",
    "epic_alterguardian_phase3trap",
}

AddReplicableComponent("wereepic")