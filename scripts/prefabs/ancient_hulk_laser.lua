local assets = {
    Asset("ANIM", "anim/ancient_hulk_projectile.zip"),
    Asset("ANIM", "anim/ancient_hulk_bomb.zip"),
    Asset("ANIM", "anim/ancient_hulk_laser_ring_fx.zip"),
    Asset("ANIM", "anim/laser_explosion.zip"),
}

local basalt_assets =
{
	Asset("ANIM", "anim/epic_rock_basalt.zip"),
}

local ringassets =
{
    Asset("ANIM", "anim/ancient_hulk_ring_fx.zip"),
}

local prefabs =
{
    "ancient_hulk_laser_ring",
    "ancient_hulk_laserhit"
}

SetSharedLootTable('epic_basalt',
	{
		{ 'rocks', 1.00 },
		{ 'rocks', 1.00 },
		{ 'rocks', 0.50 },
		{ 'flint', 1.00 },
		{ 'flint', 0.30 },
	})

local hulk_NOTAGS = { "playerghost", "INLIMBO", "DECOR", "FX" }
local hulk_DAMAGE_ONEOF_TAGS = { "_combat","_health", "pickable", "NPC_workable", "CHOP_workable", "HAMMER_workable", "MINE_workable", "DIG_workable" }
if not TheNet:GetPVPEnabled() then
    table.insert(hulk_NOTAGS,"player")
end
if TUNING.EPIC_WORLD.STRUCTURE_PROTECTION==1 then
    table.insert(hulk_NOTAGS,"structure")
    table.insert(hulk_NOTAGS,"wall")
end

local function setfires(inst,x, y, z, rad)
    for i, v in ipairs(TheSim:FindEntities(x, 0, z, rad, nil,hulk_NOTAGS,hulk_DAMAGE_ONEOF_TAGS)) do
        if v.components.burnable then
            v.components.burnable:Ignite()
        end
    end
end

local function applydamagetoent(inst, ent, targets, rad, hit)
    local x, y, z = inst.Transform:GetWorldPosition()
    if hit then
        targets = {}
    end
    if not rad then
        rad = 4
    end
    local v = ent
    if not targets[v] and v:IsValid() and not v:IsInLimbo() and
    not (v.components.health ~= nil and v.components.health:IsDead())
    then
        local vradius = 0
        if v.Physics then
            vradius = v.Physics:GetRadius()
        end

        local range = rad + vradius
        if hit or v:GetDistanceSqToPoint(Vector3(x, y, z)) < range * range then
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
                                    v.components.spawner == nil and
                                    v.components.childspawner == nil
                                )
                            )
                        )
            end
            if isworkable then
                targets[v] = true
                v:DoTaskInTime(
                    0.6,
                    function()
                        if v.components.workable then
                            v.components.workable:Destroy(inst)
                            local vx, vy, vz = v.Transform:GetWorldPosition()
                            v:DoTaskInTime(
                                0.3,
                                function()
                                    setfires(inst,vx, vy, vz, 1)
                                end
                            )
                        end
                    end
                )
            elseif v.components.pickable ~= nil and v.components.pickable:CanBePicked() and not v:HasTag("intense") then
                targets[v] = true
                local num = v.components.pickable.numtoharvest or 1
                local product = v.components.pickable.product
                local x1, y1, z1 = v.Transform:GetWorldPosition()
                v.components.pickable:Pick(TheWorld)
                if product ~= nil and num > 0 then
                    for i = 1, num do
                        local loot = SpawnPrefab(product)
                        loot.Transform:SetPosition(x1, 0, z1)
                        targets[loot] = true
                    end
                end
            elseif v:IsValid() and v.components.health then
                if inst.owner and inst.owner.components.combat:CanTarget(v) then
                    inst.owner.components.combat:DoAttack(v)
                elseif inst.components.combat:CanTarget(v) then
                    inst.components.combat:DoAttack(v)
                end

                if not v.components.health or not v.components.health:IsDead() then
                    if v.components.freezable ~= nil then
                        if v.components.freezable:IsFrozen() then
                            v.components.freezable:Unfreeze()
                        elseif v.components.freezable.coldness > 0 then
                            v.components.freezable:AddColdness(-2)
                        end
                    end
                    if v.components.temperature ~= nil then
                        local maxtemp = math.min(v.components.temperature:GetMax(), 10)
                        local curtemp = v.components.temperature:GetCurrent()
                        if maxtemp > curtemp then
                            v.components.temperature:DoDelta(math.min(10, maxtemp - curtemp))
                        end
                    end
                end
            end

            if v:IsValid() then
                SpawnPrefab("ancient_hulk_laserhit"):SetTarget(v)
            end
        end
    end
    return targets
end

local function DoDamage(inst, rad, startang, endang, spawnburns)
    local targets = {}
    local x, y, z = inst.Transform:GetWorldPosition()
    local angle = nil

    if startang and endang then
        startang = startang + 90
        endang = endang + 90
        angle = inst.Transform:GetRotation()
    end

    if inst.owner then
        inst.owner.components.combat.ignorehitrange = true
    end

    setfires(inst,x, y, z, rad)

    for i, v in ipairs(TheSim:FindEntities(x, 0, z, rad, nil, hulk_NOTAGS,hulk_DAMAGE_ONEOF_TAGS)) do
        local dodamage = true
        if startang and endang then
            local dir = inst:GetAngleToPoint(Vector3(v.Transform:GetWorldPosition()))
            local dif = angle - dir
            while dif > 450 do
                dif = dif - 360
            end
            while dif < 90 do
                dif = dif + 360
            end
            if dif < startang or dif > endang then
                dodamage = false
            end
        end
        if dodamage then
            targets = applydamagetoent(inst, v, targets, rad)
        end
    end

    if inst.owner then
        inst.owner.components.combat.ignorehitrange = false
    end

end

local function OnRemoveHit(inst)
    if inst.target ~= nil and inst.target:IsValid() then
        if inst.target.components.colouradder == nil then
            if inst.target.components.freezable ~= nil then
                inst.target.components.freezable:UpdateTint()
            else
                inst.target.AnimState:SetAddColour(0, 0, 0, 1)
            end
        end
        if inst.target.components.bloomer == nil then
            inst.target.AnimState:ClearBloomEffectHandle()
        end
    end
end

local function UpdateHit(inst, target)
    if target:IsValid() then
        local oldflash = inst.flash
        inst.flash = math.max(0, inst.flash - .075)
        if inst.flash > 0 then
            local c = math.min(1, inst.flash)
            if target.components.colouradder ~= nil then
                target.components.colouradder:PushColour(inst, c, 0, 0, 0)
            else
                target.AnimState:SetAddColour(c, 0, 0, 1)
            end
            if inst.flash < .3 and oldflash >= .3 then
                if target.components.bloomer ~= nil then
                    target.components.bloomer:PopBloom(inst)
                else
                    target.AnimState:ClearBloomEffectHandle()
                end
            end
            return
        end
    end
    inst:Remove()
end

local function SetTarget(inst, target)
    if inst.inittask ~= nil then
        inst.inittask:Cancel()
        inst.inittask = nil

        inst.target = target
        inst.OnRemoveEntity = OnRemoveHit

        if target.components.bloomer ~= nil then
            target.components.bloomer:PushBloom(inst, "shaders/anim.ksh", -1)
        else
            target.AnimState:SetBloomEffectHandle("shaders/anim.ksh")
        end
        inst.flash = .8 + math.random() * .4
        inst:DoPeriodicTask(0, UpdateHit, nil, target)
        UpdateHit(inst, target)
    end
end

local function hitfn()
    local inst = CreateEntity()
    inst.entity:AddTransform()

    inst.entity:SetPristine()

    if not TheWorld.ismastersim then
        return inst
    end

    inst.SetTarget = SetTarget
    inst.inittask = inst:DoTaskInTime(0, inst.Remove)

    inst.persists = false

    return inst
end

local function OnHitOrb(inst, dist)
    ShakeAllCameras(CAMERASHAKE.FULL, 0.4, 0.03, 1.5, inst, 40)
    inst.AnimState:PlayAnimation("impact")
    inst:ListenForEvent("animover",
        function()
            if inst.AnimState:IsCurrentAnimation("impact") then
                inst:Remove()
            end
        end
    )
    local ring = SpawnPrefab("ancient_hulk_laser_ring")
    ring.Transform:SetPosition(inst.Transform:GetWorldPosition())
    inst:DoTaskInTime(
        0.2,
        function()
            inst.components.combat.ignorehitrange = true
            DoDamage(inst, 3.5)
        end
    )
    inst.SoundEmitter:PlaySound("mnh_ancient_hulk_sound/creatures/boss/hulk_metal_robot/smash_2")
end

local function SetLightValue(inst, val1, val2, time)
    inst.components.fader:StopAll()
    if val1 and val2 and time then
        inst.Light:Enable(true)
        inst.components.fader:Fade(
            val1,
            val2,
            time,
            function(v)
                inst.Light:SetIntensity(v)
            end
        )
    else
        inst.Light:Enable(false)
    end
end

local function orbfn()
    local inst = CreateEntity()
    inst.entity:AddTransform()
    inst.entity:AddAnimState()
    inst.entity:AddSoundEmitter()
    inst.entity:AddLight()
    inst.entity:AddNetwork()

    MakeProjectilePhysics(inst, 75, 0.5)

    inst.Light:SetIntensity(.6)
    inst.Light:SetRadius(3)
    inst.Light:SetFalloff(1)
    inst.Light:SetColour(1, 0.3, 0.3)
    inst.Light:Enable(true)

    inst.AnimState:SetBank("ancient_hulk_projectile")
    inst.AnimState:SetBuild("ancient_hulk_projectile")
    inst.AnimState:PlayAnimation("spin_loop", true)

    inst:AddTag("projectile")
    inst:AddTag("laser")

    inst.entity:SetPristine()

    if not TheWorld.ismastersim then
        return inst
    end

    inst:AddComponent("complexprojectile")
    inst.components.complexprojectile:SetOnHit(OnHitOrb)
    inst.components.complexprojectile:SetHorizontalSpeed(60)
    inst.components.complexprojectile:SetGravity(-1)
    inst.components.complexprojectile.usehigharc = false

    inst:AddComponent("combat")
    inst.components.combat:SetDefaultDamage(TUNING.ANCIENT_HULK_DAMAGE*TUNING.EPIC_WORLD.DAMAGE)
    inst.components.combat.playerdamagepercent = 0.5

    inst.persists = false

    return inst
end

local function Scorch_OnUpdateFade(inst)
    inst.alpha = math.max(0, inst.alpha - (1/90) )
    inst.AnimState:SetMultColour(1, 1, 1,  inst.alpha)
    if inst.alpha == 0 then
        inst:Remove()
    end
end

local function scorchfn()
    local inst = CreateEntity()

    inst.entity:AddTransform()
    inst.entity:AddAnimState()
	inst.entity:AddNetwork()
    inst.AnimState:SetBuild("ancient_hulk_laser_ring_fx")
    inst.AnimState:SetBank("ancient_hulk_laser_ring_fx")
    inst.AnimState:PlayAnimation("idle")
    inst.AnimState:SetOrientation(ANIM_ORIENTATION.OnGround)
    inst.AnimState:SetLayer(LAYER_BACKGROUND)
    inst.AnimState:SetSortOrder(3)

    inst:AddTag("NOCLICK")
    inst:AddTag("FX")

    inst.Transform:SetScale(0.85,0.85,0.85)

    inst.entity:SetPristine()

    if not TheWorld.ismastersim then
        return inst
    end

    inst.alpha = 1
    inst:DoTaskInTime(0.7,function()
        inst:DoPeriodicTask(0, Scorch_OnUpdateFade)
    end)

    inst.Transform:SetRotation(math.random() * 360)

    inst.persists = false

    return inst
end

local function markerfn(Sim)
    local inst = CreateEntity()
    local trans = inst.entity:AddTransform()
    inst.entity:AddNetwork()
    inst.persists = false
    return inst
end

local function OnHit(inst, dist)
    inst.AnimState:PlayAnimation("land")
    inst.SoundEmitter:PlaySound("mnh_ancient_hulk_sound/creatures/boss/hulk_metal_robot/ribs/step_wires")
    inst.AnimState:PushAnimation("open")
    inst.SoundEmitter:PlaySound("mnh_ancient_hulk_sound/creatures/boss/hulk_metal_robot/rust")
    inst:ListenForEvent("animover",function()
        if inst.AnimState:IsCurrentAnimation("open") then
            inst.primed = true
            inst.AnimState:PlayAnimation("green_loop", true)
        end
    end)
end

local function onnearmine(inst, ents)
    local detonate = false
    for i, ent in ipairs(ents) do
        if ent~=inst.owner or (not TheNet:GetPVPEnabled() and not ent:HasTag("player")) then
            detonate = true
            break
        end
    end
    if inst.primed and detonate then
        inst.SetLightValue(inst, 0, 0.75, 0.2)
        inst.AnimState:PlayAnimation("red_loop", true)
        inst.SoundEmitter:PlaySound("mnh_ancient_hulk_sound/creatures/boss/hulk_metal_robot/active_LP", "boom_loop")
        inst.SoundEmitter:PlaySound("mnh_ancient_hulk_sound/creatures/boss/hulk_metal_robot/electro")
        inst:DoTaskInTime(0.8,function()
            inst.SoundEmitter:KillSound("boom_loop")
            ShakeAllCameras(CAMERASHAKE.FULL, 0.5, 0.03, 2, inst, 40)
            inst:Hide()
            local ring = SpawnPrefab("ancient_hulk_laser_ring")
            ring.Transform:SetPosition(inst.Transform:GetWorldPosition())
            inst:DoTaskInTime(0.3,function()
                DoDamage(inst, 3.5)
                inst:Remove()
            end)
            local explosion = SpawnPrefab("epic_laser_explosion")
            explosion.Transform:SetPosition(inst.Transform:GetWorldPosition())
            inst.SoundEmitter:PlaySound("mnh_ancient_hulk_sound/creatures/boss/hulk_metal_robot/smash_3")
        end)
    end
end

local function minefn()
    local inst = CreateEntity()
    local trans = inst.entity:AddTransform()
    local anim = inst.entity:AddAnimState()
    local sound = inst.entity:AddSoundEmitter()
    inst.entity:AddNetwork()

    MakeInventoryPhysics(inst, 75, 0.5)

    anim:SetBank("ancient_hulk_mine")
    anim:SetBuild("ancient_hulk_bomb")
    anim:PlayAnimation("green_loop", true)

    inst:AddTag("ancient_hulk_mine")

    inst.primed = true

    inst.glow = inst.entity:AddLight()
    inst.glow:SetIntensity(.6)
    inst.glow:SetRadius(2)
    inst.glow:SetFalloff(1)
    inst.glow:SetColour(1, 0.3, 0.3)
    inst.glow:Enable(false)

    inst:AddComponent("fader")

    inst.entity:SetPristine()

    if not TheWorld.ismastersim then
        return inst
    end

    inst:AddComponent("locomotor")
    inst:AddComponent("complexprojectile")
    inst.components.complexprojectile:SetOnHit(OnHit)
    inst.components.complexprojectile.yOffset = 2.5

    inst:AddComponent("combat")
    inst.components.combat:SetDefaultDamage(TUNING.ANCIENT_HULK_DAMAGE*TUNING.EPIC_WORLD.DAMAGE)
    inst.components.combat.playerdamagepercent = .5

    inst.SetLightValue = SetLightValue

    inst:AddComponent("epic_creatureprox")
    inst.components.epic_creatureprox.period = 0.01
    inst.components.epic_creatureprox:SetDist(3.5, 5)
    inst.components.epic_creatureprox:SetOnPlayerNear(onnearmine)

    inst.persists = false

    return inst
end

local function ringfn()
    local inst = CreateEntity()

    inst.entity:AddTransform()
    inst.entity:AddAnimState()
	inst.entity:AddNetwork()

    inst.AnimState:SetBuild("ancient_hulk_ring_fx")
    inst.AnimState:SetBank("ancient_hulk_ring_fx")
    inst.AnimState:PlayAnimation("idle")
    inst.AnimState:SetOrientation( ANIM_ORIENTATION.OnGround )
    inst.AnimState:SetLayer( LAYER_BACKGROUND )
    inst.AnimState:SetSortOrder( 2 )

    inst:AddTag("NOCLICK")
    inst:AddTag("FX")

    inst.entity:SetPristine()

    if not TheWorld.ismastersim then
        return inst
    end

    inst:ListenForEvent("animover", inst.Remove)

    inst.persists = false

    return inst
end

local function basalt_fn(Sim)
	local inst = CreateEntity()
	local trans = inst.entity:AddTransform()
	local anim = inst.entity:AddAnimState()
	inst.entity:AddSoundEmitter()
	inst.entity:AddNetwork()

	MakeObstaclePhysics(inst, 1)

	inst.AnimState:SetBank("epic_rock_basalt")
	inst.AnimState:SetBuild("epic_rock_basalt")
	inst.AnimState:PlayAnimation("full")

    inst:SetPrefabNameOverride("rock_flintless")

	local minimap = inst.entity:AddMiniMapEntity()
	minimap:SetIcon("rock_flintless.png")

	inst.entity:SetPristine()

	if not TheWorld.ismastersim then
		return inst
	end

	inst:AddComponent("lootdropper")
	inst.components.lootdropper:SetChanceLootTable('epic_basalt')

	inst:AddComponent("workable")
	inst.components.workable:SetWorkAction(ACTIONS.MINE)
	inst.components.workable:SetWorkLeft(TUNING.ROCKS_MINE)

	inst.components.workable:SetOnWorkCallback(
		function(inst, worker, workleft)
			local pt = Point(inst.Transform:GetWorldPosition())
			if workleft <= 0 then
				if inst:HasTag("trggerdarttraps") then
					triggerdarts(inst)
				end

				inst.SoundEmitter:PlaySound("dontstarve/wilson/rock_break")
				inst.components.lootdropper:DropLoot(pt)

				inst:Remove()
			else
				if workleft < TUNING.ROCKS_MINE * (1 / 3) then
					inst.AnimState:PlayAnimation("low")
				elseif workleft < TUNING.ROCKS_MINE * (2 / 3) then
					inst.AnimState:PlayAnimation("med")
				else
					if not inst.components.dislodgeable or inst.components.dislodgeable:CanBeDislodged() then
						inst.AnimState:PlayAnimation("full")
					else
						inst.AnimState:PlayAnimation("extract_success")
					end
				end
			end
		end)

	local color = 0.5 + math.random() * 0.5
	anim:SetMultColour(color, color, color, 1)

	inst:AddComponent("inspectable")
	inst.components.inspectable.nameoverride = "ROCK"

	MakeSnowCovered(inst, .01)

    inst.persists = false

	return inst
end

local function explosionfn()
    local inst = CreateEntity()

    inst.entity:AddTransform()
    inst.entity:AddAnimState()
	inst.entity:AddNetwork()
    inst.AnimState:SetBuild("laser_explosion")
    inst.AnimState:SetBank("laser_explosion")
    inst.AnimState:PlayAnimation("idle")

    inst:AddTag("NOCLICK")
    inst:AddTag("FX")
    inst:AddTag("laser")

    inst.Transform:SetScale(0.85,0.85,0.85)

    inst.entity:SetPristine()

    if not TheWorld.ismastersim then
        return inst
    end

    inst.persists = false
    inst:ListenForEvent("animover", function(inst) inst:Remove() end)
    inst:ListenForEvent("entitysleep", inst.Remove)

    return inst
end

return Prefab("ancient_hulk_laserhit", hitfn),
    Prefab("epic_ancient_hulk_orb",orbfn,assets,prefabs),
    Prefab("ancient_hulk_laser_ring", scorchfn, assets),
    Prefab("ancient_hulk_projectile_marker",markerfn),
    Prefab("epic_ancient_hulk_mine", minefn, assets, {"ancient_hulk_laser_ring","epic_laser_explosion"}),
    Prefab("ancient_hulk_ring_fx", ringfn, ringassets),
    Prefab("epic_rock_basalt", basalt_fn, basalt_assets),
    Prefab("epic_laser_explosion", explosionfn, assets)