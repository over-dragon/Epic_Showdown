local assets =
{
    Asset("ANIM", "anim/alterguardian_laser_hit_sparks_fx.zip"),
}

local prefabs =
{
    "alterguardian_laserscorch",
    "alterguardian_lasertrail",
    "alterguardian_laserhit",
}

local LAUNCH_SPEED = .2
local RADIUS = .7

local function SetLightRadius(inst, radius)
    inst.Light:SetRadius(radius)
end

local function DisableLight(inst)
    inst.Light:Enable(false)
end

local DAMAGE_CANT_TAGS = { "playerghost", "INLIMBO", "DECOR", "FX" }
local DAMAGE_ONEOF_TAGS = { "_combat", "pickable", "NPC_workable", "CHOP_workable", "HAMMER_workable", "MINE_workable", "DIG_workable" }
local LAUNCH_MUST_TAGS = { "_inventoryitem" }
local LAUNCH_CANT_TAGS = { "locomotor", "INLIMBO" }

if TUNING.EPIC_WORLD.STRUCTURE_PROTECTION==1 then
    table.insert(DAMAGE_CANT_TAGS,"structure")
    table.insert(DAMAGE_CANT_TAGS,"wall")
end

if not TheNet:GetPVPEnabled() then
    table.insert(DAMAGE_CANT_TAGS,"player")
end

local function DoDamage(inst, targets, skiptoss, skipscorch, scale, scorchscale, hitscale, heavymult, mult, forcelanded)
    inst.task = nil

    local x, y, z = inst.Transform:GetWorldPosition()

    -- First, get our presentation out of the way, since it doesn't change based on the find results.
    if inst.AnimState ~= nil then
		if scale then
			inst.AnimState:SetScale(scale, math.abs(scale))
		end
        inst.AnimState:PlayAnimation("hit_"..tostring(math.random(5)))
        inst:Show()
        inst:DoTaskInTime(inst.AnimState:GetCurrentAnimationLength() + 2 * FRAMES, inst.Remove)

        inst.Light:Enable(true)
        inst:DoTaskInTime(4 * FRAMES, SetLightRadius, .5)
        inst:DoTaskInTime(5 * FRAMES, DisableLight)

        if not skipscorch and TheWorld.Map:IsPassableAtPoint(x, 0, z, false) then
			local scorch = SpawnPrefab("alterguardian_laserscorch")
			scorch.Transform:SetPosition(x, 0, z)
			if scorchscale then
				scorch.AnimState:SetScale(scorchscale, math.abs(scorchscale))
			end
        end

        local fx = SpawnPrefab("alterguardian_lasertrail")
        fx.Transform:SetPosition(x, 0, z)
        fx:FastForward(GetRandomMinMax(.3, .7))
    else
        inst:DoTaskInTime(2 * FRAMES, inst.Remove)
    end

	--for knockback
	local disttocaster = mult and inst.caster and inst.caster:IsValid() and math.sqrt(inst.caster:GetDistanceSqToPoint(x, y, z)) or nil

	local restoredmg, restorepdp
	if inst.caster and inst.caster:IsValid() then
		if inst.overridedmg then
			restoredmg = inst.caster.components.combat.defaultdamage
			inst.caster.components.combat:SetDefaultDamage(inst.overridedmg)
		end
		if inst.overridepdp then
			restorepdp = inst.caster.components.combat.playerdamagepercent
			inst.caster.components.combat.playerdamagepercent = inst.overridepdp
		end
		inst.caster.components.combat.ignorehitrange = true
	end

	--override the fx's combat damage as well in case it gets used, but no need to restore
	if inst.overridedmg then
		inst.components.combat:SetDefaultDamage(inst.overridedmg)
	end
	if inst.overridepdp then
		inst.components.combat.playerdamagepercent = inst.overridepdp
	end
    inst.components.combat.ignorehitrange = true

	local hitradius = RADIUS * (hitscale or 1)
    for _, v in ipairs(TheSim:FindEntities(x, 0, z, hitradius + 3, nil, DAMAGE_CANT_TAGS, DAMAGE_ONEOF_TAGS)) do
        if not targets[v] and v:IsValid() and
                not (v.components.health ~= nil and v.components.health:IsDead()) then
			local range = hitradius + v:GetPhysicsRadius(.5)
            local dsq_to_laser = v:GetDistanceSqToPoint(x, y, z)
            if dsq_to_laser < range * range then
                v:PushEvent("onalterguardianlasered")

                local isworkable = false
                if v.components.workable ~= nil then
                    local work_action = v.components.workable:GetWorkAction()
                    --V2C: nil action for NPC_workable (e.g. campfires)
                    isworkable =
                        (   work_action == nil and v:HasTag("NPC_workable") ) or
                        (   v.components.workable:CanBeWorked() and
                            (   work_action == ACTIONS.CHOP or
                                work_action == ACTIONS.HAMMER or
                                work_action == ACTIONS.MINE or
                                (   work_action == ACTIONS.DIG and
                                    v.components.spawner == nil and
                                    v.components.childspawner == nil
                                )
                            )
                        )
                end
                if isworkable then
                    targets[v] = true
					v.components.workable:Destroy(inst.caster and inst.caster:IsValid() and inst.caster or inst)

                    -- Completely uproot trees.
                    if v:HasTag("stump") then
                        v:Remove()
                    end
                elseif v.components.pickable ~= nil
                        and v.components.pickable:CanBePicked()
                        and not v:HasTag("intense") then
                    targets[v] = true
					local success, loots = v.components.pickable:Pick(inst)
					if loots then
						for i, v in ipairs(loots) do
							skiptoss[v] = true
							targets[v] = true
							Launch(v, inst, LAUNCH_SPEED)
                        end
                    end
                elseif v.components.combat == nil and v.components.health ~= nil then
                    targets[v] = true
                elseif inst.components.combat:CanTarget(v) or inst.caster and inst.caster.components.combat:CanTarget(v) then
                    targets[v] = true

					--for knockback
					local strengthmult = mult and ((v.components.inventory and v.components.inventory:ArmorHasTag("heavyarmor") or v:HasTag("heavybody")) and heavymult or mult) or nil
					if strengthmult and v.components.rider and v.components.rider.mount then
						targets[v.components.rider.mount] = true
					end

                    if inst.caster ~= nil and inst.caster:IsValid() then
                        inst.caster.components.combat:DoAttack(v)
						if strengthmult then
							v:PushEvent("knockback", { knocker = inst.caster, radius = disttocaster + hitradius, strengthmult = strengthmult, forcelanded = forcelanded })
						end
                    else
                        inst.components.combat:DoAttack(v)
						if strengthmult then
							v:PushEvent("knockback", { knocker = inst, radius = hitradius, strengthmult = strengthmult, forcelanded = forcelanded })
						end
                    end

                    SpawnPrefab("alterguardian_laserhit"):SetTarget(v)

                    if not v.components.health:IsDead() then
                        if v.components.freezable ~= nil then
                            if v.components.freezable:IsFrozen() then
                                v.components.freezable:Unfreeze()
                            elseif v.components.freezable.coldness > 0 then
                                v.components.freezable:AddColdness(-2)
                            end
                        end
						local ent_temp = GetEntityTemperature(v)
						if ent_temp and 10 > ent_temp then
                        	DoDeltaTemperatureToEntity(v, 10-ent_temp)
						end
                        if v.components.sanity ~= nil then
                            v.components.sanity:DoDelta(TUNING.GESTALT_ATTACK_DAMAGE_SANITY)
                        end
                    end
                end
            end
        end
    end
    inst.components.combat.ignorehitrange = false
	if inst.caster and inst.caster:IsValid() then
		inst.caster.components.combat.ignorehitrange = false
		if restorepdp then
			inst.caster.components.combat.playerdamagepercent = restorepdp
		end
		if restoredmg then
			inst.caster.components.combat:SetDefaultDamage(restoredmg)
		end
	end

    -- After lasering stuff, try tossing any leftovers around.
	for _, v in ipairs(TheSim:FindEntities(x, 0, z, hitradius + 3, LAUNCH_MUST_TAGS, LAUNCH_CANT_TAGS)) do
        if not skiptoss[v] then
			local range = hitradius + v:GetPhysicsRadius(.5)
            if v:GetDistanceSqToPoint(x, y, z) < range * range then
                if DeactivateInventoryItemBeforeLaunch(v) then
                    targets[v] = true
                    skiptoss[v] = true
                end
                if not v.components.inventoryitem.nobounce and v.Physics ~= nil and v.Physics:IsActive() then
                    targets[v] = true
                    skiptoss[v] = true
                    Launch(v, inst, LAUNCH_SPEED)
                end
            end
        end
    end

    -- If the laser hit a boat, do boat stuff!
    local platform_hit = TheWorld.Map:GetPlatformAtPoint(x, 0, z)
    if platform_hit then
        local dsq_to_boat = platform_hit:GetDistanceSqToPoint(x, 0, z)
        if dsq_to_boat < TUNING.GOOD_LEAKSPAWN_PLATFORM_RADIUS then
            platform_hit:PushEvent("spawnnewboatleak", {pt = Vector3(x, 0, z), leak_size = "small_leak", playsoundfx = true})
        end
        platform_hit.components.health:DoDelta(-1 * TUNING.ALTERGUARDIAN_PHASE3_LASERDAMAGE / 10)
    end
end

local function Trigger(inst, delay, targets, skiptoss, skipscorch, scale, scorchscale, hitscale, heavymult, mult, forcelanded)
    if inst.task ~= nil then
        inst.task:Cancel()
        if (delay or 0) > 0 then
			inst.task = inst:DoTaskInTime(delay, DoDamage, targets or {}, skiptoss or {}, skipscorch, scale, scorchscale, hitscale, heavymult, mult, forcelanded)
        else
			DoDamage(inst, targets or {}, skiptoss or {}, skipscorch, scale, scorchscale, hitscale, heavymult, mult, forcelanded)
        end
    end
end

--V2C: Added for daywalker2 due to buggy CC laser damage code.
--     (Damage is different depending on whether .caster is provided or not.)
--     Not worth "fixing" CC atm; as that should be treated as rebalancing.
local function OverrideDamage(inst, damage, playerdamagepercent)
	inst.overridedmg = damage
	inst.overridepdp = playerdamagepercent
end

local function KeepTargetFn()
    return false
end

local function common_fn(isempty)
    local inst = CreateEntity()

    inst.entity:AddTransform()
    inst.entity:AddNetwork()

    if not isempty then
        inst.entity:AddAnimState()
        inst.AnimState:SetBank("alterguardian_laser_hits_sparks")
        inst.AnimState:SetBuild("alterguardian_laser_hit_sparks_fx")
        inst.AnimState:SetBloomEffectHandle("shaders/anim.ksh")
        inst.AnimState:SetLightOverride(1)

        inst.entity:AddLight()
        inst.Light:SetIntensity(.6)
        inst.Light:SetRadius(1)
        inst.Light:SetFalloff(.7)
        inst.Light:SetColour(0.1, 0.4, 1.0)
        inst.Light:Enable(false)
    end

    inst:Hide()

    inst:AddTag("notarget")
    inst:AddTag("hostile")

    inst:SetPrefabNameOverride("deerclops")

    inst.entity:SetPristine()

    if not TheWorld.ismastersim then
        return inst
    end

    inst:AddComponent("combat")
    inst.components.combat:SetDefaultDamage(TUNING.ALTERGUARDIAN_PHASE3_LASERDAMAGE)
    inst.components.combat:SetKeepTargetFunction(KeepTargetFn)

    inst.task = inst:DoTaskInTime(0, inst.Remove)
    inst.Trigger = Trigger
	inst.OverrideDamage = OverrideDamage
    inst.persists = false

    return inst
end

local function fn()
    return common_fn(false)
end

return Prefab("epic_alterguardian_laser", fn, assets, prefabs)
