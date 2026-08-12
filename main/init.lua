GLOBAL.setmetatable(env,{__index=function(t,k) return GLOBAL.rawget(GLOBAL,k) end})

Assets = {
    Asset("ANIM", "anim/epic_castselect_icons.zip"),
    -- Asset("ANIM", "anim/epic_castselect_icons2.zip"),
    Asset("ANIM", "anim/ancient_hulk_build.zip"),
    Asset("ANIM", "anim/ancient_hulk.zip"),
    Asset("ANIM", "anim/laser_explode_sm.zip"),
    Asset("ANIM", "anim/smoke_aoe.zip"),
    Asset("IMAGE","images/epickeepsake_filter.tex"),
	Asset("ATLAS", "images/epickeepsake_filter.xml"),
    Asset("IMAGE","images/epicorigin_filter.tex"),
	Asset("ATLAS", "images/epicorigin_filter.xml"),
    Asset("SOUNDPACKAGE", "sound/epic_castselect_icons.fev"),
    Asset("SOUND", "sound/epic_castselect_icons.fsb"),
    Asset("SOUNDPACKAGE", "sound/mnh_ancient_hulk_sound.fev"),
    Asset("SOUND", "sound/mnh_ancient_hulk_sound.fsb"),
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
    "stalker_fossil_spike2",
    "epic_mutatedwarg_fx",
    "epic_mutatedbearger_fx",
    "epicorigin",
    "epic_chaosseed",
    "ancient_hulk_laser",
}

AddReplicableComponent("wereepic")

AddMinimapAtlas("images/map_icons/epic_chaosseed.xml")