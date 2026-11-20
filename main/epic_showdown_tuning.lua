EPIC_SHOWDOWN_TUNING =
{
    SHARKBOI = {
        WORK_RADIUS_PADDING = 0.5,

        COLLAPSIBLE_WORK_ACTIONS = {
            CHOP = true,
            HAMMER = true,
            MINE = true,
        },

        COLLAPSIBLE_WORK_AND_DIG_ACTIONS = {
            CHOP = true,
            HAMMER = true,
            MINE = true,
            DIG = true,
        },

        COLLAPSIBLE_TAGS = { "NPC_workable", "CHOP_workable", "HAMMER_workable", "MINE_workable" },

        COLLAPSIBLE_DIG_TAGS = { "NPC_workable", "CHOP_workable", "HAMMER_workable", "MINE_workable", "pickable", "DIG_workable" },

        NON_COLLAPSIBLE_TAGS = { "FX", --[["NOCLICK",]] "DECOR", "INLIMBO" },

        AOE_RANGE_PADDING = 3,
        AOE_TARGET_MUSTHAVE_TAGS = { "_combat" },
        AOE_TARGET_CANT_TAGS = { "INLIMBO", "invisible", "notarget", "noattack" },

        TOSSITEM_MUST_TAGS = { "_inventoryitem" },
        TOSSITEM_CANT_TAGS = { "locomotor", "INLIMBO" },

        SWIPE_ARC = 240,
        SWIPE_OFFSET = 2,
        SWIPE_RADIUS = 3.5,

        SPAWN_CHECK_TAGS = { "locomotor" },
        SPAWN_CHECK_NOTAGS = { "INLIMBO", "invisible", "flight" },
    },

    VAULT_PILLAR_GUARD = {

        WORK_RADIUS_PADDING = 0.5,
        COLLAPSIBLE_WORK_ACTIONS = {
            CHOP = true,
            HAMMER = true,
            MINE = true,
        },

        COLLAPSIBLE_WORK_AND_DIG_ACTIONS = {
            CHOP = true,
            HAMMER = true,
            MINE = true,
            DIG = true,
        },
        COLLAPSIBLE_TAGS = { "NPC_workable", "CHOP_workable", "HAMMER_workable", "MINE_workable" },
        COLLAPSIBLE_DIG_TAGS = { "NPC_workable", "CHOP_workable", "HAMMER_workable", "MINE_workable", "pickable", "DIG_workable" },
        NON_COLLAPSIBLE_TAGS = { "FX", --[["NOCLICK",]] "DECOR", "INLIMBO" },

        AOE_RANGE_PADDING = 3,
        AOE_TARGET_MUSTHAVE_TAGS = { "_combat" },
        AOE_TARGET_CANT_TAGS = { "INLIMBO", "invisible", "notarget", "noattack" },

        TOSSITEM_MUST_TAGS = { "_inventoryitem" },
        TOSSITEM_CANT_TAGS = { "locomotor", "INLIMBO" },
    },

    KLAUS = {
        ENRAGE_SCALE = 1.4,

        ATTACK_RANGE = 3,
        ATTACK_RANGE_ANGRY = 4.2,
        HIT_RANGE = 4,
        HIT_RANGE_ANGRY = 5.6,

        CHOMP_RANGE = 7,
        CHOMP_RANGE_ANGRY = 9,
        CHOMP_MIN_RANGE = 4.5,
        CHOMP_MIN_RANGE_ANGRY = 6.3,
        CHOMP_HIT_RANGE = 3.5,
        CHOMP_HIT_RANGE_ANGRY = 4.9,
        CHOMP_SPEED_FRAMES = 10,

        ROAR_SCARE_TIME = 5,

        LAUGH_COUNT = 10,

        CHOMP_CD = 6,
        COMMAND_CD = 6,
    }
}

if TUNING.EPIC_WORLD.STRUCTURE_PROTECTION==1 then
    for _, t in ipairs({ EPIC_SHOWDOWN_TUNING.SHARKBOI, EPIC_SHOWDOWN_TUNING.VAULT_PILLAR_GUARD }) do
        table.insert(t.NON_COLLAPSIBLE_TAGS,"structure")
        table.insert(t.NON_COLLAPSIBLE_TAGS,"wall")
    end
end

EPIC_SHOWDOWN_TUNING.EPIC_ATTACK = {
    klaus = "klaus_attack",
    klaus2 = "klaus_attack"
}

EPIC_SHOWDOWN_TUNING.EPIC_WALK_START = {
    klaus = "klaus_walk_start",
    klaus2 = "klaus_walk_start"
}

EPIC_SHOWDOWN_TUNING.EPIC_WALK_STOP = {
    klaus = "klaus_walk_stop",
    klaus2 = "klaus_walk_stop"
}

EPIC_SHOWDOWN_TUNING.EPIC_DEATH = {
    klaus = "klaus_death",
    klaus2 = "klaus_death"
}

EPIC_SHOWDOWN_TUNING.EPIC_BECAME = {
    klaus = "klaus_becameepic",
    klaus2 = "klaus2_becameepic"
}

EPIC_SHOWDOWN_TUNING.EPIC_TAUNT = {
    klaus = "klaus_taunt",
    klaus2 = "klaus2_taunt"
}

EPIC_SHOWDOWN_TUNING.EPIC_KNOCKOUT = {
    klaus = "klaus_knockout",
    klaus2 = "klaus_knockout"
}

EPIC_SHOWDOWN_TUNING.EPIC_WAKEUP = {
    klaus = "klaus_wakeup",
    klaus2 = "klaus_wakeup"
}

Epic_Showdown_Attack_Tags_Server = {"attack","notalking", "abouttoattack", "autopredict", "epic","epic_attack"}
Epic_Showdown_Attack_Tags_Client = {"attack","notalking", "abouttoattack", "epic","epic_attack"}
if TUNING.EPIC_WORLD.ATTACK_LOCOMTE_INTERRUPT~=1 then
    table.insert(Epic_Showdown_Attack_Tags_Server,"busy")
    table.insert(Epic_Showdown_Attack_Tags_Client,"busy")
end

GLOBAL.EPIC_SHOWDOWN_TUNING = EPIC_SHOWDOWN_TUNING