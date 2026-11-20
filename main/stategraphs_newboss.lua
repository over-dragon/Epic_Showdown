local AddEpicAttackState = EpicShowDownState.AddEpicAttackState
local AddEpicWalkStartState = EpicShowDownState.AddEpicWalkStartState
local AddEpicWalkState = EpicShowDownState.AddEpicWalkState
local AddEpicWalkStopState = EpicShowDownState.AddEpicWalkStopState
local AddEpicDeathState = EpicShowDownState.AddEpicDeathState
local AddEpicBecameState = EpicShowDownState.AddEpicBecameState
local AddEpicTauntState = EpicShowDownState.AddEpicTauntState
local AddEpicKnockoutState = EpicShowDownState.AddEpicKnockoutState
local AddEpicWakeupState = EpicShowDownState.AddEpicWakeupState

local klaus = EPIC_SHOWDOWN_FNS.KLAUS

local function DoAttackHit(inst)
    if not inst.sg.statemem.isattack then
        inst:PerformBufferedAction()
    else
        inst:ClearBufferedAction()
    end
    inst.sg:RemoveStateTag("abouttoattack")
end

AddEpicBecameState("klaus_becameepic",
    function (inst)
        inst.AnimState:PlayAnimation("taunt2")
    end,
    {
        TimeEvent(11 * FRAMES, function(inst)
                inst.sg:AddStateTag("nofreeze")
                inst.sg:AddStateTag("nosleep")
            end),
        TimeEvent(12 * FRAMES, function(inst)
            inst.SoundEmitter:PlaySound("dontstarve/creatures/together/klaus/taunt")
        end),
        TimeEvent(14 * FRAMES, function(inst)
            klaus:DoRoarShake(inst)
        end),
        TimeEvent(15 * FRAMES, function (inst)
            klaus:DoRoarAlert(inst)
        end),
        TimeEvent(56 * FRAMES, function(inst)
            inst.sg:RemoveStateTag("busy")
            inst.sg:RemoveStateTag("nosleep")
            inst.sg:RemoveStateTag("nofreeze")
        end),
    }
)

AddEpicDeathState("klaus_death",
    function (inst)
        inst.AnimState:PlayAnimation("death")
        if not inst:HasTag("epic_nextmode") then
            for i, v in ipairs(inst.components.commander:GetAllSoldiers()) do
                if v:HasTag("deergemresistance") then
                    inst.components.commander:RemoveSoldier(v)
                end
            end
        end
    end,
    {
        TimeEvent(FRAMES, function (inst)
            klaus:DoFoleySounds(inst)
        end),
        TimeEvent(3 * FRAMES, function(inst)
            klaus:DoBodyfall(inst)
            inst.SoundEmitter:PlaySound("dontstarve/creatures/together/klaus/death")
        end),
        TimeEvent(23 * FRAMES, function (inst)
            klaus:DoFoleySounds(inst)
        end),
        TimeEvent(25 * FRAMES, function(inst)
            inst.SoundEmitter:PlaySound("dontstarve/creatures/together/klaus/bodyfall_dirt")
            klaus:ShakeIfClose(inst)
            if inst.components.burnable:IsBurning() and inst.components.burnable.nocharring then
                inst.components.burnable:Extinguish()
            end
        end),
        TimeEvent(27 * FRAMES, function(inst)
            if inst:HasTag("klaus_angery") then
                inst.SoundEmitter:PlaySound("dontstarve_DLC001/creatures/bearger/groundpound")
            end
        end),
    },
    nil,
    "klaus",
    function (inst,corpse)
        local mode = inst.components.wereepic:GetEpicMode()
        if mode=="klaus2" then
            corpse.AnimState:Hide("swap_chain")
            corpse.AnimState:Hide("swap_chain_lock")
        end
        if inst:HasTag("klaus_angery") then
            corpse.Transform:SetScale(1.68,1.68,1.68)
        end
    end
)

AddEpicTauntState("klaus_taunt",
    function (inst)
        inst.AnimState:PlayAnimation("taunt1")
    end,
    {
        TimeEvent(0, function (inst)
            klaus:DoFoleySounds(inst)
        end),
        TimeEvent(2 * FRAMES, function(inst)
            inst.SoundEmitter:PlaySound("dontstarve/creatures/together/klaus/breath_in_fast")
        end),
        TimeEvent(9 * FRAMES, function(inst)
            inst.SoundEmitter:PlaySound("dontstarve/creatures/together/klaus/breath_in_fast", nil, .75)
        end),
        TimeEvent(12 * FRAMES, function(inst)
            klaus:DoFoleySounds(inst, .5)
        end),
        TimeEvent(25 * FRAMES, function(inst)
            inst.SoundEmitter:PlaySound("dontstarve/creatures/together/klaus/breath_in_fast", nil, .8)
        end),
        TimeEvent(25 * FRAMES, function(inst)
            klaus:DoFoleySounds(inst, .7)
        end),
        TimeEvent(32 * FRAMES, function(inst)
            inst.SoundEmitter:PlaySound("dontstarve/creatures/together/klaus/breath_in_fast")
        end),
        TimeEvent(43 * FRAMES, function (inst)
            klaus:DoFoleySounds(inst)
        end),
        TimeEvent(48 * FRAMES, function(inst)
            inst.sg:RemoveStateTag("busy")
        end),
    }
)

AddEpicAttackState("klaus_attack",
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
            inst.components.combat:DoAttack(inst.sg.statemem.target)
            DoAttackHit(inst)
        end),
        TimeEvent(23 * FRAMES, function (inst)
            klaus:DoSwipeSound(inst)
        end),
        TimeEvent(24 * FRAMES, function (inst)
            klaus:DoFoleySounds(inst)
        end),
        TimeEvent(27 * FRAMES, function(inst)
            inst.components.combat:DoAttack(inst.sg.statemem.target)
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
    "klaus_walk"
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
    }
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
    }
)

AddEpicKnockoutState("klaus_knockout",
    nil,
    nil,
    "klaus_wakeup",
    {
        TimeEvent(7 * FRAMES, function (inst)
            klaus:DoScratchSound(inst)
        end),
        TimeEvent(14 * FRAMES, function(inst)
            klaus:DoFoleySounds(inst, .5)
            klaus:DoScratchSound(inst)
        end),
        TimeEvent(19 * FRAMES, function (inst)
            klaus:DoScratchSound(inst)
        end),
        TimeEvent(24 * FRAMES, function (inst)
            klaus:DoScratchSound(inst)
        end),
        TimeEvent(29 * FRAMES, function (inst)
            klaus:DoScratchSound(inst)
        end),
        TimeEvent(33 * FRAMES, function(inst)
            klaus:DoFoleySounds(inst, .5)
        end),
        TimeEvent(34 * FRAMES, function (inst)
            klaus:DoScratchSound(inst)
        end),
        TimeEvent(39 * FRAMES, function (inst)
            klaus:DoScratchSound(inst)
        end),
        TimeEvent(42 * FRAMES, function(inst)
            inst.sg:RemoveStateTag("hitwakeup")
			inst.sg:AddStateTag("sleeping")
        end),
        TimeEvent(55 * FRAMES, function(inst)
            klaus:DoFootstep(inst)
            inst.SoundEmitter:PlaySound("dontstarve/creatures/together/klaus/breath_out", nil, .5)
        end),
        TimeEvent(57 * FRAMES, function(inst)
            inst.sg:RemoveStateTag("caninterrupt")
            klaus:DoFoleySounds(inst)
        end),
        TimeEvent(58 * FRAMES, function(inst)
            inst.SoundEmitter:PlaySound("dontstarve/creatures/together/klaus/bodyfall")
        end),
        TimeEvent(60 * FRAMES, function (inst)
            klaus:ShakeIfClose(inst)
        end),
        TimeEvent(68, function(inst)
            klaus:DoFoleySounds(inst, .3)
        end),
        TimeEvent(75 * FRAMES, function(inst)
            inst.SoundEmitter:PlaySound("dontstarve/creatures/together/klaus/breath_in")
        end),
        TimeEvent(97 * FRAMES, function(inst)
            klaus:DoFoleySounds(inst, .2)
        end),
        TimeEvent(100 * FRAMES, function(inst)
            inst.SoundEmitter:PlaySound("dontstarve/creatures/together/klaus/breath_out")
        end),
    }
)

AddEpicWakeupState("klaus_wakeup",
    nil,
    {
        TimeEvent(0, function(inst)
            klaus:DoFoleySounds(inst, .3)
        end),
        TimeEvent(3 * FRAMES, function (inst)
            klaus:DoBodyfall(inst)
        end),
        TimeEvent(23 * FRAMES, function(inst)
            inst.sg:RemoveStateTag("busy")
            inst.sg:RemoveStateTag("nosleep")
        end),
        TimeEvent(24 * FRAMES, function (inst)
            klaus:DoFoleySounds(inst)
        end),
    }
)

AddEpicBecameState("klaus2_becameepic",
    function (inst)
        inst.AnimState:PlayAnimation("death_amulet")
        inst.components.health:SetPercent(TUNING.KLAUS_HEALTH_REZ)
    end,
    {
        TimeEvent(0, function(inst)
            local stafflight = SpawnPrefab("staff_castinglight")
            stafflight.Transform:SetPosition(inst.Transform:GetWorldPosition())
            stafflight:SetUp({ 150 / 255, 46 / 255, 46 / 255 }, 1, 20 * FRAMES)
            inst.SoundEmitter:PlaySound("dontstarve/common/rebirth_amulet_raise")
        end),
        TimeEvent(39 * FRAMES, function(inst)
            inst.SoundEmitter:PlaySound("dontstarve/common/rebirth_amulet_poof")
        end),
        TimeEvent(48 * FRAMES, function (inst)
            klaus:DoBodyfall(inst)
        end)
    },
    nil,
    "klaus2_becameepic2",
    function (inst)
        inst.components.health:SetPercent(TUNING.KLAUS_HEALTH_REZ)
    end
)

AddEpicBecameState("klaus2_becameepic2",
    function (inst)
        inst.AnimState:PlayAnimation("death_pst")
    end,
    {
        TimeEvent(0, function(inst)
            klaus:DoFoleySounds(inst, .3)
            klaus:DoScratchSound(inst)
        end),
        TimeEvent(4 * FRAMES, function (inst)
            klaus:DoBodyfall(inst)
        end),
        TimeEvent(10 * FRAMES, function(inst)
            klaus:DoFoleySounds(inst, .2)
        end),
        TimeEvent(23 * FRAMES, function (inst)
            klaus:DoFoleySounds(inst)
        end),
        TimeEvent(25 * FRAMES, function(inst)
            inst.SoundEmitter:PlaySound("dontstarve/creatures/together/klaus/lock_break")
            inst.SoundEmitter:PlaySound("dontstarve/creatures/together/klaus/breath_out")
        end),
        TimeEvent(26 * FRAMES, function (inst)
            klaus:DoFoleySounds(inst)
        end),
    },
    nil,
    nil,
    nil,
    true
)

AddEpicTauntState("klaus2_taunt",
    function (inst)
        inst.AnimState:PlayAnimation("taunt2")
    end,
    {
        TimeEvent(11 * FRAMES, function(inst)
            inst.sg:AddStateTag("nofreeze")
            inst.sg:AddStateTag("nosleep")
        end),
        TimeEvent(12 * FRAMES, function(inst)
            inst.SoundEmitter:PlaySound("dontstarve/creatures/together/klaus/taunt")
        end),
        TimeEvent(14 * FRAMES, function (inst)
            klaus:DoRoarShake(inst)
        end),
        TimeEvent(15 * FRAMES, function (inst)
            klaus:DoRoarAlert(inst)
        end),
        TimeEvent(56 * FRAMES, function(inst)
            inst.sg:RemoveStateTag("busy")
            inst.sg:RemoveStateTag("nosleep")
            inst.sg:RemoveStateTag("nofreeze")
        end),
    }
)