local EPIC = require("wereepic_skill")

AddComponentAction("USEITEM", "edible", function(inst, doer, target, actions, right)
    if target and target:HasTag("epic") and target:HasTag("player") then
        for i, action in ipairs(actions) do
            if action == ACTIONS.FEEDPLAYER then
                table.remove(actions, i)
                break
            end
        end
    end
end)

AddComponentAction("USEITEM", "inventoryitem", function(inst, doer, target, actions, right)
    if target and target:HasTag("epic") and target:HasTag("player") then
        for i, action in ipairs(actions) do
            if action == ACTIONS.GIVETOPLAYER or action==ACTIONS.GIVEALLTOPLAYER then
                table.remove(actions, i)
            end
        end
    end
end)

local NOTAGS = {'INLIMBO',"DECOR", "FX"}
if TUNING.EPIC_WORLD.STRUCTURE_PROTECTION == 1 then
    table.insert(NOTAGS, "structure")
    table.insert(NOTAGS, "wall")
    table.insert(NOTAGS, "waxedplant")
    table.insert(NOTAGS, "ancienttree")
end
local DAMAGE_ONEOF_TAGS = { "pickable", "NPC_workable", "CHOP_workable", "HAMMER_workable", "MINE_workable", "DIG_workable" }
local function EpicTrample(inst,x,y,z)
    for _, v in pairs(TheSim:FindEntities(x, y or 0, z, 4, nil, NOTAGS, DAMAGE_ONEOF_TAGS)) do
        if v:IsValid() then
            local isworkable = false
            if v.components.workable ~= nil then
                local work_action = v.components.workable:GetWorkAction()
                isworkable =
                    (   work_action == nil and v:HasTag("NPC_workable") ) or
                    (   v.components.workable:CanBeWorked() and
                        (   work_action == ACTIONS.CHOP or
                             work_action == ACTIONS.HAMMER or
                            work_action == ACTIONS.MINE or
                            (   work_action == ACTIONS.DIG and
                                ( TUNING.EPIC_WORLD.STRUCTURE_PROTECTION == 1 and v:HasTag("stump") or TUNING.EPIC_WORLD.STRUCTURE_PROTECTION ~= 1)
                            )
                        )
                    )
            end
            if isworkable then
                local x1, y1, z1 = v.Transform:GetWorldPosition()
                SpawnPrefab("collapse_small").Transform:SetPosition(x1, y1, z1)
                v.components.workable:Destroy(inst)

                if v:HasTag("stump") then
                    if v.components.workable then
                        v.components.workable:WorkedBy_Internal(inst, 30)
                    else
                        v:Remove()
                    end
                end
            elseif v.components.pickable ~= nil
                    and v.components.pickable:CanBePicked()
                    and not v:HasTag("intense") and (TUNING.EPIC_WORLD.STRUCTURE_PROTECTION == 1 and not v:HasTag("flower") or TUNING.EPIC_WORLD.STRUCTURE_PROTECTION ~= 1) then
                local success, loots = v.components.pickable:Pick(TheWorld)
                if loots then
                    for i, v in ipairs(loots) do
                        Launch(v, inst, 0.2)
                    end
                end
            end
        end
    end
end
local function PlayMiningFX(inst, target, nosound)
    if target ~= nil and target:IsValid() then
        local frozen = target:HasTag("frozen")
        local moonglass = target:HasAnyTag("moonglass", "LunarBuildup")
        local crystal = target:HasTag("crystal")
        if target.Transform ~= nil then
            SpawnPrefab(
                (frozen and "mining_ice_fx") or
                (moonglass and "mining_moonglass_fx") or
                (crystal and "mining_crystal_fx") or
                "mining_fx"
            ).Transform:SetPosition(target.Transform:GetWorldPosition())
        end
        if not nosound and inst.SoundEmitter ~= nil then
            inst.SoundEmitter:PlaySound(
                (frozen and "dontstarve_DLC001/common/iceboulder_hit") or
                ((moonglass or crystal) and "turnoftides/common/together/moon_glass/mine") or
                "dontstarve/wilson/use_pick_rock"
            )
        end
    end
end

local function HarvestPickable(ent, doer)
    if ent.components.pickable.picksound ~= nil then
        doer.SoundEmitter:PlaySound(ent.components.pickable.picksound)
    end

    local success, loot = ent.components.pickable:Pick(TheWorld)

    if loot ~= nil then
        for i, item in ipairs(loot) do
            Launch(item, doer, 1.5)
        end
    end
end

local function IsEntityInFront( entity, doer_rotation, doer_pos)
    local facing = Vector3(math.cos(-doer_rotation / RADIANS), 0 , math.sin(-doer_rotation / RADIANS))
    return IsWithinAngle(doer_pos, facing, TUNING.VOIDCLOTH_SCYTHE_HARVEST_ANGLE_WIDTH, entity:GetPosition())
end

local HARVEST_MUSTTAGS  = {"pickable"}
local HARVEST_CANTTAGS  = {"INLIMBO", "FX"}
local HARVEST_ONEOFTAGS = {"plant", "lichen", "oceanvine", "kelp"}

local function DoScythe( target, doer)
    if target.components.pickable ~= nil then
        local doer_pos = doer:GetPosition()
        local x, y, z = doer_pos:Get()

        local doer_rotation = doer.Transform:GetRotation()

        local ents = TheSim:FindEntities(x, y, z, TUNING.VOIDCLOTH_SCYTHE_HARVEST_RADIUS, HARVEST_MUSTTAGS, HARVEST_CANTTAGS, HARVEST_ONEOFTAGS)
        for _, ent in pairs(ents) do
            if ent:IsValid() and ent.components.pickable ~= nil then
                if IsEntityInFront(ent, doer_rotation, doer_pos) then
                    HarvestPickable(ent, doer)
                end
            end
        end
    end
    local x, y, z = target.Transform:GetWorldPosition()
    EpicTrample(doer, x, y, z)
end

local function DoEpicWork(act, workaction)
    local target = act.target
    local doer = act.doer
    if target == nil or doer == nil then return false end

    if target.components.workable == nil or
       not target.components.workable:CanBeWorked() or
       target.components.workable:GetWorkAction() ~= workaction then
        return false
    end

    if workaction == ACTIONS.MINE then
        PlayMiningFX(doer,target)
    elseif workaction == ACTIONS.DIG then
        doer.SoundEmitter:PlaySound("dontstarve/wilson/dig")
    elseif workaction == ACTIONS.HAMMER then
       doer.SoundEmitter:PlaySound("dontstarve/wilson/hit")
    end

    local x,y,z = target.Transform:GetWorldPosition()
    EpicTrample(doer, x, y, z)

    if target and target:IsValid() and target.components.workable and target.components.workable:CanBeWorked() then
        target.components.workable:WorkedBy_Internal(doer, 30)
    end

    return true
end

local EPIC_CHOP = Action()
EPIC_CHOP.id = "EPIC_CHOP"
EPIC_CHOP.strfn = function (act)
    return "EPIC_CHOP"
end
EPIC_CHOP.invalid_hold_action = true
EPIC_CHOP.distance = 5
EPIC_CHOP.fn = function (act)
    return DoEpicWork(act, ACTIONS.CHOP)
end
AddAction(EPIC_CHOP)
STRINGS.ACTIONS.EPIC_CHOP = {
    EPIC_CHOP = STRINGS.EPIC_ACTIONS_NAMED.CHOP
}

local EPIC_MINE = Action()
EPIC_MINE.id = "EPIC_MINE"
EPIC_MINE.strfn = function (act)
    return "EPIC_MINE"
end
EPIC_MINE.invalid_hold_action = true
EPIC_MINE.distance = 5
EPIC_MINE.fn = function (act)
    return DoEpicWork(act, ACTIONS.MINE)
end
AddAction(EPIC_MINE)
STRINGS.ACTIONS.EPIC_MINE = {
    EPIC_MINE = STRINGS.EPIC_ACTIONS_NAMED.MINE
}

local EPIC_DIG = Action()
EPIC_DIG.id = "EPIC_DIG"
EPIC_DIG.strfn = function (act)
    return "EPIC_DIG"
end
EPIC_DIG.rmb = true
EPIC_DIG.invalid_hold_action = true
EPIC_DIG.distance = 5
EPIC_DIG.fn = function (act)
    return DoEpicWork(act, ACTIONS.DIG)
end
AddAction(EPIC_DIG)
STRINGS.ACTIONS.EPIC_DIG = {
    EPIC_DIG = STRINGS.EPIC_ACTIONS_NAMED.DIG
}

local EPIC_HAMMER = Action()
EPIC_HAMMER.id = "EPIC_HAMMER"
EPIC_HAMMER.strfn = function (act)
    return "EPIC_HAMMER"
end
EPIC_HAMMER.priority = 3
EPIC_HAMMER.distance = 5
EPIC_HAMMER.invalid_hold_action = true
EPIC_HAMMER.fn = function (act)
    return DoEpicWork(act, ACTIONS.HAMMER)
end
AddAction(EPIC_HAMMER)
STRINGS.ACTIONS.EPIC_HAMMER = {
    EPIC_HAMMER = STRINGS.EPIC_ACTIONS_NAMED.HAMMER
}

local EPIC_SCYTHE = Action()
EPIC_SCYTHE.id = "EPIC_SCYTHE"
EPIC_SCYTHE.strfn = function (act)
    return "EPIC_SCYTHE"
end
EPIC_SCYTHE.distance = 5
EPIC_SCYTHE.rmb=true
EPIC_SCYTHE.invalid_hold_action = true
EPIC_SCYTHE.fn = function (act)
    local target = act.target
    local doer = act.doer
    if target == nil or doer == nil then return false end

    if target.components.pickable == nil or not target.components.pickable:CanBePicked() then
        return false
    end

    DoScythe(target, doer)
    return true
end
AddAction(EPIC_SCYTHE)
STRINGS.ACTIONS.EPIC_SCYTHE = {
    EPIC_SCYTHE = STRINGS.EPIC_ACTIONS_NAMED.SCYTHE
}

AddStategraphActionHandler("wilson", ActionHandler(ACTIONS.EPIC_CHOP, "epic_attack"))
AddStategraphActionHandler("wilson_client", ActionHandler(ACTIONS.EPIC_CHOP, "epic_attack"))
AddStategraphActionHandler("wilson", ActionHandler(ACTIONS.EPIC_MINE, "epic_attack"))
AddStategraphActionHandler("wilson_client", ActionHandler(ACTIONS.EPIC_MINE, "epic_attack"))
AddStategraphActionHandler("wilson", ActionHandler(ACTIONS.EPIC_DIG, "epic_attack"))
AddStategraphActionHandler("wilson_client", ActionHandler(ACTIONS.EPIC_DIG, "epic_attack"))
AddStategraphActionHandler("wilson", ActionHandler(ACTIONS.EPIC_HAMMER, "epic_attack"))
AddStategraphActionHandler("wilson_client", ActionHandler(ACTIONS.EPIC_HAMMER, "epic_attack"))
AddStategraphActionHandler("wilson", ActionHandler(ACTIONS.EPIC_SCYTHE, "epic_attack"))
AddStategraphActionHandler("wilson_client", ActionHandler(ACTIONS.EPIC_SCYTHE, "epic_attack"))

local EPIC_SKILL = Action()
EPIC_SKILL.id = "EPIC_SKILL"
EPIC_SKILL.strfn = function (act)
    return "EPIC_SKILL"
end
EPIC_SKILL.invalid_hold_action = true
EPIC_SKILL.distance = 50
EPIC_SKILL.fn = function (act)
    local doer = act.doer
    local mode = doer.replica.wereepic:GetEpicMode()
    if EPIC[mode].skill then
        return EPIC[mode].skill
    else
        return false
    end
end
AddAction(EPIC_SKILL)
STRINGS.ACTIONS.EPIC_SKILL = {
    EPIC_SKILL = STRINGS.EPIC_ACTIONS_NAMED.SKILL
}

AddStategraphActionHandler("wilson", ActionHandler(ACTIONS.EPIC_SKILL, function(inst, action)
        local mode = inst.replica.wereepic:GetEpicMode()
        local skill0 = EPIC[mode].stategraphs.skill0
        if type(skill0)=="function" then
            return skill0(inst)
        else
            return skill0
        end
    end))
AddStategraphActionHandler("wilson_client", ActionHandler(ACTIONS.EPIC_SKILL, function(inst, action)
        local mode = inst.replica.wereepic:GetEpicMode()
        local skill0 = EPIC[mode].stategraphs.skill0
        if type(skill0)=="function" then
            return skill0(inst)
        else
            return skill0
        end
    end))

local EPIC_USEITEM = Action()
EPIC_USEITEM.id = "EPIC_USEITEM"
EPIC_USEITEM.strfn = function (act)
    return "EPIC_USEITEM"
end
EPIC_USEITEM.invalid_hold_action = true
EPIC_USEITEM.fn = function (act)
    local doer = act.doer
    local invobject = act.invobject
    return invobject.components.wereepic_useableitem and invobject.components.wereepic_useableitem:StartUsing(doer)
end
AddAction(EPIC_USEITEM)
STRINGS.ACTIONS.EPIC_USEITEM = {
    EPIC_USEITEM = STRINGS.EPIC_ACTIONS_NAMED.USEITEM
}

AddStategraphActionHandler("wilson", ActionHandler(ACTIONS.EPIC_USEITEM, "epic_castspell"))
AddStategraphActionHandler("wilson_client", ActionHandler(ACTIONS.EPIC_USEITEM, "epic_castspell"))

local MONKEY_CURSE = {"wonkey","MONKEY_CURSE_1","MONKEY_CURSE_2","MONKEY_CURSE_3"}
AddComponentAction("INVENTORY", "wereepic_useableitem", function(inst, doer, actions, right)
    if inst and doer and not doer.replica.wereepic:IsEpic() and not doer:HasAnyTag(MONKEY_CURSE) and not inst:HasTag("epicorigin_discharged") then
        table.insert(actions, ACTIONS.EPIC_USEITEM)
    end
end)

local EPIC_CHARGE = Action()
EPIC_CHARGE.id = "EPIC_CHARGE"
EPIC_CHARGE.priority = 5
EPIC_CHARGE.strfn = function (act)
    return "EPIC_CHARGE"
end
EPIC_CHARGE.fn = function (act)
    local target = act.target
    local invobject = act.invobject
    return invobject.components.wereepic_chargeitem and invobject.components.wereepic_chargeitem:Charge(invobject, target)
end
AddAction(EPIC_CHARGE)
STRINGS.ACTIONS.EPIC_CHARGE = {
    EPIC_CHARGE = STRINGS.EPIC_ACTIONS_NAMED.CHARGE
}

AddStategraphActionHandler("wilson", ActionHandler(ACTIONS.EPIC_CHARGE, "doshortaction"))
AddStategraphActionHandler("wilson_client", ActionHandler(ACTIONS.EPIC_CHARGE, "doshortaction"))

AddComponentAction("USEITEM", "wereepic_chargeitem", function(inst, doer, target, actions, right)
    if right and target:HasTag("epicorigin_discharged") then
        table.insert(actions, ACTIONS.EPIC_CHARGE)
    end
end)

local EPIC_MAP_TELEPORT = Action()
EPIC_MAP_TELEPORT.id = "EPIC_MAP_TELEPORT"
EPIC_MAP_TELEPORT.strfn = function (act)
    return "EPIC_MAP_TELEPORT"
end
EPIC_MAP_TELEPORT.invalid_hold_action = true
EPIC_MAP_TELEPORT.priority = 10
EPIC_MAP_TELEPORT.rmb=true
EPIC_MAP_TELEPORT.map_action = true
EPIC_MAP_TELEPORT.map_works_on_unexplored = true
EPIC_MAP_TELEPORT.closes_map = true
EPIC_MAP_TELEPORT.customarrivecheck = function ()
    return true
end
EPIC_MAP_TELEPORT.fn = function (act)
    local mode = act.doer.replica.wereepic:GetEpicMode()
    local act_pos = act:GetActionPoint()
    if act_pos == nil then return false end
    local x, y, z = act_pos:Get()

    if mode=="antlion" or mode=="ancient_hulk" then
        if TheWorld.Map:IsOceanAtPoint(x,y, z) then return false end
        if TheWorld.Map:GetPlatformAtPoint(x,y, z) ~= nil then return false end

        if mode=="ancient_hulk" then
            act.doer.sg:GoToState("ancient_hulk_telportout", { dest = act_pos })
        elseif mode=="antlion" then
            act.doer.sg:GoToState("antlion_jumpin_enter", { dest = act_pos })
        end
    elseif mode=="malbatross" then
        if not TheWorld.Map:IsVisualGroundAtPoint(x,y,z) then
            act.doer.sg:GoToState("malbatross_arrive", { dest = act_pos })
        end
    end
    return true
end
AddAction(EPIC_MAP_TELEPORT)
STRINGS.ACTIONS.EPIC_MAP_TELEPORT = {
    EPIC_MAP_TELEPORT = STRINGS.EPIC_ACTIONS_NAMED.MAP_TELEPORT
}
ACTIONS_MAP_REMAP[ACTIONS.EPIC_MAP_TELEPORT.code] = function(act, targetpos)
    return BufferedAction(act.doer, nil, ACTIONS.EPIC_MAP_TELEPORT, act.invobject, targetpos)
end

AddStategraphActionHandler("wilson", ActionHandler(ACTIONS.EPIC_MAP_TELEPORT, function(inst, action)
        local mode = inst.replica.wereepic:GetEpicMode()
        return EPIC[mode].stategraphs.map_teleport
    end))
AddStategraphActionHandler("wilson_client", ActionHandler(ACTIONS.EPIC_MAP_TELEPORT, function(inst, action)
        local mode = inst.replica.wereepic:GetEpicMode()
        return EPIC[mode].stategraphs.map_teleport
    end))