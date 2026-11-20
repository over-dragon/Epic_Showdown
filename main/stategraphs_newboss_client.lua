local AddClientEpicAttackState = EpicShowDownState.AddClientEpicAttackState
local AddEpicWalkStartState = EpicShowDownState.AddEpicWalkStartState
local AddEpicWalkState = EpicShowDownState.AddEpicWalkState
local AddEpicWalkStopState = EpicShowDownState.AddEpicWalkStopState

local klaus = EPIC_SHOWDOWN_FNS.KLAUS

local function DoAttackHit(inst)
    if inst.sg.statemem.isattack then
        inst:ClearBufferedAction()
    end
    inst.sg:RemoveStateTag("abouttoattack")
end

AddClientEpicAttackState("klaus_attack",
    function (inst)
        inst.AnimState:PlayAnimation("attack_doubleclaw")
    end,
    nil,
    nil,
    {
        TimeEvent(FRAMES, function (inst)
            klaus:DoFoleySounds(inst)
        end),
        TimeEvent(4 * FRAMES, function(inst)
            inst.sg:AddStateTag("nofreeze")
        end),
        TimeEvent(13 * FRAMES, function (inst)
            klaus:DoSwipeSound(inst)
        end),
        TimeEvent(14 * FRAMES, function (inst)
            klaus:DoFoleySounds(inst)
        end),
        TimeEvent(16 * FRAMES, function(inst)
            DoAttackHit(inst)
        end),
        TimeEvent(23 * FRAMES, function (inst)
            klaus:DoSwipeSound(inst)
        end),
        TimeEvent(24 * FRAMES, function (inst)
            klaus:DoFoleySounds(inst)
        end),
        TimeEvent(30 * FRAMES, function(inst)
            if inst:HasTag("klaus_angery") then
                inst.sg:RemoveStateTag("attack")
                inst.sg:RemoveStateTag("busy")
            end
        end),
        TimeEvent(40 * FRAMES, function(inst)
            inst.sg:RemoveStateTag("nofreeze")
        end),
    }
)

AddEpicWalkStartState("klaus_walk_start",
    nil,
    {
        TimeEvent(8 * FRAMES, function (inst)
            klaus:DoFoleySounds(inst)
        end),
        TimeEvent(9 * FRAMES, function (inst)
            klaus:DoFootstep(inst)
        end),
    },
    "klaus_walk",
    nil,
    true
)

AddEpicWalkState("klaus_walk",
    nil,
    {
        TimeEvent(20 * FRAMES, function (inst)
            klaus:DoFoleySounds(inst)
        end),
        TimeEvent(21 * FRAMES, function (inst)
            klaus:DoFootstep(inst)
        end),
        TimeEvent(44 * FRAMES, function (inst)
            klaus:DoFoleySounds(inst)
        end),
        TimeEvent(45 * FRAMES, function (inst)
            klaus:DoFootstep(inst)
        end),
    },
    nil,
    true
)

AddEpicWalkStopState("klaus_walk_stop",
    nil,
    {
        TimeEvent(0, function(inst)
            klaus:DoFoleySounds(inst)
            klaus:DoFootstep(inst, .6)
        end),
        TimeEvent(10 * FRAMES, function (inst)
            klaus:DoFoleySounds(inst)
        end),
    },
    nil,
    true
)