---deerclops
local function YuleOnNewState(inst, data)
    if not (inst.sg:HasStateTag("sleeping") or inst.sg:HasStateTag("waking")) then
        inst.Light:SetIntensity(.6)
        inst.Light:SetRadius(8)
        inst.Light:SetFalloff(3)
        inst.Light:SetColour(1, 0, 0)
    end
end
local function Deerclops_OnHitOther(inst, data)
    local other = data.target
    if other ~= nil then
        if not (other.components.health ~= nil and other.components.health:IsDead()) then
            if other.components.freezable ~= nil then
				other.components.freezable:AddColdness(inst.sg.statemem.freezepower or inst.freezepower or 2)
            end
			local ent_temp = GetEntityTemperature(other)
			if ent_temp and 0 < ent_temp then
            	DoDeltaTemperatureToEntity(other, -5)
			end
        end
        if other.components.freezable ~= nil then
            other.components.freezable:SpawnShatterFX()
        end
    end
end
local function deerclops_oncollapse(inst, other)
    if other:IsValid() and other.components.workable ~= nil and other.components.workable:CanBeWorked() then
        SpawnPrefab("collapse_small").Transform:SetPosition(other.Transform:GetWorldPosition())
        other.components.workable:Destroy(inst)
    end
end
local function deerclops_oncollide(inst, other)
    if other ~= nil and
        (other:HasTag("tree") or other:HasTag("boulder")) and --HasTag implies IsValid
        Vector3(inst.Physics:GetVelocity()):LengthSq() >= 1 then
        inst:DoTaskInTime(2 * FRAMES, deerclops_oncollapse, other)
    end
end
---bearger
local function bearger_Clearbearger_recentlycharged(inst, other)
    inst.bearger_recentlycharged[other] = nil
end

local function bearger_OnDestroyOther(inst, other)
    if other:IsValid() and
        other.components.workable ~= nil and
        other.components.workable:CanBeWorked() and
        other.components.workable.action ~= ACTIONS.NET and
        not inst.bearger_recentlycharged[other] then
        SpawnPrefab("collapse_small").Transform:SetPosition(other.Transform:GetWorldPosition())
        other.components.workable:Destroy(inst)
        if other:IsValid() and other.components.workable ~= nil and other.components.workable:CanBeWorked() then
            inst.bearger_recentlycharged[other] = true
            inst:DoTaskInTime(3, bearger_Clearbearger_recentlycharged, other)
        end
    end
end

local function bearger_oncollide(inst, other)
    if other ~= nil and
        other:IsValid() and
        other.components.workable ~= nil and
        other.components.workable:CanBeWorked() and
        other.components.workable.action ~= ACTIONS.NET and
        (TUNING.EPIC_WORLD.STRUCTURE_PROTECTION ~= 1 or
    (other.components.workable.action == ACTIONS.DIG and other:HasTag("stump")) or
    (other.components.workable.action ~= ACTIONS.DIG and not other:HasTag("structure") and not other:HasTag("wall"))
        ) and
        Vector3(inst.Physics:GetVelocity()):LengthSq() >= 1 and
        not inst.bearger_recentlycharged[other] then
        inst:DoTaskInTime(2 * FRAMES, bearger_OnDestroyOther, other)
    end
end

local function bearger_OnHitOther(inst, data)
    if inst.sg:HasStateTag("weapontoss") and data.target ~= nil and data.target.components.inventory ~= nil and not data.target:HasTag("stronggrip")
    and not data.target.components.inventory:IsThiefProof() then
        local item = data.target.components.inventory:GetEquippedItem(EQUIPSLOTS.HANDS)
        if item ~= nil and not item:HasTag("nosteal") then
            data.target.components.inventory:DropItem(item)
            LaunchItem(inst, data.target, item)
        end
    end
end

---malbatross

---beequeen
local MAX_HONEY_VARIATIONS = 7
local MAX_RECENT_HONEY = 4
local HONEY_PERIOD = .2
local HONEY_LEVELS =
{
    {
        min_scale = .5,
        max_scale = .8,
        threshold = 8,
        duration = 1.2,
    },
    {
        min_scale = .5,
        max_scale = 1.1,
        threshold = 2,
        duration = 2,
    },
    {
        min_scale = 1,
        max_scale = 1.3,
        threshold = 1,
        duration = 4,
    },
}
local function PickHoney(inst)
    local rand = table.remove(inst.beequeen_availablehoney, math.random(#inst.beequeen_availablehoney))
    table.insert(inst.beequeen_usedhoney, rand)
    if #inst.beequeen_usedhoney > MAX_RECENT_HONEY then
        table.insert(inst.beequeen_availablehoney, table.remove(inst.beequeen_usedhoney, 1))
    end
    return rand
end

local function TrySpawnHoney(inst, x, z, min_scale, max_scale, duration)
	if TheWorld.Map:IsPassableAtPoint(x, 0, z) then
		local fx = SpawnPrefab("honey_trail")
        fx.Transform:SetPosition(x, 0, z) -- NOTES(JBK): This must be before SetVariation is called!
		fx:SetVariation(PickHoney(inst), GetRandomMinMax(min_scale, max_scale), duration + math.random() * .5)
	else
		SpawnPrefab("ocean_splash_ripple"..tostring(math.random(2))).Transform:SetPosition(x, 0, z)
	end
end

local function DoHoneyTrail(inst)
    local level = HONEY_LEVELS[
        (not inst.sg:HasStateTag("moving") and 1) or
        (inst.components.locomotor.walkspeed <= TUNING.BEEQUEEN_SPEED and 2) or
        3
    ]

    inst.beequeen_honeycount = inst.beequeen_honeycount + 1

    if inst.beequeen_honeythreshold > level.threshold then
        inst.beequeen_honeythreshold = level.threshold
    end

    if inst.beequeen_honeycount >= inst.beequeen_honeythreshold then
        local hx, hy, hz = inst.Transform:GetWorldPosition()
        inst.beequeen_honeycount = 0
        if inst.beequeen_honeythreshold < level.threshold then
            inst.beequeen_honeythreshold = math.ceil((inst.beequeen_honeythreshold + level.threshold) * .5)
        end

		TrySpawnHoney(inst, hx, hz, level.min_scale, level.max_scale, level.duration)
    end
end
local function StartHoney(inst)
    if inst.beequeen_honeytask == nil then
        inst.beequeen_honeythreshold = HONEY_LEVELS[1].threshold
        inst.beequeen_honeycount = math.ceil(inst.beequeen_honeythreshold * .5)
        inst.beequeen_honeytask = inst:DoPeriodicTask(HONEY_PERIOD, DoHoneyTrail, 0)
    end
end

local function StopHoney(inst)
    if inst.beequeen_honeytask ~= nil then
        inst.beequeen_honeytask:Cancel()
        inst.beequeen_honeytask = nil
    end
end

local function beequeen_OnAttacked(inst, data)
    if data.attacker ~= nil then
        inst.components.grouptargeter:AddTarget(data.attacker)
        inst.components.commander:ShareTargetToAllSoldiers(data.attacker)
    end
end

local function beequeen_OnAttackOther(inst, data)
    if data.target ~= nil then
        inst.components.grouptargeter:AddTarget(data.target)
		local x, y, z = data.target.Transform:GetWorldPosition()
		TrySpawnHoney(inst, x, z, 1, 1.3, 4)
    end
end

local function beequeen_OnMissOther(inst)
    local x, y, z = inst.Transform:GetWorldPosition()
    local angle = -inst.Transform:GetRotation() * DEGREES
	x = x + TUNING.BEEQUEEN_ATTACK_RANGE * math.cos(angle)
	z = z + TUNING.BEEQUEEN_ATTACK_RANGE * math.sin(angle)
	TrySpawnHoney(inst, x, z, 1, 1.3, 4)
end

---dragonfly
local function dragonfly_OnAttacked(inst, data)
    if data.attacker ~= nil then
        inst.components.grouptargeter:AddTarget(data.attacker)
    end
end

local function dragonfly_OnAttackOther(inst, data)
    if data.target ~= nil then
        inst.components.grouptargeter:AddTarget(data.target)
    end
end

---alterguardian_phase3
local function track_trap(inst, trap)
    local function ontrapremoved()
        inst._traps[trap] = nil
    end
    inst._traps[trap] = true
    inst:ListenForEvent("onremove", ontrapremoved, trap)
end
---stalker_atrium
local function stalker_atrium_OnAttack(inst,data)
    if data.attacker and data.attacker:HasTag("shadow_aligned") then
        if not inst:HasTag("shadowdominance") then
            inst:AddTag("shadowdominance")
        end
    end
end

local FINDMINIONS_MUST_TAGS = { "stalkerminion" }
local FINDMINIONS_CANT_TAGS = { "NOCLICK" }
local MINION_RADIUS = .3
local function FindMinions(inst, proximity)
    local x, y, z = inst.Transform:GetWorldPosition()
    return TheSim:FindEntities(x, y, z, MINION_RADIUS + inst:GetPhysicsRadius(0) + (proximity or .5), FINDMINIONS_MUST_TAGS, FINDMINIONS_CANT_TAGS)
end

local WEREEPIC_BOSS = {
    deerclops = {
        build = "deerclops_build",
        bank = "deerclops",
        scale = 1.65,
        phyrad = 0.5,
        dyshadow = {6,3.5},
        freezable = "deerclops_body",
        hurtsoundoverride = "dontstarve/creatures/deerclops/hurt",
        deathsoundoverride = "dontstarve/creatures/deerclops/death",
        music = "dontstarve/music/music_epicfight_winter",

        oncollide = deerclops_oncollide,

        gogglevision = false,
        health = TUNING.DEERCLOPS_HEALTH*TUNING.EPIC_WORLD.HEALTH,
        damage = TUNING.DEERCLOPS_DAMAGE*TUNING.EPIC_WORLD.DAMAGE,
        range = TUNING.MUTATED_DEERCLOPS_ATTACK_RANGE/2,

        master_postinit = function (inst)
            -- inst:AddTag("epic_immune_electrocute")
            -- inst:AddTag("epic_immune_freeze")
            -- inst:AddTag("epic_immune_sleep")
            -- if inst.components.freezable then
            --     local old_redirectfn = inst.components.freezable.redirectfn
            --     inst.components.freezable:SetRedirectFn(function (inst, coldness, freezetime, nofreeze)
            --         if inst:HasTag("epic_immune_freeze") then
            --             return true
            --         else
            --             if old_redirectfn then
            --                 return old_redirectfn(inst, coldness, freezetime, nofreeze)
            --             end
            --         end
            --     end)
            -- end

            inst.Light:SetIntensity(.6)
            inst.Light:SetRadius(8)
            inst.Light:SetFalloff(3)
            inst.Light:SetColour(1, 0, 0)

            inst.AnimState:Hide("head_neutral")

            inst:ListenForEvent("newstate", YuleOnNewState)
            inst:ListenForEvent("onhitother", Deerclops_OnHitOther)
        end,

        master_human = function (inst)
            inst.Light:SetIntensity(.8)
            inst.Light:SetRadius(.5)
            inst.Light:SetFalloff(.65)
            inst.Light:SetColour(255 / 255, 255 / 255, 236 / 255)
            inst.Light:Enable(false)

            inst:RemoveEventCallback("newstate", YuleOnNewState)
            inst:RemoveEventCallback("onhitother", Deerclops_OnHitOther)
        end,
    },

    bearger = {
        build = "bearger_build",
        bank = "bearger",
        scale = 1,
        phyrad = 1.5,
        dyshadow = {6, 3.5},
        freezable = "bearger_body",
        hurtsoundoverride = "dontstarve_DLC001/creatures/bearger/hurt",
        deathsoundoverride = "dontstarve_DLC001/creatures/bearger/death",
        music = "dontstarve/music/music_epicfight",

        oncollide = bearger_oncollide,

        gogglevision = false,
        health = TUNING.BEARGER_HEALTH*TUNING.EPIC_WORLD.HEALTH,
        damage = TUNING.BEARGER_DAMAGE*TUNING.EPIC_WORLD.DAMAGE,
        range = TUNING.BEARGER_ATTACK_RANGE,

        master_postinit = function (inst)
            inst:AddComponent("groundpounder")
            inst.components.groundpounder:UseRingMode()
            inst.components.groundpounder.destroyer = true
            inst.components.groundpounder.damageRings = 3
            inst.components.groundpounder.destructionRings = 3
            inst.components.groundpounder.platformPushingRings = 3
            inst.components.groundpounder.numRings = 3
            inst.components.groundpounder.radiusStepDistance = 2
            inst.components.groundpounder.ringWidth = 1.5
            if TUNING.EPIC_WORLD.STRUCTURE_PROTECTION==1 then
                table.insert(inst.components.groundpounder.noTags,"structure")
                table.insert(inst.components.groundpounder.noTags,"wall")
            end

            inst.bearger_recentlycharged = {}

            inst:ListenForEvent("onhitother", bearger_OnHitOther)
        end,

        master_human = function (inst)
            inst:RemoveComponent("groundpounder")

            inst:RemoveTag("bearger_run")

            if inst.components.locomotor then
                inst.components.locomotor:RemoveExternalSpeedMultiplier(inst,"bearger_run_speed")
            end

            inst:RemoveEventCallback("onhitother", bearger_OnHitOther)
        end
    },

    moose = {
        build = "mossling_build",
        bank = "mossling",
        scale = 2.5,
        phyrad = 0.8,
        dyshadow = {4.5, 2.3},
        freezable = "mossling_body",
        hurtsoundoverride = "dontstarve_DLC001/creatures/mossling/hurt",
        deathsoundoverride = "dontstarve_DLC001/creatures/mossling/death",
        music = "dontstarve_DLC001/music/music_epicfight_spring",

        oncollide = nil,

        gogglevision = false,
        health = TUNING.MOOSE_HEALTH*TUNING.EPIC_WORLD.HEALTH,
        damage = TUNING.MOOSE_DAMAGE*TUNING.EPIC_WORLD.DAMAGE,
        range = TUNING.MOOSE_ATTACK_RANGE,

        master_postinit = function (inst)
            inst:AddTag("moose")
            inst:AddTag("mossling")
            if inst.components.locomotor then
                inst.components.locomotor:SetExternalSpeedMultiplier(inst,"moose_speed",1.5)
            end
        end,

        master_human = function (inst)
            inst:RemoveTag("moose")
            inst:RemoveTag("mossling")
            if inst.components.locomotor then
                inst.components.locomotor:RemoveExternalSpeedMultiplier(inst,"moose_speed")
            end
        end
    },

    antlion = {
        build = "antlion_build",
        bank = "antlion",
        scale = 1,
        phyrad = 1.5,
        dyshadow = {6,3.5},
        freezable = "body",
        burnable = "body",
        hurtsoundoverride = "dontstarve/creatures/together/antlion/hit",
        deathsoundoverride = "dontstarve/creatures/together/antlion/death",
        music = "dontstarve/music/music_epicfight_antlion",

        oncollide = nil,

        gogglevision = true,
        health = TUNING.ANTLION_HEALTH*TUNING.EPIC_WORLD.HEALTH,
        damage = 100*TUNING.EPIC_WORLD.DAMAGE,
        range = TUNING.ANTLION_CAST_RANGE,

        master_postinit = function (inst)
            inst.AnimState:OverrideSymbol("sand_splash", "sand_splash_fx", "sand_splash")

            inst:AddTag("epic_map_teleport")
            inst:AddTag("antlion_sinkhole_blocker")

            if inst.components.locomotor then
                inst.components.locomotor:SetExternalSpeedMultiplier(inst,"antlion_speed",0)
            end
        end,

        master_human = function (inst)
            inst.AnimState:ClearOverrideSymbol("sand_splash")

            inst:RemoveTag("epic_map_teleport")
            inst:RemoveTag("antlion_sinkhole_blocker")

            if inst.components.locomotor then
                inst.components.locomotor:RemoveExternalSpeedMultiplier(inst,"antlion_speed")
            end
        end
    },

    malbatross = {
        build = "malbatross_build",
        bank = "malbatross",
        scale = 1.3,
        phyrad = 1.5,
        dyshadow = {6,2},
        freezable = "body",
        burnable = "body",
        hurtsoundoverride = "saltydog/creatures/boss/malbatross/hit",
        deathsoundoverride = "saltydog/creatures/boss/malbatross/death",
        music = "saltydog/music/malbatross",

        oncollide = nil,

        gogglevision = false,
        health = TUNING.MALBATROSS_HEALTH*TUNING.EPIC_WORLD.HEALTH,
        damage = TUNING.MALBATROSS_DAMAGE*TUNING.EPIC_WORLD.DAMAGE,
        range = TUNING.MALBATROSS_ATTACK_RANGE,

        master_postinit = function (inst)
            inst.Transform:SetSixFaced()

            local phys = inst.Physics
            if phys then
                phys:SetCollisionGroup(COLLISION.FLYERS)
                phys:ClearCollidesWith(COLLISION.WORLD)
                phys:CollidesWith(COLLISION.GROUND)
            end

            inst:AddTag("flying")
            inst:AddTag("epic_map_teleport")
            inst:AddTag("vigorbuff")

            inst.components.locomotor:EnableGroundSpeedMultiplier(false)

            inst.malbatross_recentlycharged = {}
        end,

        master_human = function (inst)
            inst.Transform:SetFourFaced()

            inst:RemoveTag("flying")
            inst:RemoveTag("epic_map_teleport")
            inst:RemoveTag("vigorbuff")

            inst.components.locomotor:EnableGroundSpeedMultiplier(true)
        end
    },

    beequeen = {
        build = "bee_queen_build",
        bank = "bee_queen",
        scale = 1.4,
        phyrad = 1.4,
        dyshadow = {4,2},
        freezable = "hive_body",
        burnable = "swap_fire",
        hurtsoundoverride = "dontstarve/creatures/together/bee_queen/hit",
        deathsoundoverride = "dontstarve/creatures/together/bee_queen/taunt",
        music = "dontstarve/music/music_epicfight_4",

        oncollide = nil,

        gogglevision = false,
        health = TUNING.BEEQUEEN_HEALTH*TUNING.EPIC_WORLD.HEALTH,
        damage = TUNING.BEEQUEEN_DAMAGE*TUNING.EPIC_WORLD.DAMAGE,
        range = TUNING.BEEQUEEN_HIT_RANGE,

        master_postinit = function (inst)
            inst.Transform:SetSixFaced()

            inst.SoundEmitter:PlaySound("dontstarve/creatures/together/bee_queen/wings_LP", "beequeen_flying")

            local phys = inst.Physics
            if phys then
                phys:SetCollisionGroup(COLLISION.FLYERS)
                phys:ClearCollidesWith(COLLISION.WORLD)
                phys:CollidesWith(COLLISION.GROUND)
            end

            inst:AddTag("flying")
            inst:AddTag("vigorbuff")
            inst:AddTag("beequeen")

            inst:AddComponent("grouptargeter")
            if inst.components.commander == nil then
                inst:AddComponent("commander")
            end
            inst.components.commander:SetTrackingDistance(80)

            inst:AddComponent("epicscare")
            inst.components.epicscare:SetRange(TUNING.BEEQUEEN_EPICSCARE_RANGE)

            inst.components.locomotor:EnableGroundSpeedMultiplier(false)

            inst.beequeen_honeytask = nil
            inst.beequeen_honeycount = 0
            inst.beequeen_honeythreshold = 0
            inst.beequeen_usedhoney = {}
            inst.beequeen_availablehoney = {}
            for i = 1, MAX_HONEY_VARIATIONS do
                table.insert(inst.beequeen_availablehoney, i)
            end
            inst.spawnguards_chain = 0

            StartHoney(inst)

            inst:ListenForEvent("attacked", beequeen_OnAttacked)
            inst:ListenForEvent("onattackother", beequeen_OnAttackOther)
            inst:ListenForEvent("onmissother", beequeen_OnMissOther)
        end,

        master_human = function (inst)
            inst.Transform:SetFourFaced()

            inst.SoundEmitter:KillSound("beequeen_flying")

            inst:RemoveTag("flying")
            inst:RemoveTag("vigorbuff")
            inst:RemoveTag("beequeen")

            inst:RemoveComponent("grouptargeter")
            inst:RemoveComponent("epicscare")

            inst.components.locomotor:EnableGroundSpeedMultiplier(true)

            StopHoney(inst)

            inst:RemoveEventCallback("attacked",beequeen_OnAttacked)
            inst:RemoveEventCallback("onattackother",beequeen_OnAttackOther)
            inst:RemoveEventCallback("onmissother",beequeen_OnMissOther)
        end
    },

    dragonfly = {
        build = "dragonfly_build",
        bank = "dragonfly",
        scale = 1.3,
        phyrad = 1.4,
        dyshadow = {6,3.5},
        freezable = nil,
        freezable_resistance = TUNING.DRAGONFLY_FREEZE_THRESHOLD,
        burnable = nil,
        burnable_damage = 0,
        hurtsoundoverride = "dontstarve_DLC001/creatures/dragonfly/hurt",
        deathsoundoverride = "dontstarve_DLC001/creatures/dragonfly/death",
        music = "dontstarve/music/music_epicfight_3",

        oncollide = nil,

        gogglevision = false,
        health = TUNING.DRAGONFLY_HEALTH*TUNING.EPIC_WORLD.HEALTH,
        damage = TUNING.DRAGONFLY_DAMAGE*TUNING.EPIC_WORLD.DAMAGE,
        range = TUNING.DRAGONFLY_HIT_RANGE,

        master_postinit = function (inst)
            inst.Transform:SetSixFaced()

            inst.SoundEmitter:PlaySound("dontstarve_DLC001/creatures/dragonfly/fly", "dragonfly_flying")

            local phys = inst.Physics
            if phys then
                phys:SetCollisionGroup(COLLISION.FLYERS)
                phys:ClearCollidesWith(COLLISION.WORLD)
                phys:CollidesWith(COLLISION.GROUND)
            end

            inst.Light:Enable(false)
            inst.Light:SetRadius(2)
            inst.Light:SetFalloff(0.5)
            inst.Light:SetIntensity(0.75)
            inst.Light:SetColour(235/255, 121/255, 12/255)

            inst:AddTag("flying")
            inst:AddTag("vigorbuff")

            inst.components.locomotor:EnableGroundSpeedMultiplier(false)

            inst:AddComponent("grouptargeter")
            local groundpounder = inst:AddComponent("groundpounder")
            groundpounder:UseRingMode()
            groundpounder.numRings = 3
            groundpounder.initialRadius = 1.5
            groundpounder.radiusStepDistance = 2
            groundpounder.ringWidth = 2
            groundpounder.damageRings = 2
            groundpounder.destructionRings = 3
            groundpounder.platformPushingRings = 3
            groundpounder.fxRings = 2
            groundpounder.fxRadiusOffset = 1.5
            groundpounder.burner = true
            groundpounder.groundpoundfx = "firesplash_fx"
            groundpounder.groundpounddamagemult = 0.5
            groundpounder.groundpoundringfx = "firering_fx"
            if TUNING.EPIC_WORLD.STRUCTURE_PROTECTION==1 then
                table.insert(groundpounder.noTags,"structure")
                table.insert(groundpounder.noTags,"wall")
            end

            inst:ListenForEvent("attacked", dragonfly_OnAttacked)
            inst:ListenForEvent("onattackother", dragonfly_OnAttackOther)
        end,

        master_human = function (inst)
            inst.Transform:SetFourFaced()

            inst.SoundEmitter:KillSound("dragonfly_flying")

            inst.Light:SetIntensity(.8)
            inst.Light:SetRadius(.5)
            inst.Light:SetFalloff(.65)
            inst.Light:SetColour(255 / 255, 255 / 255, 236 / 255)
            inst.Light:Enable(false)

            inst:RemoveTag("flying")
            inst:RemoveTag("vigorbuff")

            inst.components.locomotor:EnableGroundSpeedMultiplier(true)
            inst:RemoveComponent("grouptargeter")
            inst:RemoveComponent("groundpounder")

            if inst.components.health then
                inst.components.health.fire_damage_scale = 1
            end

            if inst.components.debuffable and inst.components.debuffable:HasDebuff("dragonfly_enraged") then
                inst.components.debuffable:RemoveDebuff("dragonfly_enraged")
            end

            inst.SoundEmitter:KillSound("fireflying")
            inst:RemoveTag("dragonfly_enraged")
            inst.components.locomotor:RemoveExternalSpeedMultiplier(inst,"dragonfly_enraged_speed")
            inst.components.propagator:StopSpreading()

            inst:RemoveEventCallback("attacked", dragonfly_OnAttacked)
            inst:RemoveEventCallback("onattackother", dragonfly_OnAttackOther)
        end
    },

    daywalker = {
        build = "daywalker_build",
        bank = "daywalker",
        scale = 1,
        phyrad = 1.3,
        dyshadow = {3.5,1.5},
        freezable = nil,
        burnable = nil,
        burnable_damage = 0,
        hurtsoundoverride = "daywalker/voice/hurt",
        deathsoundoverride = "daywalker/voice/hurt",
        music = "dontstarve/music/music_epicfight_daywalker",

        oncollide = nil,

        gogglevision = false,
        health = TUNING.DAYWALKER_HEALTH*TUNING.EPIC_WORLD.HEALTH,
        damage = TUNING.DAYWALKER_DAMAGE*TUNING.EPIC_WORLD.DAMAGE,
        range = TUNING.DAYWALKER_ATTACK_RANGE,

        master_postinit = function (inst)
            inst:AddTag("epic_immune_freeze")
            inst:AddTag("epic_immune_sleep")
            inst:AddTag("fireimmune")
            if inst.components.freezable then
                local old_redirectfn = inst.components.freezable.redirectfn
                inst.components.freezable:SetRedirectFn(function (inst, coldness, freezetime, nofreeze)
                    if inst:HasTag("epic_immune_freeze") then
                        return true
                    else
                        if old_redirectfn then
                            return old_redirectfn(inst, coldness, freezetime, nofreeze)
                        end
                    end
                end)
            end

            inst:AddComponent("epicscare")
	        inst.components.epicscare:SetRange(TUNING.DAYWALKER_EPICSCARE_RANGE)

            if inst.components.grogginess then
                inst.components.grogginess:AddImmunitySource(inst)
            end

            inst.daywalker_head = SpawnPrefab("daywalker_head")
            inst.daywalker_head.entity:SetParent(inst.entity)
            inst.daywalker_head.Follower:FollowSymbol(inst.GUID, "HEAD_follow", nil, nil, nil, true, true)

            inst.daywalker_trampledelays = {}
        end,

        master_human = function (inst)
            inst:RemoveTag("epic_immune_freeze")
            inst:RemoveTag("epic_immune_sleep")
            inst:RemoveTag("fireimmune")
            inst:RemoveTag("daywalker_run")

            inst:RemoveComponent("epicscare")

            if inst.components.grogginess then
                inst.components.grogginess:RemoveImmunitySource(inst)
            end

            if inst.components.locomotor then
                inst.components.locomotor:RemoveExternalSpeedMultiplier(inst,"daywalker_run_speed")
            end

            if inst.daywalker_head then
                inst.daywalker_head:Remove()
                inst.daywalker_head = nil
            end
        end
    },

    daywalker2 = {
        build = "daywalker_build",
        bank = "daywalker",
        scale = 1,
        phyrad = 1.3,
        dyshadow = {3.5,1.5},
        freezable = "ww_body",
        burnable = "ww_cloth",
        hurtsoundoverride = "daywalker/voice/hurt",
        deathsoundoverride = "daywalker/voice/hurt",
        music = "dontstarve/music/music_epicfight_junkyardhog",

        oncollide = nil,

        gogglevision = true,
        health = TUNING.DAYWALKER_HEALTH*TUNING.EPIC_WORLD.HEALTH,
        damage = TUNING.DAYWALKER_DAMAGE*TUNING.EPIC_WORLD.DAMAGE,
        range = TUNING.DAYWALKER_ATTACK_RANGE,

        master_postinit = function (inst)
            inst.AnimState:HideSymbol("ww_armlower_red")
            inst.AnimState:OverrideSymbol("ww_armlower_base", "daywalker_build", "ww_armlower_base_nored")
            inst.AnimState:OverrideSymbol("ww_eye_R", "daywalker_build", "ww_eye_R_scar")
            inst.AnimState:SetSymbolSaturation("fx_smear", 0)
            inst.AnimState:OverrideSymbol("scrap_debris", "scrapball", "scrap_debris")
            inst.AnimState:AddOverrideBuild("daywalker_phase3")
            inst.AnimState:Show("ARM_CARRY")
            inst.AnimState:Hide("ARM_NORMAL")

            inst:AddComponent("epicscare")
	        inst.components.epicscare:SetRange(TUNING.DAYWALKER_EPICSCARE_RANGE)

            if inst.components.combat then
                inst.components.combat.externaldamagetakenmultipliers:SetModifier(inst, TUNING.DAYWALKER2_DAMAGE_TAKEN_MULT, "daywalker2_junkarmor")
            end

            local daywalker2_head = SpawnPrefab("daywalker_head")
            daywalker2_head.entity:SetParent(inst.entity)
            daywalker2_head.Follower:FollowSymbol(inst.GUID, "HEAD_follow", nil, nil, nil, true, true)
            daywalker2_head.AnimState:OverrideSymbol("ww_eye_R", "daywalker_build", "ww_eye_R_scar")
            daywalker2_head.AnimState:OverrideSymbol("swap_eye_R", "daywalker_phase3", "swap_eye_R")
            if daywalker2_head.eye then
                daywalker2_head.eye:Remove()
                daywalker2_head.eye = nil
            end
            inst.daywalker2_head = daywalker2_head

            inst.daywalker_trampledelays = {}
        end,

        master_human = function (inst)
            inst.AnimState:ClearOverrideSymbol("ww_armlower_base")
            inst.AnimState:ClearOverrideSymbol("ww_eye_R")
            inst.AnimState:ClearOverrideSymbol("scrap_debris")
            inst.AnimState:ClearOverrideBuild("daywalker_phase3")
            inst.AnimState:Hide("ARM_CARRY")
            inst.AnimState:Show("ARM_NORMAL")

            inst:RemoveTag("daywalker_run")

            inst:RemoveComponent("epicscare")

            if inst.components.combat then
                inst.components.combat.externaldamagetakenmultipliers:RemoveModifier(inst, "daywalker2_junkarmor")
            end

            if inst.components.locomotor then
                inst.components.locomotor:RemoveExternalSpeedMultiplier(inst,"daywalker_run_speed")
            end

            if inst.daywalker2_head then
                inst.daywalker2_head:Remove()
                inst.daywalker2_head = nil
            end
        end
    },

    alterguardian_phase1 = {
        build = "alterguardian_phase1",
        bank = "alterguardian_phase1",
        scale = 1,
        phyrad = 1.25,
        dyshadow = {5,1.5},
        freezable = nil,
        burnable = nil,
        burnable_damage = 0,
        hurtsoundoverride = "moonstorm/creatures/boss/alterguardian1/hit",
        deathsoundoverride = "moonstorm/creatures/boss/alterguardian1/death",
        music = "moonstorm/creatures/boss/alterguardian1/music_epicfight",

        oncollide = nil,
        enablelunacy = true,

        gogglevision = true,
        health = TUNING.ALTERGUARDIAN_PHASE1_HEALTH*TUNING.EPIC_WORLD.HEALTH,
        damage = TUNING.ALTERGUARDIAN_PHASE1_ROLLDAMAGE*TUNING.EPIC_WORLD.DAMAGE,
        range = TUNING.ALTERGUARDIAN_PHASE1_AOERANGE,

        master_postinit = function (inst)
            inst:AddTag("epic_immune_freeze")
            inst:AddTag("epic_immune_sleep")
            inst:AddTag("epic_immune_electrocute")
            inst:AddTag("fireimmune")
            inst:AddTag("epic_lunar")
            if inst.components.freezable then
                local old_redirectfn = inst.components.freezable.redirectfn
                inst.components.freezable:SetRedirectFn(function (inst, coldness, freezetime, nofreeze)
                    if inst:HasTag("epic_immune_freeze") then
                        return true
                    else
                        if old_redirectfn then
                            return old_redirectfn(inst, coldness, freezetime, nofreeze)
                        end
                    end
                end)
            end

            if inst.components.sanity then
                inst.components.sanity:EnableLunacy(true, "epic_enablelunacy")
            end

            if inst.components.grogginess then
                inst.components.grogginess:AddImmunitySource(inst)
            end

            inst.SoundEmitter:PlaySound("moonstorm/creatures/boss/alterguardian1/idle_LP", "idle_LP")
        end,

        master_human = function (inst)
            inst:RemoveTag("epic_immune_electrocute")
            inst:RemoveTag("epic_immune_sleep")
            inst:RemoveTag("epic_immune_freeze")
            inst:RemoveTag("fireimmune")
            inst:RemoveTag("epic_lunar")

            if inst.components.sanity then
                inst.components.sanity:EnableLunacy(false, "epic_enablelunacy")
            end

            if inst.components.grogginess then
                inst.components.grogginess:RemoveImmunitySource(inst)
            end

            inst.SoundEmitter:KillSound("idle_LP")
        end
    },

    alterguardian_phase2 = {
        build = "alterguardian_phase2",
        bank = "alterguardian_phase2",
        scale = 1,
        phyrad = 2,
        dyshadow = {5.5,2},
        freezable = nil,
        burnable = nil,
        burnable_damage = 0,
        hurtsoundoverride = "moonstorm/creatures/boss/alterguardian1/onothercollide",
        deathsoundoverride = "moonstorm/creatures/boss/alterguardian2/death",
        music = "moonstorm/creatures/boss/alterguardian2/music_epicfight",

        oncollide = nil,
        enablelunacy = true,

        gogglevision = true,
        health = TUNING.ALTERGUARDIAN_PHASE2_STARTHEALTH*TUNING.EPIC_WORLD.HEALTH,
        damage = TUNING.ALTERGUARDIAN_PHASE2_DAMAGE*TUNING.EPIC_WORLD.DAMAGE,
        range = TUNING.ALTERGUARDIAN_PHASE2_CHOP_RANGE,

        master_postinit = function (inst)
            inst.Transform:SetSixFaced()

            inst.Light:SetIntensity(0)
            inst.Light:SetRadius(0)
            inst.Light:SetFalloff(0)
            inst.Light:SetColour(0.01, 0.35, 1)
            inst.Light:Enable(true)

            inst:AddTag("epic_immune_freeze")
            inst:AddTag("epic_immune_sleep")
            inst:AddTag("epic_immune_electrocute")
            inst:AddTag("fireimmune")
            inst:AddTag("epic_lunar")
            if inst.components.freezable then
                local old_redirectfn = inst.components.freezable.redirectfn
                inst.components.freezable:SetRedirectFn(function (inst, coldness, freezetime, nofreeze)
                    if inst:HasTag("epic_immune_freeze") then
                        return true
                    else
                        if old_redirectfn then
                            return old_redirectfn(inst, coldness, freezetime, nofreeze)
                        end
                    end
                end)
            end

            if inst.components.sanity then
                inst.components.sanity:EnableLunacy(true, "epic_enablelunacy")
            end

            if inst.components.grogginess then
                inst.components.grogginess:AddImmunitySource(inst)
            end

            inst.SoundEmitter:PlaySound("moonstorm/creatures/boss/alterguardian2/idle_LP","idle_LP")
        end,

        master_human = function (inst)
            inst.Transform:SetFourFaced()

            inst.Light:SetIntensity(.8)
            inst.Light:SetRadius(.5)
            inst.Light:SetFalloff(.65)
            inst.Light:SetColour(255 / 255, 255 / 255, 236 / 255)
            inst.Light:Enable(false)

            inst:RemoveTag("epic_immune_electrocute")
            inst:RemoveTag("epic_immune_sleep")
            inst:RemoveTag("epic_immune_freeze")
            inst:RemoveTag("fireimmune")
            inst:RemoveTag("epic_lunar")

            if inst.components.sanity then
                inst.components.sanity:EnableLunacy(false, "epic_enablelunacy")
            end

            if inst.components.grogginess then
                inst.components.grogginess:RemoveImmunitySource(inst)
            end

            inst.SoundEmitter:KillSound("idle_LP")
        end
    },

    alterguardian_phase3 = {
        build = "alterguardian_phase3",
        bank = "alterguardian_phase3",
        scale = 1,
        phyrad = 0,
        dyshadow = {3,1},
        freezable = nil,
        burnable = nil,
        burnable_damage = 0,
        hurtsoundoverride = "moonstorm/creatures/boss/alterguardian1/onothercollide",
        deathsoundoverride = "moonstorm/creatures/boss/alterguardian3/death",
        music = "moonstorm/creatures/boss/alterguardian3/music_epicfight",

        oncollide = nil,
        enablelunacy = true,

        gogglevision = true,
        health = TUNING.ALTERGUARDIAN_PHASE3_STARTHEALTH*TUNING.EPIC_WORLD.HEALTH,
        damage = TUNING.ALTERGUARDIAN_PHASE3_DAMAGE*TUNING.EPIC_WORLD.DAMAGE,
        range = TUNING.ALTERGUARDIAN_PHASE3_STAB_HITRANGE,

        master_postinit = function (inst)
            inst.Transform:SetSixFaced()

            inst.Light:SetIntensity(0)
            inst.Light:SetRadius(0)
            inst.Light:SetFalloff(0)
            inst.Light:SetColour(0.01, 0.35, 1)
            inst.Light:Enable(true)

            inst:AddTag("epic_immune_freeze")
            inst:AddTag("epic_immune_sleep")
            inst:AddTag("epic_immune_electrocute")
            inst:AddTag("fireimmune")
            inst:AddTag("epic_lunar")

            inst:AddTag("flying")
            inst:AddTag("vigorbuff")
            local phys = inst.Physics
            if phys then
                phys:SetCollisionGroup(COLLISION.FLYERS)
                phys:ClearCollidesWith(COLLISION.WORLD)
                phys:CollidesWith(COLLISION.GROUND)
            end

            inst.components.locomotor:EnableGroundSpeedMultiplier(false)

            if inst.components.freezable then
                local old_redirectfn = inst.components.freezable.redirectfn
                inst.components.freezable:SetRedirectFn(function (inst, coldness, freezetime, nofreeze)
                    if inst:HasTag("epic_immune_freeze") then
                        return true
                    else
                        if old_redirectfn then
                            return old_redirectfn(inst, coldness, freezetime, nofreeze)
                        end
                    end
                end)
            end

            if inst.components.sanity then
                inst.components.sanity:EnableLunacy(true, "epic_enablelunacy")
            end

            if inst.components.grogginess then
                inst.components.grogginess:AddImmunitySource(inst)
            end


            inst.SoundEmitter:PlaySound("moonstorm/creatures/boss/alterguardian3/idle_LP","idle_LP")

            inst._traps = {}
            inst.TrackTrap = track_trap

            local x, y, z = inst.Transform:GetWorldPosition()
            SpawnPrefab("moonpulse_spawner").Transform:SetPosition(x, y, z)
            TheWorld:PushEvent("ms_setclocksegs", {day = 0, dusk = 0, night = 16})
            TheWorld:PushEvent("ms_setmoonphase", {moonphase = "full", iswaxing = false})
            TheWorld:PushEvent("ms_setmoonphasestyle", {style = "alter_active"})
            TheWorld:PushEvent("ms_lockmoonphase", {lock = true})
        end,

        master_human = function (inst)
            inst.Transform:SetFourFaced()

            inst.Light:SetIntensity(.8)
            inst.Light:SetRadius(.5)
            inst.Light:SetFalloff(.65)
            inst.Light:SetColour(255 / 255, 255 / 255, 236 / 255)
            inst.Light:Enable(false)

            inst:RemoveTag("epic_immune_electrocute")
            inst:RemoveTag("epic_immune_sleep")
            inst:RemoveTag("epic_immune_freeze")
            inst:RemoveTag("fireimmune")
            inst:RemoveTag("epic_lunar")
            inst:RemoveTag("flying")
            inst:RemoveTag("vigorbuff")

            inst.components.locomotor:EnableGroundSpeedMultiplier(true)

            if inst.components.sanity then
                inst.components.sanity:EnableLunacy(false, "epic_enablelunacy")
            end

            if inst.components.grogginess then
                inst.components.grogginess:RemoveImmunitySource(inst)
            end

            inst.SoundEmitter:KillSound("idle_LP")

            inst.TrackTrap = nil

            local moonstorms = TheWorld.net.components.moonstorms
            local is_active = moonstorms ~= nil and next(moonstorms:GetMoonstormNodes()) ~= nil
            if not is_active then
                TheWorld:PushEvent("ms_setmoonphase", {moonphase = "new", iswaxing = true})
                TheWorld:PushEvent("ms_setmoonphasestyle", {style = "glassed_default"})
                TheWorld:PushEvent("ms_lockmoonphase", {lock = false})
            end
        end
    },

    stalker_atrium = {
        build = "stalker_shadow_build",
        bank = "stalker",
        scale = 1,
        phyrad = .75,
        dyshadow = {4,2},
        freezable = nil,
        burnable = nil,
        burnable_damage = 0,
        hurtsoundoverride = "dontstarve/creatures/together/stalker/hit",
        deathsoundoverride = "dontstarve/creatures/together/stalker/death3/swell",
        music = "dontstarve/music/music_epicfight_stalker_b",

        oncollide = bearger_oncollide,

        gogglevision = true,
        health = TUNING.STALKER_ATRIUM_HEALTH*TUNING.EPIC_WORLD.HEALTH,
        damage = TUNING.STALKER_DAMAGE*TUNING.EPIC_WORLD.DAMAGE,
        range = TUNING.STALKER_HIT_RANGE,

        master_postinit = function (inst)
            inst.AnimState:AddOverrideBuild("stalker_atrium_build")
            inst:AddTag("shadowdominance")
            inst:AddTag("epic_immune_freeze")
            inst:AddTag("epic_immune_sleep")
            inst:AddTag("epic_immune_electrocute")
            inst:AddTag("fireimmune")
            if inst.components.freezable then
                local old_redirectfn = inst.components.freezable.redirectfn
                inst.components.freezable:SetRedirectFn(function (inst, coldness, freezetime, nofreeze)
                    if inst:HasTag("epic_immune_freeze") then
                        return true
                    else
                        if old_redirectfn then
                            return old_redirectfn(inst, coldness, freezetime, nofreeze)
                        end
                    end
                end)
            end

            if inst.components.grogginess then
                inst.components.grogginess:AddImmunitySource(inst)
            end
            if inst.components.combat then
                inst.components.combat:SetAreaDamage(TUNING.STALKER_AOE_RANGE, TUNING.STALKER_AOE_SCALE)
            end
            if inst.components.commander == nil then
                inst:AddComponent("commander")
            end
            inst:AddComponent("epicscare")
            inst.components.epicscare:SetRange(TUNING.STALKER_EPICSCARE_RANGE)

            inst.bearger_recentlycharged = {}
            inst.stalker_atrium_should_eat = inst:DoPeriodicTask(0.5,function()
                if #FindMinions(inst) > 0 and inst.components.health:IsHurt() then
                    inst:PushEvent("stalker_atrium_fossilfeast")
                end
            end)

            inst:ListenForEvent("attacked",stalker_atrium_OnAttack)
        end,

        master_human = function (inst)
            inst.AnimState:ClearOverrideBuild("stalker_atrium_build")
            inst:RemoveTag("shadowdominance")
            inst:RemoveTag("epic_immune_electrocute")
            inst:RemoveTag("epic_immune_sleep")
            inst:RemoveTag("epic_immune_freeze")
            inst:RemoveTag("fireimmune")

            inst:RemoveComponent("epicscare")

            if inst.components.grogginess then
                inst.components.grogginess:RemoveImmunitySource(inst)
            end
            if inst.components.combat then
                inst.components.combat:SetAreaDamage()
            end

            if inst.stalker_atrium_should_eat then
                inst.stalker_atrium_should_eat:Cancel()
                inst.stalker_atrium_should_eat = nil
            end

            inst:RemoveEventCallback("attacked",stalker_atrium_OnAttack)
        end
    },

    mutatedwarg = {
        build = "warg_mutated_actions",
        bank = "warg",
        scale = 1,
        phyrad = 1,
        dyshadow = {2.5,1.5},
        freezable = nil,
        burnable = "swap_fire",
        hurtsoundoverride = "dontstarve_DLC001/creatures/vargr/hit",
        deathsoundoverride = "rifts3/mutated_varg/death",
        music = "dontstarve/music/music_epicfight_gestalt_mutants",

        oncollide = nil,
        enablelunacy = true,

        gogglevision = true,
        health = TUNING.MUTATED_WARG_HEALTH*TUNING.EPIC_WORLD.HEALTH,
        damage = TUNING.WARG_DAMAGE*TUNING.EPIC_WORLD.DAMAGE,
        range = TUNING.WARG_ATTACKRANGE,

        master_postinit = function (inst)
            inst.Transform:SetSixFaced()

            inst.AnimState:SetSymbolBloom("breath_02")
			inst.AnimState:SetSymbolBrightness("breath_02", 1.5)

            inst:AddTag("epic_immune_sleep")
            inst:AddTag("epic_lunar")

            inst:AddComponent("planarentity")
            if inst.components.grogginess then
                inst.components.grogginess:AddImmunitySource(inst)
            end

            if inst.components.planardamage then
                inst.components.planardamage:SetBaseDamage(TUNING.MUTATED_WARG_PLANAR_DAMAGE)
            end

            if inst.components.sanity then
                inst.components.sanity:EnableLunacy(true, "epic_enablelunacy")
            end

            inst.mutatedwarg_gestalt = SpawnPrefab("epic_mutatedwarg_gestaltflame_fx")
			inst.mutatedwarg_gestalt.entity:SetParent(inst.entity)
			inst.mutatedwarg_gestalt.Follower:FollowSymbol(inst.GUID, "swap_gestalt_flame", 0, 0, 0, true)
		    local frames = inst.mutatedwarg_gestalt.AnimState:GetCurrentAnimationNumFrames()
			local rnd = math.random(frames) - 1
			inst.mutatedwarg_gestalt.AnimState:SetFrame(rnd)

			inst.mutatedwarg_eyeL = SpawnPrefab("epic_mutatedwarg_eyeflame_fx")
			inst.mutatedwarg_eyeL.entity:SetParent(inst.entity)
			inst.mutatedwarg_eyeL.Follower:FollowSymbol(inst.GUID, "flameL", 0, 0, 0, true)
			frames = inst.mutatedwarg_eyeL.AnimState:GetCurrentAnimationNumFrames()
			rnd = math.random(frames) - 1
			inst.mutatedwarg_eyeL.AnimState:SetFrame(rnd)

			inst.mutatedwarg_eyeR = SpawnPrefab("epic_mutatedwarg_eyeflame_fx")
			inst.mutatedwarg_eyeR.entity:SetParent(inst.entity)
			inst.mutatedwarg_eyeR.Follower:FollowSymbol(inst.GUID, "flameR", 0, 0, 0, true)
			rnd = (rnd + math.floor((0.35 + math.random() * 0.35) * frames)) % frames
			inst.mutatedwarg_eyeR.AnimState:SetFrame(rnd)

			inst.mutatedwarg_mouthL = SpawnPrefab("epic_mutatedwarg_mouthflame_fx")
			inst.mutatedwarg_mouthL.entity:SetParent(inst.entity)
			inst.mutatedwarg_mouthL.Follower:FollowSymbol(inst.GUID, "mouthflameL", 0, 0, 0, true)
			frames = inst.mutatedwarg_mouthL.AnimState:GetCurrentAnimationNumFrames()
			rnd = math.random(frames) - 1
			inst.mutatedwarg_mouthL.AnimState:SetFrame(rnd)

			inst.mutatedwarg_mouthR = SpawnPrefab("epic_mutatedwarg_mouthflame_fx")
			inst.mutatedwarg_mouthR.entity:SetParent(inst.entity)
			inst.mutatedwarg_mouthR.Follower:FollowSymbol(inst.GUID, "mouthflameR", 0, 0, 0, true)
			rnd = (rnd + math.floor((0.35 + math.random() * 0.35) * frames)) % frames
			inst.mutatedwarg_mouthR.AnimState:SetFrame(rnd)

        end,

        master_human = function (inst)
            inst.Transform:SetFourFaced()

            inst:RemoveTag("epic_immune_sleep")
            inst:RemoveTag("epic_lunar")

            inst:RemoveComponent("planarentity")
            if inst.components.grogginess then
                inst.components.grogginess:RemoveImmunitySource(inst)
            end

            if inst.components.planardamage then
                inst.components.planardamage:SetBaseDamage(0)
            end

            if inst.components.sanity then
                inst.components.sanity:EnableLunacy(false, "epic_enablelunacy")
            end

            if inst.mutatedwarg_gestalt then
                inst.mutatedwarg_gestalt:Remove()
                inst.mutatedwarg_gestalt = nil
            end
            if inst.mutatedwarg_eyeL then
                inst.mutatedwarg_eyeL:Remove()
                inst.mutatedwarg_eyeL = nil
            end
            if inst.mutatedwarg_eyeR then
                inst.mutatedwarg_eyeR:Remove()
                inst.mutatedwarg_eyeR = nil
            end
            if inst.mutatedwarg_mouthL then
                inst.mutatedwarg_mouthL:Remove()
                inst.mutatedwarg_mouthL = nil
            end
            if inst.mutatedwarg_mouthR then
                inst.mutatedwarg_mouthR:Remove()
                inst.mutatedwarg_mouthR = nil
            end
        end
    },

    mutatedbearger = {
        build = "bearger_mutated",
        bank = "bearger",
        scale = 1,
        phyrad = 1.5,
        dyshadow = {6, 3.5},
        freezable = "bearger_body",
        hurtsoundoverride = "rifts3/mutated_bearger/hurt",
        deathsoundoverride = "dontstarve_DLC001/creatures/bearger/death",
        music = "dontstarve/music/music_epicfight_gestalt_mutants",

        oncollide = bearger_oncollide,
        enablelunacy = true,

        gogglevision = true,
        health = TUNING.MUTATED_BEARGER_HEALTH*TUNING.EPIC_WORLD.HEALTH,
        damage = TUNING.MUTATED_BEARGER_DAMAGE*TUNING.EPIC_WORLD.DAMAGE,
        range = TUNING.MUTATED_BEARGER_ATTACK_RANGE,

        master_postinit = function (inst)
            inst:AddTag("epic_immune_sleep")
            inst:AddTag("epic_lunar")

            inst:AddComponent("planarentity")
            if inst.components.grogginess then
                inst.components.grogginess:AddImmunitySource(inst)
            end

            if inst.components.planardamage then
                inst.components.planardamage:SetBaseDamage(TUNING.MUTATED_BEARGER_PLANAR_DAMAGE)
            end

            if inst.components.sanity then
                inst.components.sanity:EnableLunacy(true, "epic_enablelunacy")
            end

            inst:AddComponent("groundpounder")
            inst.components.groundpounder:UseRingMode()
            inst.components.groundpounder.destroyer = true
            inst.components.groundpounder.damageRings = 3
            inst.components.groundpounder.destructionRings = 3
            inst.components.groundpounder.platformPushingRings = 3
            inst.components.groundpounder.numRings = 3
            inst.components.groundpounder.radiusStepDistance = 2
            inst.components.groundpounder.ringWidth = 1.5
            if TUNING.EPIC_WORLD.STRUCTURE_PROTECTION==1 then
                table.insert(inst.components.groundpounder.noTags,"structure")
                table.insert(inst.components.groundpounder.noTags,"wall")
            end

            inst.bearger_recentlycharged = {}

            inst:ListenForEvent("onhitother", bearger_OnHitOther)

            inst.mutatedbearger_gestalt = SpawnPrefab("epic_mutatedbearger_gestaltflame_fx")
            inst.mutatedbearger_gestalt.entity:SetParent(inst.entity)
            inst.mutatedbearger_gestalt.Follower:FollowSymbol(inst.GUID, "swap_gestalt_flame", 0, 0, 0, true)
            local frames = inst.mutatedbearger_gestalt.AnimState:GetCurrentAnimationNumFrames()
            local rnd = math.random(frames) - 1
            inst.mutatedbearger_gestalt.AnimState:SetFrame(rnd)

            inst.mutatedbearger_eyeL = SpawnPrefab("epic_mutatedbearger_eyeflame_fx")
            inst.mutatedbearger_eyeL.entity:SetParent(inst.entity)
            inst.mutatedbearger_eyeL.Follower:FollowSymbol(inst.GUID, "flameL", 0, 0, 0, true)
            frames = inst.mutatedbearger_eyeL.AnimState:GetCurrentAnimationNumFrames()
            rnd = math.random(frames) - 1
            inst.mutatedbearger_eyeL.AnimState:SetFrame(rnd)

            inst.mutatedbearger_eyeR = SpawnPrefab("epic_mutatedbearger_eyeflame_fx")
            inst.mutatedbearger_eyeR.entity:SetParent(inst.entity)
            inst.mutatedbearger_eyeR.Follower:FollowSymbol(inst.GUID, "flameR", 0, 0, 0, true)
            rnd = (rnd + math.floor((0.35 + math.random() * 0.35) * frames)) % frames
            inst.mutatedbearger_eyeR.AnimState:SetFrame(rnd)
        end,

        master_human = function (inst)
            inst:RemoveTag("bearger_run")
            inst:RemoveTag("epic_immune_sleep")
            inst:RemoveTag("epic_lunar")

            inst:RemoveComponent("planarentity")
            if inst.components.grogginess then
                inst.components.grogginess:RemoveImmunitySource(inst)
            end

            if inst.components.planardamage then
                inst.components.planardamage:SetBaseDamage(0)
            end

            if inst.components.sanity then
                inst.components.sanity:EnableLunacy(false, "epic_enablelunacy")
            end

            inst:RemoveComponent("groundpounder")

            if inst.components.locomotor then
                inst.components.locomotor:RemoveExternalSpeedMultiplier(inst,"bearger_run_speed")
            end

            inst:RemoveEventCallback("onhitother", bearger_OnHitOther)

            if inst.mutatedbearger_gestalt then
                inst.mutatedbearger_gestalt:Remove()
                inst.mutatedbearger_gestalt = nil
            end
            if inst.mutatedbearger_eyeL then
                inst.mutatedbearger_eyeL:Remove()
                inst.mutatedbearger_eyeL = nil
            end
            if inst.mutatedbearger_eyeR then
                inst.mutatedbearger_eyeR:Remove()
                inst.mutatedbearger_eyeR = nil
            end
        end
    },

    mutateddeerclops = {
        build = "deerclops_mutated",
        bank = "deerclops",
        scale = 1.65,
        phyrad = 0.5,
        dyshadow = {6,3.5},
        freezable = "deerclops_body",
        burnable_damage = 0,
        hurtsoundoverride = "dontstarve/creatures/deerclops/hurt",
        deathsoundoverride = "dontstarve/creatures/deerclops/death",
        music = "dontstarve/music/music_epicfight_gestalt_mutants",

        oncollide = deerclops_oncollide,
        enablelunacy = true,

        gogglevision = true,
        health = TUNING.MUTATED_DEERCLOPS_HEALTH*TUNING.EPIC_WORLD.HEALTH,
        damage = TUNING.MUTATED_DEERCLOPS_DAMAGE*TUNING.EPIC_WORLD.DAMAGE,
        range = TUNING.MUTATED_DEERCLOPS_ATTACK_RANGE/2,

        master_postinit = function (inst)
            inst:AddTag("epic_immune_sleep")
            inst:AddTag("epic_lunar")
            inst:AddTag("epic_immune_freeze")
            inst:AddTag("fireimmune")
            if inst.components.freezable then
                local old_redirectfn = inst.components.freezable.redirectfn
                inst.components.freezable:SetRedirectFn(function (inst, coldness, freezetime, nofreeze)
                    if inst:HasTag("epic_immune_freeze") then
                        return true
                    else
                        if old_redirectfn then
                            return old_redirectfn(inst, coldness, freezetime, nofreeze)
                        end
                    end
                end)
            end

            inst:AddComponent("planarentity")
            if inst.components.grogginess then
                inst.components.grogginess:AddImmunitySource(inst)
            end

            if inst.components.planardamage then
                inst.components.planardamage:SetBaseDamage(TUNING.MUTATED_DEERCLOPS_PLANAR_DAMAGE)
            end

            if inst.components.sanity then
                inst.components.sanity:EnableLunacy(true, "epic_enablelunacy")
            end

            inst.AnimState:Hide("head_neutral")

            inst:ListenForEvent("onhitother", Deerclops_OnHitOther)

            inst.AnimState:Hide("gestalt_eye")
            inst.mutateddeerclops_gestalt = SpawnPrefab("epic_mutateddeerclops_gestaltflame_fx")
            inst.mutateddeerclops_gestalt.entity:SetParent(inst.entity)
            inst.mutateddeerclops_gestalt.Follower:FollowSymbol(inst.GUID, "swap_gestalt_flame", 0, 0, 0, true)
            local frames = inst.mutateddeerclops_gestalt.AnimState:GetCurrentAnimationNumFrames()
            local rnd = math.random(frames) - 1
            inst.mutateddeerclops_gestalt.AnimState:SetFrame(rnd)
        end,

        master_human = function (inst)
            inst:RemoveTag("epic_immune_sleep")
            inst:RemoveTag("epic_lunar")
            inst:RemoveTag("epic_immune_freeze")
            inst:RemoveTag("fireimmune")

            inst:RemoveComponent("planarentity")
            if inst.components.grogginess then
                inst.components.grogginess:RemoveImmunitySource(inst)
            end

            if inst.components.planardamage then
                inst.components.planardamage:SetBaseDamage(0)
            end

            if inst.components.sanity then
                inst.components.sanity:EnableLunacy(false, "epic_enablelunacy")
            end

            inst:RemoveEventCallback("onhitother", Deerclops_OnHitOther)

            inst.AnimState:Show("gestalt_eye")
            if inst.mutateddeerclops_gestalt then
                inst.mutateddeerclops_gestalt:Remove()
                inst.mutateddeerclops_gestalt = nil
            end
            if inst.sg.mem.mutateddeerclops_circle then
				inst.sg.mem.mutateddeerclops_circle:Remove()
				inst.sg.mem.mutateddeerclops_circle = nil
			end
        end,
    },
}

return WEREEPIC_BOSS