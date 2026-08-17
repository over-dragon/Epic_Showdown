local EPIC = require("wereepic_skill")

local epic_attack_tags_sever = {"attack","notalking", "abouttoattack", "autopredict", "epic"}
if TUNING.EPIC_WORLD.ATTACK_LOCOMTE_INTERRUPT~=1 then
    table.insert(epic_attack_tags_sever,"busy")
end
---deerclops
local DEERCLOPS_AOE_RANGE_PADDING = 3
local AREAATTACK_MUST_TAGS = { "_combat" }
local AREA_EXCLUDE_TAGS = { "INLIMBO", "notarget", "noattack", "flight", "playerghost" }
local ICESPAWNTIME = 0.25
local ICESPIKE_RADIUS = 1 --2/3 is more accurate, but 1 matches legacy
local function DoIceSpikeAOE(inst, target, x, z, data)
	inst.components.combat.ignorehitrange = true
	local ents = TheSim:FindEntities(x, 0, z, ICESPIKE_RADIUS + DEERCLOPS_AOE_RANGE_PADDING, AREAATTACK_MUST_TAGS, AREA_EXCLUDE_TAGS)
	for i, v in ipairs(ents) do
		if not data.targets[v] and v:IsValid() and not v:IsInLimbo() and
			not (v.components.health ~= nil and v.components.health:IsDead()) and inst.components.combat:CanTarget(v)
		then
			local range = ICESPIKE_RADIUS + v:GetPhysicsRadius(0)
			if v:GetDistanceSqToPoint(x, 0, z) < range * range and inst.components.combat:CanTarget(v) then
				local shouldknockback = inst.hasknockback and v.components.freezable ~= nil and v.components.freezable:IsFrozen()
				if shouldknockback and v.components.rider and v.components.rider.mount then
					data.targets[v.components.rider.mount] = true
				end
				inst.components.combat:DoAttack(v)
				if shouldknockback then
					v:PushEvent("knockback", { knocker = inst, radius = TUNING.DEERCLOPS_ATTACK_RANGE })
				end
				data.targets[v] = true
			end
		end
	end
	inst.components.combat.ignorehitrange = false

	--After the final spike, check if we hit anything at all
	if data.count > 1 then
		data.count = data.count - 1
	elseif next(data.targets) == nil then
		inst:PushEvent("onmissother", { target = target }) -- for ChaseAndAttack
	end
end
local function DoSpawnIceSpike(inst, target, rot, info, data, hitdelay, shouldsfx)
	local fx  = SpawnPrefab("deerclops_icespike_fx")

	fx:SetFXOwner(inst)

	fx.Transform:SetPosition(info.x, 0, info.z)
	fx.Transform:SetRotation(rot)
	fx:RestartFX(info.big, info.variation)
	if shouldsfx then
		fx.SoundEmitter:PlaySound("dontstarve/creatures/deerclops/ice_small")
	end
	if hitdelay < FRAMES then
		DoIceSpikeAOE(inst, target, info.x, info.z, data)
	else
		inst:DoTaskInTime(hitdelay, DoIceSpikeAOE, target, info.x, info.z, data)
	end
end
local function SpikeInfoNearToFar(a, b)
	return a.radius < b.radius
end

local function DeerclopsFootstep(inst, moving, noice)
	inst.SoundEmitter:PlaySound("dontstarve/creatures/deerclops/step")
	ShakeAllCameras(CAMERASHAKE.VERTICAL, .5, .03, 1, inst, 40)

	if not noice and inst.sg.mem.mutateddeerclops_circle ~= nil then
		inst.sg.mem.mutateddeerclops_circle:KillFX()
		inst.sg.mem.mutateddeerclops_circle = SpawnPrefab("deerclops_aura_circle_fx")
		local x, y, z = inst.Transform:GetWorldPosition()
		if moving then
			local rot = inst.Transform:GetRotation() * DEGREES
			x = x + math.cos(rot) * 1.5
			z = z - math.sin(rot) * 1.5
		end
		inst.sg.mem.mutateddeerclops_circle.Transform:SetPosition(x, 0, z)
		inst.sg.mem.mutateddeerclops_circle.SoundEmitter:PlaySound("dontstarve/common/break_iceblock", nil, 0.4)
	end
end

local MAX_ICESPIKE_SFX = 6
local function SpawnIceFx(inst, target)
	local data = { targets = {}, count = 0 }

	local AOEarc = 35

    local x, y, z = inst.Transform:GetWorldPosition()
    local angle = inst.Transform:GetRotation()
	local spikeinfo = {}

	local theta = angle * DEGREES
	local cos_theta = math.cos(theta)
	local sin_theta = math.sin(theta)
    local num = 3
	data.count = data.count + num
	for i = 1, num do
		local radius = TUNING.DEERCLOPS_ATTACK_RANGE / num * i
		table.insert(spikeinfo,
		{
			x = x + radius * cos_theta,
			z = z - radius * sin_theta,
			radius = radius,
		})
    end

	num = math.random(12, 17)
	data.count = data.count + num
	for i = 1, num do
        local theta =  ( angle + math.random(AOEarc *2) - AOEarc ) * DEGREES
        local radius = TUNING.DEERCLOPS_ATTACK_RANGE * math.sqrt(math.random())
		table.insert(spikeinfo,
		{
			x = x + radius * math.cos(theta),
			z = z - radius * math.sin(theta),
			radius = radius,
		})
    end

	num = math.random(5, 8)
	data.count = data.count + num
	local newarc = 180 - AOEarc
	for i = 1, num do
        local theta =  ( angle -180 + math.random(newarc *2) - newarc ) * DEGREES
        local radius = 2 * math.random() +1
		table.insert(spikeinfo,
		{
			x = x + radius * math.cos(theta),
			z = z - radius * math.sin(theta),
			radius = radius,
		})
	end

	table.sort(spikeinfo, SpikeInfoNearToFar)

	num = data.count
	local nextbig = 1
	local delayvar = ICESPAWNTIME / (num - 1) * 0.3
	local cursfxinstance = 0
	for i = 1, num do
		local rnd = math.random()
		rnd = math.floor(rnd * rnd * #spikeinfo * 0.6) + 1
		local info = table.remove(spikeinfo, rnd)
		local delay =
			(i == 1 and 0) or
			(i == num and ICESPAWNTIME) or
			(i - 1) / (num - 1) * ICESPAWNTIME + delayvar * (math.random() - 0.5)
		local hitdelay = math.max(0, 3 * FRAMES - delay)
		local soundidx = math.floor((i - 1) / (num - 1) * (MAX_ICESPIKE_SFX - 1))
		local shouldsfx = soundidx >= cursfxinstance
		if shouldsfx then
			cursfxinstance = soundidx + 1
		end
		if math.floor(i * 4 / num) == nextbig then
			info.big = true
			info.variation = nextbig
			nextbig = nextbig + 1
		end
		inst:DoTaskInTime(delay, DoSpawnIceSpike, target, angle, info, data, hitdelay, shouldsfx)
	end
end

local function SpawnLaser(inst)
    local numsteps = 10
    local x, y, z = inst.Transform:GetWorldPosition()
    local angle = (inst.Transform:GetRotation() + 90) * DEGREES
    local step = .75
    local offset = 2 - step --should still hit players right up against us
    -- local ground = TheWorld.Map
    local targets, skiptoss = {}, {}
    local i = -1
    -- local noground = false
    local fx, dist, delay, x1, z1
    while i < numsteps do
        i = i + 1
        dist = i * step + offset
        delay = math.max(0, i - 1)
        x1 = x + dist * math.sin(angle)
        z1 = z + dist * math.cos(angle)
        -- if not ground:IsPassableAtPoint(x1, 0, z1) then
        --     if i <= 0 then
        --         return
        --     end
        --     noground = true
        -- end
        fx = SpawnPrefab(i > 0 and "deerclops_laser" or "deerclops_laserempty")
        fx.caster = inst
        fx.Transform:SetPosition(x1, 0, z1)
        fx:Trigger(delay * FRAMES, targets, skiptoss)
        if i == 0 then
            ShakeAllCameras(CAMERASHAKE.FULL, .7, .02, .6, fx, 30)
        end
        -- if noground then
        --     break
        -- end
    end

    if i < numsteps then
        dist = (i + .5) * step + offset
        x1 = x + dist * math.sin(angle)
        z1 = z + dist * math.cos(angle)
    end
    fx = SpawnPrefab("deerclops_laser")
    fx.Transform:SetPosition(x1, 0, z1)
    fx:Trigger((delay + 1) * FRAMES, targets, skiptoss)

    fx = SpawnPrefab("deerclops_laser")
    fx.Transform:SetPosition(x1, 0, z1)
    fx:Trigger((delay + 2) * FRAMES, targets, skiptoss)
end

local function SetLightColour(inst, val)
    if inst.Light ~= nil then
        inst.Light:SetColour(val, 0, 0)
    end
end
local function SetLightValue(inst, val)
    if inst.Light ~= nil then
        inst.Light:SetIntensity(.6 * val * val)
        inst.Light:SetRadius(8 * val)
        inst.Light:SetFalloff(3 * val)
    end
end
local function SetLightValueAndOverride(inst, val, override)
    if inst.Light ~= nil then
        inst.Light:SetIntensity(.6 * val * val)
        inst.Light:SetRadius(8 * val)
        inst.Light:SetFalloff(3 * val)
        inst.AnimState:SetLightOverride(override)
    end
end

---bearger
local function SpawnSwipeFX(inst, offset, reverse)
    local mode = inst.replica.wereepic:GetEpicMode()
    if mode=="bearger" or mode=="mutatedbearger" then
        inst.sg.statemem.fx = SpawnPrefab(mode.."_swipe_fx")
        inst.sg.statemem.fx.entity:SetParent(inst.entity)
        inst.sg.statemem.fx.Transform:SetPosition(offset, 0, 0)
        if reverse then
            inst.sg.statemem.fx:Reverse()
        end
    end
end

local function KillSwipeFX(inst)
	if inst.sg.statemem.fx ~= nil then
		if inst.sg.statemem.fx:IsValid() then
			inst.sg.statemem.fx:Remove()
		end
		inst.sg.statemem.fx = nil
	end
end

local ARC = 90 * DEGREES --degrees to each side
local AOE_RANGE_PADDING = 3
local AOE_TARGET_MUSTHAVE_TAGS = { "_combat" }
local AOE_TARGET_CANT_TAGS = { "INLIMBO", "notarget", "noattack" }
local MAX_SIDE_TOSS_STR = 0.8

local function DoArcAttack(inst, dist, radius, heavymult, mult, forcelanded, targets)
	inst.components.combat.ignorehitrange = true
	local x, y, z = inst.Transform:GetWorldPosition()
	local rot = inst.Transform:GetRotation() * DEGREES
	local x0, z0
	if dist ~= 0 then
		if dist > 0 and ((mult ~= nil and mult > 1) or (heavymult ~= nil and heavymult > 1)) then
			x0, z0 = x, z
		end
		x = x + dist * math.cos(rot)
		z = z - dist * math.sin(rot)
	end
	for i, v in ipairs(TheSim:FindEntities(x, y, z, radius + AOE_RANGE_PADDING, AOE_TARGET_MUSTHAVE_TAGS, AOE_TARGET_CANT_TAGS)) do
		if v ~= inst and
			not (targets ~= nil and targets[v]) and
			v:IsValid() and not v:IsInLimbo()
			and not (v.components.health ~= nil and v.components.health:IsDead())
		then
			local range = radius + v:GetPhysicsRadius(0)
			local x1, y1, z1 = v.Transform:GetWorldPosition()
			local dx = x1 - x
			local dz = z1 - z
			local distsq = dx * dx + dz * dz
			if distsq > 0 and distsq < range * range and
				DiffAngleRad(rot, math.atan2(-dz, dx)) < ARC and
				inst.components.combat:CanTarget(v)
			then
				if targets then
					targets[v] = true
					if mult and v.components.rider and v.components.rider.mount then
						targets[v.components.rider.mount] = true
					end
				end
				inst.components.combat:DoAttack(v)
				if mult ~= nil then
					local strengthmult = (v.components.inventory ~= nil and v.components.inventory:ArmorHasTag("heavyarmor") or v:HasTag("heavybody")) and heavymult or mult
					if strengthmult > MAX_SIDE_TOSS_STR and x0 ~= nil then
						--Don't toss as far to the side for frontal attacks
						dx = x1 - x0
						dz = z1 - z0
						if dx ~= 0 or dz ~= 0 then
							local rot1 = math.atan2(-dz, dx) + PI
							local k = math.max(0, math.cos(math.min(PI, DiffAngleRad(rot1, rot) * 2)))
							strengthmult = MAX_SIDE_TOSS_STR + (strengthmult - MAX_SIDE_TOSS_STR) * k * k
						end
					end
					v:PushEvent("knockback", { knocker = inst, radius = radius + dist, strengthmult = strengthmult, forcelanded = forcelanded })
				end
			end
		end
	end
	inst.components.combat.ignorehitrange = false
end

local COMBO_ARC_OFFSET = 0.5

local function DoComboArcAttack(inst, targets)
	DoArcAttack(inst, COMBO_ARC_OFFSET, TUNING.BEARGER_MELEE_RANGE, 1, 1, nil, targets)
end

local function ShakeIfClose(inst)
    ShakeAllCameras(CAMERASHAKE.FULL, .7, .02, 1, inst, 40)
end

local function ShakeIfClose_Pound(inst)
    ShakeAllCameras(CAMERASHAKE.VERTICAL, .7, .025, 1.25, inst, 40)
end

local function ShakeIfClose_Footstep(inst)
    ShakeAllCameras(CAMERASHAKE.FULL, .35, .02, 1, inst, 40)
end

local function DoFootstep(inst)
	-- if inst:IsStandState("quad") then
	-- 	inst.SoundEmitter:PlaySound("dontstarve_DLC001/creatures/bearger/step_soft")
	-- else
		inst.SoundEmitter:PlaySound("dontstarve_DLC001/creatures/bearger/step_stomp")
		ShakeIfClose_Footstep(inst)
	-- end
end

local COLLAPSIBLE_WORK_ACTIONS =
{
	CHOP = true,
	DIG = true,
	HAMMER = true,
	MINE = true,
}
local COLLAPSIBLE_TAGS = { "NPC_workable" }
for k, v in pairs(COLLAPSIBLE_WORK_ACTIONS) do
	table.insert(COLLAPSIBLE_TAGS, k.."_workable")
end
local NON_COLLAPSIBLE_TAGS = { "FX", --[["NOCLICK",]] "DECOR", "INLIMBO" }

if TUNING.EPIC_WORLD.STRUCTURE_PROTECTION==1 then
    table.insert(NON_COLLAPSIBLE_TAGS,"structure")
    table.insert(NON_COLLAPSIBLE_TAGS,"wall")
end

local function DestroyStuff(inst, dist, radius, arc, nofx)
    local x, y, z = inst.Transform:GetWorldPosition()
	local rot = inst.Transform:GetRotation() * DEGREES
	if dist ~= 0 then
		x = x + dist * math.cos(rot)
		z = z - dist * math.sin(rot)
	end
	for i, v in ipairs(TheSim:FindEntities(x, y, z, radius, nil, NON_COLLAPSIBLE_TAGS, COLLAPSIBLE_TAGS)) do
		if v:IsValid() and not v:IsInLimbo() and v.components.workable ~= nil then
			local x1, y1, z1 = v.Transform:GetWorldPosition()
			if arc == nil or ((x1 ~= x or z1 ~= z) and DiffAngleRad(rot, math.atan2(z - z1, x1 - x)) < arc) then
				local work_action = v.components.workable:GetWorkAction()
				--V2C: nil action for NPC_workable (e.g. campfires)
				if (work_action == nil and v:HasTag("NPC_workable")) or
					(v.components.workable:CanBeWorked() and work_action ~= nil and COLLAPSIBLE_WORK_ACTIONS[work_action.id])
				then
					if not nofx then
						SpawnPrefab("collapse_small").Transform:SetPosition(x1, y1, z1)
					end
                    if TUNING.EPIC_WORLD.STRUCTURE_PROTECTION==1 and not (work_action==ACTIONS.DIG and not v:HasTag("stump")) or TUNING.EPIC_WORLD.STRUCTURE_PROTECTION~=1 then
                        v.components.workable:Destroy(inst)
                    end
				end
			end
		end
    end
end

local function DoComboArcWork(inst)
	DestroyStuff(inst, COMBO_ARC_OFFSET, TUNING.BEARGER_MELEE_RANGE, ARC, true)
end

local YAWNTARGET_CANT_TAGS = { "playerghost", "FX", "DECOR", "INLIMBO" }
local YAWNTARGET_ONEOF_TAGS = { "sleeper", "player" }

local function yawnfn(inst)
    local x, y, z = inst.Transform:GetWorldPosition()
    local ents = TheSim:FindEntities(x, y, z, TUNING.BEARGER_YAWN_RANGE, nil, YAWNTARGET_CANT_TAGS, YAWNTARGET_ONEOF_TAGS)
    for i, v in ipairs(ents) do
        if v ~= inst and v:IsValid() and
            not (v.components.freezable ~= nil and v.components.freezable:IsFrozen()) and
            not (v.components.pinnable ~= nil and v.components.pinnable:IsStuck()) and
            not (v.components.fossilizable ~= nil and v.components.fossilizable:IsFossilized()) then
            local mount = v.components.rider ~= nil and v.components.rider:GetMount() or nil
            if mount ~= nil then
                mount:PushEvent("ridersleep", { sleepiness = 7, sleeptime = TUNING.BEARGER_YAWN_SLEEPTIME })
            end
            if v:HasTag("player") and TheNet:GetPVPEnabled() then
                v:PushEvent("yawn", { grogginess = 4, knockoutduration = TUNING.BEARGER_YAWN_SLEEPTIME })
            elseif v.components.sleeper ~= nil then
                v.components.sleeper:AddSleepiness(7, TUNING.BEARGER_YAWN_SLEEPTIME)
            elseif v.components.grogginess ~= nil then
                v.components.grogginess:AddGrogginess(4, TUNING.BEARGER_YAWN_SLEEPTIME)
            else
                v:PushEvent("knockedout")
            end
        end
    end
    return true
end
---moose
local MooseSpinTag = {"pickable", "NPC_workable", "CHOP_workable", "HAMMER_workable", "MINE_workable", "DIG_workable"}
local MooseSpinCanNotTag = {"INLIMBO", "DECOR", "FX"}
if TUNING.EPIC_WORLD.STRUCTURE_PROTECTION==1 then
    table.insert(MooseSpinCanNotTag,"structure")
    table.insert(MooseSpinCanNotTag,"wall")
end
local function Moose_DestroyStuff(inst)
    local x, y, z = inst.Transform:GetWorldPosition()
	for i, v in ipairs(TheSim:FindEntities(x, y, z, 4, nil, MooseSpinCanNotTag, MooseSpinTag)) do
		if v:IsValid() and not v:IsInLimbo()  then
            if v.components.workable ~= nil then
                local x1, y1, z1 = v.Transform:GetWorldPosition()
				local work_action = v.components.workable:GetWorkAction()
				if (work_action == nil and v:HasTag("NPC_workable")) or
					(v.components.workable:CanBeWorked() and work_action ~= nil and COLLAPSIBLE_WORK_ACTIONS[work_action.id])
				then
					SpawnPrefab("collapse_small").Transform:SetPosition(x1, y1, z1)
                    if TUNING.EPIC_WORLD.STRUCTURE_PROTECTION==1 and not (work_action==ACTIONS.DIG and not v:HasTag("stump")) or TUNING.EPIC_WORLD.STRUCTURE_PROTECTION~=1 then
                        v.components.workable:Destroy(inst)
                    elseif v.components.pickable ~= nil
                    and v.components.pickable:CanBePicked()
                    and not v:HasTag("intense") then
                        v.components.pickable:Pick(TheWorld)
                    end
				end
            end
		end
    end
end
local function MooseDoArcAttack(inst,targets)
	inst.components.combat.ignorehitrange = true
	local x, y, z = inst.Transform:GetWorldPosition()
	for i, v in ipairs(TheSim:FindEntities(x, y, z, 4, AOE_TARGET_MUSTHAVE_TAGS, AOE_TARGET_CANT_TAGS)) do
		if v ~= inst and
			not (targets ~= nil and targets[v]) and
			v:IsValid() and not v:IsInLimbo()
			and not (v.components.health ~= nil and v.components.health:IsDead())
		then
			if inst.components.combat:CanTarget(v) then
				if targets then
					targets[v] = true
				end
				inst.components.combat:DoAttack(v)
			end
		end
	end
	inst.components.combat.ignorehitrange = false
end
local function LightningStrike(inst)
	local rad = math.random(0,3)
	local angle = math.random() * TWOPI
	local offset = Vector3(rad * math.cos(angle), 0, -rad * math.sin(angle))

	local pos = inst:GetPosition() + offset

	TheWorld:PushEvent("ms_sendlightningstrike", pos)
	TheWorld:PushEvent("ms_forceprecipitation", true)
end

---antlion
local SPIKE_SIZES =
{
    "short",
    "med",
    "tall",
}

local SPIKE_RADIUS =
{
    ["short"] = .2,
    ["med"] = .4,
    ["tall"] = .6,
    ["block"] = 1.1,
}

local function CanSpawnSpikeAt(pos, size)
    local radius = SPIKE_RADIUS[size]
    for i, v in ipairs(TheSim:FindEntities(pos.x, 0, pos.z, radius + 1.5, nil, { "antlion_sinkhole" }, { "groundspike", "antlion_sinkhole_blocker" })) do
        if v.Physics == nil then
            return false
        end
        local spacing = radius + v:GetPhysicsRadius(0)
        if v:GetDistanceSqToPoint(pos) < spacing * spacing then
            return false
        end
    end
    return true
end

local function SpawnSpikes(inst, pos, count)
    for i = #SPIKE_SIZES, 1, -1 do
        local size = SPIKE_SIZES[i]
        if CanSpawnSpikeAt(pos, size) then
            SpawnPrefab("antlion_sandspike_"..size).Transform:SetPosition(pos:Get())
            count = count - 1
            break
        end
    end
    if count > 0 then
        local dtheta = TWOPI / count
        for theta = math.random() * dtheta, TWOPI, dtheta do
            local size = SPIKE_SIZES[math.random(#SPIKE_SIZES)]
            local offset = FindWalkableOffset(pos, theta, 2 + math.random() * 2, 3, false, true,
                function(pt)
                    return CanSpawnSpikeAt(pt, size)
                end,
                false, true)
            if offset ~= nil then
                SpawnPrefab("antlion_sandspike_"..size).Transform:SetPosition(pos.x + offset.x, 0, pos.z + offset.z)
            end
        end
    end
end

local function SpawnBlock(inst, x, z)
    SpawnPrefab("antlion_sandblock").Transform:SetPosition(x, 0, z)
end

local function SpawnBlocks(inst, pos, count)
    if count > 0 then
        local dtheta = TWOPI / count
        local thetaoffset = math.random() * TWOPI
        for theta = math.random() * dtheta, TWOPI, dtheta do
            local offset = FindWalkableOffset(pos, theta + thetaoffset, 8 + math.random(), 3, false, true,
                function(pt)
                    return CanSpawnSpikeAt(pt, "block")
                end)
            if offset ~= nil then
                if theta < dtheta then
                    SpawnBlock(inst, pos.x + offset.x, pos.z + offset.z)
                else
                    inst:DoTaskInTime(math.random() * .5, SpawnBlock, pos.x + offset.x, pos.z + offset.z)
                end
            end
        end
    end
end

---malbatross
local function spawnripple(inst)
    if not TheWorld.Map:IsVisualGroundAtPoint(inst.Transform:GetWorldPosition()) then
        inst.SoundEmitter:PlaySound("saltydog/creatures/boss/malbatross/ripple")
        SpawnPrefab("boss_ripple_fx").Transform:SetPosition(inst.Transform:GetWorldPosition())
    end
end
local function spawnsplash(inst, size, pos)
    local splashpos = Vector3(inst.Transform:GetWorldPosition())
    if pos then
        splashpos = pos
    end
    if not TheWorld.Map:IsVisualGroundAtPoint(splashpos.x,splashpos.y,splashpos.z) and not TheWorld.Map:GetPlatformAtPoint(splashpos.x,splashpos.z) then
        local prefab = "splash_green_large"
        if size == "med" then
            prefab = "splash_green"
        end
        local fx = SpawnPrefab("splash_green_large")
        fx.Transform:SetPosition(splashpos.x,splashpos.y,splashpos.z)
     --   if scale then
          --  fx.Transform:SetScale(scale,scale,scale)
       -- end
    end
end

local ATTACK_WAVE_SPEED = 4
local ATTACK_WAVE_IDLE_TIME = 1.5
local ANGLE_OFFSET = 35*DEGREES
local function SpawnMalbatrossAttackWaves(inst)
    local position = inst:GetPosition()
    local angle = inst:GetRotation() + (math.random()*20 - 10)

    local angle_rads = angle*DEGREES
    local offset_direction1 = Vector3(math.cos(angle_rads), 0, -math.sin(angle_rads)):Normalize()

    local point = position + (offset_direction1 * 3.5)
    local platform = TheWorld.Map:GetPlatformAtPoint(point.x,point.y,point.z)
    if platform then
        local theta = inst.Transform:GetRotation() * DEGREES
        local offset = Vector3(math.cos( theta ), 0, -math.sin( theta ))

        platform.components.boatphysics:ApplyForce(offset.x, offset.z, TUNING.MALBATROSS_BOAT_PUSH)

        if platform.components.hullhealth then
            platform.components.health:DoDelta(-TUNING.MALBATROSS_BOAT_DAMAGE)
        end
    elseif not TheWorld.Map:IsVisualGroundAtPoint(point.x,point.y,point.z) then
        spawnsplash(inst, "med", point)

        SpawnAttackWave(position + offset_direction1, angle, {ATTACK_WAVE_SPEED, 0, 0}, nil, ATTACK_WAVE_IDLE_TIME, true)

        local offset_direction2 = Vector3(math.cos(angle_rads + ANGLE_OFFSET), 0, -math.sin(angle_rads + ANGLE_OFFSET)):Normalize()*3
        SpawnAttackWave(position + offset_direction2, angle, {ATTACK_WAVE_SPEED, 0, -1}, nil, ATTACK_WAVE_IDLE_TIME, true)

        local offset_direction3 = Vector3(math.cos(angle_rads - ANGLE_OFFSET), 0, -math.sin(angle_rads - ANGLE_OFFSET)):Normalize()*3
        SpawnAttackWave(position + offset_direction3, angle, {ATTACK_WAVE_SPEED, 0, 1}, nil, ATTACK_WAVE_IDLE_TIME, true)
    end
end

local function spawnwaves(inst, numWaves, totalAngle, waveSpeed, wavePrefab, initialOffset, idleTime, instantActivate, random_angle)
    SpawnAttackWaves(
        inst:GetPosition(),
        (not random_angle and inst.Transform:GetRotation()) or nil,
        initialOffset or (inst.Physics and inst.Physics:GetRadius()) or nil,
        numWaves,
        totalAngle,
        waveSpeed,
        wavePrefab,
        idleTime,
        instantActivate
    )
end

local function spawnwave(inst, time)
    spawnwaves(inst, 12, 360, 4, nil, 2, time or 2, nil, true)
end

local function spawnfeather(inst,time)
    local feather = SpawnPrefab("malbatross_feather_fall")
    local pos = Vector3(inst.Transform:GetWorldPosition())
    local angle = math.random() * TWOPI
    local offset = Vector3(math.cos(angle), 0, -math.sin(angle)):Normalize() * (math.random()*2+ 1)
    pos = pos + offset
    feather.Transform:SetPosition(pos.x,pos.y,pos.z)

    if time then
		feather.AnimState:SetTime(time * 79 * FRAMES)
    end

    feather.Transform:SetRotation(math.random()*360)

    if not inst.malbatross_feathers then
        inst.malbatross_feathers = 0
    end
    inst.malbatross_feathers = inst.malbatross_feathers + 1
end

local function malbatross_ClearRecentlyCharged(inst, other)
    inst.malbatross_recentlycharged[other] = nil
end

local function malbatross_onothercollide(inst, other)
    if not other:IsValid() or inst.malbatross_recentlycharged[other] or
            (not other:HasTag("tree") and not other:HasTag("mast") and not other.components.health) then
        return
    end

    if other:HasTag("smashable") and other.components.health ~= nil then
        --other.Physics:SetCollides(false)
        other.components.health:Kill()
    elseif other.components.workable ~= nil
        and other.components.workable:CanBeWorked()
        and other.components.workable.action ~= ACTIONS.NET then

        if other:HasTag("mast") then
            local boat = other:GetCurrentPlatform()
            if boat then
                local vx, vy, vz = inst.Physics:GetVelocity()
                vx, vz = VecUtil_Normalize(vx, vz)

                local boat_physics = boat.components.boatphysics
                boat_physics:ApplyForce(vx, vz, 3)
            end

            spawnfeather(inst,0.4)
            spawnfeather(inst,0.4)
            spawnfeather(inst,0.4)
            if math.random() < 0.3 then
                spawnfeather(inst,0.4)
            end
            if math.random() < 0.3 then
                spawnfeather(inst,0.4)
            end
        end

        SpawnPrefab("collapse_small").Transform:SetPosition(other.Transform:GetWorldPosition())
        other.components.workable:Destroy(inst)

        inst.malbatross_recentlycharged[other] = true
        inst:DoTaskInTime(3, malbatross_ClearRecentlyCharged, other)
    elseif other.components.health ~= nil and not other.components.health:IsDead() then
        inst.malbatross_recentlycharged[other] = true
        inst:DoTaskInTime(3, malbatross_ClearRecentlyCharged, other)
        if inst.components.combat:CanTarget(other) then
            inst.components.combat:DoAttack(other)
        end
    end
end

local function malbatross_oncollide(inst, other)
    if other ~= nil and other:IsValid() and inst:IsValid() and not inst.malbatross_recentlycharged[other] then
        inst:DoTaskInTime(2 * FRAMES, malbatross_onothercollide, other)
    end
end

local SWOOP_LOOP_TARGET_CANT_TAGS = {"INLIMBO", "fx", "malbatross", "boat", "boatbumper"}
local SWOOP_LOOP_TARGET_ONEOF_TAGS = {"tree", "mast", "_health"}

---beequeen
local FOCUSTARGET_MUST_TAGS = { "_combat", "_health" }
local FOCUSTARGET_CANT_TAGS = { "INLIMBO", "player", "bee", "notarget", "flight" }
local function FaceTarget(inst)
    local target = inst.components.combat.target
    if inst.sg.mem.focustargets ~= nil then
        local mindistsq = math.huge
        for i = #inst.sg.mem.focustargets, 1, -1 do
            local v = inst.sg.mem.focustargets[i]
            if v:IsValid() and v.components.health ~= nil and not v.components.health:IsDead() and not v:HasTag("playerghost") then
                local distsq = inst:GetDistanceSqToInst(v)
                if distsq < mindistsq then
                    mindistsq = distsq
                    target = v
                end
            else
                table.remove(inst.sg.mem.focustargets, i)
                if #inst.sg.mem.focustargets <= 0 then
                    inst.sg.mem.focustargets = nil
                    break
                end
            end
        end
    end
    if target ~= nil and target:IsValid() then
        inst:ForceFacePoint(target.Transform:GetWorldPosition())
    end
end

local function StartFlapping(inst)
    inst.SoundEmitter:PlaySound("dontstarve/creatures/together/bee_queen/wings_LP", "flying")
end

local function RestoreFlapping(inst)
    if not inst.SoundEmitter:PlayingSound("flying") then
        StartFlapping(inst)
    end
end

local function StopFlapping(inst)
    inst.SoundEmitter:KillSound("flying")
end

local function DoScreech(inst)
    ShakeAllCameras(CAMERASHAKE.FULL, 1, .015, .3, inst, 30)
    inst.SoundEmitter:PlaySound("dontstarve/creatures/together/bee_queen/taunt")
end

local function DoScreechAlert(inst)
    inst.components.epicscare:Scare(5)
    inst.components.commander:AlertAllSoldiers()
end

---daywalker
local function daywalker_DoFootstep(inst, volume)
	inst.sg.mem.lastfootstep = GetTime()
    if inst.replica.wereepic:GetEpicMode()=="daywalker" then
        inst.SoundEmitter:PlaySound("daywalker/action/step", nil, volume)
    elseif inst.replica.wereepic:GetEpicMode()=="daywalker2" then
        inst.SoundEmitter:PlaySound("qol1/daywalker_scrappy/step", nil, volume)
    end
end

local function DoAOEAttack(inst, dist, radius, heavymult, mult, forcelanded, targets)
	inst.components.combat.ignorehitrange = true
	local x, y, z = inst.Transform:GetWorldPosition()
	local rot0, x0, z0
	if dist ~= 0 then
		if dist > 0 and ((mult ~= nil and mult > 1) or (heavymult ~= nil and heavymult > 1)) then
			x0, z0 = x, z
		end
		rot0 = inst.Transform:GetRotation() * DEGREES
		x = x + dist * math.cos(rot0)
		z = z - dist * math.sin(rot0)
	end
	for i, v in ipairs(TheSim:FindEntities(x, y, z, radius + AOE_RANGE_PADDING, AOE_TARGET_MUSTHAVE_TAGS, AOE_TARGET_CANT_TAGS)) do
		if v ~= inst and
			not (targets ~= nil and targets[v]) and
			v:IsValid() and not v:IsInLimbo()
			and not (v.components.health ~= nil and v.components.health:IsDead())
			then
			local range = radius + v:GetPhysicsRadius(0)
			if v:GetDistanceSqToPoint(x, y, z) < range * range and inst.components.combat:CanTarget(v) then
				if targets then
					targets[v] = true
					if mult and v.components.rider and v.components.rider.mount then
						targets[v.components.rider.mount] = true
					end
				end
				inst.components.combat:DoAttack(v)
                inst.sg.statemem.daywalker_attack_slam = v
				if mult ~= nil then
					local strengthmult = (v.components.inventory ~= nil and v.components.inventory:ArmorHasTag("heavyarmor") or v:HasTag("heavybody")) and heavymult or mult
					if strengthmult > MAX_SIDE_TOSS_STR and x0 ~= nil then
						--Don't toss as far to the side for frontal attacks
						local rot1 = (v:GetAngleToPoint(x0, 0, z0) + 180) * DEGREES
						local k = math.max(0, math.cos(math.min(PI, DiffAngleRad(rot1, rot0) * 2)))
						strengthmult = MAX_SIDE_TOSS_STR + (strengthmult - MAX_SIDE_TOSS_STR) * k * k
					end
					v:PushEvent("knockback", { knocker = inst, radius = radius + dist + 3, strengthmult = strengthmult, forcelanded = forcelanded })
				end
			end
		end
	end
	inst.components.combat.ignorehitrange = false
end

local daywalker_COLLAPSIBLE_WORK_ACTIONS =
{
	CHOP = true,
	HAMMER = true,
	MINE = true,
	-- no digging
}
local daywalker_COLLAPSIBLE_TAGS = { "NPC_workable" }
for k, v in pairs(daywalker_COLLAPSIBLE_WORK_ACTIONS) do
	table.insert(daywalker_COLLAPSIBLE_TAGS, k.."_workable")
end
local daywalker_NON_COLLAPSIBLE_TAGS = { "FX",  "DECOR", "INLIMBO" }
local daywalker_FOOTSTEP_NON_COLLAPSIBLE_TAGS = { "FX",  "DECOR", "INLIMBO", "event_trigger" }
if TUNING.EPIC_WORLD.STRUCTURE_PROTECTION==1 then
    table.insert(daywalker_NON_COLLAPSIBLE_TAGS,"structure")
    table.insert(daywalker_NON_COLLAPSIBLE_TAGS,"wall")
end

local TRAMPLE_TIMEOUT = 5 --seconds
local TRAMPLE_THRESHOLD = 5 --steps

local function _OnTrampleTimeout(inst, trampledelays, target)
	trampledelays[target] = nil
end

local function DoAOEWork(inst, dist, radius, targets, overridenontags, trampledelays)
	local x, y, z = inst.Transform:GetWorldPosition()
	if dist ~= 0 then
		local rot = inst.Transform:GetRotation() * DEGREES
		x = x + dist * math.cos(rot)
		z = z - dist * math.sin(rot)
	end
	for i, v in ipairs(TheSim:FindEntities(x, y, z, radius + AOE_RANGE_PADDING, nil, overridenontags or daywalker_NON_COLLAPSIBLE_TAGS, daywalker_COLLAPSIBLE_TAGS)) do
		if not (targets ~= nil and targets[v]) and v:IsValid() and not v:IsInLimbo() then
			local range = radius + v:GetPhysicsRadius(0)
			if v:GetDistanceSqToPoint(x, 0, z) < range * range and v.components.workable then
				local work_action = v.components.workable:GetWorkAction()
				--V2C: nil action for NPC_workable (e.g. campfires)
				if (work_action == nil and v:HasTag("NPC_workable")) or
					(v.components.workable:CanBeWorked() and work_action ~= nil and daywalker_COLLAPSIBLE_WORK_ACTIONS[work_action.id])
				then
					if v:HasTag("daywalker_pillar") then
                        local prisoner = v.prisoner:value()
                        if prisoner ~= nil and prisoner.chained then
                            prisoner.sg:GoToState("chain_break")
                        end
                        v:OnCollided(inst)
					else
						--obstacles take a few footsteps b4 getting destroyed by regular running
						local shoulddelaytrample
						if trampledelays and v:HasTag("blocker") then
							local data = trampledelays[v]
							if data == nil then
								trampledelays[v] =
								{
									n = 1,
									task = inst:DoTaskInTime(TRAMPLE_TIMEOUT, _OnTrampleTimeout, trampledelays, v),
								}
								shoulddelaytrample = true
							else
								data.n = data.n + 1
								data.task:Cancel()
								if data.n < TRAMPLE_THRESHOLD then
									data.task = inst:DoTaskInTime(TRAMPLE_TIMEOUT, _OnTrampleTimeout, trampledelays, v)
									shoulddelaytrample = true
								else
									trampledelays[v] = nil
								end
							end
						end

                        if TUNING.EPIC_WORLD.STRUCTURE_PROTECTION==1 and not (work_action==ACTIONS.DIG and not v:HasTag("stump")) or TUNING.EPIC_WORLD.STRUCTURE_PROTECTION~=1 then
                            if shoulddelaytrample then
                                v.components.workable:WorkedBy(inst, 0)
                            else
                                v.components.workable:Destroy(inst)
                            end
                        end

						if targets then
							targets[v] = true
						end
					end
				end
			end
		end
	end
end

local function DoFootstepAOE(inst)
	DoAOEWork(inst, 0.3, 1.5, nil, daywalker_FOOTSTEP_NON_COLLAPSIBLE_TAGS, inst.daywalker_trampledelays)
end

---dawalker2
local function daywalker2_SpawnSwipeFX(inst, offset, reverse)
	inst.sg.statemem.fx = SpawnPrefab("daywalker2_swipe_fx")
	inst.sg.statemem.fx.entity:SetParent(inst.entity)
	inst.sg.statemem.fx.Transform:SetPosition(offset, 0, 0)
	if reverse then
		inst.sg.statemem.fx:Reverse()
	end
end

local function daywalker2_KillSwipeFX(inst)
	if inst.sg.statemem.fx ~= nil then
		if inst.sg.statemem.fx:IsValid() then
			inst.sg.statemem.fx:Remove()
		end
		inst.sg.statemem.fx = nil
	end
end

local daywalker2_AOE_TARGET_CANT_TAGS = { "INLIMBO", "notarget", "noattack", "junk_fence" }
local daywalker2_NOBLOCK_AOE_TARGET_CANT_TAGS = { "INLIMBO", "notarget", "noattack", "blocker" }

local function _AOEAttack(inst, dist, radius, arc, heavymult, mult, forcelanded, targets, overridenontags)
	local hit = false
	inst.components.combat.ignorehitrange = true
	local x, y, z = inst.Transform:GetWorldPosition()
	local arcx, cos_theta, sin_theta
	if dist ~= 0 or arc then
		local theta = inst.Transform:GetRotation() * DEGREES
		cos_theta = math.cos(theta)
		sin_theta = math.sin(theta)
		if dist ~= 0 then
			x = x + dist * cos_theta
			z = z - dist * sin_theta
		end
		if arc then
			arcx = x + math.cos(arc / 2 * DEGREES) * radius
		end
	end
	for i, v in ipairs(TheSim:FindEntities(x, y, z, radius + AOE_RANGE_PADDING, AOE_TARGET_MUSTHAVE_TAGS, overridenontags and daywalker2_NOBLOCK_AOE_TARGET_CANT_TAGS or daywalker2_AOE_TARGET_CANT_TAGS)) do
		if v ~= inst and
			not (targets and targets[v]) and
			v:IsValid() and not v:IsInLimbo() and
			not (v.components.health and v.components.health:IsDead())
		then
			local range = radius + v:GetPhysicsRadius(0)
			local x1, y1, z1 = v.Transform:GetWorldPosition()
			local dx = x1 - x
			local dz = z1 - z
			if dx * dx + dz * dz < range * range and
				(arcx == nil or x + cos_theta * dx - sin_theta * dz > arcx) and
				inst.components.combat:CanTarget(v)
			then
				if targets then
					targets[v] = true
					if mult and v.components.rider and v.components.rider.mount then
						targets[v.components.rider.mount] = true
					end
				end
				inst.components.combat:DoAttack(v)
				if mult then
					local strengthmult = (v.components.inventory and v.components.inventory:ArmorHasTag("heavyarmor") or v:HasTag("heavybody")) and heavymult or mult
					v:PushEvent("knockback", { knocker = inst, radius = radius + dist, strengthmult = strengthmult, forcelanded = forcelanded })
				end
				hit = true
			end
		end
	end
	inst.components.combat.ignorehitrange = false
	return hit
end

local daywalker2_NOBLOCK_NON_COLLAPSIBLE_TAGS = { "FX", "DECOR", "INLIMBO", "blocker" }
local daywalker2_FOOTSTEP_NON_COLLAPSIBLE_TAGS = { "FX", "DECOR", "INLIMBO", "junk_pile_big" }

local FRONT_ANGLE_THRESHOLD = 60 * DEGREES

local function _OnTrampleTimeout(inst, trampledelays, target)
	trampledelays[target] = nil
end

local function _DoAOEWork(inst, dist, radius, arc, targets, canblock, overridenontags, trampledelays)
	local hit, blocked = false, false
	local x, y, z = inst.Transform:GetWorldPosition()
	local theta = inst.Transform:GetRotation() * DEGREES
	local arcx, cos_theta, sin_theta
	if dist ~= 0 or arc then
		cos_theta = math.cos(theta)
		sin_theta = math.sin(theta)
		if dist ~= 0 then
			x = x + dist * cos_theta
			z = z - dist * sin_theta
		end
		if arc then
			arcx = x + math.cos(arc / 2 * DEGREES) * radius
		end
	end
	for i, v in ipairs(TheSim:FindEntities(x, y, z, radius + AOE_RANGE_PADDING, nil, overridenontags or NON_COLLAPSIBLE_TAGS, COLLAPSIBLE_TAGS)) do
		if not (targets and targets[v]) and v:IsValid() and not v:IsInLimbo() then
			local range = radius + v:GetPhysicsRadius(0)
			local x1, y1, z1 = v.Transform:GetWorldPosition()
			local dx = x1 - x
			local dz = z1 - z
			if dx * dx + dz * dz < range * range and
				(arcx == nil or x + cos_theta * dx - sin_theta * dz > arcx) and
				v.components.workable
			then
				local work_action = v.components.workable:GetWorkAction()
				if (work_action == nil and v:HasTag("NPC_workable")) or
					(v.components.workable:CanBeWorked() and work_action and COLLAPSIBLE_WORK_ACTIONS[work_action.id])
				then
					--blocked is if we want to stop when colliding with an obstacle in front of us
					local isblocker, infront
					if canblock and not blocked then
						isblocker = v:HasTag("blocker")
						infront = isblocker and (dx ~= 0 or dz ~= 0) and DiffAngleRad(theta, math.atan2(-dz, dx)) < FRONT_ANGLE_THRESHOLD
						if infront then
							blocked = true
						end
					end

					--obstacles take a few footsteps b4 getting destroyed by regular running
					local shoulddelaytrample
					if trampledelays then
						if isblocker == nil then
							isblocker = v:HasTag("blocker")
						end
						if isblocker then
							local data = trampledelays[v]
							if data == nil then
								trampledelays[v] =
								{
									n = 1,
									task = inst:DoTaskInTime(TRAMPLE_TIMEOUT, _OnTrampleTimeout, trampledelays, v),
								}
								shoulddelaytrample = true
							else
								data.n = data.n + 1
								data.task:Cancel()
								if data.n < TRAMPLE_THRESHOLD then
									data.task = inst:DoTaskInTime(TRAMPLE_TIMEOUT, _OnTrampleTimeout, trampledelays, v)
									shoulddelaytrample = true
								else
									trampledelays[v] = nil
								end
							end
						end
					elseif v:HasTag("junk_fence") then
						if inst.sg:HasStateTag("tackle") then
							if infront == nil then
								infront = (dx ~= 0 or dz ~= 0) and DiffAngleRad(theta, math.atan2(-dz, dx)) < FRONT_ANGLE_THRESHOLD
							end
							if not infront then
								--when tackling, only break junk fences directly in front of us
								shoulddelaytrample = true
							end
						else
							--when not trampling don't break junk fences
							shoulddelaytrample = true
						end
					end

                    if TUNING.EPIC_WORLD.STRUCTURE_PROTECTION==1 and not (work_action==ACTIONS.DIG and not v:HasTag("stump")) or TUNING.EPIC_WORLD.STRUCTURE_PROTECTION~=1 then
                        if shoulddelaytrample then
                            v.components.workable:WorkedBy(inst, 0)
                        else
                            v.components.workable:Destroy(inst)
                        end
                    end

					if targets then
						targets[v] = true
					end
					hit = true
				end
			end
		end
	end
	return hit, blocked
end

local function daywalker2_DoArcAttack(inst, dist, radius, arc, heavymult, mult, forcelanded, targets)
	_DoAOEWork(inst, dist, radius, arc, targets, false, nil, nil)
	_AOEAttack(inst, dist, radius, arc, heavymult, mult, forcelanded, targets, nil)
	return true
end

local function daywalker2_DoAOEAttack(inst, dist, radius, heavymult, mult, forcelanded, targets, canblock, ignoreblock)
	_DoAOEWork(inst, dist, radius, nil, targets, canblock, ignoreblock and daywalker2_NOBLOCK_NON_COLLAPSIBLE_TAGS or nil, nil)
	_AOEAttack(inst, dist, radius, nil, heavymult, mult, forcelanded, targets, ignoreblock and daywalker2_NOBLOCK_AOE_TARGET_CANT_TAGS or nil)
	return true
end

local function CalcKnockback(scale)
	if scale >= 1 then
		return nil, Lerp(1, 1.5, scale - 1)
	end
	return scale, scale * 1.3, true
end

local function CalcDamage(dist)
	local min = TUNING.ALTERGUARDIAN_PHASE3_LASERDAMAGE * TUNING.DAYWALKER2_CANNON_FAR_DAMAGE_MULT
	local max = TUNING.ALTERGUARDIAN_PHASE3_LASERDAMAGE * TUNING.DAYWALKER2_CANNON_NEAR_DAMAGE_MULT
	return math.clamp(Remap(dist, 5.4, 10, max, min), min, max), TUNING.ALTERGUARDIAN_PLAYERDAMAGEPERCENT
end

local function daywalker2_SpawnLaserHitOnly(inst, dist, scale, targets)
	local x, y, z = inst.Transform:GetWorldPosition()
	local rot = inst.Transform:GetRotation() * DEGREES
	local fx = SpawnPrefab("alterguardian_laserempty")
	fx.caster = inst
	fx.Transform:SetPosition(x + dist * math.cos(rot), 0, z - dist * math.sin(rot))

	local dmg, playerdamagepercent = CalcDamage(dist)
	local hitscale = math.max(1, scale)
	local heavymult, mult, forcelanded = CalcKnockback(scale)

	fx:OverrideDamage(dmg, playerdamagepercent)
	fx:Trigger(0, targets, nil, true, nil, nil, hitscale, heavymult, mult, forcelanded)
end

local function daywalker2_SpawnLaser(inst, dist, angle_offset, scale, scorchscale, targets)
	local x, y, z = inst.Transform:GetWorldPosition()
	local rot = (inst.Transform:GetRotation() + angle_offset) * DEGREES
	local fx = SpawnPrefab("epic_alterguardian_laser")
	fx.caster = inst
	fx.Transform:SetPosition(x + dist * math.cos(rot), 0, z - dist * math.sin(rot))

	local knockback = scale >= 1 and Lerp(1, 1.5, scale - 1) or nil
	local animscale = scale * (0.9 + math.random() * 0.2) * (inst.sg.mem.fliplaser and -1 or 1)
	inst.sg.mem.fliplaser = not inst.sg.mem.fliplaser

	local dmg, playerdamagepercent = CalcDamage(dist)
	local hitscale = math.max(1, scale)
	local heavymult, mult, forcelanded = CalcKnockback(scale)

	fx:OverrideDamage(dmg, playerdamagepercent)
	fx:Trigger(0, targets, nil, scorchscale < 0.2, animscale, scorchscale, hitscale, heavymult, mult, forcelanded)
	return dist + 0.4
end

local function daywalker2_DoFootstepAOE(inst)
	_DoAOEWork(inst, 0.3, 1.5, nil, nil, false, FOOTSTEP_NON_COLLAPSIBLE_TAGS, inst._trampledelays)
end

local function daywalker2_DoAOEAttack(inst, dist, radius, heavymult, mult, forcelanded, targets, canblock, ignoreblock)
	_DoAOEWork(inst, dist, radius, nil, targets, canblock, ignoreblock and NOBLOCK_NON_COLLAPSIBLE_TAGS or nil, nil)
	_AOEAttack(inst, dist, radius, nil, heavymult, mult, forcelanded, targets, ignoreblock and NOBLOCK_AOE_TARGET_CANT_TAGS or nil)
end

---alterguardian_phase1
local function phase1_play_foley(inst)
    inst.SoundEmitter:PlaySound("moonstorm/creatures/boss/alterguardian1/foley")
end

local function phase1_play_step(inst)
    inst.SoundEmitter:PlaySound("moonstorm/creatures/boss/alterguardian1/step")
end

local TANTRUM_SS_SPEED = 0.05
local TANTRUM_SS_SCALE = 0.075
local function ph1_tantrum_screenshake(inst)
    ShakeAllCameras(CAMERASHAKE.VERTICAL, .5, TANTRUM_SS_SPEED, TANTRUM_SS_SCALE, inst, 60)
end

local ROLL_SS_SPEED = 0.1
local ROLL_SS_SCALE = 0.1
local function ph1_roll_screenshake(inst)
    ShakeAllCameras(CAMERASHAKE.VERTICAL, .5, ROLL_SS_SPEED, ROLL_SS_SCALE, inst, 40)
end

local function ph1_spawn_land_screenshake(inst)
	ShakeAllCameras(CAMERASHAKE.VERTICAL, 0.8, 0.03, 0.6, inst, 40)
end

local function ph1_spawn_landfx(inst)
    local ix, iy, iz = inst.Transform:GetWorldPosition()
    SpawnPrefab("alterguardian_spintrail_fx").Transform:SetPosition(ix, iy, iz)
    SpawnPrefab("mining_moonglass_fx").Transform:SetPosition(ix, iy, iz)
end

local AOE_RANGE_PADDING = 3
local TARGET_MUSTHAVE_TAGS = { "_health", "_combat" }
local TARGET_CANT_TAGS = { "INLIMBO", "flight", "notarget", "noattack" }
local TARGET_ONEOF_TAGS = { "animal", "character", "monster", "shadowminion", "smallcreature", "largecreature" }
local function ph1_DoAOEAttack(inst, range)
    local x,y,z = inst.Transform:GetWorldPosition()
    local targets = TheSim:FindEntities(
		x, y, z, range + AOE_RANGE_PADDING,
        TARGET_MUSTHAVE_TAGS, TARGET_CANT_TAGS, TARGET_ONEOF_TAGS
    )
    inst.components.combat.ignorehitrange = true
	if #targets > 0 then
		inst.components.combat:SetDefaultDamage(TUNING.ALTERGUARDIAN_PHASE1_AOEDAMAGE)
		for _, target in ipairs(targets) do
			if target:IsValid() and not (target.components.health ~= nil and target.components.health:IsDead()) and inst.components.combat:CanTarget(target) then
				local range1 = range + target:GetPhysicsRadius(0)
				if target:GetDistanceSqToPoint(x, y, z) < range1 * range1 then
					inst.components.combat:DoAttack(target)
				end
			end
		end
		inst.components.combat:SetDefaultDamage(TUNING.ALTERGUARDIAN_PHASE1_ROLLDAMAGE)
	end
    inst.components.combat.ignorehitrange = false
end

local ROLL_RANGE_OFFSET = .5
local ROLL_CANT_TAGS = shallowcopy(TARGET_CANT_TAGS)
local function OnUpdateRollAttack(inst)
	local hits = inst.sg.statemem.rollhits
	if hits == nil then
		return
	end
	local x, y, z = inst.Transform:GetWorldPosition()
	local theta = inst.Transform:GetRotation() * DEGREES
	x = x + math.cos(theta) * ROLL_RANGE_OFFSET
	z = z - math.sin(theta) * ROLL_RANGE_OFFSET
    inst.components.combat.ignorehitrange = true
	local targets = TheSim:FindEntities(x, y, z, TUNING.ALTERGUARDIAN_PHASE1_ROLLRANGE + AOE_RANGE_PADDING, TARGET_MUSTHAVE_TAGS, ROLL_CANT_TAGS, TARGET_ONEOF_TAGS)
	if #targets > 0 then
		local hit = false
		for _, target in ipairs(targets) do
			if not hits[target] and target:IsValid() and target.components.health ~= nil and not target.components.health:IsDead() and inst.components.combat:CanTarget(target) then
				local range = TUNING.ALTERGUARDIAN_PHASE1_ROLLRANGE + target:GetPhysicsRadius(0)
				if target:GetDistanceSqToPoint(x, y, z) < range * range then
					inst.components.combat:DoAttack(target)
					hits[target] = true
					hit = true
				end
			end
		end
		if hit then
			ShakeAllCameras(CAMERASHAKE.SIDE, .5, .05, .1, inst, 40)
			inst.SoundEmitter:PlaySound("moonstorm/creatures/boss/alterguardian1/onothercollide")
		end
	end
    inst.components.combat.ignorehitrange = false
end

local function onothercollide(inst, other)
    if not other:IsValid() then
        return

    elseif other:HasTag("smashable") and other.components.health ~= nil then
        other.components.health:Kill()

    elseif other.components.workable ~= nil
            and other.components.workable:CanBeWorked()
            and other.components.workable.action ~= ACTIONS.NET and (TUNING.EPIC_WORLD.STRUCTURE_PROTECTION ~= 1 or
    (other.components.workable.action == ACTIONS.DIG and other:HasTag("stump")) or
    (other.components.workable.action ~= ACTIONS.DIG and not other:HasTag("structure") and not other:HasTag("wall"))
        ) then
        SpawnPrefab("collapse_small").Transform:SetPosition(other.Transform:GetWorldPosition())
        other.components.workable:Destroy(inst)

	elseif other.components.combat ~= nil
		and other.components.health ~= nil and not other.components.health:IsDead()
		and (other:HasTag("wall") or other:HasTag("structure")) and inst.components.combat:CanTarget(other)
		then
        inst.SoundEmitter:PlaySound("moonstorm/creatures/boss/alterguardian1/onothercollide")
        inst.components.combat:DoAttack(other)
    end
end

local COLLISION_DSQ = 42
local function oncollide(inst, other)
    if inst._collisions[other] == nil and other ~= nil and other:IsValid()
            and Vector3(inst.Physics:GetVelocity()):LengthSq() > COLLISION_DSQ then
        ShakeAllCameras(CAMERASHAKE.SIDE, .5, .05, .1, inst, 40)
        inst:DoTaskInTime(2 * FRAMES, onothercollide, other)
        inst._collisions[other] = true
    end
end

local function EnableRollCollision(inst, enable)
    if enable then
        inst.Physics:SetCollisionCallback(oncollide)
        inst._collisions = {}
    else
        inst.Physics:SetCollisionCallback(nil)
        inst._collisions = nil
    end
end

local function phase1_EnterShield(inst)
    inst.components.health.externalabsorbmodifiers:SetModifier(inst, TUNING.ALTERGUARDIAN_PHASE1_SHIELDABSORB, "alterguardian_phase1_shield")
end

local function phase1_ExitShield(inst)
    inst.components.health.externalabsorbmodifiers:RemoveModifier(inst, "alterguardian_phase1_shield")
end

---alterguardian_phase2
local SPIN_CANT_TAGS = { "INLIMBO", "FX", "NOCLICK", "playerghost", "flight", "notarget", "noattack" }
local SPIN_ONEOF_TAGS = {"_health", "CHOP_workable", "HAMMER_workable", "MINE_workable"}
local SPIN_FX_RATE = 10*FRAMES
if TUNING.EPIC_WORLD.STRUCTURE_PROTECTION==1 then
    table.insert(SPIN_CANT_TAGS,"structure")
    table.insert(SPIN_CANT_TAGS,"wall")
end
local function set_lightvalues(inst, val)
    inst.Light:SetIntensity(0.40 + (0.40 * val * val))
    inst.Light:SetRadius(4 * val)
    inst.Light:SetFalloff(0.85)
end

local function phase2_play_foley(inst)
    inst.SoundEmitter:PlaySound("moonstorm/creatures/boss/alterguardian2/foley")
end

local function phase2_play_step(inst)
    inst.SoundEmitter:PlaySound("moonstorm/creatures/boss/alterguardian2/step")
end

local NUM_SMALLGUARDS = 5
local Z_SPAWN_DIFF = 0.50
local X_SPAWN_DIFF = 1.75 * 2
local function do_gestalt_summon(inst)
    local target = inst.components.combat.target
    if target == nil then
        return
    end

    local tpos = target:GetPosition()
    local ipos = inst:GetPosition()

    local itot_normal, itot_len = (tpos - ipos):GetNormalizedAndLength()
    local itot_perp = Vector3(itot_normal.z, 0, -itot_normal.x)

    local spawn_len = math.max(2, itot_len - 4)
    local spawn_start = ipos + (itot_normal * spawn_len) + (itot_perp * GetRandomWithVariance(0, 0.5))
    for i = 1, NUM_SMALLGUARDS do
        inst:DoTaskInTime((i-1)*3*FRAMES, function(inst2)
            local spawn_pos = spawn_start
            if i ~= 1 then
                -- At each step, go "back" (towards the boss) a little bit, (RoundBiasedUp)
                -- then spawn subsequent objects on opposite sides. (IsNumberEven)
                local num_steps = RoundBiasedUp((i-1) / 2)
                local x_step, z_step = nil, nil
                if IsNumberEven(i) then
                    z_step = -1 * Z_SPAWN_DIFF * num_steps
                    x_step = X_SPAWN_DIFF * num_steps
                else
                    z_step = -1 * Z_SPAWN_DIFF * num_steps
                    x_step = -1 * X_SPAWN_DIFF * num_steps
                end
                spawn_pos = spawn_pos + (itot_normal*z_step) + (itot_perp*x_step)
            end

            local smallguard = SpawnPrefab("smallguard_alterguardian_projectile")
            smallguard.Transform:SetPosition(spawn_pos:Get())
            smallguard:SetTargetPosition(spawn_pos + itot_normal)
        end)
    end
end

local function spawn_spike_with_target(inst, data)
    if not data then
        return
    end

    local spawn_vec = data.spawn_pos or inst:GetPosition()

    local spike = SpawnPrefab("alterguardian_phase2spiketrail")
    spike.Transform:SetPosition(spawn_vec.x, 0, spawn_vec.z)
    spike.Transform:SetRotation(data.angle)
    spike:SetOwner(inst)
end

local MIN_SPIKE_COUNT, MAX_SPIKE_COUNT = 3, 4
local SPIKE_DSQ = TUNING.ALTERGUARDIAN_PHASE2_SPIKE_RANGE * TUNING.ALTERGUARDIAN_PHASE2_SPIKE_RANGE
local SPIKE_SPAWN_DELAY = 15*FRAMES
local SPIKEATTACK_CANT_TAGS = {"INLIMBO", "playerghost","player"}

local function DoSpikeAttack(inst)
    local ipos = inst:GetPosition()

    local spikes_to_spawn = GetRandomMinMax(MIN_SPIKE_COUNT, MAX_SPIKE_COUNT)
    local spikes_spawned = 0

    local angles_chosen = {}

    for _, p in ipairs(AllPlayers) do
        if not p:HasTag("playerghost") and p.entity:IsVisible()
                and (p.components.health ~= nil and not p.components.health:IsDead())
                and p:GetDistanceSqToPoint(ipos:Get()) < SPIKE_DSQ and inst.components.combat:CanTarget(p) then
            local firing_angle = inst:GetAngleToPoint(p.Transform:GetWorldPosition())
            table.insert(angles_chosen, firing_angle)

            local spawn_data =
            {
                spawn_pos = ipos,
                angle = firing_angle,
            }
            inst:DoTaskInTime(SPIKE_SPAWN_DELAY*spikes_spawned, spawn_spike_with_target, spawn_data)
            spikes_spawned = spikes_spawned + 1
            if spikes_spawned >= spikes_to_spawn then
                break
            end
        end
    end

    if spikes_spawned >= spikes_to_spawn then
        return
    end

    -- There are still spikes we could spawn, so look for other entities that are targetable.

    local ix, iy, iz = ipos:Get()
    local targetable_entities = TheSim:FindEntities(
        ix, iy, iz, TUNING.ALTERGUARDIAN_PHASE2_SPIKE_RANGE,
        { "_combat" }, SPIKEATTACK_CANT_TAGS)
    if #targetable_entities <= 0 then
        return
    end

    for _, p in ipairs(targetable_entities) do
        if p.components.health ~= nil and not p.components.health:IsDead() then
            local firing_angle = inst:GetAngleToPoint(p.Transform:GetWorldPosition())
            table.insert(angles_chosen, firing_angle)

            local spawn_data =
            {
                spawn_pos = ipos,
                angle = firing_angle,
            }
            inst:DoTaskInTime(SPIKE_SPAWN_DELAY*spikes_spawned, spawn_spike_with_target, spawn_data)
            spikes_spawned = spikes_spawned + 1
            if spikes_spawned >= spikes_to_spawn then
                break
            end
        end
    end

    if spikes_spawned >= spikes_to_spawn then
        return
    end

    -- We STILL have spikes remaining. So try to just pick random angles
    -- that are some amount different than the ones we've already chosen.
    local spikes_remaining = spikes_to_spawn - spikes_spawned
    for i=1, spikes_remaining do
        local start_angle = 360*math.random()
        local firing_angle = nil
        for ang = 0, 360, 60 do
            local possible_angle = start_angle + ang
            local angle_valid = true
            for _, used_ang in ipairs(angles_chosen) do
                if math.abs(possible_angle - used_ang) < 30 then
                    angle_valid = false
                    break
                end
            end

            if angle_valid then
                firing_angle = possible_angle
                break
            end
        end

        if firing_angle then
            table.insert(angles_chosen, firing_angle)
            local spawn_data =
            {
                spawn_pos = ipos,
                angle = firing_angle,
            }
            inst:DoTaskInTime(SPIKE_SPAWN_DELAY*spikes_spawned, spawn_spike_with_target, spawn_data)
        end
    end
end

local function spawn_spintrail(inst)
    local facing_dir = inst.Transform:GetRotation() * DEGREES
    local spawn_pt = inst:GetPosition() --- Vector3(1.5 * math.cos(facing_dir), 0, -1.5 * math.sin(facing_dir))
    SpawnPrefab("alterguardian_spintrail_fx").Transform:SetPosition(spawn_pt:Get())
    SpawnPrefab("mining_moonglass_fx").Transform:SetPosition(spawn_pt:Get())
end

---alterguardian_phase3
local LUCKFORMULA_RECIPROCAL = 3
local function SpawnLargeGestaltChanceMult(inst, chance, luck)
    return luck < 0 and chance * (1 + math.abs(luck))
        or luck > 0 and chance * (LUCKFORMULA_RECIPROCAL / (LUCKFORMULA_RECIPROCAL + luck))
end
local function do_summon_spawn(inst)
    local target_in_range = false
    local ix, _, iz = inst.Transform:GetWorldPosition()
    for i, p in ipairs(AllPlayers) do
        local dsq_to_player = p:GetDistanceSqToPoint(ix, 0, iz)
        if dsq_to_player < TUNING.ALTERGUARDIAN_PHASE3_SUMMONRSQ and p~=inst and TheNet:GetPVPEnabled() and not p:HasTag("epic") then
            -- Don't count ghosts, and don't "sleep-camp" players that are knocked out.
            if (p.components.grogginess ~= nil and not p.components.grogginess:IsKnockedOut())
                    and not p:HasTag("playerghost") then
                target_in_range = true

                local spawn_prefab = TryLuckRoll(p, TUNING.ALTERGUARDIAN_SPAWN_LARGE_GESTALT_PROJECTILE_CHANCE, SpawnLargeGestaltChanceMult)
                    and "largeguard_alterguardian_projectile"
                    or "gestalt_alterguardian_projectile"
                local gestalt = SpawnPrefab(spawn_prefab)

                local px, py, pz = p.Transform:GetWorldPosition()

                local radius = GetRandomMinMax(3, 5)
                local angle = (inst:GetAngleToPoint(px, py, pz) + GetRandomMinMax(-90, 90)) * DEGREES
                gestalt.Transform:SetPosition(
                    px + radius * math.cos(angle),
                    py,
                    pz + radius * -math.sin(angle)
                )
                gestalt:ForceFacePoint(px, py, pz)
                gestalt:SetTargetPosition(Vector3(px, py, pz))
            end
        end
    end

    local summon_radius = math.sqrt(TUNING.ALTERGUARDIAN_PHASE3_SUMMONRSQ)
    for i, v in ipairs(TheSim:FindEntities(ix, 0, iz, summon_radius, {"_combat","_health"}, {"INLIMBO", "notarget", "noattack","FX","brightmareboss", "brightmare","epic"})) do
        if v~=inst and (v.components.sleeper and not v.components.sleeper:IsAsleep() or v:HasTag("shadow_aligned") ) then
            local spawn_prefab = v:HasTag("shadow_aligned") and "largeguard_alterguardian_projectile" or math.random()<0.6 and "largeguard_alterguardian_projectile" or "gestalt_alterguardian_projectile" 
            local gestalt = SpawnPrefab(spawn_prefab)

            local vx, vy, vz = v.Transform:GetWorldPosition()

            local radius = GetRandomMinMax(3, 5)
            local angle = (inst:GetAngleToPoint(vx, vy, vz) + GetRandomMinMax(-90, 90)) * DEGREES
            gestalt.Transform:SetPosition(
                vx + radius * math.cos(angle),
                vy,
                vz + radius * -math.sin(angle)
            )
            gestalt:ForceFacePoint(vx, vy, vz)
            gestalt:SetTargetPosition(Vector3(vx, vy, vz))
            target_in_range = true
        end    
    end

    if not target_in_range then
        inst.sg.statemem.ready_to_finish = true
    end
end

local TRIBEAM_ANGLEOFF = PI/5
local TRIBEAM_COS = math.cos(TRIBEAM_ANGLEOFF)
local TRIBEAM_SIN = math.sin(TRIBEAM_ANGLEOFF)
local TRIBEAM_COSNEG = math.cos(-TRIBEAM_ANGLEOFF)
local TRIBEAM_SINNEG = math.sin(-TRIBEAM_ANGLEOFF)

local SECOND_BLAST_TIME = 22*FRAMES

local NUM_STEPS = 10
local STEP = 1.0
local OFFSET = 2 - STEP
local function SpawnBeam(inst, target_pos)
    if target_pos == nil then
        return
    end

    local ix, iy, iz = inst.Transform:GetWorldPosition()

    -- This is the "step" of fx spawning that should align with the position the beam is targeting.
    local target_step_num = RoundBiasedUp(NUM_STEPS * 2/5)

    local angle = nil

    -- gx, gy, gz is the point of the actual first beam fx
    local gx, gy, gz = nil, 0, nil
    local x_step = STEP
    if inst:GetDistanceSqToPoint(target_pos:Get()) < 4 then
        angle = math.atan2(iz - target_pos.z, ix - target_pos.x)

        -- If the target is too close, use the minimum distance
        gx, gy, gz = inst.Transform:GetWorldPosition()
        gx = gx + (2 * math.cos(angle))
        gz = gz + (2 * math.sin(angle))
    else
        angle = math.atan2(iz - target_pos.z, ix - target_pos.x)

        gx, gy, gz = target_pos:Get()
        gx = gx + (target_step_num * STEP * math.cos(angle))
        gz = gz + (target_step_num * STEP * math.sin(angle))
    end

    local targets, skiptoss = {[inst] = true}, {}
    local sbtargets, sbskiptoss = {[inst] = true}, {}
    local x, z = nil, nil
    local trigger_time = nil

    local i = -1
    while i < NUM_STEPS do
        i = i + 1
        x = gx - i * x_step * math.cos(angle)
        z = gz - i * STEP * math.sin(angle)

        local first = (i == 0)
        local prefab = (i > 0 and "epic_alterguardian_laser") or "alterguardian_laserempty"
        local x1, z1 = x, z

        trigger_time = math.max(0, i - 1) * FRAMES

        inst:DoTaskInTime(trigger_time, function(inst2)
            local fx = SpawnPrefab(prefab)
            fx.caster = inst
            fx.Transform:SetPosition(x1, 0, z1)
            fx:Trigger(0, targets, skiptoss)
            if first then
                ShakeAllCameras(CAMERASHAKE.FULL, .7, .02, .2, target_pos or fx, 30)
            end
        end)

        inst:DoTaskInTime(trigger_time + SECOND_BLAST_TIME, function(inst2)
            local fx = SpawnPrefab(prefab)
            fx.caster = inst
            fx.Transform:SetPosition(x1, 0, z1)
            fx:Trigger(0, sbtargets, sbskiptoss, true)
            if first then
                ShakeAllCameras(CAMERASHAKE.FULL, .7, .02, .2, target_pos or fx, 30)
            end
        end)
    end

    inst:DoTaskInTime(i*FRAMES, function(inst2)
        local fx = SpawnPrefab("epic_alterguardian_laser")
        fx.caster = inst
        fx.Transform:SetPosition(x, 0, z)
        fx:Trigger(0, targets, skiptoss)
    end)

    inst:DoTaskInTime((i+1)*FRAMES, function(inst2)
        local fx = SpawnPrefab("epic_alterguardian_laser")
        fx.caster = inst
        fx.Transform:SetPosition(x, 0, z)
        fx:Trigger(0, targets, skiptoss)
    end)
end

local function SpawnTrapProjectile(inst, target_positions)
    local target_position = table.remove(target_positions)

    local projectile = SpawnPrefab("epic_alterguardian_phase3trapprojectile")
    projectile.Transform:SetPosition(target_position:Get())
    projectile:SetGuardian(inst)

    if #target_positions > 0 then
        -- Spawn the projectiles, in a tail-recursive-style way.
        inst:DoTaskInTime(0.5, SpawnTrapProjectile, target_positions)
    end
end
local TRAP_PLAYERCOUNT_DSQ = TUNING.ALTERGUARDIAN_PHASE3_TARGET_DIST^2
local function DoTraps(inst, basetrapcount, minrange, maxrange)
    local position = inst:GetPosition()
    local px, py, pz = position:Get()

    -- Add extra traps based on the number of nearby players.
    local num_traps = basetrapcount or 4
    local num_players = 0
    if TheNet:GetPVPEnabled() then
        for _, v in ipairs(AllPlayers) do
            if not v:HasTag("playerghost") and v.entity:IsVisible()
                    and v:GetDistanceSqToPoint(px, py, pz) < TRAP_PLAYERCOUNT_DSQ and v~=inst then
                num_players = num_players + 1
            end
        end
    else
        num_players = math.random(6)
    end
    
    num_traps = num_traps + RoundBiasedDown(num_players/2)

    local initial_offset = PI2 * math.random()

    local angles = {}
    for i = 1, num_traps do
        local delta = (1.5 + 0.5*math.random()) * PI / num_traps
        table.insert(angles, i*delta + initial_offset)
    end
    shuffleArray(angles)

    local target_positions = {}
    for i = 1, #angles do
        local range = minrange + math.sqrt(math.random()) * maxrange
        local offset = FindWalkableOffset(position, angles[i], range, 12, true, true, NoHoles)
        if offset ~= nil then
            -- Turn the offset into a world position.
            offset.x = offset.x + position.x
            offset.y = 0
            offset.z = offset.z + position.z
            table.insert(target_positions, offset)
        end
    end

    if #target_positions > 0 then
        -- Spawn the projectiles, in a tail-recursive-style way.
        inst:DoTaskInTime(0.5, SpawnTrapProjectile, target_positions)
    end
end

local BASE_NUM_ANGULAR_STEPS = 10
local SWEEP_ANGULAR_LENGTH = 75
local BASE_SWEEP_DISTANCE = 8
local MIN_SWEEP_DISTANCE = 3
local function SpawnSweep(inst, target_pos)
    local gx, gy, gz = inst.Transform:GetWorldPosition()

    local angle = nil
    local dist = nil
    local angle_step_dir = 1
    local x_dir = 1

    if target_pos == nil then
        angle = DEGREES * (inst.Transform:GetRotation() + (SWEEP_ANGULAR_LENGTH/2))
        dist = BASE_SWEEP_DISTANCE
        x_dir = -1
        angle_step_dir = -1
    else
        angle = math.atan2(gz - target_pos.z, gx - target_pos.x) - (SWEEP_ANGULAR_LENGTH * DEGREES/2)
        dist = math.max(math.sqrt(inst:GetDistanceSqToPoint(target_pos:Get())), MIN_SWEEP_DISTANCE)
    end

    local num_angle_steps = BASE_NUM_ANGULAR_STEPS + RoundBiasedDown((math.abs(dist) - BASE_SWEEP_DISTANCE) / 2)
    local angle_step = (SWEEP_ANGULAR_LENGTH / num_angle_steps) * DEGREES

    local targets, skiptoss = {}, {}
    local sbtargets, sbskiptoss = {}, {}
    local x, z = nil, nil
    local delay = nil

    local i = -1
    while i < num_angle_steps do
        i = i + 1
        delay = math.max(0, i - 1)*FRAMES

        x = gx - (x_dir * dist * math.cos(angle))
        z = gz - dist * math.sin(angle)
        angle = angle + (angle_step_dir * angle_step)

        -- Assign loop-local values to be captured (we still need x and z for post-loop)
        local first = (i == 0)
        local x1, z1 = x, z
        inst:DoTaskInTime(delay, function(inst2)
            local fx = SpawnPrefab("epic_alterguardian_laser")
            fx.caster = inst
            fx.Transform:SetPosition(x1, 0, z1)
            fx:Trigger(0, targets, skiptoss)
            if first then
                ShakeAllCameras(CAMERASHAKE.FULL, .7, .02, .6, target_pos or fx, 30)
            end
        end)

        inst:DoTaskInTime(delay + SECOND_BLAST_TIME, function(inst2)
            local fx = SpawnPrefab("epic_alterguardian_laser")
            fx.caster = inst
            fx.Transform:SetPosition(x1, 0, z1)
            fx:Trigger(0, sbtargets, sbskiptoss, true)
            if first then
                ShakeAllCameras(CAMERASHAKE.FULL, .7, .02, .6, target_pos or fx, 30)
            end
        end)
    end

    inst:DoTaskInTime(i*FRAMES, function(inst2)
        local fx = SpawnPrefab("epic_alterguardian_laser")
        fx.caster = inst
        fx.Transform:SetPosition(x, 0, z)
        fx:Trigger(0, targets, skiptoss)
    end)

    inst:DoTaskInTime((i+1)*FRAMES, function(inst2)
        local fx = SpawnPrefab("epic_alterguardian_laser")
        fx.caster = inst
        fx.Transform:SetPosition(x, 0, z)
        fx:Trigger(0, targets, skiptoss)
    end)
end

local function start_summon_circle(inst)
    local ix, iy, iz = inst.Transform:GetWorldPosition()
    if inst.sg.mem.summon_circle == nil then
        inst.sg.mem.summon_circle = SpawnPrefab("alterguardian_phase3circle")
        inst.sg.mem.summon_circle.Transform:SetPosition(ix, iy, iz)
    end

    if inst.sg.mem.summon_fx == nil then
        inst.sg.mem.summon_fx = SpawnPrefab("alterguardian_summon_fx")
        inst.sg.mem.summon_fx.Transform:SetScale(1.3, 1.3, 1.3)
        inst.sg.mem.summon_fx.Transform:SetPosition(inst.Transform:GetWorldPosition())
    end
end

local function stop_summon_circle(inst)
    if inst.sg.mem.summon_circle ~= nil and inst.sg.mem.summon_circle:IsValid() then
        inst.sg.mem.summon_circle:Remove()
        inst.sg.mem.summon_circle = nil
    end

    if inst.sg.mem.summon_fx ~= nil and inst.sg.mem.summon_fx:IsValid() then
        inst.sg.mem.summon_fx:PushEvent("endloop")
        inst.sg.mem.summon_fx = nil
    end
end

---stalker_atrium
local function SetBlinkLevel(inst, level)
    inst.AnimState:SetAddColour(level, level, level, 0)
    inst.AnimState:SetLightOverride(math.min(1, (inst.sg.statemem.baselightoverride or 0) + level))
end

local function BlinkHigh(inst) SetBlinkLevel(inst, 1) end
local function BlinkMed(inst) SetBlinkLevel(inst, .3) end
local function BlinkLow(inst) SetBlinkLevel(inst, .2) end
local function BlinkOff(inst) SetBlinkLevel(inst, 0) end

---ancient_hulk
local hulk_NOTAGS = { "playerghost", "INLIMBO", "DECOR", "FX" }
local hulk_DAMAGE_ONEOF_TAGS = { "_combat", "pickable", "NPC_workable", "CHOP_workable", "HAMMER_workable", "MINE_workable", "DIG_workable" }
if not TheNet:GetPVPEnabled() then
    table.insert(hulk_NOTAGS,"player")
end
if TUNING.EPIC_WORLD.STRUCTURE_PROTECTION==1 then
    table.insert(hulk_NOTAGS,"structure")
    table.insert(hulk_NOTAGS,"wall")
end
local function setfires(inst,x, y, z, rad)
    for i, v in ipairs(TheSim:FindEntities(x, 0, z, rad, nil,hulk_NOTAGS,hulk_DAMAGE_ONEOF_TAGS)) do
        if v.components.burnable and v~=inst then
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
            elseif v:IsValid() and v.components.health and inst.components.combat:CanTarget(v) then
                inst.components.combat:DoAttack(v)
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

local function ancient_hulk_DoDamage(inst, rad, startang, endang, spawnburns)
    local targets = {}
    local x, y, z = inst.Transform:GetWorldPosition()
    local angle = nil

    if startang and endang then
        startang = startang + 90
        endang = endang + 90
        angle = inst.Transform:GetRotation()
    end

    inst.components.combat.ignorehitrange = true

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

    inst.components.combat.ignorehitrange = false
end

AddStategraphState("wilson",State{
		name = "epic_attack",
		tags = epic_attack_tags_sever,

		onenter = function(inst)
            if inst.components.combat:InCooldown() then
                inst.sg:RemoveStateTag("abouttoattack")
                inst:ClearBufferedAction()
                inst.sg:GoToState("epic_idle", true)
                return
            end
			local mode = inst.components.wereepic and inst.components.wereepic:GetEpicMode()
            local buffaction = inst:GetBufferedAction()
            local target = buffaction ~= nil and buffaction.target or nil
			inst.components.combat:SetTarget(target)
            inst.components.combat:StartAttack()
            inst.components.locomotor:Stop()
            if mode=="antlion" then
                inst.AnimState:PlayAnimation("cast_pre")
                inst.AnimState:PushAnimation("cast_pst")
            elseif mode=="daywalker" then
                inst.AnimState:PlayAnimation("atk_slam_pre")
                inst.AnimState:PushAnimation("atk_slam")
            elseif mode=="daywalker2" then
                inst.AnimState:PlayAnimation("atk_object")
                inst.AnimState:PushAnimation("atk_object_pst")
                inst.SoundEmitter:PlaySound("daywalker/voice/speak_short")
			    inst.SoundEmitter:PlaySound("dontstarve/wilson/attack_whoosh")
                inst.components.combat:SetDefaultDamage(TUNING.DAYWALKER2_ATTACK_SWING_DAMAGE)
            elseif mode=="alterguardian_phase1" then
                inst.AnimState:PlayAnimation("tantrum_pre")
                inst.AnimState:PushAnimation("tantrum_loop")
                inst.AnimState:PushAnimation("tantrum_loop")
                inst.AnimState:PushAnimation("tantrum_loop")
                inst.AnimState:PushAnimation("tantrum_pst")
            elseif mode=="alterguardian_phase2" then
                inst.AnimState:PlayAnimation("attk_chop")
                local num = inst.replica.wereepic:GetPh2Atk()
                if num>0 then
                    inst.SoundEmitter:PlaySound("moonstorm/creatures/boss/alterguardian2/summon")
                    inst.sg.mem.summon_fx = SpawnPrefab("alterguardian_summon_fx")
                    inst.sg.mem.summon_fx.Transform:SetScale(1.3, 1.3, 1.3)
                    inst.sg.mem.summon_fx.Transform:SetPosition(inst.Transform:GetWorldPosition())
                    inst.sg.statemem.ph2_summon = true
                    inst.replica.wereepic._phase2:set(num-1)
                else
                    inst.sg.statemem.ph2_summon = false
                end
            elseif mode=="alterguardian_phase3" then
                inst.AnimState:PlayAnimation("attk_stab")
                inst.SoundEmitter:PlaySound("moonstorm/creatures/boss/alterguardian3/atk_stab")
            elseif mode=="stalker_atrium" then
                inst.AnimState:PlayAnimation("attack")
                inst.SoundEmitter:PlaySound("dontstarve/creatures/together/stalker/out")
            elseif mode=="mutatedbearger" then
                if inst.AnimState:IsCurrentAnimation("atk1") or inst.AnimState:IsCurrentAnimation("atk1_pst") or inst.AnimState:IsCurrentAnimation("atk1a") then
                    inst.AnimState:PlayAnimation("atk2")
                    inst.AnimState:PushAnimation("atk2_pst", false)
                    inst.sg.statemem.mutatedbearger_combo = true
                    inst.SoundEmitter:PlaySound("dontstarve_DLC001/creatures/bearger/attack")
                elseif inst.AnimState:IsCurrentAnimation("atk2") or inst.AnimState:IsCurrentAnimation("atk2_pst") then
                    inst.AnimState:PlayAnimation("atk1a")
                    inst.AnimState:PushAnimation("atk1_pst", false)
                    inst.sg.statemem.mutatedbearger_combo = true
                    inst.SoundEmitter:PlaySound("dontstarve_DLC001/creatures/bearger/attack")
                else
                    inst.AnimState:PlayAnimation("atk1")
				    inst.AnimState:PushAnimation("atk1_pst", false)
                    inst.sg.statemem.mutatedbearger_combo = false
                end
            elseif mode=="ancient_hulk" then
                inst.AnimState:PlayAnimation("atk_chomp")
            else
                inst.AnimState:PlayAnimation("atk")
            end

            if mode=="bearger" or mode=="daywalker" or mode=="mutatedbearger" then
                if mode=="bearger" or mode=="mutatedbearger" then
                    inst.Transform:SetEightFaced()
                end
                if target ~= nil and target:IsValid() then
                    inst.sg.statemem.target = target
                    inst.sg.statemem.targetpos = target:GetPosition()
                    local x1, y1, z1 = target.Transform:GetWorldPosition()
                    local rot = inst.Transform:GetRotation()
                    local rot1 = inst:GetAngleToPoint(x1, y1, z1)
                    local diff = DiffAngle(rot, rot1)
                    if diff < 90 then
                        inst.Transform:SetRotation(rot1)
                    end
                end
                if mode=="daywalker" then
                    inst.sg.statemem.speedmult = 1
                    inst.sg.statemem.speed = 2
                    inst.sg.statemem.decel = 0
                    inst.Physics:SetMotorVelOverride(2, 0, 0)
                end
            elseif mode=="deerclops" or mode=="daywalker2" or mode=="alterguardian_phase2" or mode=="mutatedwarg" or mode=="mutateddeerclops" then
                if target ~= nil and target:IsValid() then
                    inst:ForceFacePoint(target.Transform:GetWorldPosition())
                    inst.sg.statemem.target = target
                end
                if mode=="deerclops" or mode=="mutatedwarg" or mode=="mutateddeerclops" then
                    inst.SoundEmitter:PlaySound(EPIC[mode].sounds.attack)
                end
            elseif mode=="antlion" then
                if target ~= nil and target:IsValid() then
                    inst.sg.statemem.target = target
                    inst.sg.statemem.targetpos = target:GetPosition()
                    inst.sg.statemem.targetpos.y = 0
                end
            elseif mode=="dragonfly" then
                inst.sg.statemem.target = target
                if inst:HasTag("dragonfly_enraged") then
                    local attackfx = SpawnPrefab("attackfire_fx")
                    attackfx.Transform:SetPosition(inst.Transform:GetWorldPosition())
                    attackfx.Transform:SetRotation(inst.Transform:GetRotation())
                end
            else
                inst.sg.statemem.target = target
            end

            if target ~= nil then
                if target:IsValid() then
                    inst.sg.statemem.attacktarget = target
                    inst.sg.statemem.retarget = target
                end
            end

            inst.sg.statemem.isattack = buffaction.action == ACTIONS.ATTACK or nil
			inst.sg.statemem.epicmode = mode
			inst.sg.statemem.original_target = target

            if EPIC[mode].attack_timeout then
                inst.sg:SetTimeout(EPIC[mode].attack_timeout)
            else
                inst.sg:SetTimeout(inst.AnimState:GetCurrentAnimationLength()- 6 * FRAMES)
            end
		end,

		onupdate = function(inst)
			if inst.sg.statemem.target ~= nil then
				if inst.sg.statemem.target:IsValid() then
                    if inst.sg.statemem.epicmode=="deerclops" or inst.sg.statemem.epicmode=="daywalker2" or
                    inst.sg.statemem.epicmode=="alterguardian_phase2" or inst.sg.statemem.epicmode=="mutateddeerclops" then
                        local rot = inst.Transform:GetRotation()
                        local rot1 = inst:GetAngleToPoint(inst.sg.statemem.target.Transform:GetWorldPosition())
                        if DiffAngle(rot, rot1) < 45 then
                            inst.Transform:SetRotation(rot1)
                            return
                        end
                    elseif inst.sg.statemem.epicmode=="bearger" or inst.sg.statemem.epicmode=="daywalker" or inst.sg.statemem.epicmode=="mutatedbearger" then
                        local p = inst.sg.statemem.targetpos
                        p.x, p.y, p.z = inst.sg.statemem.target.Transform:GetWorldPosition()
                        if inst.sg.statemem.targetpos ~= nil then
                            local rot = inst.Transform:GetRotation()
                            local rot1 = inst:GetAngleToPoint(inst.sg.statemem.targetpos)
                            local drot = ReduceAngle(rot1 - rot)
                            if math.abs(drot) < 90 then
                                rot1 = rot + math.clamp(drot / 2, -1, 1)
                                inst.Transform:SetRotation(rot1)
                            end
                        end
                    elseif inst.sg.statemem.epicmode=="antlion" then
                        local x, y, z = inst.sg.statemem.target.Transform:GetWorldPosition()
                        inst.sg.statemem.targetpos.x, inst.sg.statemem.targetpos.z = x, z
                    end
                    if inst.sg.statemem.epicmode=="daywalker" then
                        if inst.sg.statemem.decel ~= 0 then
                            if inst.sg.statemem.speed <= 0 then
                                inst.Physics:ClearMotorVelOverride()
                                inst.Physics:Stop()
                                inst.sg.statemem.decel = 0
                            else
                                inst.Physics:SetMotorVelOverride(inst.sg.statemem.speed * inst.sg.statemem.speedmult, 0, 0)
                                inst.sg.statemem.speed = inst.sg.statemem.speed + inst.sg.statemem.decel
                            end
                        end
                    end
				end
			end
		end,

		timeline =
		{
            FrameEvent(0, function(inst)
                if inst.sg.statemem.epicmode=="malbatross" then
                    inst.SoundEmitter:PlaySound("saltydog/creatures/boss/malbatross/attack_call")
                elseif inst.sg.statemem.epicmode=="beequeen" then
                    inst.SoundEmitter:PlaySound("dontstarve/creatures/together/bee_queen/attack_pre")
                elseif inst.sg.statemem.epicmode=="daywalker" then
                    inst.SoundEmitter:PlaySound("daywalker/voice/hurt")
				    inst.SoundEmitter:PlaySound("daywalker/action/step", nil, 0.3)
                end
            end),
            FrameEvent(3, function(inst)
                if inst.sg.statemem.epicmode=="antlion" then
                    if inst.sg.statemem.targetpos ~= nil then
                        SpawnSpikes(inst, inst.sg.statemem.targetpos, math.random(6, 7))
                        inst.sg.statemem.target = nil
                    end
                    if not inst.sg.statemem.isattack then
                        inst:PerformBufferedAction()
                    else
                        inst:ClearBufferedAction()
                    end
                    inst.sg:RemoveStateTag("abouttoattack")
                elseif inst.sg.statemem.epicmode=="stalker_atrium" then
                    inst.SoundEmitter:PlaySound("dontstarve/creatures/together/stalker/head")
                end
            end),
            FrameEvent(4, function(inst)
                if inst.sg.statemem.epicmode=="bearger" or (inst.sg.statemem.epicmode=="mutatedbearger" and not inst.sg.statemem.mutatedbearger_combo) then
                    inst.SoundEmitter:PlaySound(EPIC[inst.sg.statemem.epicmode].sounds.attack)
                end
            end),
            FrameEvent(7, function(inst)
                if inst.sg.statemem.epicmode=="dragonfly" then
                    inst.SoundEmitter:PlaySound("dontstarve_DLC001/creatures/dragonfly/swipe")
                end
            end),
            FrameEvent(8, function(inst)
                if inst.sg.statemem.epicmode=="antlion" then
                    inst.SoundEmitter:PlaySound("dontstarve/creatures/together/antlion/cast_pre")
                elseif inst.sg.statemem.epicmode=="alterguardian_phase2" and not inst.sg.statemem.ph2_summon then
                    inst.SoundEmitter:PlaySound("moonstorm/creatures/boss/alterguardian2/scream")
                elseif inst.sg.statemem.epicmode=="ancient_hulk" then
                    inst.SoundEmitter:PlaySound("mnh_ancient_hulk_sound/creatures/boss/hulk_metal_robot/dig")
                end
            end),
            FrameEvent(9, function(inst)
                if inst.sg.statemem.epicmode=="daywalker2" then
                    inst.SoundEmitter:PlaySound("qol1/daywalker_scrappy/objectswing_f15")
                end
            end),
            FrameEvent(11, function(inst)
                if inst.sg.statemem.epicmode=="mutatedwarg" then
                    inst.components.combat:DoAttack(inst.sg.statemem.target)
                    if not inst.sg.statemem.isattack then
                        inst:PerformBufferedAction()
                    else
                        inst:ClearBufferedAction()
                    end
                    inst.sg:RemoveStateTag("abouttoattack")
                end
            end),
            FrameEvent(12, function(inst)
                if inst.sg.statemem.epicmode=="daywalker2" then
                    daywalker2_SpawnSwipeFX(inst, 1, true)
                end
            end),
            FrameEvent(13, function(inst)
                if inst.sg.statemem.epicmode=="malbatross" then
                    inst.SoundEmitter:PlaySound("saltydog/creatures/boss/malbatross/attack_swipe_water")
                elseif inst.sg.statemem.epicmode=="stalker_atrium" then
                    inst.SoundEmitter:PlaySound("dontstarve/creatures/together/stalker/attack_swipe")
                end
            end),
            FrameEvent(14, function(inst)
                if inst.sg.statemem.epicmode=="beequeen" then
                    inst.SoundEmitter:PlaySound("dontstarve/creatures/together/bee_queen/attack")
                    inst.components.combat:DoAttack(inst.sg.statemem.target)
                    if not inst.sg.statemem.isattack then
                        inst:PerformBufferedAction()
                    else
                        inst:ClearBufferedAction()
                    end
                    inst.sg:RemoveStateTag("abouttoattack")
                end
            end),
            FrameEvent(15, function(inst)
                if inst.sg.statemem.epicmode=="dragonfly" then
                    inst.SoundEmitter:PlaySound("dontstarve_DLC001/creatures/dragonfly/punchimpact")
                    local target = inst.sg.statemem.target
                    inst.components.combat:DoAttack(target)
                    if inst:HasTag("dragonfly_enraged") and target ~= nil and target.components.health ~= nil and not target.components.health:IsDead() and target:IsValid() then
                        target.components.health:DoFireDamage(5, inst, true)
                    end
                    if not inst.sg.statemem.isattack then
                        inst:PerformBufferedAction()
                    else
                        inst:ClearBufferedAction()
                    end
                    inst.sg:RemoveStateTag("abouttoattack")
                elseif inst.sg.statemem.epicmode=="ancient_hulk" then
                    inst.components.combat:DoAttack(inst.sg.statemem.target)
                    if not inst.sg.statemem.isattack then
                        inst:PerformBufferedAction()
                    else
                        inst:ClearBufferedAction()
                    end
                    inst.sg:RemoveStateTag("abouttoattack")
                end
            end),
            FrameEvent(16, function(inst)
                if inst.sg.statemem.epicmode=="daywalker2" then
                    local targets = {}
                    daywalker2_DoArcAttack(inst, 1, 4.5, 240, nil, 0.75, nil, targets)
                    if not inst.sg.statemem.isattack then
                        inst:PerformBufferedAction()
                    else
                        inst:ClearBufferedAction()
                    end
                    inst.sg:RemoveStateTag("abouttoattack")
                end
            end),
            FrameEvent(18, function(inst)
                if inst.sg.statemem.epicmode=="daywalker" then
                    inst.Physics:SetMotorVelOverride(1, 0, 0)
                elseif inst.sg.statemem.ph2_summon then
                    inst.SoundEmitter:PlaySound("dontstarve_DLC001/creatures/bearger/swhoosh")
                end
            end),
            FrameEvent(19, function(inst)
                if inst.sg.statemem.epicmode=="daywalker" then
                    inst.Physics:SetMotorVelOverride(2, 0, 0)
                end
            end),
            FrameEvent(20, function(inst)
                if inst.sg.statemem.epicmode=="moose" then
                    inst.components.combat:DoAttack(inst.sg.statemem.target, nil, nil, "electric")
                    inst.SoundEmitter:PlaySound(EPIC[inst.sg.statemem.epicmode].sounds.attack)
                    if not inst.sg.statemem.isattack then
                        inst:PerformBufferedAction()
                    else
                        inst:ClearBufferedAction()
                    end
                    inst.sg:RemoveStateTag("abouttoattack")
                end
            end),
            FrameEvent(21, function(inst)
                if inst.sg.statemem.epicmode=="daywalker" then
                    inst.SoundEmitter:PlaySound("daywalker/action/attack_slam_whoosh")
                    inst.Physics:SetMotorVelOverride(8, 0, 0)
                elseif inst.sg.statemem.epicmode=="alterguardian_phase2" and not inst.sg.statemem.ph2_summon then
                    inst.SoundEmitter:PlaySound("dontstarve_DLC001/creatures/bearger/swhoosh")
                end
            end),
            FrameEvent(22, function(inst)
                if inst.sg.statemem.epicmode=="daywalker" then
                    inst.SoundEmitter:PlaySound("daywalker/voice/attack_big")
				    inst.SoundEmitter:PlaySound("daywalker/action/step")
                elseif inst.sg.statemem.epicmode=="alterguardian_phase2" then
                    inst.SoundEmitter:PlaySound("moonstorm/creatures/boss/alterguardian2/ground_hit")
                    ShakeAllCameras(CAMERASHAKE.VERTICAL, .75, 0.1, 0.1, inst, 30)
                    if inst.sg.statemem.ph2_summon then
                        inst.SoundEmitter:PlaySound("moonstorm/creatures/boss/alterguardian2/spell_cast")
                    end
                elseif inst.sg.statemem.epicmode=="alterguardian_phase3" then
                    inst.SoundEmitter:PlaySound("moonstorm/creatures/boss/alterguardian3/atk_stab_LP","stab_loop")
                elseif inst.sg.statemem.epicmode=="ancient_hulk" then
                    inst.SoundEmitter:PlaySound("mnh_ancient_hulk_sound/creatures/boss/hulk_metal_robot/drag")
                end
            end),
            FrameEvent(23, function(inst)
                if inst.sg.statemem.epicmode=="alterguardian_phase1" then
                    inst.SoundEmitter:PlaySound("moonstorm/creatures/boss/alterguardian1/tantrum")
                elseif inst.sg.statemem.epicmode=="alterguardian_phase2" then
                    inst.components.combat:DoAttack(inst.sg.statemem.target)
                    if not inst.sg.statemem.isattack then
                        inst:PerformBufferedAction()
                    else
                        inst:ClearBufferedAction()
                    end
                    inst.sg:RemoveStateTag("abouttoattack")
                elseif inst.sg.statemem.mutatedbearger_combo then
                    inst.Physics:SetMotorVelOverride(6, 0, 0)
                end
            end),
            FrameEvent(24, function(inst)
                if inst.sg.statemem.mutatedbearger_combo then
                    inst.SoundEmitter:PlaySound("dontstarve_DLC001/creatures/bearger/swhoosh")
                    inst.Physics:SetMotorVelOverride(12, 0, 0)
                end
            end),
            FrameEvent(25, function(inst)
                if inst.sg.statemem.epicmode=="antlion" then
                    inst.SoundEmitter:PlaySound("dontstarve/creatures/together/antlion/cast_post")
                elseif inst.sg.statemem.epicmode=="alterguardian_phase1" then
                    inst.SoundEmitter:PlaySound("moonstorm/creatures/boss/alterguardian1/tantrum")

                    ph1_tantrum_screenshake(inst)
                    ph1_spawn_landfx(inst)
                elseif inst.sg.statemem.mutatedbearger_combo then
                    SpawnSwipeFX(inst, COMBO_ARC_OFFSET, true)
                end
            end),
            FrameEvent(26, function(inst)
                if inst.sg.statemem.epicmode=="daywalker" then
                    inst.Physics:SetMotorVelOverride(2, 0, 0)
                elseif inst.sg.statemem.epicmode=="alterguardian_phase1" then
                    inst.SoundEmitter:PlaySound("moonstorm/creatures/boss/alterguardian1/tantrum")

                    ph1_DoAOEAttack(inst, TUNING.ALTERGUARDIAN_PHASE1_AOERANGE)

                    if not inst.sg.statemem.isattack then
                        inst:PerformBufferedAction()
                    else
                        inst:ClearBufferedAction()
                    end
                end
            end),
            FrameEvent(27, function(inst)
                if inst.sg.statemem.epicmode=="mutatedbearger" and not inst.sg.statemem.mutatedbearger_combo then
                    inst.Physics:SetMotorVelOverride(6, 0, 0)
                end
            end),
            FrameEvent(28, function(inst)
                if inst.sg.statemem.epicmode=="bearger" then
                    inst.SoundEmitter:PlaySound("dontstarve_DLC001/creatures/bearger/swhoosh")
                elseif inst.sg.statemem.epicmode=="daywalker" then
                    inst.Physics:SetMotorVelOverride(1.5, 0, 0)
                elseif inst.sg.statemem.epicmode=="alterguardian_phase2" and inst.sg.statemem.ph2_summon then
                    do_gestalt_summon(inst)
                elseif inst.sg.statemem.epicmode=="mutatedbearger" and not inst.sg.statemem.mutatedbearger_combo then
                    inst.SoundEmitter:PlaySound("dontstarve_DLC001/creatures/bearger/swhoosh")
                    inst.Physics:SetMotorVelOverride(6, 0, 0)
                elseif inst.sg.statemem.mutatedbearger_combo then
                    inst.sg.statemem.targets = {}
				    DoComboArcAttack(inst, inst.sg.statemem.targets)
                    if not inst.sg.statemem.isattack then
                        inst:PerformBufferedAction()
                    else
                        inst:ClearBufferedAction()
                    end
                    inst.sg:RemoveStateTag("abouttoattack")
                end
            end),
            FrameEvent(29, function(inst)
                if inst.sg.statemem.epicmode=="bearger" then
                    SpawnSwipeFX(inst, 1)
                elseif inst.sg.statemem.epicmode=="antlion" then
                    inst.SoundEmitter:PlaySound("dontstarve/creatures/together/antlion/sfx/ground_break")
                elseif inst.sg.statemem.epicmode=="malbatross" then
                    inst.components.combat:DoAttack(inst.sg.statemem.target)
                    SpawnMalbatrossAttackWaves(inst)
                    if not inst.sg.statemem.isattack then
                        inst:PerformBufferedAction()
                    else
                        inst:ClearBufferedAction()
                    end
                    inst.sg:RemoveStateTag("abouttoattack")
                elseif inst.sg.statemem.epicmode=="alterguardian_phase3" then
                    MooseDoArcAttack(inst)
                    if not inst.sg.statemem.isattack then
                        inst:PerformBufferedAction()
                    else
                        inst:ClearBufferedAction()
                    end
                elseif inst.sg.statemem.epicmode=="mutatedbearger" and not inst.sg.statemem.mutatedbearger_combo then
                    SpawnSwipeFX(inst, 0.5)
                elseif inst.sg.statemem.mutatedbearger_combo then
                    local targets = inst.sg.statemem.targets
                    local original_target = inst.sg.statemem.original_target
                    DoComboArcAttack(inst, targets)
                    DoComboArcWork(inst)
                    if next(targets) == nil then
                        inst:PushEvent("onmissother", { target = original_target }) --for ChaseAndAttack
                    end
                end
			end),
            FrameEvent(30, function(inst)
                if inst.sg.statemem.mutatedbearger_combo then
                    inst.Physics:SetMotorVelOverride(6, 0, 0)
                end
            end),
            FrameEvent(31, function(inst)
                if inst.sg.statemem.mutatedbearger_combo then
                    inst.Physics:SetMotorVelOverride(3, 0, 0)
                end
            end),
			FrameEvent(32, function(inst)
                if inst.sg.statemem.epicmode=="bearger" then
                    inst.sg.statemem.targets = {}
				    DoArcAttack(inst, 1, TUNING.BEARGER_MELEE_RANGE, nil, nil, nil, inst.sg.statemem.targets)
                    if not inst.sg.statemem.isattack then
                        inst:PerformBufferedAction()
                    else
                        inst:ClearBufferedAction()
                    end
                    inst.sg:RemoveStateTag("abouttoattack")
                elseif inst.sg.statemem.epicmode=="deerclops" or inst.sg.statemem.epicmode=="mutateddeerclops" then
                    if not inst.sg.statemem.isattack then
                        inst:PerformBufferedAction()
                    else
                        inst:ClearBufferedAction()
                    end
					SpawnIceFx(inst, inst.sg.statemem.original_target)
                    inst.sg:RemoveStateTag("abouttoattack")
                elseif inst.sg.statemem.epicmode=="antlion" then
                    ShakeAllCameras(CAMERASHAKE.VERTICAL, .3, .02, 1, inst, 30)
                elseif inst.sg.statemem.epicmode=="alterguardian_phase2" and inst.sg.statemem.ph2_summon then
                    inst.sg:RemoveStateTag("attack")
                    inst.sg:RemoveStateTag("busy")
                elseif inst.sg.statemem.epicmode=="stalker_atrium" then
                    inst.components.combat:DoAttack(inst.sg.statemem.target)
                    if not inst.sg.statemem.isattack then
                        inst:PerformBufferedAction()
                    else
                        inst:ClearBufferedAction()
                    end
                    inst.sg:RemoveStateTag("abouttoattack")
                elseif inst.sg.statemem.epicmode=="mutatedbearger" and not inst.sg.statemem.mutatedbearger_combo then
                    inst.sg.statemem.targets = {}
                    DoComboArcAttack(inst, inst.sg.statemem.targets)
                    if not inst.sg.statemem.isattack then
                        inst:PerformBufferedAction()
                    else
                        inst:ClearBufferedAction()
                    end
                    inst.sg:RemoveStateTag("abouttoattack")
                elseif inst.sg.statemem.mutatedbearger_combo then
                    inst.Physics:SetMotorVelOverride(1.5, 0, 0)
                end
			end),
            FrameEvent(33, function(inst)
				if inst.sg.statemem.epicmode=="bearger" then
                    local targets = inst.sg.statemem.targets
                    local original_target = inst.sg.statemem.original_target
                    DoArcAttack(inst, 1, TUNING.BEARGER_MELEE_RANGE, nil, nil, nil, targets)
                    DestroyStuff(inst, 1, TUNING.BEARGER_MELEE_RANGE)
                    if next(targets) == nil then
                        inst:PushEvent("onmissother", { target = original_target }) --for ChaseAndAttack
                    end
                elseif inst.sg.statemem.epicmode=="mutatedbearger" and not inst.sg.statemem.mutatedbearger_combo then
                    local targets = inst.sg.statemem.targets
                    local original_target = inst.sg.statemem.original_target
                    DoComboArcAttack(inst, targets)
                    DoComboArcWork(inst)
                    if next(targets) == nil then
                        inst:PushEvent("onmissother", { target = original_target }) --for ChaseAndAttack
                    end
                elseif inst.sg.statemem.mutatedbearger_combo then
                    inst.Physics:SetMotorVelOverride(0.75, 0, 0)
                end
			end),
			FrameEvent(34, function(inst)
                if inst.sg.statemem.epicmode=="deerclops" or inst.sg.statemem.epicmode=="mutateddeerclops" then
                    inst.SoundEmitter:PlaySound(EPIC[inst.sg.statemem.epicmode].sounds.swipe)
                    ShakeAllCameras(CAMERASHAKE.FULL, .5, .025, 1.25, inst, 40)
                elseif inst.sg.statemem.epicmode=="mutatedbearger" and not inst.sg.statemem.mutatedbearger_combo then
                    inst.Physics:SetMotorVelOverride(6, 0, 0)
                elseif inst.sg.statemem.mutatedbearger_combo then
                    inst.Physics:SetMotorVelOverride(0.375, 0, 0)
                end
			end),
            FrameEvent(35, function(inst)
                if inst.sg.statemem.epicmode=="mutatedbearger" and not inst.sg.statemem.mutatedbearger_combo then
                    inst.Physics:SetMotorVelOverride(3, 0, 0) 
                end
            end),
            FrameEvent(36, function(inst)
                if inst.sg.statemem.epicmode=="mutatedbearger" and not inst.sg.statemem.mutatedbearger_combo then
                    inst.Physics:SetMotorVelOverride(1.5, 0, 0) 
                end
            end),
            FrameEvent(37, function(inst)
                if inst.sg.statemem.epicmode=="mutatedbearger" and not inst.sg.statemem.mutatedbearger_combo then
                    inst.Physics:SetMotorVelOverride(0.75, 0, 0)
                elseif inst.sg.statemem.mutatedbearger_combo then
                    inst.sg:RemoveStateTag("busy")
                    inst.sg:RemoveStateTag("attack")
                end
            end),
            FrameEvent(38, function(inst)
                if inst.sg.statemem.epicmode=="mutatedbearger" and not inst.sg.statemem.mutatedbearger_combo then
                    inst.Physics:SetMotorVelOverride(0.375, 0, 0) 
                end
            end),
            FrameEvent(39, function(inst)
                if inst.sg.statemem.epicmode=="alterguardian_phase1" then
                    inst.SoundEmitter:PlaySound("moonstorm/creatures/boss/alterguardian1/tantrum")
                elseif inst.sg.statemem.epicmode=="mutatedbearger" and not inst.sg.statemem.mutatedbearger_combo then
                    inst.Physics:ClearMotorVelOverride()
				    inst.Physics:Stop()
                end
            end),
            FrameEvent(40, function(inst)
                if inst.sg.statemem.epicmode=="daywalker" then
                    inst.Physics:SetMotorVelOverride(3, 0, 0)
                end
            end),
            FrameEvent(41, function(inst)
                if inst.sg.statemem.epicmode=="daywalker" then
                    if inst.sg.statemem.targetpos ~= nil then
                        local x, y, z = inst.Transform:GetWorldPosition()
                        local dx = inst.sg.statemem.targetpos.x - x
                        local dz = inst.sg.statemem.targetpos.z - z
                        if dx ~= 0 or dz ~= 0 then
                            local rot1 = math.atan2(-dz, dx)
                            local diff = DiffAngleRad(inst.Transform:GetRotation() * DEGREES, rot1)
                            if diff * RADIANS < 60 then
                                local dist = math.sqrt(dx * dx + dz * dz) * math.cos(diff)
                                local maxdist = (12 + 20 + 3 * 36) * FRAMES
                                inst.sg.statemem.speedmult = math.clamp(math.abs(dist / maxdist), 0.25, 1.2)
                            else
                                inst.sg.statemem.speedmult = 1
                            end
                        else
                            inst.sg.statemem.speedmult = 0.25
                        end
                    end
                    inst.Physics:SetMotorVelOverride(12 * inst.sg.statemem.speedmult, 0, 0)
                elseif inst.sg.statemem.epicmode=="alterguardian_phase1" then
                    inst.SoundEmitter:PlaySound("moonstorm/creatures/boss/alterguardian1/tantrum")

                    ph1_tantrum_screenshake(inst)
                    ph1_spawn_landfx(inst)
                elseif inst.sg.statemem.epicmode=="mutatedbearger" and not inst.sg.statemem.mutatedbearger_combo then
                    inst.sg:RemoveStateTag("busy")
                    inst.sg:RemoveStateTag("attack")
                end
            end),
            FrameEvent(42, function(inst)
                if inst.sg.statemem.epicmode=="daywalker" then
                    inst.Physics:SetMotorVelOverride(20 * inst.sg.statemem.speedmult, 0, 0)
                elseif inst.sg.statemem.epicmode=="alterguardian_phase1" then
                    inst.SoundEmitter:PlaySound("moonstorm/creatures/boss/alterguardian1/tantrum")
                    ph1_DoAOEAttack(inst, TUNING.ALTERGUARDIAN_PHASE1_AOERANGE)
                end
            end),
            FrameEvent(43, function(inst)
                if inst.sg.statemem.epicmode=="daywalker" then
                    inst.Physics:SetMotorVelOverride(36 * inst.sg.statemem.speedmult, 0, 0)
                end
            end),
            FrameEvent(45, function(inst)
                if inst.sg.statemem.epicmode=="daywalker" then
                    inst.SoundEmitter:PlaySound("daywalker/action/attack_slam_down")
                    inst.Physics:ClearMotorVelOverride()
                    inst.Physics:Stop()
                elseif inst.sg.statemem.epicmode=="alterguardian_phase3" then
                    MooseDoArcAttack(inst)
                    inst.sg:RemoveStateTag("abouttoattack")
                end
            end),
            FrameEvent(46, function(inst)
                if inst.sg.statemem.epicmode=="daywalker" then
                    inst.sg.statemem.speed = 4
                    inst.sg.statemem.decel = -1

                    local sinkhole = SpawnPrefab("daywalker_sinkhole")
                    sinkhole.Transform:SetPosition(inst.Transform:GetWorldPosition())
                    sinkhole:PushEvent("docollapse")

                    inst.components.combat:SetDefaultDamage(TUNING.DAYWALKER_SLAM_DAMAGE)

                    local targets = {}

                    if not inst.sg.statemem.isattack then
                        inst:PerformBufferedAction()
                    else
                        inst:ClearBufferedAction()
                    end

                    DoAOEAttack(inst, 0, TUNING.DAYWALKER_SLAM_SINKHOLERADIUS, 0.7, 0.7, false,targets)
                    inst.sg:RemoveStateTag("abouttoattack")
                end
            end),
            FrameEvent(47, function(inst)
                if inst.sg.statemem.epicmode=="stalker_atrium" then
                    inst.SoundEmitter:PlaySound("dontstarve/creatures/together/stalker/head")
                end
            end),
            FrameEvent(55, function(inst)
                if inst.sg.statemem.epicmode=="alterguardian_phase1" then
                    inst.SoundEmitter:PlaySound("moonstorm/creatures/boss/alterguardian1/tantrum")
                elseif inst.sg.statemem.epicmode=="alterguardian_phase3" then
                    inst.SoundEmitter:KillSound("stab_loop")
                end
            end),
            FrameEvent(57, function(inst)
                if inst.sg.statemem.epicmode=="alterguardian_phase1" then
                    inst.SoundEmitter:PlaySound("moonstorm/creatures/boss/alterguardian1/tantrum")

                    ph1_tantrum_screenshake(inst)
                    ph1_spawn_landfx(inst)
                end
            end),
            FrameEvent(58, function(inst)
                if inst.sg.statemem.epicmode=="alterguardian_phase1" then
                    inst.SoundEmitter:PlaySound("moonstorm/creatures/boss/alterguardian1/tantrum")

                    ph1_DoAOEAttack(inst, TUNING.ALTERGUARDIAN_PHASE1_AOERANGE)

                end
            end),
            FrameEvent(70, function(inst)
                if inst.sg.statemem.epicmode=="alterguardian_phase1" then
                    inst.SoundEmitter:PlaySound("moonstorm/creatures/boss/alterguardian1/tantrum")
                end
			end),
            FrameEvent(72, function(inst)
                if inst.sg.statemem.epicmode=="alterguardian_phase1" then
                    inst.SoundEmitter:PlaySound("moonstorm/creatures/boss/alterguardian1/tantrum")

                    ph1_tantrum_screenshake(inst)
                    ph1_spawn_landfx(inst)
                end
			end),
            FrameEvent(73, function(inst)
                if inst.sg.statemem.epicmode=="alterguardian_phase1" then
                    inst.SoundEmitter:PlaySound("moonstorm/creatures/boss/alterguardian1/tantrum")

                    ph1_DoAOEAttack(inst, TUNING.ALTERGUARDIAN_PHASE1_AOERANGE)
                    inst.sg:RemoveStateTag("abouttoattack")
                end
			end),
            FrameEvent(110, function(inst)
                if inst.sg.statemem.epicmode=="alterguardian_phase1" then
                    inst.SoundEmitter:PlaySound("moonstorm/creatures/boss/alterguardian1/step")
                end
			end),
            FrameEvent(116, function(inst)
                if inst.sg.statemem.epicmode=="alterguardian_phase1" then
                    inst.SoundEmitter:PlaySound("moonstorm/creatures/boss/alterguardian1/step")
                end
			end),
            FrameEvent(119, function(inst)
                if inst.sg.statemem.epicmode=="alterguardian_phase1" then
                    inst.SoundEmitter:PlaySound("moonstorm/creatures/boss/alterguardian1/step")
                end
			end),
		},

        ontimeout = function(inst)
            inst.sg:RemoveStateTag("attack")
            inst.sg:RemoveStateTag("busy")
        end,

		events =
		{
			EventHandler("animover", function(inst)
				if inst.AnimState:AnimDone() then
					inst.sg:GoToState("epic_idle")
				end
			end),
		},

        onexit = function(inst)
            if inst.sg.statemem.epicmode=="bearger" or inst.sg.statemem.epicmode=="mutatedbearger" then
                inst.Transform:SetFourFaced()
                KillSwipeFX(inst)
                inst.Physics:ClearMotorVelOverride()
                inst.Physics:Stop()
            elseif inst.sg.statemem.epicmode=="daywalker" then
                inst.Physics:ClearMotorVelOverride()
                inst.Physics:Stop()
                inst.components.combat:SetDefaultDamage(TUNING.DAYWALKER_DAMAGE)
            elseif inst.sg.statemem.epicmode=="daywalker2" then
                inst.components.combat:SetDefaultDamage(TUNING.DAYWALKER_DAMAGE)
			    daywalker2_KillSwipeFX(inst)
            end
            if inst.sg.mem.summon_fx and inst.sg.mem.summon_fx:IsValid() then
                inst.sg.mem.summon_fx:PushEvent("endloop")
                inst.sg.mem.summon_fx = nil
            end
            inst.components.combat:SetTarget(nil)
            if inst.sg:HasStateTag("abouttoattack") then
                inst.components.combat:CancelAttack()
            end
        end,
	})

AddStategraphState("wilson",State{
        name = "epic_walk_start",
        tags = { "moving", "walking" , "canrotate", "autopredict" ,"epic"},

        onenter = function(inst)
			local mode = inst.components.wereepic and inst.components.wereepic:GetEpicMode()
            inst.components.locomotor:RunForward()
            if mode=="bearger" or mode=="mutatedbearger" then
                if inst:HasTag("bearger_run") then
                    if not inst.SoundEmitter:PlayingSound("taunt") then
                        inst.SoundEmitter:PlaySound(EPIC[mode].sounds.taunt, "taunt")
                    end
                end
                inst.AnimState:PlayAnimation("charge_pre")
            elseif mode=="antlion" then
                if not inst.AnimState:IsCurrentAnimation("idle") then
                    inst.AnimState:PlayAnimation("idle")
                end
            elseif inst:HasTag("dragonfly_enraged") then
                inst.AnimState:PlayAnimation("walk_angry_pre")
                inst.SoundEmitter:PlaySound("dontstarve_DLC001/creatures/dragonfly/angry")
            elseif inst:HasTag("daywalker_run") or mode=="mutatedwarg" then
                inst.AnimState:PlayAnimation("run_pre")
            else
                inst.AnimState:PlayAnimation("walk_pre")
            end
			inst.sg.statemem.epicmode = mode
        end,

        onupdate = function(inst)
            inst.components.locomotor:RunForward()
        end,

        timeline =
        {
            TimeEvent(0 * FRAMES, function(inst)
				if inst.sg.statemem.epicmode=="daywalker" or inst.sg.statemem.epicmode=="daywalker2" then
					daywalker_DoFootstep(inst,0.5)
				end
            end),
            TimeEvent(1*FRAMES, function(inst)
                if not inst:HasTag("dragonfly_enraged") then
                    inst.SoundEmitter:PlaySound("dontstarve_DLC001/creatures/dragonfly/blink")
                end
            end),
            TimeEvent(2*FRAMES, function(inst)
                if inst:HasTag("dragonfly_enraged") then
                    inst.SoundEmitter:PlaySound("dontstarve_DLC001/creatures/dragonfly/blink")
                end
            end),
            TimeEvent(3*FRAMES, function(inst)
                if inst.sg.statemem.epicmode=="alterguardian_phase2" then
                    phase2_play_foley(inst)
                end
            end),
            TimeEvent(7 * FRAMES, function(inst)
				if inst.sg.statemem.epicmode=="deerclops" or inst.sg.statemem.epicmode=="mutateddeerclops" then
					DeerclopsFootstep(inst, true)
                elseif inst.sg.statemem.epicmode=="malbatross" then
                    inst.SoundEmitter:PlaySound("saltydog/creatures/boss/malbatross/flap")
				end
            end),
            TimeEvent(9 * FRAMES, function(inst)
				if inst.sg.statemem.epicmode=="malbatross" then
                    spawnripple(inst)
				end
            end)
        },

        events =
        {
			EventHandler("animover", function(inst)
                if inst.AnimState:AnimDone() then
					inst.sg.statemem.walking = true
                    inst.sg:GoToState("epic_walk")
                end
            end),
        },

        onexit = function (inst)
			if not inst.sg.statemem.walking and (inst.sg.statemem.epicmode=="deerclops" or inst.sg.statemem.epicmode=="mutateddeerclops") then
				DeerclopsFootstep(inst, false)
			end
        end
    })

AddStategraphState("wilson",State{
        name = "epic_walk",
        tags = { "moving", "walking", "canrotate", "autopredict","epic" },

        onenter = function(inst)
			local mode = inst.components.wereepic and inst.components.wereepic:GetEpicMode()
            inst.components.locomotor:RunForward()
            if mode=="bearger" or mode=="mutatedbearger" then
                if inst:HasTag("bearger_run") then
                    if not inst.SoundEmitter:PlayingSound("taunt") then
                        inst.SoundEmitter:PlaySound(EPIC[mode].sounds.taunt, "taunt")
                    end
                    if not inst.AnimState:IsCurrentAnimation("charge_roar_loop") then
                        inst.AnimState:PlayAnimation("charge_roar_loop", true)
                    end
                else
                    if not inst.AnimState:IsCurrentAnimation("charge_loop") then
                        inst.AnimState:PlayAnimation("charge_loop", true)
                    end
                end
            elseif mode=="antlion" then
                if not inst.AnimState:IsCurrentAnimation("lookaround") then
                    inst.AnimState:PlayAnimation("lookaround", true)
                end
            elseif mode=="dragonfly" then
                if inst:HasTag("dragonfly_enraged") then
                    if not inst.AnimState:IsCurrentAnimation("walk_angry") then
                        inst.AnimState:PlayAnimation("walk_angry", true)
                    end
                    if math.random() < .5 then
                        inst.SoundEmitter:PlaySound("dontstarve_DLC001/creatures/dragonfly/angry")
                    end
                else
                    if not inst.AnimState:IsCurrentAnimation("walk") then
                        inst.AnimState:PlayAnimation("walk", true)
                    end
                end
            elseif inst:HasTag("daywalker_run") or mode=="mutatedwarg" then
                if not inst.AnimState:IsCurrentAnimation("run_loop") then
                    inst.AnimState:PlayAnimation("run_loop", true)
                end
            else
                if not inst.AnimState:IsCurrentAnimation("walk_loop") then
                    inst.AnimState:PlayAnimation("walk_loop", true)
                end
            end

			if EPIC[mode].sounds.walk then
				inst.SoundEmitter:PlaySound(EPIC[mode].sounds.walk)
			end
			inst.sg.statemem.epicmode = mode
            inst.sg:SetTimeout(inst.AnimState:GetCurrentAnimationLength())
        end,

        onupdate = function(inst)
            inst.components.locomotor:RunForward()
        end,

        timeline =
        {
            FrameEvent(0, function(inst)
                if inst:HasTag("bearger_run") then
                    DoFootstep(inst)
				    DestroyStuff(inst, 0, 5)
                elseif inst.sg.statemem.epicmode=="beequeen" then
                    inst.SoundEmitter:PlaySound("dontstarve/creatures/together/bee_queen/breath")
                elseif inst.sg.statemem.epicmode=="alterguardian_phase2" then
                    phase2_play_step(inst)
                    PlayFootstep(inst)
                elseif inst.sg.statemem.epicmode=="stalker_atrium" then
                    inst.SoundEmitter:PlaySound("dontstarve/creatures/together/stalker/footstep")
                end
			end),
            FrameEvent(1, function(inst)
				if (inst.sg.statemem.epicmode=="bearger" or inst.sg.statemem.epicmode=="mutatedbearger" ) and not inst:HasTag("bearger_run") then
					DoFootstep(inst)
                elseif inst.sg.statemem.epicmode=="moose" then
                    PlayFootstep(inst)
				end
			end),
            FrameEvent(3, function(inst)
                if inst.sg.statemem.epicmode=="alterguardian_phase1" then
                    phase1_play_foley(inst)
                elseif inst.sg.statemem.epicmode=="alterguardian_phase2" then
                    phase2_play_foley(inst)
                elseif inst.sg.statemem.epicmode=="ancient_hulk" then
                    inst.SoundEmitter:PlaySoundWithParams("mnh_ancient_hulk_sound/creatures/boss/hulk_metal_robot/ribs/servo", {intensity=math.random()})
				end
			end),
            FrameEvent(5, function(inst)
                if inst.sg.statemem.epicmode=="moose" then
                    PlayFootstep(inst)
                elseif inst.sg.statemem.epicmode=="mutatedwarg" then
                    PlayFootstep(inst)
                    inst.SoundEmitter:PlaySound(EPIC[inst.sg.statemem.epicmode].sounds.idle)
				end
			end),
            FrameEvent(6, function(inst)
                if inst.sg.statemem.epicmode=="alterguardian_phase1" then
                    phase1_play_step(inst)
                    PlayFootstep(inst)
				end
			end),
			FrameEvent(8, function(inst)
                if inst:HasTag("bearger_run") then
                    DoFootstep(inst)
				    DestroyStuff(inst, 0, 5)
                end
			end),
            FrameEvent(9, function(inst)
                if inst:HasTag("daywalker_run") then
                    daywalker_DoFootstep(inst)
				end
			end),
            FrameEvent(10, function(inst)
                if inst.sg.statemem.epicmode=="moose" then
                    PlayFootstep(inst)
                elseif inst.sg.statemem.epicmode=="alterguardian_phase1" then
                    phase1_play_foley(inst)
                elseif inst.sg.statemem.epicmode=="alterguardian_phase2" then
                    phase2_play_foley(inst)
                elseif inst:HasTag("daywalker_run") then
                    DoFootstepAOE(inst)
				end
			end),
            FrameEvent(12, function(inst)
                if inst.sg.statemem.epicmode=="ancient_hulk" then
                    inst.SoundEmitter:PlaySoundWithParams("mnh_ancient_hulk_sound/creatures/boss/hulk_metal_robot/head/step", {intensity=math.random()})
				end
			end),
            FrameEvent(15, function(inst)
                if inst.sg.statemem.epicmode=="stalker_atrium" then
                    inst.SoundEmitter:PlaySound("dontstarve/creatures/together/stalker/footstep")
                end
			end),
            FrameEvent(16, function(inst)
				if inst.sg.statemem.epicmode=="alterguardian_phase1" then
					phase1_play_step(inst)
                elseif inst.sg.statemem.epicmode=="ancient_hulk" then
                    inst.SoundEmitter:PlaySoundWithParams("mnh_ancient_hulk_sound/creatures/boss/hulk_metal_robot/head/step", {intensity=math.random()})
				end
			end),
			FrameEvent(17, function(inst)
				if (inst.sg.statemem.epicmode=="bearger" or inst.sg.statemem.epicmode=="mutatedbearger" ) and not inst:HasTag("bearger_run") then
					DoFootstep(inst)
				end
			end),
            FrameEvent(19, function (inst)
                if (inst.sg.statemem.epicmode=="daywalker" or inst.sg.statemem.epicmode=="daywalker2" ) and
                not inst:HasTag("daywalker_run") then
                    daywalker_DoFootstep(inst)
                end
            end),
            FrameEvent(20, function(inst)
                if inst.sg.statemem.epicmode=="ancient_hulk" then
                    inst.SoundEmitter:PlaySoundWithParams("mnh_ancient_hulk_sound/creatures/boss/hulk_metal_robot/arm/step", {intensity=math.random()})
				end
			end),
            FrameEvent(22, function(inst)
                if inst:HasTag("daywalker_run") then
                    daywalker_DoFootstep(inst)
                elseif inst.sg.statemem.epicmode=="alterguardian_phase1" then
					phase1_play_foley(inst)
                elseif inst.sg.statemem.epicmode=="alterguardian_phase2" then
					phase2_play_foley(inst)
				end
			end),
            FrameEvent(23, function(inst)
				if inst.sg.statemem.epicmode=="deerclops" or inst.sg.statemem.epicmode=="mutateddeerclops" then
					DeerclopsFootstep(inst, true)
                elseif inst:HasTag("daywalker_run") then
                    DoFootstepAOE(inst)
				end
            end),
            FrameEvent(24, function(inst)
                if inst.sg.statemem.epicmode=="alterguardian_phase2" then
					phase2_play_step(inst)
				end
			end),
            FrameEvent(27, function(inst)
                if inst.sg.statemem.epicmode=="alterguardian_phase1" then
					phase1_play_step(inst)
                    PlayFootstep(inst)
				end
			end),
            FrameEvent(32, function(inst)
                if inst.sg.statemem.epicmode=="stalker_atrium" then
                    inst.SoundEmitter:PlaySound("dontstarve/creatures/together/stalker/footstep")
                end
			end),
            FrameEvent(33, function(inst)
				if inst.sg.statemem.epicmode=="malbatross" then
					spawnripple(inst)
				end
            end),
            FrameEvent(36, function(inst)
				if inst.sg.statemem.epicmode=="alterguardian_phase2" then
					phase2_play_step(inst)
                    PlayFootstep(inst)
				end
            end),
            FrameEvent(37, function(inst)
				if inst.sg.statemem.epicmode=="malbatross" then
					inst.SoundEmitter:PlaySound("saltydog/creatures/boss/malbatross/flap")
				end
            end),
            FrameEvent(43, function (inst)
                if (inst.sg.statemem.epicmode=="daywalker" or inst.sg.statemem.epicmode=="daywalker2" ) and
                not inst:HasTag("daywalker_run") then
                    daywalker_DoFootstep(inst)
                end
            end),
            FrameEvent(47, function(inst)
				if inst.sg.statemem.epicmode=="deerclops" or inst.sg.statemem.epicmode=="mutateddeerclops" then
					DeerclopsFootstep(inst, true)
				end
            end),
            FrameEvent(48, function(inst)
				if inst.sg.statemem.epicmode=="alterguardian_phase2" then
					phase2_play_step(inst)
                    PlayFootstep(inst)
				end
            end),
        },

        events =
        {

        },

        ontimeout = function(inst)
            if (inst.sg.statemem.epicmode=="bearger" or inst.sg.statemem.epicmode=="mutatedbearger" ) and not inst:HasTag("bearger_run") then
                if inst.components.combat:HasTarget() and math.random() < 0.5 then
                    inst.SoundEmitter:PlaySound(EPIC[inst.sg.statemem.epicmode].sounds.growl)
                end
            end
            inst.sg.statemem.walking = true
			inst.sg:GoToState("epic_walk")
        end,

        onexit = function (inst)
			if not inst.sg.statemem.walking and (inst.sg.statemem.epicmode=="deerclops" or inst.sg.statemem.epicmode=="mutateddeerclops") then
				DeerclopsFootstep(inst, false)
			end
        end
    })

AddStategraphState("wilson",State{
        name = "epic_walk_stop",
        tags = { "canrotate", "idle", "autopredict","epic" },

        onenter = function(inst)
			local mode = inst.components.wereepic and inst.components.wereepic:GetEpicMode()
            inst.components.locomotor:Stop()
            if mode=="bearger" or mode=="mutatedbearger" then
                inst.AnimState:PlayAnimation("charge_pst")
                DoFootstep(inst)
            elseif mode=="antlion" then
                if not inst.AnimState:IsCurrentAnimation("idle") then
                    inst.AnimState:PlayAnimation("idle")
                end
            elseif inst:HasTag("dragonfly_enraged") then
                inst.AnimState:PlayAnimation("walk_angry_pst")
            elseif inst:HasTag("daywalker_run") or mode=="mutatedwarg" then
                inst.AnimState:PlayAnimation("run_pst")
            else
                inst.AnimState:PlayAnimation("walk_pst")
            end
            if mode=="ancient_hulk" then
                inst.SoundEmitter:PlaySoundWithParams("mnh_ancient_hulk_sound/creatures/boss/hulk_metal_robot/head/step", {intensity=math.random()})
            end
			inst.sg.statemem.epicmode = mode
        end,

        timeline =
        {
            FrameEvent(0, function(inst)
				if inst.sg.statemem.epicmode=="alterguardian_phase2" then
					phase2_play_step(inst)
                    PlayFootstep(inst)
				end
            end),
            FrameEvent(1, function(inst)
                if inst.sg.statemem.epicmode=="dragonfly" and not inst:HasTag("dragonfly_enraged") then
                    inst.SoundEmitter:PlaySound("dontstarve_DLC001/creatures/dragonfly/blink")
                end
            end),
            FrameEvent(2, function(inst)
                if inst:HasTag("dragonfly") then
                    inst.SoundEmitter:PlaySound("dontstarve_DLC001/creatures/dragonfly/blink")
                end
            end),
            FrameEvent(3, function(inst)
                if inst.sg.statemem.epicmode=="alterguardian_phase1" then
                    phase1_play_foley(inst)
				end
			end),
            FrameEvent(5, function(inst)
                if inst.sg.statemem.epicmode=="alterguardian_phase1" then
                    phase1_play_foley(inst)
				end
			end),
            FrameEvent(7, function(inst)
                if inst.sg.statemem.epicmode=="alterguardian_phase1" then
                    inst.SoundEmitter:PlaySound("moonstorm/creatures/boss/alterguardian1/step",nil,.50)
                    PlayFootstep(inst)
				end
			end),
            FrameEvent(8, function(inst)
                if inst.sg.statemem.epicmode=="alterguardian_phase1" then
                    inst.SoundEmitter:PlaySound("moonstorm/creatures/boss/alterguardian1/step",nil,.25)
                    PlayFootstep(inst)
				end
			end),
            FrameEvent(10, function(inst)
				if inst.sg.statemem.epicmode=="alterguardian_phase2" then
					phase2_play_foley(inst)
				end
            end),
            FrameEvent(12, function(inst)
				if inst.sg.statemem.epicmode=="alterguardian_phase2" then
					phase2_play_step(inst)
                    PlayFootstep(inst)
				end
            end),
            FrameEvent(16, function(inst)
				if inst.sg.statemem.epicmode=="alterguardian_phase2" then
					phase2_play_foley(inst)
				end
            end),
            FrameEvent(18, function(inst)
				if inst.sg.statemem.epicmode=="alterguardian_phase2" then
					phase2_play_step(inst)
                    PlayFootstep(inst)
				end
            end),
        },

        events =
        {
            EventHandler("animover", function(inst)
                if inst.AnimState:AnimDone() then
                    inst.sg:GoToState("epic_idle")
                end
            end),
        },

        onexit = function(inst)

        end,
    })

AddStategraphState("wilson",State{
        name = "epic_death",
        tags = { "busy", "pausepredict", "nomorph" ,"epic","noattack","epic_death"},

        onenter = function(inst, data)
            local mode = inst.components.wereepic and inst.components.wereepic:GetEpicMode()

            inst.components.locomotor:Stop()
            inst.components.locomotor:Clear()
            inst:ClearBufferedAction()

            if inst.components.playercontroller then
                inst.components.playercontroller:RemotePausePrediction()
            end

            if mode=="malbatross" then
                if not inst:IsOnPassablePoint() then
                    inst.AnimState:PlayAnimation("death_ocean")
                else
                    inst.AnimState:PlayAnimation("death")
                end
            elseif mode=="daywalker" or mode=="daywalker2" then
                inst.AnimState:PlayAnimation("defeat")
            elseif mode=="alterguardian_phase1" then
                inst.AnimState:SetBuild("alterguardian_spawn_death")
                inst.AnimState:SetBankAndPlayAnimation("alterguardian_spawn_death", "phase1_death")
            elseif mode=="alterguardian_phase2" then
                inst.AnimState:SetBuild("alterguardian_spawn_death")
                inst.AnimState:SetBankAndPlayAnimation("alterguardian_spawn_death", "phase2_death")
            elseif mode=="alterguardian_phase3" then
                inst.AnimState:SetBuild("alterguardian_spawn_death")
                inst.AnimState:SetBankAndPlayAnimation("alterguardian_spawn_death", "phase3_death")
            elseif mode=="stalker_atrium" then
                inst.AnimState:PlayAnimation("death3")
            elseif mode=="ancient_hulk" then
                inst.AnimState:PlayAnimation("death_explode")
            else
                inst.AnimState:PlayAnimation("death")
            end

			inst.SoundEmitter:PlaySound(inst.deathsoundoverride)

            inst.sg.statemem.epicmode = mode

            if data then
                inst.sg.statemem.epicdeathdata = data
            end

        end,

        timeline =
        {
            FrameEvent(1, function(inst)
                if inst.sg.statemem.epicmode=="stalker_atrium" then
                    inst.SoundEmitter:PlaySound("dontstarve/creatures/together/stalker/death_pop")
                end
            end),
            FrameEvent(6, function(inst)
                if inst.sg.statemem.epicmode=="stalker_atrium" then
                    inst.SoundEmitter:PlaySound("dontstarve/creatures/together/stalker/death3/whip")
                elseif inst.sg.statemem.epicmode=="ancient_hulk" then
                    inst.SoundEmitter:PlaySoundWithParams("mnh_ancient_hulk_sound/creatures/boss/hulk_metal_robot/laser", {intensity= .3})
                end
            end),
            FrameEvent(7, function(inst)
                if inst.sg.statemem.epicmode=="daywalker" then
                    inst.SoundEmitter:PlaySound("daywalker/action/step", nil, 0.4)
                elseif inst.sg.statemem.epicmode=="daywalker2" then
                    inst.SoundEmitter:PlaySound("qol1/daywalker_scrappy/step", nil, 0.4)
                end
            end),
            FrameEvent(15, function(inst)
                if inst.sg.statemem.epicmode=="stalker_atrium" then
                    inst.SoundEmitter:PlaySound("dontstarve/creatures/together/stalker/death3/whip_snap")
                end
            end),
            FrameEvent(16, function(inst)
                if inst.sg.statemem.epicmode=="alterguardian_phase2" then
                    set_lightvalues(inst, 0.6)
                elseif inst.sg.statemem.epicmode=="ancient_hulk" then
                    inst.SoundEmitter:KillSound("gears")
                    inst.SoundEmitter:PlaySound("mnh_ancient_hulk_sound/creatures/boss/hulk_metal_robot/death")
                end
            end),
            FrameEvent(18, function(inst)
                if inst.sg.statemem.epicmode=="alterguardian_phase3" then
                    set_lightvalues(inst, 0.9)
                end
            end),
            FrameEvent(21, function(inst)
                if inst.sg.statemem.epicmode=="alterguardian_phase3" then
                    set_lightvalues(inst, 0.75)
                elseif inst.sg.statemem.epicmode=="ancient_hulk" then
                    inst.SoundEmitter:PlaySound("mnh_ancient_hulk_sound/creatures/boss/hulk_metal_robot/death_taunt")
                end
            end),
            FrameEvent(23, function(inst)
                if inst.sg.statemem.epicmode=="daywalker" or inst.sg.statemem.epicmode=="daywalker2" then
                    inst.SoundEmitter:PlaySound("daywalker/voice/speak_short")
                elseif inst.sg.statemem.epicmode=="ancient_hulk" then
                    inst.SoundEmitter:PlaySoundWithParams("mnh_ancient_hulk_sound/creatures/boss/hulk_metal_robot/laser", {intensity= .4})
                end
            end),
            FrameEvent(27, function(inst)
                if inst.sg.statemem.epicmode=="alterguardian_phase2" then
                    set_lightvalues(inst, 0.9)
                elseif inst.sg.statemem.epicmode=="ancient_hulk" then
                    inst.SoundEmitter:PlaySoundWithParams("mnh_ancient_hulk_sound/creatures/boss/hulk_metal_robot/laser", {intensity= .6})
                end
            end),
            FrameEvent(31, function(inst)
                if inst.sg.statemem.epicmode=="alterguardian_phase2" then
                    set_lightvalues(inst, 0.5)
                end
            end),
            FrameEvent(33, function(inst)
                if inst.sg.statemem.epicmode=="daywalker" or inst.sg.statemem.epicmode=="daywalker2" then
                    inst.SoundEmitter:PlaySound("dontstarve/movement/bodyfall_dirt")
                elseif inst.sg.statemem.epicmode=="ancient_hulk" then
                    inst.SoundEmitter:PlaySoundWithParams("mnh_ancient_hulk_sound/creatures/boss/hulk_metal_robot/laser", {intensity= .8})
                end
            end),
            FrameEvent(36, function(inst)
                if inst.sg.statemem.epicmode=="ancient_hulk" then
                    inst.SoundEmitter:PlaySoundWithParams("mnh_ancient_hulk_sound/creatures/boss/hulk_metal_robot/laser", {intensity= 1})
                end
            end),
            FrameEvent(39, function(inst)
                if inst.sg.statemem.epicmode=="alterguardian_phase2" then
                    set_lightvalues(inst, 0.9)
                end
            end),
            FrameEvent(40, function(inst)
                if inst.sg.statemem.epicmode=="alterguardian_phase3" then
                    set_lightvalues(inst, 0.675)
                end
            end),
            FrameEvent(41, function(inst)
                if inst.sg.statemem.epicmode=="stalker_atrium" then
                    inst.SoundEmitter:PlaySound("dontstarve/creatures/together/stalker/death3/pianohits_1")
                end
            end),
            FrameEvent(44, function(inst)
                if inst.sg.statemem.epicmode=="stalker_atrium" then
                    ShakeIfClose(inst)
                end
            end),
            FrameEvent(48, function(inst)
                if inst.sg.statemem.epicmode=="malbatross" then
                    spawnsplash(inst)
                    spawnwave(inst)
                    inst.SoundEmitter:PlaySound("turnoftides/common/together/water/splash/boss")
                end
                ShakeAllCameras(CAMERASHAKE.FULL, .7, .02, 2, inst, 40)
            end),
            FrameEvent(49, function(inst)
                if inst.sg.statemem.epicmode=="stalker_atrium" then
                    inst.SoundEmitter:PlaySound("dontstarve/creatures/together/stalker/death3/orchhits")
                end
            end),
            FrameEvent(55, function(inst)
                if inst.sg.statemem.epicmode=="stalker_atrium" then
                    inst.SoundEmitter:PlaySound("dontstarve/creatures/together/stalker/death3/stretch")
                end
            end),
            FrameEvent(60, function(inst)
                if inst.sg.statemem.epicmode=="alterguardian_phase3" then
                    set_lightvalues(inst, 0.65)
                elseif inst.sg.statemem.epicmode=="ancient_hulk" then
                    inst.SoundEmitter:PlaySound("mnh_ancient_hulk_sound/creatures/boss/hulk_metal_robot/explode_small",nil,.5)
                end
            end),
            FrameEvent(67, function(inst)
                if inst.sg.statemem.epicmode=="ancient_hulk" then
                    inst.SoundEmitter:PlaySound("mnh_ancient_hulk_sound/creatures/boss/hulk_metal_robot/explode_small",nil,.6)
                end
            end),
            FrameEvent(73, function(inst)
                if inst.sg.statemem.epicmode=="stalker_atrium" then
                    inst.SoundEmitter:PlaySound("dontstarve/creatures/together/stalker/death3/whip")
                end
            end),
            FrameEvent(76, function(inst)
                if inst.sg.statemem.epicmode=="daywalker" or inst.sg.statemem.epicmode=="daywalker2" then
                    inst.SoundEmitter:PlaySound("daywalker/voice/speak_short")
                elseif inst.sg.statemem.epicmode=="ancient_hulk" then
                    inst.SoundEmitter:PlaySound("mnh_ancient_hulk_sound/creatures/boss/hulk_metal_robot/explode_small",nil,.7)
                end
            end),
            FrameEvent(79, function(inst)
                if inst.sg.statemem.epicmode=="ancient_hulk" then
                    inst.SoundEmitter:PlaySound("mnh_ancient_hulk_sound/creatures/boss/hulk_metal_robot/explode_small",nil,.6)
                end
            end),
            FrameEvent(81, function(inst)
                if inst.sg.statemem.epicmode=="ancient_hulk" then
                    ShakeAllCameras(CAMERASHAKE.FULL, 0.7, 0.02, 3, inst, 40)
                    ancient_hulk_DoDamage(inst,6)
                end
            end),
            FrameEvent(82, function(inst)
                if inst.sg.statemem.epicmode=="ancient_hulk" then
                    inst.SoundEmitter:PlaySound("mnh_ancient_hulk_sound/creatures/boss/hulk_metal_robot/explode")
                end
            end),
            FrameEvent(85, function(inst)
                if inst.sg.statemem.epicmode=="stalker_atrium" then
                    inst.SoundEmitter:PlaySound("dontstarve/creatures/together/stalker/death3/whip_snap")
                end
            end),
            FrameEvent(108, function(inst)
                if inst.sg.statemem.epicmode=="stalker_atrium" then
                    inst.SoundEmitter:PlaySound("dontstarve/creatures/together/stalker/death3/pianohits_1")
                end
            end),
            FrameEvent(110, function(inst)
                if inst.sg.statemem.epicmode=="stalker_atrium" then
                    inst.SoundEmitter:PlaySound("dontstarve/creatures/together/stalker/death3/whip")
                end
            end),
            FrameEvent(111, function(inst)
                if inst.sg.statemem.epicmode=="stalker_atrium" then
                    ShakeIfClose(inst)
                end
            end),
            FrameEvent(116, function(inst)
                if inst.sg.statemem.epicmode=="stalker_atrium" then
                    inst.SoundEmitter:PlaySound("dontstarve/creatures/together/stalker/death3/orchhits")
                end
            end),
            FrameEvent(132, function(inst)
                if inst.sg.statemem.epicmode=="stalker_atrium" then
                    inst.SoundEmitter:PlaySound("dontstarve/creatures/together/stalker/death3/whip_snap")
                end
            end),
            FrameEvent(135, function(inst)
                if inst.sg.statemem.epicmode=="stalker_atrium" then
                    inst.SoundEmitter:PlaySound("dontstarve/creatures/together/stalker/death3/whip_snap")
                    inst.SoundEmitter:PlaySound("dontstarve/creatures/together/stalker/death3/fwump")
                end
            end),
            FrameEvent(138, function(inst)
                if inst.sg.statemem.epicmode=="stalker_atrium" then
                    inst.SoundEmitter:PlaySound("dontstarve/creatures/together/stalker/death3/pianohits_1")
                end
            end),
            FrameEvent(152, function(inst)
                if inst.sg.statemem.epicmode=="stalker_atrium" then
                    inst.SoundEmitter:PlaySound("dontstarve/creatures/together/stalker/death3/pianohits_2")
                end
            end),
            FrameEvent(155, function(inst)
                if inst.sg.statemem.epicmode=="stalker_atrium" then
                    ShakeAllCameras(CAMERASHAKE.VERTICAL, .6, .02, .4, inst, 30)
                end
            end),
            FrameEvent(168, function(inst)
                if inst.sg.statemem.epicmode=="stalker_atrium" then
                    inst.SoundEmitter:PlaySound("dontstarve/creatures/together/stalker/death3/stretch")
                end
            end),
            FrameEvent(170, function(inst)
                if inst.sg.statemem.epicmode=="stalker_atrium" then
                    inst.SoundEmitter:PlaySound("dontstarve/creatures/together/stalker/taunt_short")
                end
            end),
            FrameEvent(185, function(inst)
                if inst.sg.statemem.epicmode=="stalker_atrium" then
                    inst.SoundEmitter:PlaySound("dontstarve/creatures/together/stalker/death3/whip_snap")
                    inst.SoundEmitter:PlaySound("dontstarve/creatures/together/stalker/death")
                end
            end),
            FrameEvent(190, function(inst)
                if inst.sg.statemem.epicmode=="stalker_atrium" then
                    inst.SoundEmitter:PlaySound("dontstarve/creatures/together/stalker/death3/transform")
                end
            end),
            FrameEvent(194, function(inst)
                if inst.sg.statemem.epicmode=="stalker_atrium" then
                    inst.DynamicShadow:Enable(false)
                    ShakeIfClose(inst)
                end
            end),
            FrameEvent(300, function(inst)
                if inst.sg.statemem.epicmode=="stalker_atrium" then
                    inst.SoundEmitter:PlaySound("dontstarve/charlie/attack_low")
                end
            end),
            FrameEvent(303, function(inst)
                if inst.sg.statemem.epicmode=="stalker_atrium" then
                    ShakeIfClose(inst)
                end
            end),
            FrameEvent(304, function(inst)
                if inst.sg.statemem.epicmode=="stalker_atrium" then
                    local pos = inst:GetPosition()
                    local rose = SpawnPrefab("flower_rose")
                    rose.planted = true
                    rose.Transform:SetPosition(pos:Get())
                end
            end),
        },

        events =
        {
            EventHandler("animover", function(inst)
                if inst.AnimState:AnimDone() then
                    local data = inst.sg.statemem.epicdeathdata
                    if inst.components.wereepic then
                        inst.components.wereepic:OnBecameHuman()
                    end
                    if data then
                        if data ~= nil and data.cause == "file_load" and inst.components.revivablecorpse ~= nil then
                            inst.sg:GoToState("corpse", true)
                        elseif not inst.sg:HasStateTag("dead") then

                            if inst.shadowthrall_parasite_hosted_death and
                                not inst.components.rider:IsRiding() and
                                not inst:HasAnyTag("beaver", "weremoose", "weregoose") and
                                not inst.charlie_vinesave and
                                not (inst.wx78_backupbody_save and inst.CanSpawnBackupBody and inst:CanSpawnBackupBody()) and
                                not inst.components.revivablecorpse then
                                inst.sg:GoToState("death_hosted", data)
                            else
                                inst.sg:GoToState("death", data)
                            end
                        end
                    else
                        if inst.sg.statemem.epicmode~="stalker_atrium" and inst.sg.statemem.epicmode~="ancient_hulk" then
                            local corpse = SpawnPrefab("epic_"..inst.sg.statemem.epicmode.."_corpse")
                            local x,y,z = inst.Transform:GetWorldPosition()
                            corpse.Transform:SetPosition(x,y,z)
                            if inst.sg.statemem.epicmode=="malbatross" and not inst:IsOnPassablePoint()  then
                                corpse.AnimState:PlayAnimation("death_ocean_idle",true)
                            end
                            inst._epic_corpse = corpse
                        end
                        inst.sg:GoToState("epic_gravestone_rebirth")
                    end
                end
            end),
        },

		onexit = function(inst)
            if inst.sg.statemem.epicmode=="stalker_atrium" then
                inst.DynamicShadow:Enable(true)
            end
		end,
    })

AddStategraphState("wilson",State{
        name = "becameepic",
        tags = { "busy","epic","nopredict", "nomorph"},

        onenter = function(inst)
            inst.components.locomotor:Stop()
            local mode = inst.components.wereepic and inst.components.wereepic:GetEpicMode()
            if mode=="moose" or mode=="dragonfly" then
                inst.AnimState:PlayAnimation("taunt_pre")
                inst.AnimState:PushAnimation("taunt")
                inst.AnimState:PushAnimation("taunt_pst", false)
            elseif mode=="alterguardian_phase1" then
                inst.AnimState:SetBuild("alterguardian_spawn_death")
                inst.AnimState:SetBankAndPlayAnimation("alterguardian_spawn_death", "phase1_spawn")
                inst.components.health:SetInvincible(true)
                inst.SoundEmitter:PlaySound("moonstorm/creatures/boss/alterguardian1/spawn")
                inst.sg:AddStateTag("noattack")
            elseif mode=="alterguardian_phase2" then
                inst.AnimState:SetBuild("alterguardian_spawn_death")
                inst.AnimState:SetBankAndPlayAnimation("alterguardian_spawn_death", "phase2_spawn")
                inst.components.health:SetInvincible(true)
                inst.SoundEmitter:PlaySound("moonstorm/creatures/boss/alterguardian2/spawn")
                inst.sg:AddStateTag("noattack")
                set_lightvalues(inst, 0.1)
            elseif mode=="alterguardian_phase3" then
                inst.AnimState:SetBuild("alterguardian_spawn_death")
                inst.AnimState:SetBankAndPlayAnimation("alterguardian_spawn_death", "phase3_spawn")
                inst.components.health:SetInvincible(true)
                inst.SoundEmitter:PlaySound("moonstorm/creatures/boss/alterguardian3/spawn")
                inst.sg:AddStateTag("noattack")
                set_lightvalues(inst, 0.0)
            elseif mode=="stalker_atrium" then
                inst.components.health:SetInvincible(true)
                inst.Transform:SetNoFaced()
                inst.AnimState:PlayAnimation("enter")
                inst.SoundEmitter:PlaySound("dontstarve/ghost/ghost_get_bloodpump")
                inst.sg.statemem.baselightoverride = .1
            elseif mode=="mutatedwarg" then
                inst.components.health:SetInvincible(true)
                inst.sg:AddStateTag("noattack")
                inst.AnimState:PlayAnimation("mutate_pre")
                inst.AnimState:PushAnimation("mutate",false)
                inst.SoundEmitter:PlaySound("rifts3/mutated_deerclops/twitching_LP", "mutated_loop")

                inst.AnimState:OverrideSymbol("SPIKE", "warg_mutated_actions", "SPIKE")
                inst.AnimState:OverrideSymbol("hair_mutate", "warg_mutated_actions", "hair_mutate")
                inst.SoundEmitter:PlaySound("rifts3/mutated_varg/mutate_pre_f0")
            elseif mode=="mutatedbearger" then
                inst.components.health:SetInvincible(true)
                inst.sg:AddStateTag("noattack")
                inst.AnimState:PlayAnimation("mutate_pre")
                inst.AnimState:PushAnimation("mutate",false)
                inst.SoundEmitter:PlaySound("rifts3/mutated_deerclops/twitching_LP", "mutated_loop")

                inst.AnimState:OverrideSymbol("bearger_rib", "bearger_mutated", "bearger_rib")
                inst.SoundEmitter:PlaySound("rifts3/mutated_bearger/mutate_pre_tone_f0")
            elseif mode=="mutateddeerclops" then
                inst.components.health:SetInvincible(true)
                inst.sg:AddStateTag("noattack")
                inst.AnimState:PlayAnimation("mutate_pre")
                inst.AnimState:PushAnimation("mutate",false)
                inst.SoundEmitter:PlaySound("rifts3/mutated_deerclops/twitching_LP", "mutated_loop")

                inst.AnimState:OverrideSymbol("eye_crystal", "deerclops_mutated", "eye_crystal")
		        inst.AnimState:OverrideSymbol("frozen_debris", "deerclops_mutated", "frozen_debris")
                inst.SoundEmitter:PlaySound("rifts3/mutated_deerclops/mutate_pre_f0")
            elseif mode=="ancient_hulk" then
                inst.components.health:SetInvincible(true)
                inst.sg:AddStateTag("noattack")
                inst.AnimState:PlayAnimation("activate")
                inst.SoundEmitter:PlaySound("mnh_ancient_hulk_sound/creatures/boss/hulk_metal_robot/gears_LP","gears")
            else
                inst.AnimState:PlayAnimation("taunt")
            end

            inst.sg.statemem.epicmode = mode

            local x, y, z = inst.Transform:GetWorldPosition()
            local lightning = SpawnPrefab("lightning")
            lightning.Transform:SetPosition(x,y,z)

        end,

        timeline =
        {
            FrameEvent(0, function(inst)
                if inst.sg.statemem.epicmode=="stalker_atrium" then
                    inst.SoundEmitter:PlaySound("dontstarve/creatures/together/stalker/enter")
                elseif inst.sg.statemem.epicmode=="ancient_hulk" then
                    inst.SoundEmitter:SetParameter( "gears", "intensity", 0.2 )
                end
            end),
            FrameEvent(1, function(inst)
                if inst.sg.statemem.epicmode=="ancient_hulk" then
                    inst.SoundEmitter:PlaySound("mnh_ancient_hulk_sound/creatures/boss/hulk_metal_robot/electro")
                end
            end),
            FrameEvent(2, function(inst)
                if inst.sg.statemem.epicmode=="dragonfly" then
                    inst.SoundEmitter:PlaySound("dontstarve_DLC001/creatures/dragonfly/blink")
                end
            end),
            FrameEvent(4, function(inst)
                if inst.sg.statemem.epicmode=="daywalker" or inst.sg.statemem.epicmode=="daywalker2" then
                    inst.SoundEmitter:PlaySound("daywalker/voice/chainbreak_break_2")
                elseif inst.sg.statemem.epicmode=="ancient_hulk" then
                    inst.SoundEmitter:PlaySound("mnh_ancient_hulk_sound/creatures/boss/hulk_metal_robot/electro",nil,.5)
                end
            end),
			FrameEvent(5, function(inst)
                if inst.sg.statemem.epicmode=="deerclops"  then
                    inst.SoundEmitter:PlaySound(EPIC[inst.sg.statemem.epicmode].sounds.taunt_grrr)
                elseif inst.sg.statemem.epicmode=="moose" then
                    inst.SoundEmitter:PlaySound(EPIC[inst.sg.statemem.epicmode].sounds.flap)
                elseif inst.sg.statemem.epicmode=="antlion" then
                    inst.SoundEmitter:PlaySound("dontstarve/creatures/together/antlion/taunt")
                elseif inst.sg.statemem.epicmode=="malbatross" then
                    inst.SoundEmitter:PlaySound("saltydog/creatures/boss/malbatross/taunt")
                end
            end),
            FrameEvent(6, function(inst)
                if inst.sg.statemem.epicmode=="mutateddeerclops" then
                    inst.SoundEmitter:PlaySound("rifts3/mutated_deerclops/ice_grow_4f_leadin")
                elseif inst.sg.statemem.epicmode=="ancient_hulk" then
                    inst.SoundEmitter:PlaySound("mnh_ancient_hulk_sound/creatures/boss/hulk_metal_robot/arm/active")
                end
            end),
            FrameEvent(7, function(inst)
                if inst.sg.statemem.epicmode=="moose" then
                    inst.SoundEmitter:PlaySound(EPIC[inst.sg.statemem.epicmode].sounds.taunt)
                end
            end),
            FrameEvent(8, function(inst)
                if inst.sg.statemem.epicmode=="bearger" then
                    inst.SoundEmitter:PlaySound(EPIC[inst.sg.statemem.epicmode].sounds.taunt)
                elseif inst.sg.statemem.epicmode=="malbatross" then
                    spawnripple(inst)
                elseif inst.sg.statemem.epicmode=="beequeen" then
                    DoScreech(inst)
                elseif inst.sg.statemem.epicmode=="alterguardian_phase2" then
                    set_lightvalues(inst, 0.4)
                end
            end),
            FrameEvent(9, function(inst)
                if inst.sg.statemem.epicmode=="moose" then
                    inst.SoundEmitter:PlaySound(EPIC[inst.sg.statemem.epicmode].sounds.flap)
                elseif inst.sg.statemem.epicmode=="beequeen" then
                    DoScreechAlert(inst)
                end
            end),
            FrameEvent(10, function(inst)
                if inst.sg.statemem.epicmode=="ancient_hulk" then
                    inst.SoundEmitter:PlaySound("mnh_ancient_hulk_sound/creatures/boss/hulk_metal_robot/arm/active")
                end
            end),
            FrameEvent(12, function(inst)
                if inst.sg.statemem.epicmode=="alterguardian_phase3" then
                    set_lightvalues(inst, 0.05)
                elseif inst.sg.statemem.epicmode=="ancient_hulk" then
                    inst.SoundEmitter:PlaySound("mnh_ancient_hulk_sound/creatures/boss/hulk_metal_robot/arm/active",nil,.5)
                end
            end),
            FrameEvent(13, function(inst)
                if inst.sg.statemem.epicmode=="moose" then
                    inst.SoundEmitter:PlaySound(EPIC[inst.sg.statemem.epicmode].sounds.flap)
                end
            end),
            FrameEvent(14, function(inst)
                if inst.sg.statemem.epicmode=="alterguardian_phase3" then
                    set_lightvalues(inst, 0.10)
                elseif inst.sg.statemem.epicmode=="mutatedwarg" then
                    inst.SoundEmitter:KillSound("mutated_loop")
                    inst.SoundEmitter:PlaySound("rifts3/mutated_varg/mutate_pre_f14")
                end
            end),
			FrameEvent(16, function(inst)
                if inst.sg.statemem.epicmode=="deerclops" then
                    inst.SoundEmitter:PlaySound(EPIC[inst.sg.statemem.epicmode].sounds.taunt_howl)
                end
            end),
            FrameEvent(17, function(inst)
                if inst.sg.statemem.epicmode=="moose" then
                    inst.SoundEmitter:PlaySound(EPIC[inst.sg.statemem.epicmode].sounds.flap)
                end
            end),
            FrameEvent(18, function(inst)
                if inst.sg.statemem.epicmode=="daywalker" or inst.sg.statemem.epicmode=="daywalker2" then
                    inst.components.epicscare:Scare(5)
                elseif inst.sg.statemem.epicmode=="stalker_atrium" then
                    BlinkLow(inst)
                end
            end),
            FrameEvent(19, function(inst)
                if inst.sg.statemem.epicmode=="dragonfly" then
                    inst.SoundEmitter:PlaySound("dontstarve_DLC001/creatures/dragonfly/buttstomp")
                    inst.SoundEmitter:PlaySound("dontstarve_DLC001/creatures/dragonfly/buttstomp_voice")
                elseif inst.sg.statemem.epicmode=="daywalker" then
                    inst.SoundEmitter:PlaySound("daywalker/action/step", nil, 0.3)
				    ShakeAllCameras(CAMERASHAKE.FULL, 1.4, .02, .2, inst, 30)
                elseif inst.sg.statemem.epicmode=="daywalker2" then
                    inst.SoundEmitter:PlaySound("qol1/daywalker_scrappy/step", nil, 0.3)
				    ShakeAllCameras(CAMERASHAKE.FULL, 1.4, .02, .2, inst, 30)
                elseif inst.sg.statemem.epicmode=="stalker_atrium" then
                    BlinkOff(inst)
                end
            end),
            FrameEvent(20, function(inst)
                if inst.sg.statemem.epicmode=="ancient_hulk" then
                    inst.SoundEmitter:PlaySound("mnh_ancient_hulk_sound/creatures/boss/hulk_metal_robot/arm/active")
                end
            end),
            FrameEvent(21, function(inst)
                if inst.sg.statemem.epicmode=="moose" then
                    inst.SoundEmitter:PlaySound(EPIC[inst.sg.statemem.epicmode].sounds.flap)
                end
            end),
            FrameEvent(24, function(inst)
                if inst.sg.statemem.epicmode=="ancient_hulk" then
                    inst.SoundEmitter:PlaySound("mnh_ancient_hulk_sound/creatures/boss/hulk_metal_robot/electro")
                end
            end),
            FrameEvent(26, function(inst)
                if inst.sg.statemem.epicmode=="dragonfly" then
                    inst.SoundEmitter:PlaySound("dontstarve_DLC001/creatures/dragonfly/buttstomp")
                    inst.SoundEmitter:PlaySound("dontstarve_DLC001/creatures/dragonfly/buttstomp_voice")
                elseif inst.sg.statemem.epicmode=="ancient_hulk" then
                    inst.SoundEmitter:SetParameter( "gears", "intensity", 0.3 )
                end
            end),
            FrameEvent(28, function(inst)
                if inst.sg.statemem.epicmode=="alterguardian_phase3" then
                    set_lightvalues(inst, 0.15)
                elseif inst.sg.statemem.epicmode=="ancient_hulk" then
                    inst.SoundEmitter:PlaySound("mnh_ancient_hulk_sound/creatures/boss/hulk_metal_robot/electro",nil,.5)
                    inst.SoundEmitter:PlaySoundWithParams("mnh_ancient_hulk_sound/creatures/boss/hulk_metal_robot/ribs/servo", {intensity=math.random()})
                end
            end),
            FrameEvent(29, function(inst)
                if inst.sg.statemem.epicmode=="stalker_atrium" then
                    BlinkLow(inst)
                end
            end),
            FrameEvent(30, function(inst)
                if inst.sg.statemem.epicmode=="stalker_atrium" then
                    BlinkOff(inst)
                    ShakeIfClose(inst)
                end
            end),
            FrameEvent(31, function(inst)
                if inst.sg.statemem.epicmode=="stalker_atrium" then
                    BlinkMed(inst)
                end
            end),
            FrameEvent(32, function(inst)
                if inst.sg.statemem.epicmode=="stalker_atrium" then
                    BlinkLow(inst)
                end
            end),
            FrameEvent(33, function(inst)
                if inst.sg.statemem.epicmode=="beequeen" then
                    DoScreech(inst)
                elseif inst.sg.statemem.epicmode=="alterguardian_phase3" then
                    set_lightvalues(inst,0.25)
                elseif inst.sg.statemem.epicmode=="stalker_atrium" then
                    BlinkOff(inst)
                end
            end),
            FrameEvent(34, function(inst)
                if inst.sg.statemem.epicmode=="beequeen" then
                    DoScreechAlert(inst)
                end
            end),
            FrameEvent(37, function(inst)
                if inst.sg.statemem.epicmode=="dragonfly" then
                    inst.SoundEmitter:PlaySound("dontstarve_DLC001/creatures/dragonfly/buttstomp")
                    inst.SoundEmitter:PlaySound("dontstarve_DLC001/creatures/dragonfly/buttstomp_voice")
                elseif inst.sg.statemem.epicmode=="stalker_atrium" then
                    BlinkMed(inst)
                elseif inst.sg.statemem.epicmode=="ancient_hulk" then
                    inst.SoundEmitter:PlaySound("mnh_ancient_hulk_sound/creatures/boss/hulk_metal_robot/electro")
                    inst.SoundEmitter:PlaySound("mnh_ancient_hulk_sound/creatures/boss/hulk_metal_robot/ribs/step")
                end
            end),
            FrameEvent(38, function(inst)
                if inst.sg.statemem.epicmode=="stalker_atrium" then
                    BlinkLow(inst)
                end
            end),
            FrameEvent(39, function(inst)
                if inst.sg.statemem.epicmode=="stalker_atrium" then
                    BlinkOff(inst)
                elseif inst.sg.statemem.epicmode=="ancient_hulk" then
                    inst.SoundEmitter:PlaySound("mnh_ancient_hulk_sound/creatures/boss/hulk_metal_robot/electro",nil,.5)
                end
            end),
            FrameEvent(40, function(inst)
                if inst.sg.statemem.epicmode=="alterguardian_phase3" then
                    set_lightvalues(inst, 0.10)
                elseif inst.sg.statemem.epicmode=="stalker_atrium" then
                    BlinkMed(inst)
                elseif inst.sg.statemem.epicmode=="ancient_hulk" then
                    inst.SoundEmitter:PlaySound("mnh_ancient_hulk_sound/creatures/boss/hulk_metal_robot/head/active")
                end
            end),
            FrameEvent(41, function(inst)
                if inst.sg.statemem.epicmode=="stalker_atrium" then
                    BlinkOff(inst)
                end
            end),
            FrameEvent(42, function(inst)
                if inst.sg.statemem.epicmode=="stalker_atrium" then
                    BlinkMed(inst)
                    ShakeIfClose(inst)
                elseif inst.sg.statemem.epicmode=="ancient_hulk" then
                    inst.SoundEmitter:PlaySound("mnh_ancient_hulk_sound/creatures/boss/hulk_metal_robot/electro")
                end
            end),
            FrameEvent(43, function(inst)
                if inst.sg.statemem.epicmode=="stalker_atrium" then
                    BlinkLow(inst)
                end
            end),
            FrameEvent(44, function(inst)
                if inst.sg.statemem.epicmode=="dragonfly" then
                    inst.SoundEmitter:PlaySound("dontstarve_DLC001/creatures/dragonfly/blink")
                elseif inst.sg.statemem.epicmode=="stalker_atrium" then
                    BlinkOff(inst)
                elseif inst.sg.statemem.epicmode=="ancient_hulk" then
                    inst.SoundEmitter:PlaySound("mnh_ancient_hulk_sound/creatures/boss/hulk_metal_robot/head/active")
                end
            end),
            FrameEvent(45, function(inst)
                if inst.sg.statemem.epicmode=="mutateddeerclops" then
                    inst.SoundEmitter:PlaySound("rifts3/mutated_deerclops/mutate_pre_f45")
                end
            end),
            FrameEvent(46, function(inst)
                if inst.sg.statemem.epicmode=="mutateddeerclops" then
                    inst.SoundEmitter:PlaySound("rifts3/mutated_deerclops/ice_grow_4f_leadin")
                elseif inst.sg.statemem.epicmode=="ancient_hulk" then
                    inst.SoundEmitter:PlaySoundWithParams("mnh_ancient_hulk_sound/creatures/boss/hulk_metal_robot/ribs/servo", {intensity=math.random()})
                    inst.SoundEmitter:PlaySound("mnh_ancient_hulk_sound/creatures/boss/hulk_metal_robot/start")
                end
            end),
            FrameEvent(47, function(inst)
                if inst.sg.statemem.epicmode=="daywalker" then
                    inst.SoundEmitter:PlaySound("daywalker/action/step", nil, 0.2)
                elseif inst.sg.statemem.epicmode=="daywalker2" then
                    inst.SoundEmitter:PlaySound("qol1/daywalker_scrappy/step", nil, 0.2)
                elseif inst.sg.statemem.epicmode=="stalker_atrium" then
                    inst.SoundEmitter:PlaySound("dontstarve/creatures/together/stalker/head")
                end
            end),
            FrameEvent(48, function(inst)
                if inst.sg.statemem.epicmode=="alterguardian_phase2" then
                    set_lightvalues(inst, 0.425)
                end
            end),
            FrameEvent(49, function(inst)
                if inst.sg.statemem.epicmode=="alterguardian_phase2" then
                    set_lightvalues(inst, 0.45)
                end
            end),
            FrameEvent(50, function(inst)
                if inst.sg.statemem.epicmode=="alterguardian_phase2" then
                    set_lightvalues(inst, 0.475)
                elseif inst.sg.statemem.epicmode=="stalker_atrium" then
                    BlinkMed(inst)
                elseif inst.sg.statemem.epicmode=="ancient_hulk" then
                    inst.SoundEmitter:SetParameter( "gears", "intensity", 0.4 )
                end
            end),
            FrameEvent(51, function(inst)
                if inst.sg.statemem.epicmode=="alterguardian_phase2" then
                    set_lightvalues(inst, 0.5)
                elseif inst.sg.statemem.epicmode=="stalker_atrium" then
                    BlinkLow(inst)
                end
            end),
            FrameEvent(52, function(inst)
                if inst.sg.statemem.epicmode=="alterguardian_phase2" then
                    set_lightvalues(inst, 0.525)
                elseif inst.sg.statemem.epicmode=="stalker_atrium" then
                    BlinkOff(inst)
                end
            end),
            FrameEvent(53, function(inst)
                if inst.sg.statemem.epicmode=="alterguardian_phase2" then
                    set_lightvalues(inst, 0.55)
                end
            end),
            FrameEvent(54, function(inst)
                if inst.sg.statemem.epicmode=="alterguardian_phase2" then
                    set_lightvalues(inst, 0.575)
                elseif inst.sg.statemem.epicmode=="stalker_atrium" then
                    BlinkMed(inst)
                elseif inst.sg.statemem.epicmode=="ancient_hulk" then
                    inst.SoundEmitter:PlaySound("mnh_ancient_hulk_sound/creatures/boss/hulk_metal_robot/leg/active")
                end
            end),
            FrameEvent(55, function(inst)
                if inst.sg.statemem.epicmode=="alterguardian_phase2" then
                    set_lightvalues(inst, 0.44)
                elseif inst.sg.statemem.epicmode=="stalker_atrium" then
                    BlinkLow(inst)
                end
            end),
            FrameEvent(56, function(inst)
                if inst.sg.statemem.epicmode=="stalker_atrium" then
                    BlinkOff(inst)
                elseif inst.sg.statemem.epicmode=="ancient_hulk" then
                    inst.SoundEmitter:PlaySound("mnh_ancient_hulk_sound/creatures/boss/hulk_metal_robot/leg/active")
                end
            end),
            FrameEvent(57, function(inst)
                if inst.sg.statemem.epicmode=="beequeen" then
                    inst.sg:RemoveStateTag("busy")
                elseif inst.sg.statemem.epicmode=="stalker_atrium" then
                    BlinkHigh(inst)
                    ShakeIfClose(inst)
                end
            end),
            FrameEvent(58, function(inst)
                if inst.sg.statemem.epicmode=="stalker_atrium" then
                    BlinkOff(inst)
                elseif inst.sg.statemem.epicmode=="ancient_hulk" then
                    inst.SoundEmitter:PlaySound("mnh_ancient_hulk_sound/creatures/boss/hulk_metal_robot/leg/active")
                end
            end),
            FrameEvent(60, function(inst)
                if inst.sg.statemem.epicmode=="stalker_atrium" then
                    BlinkMed(inst)
                elseif inst.sg.statemem.epicmode=="ancient_hulk" then
                    inst.SoundEmitter:PlaySound("mnh_ancient_hulk_sound/creatures/boss/hulk_metal_robot/leg/active")
                end
            end),
            FrameEvent(61, function(inst)
                if inst.sg.statemem.epicmode=="stalker_atrium" then
                    BlinkLow(inst)
                elseif inst.sg.statemem.epicmode=="mutateddeerclops" then
                    inst.SoundEmitter:PlaySound("rifts3/mutated_deerclops/ice_grow_4f_leadin")
                end
            end),
            FrameEvent(62, function(inst)
                if inst.sg.statemem.epicmode=="alterguardian_phase2" then
                    set_lightvalues(inst, 0.5)
                elseif inst.sg.statemem.epicmode=="stalker_atrium" then
                    BlinkOff(inst)
                end
            end),
            FrameEvent(63, function(inst)
                if inst.sg.statemem.epicmode=="alterguardian_phase3" then
                    set_lightvalues(inst, 0.175)
                elseif inst.sg.statemem.epicmode=="stalker_atrium" then
                    inst.sg.statemem.baselightoverride = 0
                    inst.sg.statemem.fadeout = .2
                elseif inst.sg.statemem.epicmode=="ancient_hulk" then
                    inst.SoundEmitter:PlaySoundWithParams("mnh_ancient_hulk_sound/creatures/boss/hulk_metal_robot/ribs/servo", {intensity=math.random()})
                end
            end),
            FrameEvent(65, function(inst)
                if inst.sg.statemem.epicmode=="alterguardian_phase2" then
                    set_lightvalues(inst, 0.6)
                elseif inst.sg.statemem.epicmode=="ancient_hulk" then
                    inst.SoundEmitter:PlaySound("mnh_ancient_hulk_sound/creatures/boss/hulk_metal_robot/electro",nil,.5)
                end
            end),
            FrameEvent(66, function(inst)
                if inst.sg.statemem.epicmode=="mutateddeerclops" then
                    inst.SoundEmitter:PlaySound("rifts3/mutated_deerclops/ice_grow_4f_leadin")
                end
            end),
            FrameEvent(68, function(inst)
                if inst.sg.statemem.epicmode=="mutatedbearger" then
                    inst.SoundEmitter:PlaySound("dontstarve_DLC001/creatures/bearger/step_soft")
                end
            end),
            FrameEvent(69, function(inst)
                if inst.sg.statemem.epicmode=="alterguardian_phase2" then
                    set_lightvalues(inst, 0.4)
                end
            end),
            FrameEvent(70, function(inst)
                if inst.sg.statemem.epicmode=="alterguardian_phase3" then
                    set_lightvalues(inst, 0.225)
                elseif inst.sg.statemem.epicmode=="mutatedbearger" then
                    ShakeAllCameras(CAMERASHAKE.FULL, .35, .02, .5, inst, 30)
                elseif inst.sg.statemem.epicmode=="mutateddeerclops" then
                    inst.SoundEmitter:KillSound("mutated_loop")
                end
            end),
            FrameEvent(71, function(inst)
                if inst.sg.statemem.epicmode=="mutateddeerclops" then
                    inst.SoundEmitter:PlaySound("rifts3/mutated_varg/mutate")
                end
            end),
            FrameEvent(75, function(inst)
                if inst.sg.statemem.epicmode=="alterguardian_phase2" then
                    set_lightvalues(inst, 0.625)
                elseif inst.sg.statemem.epicmode=="ancient_hulk" then
                    inst.SoundEmitter:SetParameter( "gears", "intensity", 1 )
                end
            end),
            FrameEvent(79, function(inst)
                if inst.sg.statemem.epicmode=="alterguardian_phase3" then
                    set_lightvalues(inst, 0.4)
                end
            end),
            FrameEvent(80, function(inst)
                if inst.sg.statemem.epicmode=="alterguardian_phase2" then
                    set_lightvalues(inst, 0.75)
                end
            end),
            FrameEvent(83, function(inst)
                if inst.sg.statemem.epicmode=="ancient_hulk" then
                    inst.SoundEmitter:PlaySound("mnh_ancient_hulk_sound/creatures/boss/hulk_metal_robot/electro")
                end
            end),
            FrameEvent(84, function(inst)
                if inst.sg.statemem.epicmode=="ancient_hulk" then
                    inst.SoundEmitter:PlaySoundWithParams("mnh_ancient_hulk_sound/creatures/boss/hulk_metal_robot/ribs/servo", {intensity=math.random()})
                end
            end),
            FrameEvent(86, function(inst)
                if inst.sg.statemem.epicmode=="ancient_hulk" then
                    inst.SoundEmitter:PlaySound("mnh_ancient_hulk_sound/creatures/boss/hulk_metal_robot/electro",nil,.5)
                end
            end),
            FrameEvent(88, function(inst)
                if inst.sg.statemem.epicmode=="alterguardian_phase2" then
                    set_lightvalues(inst, 0.85)
                end
            end),
            FrameEvent(97, function(inst)
                if inst.sg.statemem.epicmode=="alterguardian_phase3" then
                    set_lightvalues(inst, 0.6)
                end
            end),
            FrameEvent(100, function(inst)
                if inst.sg.statemem.epicmode=="ancient_hulk" then
                    inst.SoundEmitter:SetParameter( "gears", "intensity", .7 )
                end
            end),
            FrameEvent(101, function(inst)
                if inst.sg.statemem.epicmode=="alterguardian_phase3" then
                    set_lightvalues(inst, 0.9)
                elseif inst.sg.statemem.epicmode=="ancient_hulk" then
                    inst.SoundEmitter:PlaySound("mnh_ancient_hulk_sound/creatures/boss/hulk_metal_robot/leg/step")
                end
            end),
            FrameEvent(103, function(inst)
                if inst.sg.statemem.epicmode=="ancient_hulk" then
                    inst.SoundEmitter:PlaySound("mnh_ancient_hulk_sound/creatures/boss/hulk_metal_robot/electro")
                end
            end),
            FrameEvent(106, function(inst)
                if inst.sg.statemem.epicmode=="mutatedwarg" then
                    inst.SoundEmitter:PlaySound("rifts3/mutated_varg/mutate")
                elseif inst.sg.statemem.epicmode=="ancient_hulk" then
                    inst.SoundEmitter:PlaySound("mnh_ancient_hulk_sound/creatures/boss/hulk_metal_robot/taunt")
                    inst.SoundEmitter:PlaySound("mnh_ancient_hulk_sound/creatures/boss/hulk_metal_robot/electro",nil,.25)
                end
            end),
            FrameEvent(113, function(inst)
                if inst.sg.statemem.epicmode=="alterguardian_phase3" then
                    set_lightvalues(inst, 0.95)
                elseif inst.sg.statemem.epicmode=="ancient_hulk" then
                    inst.SoundEmitter:PlaySound("mnh_ancient_hulk_sound/creatures/boss/hulk_metal_robot/electro",nil,.25)
                end
            end),
            FrameEvent(125, function(inst)
                if inst.sg.statemem.epicmode=="alterguardian_phase3" then
                    set_lightvalues(inst, 0.9)
                elseif inst.sg.statemem.epicmode=="mutatedbearger" then
                    inst.SoundEmitter:KillSound("mutated_loop")
                    inst.SoundEmitter:PlaySound("dontstarve_DLC001/creatures/bearger/step_soft")
                elseif inst.sg.statemem.epicmode=="ancient_hulk" then
                    inst.SoundEmitter:PlaySoundWithParams("mnh_ancient_hulk_sound/creatures/boss/hulk_metal_robot/ribs/servo", {intensity=math.random()})
                end
            end),
            FrameEvent(150, function(inst)
                if inst.sg.statemem.epicmode=="mutatedbearger" then
                    inst.SoundEmitter:PlaySound("rifts3/mutated_bearger/taunt")
                    inst.SoundEmitter:PlaySound("rifts3/mutated_varg/mutate")
                end
            end),
            FrameEvent(175, function(inst)
                if inst.sg.statemem.epicmode=="mutatedbearger" then
                    DoFootstep(inst)
                end
            end),
            FrameEvent(177, function(inst)
                if inst.sg.statemem.epicmode=="mutatedbearger" then
                    inst.SoundEmitter:PlaySound("dontstarve_DLC001/creatures/bearger/step_soft")
                end
            end),
        },

        onupdate = function(inst)
            if inst.sg.statemem.epicmode=="stalker_atrium" then
                if inst.sg.statemem.fadeout ~= nil then
                    if inst.sg.statemem.fadeout > .02 then
                        inst.sg.statemem.fadeout = inst.sg.statemem.fadeout - .02
                        inst.AnimState:SetLightOverride(inst.sg.statemem.fadeout)
                    else
                        inst.sg.statemem.fadeout = nil
                        inst.AnimState:SetLightOverride(0)
                    end
                elseif inst.sg.statemem.baselightoverride < .2 then
                    inst.sg.statemem.baselightoverride = math.min(.2, inst.sg.statemem.baselightoverride + .01)
                    inst.AnimState:SetLightOverride(inst.sg.statemem.baselightoverride)
                end
            end
        end,

        events =
        {
            EventHandler("animover", function(inst)
                if inst.AnimState:AnimDone() then
                    if inst.sg.statemem.epicmode=="stalker_atrium" or inst.sg.statemem.epicmode=="mutateddeerclops" then
                        inst.sg:GoToState("epic_taunt")
                    else
                        inst.sg:GoToState("epic_idle")
                    end
                end
            end),
        },

        onexit = function (inst)
            if inst.sg.statemem.epicmode=="alterguardian_phase1" then
                inst.components.health:SetInvincible(false)
                inst.AnimState:SetBuild("alterguardian_phase1")
                inst.AnimState:SetBankAndPlayAnimation("alterguardian_phase1", "idle")
            elseif inst.sg.statemem.epicmode=="alterguardian_phase2" then
                inst.components.health:SetInvincible(false)
                inst.AnimState:SetBuild("alterguardian_phase2")
                inst.AnimState:SetBankAndPlayAnimation("alterguardian_phase2", "idle")
            elseif inst.sg.statemem.epicmode=="alterguardian_phase3" then
                inst.components.health:SetInvincible(false)
                inst.AnimState:SetBuild("alterguardian_phase3")
                inst.AnimState:SetBankAndPlayAnimation("alterguardian_phase3", "idle")
            elseif inst.sg.statemem.epicmode=="stalker_atrium" then
                inst.Transform:SetFourFaced()
                inst.components.health:SetInvincible(false)
                inst.sg.statemem.baselightoverride = nil
                BlinkOff(inst)
            elseif inst.sg.statemem.epicmode=="mutatedwarg" then
                inst.components.health:SetInvincible(false)
                inst.AnimState:ClearOverrideSymbol("SPIKE")
                inst.AnimState:ClearOverrideSymbol("hair_mutate")
            elseif inst.sg.statemem.epicmode=="mutatedbearger" then
                inst.components.health:SetInvincible(false)
                inst.AnimState:ClearOverrideSymbol("bearger_rib")
            elseif inst.sg.statemem.epicmode=="mutateddeerclops" then
                inst.components.health:SetInvincible(false)
                inst.AnimState:ClearOverrideSymbol("eye_crystal")
                inst.AnimState:ClearOverrideSymbol("frozen_debris")
                if inst.sg.mem.mutateddeerclops_circle == nil then
                    inst.sg.mem.mutateddeerclops_circle = SpawnPrefab("deerclops_aura_circle_fx")
                    local x, y, z = inst.Transform:GetWorldPosition()
                    inst.sg.mem.mutateddeerclops_circle.Transform:SetPosition(x, 0, z)
                    inst.sg.mem.mutateddeerclops_circle:GrowFX()
                end
            elseif inst.sg.statemem.epicmode=="ancient_hulk" then
                inst.components.health:SetInvincible(false)
            end
            inst.SoundEmitter:KillSound("mutated_loop")
        end
    })

AddStategraphState("wilson",State{
        name = "epic_taunt",
        tags = { "epic_taunt","pausepredict", "epic","epic_skill","busy"},

        onenter = function(inst)
            local mode = inst.components.wereepic and inst.components.wereepic:GetEpicMode()
            inst.components.locomotor:Stop()
            if mode=="moose" or mode=="dragonfly" then
                inst.AnimState:PlayAnimation("taunt_pre")
                inst.AnimState:PushAnimation("taunt")
                inst.AnimState:PushAnimation("taunt_pst", false)
            elseif mode=="beequeen" then
                FaceTarget(inst)
                inst.AnimState:PlayAnimation("screech")
            elseif mode=="stalker_atrium" then
                inst.AnimState:PlayAnimation("taunt1")
                inst.SoundEmitter:PlaySound("dontstarve/creatures/together/stalker/out")
            elseif mode=="mutatedwarg" then
                inst.AnimState:PlayAnimation("howl")
                inst.SoundEmitter:PlaySound("rifts3/mutated_varg/howl")
            else
                inst.AnimState:PlayAnimation("taunt")
            end

            inst.sg.statemem.epicmode = mode

            if inst.components.playercontroller then
                inst.components.playercontroller:RemotePausePrediction()
            end
        end,

        timeline =
        {
            FrameEvent(2, function(inst)
                if inst.sg.statemem.epicmode=="dragonfly" then
                    inst.SoundEmitter:PlaySound("dontstarve_DLC001/creatures/dragonfly/blink")
                end
            end),
            FrameEvent(4, function(inst)
                if inst.sg.statemem.epicmode=="daywalker" or inst.sg.statemem.epicmode=="daywalker2" then
                    inst.SoundEmitter:PlaySound("daywalker/voice/chainbreak_break_2")
                end
            end),
			FrameEvent(5, function(inst)
                if inst.sg.statemem.epicmode=="deerclops" or inst.sg.statemem.epicmode=="mutateddeerclops" then
                    inst.SoundEmitter:PlaySound(EPIC[inst.sg.statemem.epicmode].sounds.taunt_grrr)
                elseif inst.sg.statemem.epicmode=="moose" then
                    inst.SoundEmitter:PlaySound(EPIC[inst.sg.statemem.epicmode].sounds.flap)
                elseif inst.sg.statemem.epicmode=="antlion" then
                    inst.SoundEmitter:PlaySound("dontstarve/creatures/together/antlion/taunt")
                elseif inst.sg.statemem.epicmode=="malbatross" then
                    inst.SoundEmitter:PlaySound("saltydog/creatures/boss/malbatross/taunt")
                end
            end),
            FrameEvent(7, function(inst)
                if inst.sg.statemem.epicmode=="moose" then
                    inst.SoundEmitter:PlaySound(EPIC[inst.sg.statemem.epicmode].sounds.taunt)
                end
            end),
            FrameEvent(8, function(inst)
                if inst.sg.statemem.epicmode=="bearger" or inst.sg.statemem.epicmode=="mutatedbearger" then
                    inst.SoundEmitter:PlaySound(EPIC[inst.sg.statemem.epicmode].sounds.taunt)
                elseif inst.sg.statemem.epicmode=="malbatross" then
                    spawnripple(inst)
                elseif inst.sg.statemem.epicmode=="beequeen" then
                    DoScreech(inst)
                end
            end),
            FrameEvent(9, function(inst)
                if inst.sg.statemem.epicmode=="moose" then
                    inst.SoundEmitter:PlaySound(EPIC[inst.sg.statemem.epicmode].sounds.flap)
                elseif inst.sg.statemem.epicmode=="beequeen" then
                    DoScreechAlert(inst)
                end
            end),
            FrameEvent(13, function(inst)
                if inst.sg.statemem.epicmode=="moose" then
                    inst.SoundEmitter:PlaySound(EPIC[inst.sg.statemem.epicmode].sounds.flap)
                end
            end),
            FrameEvent(14, function(inst)
                if inst.sg.statemem.epicmode=="stalker_atrium" then
                    inst.SoundEmitter:PlaySound("dontstarve/creatures/together/stalker/taunt")
                end
            end),
			FrameEvent(16, function(inst)
                if inst.sg.statemem.epicmode=="deerclops" or inst.sg.statemem.epicmode=="mutateddeerclops" then
                    inst.SoundEmitter:PlaySound(EPIC[inst.sg.statemem.epicmode].sounds.taunt_howl)
                end
            end),
            FrameEvent(17, function(inst)
                if inst.sg.statemem.epicmode=="moose" then
                    inst.SoundEmitter:PlaySound(EPIC[inst.sg.statemem.epicmode].sounds.flap)
                end
            end),
            FrameEvent(18, function(inst)
                if inst.sg.statemem.epicmode=="daywalker" or inst.sg.statemem.epicmode=="daywalker2" then
                    inst.components.epicscare:Scare(5)
                elseif inst.sg.statemem.epicmode=="stalker_atrium" then
                    ShakeAllCameras(CAMERASHAKE.FULL, 1.2, .03, .7, inst, 30)
                end
            end),
            FrameEvent(19, function(inst)
                if inst.sg.statemem.epicmode=="dragonfly" then
                    inst.SoundEmitter:PlaySound("dontstarve_DLC001/creatures/dragonfly/buttstomp")
                    inst.SoundEmitter:PlaySound("dontstarve_DLC001/creatures/dragonfly/buttstomp_voice")
                elseif inst.sg.statemem.epicmode=="daywalker" then
                    inst.SoundEmitter:PlaySound("daywalker/action/step", nil, 0.3)
				    ShakeAllCameras(CAMERASHAKE.FULL, 1.4, .02, .2, inst, 30)
                elseif inst.sg.statemem.epicmode=="daywalker2" then
                    inst.SoundEmitter:PlaySound("qol1/daywalker_scrappy/step", nil, 0.3)
				    ShakeAllCameras(CAMERASHAKE.FULL, 1.4, .02, .2, inst, 30)
                elseif inst.sg.statemem.epicmode=="stalker_atrium" then
                    inst.components.epicscare:Scare(5)
                end
            end),
            FrameEvent(21, function(inst)
                if inst.sg.statemem.epicmode=="moose" then
                    inst.SoundEmitter:PlaySound(EPIC[inst.sg.statemem.epicmode].sounds.flap)
                end
            end),
            FrameEvent(26, function(inst)
                if inst.sg.statemem.epicmode=="dragonfly" then
                    inst.SoundEmitter:PlaySound("dontstarve_DLC001/creatures/dragonfly/buttstomp")
                    inst.SoundEmitter:PlaySound("dontstarve_DLC001/creatures/dragonfly/buttstomp_voice")
                end
            end),
            FrameEvent(33, function(inst)
                if inst.sg.statemem.epicmode=="beequeen" then
                    DoScreech(inst)
                end
            end),
            FrameEvent(34, function(inst)
                if inst.sg.statemem.epicmode=="beequeen" then
                    DoScreechAlert(inst)
                end
            end),
            FrameEvent(37, function(inst)
                if inst.sg.statemem.epicmode=="dragonfly" then
                    inst.SoundEmitter:PlaySound("dontstarve_DLC001/creatures/dragonfly/buttstomp")
                    inst.SoundEmitter:PlaySound("dontstarve_DLC001/creatures/dragonfly/buttstomp_voice")
                end
            end),
            FrameEvent(44, function(inst)
                if inst.sg.statemem.epicmode=="dragonfly" then
                    inst.SoundEmitter:PlaySound("dontstarve_DLC001/creatures/dragonfly/blink")
                end
            end),
            FrameEvent(47, function(inst)
                if inst.sg.statemem.epicmode=="daywalker" then
                    inst.SoundEmitter:PlaySound("daywalker/action/step", nil, 0.2)
                elseif inst.sg.statemem.epicmode=="daywalker2" then
                    inst.SoundEmitter:PlaySound("qol1/daywalker_scrappy/step", nil, 0.2)
                end
            end),
            FrameEvent(57, function(inst)
                if inst.sg.statemem.epicmode=="beequeen" then
                    inst.sg:RemoveStateTag("busy")
                end
            end),
            FrameEvent(58, function(inst)
                if inst.sg.statemem.epicmode=="stalker_atrium" then
                    inst.sg:RemoveStateTag("busy")
                end
            end),
        },

        events =
        {
            EventHandler("animover", function(inst)
                if inst.AnimState:AnimDone() then
                    inst.sg:GoToState("epic_idle")
                end
            end),
        },

        onexit = function (inst)

        end
    })

AddStategraphState("wilson",State{
        name = "deerclops_laserbeam",
        tags = { "busy","epic_skill","attack","epic" },

        onenter = function(inst)
            inst.Physics:Stop()
            inst.Light:Enable(true)
			inst.AnimState:SetBuild("deerclops_yule")
            inst.AnimState:PlayAnimation("atk2")
			inst.Transform:SetEightFaced()
			local buffaction = inst:GetBufferedAction()
            if buffaction then
				if buffaction.pos then
					inst:ForceFacePoint(buffaction:GetActionPoint():Get())
					inst._facepoint_x,inst._facepoint_y,inst._facepoint_z = buffaction:GetActionPoint():Get()
                elseif buffaction.target and buffaction.target:IsValid() then
                    local x, y, z = buffaction.target.Transform:GetWorldPosition()
                    inst:ForceFacePoint(x, y, z)
                    inst._facepoint_x, inst._facepoint_y, inst._facepoint_z = x, y, z
                end
			end

            inst.SoundEmitter:PlaySound("dontstarve/creatures/deerclops/charge")
        end,

        onupdate = function(inst)
            if inst._facepoint_x and inst._facepoint_y and inst._facepoint_z then
                inst:ForceFacePoint(inst._facepoint_x, inst._facepoint_y, inst._facepoint_z)
            end
            if inst.sg.statemem.lightval then
                inst.sg.statemem.lightval = inst.sg.statemem.lightval * .99
                SetLightValueAndOverride(inst, inst.sg.statemem.lightval, (inst.sg.statemem.lightval - 1) * 3)
            end
        end,

        timeline =
        {
			TimeEvent(FRAMES, function(inst) inst.SoundEmitter:PlaySound("dontstarve/creatures/deerclops/attack", nil) end),
			TimeEvent(4 * FRAMES, function(inst) inst.SoundEmitter:PlaySound("dontstarve/creatures/deerclops/step", nil, .7) end),
            TimeEvent(6 * FRAMES, function(inst)
                ShakeAllCameras(CAMERASHAKE.VERTICAL, .2, .02, .5, inst, 40)
                SetLightValue(inst, .97)
            end),
            TimeEvent(7 * FRAMES, function(inst) SetLightValueAndOverride(inst, 1, .2) end),
            TimeEvent(8 * FRAMES, function(inst) SetLightValueAndOverride(inst, .99, .15) end),
            TimeEvent(9 * FRAMES, function(inst) SetLightValueAndOverride(inst, .97, .05) end),
            TimeEvent(10 * FRAMES, function(inst) SetLightValueAndOverride(inst, .96, 0) end),
            TimeEvent(11 * FRAMES, function(inst) SetLightValueAndOverride(inst, 1.01, .35) end),
            TimeEvent(12 * FRAMES, function(inst) SetLightValueAndOverride(inst, 1, .3) end),
            TimeEvent(13 * FRAMES, function(inst) SetLightValueAndOverride(inst, .95, .05) end),
            TimeEvent(14 * FRAMES, function(inst) SetLightValueAndOverride(inst, .94, 0) end),
            TimeEvent(15 * FRAMES, function(inst) SetLightValueAndOverride(inst, 1, .3) end),
            TimeEvent(16 * FRAMES, function(inst) SetLightValueAndOverride(inst, .99, .25) end),
            TimeEvent(17 * FRAMES, function(inst) SetLightValueAndOverride(inst, .92, .05) end),
            TimeEvent(18 * FRAMES, function(inst)
                SetLightValueAndOverride(inst, .9, 0)
				inst.SoundEmitter:PlaySound("dontstarve/creatures/deerclops/taunt_howl", nil, .4)
            end),
            TimeEvent(19 * FRAMES, function(inst)
                inst.SoundEmitter:PlaySound("dontstarve/creatures/deerclops/laser")
                SpawnLaser(inst)
                SetLightValueAndOverride(inst, 1.08, .7)
            end),
            TimeEvent(20 * FRAMES, function(inst) SetLightValueAndOverride(inst, 1.12, 1) end),
            TimeEvent(21 * FRAMES, function(inst) SetLightValueAndOverride(inst, 1.1, .9) end),
            TimeEvent(22 * FRAMES, function(inst) SetLightValueAndOverride(inst, 1.06, .4) end),
            TimeEvent(23 * FRAMES, function(inst) SetLightValueAndOverride(inst, 1.1, .6) end),
            TimeEvent(24 * FRAMES, function(inst) SetLightValueAndOverride(inst, 1.06, .3) end),
            TimeEvent(25 * FRAMES, function(inst) SetLightValueAndOverride(inst, 1.05, .25) end),
            TimeEvent(26 * FRAMES, function(inst) SetLightValueAndOverride(inst, 1.1, .5) end),
            TimeEvent(27 * FRAMES, function(inst) SetLightValueAndOverride(inst, 1.08, .45) end),
            TimeEvent(28 * FRAMES, function(inst) SetLightValueAndOverride(inst, 1.05, .2) end),
            TimeEvent(29 * FRAMES, function(inst) SetLightValueAndOverride(inst, 1.1, .3) end),
            TimeEvent(30 * FRAMES, function(inst)
                inst.sg.statemem.lightval = 1.1
            end),
            TimeEvent(32 * FRAMES, function(inst)
				inst.SoundEmitter:PlaySound("dontstarve/creatures/deerclops/taunt_grrr", nil, .5)
                inst.sg.statemem.lightval = 1.035
                SetLightColour(inst, .9)
            end),
            TimeEvent(33 * FRAMES, function(inst) SetLightColour(inst, .8) end),
			TimeEvent(41 * FRAMES, function(inst) inst.SoundEmitter:PlaySound("dontstarve/creatures/deerclops/step", nil, .7) end),
            TimeEvent(43 * FRAMES, function(inst)
                ShakeAllCameras(CAMERASHAKE.VERTICAL, .3, .02, .7, inst, 40)
            end),
            TimeEvent(47 * FRAMES, function(inst)
                inst.sg.statemem.lightval = nil
                SetLightValueAndOverride(inst, .9, 0)
                SetLightColour(inst, .9)
            end),
            TimeEvent(48 * FRAMES, function(inst)
                inst.sg:RemoveStateTag("busy")
                SetLightValue(inst, 1)
                SetLightColour(inst, 1)
            end),
        },

        events =
        {
            EventHandler("animover", function(inst)
                inst.sg.statemem.keepfacing = true
                inst.sg:GoToState("epic_idle")
            end),
        },

        onexit = function(inst)
            SetLightValueAndOverride(inst, 1, 0)
            SetLightColour(inst, 1)
			inst.Transform:SetFourFaced()
        end,
    })

AddStategraphState("wilson",State{
		name = "bearger_pound",
		tags = { "attack", "busy","epic_skill","epic" },

		onenter = function(inst)
			inst.components.locomotor:StopMoving()
			inst.AnimState:PlayAnimation("ground_pound")
            inst.AnimState:PushAnimation("to_bi",false)
		end,

		timeline =
		{
			FrameEvent(13, function(inst) inst.SoundEmitter:PlaySound("dontstarve_DLC001/creatures/bearger/swhoosh") end),
			FrameEvent(20, function(inst)
				ShakeIfClose_Pound(inst)
				inst.components.groundpounder:GroundPound()
				inst.SoundEmitter:PlaySound("dontstarve_DLC001/creatures/bearger/groundpound")
			end),
		},

		events =
		{
			EventHandler("animover", function(inst)
				if inst.AnimState:AnimDone() then
					inst.sg:GoToState("epic_idle")
				end
			end),
		},
	})

AddStategraphState("wilson",State{
		name = "bearger_yawn",
		tags = { "yawn", "busy","epic_skill","epic","pausepredict","bearger_yawn" },

		onenter = function(inst)
			inst.components.locomotor:StopMoving()
			inst.AnimState:PlayAnimation("yawn")
			inst.AnimState:PushAnimation( "yawn_pst", false)
			if inst.components.playercontroller then
                inst.components.playercontroller:RemotePausePrediction()
            end
		end,

		timeline =
		{
			FrameEvent(22, function(inst)
				inst.SoundEmitter:PlaySound("dontstarve_DLC001/creatures/bearger/yawn")
			end),
			FrameEvent(50, yawnfn),
			FrameEvent(65, function(inst)
				inst.sg:RemoveStateTag("busy")
				inst.sg:AddStateTag("canrotate")
			end),
		},

		events =
		{
			EventHandler("animqueueover", function(inst)
				if inst.AnimState:AnimDone() then
					inst.sg:GoToState("epic_idle")
				end
			end),
		},
	})

AddStategraphState("wilson",State{
		name = "moose_spin_pre",
		tags = {"busy","epic","epic_skill"},

		onenter = function(inst)
			inst.Physics:Stop()
			inst.AnimState:PlayAnimation("spin_pre")
			inst.components.burnable:Extinguish()
			inst.moose_numSpins = 0
            inst._moose_spintargets = {}

            local buffaction = inst:GetBufferedAction()
            if buffaction then
				if buffaction.pos then
					inst:ForceFacePoint(buffaction:GetActionPoint():Get())
					inst._facepoint_x,inst._facepoint_y,inst._facepoint_z = buffaction:GetActionPoint():Get()
                elseif buffaction.target and buffaction.target:IsValid() then
                    local x, y, z = buffaction.target.Transform:GetWorldPosition()
                    inst:ForceFacePoint(x, y, z)
                    inst._facepoint_x, inst._facepoint_y, inst._facepoint_z = x, y, z
                    inst.sg.statemem.target = buffaction.target
                end
			end
            inst:PerformBufferedAction()
		end,

		events =
		{
			EventHandler("animover", function(inst)
                inst.sg:GoToState("moose_spin_loop",inst.sg.statemem.target)
            end),
		},

		timeline =
		{
			TimeEvent(6*FRAMES, function(inst)
                inst.SoundEmitter:PlaySound("dontstarve_DLC001/creatures/mossling/attack")
            end),
		},

        onexit = function (inst)

        end
	})

AddStategraphState("wilson",State{
		name = "moose_spin_loop",
		tags = { "busy", "spinning", "noelectrocute","epic","epic_skill","nopredict", "nomorph" },

		onenter = function(inst,target)
			inst.AnimState:PlayAnimation("spin_loop")
			inst.SoundEmitter:PlaySound("dontstarve_DLC001/creatures/mossling/spin", "spinLoop")

			local fx = SpawnPrefab("mossling_spin_fx")
			fx.entity:SetParent(inst.entity)
			fx.Transform:SetPosition(0,0.1,0)
			inst.components.burnable:Extinguish()

            inst.sg.statemem.target = target
		end,

		onupdate = function(inst)
            if inst.sg.statemem.target and inst.sg.statemem.target:IsValid() then
                local x, y, z = inst.sg.statemem.target.Transform:GetWorldPosition()
                inst:ForceFacePoint(x, y, z)
            end
            Moose_DestroyStuff(inst)
            MooseDoArcAttack(inst,inst._moose_spintargets)
            inst.Physics:SetMotorVelOverride(12 , 0, 0)
		end,

		onexit = function(inst)
			inst.SoundEmitter:KillSound("spinLoop")
            inst.Physics:ClearMotorVelOverride()
			inst.components.locomotor:StopMoving()
            inst._moose_spintargets = {}
		end,

		timeline=
		{
            TimeEvent(10*FRAMES, function(inst)
				inst._moose_spintargets = {}
			end),
			TimeEvent(5*FRAMES, function(inst)
				if math.random() < 0.1 then
					LightningStrike(inst)
				end
			end),
            TimeEvent(20*FRAMES, function(inst)
				inst._moose_spintargets = {}
			end),
            TimeEvent(30*FRAMES, function(inst)
				inst._moose_spintargets = {}
			end),
            TimeEvent(40*FRAMES, function(inst)
				inst._moose_spintargets = {}
			end),
            TimeEvent(50*FRAMES, function(inst)
				inst._moose_spintargets = {}
			end),
            TimeEvent(60*FRAMES, function(inst)
				inst._moose_spintargets = {}
			end),
            TimeEvent(65*FRAMES, function(inst)
				inst._moose_spintargets = {}
			end),
		},

		events=
		{
			EventHandler("animover",
			function(inst)
				inst.moose_numSpins = inst.moose_angery and inst.moose_numSpins + 1 or 2
				if inst.moose_numSpins>=2 then
					inst.sg:GoToState("moose_spin_pst")
				else
					inst.sg:GoToState("moose_spin_loop",inst.sg.statemem.target)
				end
			end),
		},
	})

AddStategraphState("wilson",State{
		name = "moose_spin_pst",
		tags = {"busy","epic","epic_skill","nopredict", "nomorph"},

		onenter = function(inst)
			inst.AnimState:PlayAnimation("spin_pst")
		end,

		events =
		{
			EventHandler("animover", function(inst) inst.sg:GoToState("moose_spin_pst_loop") end),
		},
	})

AddStategraphState("wilson",State{
		name = "moose_spin_pst_loop",
		tags = {"busy","epic","epic_skill","nopredict", "nomorph"},

		onenter = function(inst)
			inst.AnimState:PlayAnimation("spin_pst_loop", true)
			inst.SoundEmitter:PlaySound("dontstarve_DLC001/creatures/mossling/dizzy", "dizzy")
			inst.sg:SetTimeout(math.random() + (inst.moose_angery and 4.5 or 2))
		end,

		onexit = function(inst)
			inst.SoundEmitter:KillSound("dizzy")
		end,

		timeline=
		{
		},

		ontimeout = function(inst)
			inst.sg:GoToState("moose_spin_pst_loop_pst")
		end,
	})

AddStategraphState("wilson",State{
		name = "moose_spin_pst_loop_pst",
		tags = {"busy","epic","epic_skill","nopredict", "nomorph"},

		onenter = function(inst)
			inst.AnimState:PlayAnimation("spin_pst_loop_pst")
		end,

		events =
		{
			EventHandler("animover", function(inst) inst.sg:GoToState("epic_idle") end),
		},
	})

AddStategraphState("wilson",State{
		name = "moose_meep",
		tags = {"busy","epic","epic_skill","moose_meep","pausepredict",},

		onenter = function(inst)
			inst.Physics:Stop()
			inst.AnimState:PlayAnimation("meep")
            if inst.components.playercontroller then
                inst.components.playercontroller:RemotePausePrediction()
            end
		end,

		timeline=
		{
			TimeEvent(7*FRAMES, function(inst) inst.SoundEmitter:PlaySound("dontstarve_DLC001/creatures/mossling/flap") end),
			TimeEvent(10*FRAMES, function(inst)
                if TheWorld.state.season=="spring" then
                    if inst.moose_meep_num then
                        inst.moose_meep_num = inst.moose_meep_num + 1
                    else
                        inst.moose_meep_num = 0
                    end
                    if inst.moose_meep_num>=10 then
                        local moose = SpawnPrefab("moose")
                        local x,y,z = inst.Transform:GetWorldPosition()
                        local x_offset = math.random(-3,3)
                        local z_offset = math.random(-3,3)
                        moose.Transform:SetPosition(x+x_offset,10,z+z_offset)
                        moose.sg:GoToState("glide")
                        inst.moose_meep_num = -30
                    end
                end
            end),
			TimeEvent(10*FRAMES, function(inst) inst.SoundEmitter:PlaySound("dontstarve_DLC001/creatures/mossling/honk") end),
			TimeEvent(11*FRAMES, function(inst) inst.SoundEmitter:PlaySound("dontstarve_DLC001/creatures/mossling/flap") end),
			TimeEvent(15*FRAMES, function(inst) inst.SoundEmitter:PlaySound("dontstarve_DLC001/creatures/mossling/flap") end),
			TimeEvent(19*FRAMES, function(inst) inst.SoundEmitter:PlaySound("dontstarve_DLC001/creatures/mossling/flap") end),
			TimeEvent(23*FRAMES, function(inst) inst.SoundEmitter:PlaySound("dontstarve_DLC001/creatures/mossling/flap") end),
		},

		events=
		{
			EventHandler("animover", function(inst) inst.sg:GoToState("epic_idle") end),
		},
	})
---antlion
AddStategraphState("wilson",State{
        name = "antlion_jumpin_out",
        tags = { "busy","epic","epic_skill" },

        onenter = function(inst)
            inst.components.locomotor:Stop()
            inst.AnimState:PlayAnimation("out")

            local buffaction = inst:GetBufferedAction()
            if buffaction then
                if buffaction.pos then
					inst._jumppoint_x,inst._jumppoint_y,inst._jumppoint_z = buffaction:GetActionPoint():Get()
                elseif buffaction.target and buffaction.target:IsValid() then
                    local x, y, z = buffaction.target.Transform:GetWorldPosition()
                    inst._jumppoint_x, inst._jumppoint_y, inst._jumppoint_z = x, y, z
                end
                if buffaction.action==ACTIONS.EPIC_MAP_TELEPORT then
                    inst.sg.statemem.ismapteleport = true
                else
                    inst:PerformBufferedAction()
                end
            end

        end,

        events =
        {
            EventHandler("animover", function(inst)
                if inst.AnimState:AnimDone() then
                    if inst.sg.statemem.ismapteleport then
                        inst:PerformBufferedAction()
                    else
                        inst.sg:GoToState("antlion_jumpin_enter")
                    end
                end
            end),
        },

        timeline =
        {
            FrameEvent(15, function(inst)
				inst.SoundEmitter:PlaySound("dontstarve/creatures/together/antlion/cast_pre")
			end),
            FrameEvent(31, function(inst)
				inst.SoundEmitter:PlaySound("dontstarve/creatures/together/antlion/cast_post")
			end),
            FrameEvent(32, function(inst)
				inst.SoundEmitter:PlaySound("dontstarve/creatures/together/antlion/cast_post")
                Moose_DestroyStuff(inst)
                MooseDoArcAttack(inst)
			end),
            FrameEvent(34, function(inst)
				if inst.components.health then
                    inst.components.health:SetInvincible(true)
                end
			end),
        },

        onexit = function (inst)
            if inst.components.health then
                inst.components.health:SetInvincible(false)
            end
        end,
    })

AddStategraphState("wilson",State{
        name = "antlion_jumpin_enter",
        tags = { "busy", "pausepredict", "nomorph" ,"epic","epic_skill"},

        onenter = function(inst,data)
            inst.components.locomotor:Stop()
            inst.AnimState:PlayAnimation("enter")

            if data and data.dest then
                local x, y, z = data.dest:Get()
                inst._jumppoint_x = x
                inst._jumppoint_y = y
                inst._jumppoint_z = z
            end

            if not TheWorld.Map:IsOceanAtPoint(inst._jumppoint_x,inst._jumppoint_y, inst._jumppoint_z)
            and TheWorld.Map:GetPlatformAtPoint(inst._jumppoint_x,inst._jumppoint_y, inst._jumppoint_z) == nil then
                inst.Physics:Teleport(inst._jumppoint_x, inst._jumppoint_y, inst._jumppoint_z)
                inst:SnapCamera()
            end

            if inst.components.health then
                inst.components.health:SetInvincible(true)
            end

            Moose_DestroyStuff(inst)
            MooseDoArcAttack(inst)

            if inst.components.playercontroller ~= nil then
                inst.components.playercontroller:RemotePausePrediction()
            end
        end,

        events = {
            EventHandler("animover", function(inst)
                if inst.AnimState:AnimDone() then
                    inst.sg:GoToState("epic_idle")
                end
            end),
        },

        timeline =
        {
            FrameEvent(1, function(inst)
				inst.SoundEmitter:PlaySound("dontstarve/creatures/together/antlion/cast_post")
			end),
            FrameEvent(6, function(inst)
				if inst.components.health then
                    inst.components.health:SetInvincible(false)
                end
			end),
            FrameEvent(8, function(inst)
				inst.SoundEmitter:PlaySound("dontstarve/creatures/together/antlion/sfx/ground_break")
			end),
        },

        onexit = function (inst)
            if inst.components.health then
                inst.components.health:SetInvincible(false)
            end
        end,
    })

AddStategraphState("wilson",State{
        name = "antlion_summonwall",
        tags = { "attack", "busy","epic","epic_skill","pausepredict","antlion_summonwall" },

        onenter = function(inst)
            inst.components.locomotor:Stop()
            inst.AnimState:PlayAnimation("cast_sandcastle")
            if inst.components.playercontroller then
                inst.components.playercontroller:RemotePausePrediction()
            end
        end,

        timeline =
        {
            TimeEvent(9 * FRAMES, function(inst)
                inst.sg:AddStateTag("nosleep")
                inst.sg:AddStateTag("nofreeze")
                inst.SoundEmitter:PlaySound("dontstarve/creatures/together/antlion/attack_pre")
            end),
            TimeEvent(14 * FRAMES, function(inst)
                SpawnBlocks(inst, inst:GetPosition(), 19)
            end),
            TimeEvent(25 * FRAMES, function (inst)
                ShakeAllCameras(CAMERASHAKE.FULL, 1, .02, 1, inst, 30)
            end),
            TimeEvent(25 * FRAMES, function (inst)
                inst.sg:RemoveStateTag("busy")
                inst.sg:RemoveStateTag("nosleep")
                inst.sg:RemoveStateTag("nofreeze")
            end),
        },

        events =
        {
            EventHandler("animover", function(inst)
                if inst.AnimState:AnimDone() then
                    inst.sg:GoToState("epic_idle")
                end
            end),
        },
    })

AddStategraphState("wilson",State{
        name = "antlion_hightributeresponse",
        tags = { "busy" ,"epic","epic_skill","pausepredict","antlion_hightributeresponse"},

        onenter = function(inst)
            inst.AnimState:PlayAnimation("full_pre")
            inst.AnimState:PushAnimation("full_loop", false)
            inst.AnimState:PushAnimation("full_pst", false)
            if inst.components.playercontroller then
                inst.components.playercontroller:RemotePausePrediction()
            end
        end,

        timeline =
        {
            TimeEvent(0, function(inst)
                inst.SoundEmitter:PlaySound("dontstarve/creatures/together/antlion/purr")
                inst.SoundEmitter:PlaySound("dontstarve/creatures/together/antlion/rub")
            end),
            TimeEvent(16 * FRAMES, function(inst) inst.SoundEmitter:PlaySound("dontstarve/creatures/together/antlion/rub") end),
            TimeEvent(30 * FRAMES, function(inst) inst.SoundEmitter:PlaySound("dontstarve/creatures/together/antlion/rub") end),
            TimeEvent(46 * FRAMES, function(inst) inst.SoundEmitter:PlaySound("dontstarve/creatures/together/antlion/rub") end),
        },

        events =
        {
            EventHandler("animqueueover", function(inst)
                if inst.AnimState:AnimDone() then
                    inst.sg:GoToState("epic_idle")
                end
            end),
        },
    })

AddStategraphState("wilson",State{
        name = "antlion_eat",
        tags = { "busy", "caninterrupt","epic","epic_skill","pausepredict","antlion_eat" },

        onenter = function(inst)
            inst.AnimState:PlayAnimation("eat")
            inst.components.burnable:Extinguish()
            if inst.components.playercontroller then
                inst.components.playercontroller:RemotePausePrediction()
            end
        end,

        timeline =
        {
            TimeEvent(12 * FRAMES, function(inst) inst.SoundEmitter:PlaySound("dontstarve/creatures/together/antlion/eat") end),
            TimeEvent(36 * FRAMES, function(inst) inst.SoundEmitter:PlaySound("dontstarve/creatures/together/antlion/eat") end),
            TimeEvent(38 * FRAMES, function(inst)
                if not inst.components.health:IsDead() then
                    inst.components.health:DoDelta(TUNING.ANTLION_EAT_HEALING*TUNING.EPIC_WORLD.HEALTH)
                end
            end),
            TimeEvent(59 * FRAMES, function(inst)
                if not inst.components.health:IsDead() then
                    inst.components.health:DoDelta(TUNING.ANTLION_EAT_HEALING*TUNING.EPIC_WORLD.HEALTH)
                end
            end),
            TimeEvent(71 * FRAMES, function(inst) inst.SoundEmitter:PlaySound("dontstarve/creatures/together/antlion/swallow") end),
        },

        events =
        {
            EventHandler("animover", function(inst)
                if inst.AnimState:AnimDone() then
                    inst.sg:GoToState("epic_idle")
                end
            end),
        },
    })

---malbatross
AddStategraphState("wilson",State{
        name = "malbatross_depart",
        tags = { "busy","epic","epic_skill","nosleep", "swoop", "flight", "noelectrocute" },

        onenter = function(inst)
            inst.components.locomotor:Stop()
            inst.AnimState:PlayAnimation("despawn")
        end,

        events =
        {
            EventHandler("animover", function(inst)
                if inst.AnimState:AnimDone() then
                    inst:PerformBufferedAction()
                end
            end),
        },

        timeline =
        {
            FrameEvent(6, function(inst)
				inst.SoundEmitter:PlaySound("saltydog/creatures/boss/malbatross/flap")
			end),
            FrameEvent(30, function(inst)
				inst.SoundEmitter:PlaySound("saltydog/creatures/boss/malbatross/flap")
			end),
            FrameEvent(32, function(inst)
				inst.sg:AddStateTag("noattack")
			end),
        },

        onexit = function (inst)

        end,
    })

AddStategraphState("wilson",State{
        name = "malbatross_arrive",
        tags = { "busy", "pausepredict", "nomorph" ,"epic","epic_skill","noattack", "nosleep", "swoop", "flight", "noelectrocute"},

        onenter = function(inst,data)
            inst.components.locomotor:Stop()
            inst.AnimState:PlayAnimation("spawn")

            if data and data.dest then
                local x, y, z = data.dest:Get()
                inst._jumppoint_x = x
                inst._jumppoint_y = y
                inst._jumppoint_z = z
            end

            if not TheWorld.Map:IsVisualGroundAtPoint(inst._jumppoint_x,inst._jumppoint_y, inst._jumppoint_z) then
                inst.Physics:Teleport(inst._jumppoint_x, inst._jumppoint_y, inst._jumppoint_z)
                inst:SnapCamera()
            end

            if inst.components.playercontroller ~= nil then
                inst.components.playercontroller:RemotePausePrediction()
            end
        end,

        events = {
            EventHandler("animover", function(inst)
                if inst.AnimState:AnimDone() then
                    inst.sg:GoToState("epic_idle")
                end
            end),
        },

        timeline =
        {
            FrameEvent(7, function(inst)
				inst.SoundEmitter:PlaySound("saltydog/creatures/boss/malbatross/whoosh")
			end),
            FrameEvent(14, function(inst)
				inst.sg:RemoveStateTag("noattack")
                inst.sg:RemoveStateTag("nosleep")
				inst.sg:RemoveStateTag("noelectrocute")
			end),
            FrameEvent(17, function(inst)
				inst.SoundEmitter:PlaySound("saltydog/creatures/boss/malbatross/flap")
			end),
            FrameEvent(27, function(inst)
				inst.SoundEmitter:PlaySound("saltydog/creatures/boss/malbatross/flap")
			end),
        },

        onexit = function (inst)

        end,
    })

AddStategraphState("wilson",State{
        name = "malbatross_swoop_pre",
        tags = {"busy", "swoop","epic","epic_skill"},

        onenter = function(inst)
            inst.Physics:Stop()
            inst.AnimState:PlayAnimation("swoop_pre")

            local buffaction = inst:GetBufferedAction()
            if buffaction then
				if buffaction.pos then
					inst:ForceFacePoint(buffaction:GetActionPoint():Get())
					inst._facepoint_x,inst._facepoint_y,inst._facepoint_z = buffaction:GetActionPoint():Get()
                elseif buffaction.target and buffaction.target:IsValid() then
                    local x, y, z = buffaction.target.Transform:GetWorldPosition()
                    inst:ForceFacePoint(x, y, z)
                    inst._facepoint_x, inst._facepoint_y, inst._facepoint_z = x, y, z
                end
			end
            inst:PerformBufferedAction()
        end,

        timeline =
        {
            TimeEvent(6 * FRAMES, function(inst) inst.SoundEmitter:PlaySound("saltydog/creatures/boss/malbatross/eat") end),
            TimeEvent(8 * FRAMES, function(inst) inst.SoundEmitter:PlaySound("saltydog/creatures/boss/malbatross/swoop_pre") end),
        },

        events =
        {
            EventHandler("animover", function(inst) inst.sg:GoToState("malbatross_swoop_loop") end),
        },
    })

AddStategraphState("wilson",State{
        name = "malbatross_swoop_loop",
        tags = {"busy", "swoop","epic","epic_skill","nopredict", "nomorph"},

        onenter = function(inst)
            inst.components.locomotor:Stop()
            inst.components.locomotor:EnableGroundSpeedMultiplier(false)
            inst.Physics:Stop()
            inst.AnimState:PlayAnimation("swoop_loop", true)
            inst.Physics:SetMotorVelOverride(16,0,0)
            inst.sg:SetTimeout(1.7)
            inst.sg.statemem.collisiontime = 0

        end,

        onupdate = function(inst, dt)
            if inst.sg.statemem.collisiontime <= 0 then
                local x,y,z = inst.Transform:GetWorldPosition()
                local ents = TheSim:FindEntities(x, y, z, 2, nil, SWOOP_LOOP_TARGET_CANT_TAGS, SWOOP_LOOP_TARGET_ONEOF_TAGS)
                for i,ent in ipairs(ents) do
                    malbatross_oncollide(inst,ent)
                end

                spawnripple(inst)

                inst.sg.statemem.collisiontime = 3/30
            end
            inst.sg.statemem.collisiontime = inst.sg.statemem.collisiontime - dt
        end,

        timeline =
        {
            TimeEvent(0*FRAMES, function(inst) inst.SoundEmitter:PlaySound("saltydog/creatures/boss/malbatross/swoop") end),
        },

        onexit = function(inst)
            inst.components.locomotor:Stop()
            inst.components.locomotor:EnableGroundSpeedMultiplier(true)
            inst.Physics:ClearMotorVelOverride()
            inst.components.locomotor:Stop()
        end,

        ontimeout=function(inst)
            inst.sg:GoToState("malbatross_swoop_pst")
        end,
    })

AddStategraphState("wilson",State{
        name = "malbatross_swoop_pst",
        tags = {"busy", "swoop","epic","epic_skill","nopredict", "nomorph"},

        onenter = function(inst)
            inst.Physics:Stop()
            inst.AnimState:PlayAnimation("swoop_pst")
        end,

        timeline=
        {
            TimeEvent(3*FRAMES, function(inst) inst.SoundEmitter:PlaySound("saltydog/creatures/boss/malbatross/flap") end),
            TimeEvent(14*FRAMES, function(inst) inst.SoundEmitter:PlaySound("saltydog/creatures/boss/malbatross/flap") end),
        },

        events =
        {
            EventHandler("animover", function(inst) inst.sg:GoToState("epic_taunt") end),
        },
    })

AddStategraphState("wilson",State{
        name = "malbatross_combatdive",
        tags = { "busy", "nosleep", "canrotate","epic","epic_skill","pausepredict","malbatross_combatdive" },

        onenter = function(inst)
            inst.components.locomotor:StopMoving()

            inst:AddTag("scarytooceanprey")
            inst.AnimState:PlayAnimation("dive")

            if inst.components.playercontroller ~= nil then
				inst.components.playercontroller:RemotePausePrediction()
            end
        end,

        onexit = function(inst)
            inst:RemoveTag("scarytooceanprey")
        end,

        timeline =
        {
            TimeEvent(10*FRAMES, function(inst) inst.SoundEmitter:PlaySound("saltydog/creatures/boss/malbatross/flap") end),
            TimeEvent(10*FRAMES, function(inst)
                Moose_DestroyStuff(inst)
                MooseDoArcAttack(inst)
            end),
            TimeEvent(19 * FRAMES, function(inst)
				inst.SoundEmitter:PlaySound("turnoftides/common/together/water/splash/large")
                spawnsplash(inst)
                spawnwave(inst, 1)
                inst.DynamicShadow:Enable(false)
                inst.sg:AddStateTag("noattack")
				inst.sg:AddStateTag("noelectrocute")
                if inst.components.burnable ~= nil then
                    if inst.components.burnable:IsBurning() then
                        inst.components.burnable:Extinguish()
                    elseif inst.components.burnable:IsSmoldering() then
                        inst.components.burnable:SmotherSmolder()
                    end
                end
            end),
        },

        ontimeout = function(inst)
            inst.sg:GoToState("malbatross_combatdive_pst")
        end,

        events =
        {
            EventHandler("animover", function(inst)
                inst.sg:SetTimeout(2)
            end)
        },
    })

AddStategraphState("wilson",State{
        name = "malbatross_combatdive_pst",
		tags = { "busy", "nosleep", "noattack", "noelectrocute","epic","epic_skill","pausepredict","malbatross_combatdive_pst" },

        onenter = function(inst)
            if inst.components.combat and inst.components.combat.target then
                -- reposition away from target
                local pt = Vector3(inst.Transform:GetWorldPosition())
                local angle = inst:GetAngleToPoint(Vector3(inst.components.combat.target.Transform:GetWorldPosition())) + 180
                local offset = FindSwimmableOffset(pt, angle * DEGREES, 12, 16, true) or
                               FindSwimmableOffset(pt, angle * DEGREES, 8, 16, true) or
                               FindSwimmableOffset(pt, angle * DEGREES, 4, 16, true) or
                               Vector3(0,0,0)
                inst.Transform:SetPosition(pt.x +offset.x,pt.y,pt.z+offset.z)
            end

            inst.AnimState:PlayAnimation("nofish")

            Moose_DestroyStuff(inst)
            MooseDoArcAttack(inst)
        end,

        onexit = function(inst)

        end,

        timeline =
        {
            TimeEvent(1 * FRAMES, function(inst)
             inst.SoundEmitter:PlaySound("turnoftides/common/together/water/splash/jump_large")
                spawnsplash(inst)
                spawnwave(inst, 1)
                inst.DynamicShadow:Enable(true)
            end),
			TimeEvent(4*FRAMES, function(inst)
				inst.sg:RemoveStateTag("noattack")
				inst.sg:RemoveStateTag("electrocute")
			end),
        },

        events =
        {
            EventHandler("animover", function (inst)
                inst.sg:GoToState("epic_idle")
            end),
        },
    })

---beequeen
AddStategraphState("wilson",State{
        name = "beequeen_spawnguards",
        tags = { "spawnguards", "busy", "nosleep", "nofreeze","epic","epic_skill" },

        onenter = function(inst)
            FaceTarget(inst)
            inst.components.locomotor:StopMoving()
            inst.AnimState:PlayAnimation("spawn")
            inst.SoundEmitter:PlaySound("dontstarve/creatures/together/bee_queen/spawn")
            inst:PerformBufferedAction()
        end,

        timeline =
        {
            TimeEvent(16 * FRAMES, function(inst)
                local oldnum = inst.components.commander:GetNumSoldiers()
                if oldnum<16 then
                    local x, y, z = inst.Transform:GetWorldPosition()
                    local rot = inst.Transform:GetRotation()
                    local num = 16-oldnum<4 and 16-oldnum or 4

                    local drot = 360 / num
                    for i = 1, num do
                        local minion = SpawnPrefab("beeguard")
                        local angle = rot + i * drot
                        local radius = minion:GetPhysicsRadius(0)
                        minion.Transform:SetRotation(angle)
                        angle = -angle * DEGREES
                        minion.Transform:SetPosition(x + radius * math.cos(angle), 0, z + radius * math.sin(angle))
                        minion:OnSpawnedGuard(inst)
                    end

                    local soldiers = inst.components.commander:GetAllSoldiers()
                    num = #soldiers
                    drot = 360 / num
                    for i = 1, num do
                        local angle = -(rot + i * drot) * DEGREES
                        local xoffs = TUNING.BEEGUARD_GUARD_RANGE * math.cos(angle)
                        local zoffs = TUNING.BEEGUARD_GUARD_RANGE * math.sin(angle)
                        local mindistsq = math.huge
                        local closest = 1
                        for i2, v in ipairs(soldiers) do
                            local offset = v.components.knownlocations:GetLocation("queenoffset")
                            if offset ~= nil then
                                local distsq = distsq(xoffs, zoffs, offset.x, offset.z)
                                if distsq < mindistsq then
                                    mindistsq = distsq
                                    closest = i2
                                end
                            end
                        end
                        table.remove(soldiers, closest).components.knownlocations:RememberLocation("queenoffset", Vector3(xoffs, 0, zoffs), false)
                    end
                end
            end),
        },

        events =
        {
            EventHandler("animover", function (inst)
                inst.sg:GoToState("epic_idle")
            end),
        },
    })

AddStategraphState("wilson",State{
        name = "beequeen_focustarget",
        tags = { "focustarget", "busy", "nosleep", "nofreeze","epic","epic_skill","pausepredict","beequeen_focustarget" },

        onenter = function(inst)
            FaceTarget(inst)
            inst.components.locomotor:StopMoving()
            local num = math.random(2,3)
            inst.AnimState:PlayAnimation("command"..tostring(num))

            if inst.components.playercontroller ~= nil then
				inst.components.playercontroller:RemotePausePrediction()
            end
        end,

        timeline =
        {
            TimeEvent(8 * FRAMES, DoScreech),
            TimeEvent(9 * FRAMES, DoScreechAlert),
            TimeEvent(11 * FRAMES, function(inst)
                inst.SoundEmitter:PlaySound("dontstarve/creatures/together/bee_queen/attack_pre")
            end),
            TimeEvent(18 * FRAMES, function(inst)
                inst.sg.mem.focuscount = 0
                inst.sg.mem.focustargets = nil

                local soldiers = inst.components.commander:GetAllSoldiers()
                if #soldiers > 0 then
                    local targets1 = {}
                    for k, v in pairs(inst.components.grouptargeter:GetTargets()) do
                        if inst:IsNear(k, TUNING.BEEQUEEN_FOCUSTARGET_RANGE) then
                            table.insert(targets1, k)
                        end
                    end
                    local maxtargets = math.max(1, math.floor(#soldiers / TUNING.BEEGUARD_SQUAD_SIZE))
                    local targets = {}
                    for i = 1, maxtargets do
                        if #targets1 > 0 then
                            table.insert(targets, table.remove(targets1, math.random(#targets1)))
                        else
                            if inst.components.combat.target ~= nil then
                                table.insert(targets, inst.components.combat.target)
                            end
                            break
                        end
                    end
                    if #targets > 1 then
                        local sorted = {}
                        for i, v in ipairs(soldiers) do
                            local dists = {}
                            local totaldist = 0
                            for i1, v1 in ipairs(targets) do
                                local distsq = v:GetDistanceSqToInst(v1)
                                table.insert(dists, distsq)
                                totaldist = totaldist + distsq
                            end
                            for i1, v1 in ipairs(dists) do
                                dists[i1] = v1 / totaldist
                            end
                            table.insert(sorted, { inst = v, scores = dists })
                        end
                        for i, v in ipairs(targets) do
                            table.sort(sorted, function(a, b) return a.scores[i] < b.scores[i] end)
                            local squadsize = math.max(#sorted / (#targets - i + 1))
                            for i1 = 1, squadsize do
                                table.remove(sorted, 1).inst:FocusTarget(v)
                            end
                        end
                        inst.sg.mem.focustargets = targets
                    elseif #targets > 0 then
                        for i, v in ipairs(soldiers) do
                            v:FocusTarget(targets[1])
                        end
                        inst.sg.mem.focustargets = targets
                    end
                end
            end),
        },

        events =
        {
            EventHandler("animover", function (inst)
                inst.sg:GoToState("epic_idle")
            end),
        },

        onexit = function(inst)

        end,
    })

AddStategraphState("wilson",State{
        name = "beequeen_alertbee",
        tags = { "focustarget", "busy", "nosleep", "nofreeze","epic","epic_skill","pausepredict","beequeen_alertbee" },

        onenter = function(inst)
            FaceTarget(inst)
            inst.components.locomotor:StopMoving()
            inst.AnimState:PlayAnimation("command1")

            if inst.components.playercontroller ~= nil then
				inst.components.playercontroller:RemotePausePrediction()
            end
        end,

        timeline =
        {
            TimeEvent(6 * FRAMES, function(inst)
                inst.SoundEmitter:PlaySound("dontstarve/creatures/together/bee_queen/attack_pre")
            end),
            TimeEvent(7 * FRAMES, DoScreech),
            TimeEvent(8 * FRAMES, DoScreechAlert),
            TimeEvent(20 * FRAMES, function(inst)
                inst.SoundEmitter:PlaySound("dontstarve/creatures/together/bee_queen/attack_pre")
            end),
            TimeEvent(22 * FRAMES, DoScreech),
            TimeEvent(23 * FRAMES, DoScreechAlert),
        },

        events =
        {
            EventHandler("animover", function (inst)
                inst.sg:GoToState("epic_idle")
            end),
        },
    })

---daywalker
AddStategraphState("wilson",State{
		name = "daywalker_attack_pounce",
		tags = { "busy", "jumping", "nointerrupt","epic","epic_skill" },

		onenter = function(inst)
			inst.AnimState:PlayAnimation("atk3")
			inst.SoundEmitter:PlaySound("daywalker/voice/speak_short")
			inst.SoundEmitter:PlaySound("daywalker/action/attack3")
            local buffaction = inst:GetBufferedAction()
            if buffaction then
				if buffaction.pos then
					inst:ForceFacePoint(buffaction:GetActionPoint():Get())
					inst._facepoint_x,inst._facepoint_y,inst._facepoint_z = buffaction:GetActionPoint():Get()
                elseif buffaction.target and buffaction.target:IsValid() then
                    local x, y, z = buffaction.target.Transform:GetWorldPosition()
                    inst:ForceFacePoint(x, y, z)
                    inst._facepoint_x, inst._facepoint_y, inst._facepoint_z = x, y, z
                end
			end
            inst.sg.statemem.speed = 8
			inst.sg.statemem.speedmult = inst:HasTag("daywalker_run") and 4 or 1
			inst.Physics:SetMotorVelOverride(11 * inst.sg.statemem.speedmult, 0, 0)
		end,

		onupdate = function(inst)
			inst.sg.statemem.speed = inst.sg.statemem.speed * 0.9
			inst.Physics:SetMotorVelOverride(inst.sg.statemem.speed * inst.sg.statemem.speedmult, 0, 0)
			if inst.sg.statemem.collides ~= nil then
				DoAOEAttack(inst, 0.2, 1.4, nil, nil, nil, inst.sg.statemem.collides)
			end
		end,

		timeline =
		{
			FrameEvent(0, function(inst)
				inst.components.combat:SetDefaultDamage(TUNING.DAYWALKER_POUNCE_DAMAGE)
				inst.sg.statemem.collides = {}
			end),
			FrameEvent(5, function(inst)
				inst.sg.statemem.collides = nil
			end),
			FrameEvent(10, function(inst) inst.SoundEmitter:PlaySound("daywalker/action/step") end),
			FrameEvent(11, function (inst)
                ShakeAllCameras(CAMERASHAKE.FULL, .4, .02, .15, inst, 20)
            end),
			FrameEvent(12, function(inst)
				inst.components.combat:SetDefaultDamage(TUNING.DAYWALKER_XCLAW_DAMAGE)
                local targets = {}
				DoAOEWork(inst, 3, 3,targets)
				DoAOEWork(inst, 0.4, 1.6,targets)
				DoAOEAttack(inst, 3, 3, 1 + 0.1 * inst.sg.statemem.speedmult, 1 + 0.2 * inst.sg.statemem.speedmult, false,targets)
				DoAOEAttack(inst, 0.4, 1.6, 1, 1, false,targets)
			end),
		},

		events =
		{
			EventHandler("animover", function(inst)
				if inst.AnimState:AnimDone() then
                    if inst.sg.statemem.daywalker_attack_slam then
                        inst.sg:GoToState("daywalker_attack_slam",inst.sg.statemem.daywalker_attack_slam)
                    else
                        inst.sg:GoToState("epic_idle")
                    end
				end
			end),
		},

		onexit = function(inst)
			inst.Physics:ClearMotorVelOverride()
			inst.Physics:Stop()
			inst.components.combat:SetDefaultDamage(TUNING.DAYWALKER_DAMAGE)
		end,
	})

AddStategraphState("wilson",State{
		name = "daywalker_attack_slam",
		tags = { "attack", "busy", "jumping", "notalksound","epic","epic_skill","pausepredict" },

		onenter = function(inst, target)
			inst.AnimState:PlayAnimation("atk_slam")
			if target ~= nil and target:IsValid() then
				inst.sg.statemem.target = target
				inst.sg.statemem.targetpos = target:GetPosition()
				inst.sg.statemem.tracking = true
				local x1, y1, z1 = target.Transform:GetWorldPosition()
				local rot = inst.Transform:GetRotation()
				local rot1 = inst:GetAngleToPoint(x1, y1, z1)
				local diff = DiffAngle(rot, rot1)
				if diff < 90 then
					inst.Transform:SetRotation(rot1)
				end
			end
			inst.sg.statemem.speedmult = 1
			inst.sg.statemem.speed = 2
			inst.sg.statemem.decel = 0
			inst.Physics:SetMotorVelOverride(2, 0, 0)
		end,

		onupdate = function(inst)
			if inst.sg.statemem.tracking then
				if inst.sg.statemem.target ~= nil then
					if inst.sg.statemem.target:IsValid() then
						local p = inst.sg.statemem.targetpos
						p.x, p.y, p.z = inst.sg.statemem.target.Transform:GetWorldPosition()
					else
						inst.sg.statemem.target = nil
					end
				end
				if inst.sg.statemem.targetpos ~= nil then
					local rot = inst.Transform:GetRotation()
					local rot1 = inst:GetAngleToPoint(inst.sg.statemem.targetpos)
					local drot = ReduceAngle(rot1 - rot)
					if math.abs(drot) < 90 then
						rot1 = rot + math.clamp(drot / 2, -1, 1)
						inst.Transform:SetRotation(rot1)
					end
				end
			end
			if inst.sg.statemem.decel ~= 0 then
				if inst.sg.statemem.speed <= 0 then
					inst.Physics:ClearMotorVelOverride()
					inst.Physics:Stop()
					inst.sg.statemem.decel = 0
				else
					inst.Physics:SetMotorVelOverride(inst.sg.statemem.speed * inst.sg.statemem.speedmult, 0, 0)
					inst.sg.statemem.speed = inst.sg.statemem.speed + inst.sg.statemem.decel
				end
			end
		end,

		timeline =
		{
			FrameEvent(1, function(inst) inst.SoundEmitter:PlaySound("daywalker/action/attack_slam_whoosh") end),
			FrameEvent(2, function(inst)
				inst.SoundEmitter:PlaySound("daywalker/voice/attack_big")
				inst.SoundEmitter:PlaySound("daywalker/action/step")
			end),
			FrameEvent(25, function(inst) inst.SoundEmitter:PlaySound("daywalker/action/attack_slam_down") end),

			FrameEvent(1, function(inst) inst.Physics:SetMotorVelOverride(8, 0, 0) end),
			FrameEvent(6, function(inst) inst.Physics:SetMotorVelOverride(2, 0, 0) end),
			FrameEvent(8, function(inst) inst.Physics:SetMotorVelOverride(1.5, 0, 0) end),
			FrameEvent(20, function(inst)
				inst.sg.statemem.tracking = false
				inst.Physics:SetMotorVelOverride(3, 0, 0)
			end),
			FrameEvent(21, function(inst)
				if inst.sg.statemem.targetpos ~= nil then
					local x, y, z = inst.Transform:GetWorldPosition()
					local dx = inst.sg.statemem.targetpos.x - x
					local dz = inst.sg.statemem.targetpos.z - z
					if dx ~= 0 or dz ~= 0 then
						local rot1 = math.atan2(-dz, dx)
						local diff = DiffAngleRad(inst.Transform:GetRotation() * DEGREES, rot1)
						if diff * RADIANS < 60 then
							local dist = math.sqrt(dx * dx + dz * dz) * math.cos(diff)
							local maxdist = (12 + 20 + 3 * 36) * FRAMES
							inst.sg.statemem.speedmult = math.clamp(math.abs(dist / maxdist), 0.25, 1.2)
						else
							inst.sg.statemem.speedmult = 1
						end
					else
						inst.sg.statemem.speedmult = 0.25
					end
				end
				inst.Physics:SetMotorVelOverride(12 * inst.sg.statemem.speedmult, 0, 0)
			end),
			FrameEvent(22, function(inst) inst.Physics:SetMotorVelOverride(20 * inst.sg.statemem.speedmult, 0, 0) end),
			FrameEvent(23, function(inst) inst.Physics:SetMotorVelOverride(36 * inst.sg.statemem.speedmult, 0, 0) end),
			FrameEvent(24, function(inst)
				inst.sg:AddStateTag("nointerrupt")
			end),
			FrameEvent(26, function(inst)
				inst.sg.statemem.speed = 4
				inst.sg.statemem.decel = -1

				local sinkhole = SpawnPrefab("daywalker_sinkhole")
				sinkhole.Transform:SetPosition(inst.Transform:GetWorldPosition())
				sinkhole:PushEvent("docollapse")

				inst.components.combat:SetDefaultDamage(TUNING.DAYWALKER_SLAM_DAMAGE)
				local targets = {}
				DoAOEAttack(inst, 0, TUNING.DAYWALKER_SLAM_SINKHOLERADIUS, 0.7, 0.7, false, targets)
				--local targets table; this code is valid even if we left state
				for k in pairs(targets) do
					if k:IsValid() and k:HasTag("smallcreature") then
						targets[k] = nil
					end
				end
			end),
			FrameEvent(61, function(inst)
				inst.sg:RemoveStateTag("nointerrupt")
				inst.sg:AddStateTag("caninterrupt")
			end),
		},

		events =
		{
			EventHandler("animover", function(inst)
				if inst.AnimState:AnimDone() then
					inst.sg:GoToState("epic_idle")
				end
			end),
		},

		onexit = function(inst)
			inst.Physics:ClearMotorVelOverride()
			inst.Physics:Stop()
			inst.components.combat:SetDefaultDamage(TUNING.DAYWALKER_DAMAGE)
		end,
	})

---daywalker2
AddStategraphState("wilson",State{
		name = "daywalker2_cannon_pre",
		tags = { "busy", "epic","epic_skill" },

		onenter = function(inst)
			inst.components.locomotor:Stop()
			inst.AnimState:PlayAnimation("laser_pre")
			inst.SoundEmitter:PlaySound("qol1/daywalker_scrappy/laser_pre")
			inst.SoundEmitter:PlaySound("daywalker/voice/speak_short")

            local buffaction = inst:GetBufferedAction()
            if buffaction then
				if buffaction.pos then
					inst:ForceFacePoint(buffaction:GetActionPoint():Get())
					inst._facepoint_x,inst._facepoint_y,inst._facepoint_z = buffaction:GetActionPoint():Get()
                elseif buffaction.target and buffaction.target:IsValid() then
                    local x, y, z = buffaction.target.Transform:GetWorldPosition()
                    inst:ForceFacePoint(x, y, z)
                    inst._facepoint_x, inst._facepoint_y, inst._facepoint_z = x, y, z
                end
			end
            inst:PerformBufferedAction()
		end,

		onupdate = function(inst)
			if inst._facepoint_x and inst._facepoint_y and inst._facepoint_z then
                inst:ForceFacePoint(inst._facepoint_x, inst._facepoint_y, inst._facepoint_z)
            end
		end,

		events =
		{
			EventHandler("animover", function(inst)
				if inst.AnimState:AnimDone() then
					inst.sg:GoToState("daywalker2_cannon")
				end
			end),
		},
	})

AddStategraphState("wilson",State{
		name = "daywalker2_cannon",
		tags = { "busy", "nosleep","epic","epic_skill","nopredict", "nomorph" },

		onenter = function(inst)
			inst.components.locomotor:Stop()
			inst.AnimState:PlayAnimation("laser_pst")
			inst.SoundEmitter:PlaySound("qol1/daywalker_scrappy/laser_pst")
			inst.SoundEmitter:PlaySound("daywalker/voice/speak_short")
		end,

		onupdate = function(inst)
			if inst._facepoint_x and inst._facepoint_y and inst._facepoint_z then
                inst:ForceFacePoint(inst._facepoint_x, inst._facepoint_y, inst._facepoint_z)
            end
		end,

		timeline =
		{
			FrameEvent(5, function(inst)
				inst.sg.statemem.targets = { [inst] = true }

				SpawnPrefab("alterguardian_laserhit"):SetTarget(inst)

				daywalker2_SpawnLaserHitOnly(inst, 1.5, 2.5, inst.sg.statemem.targets)

				local dist = 3
				daywalker2_SpawnLaser(inst, dist, -30, 2, 0, inst.sg.statemem.targets)
				daywalker2_SpawnLaser(inst, dist, 30, 2, 0, inst.sg.statemem.targets)
				dist = daywalker2_SpawnLaser(inst, dist, 0, 2, 5, inst.sg.statemem.targets)

				daywalker2_SpawnLaser(inst, dist, -25, 1.5, 0, inst.sg.statemem.targets)
				daywalker2_SpawnLaser(inst, dist, 25, 1.5, 0, inst.sg.statemem.targets)
				dist = daywalker2_SpawnLaser(inst, dist, 0, 1.5, 3, inst.sg.statemem.targets)
				inst.sg.statemem.dist = dist
			end),
			FrameEvent(6, function(inst)
				local dist = inst.sg.statemem.dist
				local scorchscale = 3
				for i = 1, 5 do
					scorchscale = scorchscale * 0.8
					dist = daywalker2_SpawnLaser(inst, dist, 0, 1, scorchscale, inst.sg.statemem.targets)
				end
				inst.sg.statemem.dist = dist
				inst.sg.statemem.scorchscale = scorchscale
			end),
			FrameEvent(7, function(inst)
				local dist = inst.sg.statemem.dist
				local scorchscale = inst.sg.statemem.scorchscale
				for i = 1, 9 do
					scorchscale = scorchscale * 0.8
					dist = daywalker2_SpawnLaser(inst, dist, 0, Lerp(1, 0.5, i / 10), scorchscale, inst.sg.statemem.targets)
				end
				inst.sg.statemem.dist = dist
				inst.sg.statemem.scorchscale = scorchscale
			end),
			FrameEvent(8, function(inst)
				local dist = inst.sg.statemem.dist
				local scorchscale = inst.sg.statemem.scorchscale
				--0.99 so we don't knockback
				daywalker2_SpawnLaser(inst, dist, 0, 0.99, scorchscale, inst.sg.statemem.targets)
			end),
            FrameEvent(38, function(inst)
				inst.sg:RemoveStateTag("busy")
			end),
		},

		events =
		{
			EventHandler("animover", function(inst)
				if inst.AnimState:AnimDone() then
					inst.sg:GoToState("epic_idle")
				end
			end),
		},

		onexit = function(inst)

		end,
	})

AddStategraphState("wilson",State{
		name = "daywalker2_tackle_pre",
		tags = { "tackle", "busy", "epic","epic_skill" },

		onenter = function(inst)
			inst.components.locomotor:Stop()
			inst.AnimState:PlayAnimation("tackle_pre")
			inst.SoundEmitter:PlaySound("daywalker/voice/speak_short")

            local buffaction = inst:GetBufferedAction()
            if buffaction then
				if buffaction.pos then
					inst:ForceFacePoint(buffaction:GetActionPoint():Get())
					inst._facepoint_x,inst._facepoint_y,inst._facepoint_z = buffaction:GetActionPoint():Get()
                elseif buffaction.target and buffaction.target:IsValid() then
                    local x, y, z = buffaction.target.Transform:GetWorldPosition()
                    inst:ForceFacePoint(x, y, z)
                    inst._facepoint_x, inst._facepoint_y, inst._facepoint_z = x, y, z
                end
			end

			if inst.sg.lasttags and inst.sg.lasttags["moving"] then
				inst.sg:AddStateTag("jumping")
				if inst.sg.lasttags["running"] then
					inst.AnimState:SetFrame(4)
					inst.Physics:SetMotorVelOverride(inst.components.locomotor:GetRunSpeed(), 0, 0)
				end
			end
            inst:PerformBufferedAction()
		end,

		onupdate = function(inst)
			if inst._facepoint_x and inst._facepoint_y and inst._facepoint_z then
                inst:ForceFacePoint(inst._facepoint_x, inst._facepoint_y, inst._facepoint_z)
            end
		end,

		timeline =
		{
			FrameEvent(6, daywalker_DoFootstep),
		},

		events =
		{
			EventHandler("animover", function(inst)
				if inst.AnimState:AnimDone() then
					inst.sg:GoToState("daywalker2_tackle_loop")
				end
			end),
		},

		onexit = function(inst)
			if inst.sg:HasStateTag("jumping") then
				inst.Physics:ClearMotorVelOverride()
				inst.Physics:Stop()
			end
		end,
	})

AddStategraphState("wilson",State{
		name = "daywalker2_tackle_loop",
		tags = { "tackle", "busy", "jumping","epic","epic_skill","nopredict", "nomorph" },

		onenter = function(inst)
			inst.AnimState:PlayAnimation("tackle", true)
			inst.sg:SetTimeout(inst.AnimState:GetCurrentAnimationLength() * 3) --16 * 3

			inst.sg.statemem.targets = {}
			inst.components.combat:SetDefaultDamage(TUNING.DAYWALKER2_TACKLE_DAMAGE)
		end,

		onupdate = function(inst)
			local speedmult = inst.components.locomotor:GetSpeedMultiplier() *2/3
			inst.Physics:SetMotorVelOverride(TUNING.DAYWALKER2_TACKLE_SPEED * speedmult, 0, 0)

			daywalker2_DoAOEAttack(inst, 1, 2, nil, 1, nil, inst.sg.statemem.targets)

			if inst.sg.statemem.trample then
				inst.sg.statemem.trample = nil
				daywalker2_DoFootstepAOE(inst)
			end
		end,

		timeline =
		{
			FrameEvent(0, daywalker2_DoFootstepAOE), --from tackle_pre

			--loop 1
			FrameEvent(7, daywalker_DoFootstep),
			FrameEvent(8, function(inst)
				inst.sg.statemem.trample = true
			end),
			FrameEvent(15, daywalker_DoFootstep),
			FrameEvent(16, function(inst)
				inst.sg.statemem.trample = true
				daywalker2_DoFootstepAOE(inst)
			end),

			--loop 2
			FrameEvent(23, daywalker_DoFootstep),
			FrameEvent(24, function(inst)
				inst.sg.statemem.trample = true
			end),
			FrameEvent(31, daywalker_DoFootstep),
			FrameEvent(32, function(inst)
				inst.sg.statemem.trample = true
				daywalker2_DoFootstepAOE(inst)
			end),

			--loop 3
			FrameEvent(39, daywalker_DoFootstep),
			FrameEvent(40, function(inst)
				inst.sg.statemem.trample = true
			end),
			FrameEvent(47, daywalker_DoFootstep),
			FrameEvent(48, function(inst)
				inst.sg.statemem.trample = true
				daywalker2_DoFootstepAOE(inst)
			end),
		},

		ontimeout = function(inst)
			inst.sg:GoToState("daywalker2_tackle_lift")
		end,

		onexit = function(inst)
			inst.components.combat:SetDefaultDamage(TUNING.DAYWALKER_DAMAGE)
			inst.Physics:ClearMotorVelOverride()
			inst.Physics:Stop()
		end,
	})

AddStategraphState("wilson",State{
		name = "daywalker2_tackle_lift",
		tags = { "tackle", "busy", "jumping","epic","epic_skill","nopredict", "nomorph" },

		onenter = function(inst)
			inst.AnimState:PlayAnimation("tackle_lift")
			inst.SoundEmitter:PlaySound("daywalker/voice/speak_short")
			inst.SoundEmitter:PlaySound("qol1/daywalker_scrappy/bodyswing_f5")
			inst.sg.statemem.targets = {}
			inst.sg.statemem.speedmult = 1
			inst.components.combat:SetDefaultDamage(TUNING.DAYWALKER2_TACKLE_DAMAGE)
		end,

		onupdate = function(inst)
			if inst.sg.statemem.speedmult then
				inst.sg.statemem.speedmult = inst.sg.statemem.speedmult * 0.75
				inst.Physics:SetMotorVelOverride(TUNING.DAYWALKER2_TACKLE_SPEED * inst.components.locomotor:GetSpeedMultiplier() * inst.sg.statemem.speedmult, 0, 0)
				DoAOEAttack(inst, 1, 2, nil, nil, nil, inst.sg.statemem.targets, false, false)
			end
		end,

		timeline =
		{
			FrameEvent(5, function(inst)
				inst.Physics:ClearMotorVelOverride()
				inst.Physics:Stop()
				inst.sg:RemoveStateTag("jumping")
				inst.sg.statemem.speedmult = nil
				inst.sg.statemem.targets = {}
				DoAOEAttack(inst, 1, 2, nil, 0.75, nil, inst.sg.statemem.targets, false, false)
			end),
			FrameEvent(6, function(inst)
			    DoAOEAttack(inst, 1, 2, nil, 0.75, nil, inst.sg.statemem.targets, false, false)
			end),
			FrameEvent(18, function(inst)
				inst.sg:RemoveStateTag("busy")
			end),
		},

		events =
		{
			EventHandler("animover", function(inst)
				if inst.AnimState:AnimDone() then
					inst.sg:GoToState("epic_idle")
				end
			end),
		},

		onexit = function(inst)
			inst.Physics:ClearMotorVelOverride()
			inst.Physics:Stop()
			inst.components.combat:SetDefaultDamage(TUNING.DAYWALKER_DAMAGE)
		end,
	})

---alterguardian_phase1
AddStategraphState("wilson",State{
        name = "phase1_roll_start",
		tags = { "busy", "canrotate", "charge","epic","epic_skill","ph1_roll" },

        onenter = function(inst)
            local buffaction = inst:GetBufferedAction()
            if buffaction then
				if buffaction.pos then
					inst:ForceFacePoint(buffaction:GetActionPoint():Get())
					inst._facepoint_x,inst._facepoint_y,inst._facepoint_z = buffaction:GetActionPoint():Get()
                elseif buffaction.target and buffaction.target:IsValid() then
                    local x, y, z = buffaction.target.Transform:GetWorldPosition()
                    inst:ForceFacePoint(x, y, z)
                    inst._facepoint_x, inst._facepoint_y, inst._facepoint_z = x, y, z
                    inst.sg.statemem.target = buffaction.target
                end
			end

            inst.components.locomotor:Stop()

            inst.AnimState:PlayAnimation("roll_pre")
            inst._ph1_roll_num = 0

            inst:PerformBufferedAction()
        end,

        timeline =
        {

            TimeEvent(1*FRAMES, function(inst)
                inst.Physics:SetMotorVelOverride(6, 0, 0)
            end),
            TimeEvent(12*FRAMES, function(inst)
                inst.SoundEmitter:PlaySound("moonstorm/creatures/boss/alterguardian1/step")
            end),
            TimeEvent(17*FRAMES, function(inst)
                inst.SoundEmitter:PlaySound("moonstorm/creatures/boss/alterguardian1/step")
            end),
            TimeEvent(29*FRAMES, function(inst)
                inst.SoundEmitter:PlaySound("moonstorm/creatures/boss/alterguardian1/step")
            end),
            TimeEvent(39*FRAMES, function(inst)
                inst.SoundEmitter:PlaySound("moonstorm/creatures/boss/alterguardian1/step")
            end),
        },

        events =
        {
            EventHandler("animover", function(inst)
                inst.sg:GoToState("phase1_roll",inst.sg.statemem.target)
            end),
        },

        onexit = function(inst)
            inst.components.locomotor:Stop()
            inst.Physics:ClearMotorVelOverride()
        end,
    })

AddStategraphState("wilson",State{
        name = "phase1_roll",
		tags = { "busy", "charge","epic","epic_skill","pausepredict","ph1_roll" },

        onenter = function(inst,target)
            EnableRollCollision(inst,true)

            inst.components.locomotor:Stop()
            inst.Physics:SetMotorVelOverride(10, 0, 0)
			inst.sg.statemem.rollhits = {}

            inst.AnimState:PlayAnimation("roll_loop", true)

            inst.sg:SetTimeout(inst.AnimState:GetCurrentAnimationLength())

            if target and target:IsValid() then
                inst._facepoint_x,inst._facepoint_y,inst._facepoint_z = target.Transform:GetWorldPosition()
                inst.sg.statemem.target = target
            end

            inst:ForceFacePoint(inst._facepoint_x, inst._facepoint_y, inst._facepoint_z)

            inst._ph1_roll_num = inst._ph1_roll_num +1
        end,

		onupdate = OnUpdateRollAttack,

        timeline =
        {
            TimeEvent(1*FRAMES, function(inst)
                inst.SoundEmitter:PlaySound("moonstorm/creatures/boss/alterguardian1/roll")

                ph1_roll_screenshake(inst)

                ph1_spawn_landfx(inst)
            end),
        },

        onexit = function(inst)
            inst.components.locomotor:Stop()
            inst.Physics:ClearMotorVelOverride()

            EnableRollCollision(inst,false)
        end,

        ontimeout = function(inst)
            if inst._ph1_roll_num<=3 then
                inst.sg:GoToState("phase1_roll",inst.sg.statemem.target)
            else
                inst.sg:GoToState("phase1_roll_stop",inst.sg.statemem.target)
            end
            
        end,
    })

AddStategraphState("wilson",State{
        name = "phase1_roll_stop",
		tags = { "busy", "charge","epic","epic_skill","pausepredict","ph1_roll" },

        onenter = function(inst,target)
            inst.AnimState:PlayAnimation("roll_pst")

            ph1_roll_screenshake(inst)

            EnableRollCollision(inst,true)

            inst.components.locomotor:Stop()
            inst.Physics:SetMotorVelOverride(10, 0, 0)
			inst.sg.statemem.rollhits = {}

            if target and target:IsValid() then
                inst._facepoint_x,inst._facepoint_y,inst._facepoint_z = target.Transform:GetWorldPosition()
            end

            inst:ForceFacePoint(inst._facepoint_x, inst._facepoint_y, inst._facepoint_z)
        end,

		onupdate = OnUpdateRollAttack,

        timeline =
        {
            TimeEvent(1*FRAMES, function(inst)
                inst.SoundEmitter:PlaySound("moonstorm/creatures/boss/alterguardian1/roll")

                ph1_roll_screenshake(inst)

                ph1_spawn_landfx(inst)
            end),
            TimeEvent(18*FRAMES, function(inst)
                inst.SoundEmitter:PlaySound("moonstorm/creatures/boss/alterguardian1/roll")
            end),
            TimeEvent(18*FRAMES, function(inst)
                inst.SoundEmitter:PlaySound("moonstorm/creatures/boss/alterguardian1/tantrum")

                ph1_tantrum_screenshake(inst)

                ph1_spawn_landfx(inst)

                ph1_DoAOEAttack(inst, TUNING.ALTERGUARDIAN_PHASE1_AOERANGE)
            end),
            TimeEvent(22*FRAMES, function(inst)
                -- Velocity overrides are a stack, so we have to clear our 10 off first.
                inst.Physics:ClearMotorVelOverride()
                inst.Physics:SetMotorVelOverride(3, 0, 0)
				inst.sg.statemem.rollhits = nil
            end),
            TimeEvent(35*FRAMES, function(inst)
                inst.SoundEmitter:PlaySound("moonstorm/creatures/boss/alterguardian1/step")

                inst.components.locomotor:Stop()
                inst.Physics:ClearMotorVelOverride()

                EnableRollCollision(inst,false)

                inst.sg.statemem.roll_finished = true
            end),
            TimeEvent(43*FRAMES, function(inst)
                inst.SoundEmitter:PlaySound("moonstorm/creatures/boss/alterguardian1/step")
            end),
            TimeEvent(48*FRAMES, function(inst)
                inst.SoundEmitter:PlaySound("moonstorm/creatures/boss/alterguardian1/step")
            end),
            TimeEvent(52*FRAMES, function(inst)
                inst.SoundEmitter:PlaySound("moonstorm/creatures/boss/alterguardian1/step")
                inst.sg:RemoveStateTag("busy")
            end),
        },

        events =
        {
            EventHandler("animover", function (inst)
                inst.sg:GoToState("epic_idle")
            end),
        },

        onexit = function(inst)
            if not inst.sg.statemem.roll_finished then
                inst.components.locomotor:Stop()
                inst.Physics:ClearMotorVelOverride()

                EnableRollCollision(inst,false)
            end
        end,
    })

AddStategraphState("wilson",State{
        name = "phase1_shield_pre",
        tags = {"busy","epic","epic_skill","pausepredict"},

        onenter = function(inst)
            inst.Physics:Stop()

            inst.AnimState:PlayAnimation("shield_pre")

            if inst.components.playercontroller ~= nil then
				inst.components.playercontroller:RemotePausePrediction()
            end
        end,

        timeline =
        {
            TimeEvent(0*FRAMES, function(inst)
                inst.SoundEmitter:PlaySound("moonstorm/creatures/boss/alterguardian1/shield_pre")
            end),
            TimeEvent(15*FRAMES, function(inst)
                inst.SoundEmitter:PlaySound("moonstorm/creatures/boss/alterguardian1/shield")
            end),
            TimeEvent(26*FRAMES, function(inst)
                inst.SoundEmitter:PlaySound("moonstorm/creatures/boss/alterguardian1/shield")
            end),
            TimeEvent(30*FRAMES, function(inst)
                inst.SoundEmitter:PlaySound("moonstorm/creatures/boss/alterguardian1/shield")
            end),
        },

        events =
        {
            EventHandler("animover", function(inst)
                inst.sg:GoToState("phase1_shield")
            end),
        },
    })

AddStategraphState("wilson",State{
        name = "phase1_shield",
        tags = {"busy", "shield","epic","epic_skill","pausepredict"},

        onenter = function(inst)
            inst.Physics:Stop()

            inst.AnimState:PlayAnimation("shield", true)

            inst.SoundEmitter:PlaySound("moonstorm/creatures/boss/alterguardian1/summon")

            phase1_EnterShield(inst)
        end,

        onexit = function(inst)
            phase1_ExitShield(inst)
        end,
    })

AddStategraphState("wilson",State{
        name = "phase1_shield_hit",
        tags = {"busy", "hit", "shield","epic","epic_skill","pausepredict"},

        onenter = function(inst)
            inst.components.locomotor:StopMoving()

            inst.AnimState:PlayAnimation("shield_hit")

            inst.SoundEmitter:PlaySound("moonstorm/creatures/boss/alterguardian1/hit")

            phase1_EnterShield(inst)
        end,

        events =
        {
            EventHandler("animover", function(inst)
                inst.sg:GoToState("phase1_shield")
            end),
        },

        onexit = function(inst)
            phase1_ExitShield(inst)
        end,
    })

AddStategraphState("wilson",State{
        name = "phase1_shield_end",
        tags = { "busy", "shield_end","epic","epic_skill","pausepredict" },

        onenter = function(inst)
            inst.AnimState:PlayAnimation("shield_pst")
        end,

        timeline =
        {
            TimeEvent(20*FRAMES, function(inst)
                inst.SoundEmitter:PlaySound("moonstorm/creatures/boss/alterguardian1/step")
            end),
            TimeEvent(29*FRAMES, function(inst)
                inst.SoundEmitter:PlaySound("moonstorm/creatures/boss/alterguardian1/step")
            end),
            TimeEvent(34*FRAMES, function(inst)
                inst.SoundEmitter:PlaySound("moonstorm/creatures/boss/alterguardian1/step")
            end),
        },

        events =
        {
            EventHandler("animover", function (inst)
                inst.sg:GoToState("epic_idle")
            end),
        },
    })

---alterguardian_phase2
AddStategraphState("wilson",State {
        name = "epic_atk_spike",
        tags = { "busy","epic","epic_skill1"},

        onenter = function(inst, target)
            inst.components.locomotor:StopMoving()

            inst.AnimState:PlayAnimation("attk_stab_pre")
            inst.AnimState:PushAnimation("attk_stab_loop")

            local buffaction = inst:GetBufferedAction()
            if buffaction then
				if buffaction.pos then
					inst:ForceFacePoint(buffaction:GetActionPoint():Get())
					inst._facepoint_x,inst._facepoint_y,inst._facepoint_z = buffaction:GetActionPoint():Get()
                elseif buffaction.target and buffaction.target:IsValid() then
                    local x, y, z = buffaction.target.Transform:GetWorldPosition()
                    inst:ForceFacePoint(x, y, z)
                    inst._facepoint_x, inst._facepoint_y, inst._facepoint_z = x, y, z
                end
			end

            inst.sg:SetTimeout(2.25 + math.random() * 0.25)
            inst:PerformBufferedAction()
        end,

        timeline =
        {
            TimeEvent(11*FRAMES, function(inst)
                inst.SoundEmitter:PlaySound("moonstorm/creatures/boss/alterguardian2/atk_spike_pre")
            end),
            TimeEvent(28*FRAMES, function(inst)
                inst.SoundEmitter:PlaySound("moonstorm/creatures/boss/alterguardian2/atk_spike")

                ShakeAllCameras(CAMERASHAKE.FULL, .75, 0.1, 0.1, inst, 50)

                MooseDoArcAttack(inst)
            end),
            TimeEvent(32*FRAMES, function(inst)
                DoSpikeAttack(inst)
            end),
        },

        ontimeout = function(inst)
            inst.sg:GoToState("epic_atk_spike_pst")
        end,
    })

AddStategraphState("wilson",State {
        name = "epic_atk_spike_pst",
        tags = { "busy","pausepredict","epic","epic_skill"},

        onenter = function(inst)
            inst.components.locomotor:StopMoving()
            inst.AnimState:PlayAnimation("attk_stab_pst")

            if inst.components.playercontroller ~= nil then
				inst.components.playercontroller:RemotePausePrediction()
            end
        end,

        events =
        {
            EventHandler("animover", function (inst)
                inst.sg:GoToState("epic_idle")
            end),
        },
    })

AddStategraphState("wilson",State {
        name = "epic_spin_pre",
        tags = {"busy", "canrotate", "spin","epic","epic_skill"},

        onenter = function(inst)
            inst.components.locomotor:Stop()
            inst.AnimState:PlayAnimation("attk_spin_pre")

            inst:RemoveTag("phase2_spin_atk")

            local buffaction = inst:GetBufferedAction()
            if buffaction then
				if buffaction.pos then
					inst:ForceFacePoint(buffaction:GetActionPoint():Get())
					inst._facepoint_x,inst._facepoint_y,inst._facepoint_z = buffaction:GetActionPoint():Get()
                elseif buffaction.target and buffaction.target:IsValid() then
                    local x, y, z = buffaction.target.Transform:GetWorldPosition()
                    inst:ForceFacePoint(x, y, z)
                    inst._facepoint_x, inst._facepoint_y, inst._facepoint_z = x, y, z
                    inst.sg.statemem.target = buffaction.target
                end
			end

            inst:PerformBufferedAction()
        end,

		onupdate = function(inst, dt)
            local target = inst.sg.statemem.target
            if target ~= nil and target:IsValid() then
                inst:ForceFacePoint(target.Transform:GetWorldPosition())
            end

            if inst.sg.timeinstate > 32*FRAMES then
                local time_in_spin = inst.sg.timeinstate - 32*FRAMES
                if time_in_spin > (FRAMES^3) and time_in_spin % SPIN_FX_RATE < (FRAMES^3) then
                    spawn_spintrail(inst)
                end
            end

			-- Do a check for AOE damage & smashing occasionally.
			if inst.sg.statemem.attack_time == nil then
				--not yet
			elseif inst.sg.statemem.attack_time > 0 then
				inst.sg.statemem.attack_time = inst.sg.statemem.attack_time - dt
			else
				local ix, iy, iz = inst.Transform:GetWorldPosition()
				local targets = TheSim:FindEntities(
					ix, iy, iz, TUNING.ALTERGUARDIAN_PHASE2_CHOP_RANGE + AOE_RANGE_PADDING,
					nil, SPIN_CANT_TAGS, SPIN_ONEOF_TAGS
				)
				for _, target in ipairs(targets) do
					if target:IsValid() and not target:IsInLimbo() then
						local range = TUNING.ALTERGUARDIAN_PHASE2_CHOP_RANGE + target:GetPhysicsRadius(0)
						if target:GetDistanceSqToPoint(ix, iy, iz) < range * range then
							local has_health = target.components.health ~= nil
							if has_health and target:HasTag("smashable") then
								target.components.health:Kill()
							elseif target.components.workable ~= nil
								and target.components.workable:CanBeWorked() then
								if not target:HasTag("moonglass") then
									local tx, ty, tz = target.Transform:GetWorldPosition()
									local collapse_fx = SpawnPrefab("collapse_small")
									collapse_fx.Transform:SetPosition(tx, ty, tz)
								end

								target.components.workable:Destroy(inst)
							elseif has_health and not target.components.health:IsDead() and inst.components.combat:CanTarget(target) then
								inst.components.combat:DoAttack(target)
							end
						end
					end
				end

				inst.sg.statemem.attack_time = 8*FRAMES
			end
        end,

        timeline =
        {
            TimeEvent(30*FRAMES, function(inst)
                inst.SoundEmitter:PlaySound("moonstorm/creatures/boss/alterguardian2/atk_spin_pre")
            end),
            TimeEvent(32*FRAMES, function(inst)

                local spin_speed = TUNING.ALTERGUARDIAN_PHASE2_SPIN_SPEED
                local target = inst.sg.statemem.target
                if target ~= nil and target:IsValid() and target.components.locomotor ~= nil then
                    spin_speed = math.max(spin_speed, target.components.locomotor:GetRunSpeed() * inst.components.locomotor:GetSpeedMultiplier()) - 0.25
                    spin_speed = math.min(spin_speed, 35)
                end
                inst.sg.statemem.spin_speed = spin_speed
                inst.Physics:SetMotorVelOverride(spin_speed, 0, 0)
            end),
			TimeEvent(35 * FRAMES, function(inst)
				inst.sg.statemem.attack_time = 0
			end),
        },

        events =
        {
            EventHandler("animover", function(inst)
                local loop_data =
                {
                    spin_time_remaining = (inst.sg.timeinstate - 18*FRAMES) % SPIN_FX_RATE,
                    target = inst.sg.statemem.target,
                    speed = inst.sg.statemem.spin_speed,
					attack_time = inst.sg.statemem.attack_time,
                }
                inst.sg:GoToState("epic_spin_loop", loop_data)
            end),
        },

        onexit = function(inst)
            inst.Physics:ClearMotorVelOverride()
            inst.components.locomotor:Stop()
        end,
    })

AddStategraphState("wilson",State {
        name = "epic_spin_loop",
        tags = {"busy", "spin","pausepredict","epic","epic_skill"},

        onenter = function(inst, data)
            inst.components.locomotor:Stop()

            inst.AnimState:PlayAnimation("attk_spin_loop", true)

            inst.sg.statemem.loop_len = inst.AnimState:GetCurrentAnimationLength()
            local num_loops = math.random(TUNING.ALTERGUARDIAN_PHASE2_SPINMIN, TUNING.ALTERGUARDIAN_PHASE2_SPINMAX)
            inst.sg:SetTimeout(inst.sg.statemem.loop_len * num_loops)

			inst.sg.statemem.attack_time = data.attack_time or 0
            inst.sg.statemem.target = data.target
            inst.sg.statemem.speed = data.speed
            inst.sg.statemem.initial_spin_fx_time = data.spin_time_remaining

            inst.SoundEmitter:PlaySound("moonstorm/creatures/boss/alterguardian2/atk_spin_LP","spin_loop")

            inst.Physics:SetMotorVelOverride(data.speed, 0, 0)

            if inst.components.playercontroller ~= nil then
				inst.components.playercontroller:RemotePausePrediction()
            end
        end,

        onupdate = function(inst, dt)
            -- If our original target is still alive, chase them down.
            -- Otherwise, we'll just go in the direction we were facing until we finish.
            if inst.sg.statemem.target ~= nil then
                if inst.sg.statemem.target:IsValid() and
                        (inst.sg.statemem.target.components.health ~= nil
                        and not inst.sg.statemem.target.components.health:IsDead()) then
                    inst:ForceFacePoint(inst.sg.statemem.target.Transform:GetWorldPosition())
                else
                    inst.sg.statemem.target = nil
                end
            end

            local fx_time_in_state = inst.sg.statemem.initial_spin_fx_time + inst.sg.timeinstate
            if fx_time_in_state % SPIN_FX_RATE < (FRAMES^3) then
                spawn_spintrail(inst)
            end

            -- Do a check for AOE damage & smashing occasionally.
            if inst.sg.statemem.attack_time > 0 then
                inst.sg.statemem.attack_time = inst.sg.statemem.attack_time - dt
            else

                local ix, iy, iz = inst.Transform:GetWorldPosition()
                local targets = TheSim:FindEntities(
					ix, iy, iz, TUNING.ALTERGUARDIAN_PHASE2_CHOP_RANGE + AOE_RANGE_PADDING,
                    nil, SPIN_CANT_TAGS, SPIN_ONEOF_TAGS
                )
                for _, target in ipairs(targets) do
					if target:IsValid() and not target:IsInLimbo() then
						local range = TUNING.ALTERGUARDIAN_PHASE2_CHOP_RANGE + target:GetPhysicsRadius(0)
						if target:GetDistanceSqToPoint(ix, iy, iz) < range * range then
							local has_health = target.components.health ~= nil
							if has_health and target:HasTag("smashable") then
								target.components.health:Kill()
							elseif target.components.workable ~= nil
								and target.components.workable:CanBeWorked() then
								if not target:HasTag("moonglass") then
									local tx, ty, tz = target.Transform:GetWorldPosition()
									local collapse_fx = SpawnPrefab("collapse_small")
									collapse_fx.Transform:SetPosition(tx, ty, tz)
								end

								target.components.workable:Destroy(inst)
							elseif has_health and not target.components.health:IsDead() and inst.components.combat:CanTarget(target) then
								inst.components.combat:DoAttack(target)
							end
						end
                    end
                end

                inst.sg.statemem.attack_time = 8*FRAMES
            end
        end,

        ontimeout = function(inst)
            inst.sg.statemem.exit_by_timeout = true
            inst.sg:GoToState("epic_spin_pst", inst.sg.statemem.speed)
        end,

        onexit = function(inst)
            inst.Physics:ClearMotorVelOverride()
            inst.components.locomotor:Stop()

            -- We may be exiting this state via death, etc.
            if not inst.sg.statemem.exit_by_timeout then
                inst.SoundEmitter:KillSound("spin_loop")
            end
        end,
    })

AddStategraphState("wilson",State {
        name = "epic_spin_pst",
        tags = {"busy", "spin","spin","pausepredict","epic","epic_skill"},

        onenter = function(inst, speed)
            inst.components.locomotor:Stop()
            inst.Physics:SetMotorVelOverride(speed, 0, 0)

            inst.AnimState:PlayAnimation("attk_spin_pst")
        end,

        timeline =
        {
            TimeEvent(8*FRAMES, function(inst)
                local ix, iy, iz = inst.Transform:GetWorldPosition()
                local targets = TheSim:FindEntities(
					ix, iy, iz, TUNING.ALTERGUARDIAN_PHASE2_CHOP_RANGE + AOE_RANGE_PADDING,
                    nil, SPIN_CANT_TAGS, SPIN_ONEOF_TAGS
                )
                for _, target in ipairs(targets) do
					if target:IsValid() and not target:IsInLimbo() then
						local range = TUNING.ALTERGUARDIAN_PHASE2_CHOP_RANGE + target:GetPhysicsRadius(0)
						if target:GetDistanceSqToPoint(ix, iy, iz) < range * range then
							local has_health = target.components.health ~= nil
							if has_health and target:HasTag("smashable") then
								target.components.health:Kill()
							elseif target.components.workable ~= nil
								and target.components.workable:CanBeWorked() then
								if not target:HasTag("moonglass") then
									local tx, ty, tz = target.Transform:GetWorldPosition()
									local collapse_fx = SpawnPrefab("collapse_small")
									collapse_fx.Transform:SetPosition(tx, ty, tz)
								end

								target.components.workable:Destroy(inst)
							elseif has_health and not target.components.health:IsDead() and inst.components.combat:CanTarget(target) then
								inst.components.combat:DoAttack(target)
							end
						end
                    end
                end
            end),
            TimeEvent(11*FRAMES, function(inst)
                inst.sg.statemem._spin_cleaned_up = true
                inst.Physics:ClearMotorVelOverride()
                inst.components.locomotor:Stop()
            end),
            TimeEvent(10*FRAMES, function(inst)
                inst.sg.statemem._spin_sound_stopped = true
                inst.SoundEmitter:KillSound("spin_loop")
            end),
        },

        events =
        {
            EventHandler("animover", function (inst)
                inst.sg:GoToState("epic_idle")
            end),
        },

        onexit = function(inst)
            if not inst.sg.statemem._spin_cleaned_up then
                inst.Physics:ClearMotorVelOverride()
                inst.components.locomotor:Stop()
            end

            if not inst.sg.statemem._spin_sound_stopped then
                inst.SoundEmitter:KillSound("spin_loop")
            end
        end,
    })

---alterguardian_phase3
AddStategraphState("wilson",State{
        name = "phase3_atk_traps",
        tags = { "busy", "canrotate","epic","epic_skill","pausepredict","phase3_atk_traps"},

        onenter = function(inst)
            inst.components.locomotor:StopMoving()

            inst.AnimState:PlayAnimation("attk_skybeam")

            if inst.components.playercontroller ~= nil then
				inst.components.playercontroller:RemotePausePrediction()
            end
        end,

        timeline =
        {
            TimeEvent(0*FRAMES, function(inst)
                inst.SoundEmitter:PlaySound("moonstorm/creatures/boss/alterguardian3/atk_sky_beam")
            end),
            TimeEvent(44*FRAMES, function(inst)
                DoTraps(inst,
                    4,
                    TUNING.ALTERGUARDIAN_PHASE3_TRAP_MINRANGE,
                    TUNING.ALTERGUARDIAN_PHASE3_TRAP_MAXRANGE
                )
            end),
            TimeEvent(54*FRAMES, function(inst)
                DoTraps(inst,
                    6,
                    TUNING.ALTERGUARDIAN_PHASE3_TRAP_MINRANGE + 3.5,
                    TUNING.ALTERGUARDIAN_PHASE3_TRAP_MAXRANGE + 3.5
                )
            end),

            TimeEvent(1*FRAMES, function(inst) set_lightvalues(inst, 0.9) end),
            TimeEvent(2*FRAMES, function(inst) set_lightvalues(inst, 0.875) end),
            TimeEvent(3*FRAMES, function(inst) set_lightvalues(inst, 0.85) end),
            TimeEvent(4*FRAMES, function(inst) set_lightvalues(inst, 0.825) end),
            TimeEvent(5*FRAMES, function(inst) set_lightvalues(inst, 0.8) end),
            TimeEvent(6*FRAMES, function(inst) set_lightvalues(inst, 0.775) end),
            TimeEvent(7*FRAMES, function(inst) set_lightvalues(inst, 0.75) end),
            TimeEvent(8*FRAMES, function(inst) set_lightvalues(inst, 0.725) end),
            TimeEvent(9*FRAMES, function(inst) set_lightvalues(inst, 0.7) end),
            TimeEvent(10*FRAMES, function(inst) set_lightvalues(inst, 0.675) end),
            TimeEvent(11*FRAMES, function(inst) set_lightvalues(inst, 0.65) end),
            TimeEvent(12*FRAMES, function(inst) set_lightvalues(inst, 0.625) end),
            TimeEvent(13*FRAMES, function(inst) set_lightvalues(inst, 0.6) end),
            TimeEvent(14*FRAMES, function(inst) set_lightvalues(inst, 0.575) end),
            TimeEvent(15*FRAMES, function(inst) set_lightvalues(inst, 0.55) end),
            TimeEvent(16*FRAMES, function(inst) set_lightvalues(inst, 0.525) end),
            TimeEvent(17*FRAMES, function(inst) set_lightvalues(inst, 0.5) end),
            TimeEvent(18*FRAMES, function(inst) set_lightvalues(inst, 0.6) end),
            TimeEvent(19*FRAMES, function(inst) set_lightvalues(inst, 0.7) end),
            TimeEvent(20*FRAMES, function(inst) set_lightvalues(inst, 0.8) end),
            TimeEvent(21*FRAMES, function(inst) set_lightvalues(inst, 0.9) end),
            TimeEvent(22*FRAMES, function(inst) set_lightvalues(inst, 0.92) end),
            TimeEvent(23*FRAMES, function(inst) set_lightvalues(inst, 0.94) end),

            TimeEvent(40*FRAMES, function(inst) set_lightvalues(inst, 0.92) end),
            TimeEvent(41*FRAMES, function(inst) set_lightvalues(inst, 0.9) end),
        },

        events =
        {
            EventHandler("animover", function(inst)
                inst.sg:GoToState("epic_idle")
            end),
        },

        onexit = function(inst)
            inst.SoundEmitter:KillSound("channel")
        end,
    })

AddStategraphState("wilson",State{
        name = "phase3_atk_summon_pre",
        tags = { "busy","epic","epic_skill","pausepredict","phase3_atk_summon_pre" },

        onenter = function(inst)
            inst.components.locomotor:StopMoving()

            inst.AnimState:PlayAnimation("attk_stab2_pre")

            start_summon_circle(inst)

            inst.SoundEmitter:PlaySound("moonstorm/creatures/boss/alterguardian3/atk_stab_short")
            inst.SoundEmitter:PlaySound("moonstorm/creatures/boss/alterguardian3/atk_stab_LP_pre","atk_stab_loop_pre")

            if inst.components.playercontroller ~= nil then
				inst.components.playercontroller:RemotePausePrediction()
            end
        end,

        events =
        {
            EventHandler("animover", function(inst)
                inst.sg.statemem.loop_exit = true
                inst.sg:GoToState("phase3_atk_summon_loop")
            end),
        },

        onexit = function(inst)
            if not inst.sg.statemem.loop_exit then
                stop_summon_circle(inst)
            end
        end,
    })

AddStategraphState("wilson",State{
        name = "phase3_atk_summon_loop",
        tags = { "busy","epic","epic_skill","pausepredict","phase3_atk_summon_loop" },

        onenter = function(inst)
            inst.components.locomotor:StopMoving()

            inst.AnimState:PlayAnimation("attk_stab2_loop")

            inst.sg.mem.summon_loops = inst.sg.mem.summon_loops or 0
            inst.sg.mem.loop_anim_len = inst.sg.mem.loop_anim_len or inst.AnimState:GetCurrentAnimationLength()

            inst.sg.statemem.previous_loop_time = (inst.sg.mem.summon_loops * inst.sg.mem.loop_anim_len)

            inst.SoundEmitter:PlaySound("moonstorm/creatures/boss/alterguardian3/summon")
        end,

        onupdate = function(inst, dt)
            local time_in_summon = inst.sg:GetTimeInState() + inst.sg.statemem.previous_loop_time
            local summon_maxtime = inst.sg.mem.loop_anim_len * TUNING.ALTERGUARDIAN_PHASE3_SUMMONMAXLOOPS
            local percent_in_summon = time_in_summon / summon_maxtime

            inst.SoundEmitter:SetParameter("atk_stab_loop_pre", "intensity", percent_in_summon)
        end,

        timeline =
        {
            TimeEvent(1*FRAMES,function (inst)
                MooseDoArcAttack(inst)
            end),
            TimeEvent(8*FRAMES, do_summon_spawn),
            TimeEvent(16*FRAMES, do_summon_spawn),
        },

        events =
        {
            EventHandler("animover", function(inst)
                inst.sg.statemem.legit_exit = true

                inst.sg.mem.summon_loops = inst.sg.mem.summon_loops + 1

                if inst.sg.statemem.ready_to_finish or inst.sg.mem.summon_loops >= TUNING.ALTERGUARDIAN_PHASE3_SUMMONMAXLOOPS then
                    inst.sg.mem.summon_loops = nil
                    inst.sg:GoToState("phase3_atk_summon_pst")
                else
                    inst.sg:GoToState("phase3_atk_summon_loop")
                end
            end),
        },

        onexit = function(inst)
            -- Whether we go to pst or loop, we're fine.
            -- This is to cover stuff like death
            if not inst.sg.statemem.legit_exit then
                inst.SoundEmitter:KillSound("summon_loop")
                stop_summon_circle(inst)
            end
        end,
    })

AddStategraphState("wilson",State{
        name = "phase3_atk_summon_pst",
        tags = { "busy","epic","epic_skill","pausepredict","phase3_atk_summon_pst" },

        onenter = function(inst)
            inst.components.locomotor:StopMoving()

            inst.AnimState:PlayAnimation("attk_stab2_pst")

            inst.SoundEmitter:KillSound("atk_stab_loop_pre")
            inst.SoundEmitter:KillSound("summon_loop")
        end,

        events =
        {
            EventHandler("animover", function (inst)
                inst.sg:GoToState("epic_idle")
            end),
        },

        onexit = function(inst)
            stop_summon_circle(inst)
        end,
    })

AddStategraphState("wilson",State{
        name = "phase3_atk_beam",
        tags = { "busy", "canrotate","epic","epic_skill"},

        onenter = function(inst)
            inst.Transform:SetEightFaced()

            inst.components.locomotor:StopMoving()

            inst.AnimState:PlayAnimation("attk_beam")

            local buffaction = inst:GetBufferedAction()
            if buffaction then
				if buffaction.pos then
					inst:ForceFacePoint(buffaction:GetActionPoint():Get())
					inst._facepoint_x,inst._facepoint_y,inst._facepoint_z = buffaction:GetActionPoint():Get()
                elseif buffaction.target and buffaction.target:IsValid() then
                    local x, y, z = buffaction.target.Transform:GetWorldPosition()
                    inst:ForceFacePoint(x, y, z)
                    inst._facepoint_x, inst._facepoint_y, inst._facepoint_z = x, y, z
                    inst.sg.statemem.target = buffaction.target
                end
			end
            inst.SoundEmitter:PlaySound("moonstorm/creatures/boss/alterguardian3/atk_beam")
            inst:PerformBufferedAction()
        end,

        onupdate = function(inst)
            if inst.sg.statemem.target ~= nil and inst.sg.statemem.target:IsValid() then
                inst._facepoint_x, inst._facepoint_y, inst._facepoint_z = inst.sg.statemem.target.Transform:GetWorldPosition()
                if inst.sg.statemem.target_pos then
                    inst.sg.statemem.target_pos = Vector3(inst._facepoint_x, inst._facepoint_y, inst._facepoint_z)
                end
            end
            local x, _, z = inst.Transform:GetWorldPosition()
            local x1, y1, z1 = inst._facepoint_x, inst._facepoint_y, inst._facepoint_z
            local dx, dz = x1 - x, z1 - z
            if (dx * dx + dz * dz) < 256 and math.abs(anglediff(inst.Transform:GetRotation(), math.atan2(-dz, dx) / DEGREES)) < 45 then
                inst:ForceFacePoint(x1, y1, z1)
                return
            end
        end,

        timeline =
        {
            TimeEvent(21*FRAMES, function(inst)
                if inst.sg.statemem.target ~= nil and inst.sg.statemem.target:IsValid() then
                    inst.sg.statemem.target_pos = inst.sg.statemem.target:GetPosition()
                else
                    inst.sg.statemem.target_pos = Vector3(inst._facepoint_x, inst._facepoint_y, inst._facepoint_z)
                end
            end),

            TimeEvent(35*FRAMES, function(inst)
                local ipos = inst:GetPosition()

                local target_pos = inst.sg.statemem.target_pos
                if target_pos == nil then
                    local angle = inst.Transform:GetRotation() * DEGREES
                    target_pos = ipos + Vector3(OFFSET * math.cos(angle), 0, -OFFSET * math.sin(angle))
                end
                SpawnBeam(inst, target_pos)

                -- Take the vector from the boss to the target position, and rotate it a bit
                -- both clockwise and counterclockwise, to get target positions that produce
                -- an aligned tri-beam, sourced at the boss.
                local i_to_target = target_pos - ipos

                local offpos1 = Vector3(
                    (i_to_target.x * TRIBEAM_COS - i_to_target.z * TRIBEAM_SIN) + ipos.x,
                    0,
                    (i_to_target.x * TRIBEAM_SIN + i_to_target.z * TRIBEAM_COS) + ipos.z
                )
                SpawnBeam(inst, offpos1)

                local offpos2 = Vector3(
                    (i_to_target.x * TRIBEAM_COSNEG - i_to_target.z * TRIBEAM_SINNEG) + ipos.x,
                    0,
                    (i_to_target.x * TRIBEAM_SINNEG + i_to_target.z * TRIBEAM_COSNEG) + ipos.z
                )
                SpawnBeam(inst, offpos2)
            end),
            -- Play a second blast sound about when the second blast will occur, relative to the above TimeEvent.
            -- TimeEvent(35*FRAMES + SECOND_BLAST_TIME, laser_sound),

            TimeEvent(1*FRAMES, function(inst) set_lightvalues(inst, 0.9) end),
            TimeEvent(2*FRAMES, function(inst) set_lightvalues(inst, 0.875) end),
            TimeEvent(3*FRAMES, function(inst) set_lightvalues(inst, 0.85) end),
            TimeEvent(4*FRAMES, function(inst) set_lightvalues(inst, 0.825) end),
            TimeEvent(5*FRAMES, function(inst) set_lightvalues(inst, 0.8) end),
            TimeEvent(6*FRAMES, function(inst) set_lightvalues(inst, 0.775) end),
            TimeEvent(7*FRAMES, function(inst) set_lightvalues(inst, 0.75) end),
            TimeEvent(8*FRAMES, function(inst) set_lightvalues(inst, 0.725) end),
            TimeEvent(9*FRAMES, function(inst) set_lightvalues(inst, 0.7) end),
            TimeEvent(10*FRAMES, function(inst) set_lightvalues(inst, 0.675) end),
            TimeEvent(11*FRAMES, function(inst) set_lightvalues(inst, 0.65) end),
            TimeEvent(12*FRAMES, function(inst) set_lightvalues(inst, 0.625) end),
            TimeEvent(13*FRAMES, function(inst) set_lightvalues(inst, 0.6) end),
            TimeEvent(14*FRAMES, function(inst) set_lightvalues(inst, 0.575) end),
            TimeEvent(15*FRAMES, function(inst) set_lightvalues(inst, 0.55) end),
            TimeEvent(16*FRAMES, function(inst) set_lightvalues(inst, 0.525) end),
            TimeEvent(17*FRAMES, function(inst) set_lightvalues(inst, 0.5) end),

            TimeEvent(21*FRAMES, function(inst) set_lightvalues(inst, 0.7) end),
            TimeEvent(22*FRAMES, function(inst) set_lightvalues(inst, 0.675) end),
            TimeEvent(23*FRAMES, function(inst) set_lightvalues(inst, 0.65) end),
            TimeEvent(24*FRAMES, function(inst) set_lightvalues(inst, 0.625) end),
            TimeEvent(25*FRAMES, function(inst) set_lightvalues(inst, 0.6) end),

            TimeEvent(26*FRAMES, function(inst) set_lightvalues(inst, 0.7) end),
            TimeEvent(27*FRAMES, function(inst) set_lightvalues(inst, 0.675) end),
            TimeEvent(28*FRAMES, function(inst) set_lightvalues(inst, 0.65) end),
            TimeEvent(29*FRAMES, function(inst) set_lightvalues(inst, 0.625) end),
            TimeEvent(30*FRAMES, function(inst) set_lightvalues(inst, 0.6) end),
            TimeEvent(31*FRAMES, function(inst) set_lightvalues(inst, 0.7) end),

            TimeEvent(32*FRAMES, function(inst) set_lightvalues(inst, 0.7) end),
            TimeEvent(33*FRAMES, function(inst) set_lightvalues(inst, 0.8) end),
            TimeEvent(34*FRAMES, function(inst) set_lightvalues(inst, 0.9) end),
        },

        events =
        {
            EventHandler("animover", function (inst)
                inst.sg:GoToState("epic_idle")
            end),
        },

        onexit = function(inst)
            inst.Transform:SetSixFaced()
        end,
    })

AddStategraphState("wilson",State{
        name = "phase3_atk_sweep",
        tags = { "busy", "canrotate","epic","epic_skill"},

        onenter = function(inst)
            inst.Transform:SetFourFaced()

            inst.components.locomotor:StopMoving()

            inst.AnimState:PlayAnimation("attk_swipe")

            inst.SoundEmitter:PlaySound("moonstorm/creatures/boss/alterguardian3/atk_beam")
            local buffaction = inst:GetBufferedAction()
            if buffaction then
				if buffaction.pos then
					inst:ForceFacePoint(buffaction:GetActionPoint():Get())
					inst._facepoint_x,inst._facepoint_y,inst._facepoint_z = buffaction:GetActionPoint():Get()
                elseif buffaction.target and buffaction.target:IsValid() then
                    local x, y, z = buffaction.target.Transform:GetWorldPosition()
                    inst:ForceFacePoint(x, y, z)
                    inst._facepoint_x, inst._facepoint_y, inst._facepoint_z = x, y, z
                    inst.sg.statemem.target = buffaction.target
                end
			end
            inst:PerformBufferedAction()
        end,

        onupdate = function(inst)
            if inst.sg.statemem.target ~= nil and inst.sg.statemem.target:IsValid() then
                inst._facepoint_x, inst._facepoint_y, inst._facepoint_z = inst.sg.statemem.target.Transform:GetWorldPosition()
                if inst.sg.statemem.target_pos then
                    inst.sg.statemem.target_pos = Vector3(inst._facepoint_x, inst._facepoint_y, inst._facepoint_z)
                end
            end
            local x, _, z = inst.Transform:GetWorldPosition()
            local x1, y1, z1 = inst._facepoint_x, inst._facepoint_y, inst._facepoint_z
            local dx, dz = x1 - x, z1 - z
            if (dx * dx + dz * dz) < 256 and math.abs(anglediff(inst.Transform:GetRotation(), math.atan2(-dz, dx) / DEGREES)) < 45 then
                inst:ForceFacePoint(x1, y1, z1)
                return
            end
        end,

        timeline =
        {
            TimeEvent(21*FRAMES, function(inst)
                if inst.sg.statemem.target ~= nil and inst.sg.statemem.target:IsValid() then
                    inst.sg.statemem.target_pos = inst.sg.statemem.target:GetPosition()
                else
                    inst.sg.statemem.target_pos = Vector3(inst._facepoint_x, inst._facepoint_y, inst._facepoint_z)
                end
            end),

            TimeEvent(37*FRAMES, function(inst)
                local target_pos = inst.sg.statemem.target_pos

                SpawnSweep(inst, target_pos)

                if target_pos ~= nil then
                    local itot = target_pos - inst:GetPosition()
                    if itot:LengthSq() > 0 then
                        local itot_dir, itot_len = itot:GetNormalizedAndLength()
                        SpawnSweep(inst, target_pos + (itot_dir * 4.5))
                        if itot_len > 4.75 then
                            SpawnSweep(inst, target_pos - (itot_dir * 4.5))
                        end
                    end
                end
            end),
            -- Play a second blast sound about when the second blast will occur, relative to the above TimeEvent.
            -- TimeEvent(37*FRAMES + SECOND_BLAST_TIME, laser_sound),

            TimeEvent(1*FRAMES, function(inst) set_lightvalues(inst, 0.9) end),
            TimeEvent(2*FRAMES, function(inst) set_lightvalues(inst, 0.875) end),
            TimeEvent(3*FRAMES, function(inst) set_lightvalues(inst, 0.85) end),
            TimeEvent(4*FRAMES, function(inst) set_lightvalues(inst, 0.825) end),
            TimeEvent(5*FRAMES, function(inst) set_lightvalues(inst, 0.8) end),
            TimeEvent(6*FRAMES, function(inst) set_lightvalues(inst, 0.775) end),
            TimeEvent(7*FRAMES, function(inst) set_lightvalues(inst, 0.75) end),
            TimeEvent(8*FRAMES, function(inst) set_lightvalues(inst, 0.725) end),
            TimeEvent(9*FRAMES, function(inst) set_lightvalues(inst, 0.7) end),
            TimeEvent(10*FRAMES, function(inst) set_lightvalues(inst, 0.675) end),
            TimeEvent(11*FRAMES, function(inst) set_lightvalues(inst, 0.65) end),
            TimeEvent(12*FRAMES, function(inst) set_lightvalues(inst, 0.625) end),
            TimeEvent(13*FRAMES, function(inst) set_lightvalues(inst, 0.6) end),
            TimeEvent(14*FRAMES, function(inst) set_lightvalues(inst, 0.575) end),
            TimeEvent(15*FRAMES, function(inst) set_lightvalues(inst, 0.55) end),
            TimeEvent(16*FRAMES, function(inst) set_lightvalues(inst, 0.525) end),
            TimeEvent(17*FRAMES, function(inst) set_lightvalues(inst, 0.5) end),

            TimeEvent(21*FRAMES, function(inst) set_lightvalues(inst, 0.7) end),
            TimeEvent(22*FRAMES, function(inst) set_lightvalues(inst, 0.675) end),
            TimeEvent(23*FRAMES, function(inst) set_lightvalues(inst, 0.65) end),
            TimeEvent(24*FRAMES, function(inst) set_lightvalues(inst, 0.625) end),
            TimeEvent(25*FRAMES, function(inst) set_lightvalues(inst, 0.6) end),

            TimeEvent(26*FRAMES, function(inst) set_lightvalues(inst, 0.7) end),
            TimeEvent(27*FRAMES, function(inst) set_lightvalues(inst, 0.675) end),
            TimeEvent(28*FRAMES, function(inst) set_lightvalues(inst, 0.65) end),
            TimeEvent(29*FRAMES, function(inst) set_lightvalues(inst, 0.625) end),
            TimeEvent(30*FRAMES, function(inst) set_lightvalues(inst, 0.6) end),
            TimeEvent(31*FRAMES, function(inst) set_lightvalues(inst, 0.7) end),

            TimeEvent(32*FRAMES, function(inst) set_lightvalues(inst, 0.7) end),
            TimeEvent(33*FRAMES, function(inst) set_lightvalues(inst, 0.75) end),
            TimeEvent(34*FRAMES, function(inst) set_lightvalues(inst, 0.8) end),
            TimeEvent(35*FRAMES, function(inst) set_lightvalues(inst, 0.85) end),
            TimeEvent(36*FRAMES, function(inst) set_lightvalues(inst, 0.9) end),
        },

        events =
        {
            EventHandler("animover", function (inst)
                inst.sg:GoToState("epic_idle")
            end),
        },

        onexit = function(inst)
            inst.Transform:SetSixFaced()
        end,
    })