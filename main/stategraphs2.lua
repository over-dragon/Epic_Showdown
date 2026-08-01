local function DoHurtSound(inst)
    if inst.hurtsoundoverride ~= nil then
        inst.SoundEmitter:PlaySound(inst.hurtsoundoverride, nil, inst.hurtsoundvolume)
    elseif not inst:HasTag("mime") then
        inst.SoundEmitter:PlaySound((inst.talker_path_override or "dontstarve/characters/")..(inst.soundsname or inst.prefab).."/hurt", nil, inst.hurtsoundvolume)
    end
end
local function ClearStatusAilments(inst)
    if inst.components.freezable ~= nil and inst.components.freezable:IsFrozen() then
        inst.components.freezable:Unfreeze()
    end
    if inst.components.pinnable ~= nil and inst.components.pinnable:IsStuck() then
        inst.components.pinnable:Unstick()
    end
end

local function electrocute_recovery_delay(inst)
	local delay = inst.electrocute_delay or TUNING.ELECTROCUTE_DEFAULT_DELAY
	local resist = inst._electrocute_resist or 0
	local t = GetTime()
	if inst._last_electrocute_time == nil or inst._last_electrocute_time + math.max(10 * delay.max, delay.max + resist) < t then
		return false --first hit, no delay
	elseif inst._last_electrocute_delay == nil then
		inst._last_electrocute_delay = GetRandomMinMax(delay.min, delay.max) + resist
	end
	return inst._last_electrocute_time + inst._last_electrocute_delay > t
end
local function update_electrocute_recovery_delay(inst)
	local t = GetTime()
	if inst._electrocute_resist then
		if inst._last_electrocute_time then
			local delay = inst.electrocute_delay or TUNING.ELECTROCUTE_DEFAULT_DELAY
			local dt = t - inst._last_electrocute_time
			if dt > delay.max then
				inst._electrocute_resist = math.max(0, inst._electrocute_resist - (dt - delay.max) / 10)
			end
		end
		inst._electrocute_resist = inst._electrocute_resist + 1
	elseif inst:HasTag("epic") then
		inst._electrocute_resist = 1
	end
	inst._last_electrocute_time = t
	inst._last_electrocute_delay = nil
end
local function spawn_electrocute_fx(inst, data, duration)
	duration = duration or CalcEntityElectrocuteDuration(inst, data and data.duration)
	data = data and (
		data.attackdata and {
			attackdata = data.attackdata,
			targets = data.targets,
			numforks = data.numforks and data.numforks - 1 or nil,
			duration = data.duration,
			noburn = data.noburn,
		} or
		data.stimuli == "electric" and {
			attackdata = data,
			duration = data.duration,
			noburn = data.noburn,
		}
	) or nil
	local fx = SpawnPrefab("electrocute_fx")
	fx:SetFxTarget(inst, duration, data)
	return fx
end
local function try_goto_electrocute_state(inst, data, state, statedata, ongotostatefn)
	if state == nil then
        if inst.sg:HasState("electrocute") then
			state = "epic_electrocute"
			statedata = data and (
				data.stimuli == "electric" and {
					attackdata = data,
					duration = data.duration,
					noburn = data.noburn,
					numforks = data.numforks, --pass 0 (not nil) for no forking
				}
			) or data
		elseif inst.sg:HasState("hit") then
			state = "epic_hit"
		else
			return false
		end
	end

	if state ~= "electrocute" then
		update_electrocute_recovery_delay(inst)
		spawn_electrocute_fx(inst, data)
		ClearStatusAilments(inst)
		if inst.components.sleeper then
			inst.components.sleeper:WakeUp()
		end
		if inst.sg.mem.burn_on_electrocute and not (data and data.noburn) and
			inst.components.burnable and not inst.components.burnable:IsBurning()
		then
			local attackdata = data and data.attackdata or data
			inst.components.burnable:Ignite(nil, attackdata and (attackdata.weapon or attackdata.attacker), attackdata and attackdata.attacker)
		end
	end
	if ongotostatefn then
		ongotostatefn(inst)
	end
	inst.sg:GoToState(state, statedata)
	return true
end
local function try_electrocute_onevent(inst, data, state, statedata, ongotostatefn)
	return not (inst.components.inventory and inst.components.inventory:IsInsulated())
		--and not inst:HasTag("electricdamageimmune") and --V2C: redundant. either shouldn't have "electrocute" states if immune, or if using a shared SG then set sg.mem.noelectrocute = true
		--NOTE: players (e.g. wx) still goto electrocute state even if "electricdamageimmune"
		--      so we actually CAN'T check the tag here, or it will break players' behaviour.
		and not inst.sg.mem.noelectrocute
		and (not inst.sg:HasAnyStateTag("dead", "nointerrupt", "noelectrocute") or inst.sg:HasStateTag("canelectrocute"))
		and not (data and data.attacker and not data.noresist and electrocute_recovery_delay(inst))
		and try_goto_electrocute_state(inst, data, state, statedata, ongotostatefn)
end
local function onelectrocute(inst, data)
	if not (inst.components.health and inst.components.health:IsDead()) then
		try_electrocute_onevent(inst, data)
	end
end
local function SetSleeperSleepState(inst)
    if inst.components.grue ~= nil then
        inst.components.grue:AddImmunity("sleeping")
    end
    if inst.components.firebug ~= nil then
        inst.components.firebug:Disable()
    end
    if inst.components.playercontroller ~= nil then
        inst.components.playercontroller:EnableMapControls(false)
        inst.components.playercontroller:Enable(false)
    end
    inst:OnSleepIn()
    inst:ShowActions(false)
end

local function SetSleeperAwakeState(inst)
    if inst.components.grue ~= nil then
        inst.components.grue:RemoveImmunity("sleeping")
    end
    if inst.components.firebug ~= nil then
        inst.components.firebug:Enable()
    end
    if inst.components.playercontroller ~= nil then
        inst.components.playercontroller:EnableMapControls(true)
        inst.components.playercontroller:Enable(true)
    end
    inst:OnWakeUp()
    inst:ShowActions(true)
end
---malbatross
local function land_without_floater(creature)
    creature:RemoveTag("flying")
    if creature.Physics ~= nil then
		CollisionMaskBatcher(creature)
			:CollidesWith(COLLISION.LIMITS)
			:ClearCollidesWith(COLLISION.FLYERS)
			:CommitTo(creature)
    end
end

local function raise_without_floater(creature)
    creature:AddTag("flying")
    if creature.Physics ~= nil then
		CollisionMaskBatcher(creature)
			:ClearCollidesWith(COLLISION.LIMITS)
			:CollidesWith(COLLISION.FLYERS)
			:CommitTo(creature)
    end
end

local function spawnripple(inst)
    if not TheWorld.Map:IsVisualGroundAtPoint(inst.Transform:GetWorldPosition()) then
        inst.SoundEmitter:PlaySound("saltydog/creatures/boss/malbatross/ripple")
        SpawnPrefab("boss_ripple_fx").Transform:SetPosition(inst.Transform:GetWorldPosition())
    end
end
---stalker_atrium
local MAIN_SHIELD_CD = 1.2
local function PickShield(inst)
    local t = GetTime()
    if (inst.sg.mem.stalker_lastshieldtime or 0) + .2 >= t then
        return
    end

    inst.sg.mem.stalker_lastshieldtime = t

    --variation 3 or 4 is the main shield
    local dt = t - (inst.sg.mem.stalker_lastmainshield or 0)
    if dt >= MAIN_SHIELD_CD then
        inst.sg.mem.stalker_lastmainshield = t
        return math.random(3, 4)
    end

    local rnd = math.random()
    if rnd < dt / MAIN_SHIELD_CD then
        inst.sg.mem.stalker_lastmainshield = t
        return math.random(3, 4)
    end

    return rnd < dt / (MAIN_SHIELD_CD * 2) + .5 and 2 or 1
end
local function DoSpawnSpikes(inst, pts, level, cache)
    if not inst.components.health:IsDead() then
        for i, v in ipairs(pts) do
            local variation = table.remove(cache.vars, math.random(#cache.vars))
            table.insert(cache.used, variation)
            if #cache.used > 3 then
                table.insert(cache.queued, table.remove(cache.used, 1))
            end
            if #cache.vars <= 0 then
                local swap = cache.vars
                cache.vars = cache.queued
                cache.queued = swap
            end

            local spike = SpawnPrefab("stalker_fossilspike2")
            spike:SetOwner(inst)
            spike.Transform:SetPosition(v:Get())
            spike:RestartSpike(0, variation, level)
        end
    end
end

local function GenerateSpiralSpikes(inst)
    local spawnpoints = {}
    local source = inst
    local x, y, z = source.Transform:GetWorldPosition()
    local spacing = 1.7
    local radius = 2
    local deltaradius = .2
    local angle = TWOPI * math.random()
    local deltaanglemult = (inst.reversespikes and -2 or 2) * PI * spacing
    inst.reversespikes = not inst.reversespikes
    local delay = 0
    local deltadelay = 2 * FRAMES
    local num = 30
    local map = TheWorld.Map
    for i = 1, num do
        local oldradius = radius
        radius = radius + deltaradius
        local circ = PI * (oldradius + radius)
        local deltaangle = deltaanglemult / circ
        angle = angle + deltaangle
        local x1 = x + radius * math.cos(angle)
        local z1 = z + radius * math.sin(angle)
        if map:IsPassableAtPoint(x1, 0, z1) then
            table.insert(spawnpoints, {
                t = delay,
                level = i / num,
                pts = { Vector3(x1, 0, z1) },
            })
            delay = delay + deltadelay
        end
    end
    return spawnpoints, source
end

local function GenerateCircleSpikes(inst,r)
    local spawnpoints = {}
    local source = inst
    local x, y, z = source.Transform:GetWorldPosition()
    if not r then
        x, y, z = inst._facepoint_x, inst._facepoint_y, inst._facepoint_z
    end
    local spacing = 1.7
    local radius = r or 0.6
    local deltaradius = 1
    local numrings = 6
    local ringdelay = 0
    local ringgap = 8 * FRAMES
    local total = 0
    local map = TheWorld.Map

    for ring = 1, numrings do
        local circ = TWOPI * radius
        local count = math.max(1, math.floor(circ / spacing))
        local startangle = TWOPI * math.random()

        for i = 1, count do
            total = total + 1
            local angle = startangle + (i - 1) * TWOPI / count
            local x1 = x + radius * math.cos(angle)
            local z1 = z + radius * math.sin(angle)
            if map:IsPassableAtPoint(x1, 0, z1) then
                table.insert(spawnpoints, {
                    t = ringdelay,
                    level = total / 30,
                    pts = { Vector3(x1, 0, z1) },
                })
            end
        end

        ringdelay = ringdelay + ringgap
        radius = radius + deltaradius
    end

    return spawnpoints, source
end

local function PlayFlameSound(inst, source)
    source.SoundEmitter:PlaySound("dontstarve/creatures/together/stalker/flame")
end

local function SpawnSpikes(inst)

    local spikes, source = GenerateCircleSpikes(inst,1)
    if #spikes > 0 then
        local cache =
        {
            vars = { 1, 2, 3, 4, 5, 6, 7 },
            used = {},
            queued = {},
        }
        local flames = {}
        local flameperiod = .8
        for i, v in ipairs(spikes) do
            flames[math.floor(v.t / flameperiod)] = true
            inst:DoTaskInTime(v.t, DoSpawnSpikes, v.pts, v.level, cache)
        end
        if source ~= nil and source.SoundEmitter ~= nil then
            for k, v in pairs(flames) do
                inst:DoTaskInTime(k, PlayFlameSound, source)
            end
        end
    end

    spikes, source = GenerateCircleSpikes(inst)
    if #spikes > 0 then
        local cache =
        {
            vars = { 1, 2, 3, 4, 5, 6, 7 },
            used = {},
            queued = {},
        }
        local flames = {}
        local flameperiod = .8
        for i, v in ipairs(spikes) do
            flames[math.floor(v.t / flameperiod)] = true
            inst:DoTaskInTime(v.t, DoSpawnSpikes, v.pts, v.level, cache)
        end
        if source ~= nil and source.SoundEmitter ~= nil then
            for k, v in pairs(flames) do
                inst:DoTaskInTime(k, PlayFlameSound, source)
            end
        end
    end
end

local MINION_RADIUS = .3
local MINION_SPAWN_PERIOD = .75
local NUM_RINGS = 3
local RING_SIZE = 7.5 / NUM_RINGS
local RING_TOTAL = 1
for i = 2, NUM_RINGS do
    RING_TOTAL = RING_TOTAL + i * i
end

local function DoSpawnMinion(inst)
    local pt = table.remove(inst.minionpoints, math.random(#inst.minionpoints))
    local minion = SpawnPrefab("stalker_minion")
    minion.Transform:SetPosition(pt:Get())
    minion:ForceFacePoint(pt)
    minion:OnSpawnedBy(inst)
    if #inst.minionpoints <= 0 then
        inst.miniontask:Cancel()
        inst.miniontask = nil
        inst.minionpoints = nil
    end
end

--count is specified on load only
local function SpawnMinions(inst, count)
    if count == nil then
        count = TUNING.STALKER_MINIONS_COUNT
    end

    if count <= 0 or inst.miniontask ~= nil then
        return
    end

    local x, y, z = inst.Transform:GetWorldPosition()
    local map = TheWorld.Map
    inst.minionpoints = {}
    for ring = 1, NUM_RINGS do
        local ringweight = ring * ring / RING_TOTAL
        local ringcount = math.floor(count * ringweight + .5)
        if ringcount > 0 then
            local delta = TWOPI / ringcount
            local radius = ring * RING_SIZE
            for i = 1, ringcount do
                local angle = delta * i
                local x1 = x + radius * math.cos(angle) + math.random() - .5
                local z1 = z + radius * math.sin(angle) + math.random() - .5
                if map:IsAboveGroundAtPoint(x1, 0, z1) then
                    table.insert(inst.minionpoints, Vector3(x1, 0, z1))
                end
            end
        end
    end
    if #inst.minionpoints > 0 then
        inst.miniontask = inst:DoPeriodicTask(MINION_SPAWN_PERIOD, DoSpawnMinion, 0)
    else
        inst.minionpoints = nil
    end
end

local FINDMINIONS_MUST_TAGS = { "stalkerminion" }
local FINDMINIONS_CANT_TAGS = { "NOCLICK" }
local function FindMinions(inst, proximity)
    local x, y, z = inst.Transform:GetWorldPosition()
    return TheSim:FindEntities(x, y, z, MINION_RADIUS + inst:GetPhysicsRadius(0) + (proximity or .5), FINDMINIONS_MUST_TAGS, FINDMINIONS_CANT_TAGS)
end

local function EatMinions(inst)
    local minions = FindMinions(inst)
    local num = math.min(3, #minions)
    for i = 1, num do
        minions[i]:PushEvent("stalkerconsumed")
    end
    if not inst.components.health:IsDead() then
        inst.components.health:DoDelta(TUNING.STALKER_FEAST_HEALING * TUNING.EPIC_WORLD.HEALTH * num)
    end
    return num
end

local function StartMindControlSound(inst)
    if inst.sg.mem.mindcontrolsoundtask ~= nil then
        inst.sg.mem.mindcontrolsoundtask:Cancel()
        inst.sg.mem.mindcontrolsoundtask = nil
        inst.SoundEmitter:KillSound("mindcontrol")
    end
    if not inst.SoundEmitter:PlayingSound("mindcontrol") then
        inst.SoundEmitter:PlaySound("dontstarve/creatures/together/stalker/mindcontrol_LP", "mindcontrol")
    end
end

local function OnMindControlSoundFaded(inst)
    inst.sg.mem.mindcontrolsoundtask = nil
    inst.SoundEmitter:KillSound("mindcontrol")
end

local function StopMindControlSound(inst)
    if inst.sg.mem.mindcontrolsoundtask == nil and inst.SoundEmitter:PlayingSound("mindcontrol") then
        inst.SoundEmitter:SetVolume("mindcontrol", 0)
        inst.sg.mem.mindcontrolsoundtask = inst:DoTaskInTime(10, OnMindControlSoundFaded)
    end
end

local function IsValidMindControlTarget(inst, guy)
    if not inst:IsNear(guy, TUNING.STALKER_MINDCONTROL_RANGE) or guy==inst then
        return false
    end
    return not (guy.components.health:IsDead() or guy:HasTag("playerghost"))
        and (guy:DebuffsEnabled())
        and guy.entity:IsVisible()
end

local function IsCrazyGuy(guy)
    local sanity = guy ~= nil and guy.replica.sanity or nil
    return sanity ~= nil and sanity:GetPercentNetworked() <= (guy:HasTag("dappereffects") and TUNING.DAPPER_BEARDLING_SANITY or TUNING.BEARDLING_SANITY)
end

local function MindControl(inst)
    local count = 0
    for i, v in ipairs(AllPlayers) do
        if v~=inst and IsValidMindControlTarget(inst, v) and IsCrazyGuy(v) then
            count = count + 1
            v:AddDebuff("mindcontroller", "mindcontroller")
        end
    end

    return count
end

---mutatedwarg
local function SpawnHounds(inst)
    local num = 0
    local followers = inst.components.leader and inst.components.leader.followers or {}
    for k, v in pairs(followers) do
        if k:HasTag("hound") then
            num = num + 1
        end
    end

    if num>=5 then
        return
    end

    local x,y,z = inst.Transform:GetWorldPosition()
    for i = 1, 5-num do
        local prefab = math.random() <0.5 and "hound" or math.random()<0.5 and "firehound" or "icehound"
        local hound = SpawnPrefab(prefab)
        if hound ~= nil then
            if hound.components.follower ~= nil then
                hound.components.follower:SetLeader(inst)
            end
        end
        hound.Transform:SetPosition(x+math.random(-3,3),y,z+math.random(-3,3))
        hound.sg:GoToState("taunt")
    end
end

local function SpawnCloseEmberFX(inst, angle)
	local x, y, z = inst.Transform:GetWorldPosition()
	angle = (inst.Transform:GetRotation() + angle) * DEGREES
	x = x + math.cos(angle) * 3.5
	z = z - math.sin(angle) * 3.5
	angle = math.random() * PI2
	x = x + math.cos(angle) * 0.6
	z = z - math.sin(angle) * 0.6

	if not TheWorld.Map:IsPassableAtPoint(x, 0, z) then
		return
	end

	local fx = SpawnPrefab("warg_mutated_ember_fx")
	fx:SetFXOwner(inst)
	fx.Transform:SetPosition(x, 0, z)
	fx:RestartFX(1.7 + math.random() * 0.3, "nofade")
	fx:DoTaskInTime(math.random(18, 22) * FRAMES, fx.KillFX)
end

local function SpawnBreathFX(inst, angle, dist, targets)
	local fx = SpawnPrefab("warg_mutated_breath_fx")
	fx:SetFXOwner(inst)

	local scale = (1.4 + math.random() * 0.25)
	if dist < 6 then
		scale = scale * 1.2
	elseif dist > 7 then
		scale = scale * (1 + (dist - 7) / 6)
	end

	local fadeoption = (dist < 6 and "nofade") or (dist <= 7 and "latefade") or nil

	local x, y, z = inst.Transform:GetWorldPosition()
	angle = (inst.Transform:GetRotation() + angle) * DEGREES
	x = x + math.cos(angle) * dist
	z = z - math.sin(angle) * dist
	dist = dist / 20
	angle = math.random() * PI2
	x = x + math.cos(angle) * dist
	z = z - math.sin(angle) * dist

	fx.Transform:SetPosition(x, 0, z)
	fx:RestartFX(scale, fadeoption, targets)
end

local AOE_OFFSET = 3
local AOE_RANGE = 1.7
local AOE_RANGE_PADDING = 3
local AOE_TARGET_TAGS = { "_combat" }
local AOE_TARGET_CANT_TAGS = { "INLIMBO", "playerghost" }
local MULTIHIT_FRAMES = 10

--NOTE: This is for close range that the breath fx doesn't fully cover
local function DoFlamethrowerAOE(inst, angle, targets)
	inst.components.combat.ignorehitrange = true
	inst.components.combat.ignoredamagereflect = true

	local tick = GetTick()
	local x, y, z = inst.Transform:GetWorldPosition()
	angle = (inst.Transform:GetRotation() + angle) * DEGREES
	x = x + math.cos(angle) * AOE_OFFSET
	z = z - math.sin(angle) * AOE_OFFSET
	local ents = TheSim:FindEntities(x, 0, z, AOE_RANGE + AOE_RANGE_PADDING, AOE_TARGET_TAGS, AOE_TARGET_CANT_TAGS)
	for i, v in ipairs(ents) do
		if v:IsValid() and not v:IsInLimbo() and not (v.components.health ~= nil and v.components.health:IsDead()) then
			local range = AOE_RANGE + v:GetPhysicsRadius(0)
			if v:GetDistanceSqToPoint(x, 0, z) < range * range then
				local target_data = targets[v]
				if target_data == nil then
					target_data = {}
					targets[v] = target_data
				end
				if target_data.tick ~= tick then
					target_data.tick = tick
					--Supercool
            		local ent_temp = GetEntityTemperature(v)
					if ent_temp and TUNING.MUTATED_WARG_COLDFIRE_TEMPERATURE < ent_temp then
						SetEntityTemperature(v, TUNING.MUTATED_WARG_COLDFIRE_TEMPERATURE)
					end
					--Hit
					if (target_data.hit_tick == nil or target_data.hit_tick + MULTIHIT_FRAMES < tick) and inst.components.combat:CanTarget(v) then
						target_data.hit_tick = tick
						inst.components.combat:DoAttack(v)
					end
				end
			end
		end
	end

	inst.components.combat.ignorehitrange = false
	inst.components.combat.ignoredamagereflect = false
end

---mutatedbearger
local AOE_TARGET_MUSTHAVE_TAGS = { "_combat" }

local function DoAOEAttack(inst, dist, radius, heavymult, mult, forcelanded, targets, knockback_existing_targets)
	inst.components.combat.ignorehitrange = true
	local x, y, z = inst.Transform:GetWorldPosition()
	local rot = inst.Transform:GetRotation() * DEGREES
	if dist ~= 0 then
		x = x + dist * math.cos(rot)
		z = z - dist * math.sin(rot)
	end
	for i, v in ipairs(TheSim:FindEntities(x, y, z, radius + AOE_RANGE_PADDING, AOE_TARGET_MUSTHAVE_TAGS, AOE_TARGET_CANT_TAGS)) do
		if v ~= inst and v:IsValid() and not v:IsInLimbo() and
			not (v.components.health ~= nil and v.components.health:IsDead())
		then
			local is_existing_target = targets ~= nil and targets[v]
			if not is_existing_target or knockback_existing_targets then
				local range = radius + v:GetPhysicsRadius(0)
				local distsq = v:GetDistanceSqToPoint(x, y, z)
				if distsq < range * range then
					local should_knockback = is_existing_target
					if not is_existing_target and inst.components.combat:CanTarget(v) then
						if targets then
							targets[v] = true
							if mult and v.components.rider and v.components.rider.mount then
								targets[v.components.rider.mount] = true
							end
						end
						inst.components.combat:DoAttack(v)
						should_knockback = true
					end
					if should_knockback and mult ~= nil then
						v:PushEvent("knockback", { knocker = inst, radius = radius + dist, strengthmult = (v.components.inventory ~= nil and v.components.inventory:ArmorHasTag("heavyarmor") or v:HasTag("heavybody")) and heavymult or mult, forcelanded = forcelanded })
					end
				end
			end
		end
	end
	inst.components.combat.ignorehitrange = false
end
---mutateddeerclops
local ICE_LANCE_RADIUS = 5.5
local AREAATTACK_MUST_TAGS = { "_combat" }
local AREA_EXCLUDE_TAGS = { "INLIMBO", "notarget", "noattack", "playerghost" }
local function DoIceLanceAOE(inst, pt, targets)
	inst.components.combat.ignorehitrange = true
	local dist = math.sqrt(inst:GetDistanceSqToPoint(pt))
	local ents = TheSim:FindEntities(pt.x, 0, pt.z, ICE_LANCE_RADIUS, AREAATTACK_MUST_TAGS, AREA_EXCLUDE_TAGS)
	for i, v in ipairs(ents) do
		if not targets[v] and v:IsValid() and not v:IsInLimbo() and
			not (v.components.health ~= nil and v.components.health:IsDead()) and
			inst.components.combat:CanTarget(v)
		then
			local wasfrozen = v.components.freezable ~= nil and v.components.freezable:IsFrozen()
			if wasfrozen and v.components.rider and v.components.rider.mount then
				targets[v.components.rider.mount] = true
			end
			inst.components.combat:DoAttack(v)
			if wasfrozen then
				v:PushEvent("knockback", { knocker = inst, radius = dist + ICE_LANCE_RADIUS })
			end
			targets[v] = true
		end
	end
	inst.components.combat.ignorehitrange = false
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

AddStategraphEvent("wilson", EventHandler("onload_wereepic", function(inst,data)
    if data and data.mode~="none" then
        inst.sg:GoToState("epic_castspell_onload",{mode = data.mode})
    end
end))

AddStategraphEvent("wilson", EventHandler("stalker_atrium_fossilfeast", function(inst)
    local mode = inst.components.wereepic and inst.components.wereepic:GetEpicMode()
    if mode=="stalker_atrium" and not (inst.sg:HasStateTag("busy") or inst.components.health:IsDead() or inst.sg:HasStateTag("attack")) then
        inst.sg:GoToState("stalker_atrium_eat_pre")
    end
end))

AddStategraphState("wilson",State{
        name = "epic_idle",
        tags = { "idle", "canrotate" ,"epic"},

        onenter = function(inst)
            if inst.sg.lasttags and not inst.sg.lasttags["busy"] then
				inst.components.locomotor:StopMoving()
			else
				inst.components.locomotor:Stop()
				inst.components.locomotor:Clear()
			end
			inst:ClearBufferedAction()

            local mode = inst.components.wereepic and inst.components.wereepic:GetEpicMode()
            if mode=="moose" or mode=="antlion" or mode=="dragonfly" or mode=="daywalker" or mode=="daywalker2" or mode=="alterguardian_phase1" or mode=="alterguardian_phase2" then
                inst.AnimState:PlayAnimation("idle", true)
            elseif mode=="alterguardian_phase3" then
                if math.random()<.5 then
                    inst.AnimState:PlayAnimation("idle2", true)
                else
                    inst.AnimState:PlayAnimation("idle", true)
                end
            elseif mode=="stalker_atrium" then
                inst.AnimState:PlayAnimation("idle")
                inst.SoundEmitter:PlaySound("dontstarve/creatures/together/stalker/in")
            else
                inst.AnimState:PlayAnimation("idle_loop",true)
            end

            inst.sg.statemem.epicmode = mode
        end,

        timeline =
        {
            TimeEvent(26 * FRAMES, function(inst)
                if inst.sg.statemem.epicmode=="stalker_atrium" then
                    inst.SoundEmitter:PlaySound("dontstarve/creatures/together/stalker/out")
                end
            end),
        },

        events =
        {
            EventHandler("animover", function(inst)
                if inst.AnimState:AnimDone() then
                    if inst.sg.statemem.epicmode=="stalker_atrium" then
                        inst.sg:GoToState("epic_idle")
                    end
                end
            end),
        },

		onexit = function(inst)

		end,
    })

AddStategraphState("wilson",State{
        name = "epic_hit",
		tags = { "busy", "pausepredict", "keepchannelcasting" ,"epic"},

        onenter = function(inst, frozen)
            local mode = inst.components.wereepic and inst.components.wereepic:GetEpicMode()
            inst.components.locomotor:Stop()
            inst:ClearBufferedAction()
            if mode=="bearger" or mode=="mutatedbearger" then
                inst.AnimState:PlayAnimation("standing_hit")
            else
                inst.AnimState:PlayAnimation("hit")
            end

            if frozen == "noimpactsound" then
                frozen = nil
            else
                inst.SoundEmitter:PlaySound("dontstarve/wilson/hit")
            end
            DoHurtSound(inst)

            --V2C: some of the woodie's were-transforms have shorter hit anims
			local stun_frames = math.min(inst.AnimState:GetCurrentAnimationNumFrames(), frozen and 12 or 10)
            if inst.components.playercontroller ~= nil then
                --Specify min frames of pause since "busy" tag may be
                --removed too fast for our network update interval.
                inst.components.playercontroller:RemotePausePrediction(stun_frames <= 7 and stun_frames or nil)
            end
            inst.sg:SetTimeout(stun_frames * FRAMES)
        end,

        ontimeout = function(inst)
			--V2C: -removing the tag now, since this is actually a supported "channeling_item"
			--      state (i.e. has custom anim)
			--     -the state enters with the tag though, to cheat having to create a separate
			--      hit state for channeling items
			inst.sg:RemoveStateTag("keepchannelcasting")
            inst.sg:GoToState("epic_idle")
        end,

        timeline =
		{
			FrameEvent(5, function(inst) inst.sg:RemoveStateTag("busy") end),
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
        name = "epic_electrocute",
		tags = { "busy", "pausepredict", "electrocute", "noelectrocute","epic" },

		onenter = function(inst, data)
            local mode = inst.components.wereepic and inst.components.wereepic:GetEpicMode()
            inst.sg.statemem.epicmode = mode
            ClearStatusAilments(inst)
			if inst.components.grogginess then
				inst.components.grogginess:ResetGrogginess()
			end

            inst.components.locomotor:Stop()
			inst.components.locomotor:Clear()
            inst:ClearBufferedAction()

            local fx = SpawnPrefab("electrocute_fx")
	        fx:SetFxTarget(inst, 0.5, data)

			local isplant = inst:HasTag("plantkin")
			local isshort = isplant or (data ~= nil and data.duration ~= nil and data.duration <= TUNING.ELECTROCUTE_SHORT_DURATION)

            if not inst:HasTag("electricdamageimmune") then
                inst.components.bloomer:PushBloom("electrocute", "shaders/anim.ksh", -2)
                inst.Light:Enable(true)

				if isplant and not (data and data.noburn) then
					local attackdata = data and data.attackdata or data
					inst.components.burnable:Ignite(nil, attackdata and (attackdata.weapon or attackdata.attacker), attackdata and attackdata.attacker)
				end
            end

			if data then
				data =
					data.attackdata and {
						attackdata = data.attackdata,
						targets = data.targets,
						numforks = data.numforks and data.numforks - 1 or nil,
					} or
					data.stimuli == "electric" and {
						attackdata = data,
					} or
					nil
				if data then
					StartElectrocuteForkOnTarget(inst, data)
				end
			end

            inst.AnimState:PlayAnimation("shock_loop")
            inst.AnimState:PushAnimation("shock_pst", false)
			if isshort then
				inst.AnimState:SetFrame(8)
				inst.sg:SetTimeout(inst.AnimState:GetCurrentAnimationLength() + (2 - 8) * FRAMES)
			else
				inst.sg:SetTimeout(inst.AnimState:GetCurrentAnimationLength() + 4 * FRAMES)
			end

            DoHurtSound(inst)

            if inst.components.playercontroller ~= nil then
                inst.components.playercontroller:RemotePausePrediction()
            end
        end,

        events =
        {
            EventHandler("animover", function(inst)
                if not inst:HasTag("electricdamageimmune") then
                    inst.Light:Enable(false)
                    inst.components.bloomer:PopBloom("electrocute")
                end
            end),

            EventHandler("animqueueover", function(inst)
                if inst.AnimState:AnimDone() then
                    inst.sg:GoToState("epic_idle")
                end
            end),
        },

        ontimeout = function(inst)
			inst.sg:RemoveStateTag("busy")
			inst.sg:RemoveStateTag("pausepredict")
			inst.sg:RemoveStateTag("noelectrocute")
			inst.sg:AddStateTag("idle")
        end,

        onexit = function(inst)
            if not inst:HasTag("electricdamageimmune") then
                inst.Light:Enable(false)
                inst.components.bloomer:PopBloom("electrocute")
            end
            if inst.sg.statemem.epicmode=="deerclops" then
                inst.Light:Enable(true)
            end
        end,
    })

AddStategraphState("wilson",State{
        name = "epic_frozen",
        tags = { "busy", "frozen", "nopredict", "nodangle","epic" },

        onenter = function(inst)
            if inst.components.pinnable ~= nil and inst.components.pinnable:IsStuck() then
                inst.components.pinnable:Unstick()
            end

            inst.components.locomotor:Stop()
            inst:ClearBufferedAction()

            inst.AnimState:OverrideSymbol("swap_frozen", "frozen", "frozen")
            inst.AnimState:PlayAnimation("frozen")
            inst.SoundEmitter:PlaySound("dontstarve/common/freezecreature")

            if inst.components.playercontroller ~= nil then
                inst.components.playercontroller:EnableMapControls(false)
                inst.components.playercontroller:Enable(false)
            end

            --V2C: cuz... freezable component and SG need to match state,
            --     but messages to SG are queued, so it is not great when
            --     when freezable component tries to change state several
            --     times within one frame...
            if inst.components.freezable == nil then
                inst.sg:GoToState("epic_hit", true)
            elseif inst.components.freezable:IsThawing() then
                inst.sg.statemem.isstillfrozen = true
                inst.sg:GoToState("epic_thaw")
            elseif not inst.components.freezable:IsFrozen() then
                inst.sg:GoToState("epic_hit", true)
            end
        end,

        events =
        {
            EventHandler("onthaw", function(inst)
                inst.sg.statemem.isstillfrozen = true
                inst.sg:GoToState("epic_thaw")
            end),
            EventHandler("unfreeze", function(inst)
                inst.sg:GoToState("epic_hit", true)
            end),
        },

        onexit = function(inst)
            if not inst.sg.statemem.isstillfrozen then
                if inst.components.playercontroller ~= nil then
                    inst.components.playercontroller:EnableMapControls(true)
                    inst.components.playercontroller:Enable(true)
                end
            end
            inst.AnimState:ClearOverrideSymbol("swap_frozen")
        end,
    })

AddStategraphState("wilson",State{
        name = "epic_thaw",
        tags = { "busy", "thawing", "nopredict", "nodangle","epic" },

        onenter = function(inst)
            inst.components.locomotor:Stop()
            inst:ClearBufferedAction()

            inst.AnimState:OverrideSymbol("swap_frozen", "frozen", "frozen")
            inst.AnimState:PlayAnimation("frozen_loop_pst", true)
            inst.SoundEmitter:PlaySound("dontstarve/common/freezethaw", "thawing")

            if inst.components.playercontroller ~= nil then
                inst.components.playercontroller:EnableMapControls(false)
                inst.components.playercontroller:Enable(false)
            end
        end,

        events =
        {
            EventHandler("unfreeze", function(inst)
                inst.sg:GoToState("epic_hit", true)
            end),
        },

        onexit = function(inst)
            if inst.components.playercontroller ~= nil then
                inst.components.playercontroller:EnableMapControls(true)
                inst.components.playercontroller:Enable(true)
            end
            inst.SoundEmitter:KillSound("thawing")
            inst.AnimState:ClearOverrideSymbol("swap_frozen")
        end,
    })

AddStategraphState("wilson",State{
        name = "epic_knockout",
        tags = { "busy", "knockout", "nopredict", "nomorph","epic" },

        onenter = function(inst,data)
            local mode = inst.components.wereepic and inst.components.wereepic:GetEpicMode()
            inst.components.locomotor:Stop()
            inst:ClearBufferedAction()
            if mode=="bearger" or mode=="mutatedbearger" then
                inst.AnimState:PlayAnimation("standing_sleep_pre")
				inst.AnimState:PushAnimation("sleep_pre", false)
                inst.AnimState:PushAnimation("sleep_loop",true)
            elseif mode=="malbatross" then
                land_without_floater(inst)
                if not inst:IsOnPassablePoint() then
                    inst.AnimState:PlayAnimation("sleep_ocean_pre")
                    inst.AnimState:PushAnimation("sleep_ocean_loop",true)
                else
                    inst.AnimState:PlayAnimation("sleep_pre")
                    inst.AnimState:PushAnimation("sleep_loop",true)
                end
            else
                inst.AnimState:PlayAnimation("sleep_pre")
                inst.AnimState:PushAnimation("sleep_loop",true)
            end

            SetSleeperSleepState(inst)

            if data and data.source=="yawn" then
                inst.sg:SetTimeout(TUNING.MANDRAKE_SLEEP_TIME*2)
            else
                inst.sg:SetTimeout(TUNING.MANDRAKE_SLEEP_TIME)
            end
            inst.sg:AddStateTag("hitwakeup")
        end,

        ontimeout = function(inst)
            inst.sg:GoToState("epic_wakeup")
        end,

        timeline =
        {
            TimeEvent(1*FRAMES, function(inst)
                if inst.sg.statemem.epicmode=="malbatross" then
                    inst.SoundEmitter:PlaySound("turnoftides/common/together/water/splash/jump_boss")
                end
            end),
            TimeEvent(15*FRAMES, function(inst)
                if inst.sg.statemem.epicmode=="moose" then
                    inst.SoundEmitter:PlaySound("dontstarve_DLC001/creatures/mossling/yawn")
                end
            end),
            TimeEvent(25*FRAMES, function(inst)
                if inst.sg.statemem.epicmode=="moose" then
                    inst.SoundEmitter:PlaySound("dontstarve_DLC001/creatures/mossling/sleep")
                end
            end),
            TimeEvent(42 * FRAMES, function(inst)
                inst.sg:RemoveStateTag("hitwakeup")
				inst.sg:AddStateTag("sleeping")
            end),
        },

        events =
        {
            EventHandler("firedamage", function(inst)
                if inst.sg:HasStateTag("sleeping") and not inst.sg:HasStateTag("drowning") and not inst.sg:HasStateTag("falling") then
                    inst.sg.statemem.iswaking = true
                    inst.sg:GoToState("epic_wakeup")
                else
                    inst.sg.statemem.cometo = true
                end
            end),
            EventHandler("cometo", function(inst)
                if inst.sg:HasStateTag("sleeping") and not inst.sg:HasStateTag("drowning") and not inst.sg:HasStateTag("falling") then
                    inst.sg.statemem.iswaking = true
                    inst.sg:GoToState("epic_wakeup")
                else
                    inst.sg.statemem.cometo = true
                end
            end),
            EventHandler("animover", function(inst)
                if inst.AnimState:AnimDone() then
                    if inst.sg.statemem.cometo then
                        inst.sg.statemem.iswaking = true
                        inst.sg:GoToState("epic_wakeup")
                    else
                        inst.sg:AddStateTag("sleeping")
                    end
                end
            end),
        },

        onexit = function(inst)
            if inst.components.grogginess then
                inst.components.grogginess.knockedout = false
				inst.components.grogginess:CapToResistance()
            end
            if not inst.sg.statemem.iswaking then
                --Interrupted
                SetSleeperAwakeState(inst)
            end
        end,
    })

AddStategraphState("wilson",State{
        name = "epic_wakeup",
        tags = { "busy", "waking", "nomorph", "nodangle","epic" },

        onenter = function(inst, data)
            if inst.components.playercontroller ~= nil then
                inst.components.playercontroller:Enable(false)
            end
            local mode = inst.components.wereepic and inst.components.wereepic:GetEpicMode()
            if mode=="malbatross" then
                if not inst:IsOnPassablePoint() then
                    inst.AnimState:PlayAnimation("sleep_ocean_pst")
                else
                    inst.AnimState:PlayAnimation("sleep_pst")
                end
            else
                inst.AnimState:PlayAnimation("sleep_pst")
            end

            inst.sg.statemem.epicmode = mode
        end,

        timeline = {
            TimeEvent(10*FRAMES, function(inst)
                if inst.sg.statemem.epicmode=="moose" then
                    inst.SoundEmitter:PlaySound("dontstarve_DLC001/creatures/mossling/hatch")
                end
            end),
            TimeEvent(28*FRAMES, function(inst)
                if inst.sg.statemem.epicmode=="malbatross" then
                    spawnripple(inst)
                end
            end),
            TimeEvent(44*FRAMES, function(inst)
                if inst.sg.statemem.epicmode=="malbatross" then
                    raise_without_floater(inst)
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
            SetSleeperAwakeState(inst)
        end,
    })
---stalker_atrium
AddStategraphState("wilson",State{
        name = "stalker_atrium_spikes",
        tags = { "busy", "stalker_atrium_spikes","epic","epic_skill" },

        onenter = function(inst)
            inst.components.locomotor:StopMoving()
            inst.AnimState:PlayAnimation("spike")
            inst.SoundEmitter:PlaySound("dontstarve/creatures/together/stalker/attack1_pbaoe_pre")
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
            TimeEvent(6 * FRAMES, function(inst)
                SpawnSpikes(inst)
            end),
            TimeEvent(8 * FRAMES, function(inst) inst.SoundEmitter:PlaySound("dontstarve/creatures/together/stalker/out") end),
            TimeEvent(12 * FRAMES, function(inst) inst.SoundEmitter:PlaySound("dontstarve/creatures/together/stalker/in") end),
            TimeEvent(30 * FRAMES, function(inst)
                inst.SoundEmitter:PlaySound("dontstarve/creatures/together/stalker/laugh")
                inst.components.epicscare:Scare(5)
            end),
            TimeEvent(48 * FRAMES, function(inst) inst.SoundEmitter:PlaySound("dontstarve/creatures/together/stalker/taunt_short", nil, .6) end),
            TimeEvent(50 * FRAMES, function(inst) inst.SoundEmitter:PlaySound("dontstarve/creatures/together/stalker/attack1_pbaoe") end),
            TimeEvent(51 * FRAMES, function(inst)
                ShakeAllCameras(CAMERASHAKE.VERTICAL, .5, .03, .7, inst, 30)
                inst.components.combat:DoAreaAttack(inst, 3.5, nil, nil, nil, { "INLIMBO", "notarget", "invisible", "noattack", "playerghost", "shadow", "shadowchesspiece", "shadowcreature" })
            end),
            TimeEvent(61 * FRAMES, function(inst)
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
    })

AddStategraphState("wilson",State{
        name = "stalker_atrium_summon_minions_pre",
        tags = { "busy", "summoning","stalker_atrium_summon_minions_pre","epic","epic_skill","pausepredict" },

        onenter = function(inst)
            inst.components.locomotor:StopMoving()
            inst.AnimState:PlayAnimation("summon_pre")
            inst.sg.statemem.count = 3
            if inst.components.playercontroller then
                inst.components.playercontroller:RemotePausePrediction()
            end
        end,

        events =
        {
            EventHandler("attacked", function(inst)
                inst.sg.statemem.count = inst.sg.statemem.count - 1
            end),
            EventHandler("animover", function(inst)
                if inst.AnimState:AnimDone() then
                    SpawnMinions(inst)
                    inst.sg:GoToState("stalker_atrium_summon_minions_loop", { count = inst.sg.statemem.count })
                end
            end),
        },
    })

AddStategraphState("wilson",State{
        name = "stalker_atrium_summon_minions_loop",
        tags = { "busy", "summoning","stalker_atrium_summon_minions_loop","epic","epic_skill","pausepredict" },

        onenter = function(inst, data)
            inst.components.locomotor:StopMoving()
            inst.AnimState:PlayAnimation("summon_loop")
            inst.SoundEmitter:PlaySound("dontstarve/creatures/together/stalker/summon")
            inst.sg.statemem.data = data or { count = 0 }
        end,

        timeline =
        {
            TimeEvent(4 * FRAMES, function(inst)
                ShakeAllCameras(CAMERASHAKE.VERTICAL, .5, .02, .2, inst, 30)
            end),
            TimeEvent(5 * FRAMES, function(inst)
                inst.components.epicscare:Scare(5)
            end),
        },

        events =
        {
            EventHandler("attacked", function(inst)
                inst.sg.statemem.data.count = inst.sg.statemem.data.count - 1
            end),
            EventHandler("animover", function(inst)
                if inst.AnimState:AnimDone() then
                    if inst.sg.statemem.data.count > 1 or not inst.sg.statemem.data.looped then
                        inst.sg.statemem.data.count = inst.sg.statemem.data.count - 1
                        inst.sg.statemem.data.looped = true
                        inst.sg:GoToState("stalker_atrium_summon_minions_loop", inst.sg.statemem.data)
                    else
                        inst.sg:GoToState("stalker_atrium_summon_minions_pst")
                    end
                end
            end),
        },
    })

AddStategraphState("wilson",State{
        name = "stalker_atrium_summon_minions_pst",
        tags = { "busy", "summoning","stalker_atrium_summon_minions_pst","epic","epic_skill","pausepredict" },

        onenter = function(inst)
            inst.components.locomotor:StopMoving()
            inst.AnimState:PlayAnimation("summon_pst")
        end,

        timeline =
        {
            TimeEvent(7 * FRAMES, function(inst)
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
    })

AddStategraphState("wilson",State{
        name = "stalker_atrium_eat_pre",
        tags = { "busy", "feasting","epic","epic_skill","pausepredict" },

        onenter = function(inst)
            inst.components.locomotor:StopMoving()
            inst.AnimState:PlayAnimation("taunt2_pre")
            inst.sg.statemem.data =
            {
                side = math.random() < .5,
                resist = 1,
            }
        end,

        events =
        {
            EventHandler("attacked", function(inst)
                inst.sg.statemem.data.resist = inst.sg.statemem.data.resist - 1
            end),
            EventHandler("animover", function(inst)
                if inst.AnimState:AnimDone() then
                    inst.sg:GoToState("stalker_atrium_eat_idle", inst.sg.statemem.data)
                end
            end),
        },
    })

AddStategraphState("wilson",State{
        name = "stalker_atrium_eat_idle",
        tags = { "busy", "feasting","epic","epic_skill","pausepredict" },

        onenter = function(inst, data)
            local ishurt = inst.components.health:IsHurt()
            if ishurt and #FindMinions(inst) > 0 then
                data.idle = 0
                inst.sg:GoToState("stalker_atrium_eat_loop", data)
                return
            elseif data.idle ~= nil and (not ishurt or data.idle > 6 or data.resist <= 0 or #FindMinions(inst,5) <= 0) then
                inst.sg:GoToState("stalker_atrium_eat_pst")
                return
            end

            data.idle = (data.idle or 0) + 1
            inst.sg.statemem.data = data

            inst.components.locomotor:StopMoving()
            inst.AnimState:PlayAnimation("taunt2_loop1")
        end,

        timeline =
        {
            TimeEvent(2 * FRAMES, function(inst) inst.SoundEmitter:PlaySound("dontstarve/creatures/together/stalker/in") end),
            TimeEvent(12 * FRAMES, function(inst)
                inst.components.epicscare:Scare(5)
            end),
            TimeEvent(18 * FRAMES, function(inst) inst.SoundEmitter:PlaySound("dontstarve/creatures/together/stalker/out") end),
        },

        events =
        {
            EventHandler("attacked", function(inst)
                inst.sg.statemem.data.resist = inst.sg.statemem.data.resist - 1
            end),
            EventHandler("animover", function(inst)
                if inst.AnimState:AnimDone() then
                    inst.sg:GoToState("stalker_atrium_eat_idle", inst.sg.statemem.data)
                end
            end),
        },
    })

AddStategraphState("wilson",State{
        name = "stalker_atrium_eat_loop",
        tags = { "busy", "feasting","epic","epic_skill","pausepredict" },

        onenter = function(inst, data)
            inst.components.locomotor:StopMoving()
            data.side = not data.side
            inst.sg.statemem.data = data
            inst.AnimState:PlayAnimation(data.side and "taunt2_loop2" or "taunt2_loop3")
        end,

        timeline =
        {
            TimeEvent(9 * FRAMES, function(inst)
                if EatMinions(inst) > 0 then
                    inst.AnimState:Show("FX_EAT")
                else
                    inst.AnimState:Hide("FX_EAT")
                end
                inst.SoundEmitter:PlaySound("dontstarve/creatures/together/stalker/taunt_short")
            end),
            TimeEvent(11.5 * FRAMES, function(inst)
                ShakeAllCameras(CAMERASHAKE.FULL, .5, .02, .2, inst, 30)
            end),
            TimeEvent(12.5 * FRAMES, function(inst)
                inst.components.epicscare:Scare(5)
            end),
            TimeEvent(21 * FRAMES, function(inst) inst.SoundEmitter:PlaySound("dontstarve/creatures/together/stalker/out") end),
        },

        events =
        {
            EventHandler("attacked", function(inst)
                inst.sg.statemem.data.resist = inst.sg.statemem.data.resist - 1
            end),
            EventHandler("animover", function(inst)
                if inst.AnimState:AnimDone() then
                    inst.sg:GoToState("stalker_atrium_eat_idle", inst.sg.statemem.data)
                end
            end),
        },
    })

AddStategraphState("wilson",State{
        name = "stalker_atrium_eat_pst",
        tags = { "busy","epic","epic_skill","pausepredict" },

        onenter = function(inst)
            inst.components.locomotor:StopMoving()
            inst.AnimState:PlayAnimation("taunt2_pst")
        end,

        timeline =
        {
            TimeEvent(8 * FRAMES, function(inst)
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
    })

AddStategraphState("wilson",State{
        name = "stalker_atrium_mindcontrol_pre",
        tags = { "busy", "mindcontrol","epic","epic_skill","pausepredict","stalker_atrium_mindcontrol_pre" },

        onenter = function(inst)
            inst.components.locomotor:StopMoving()
            inst.AnimState:PlayAnimation("control_pre")
            inst.sg.statemem.count = 2
            if inst.components.playercontroller then
                inst.components.playercontroller:RemotePausePrediction()
            end
        end,

        events =
        {
            EventHandler("animover", function(inst)
                if inst.AnimState:AnimDone() then
                    inst.sg:GoToState("stalker_atrium_mindcontrol_loop", inst.sg.statemem.count)
                end
            end),
        },
    })

AddStategraphState("wilson",State{
        name = "stalker_atrium_mindcontrol_loop",
        tags = { "busy", "mindcontrol","epic","epic_skill","pausepredict","stalker_atrium_mindcontrol_loop" },

        onenter = function(inst, count)
            inst.components.locomotor:StopMoving()
            inst.AnimState:PlayAnimation("control_loop")
            StartMindControlSound(inst)
            inst.sg.statemem.count = MindControl(inst) > 0 and count or 0
            ShakeAllCameras(CAMERASHAKE.FULL, 2, .04, .075, inst, 30)
            inst.components.epicscare:Scare(5)
            -- if inst.components.playercontroller then
            --     inst.components.playercontroller:RemotePausePrediction()
            -- end
        end,

        onupdate = function(inst)
            if MindControl(inst) <= 0 then
                inst.sg.statemem.count = 0
            end
        end,

        events =
        {
            EventHandler("animover", function(inst)
                if inst.AnimState:AnimDone() then
                    if inst.sg.statemem.count > 1 then
                        inst.sg.statemem.continue = true
                        inst.sg:GoToState("stalker_atrium_mindcontrol_loop", inst.sg.statemem.count - 1)
                    else
                        inst.sg:GoToState("stalker_atrium_mindcontrol_pst")
                    end
                end
            end),
        },

        onexit = function(inst)
            if not inst.sg.statemem.continue then
                StopMindControlSound(inst)
            end
        end,
    })

AddStategraphState("wilson",State{
        name = "stalker_atrium_mindcontrol_pst",
        tags = { "busy", "mindcontrol","epic","epic_skill","pausepredict","stalker_atrium_mindcontrol_pst" },

        onenter = function(inst)
            inst.components.locomotor:StopMoving()
            inst.AnimState:PlayAnimation("control_pst")
        end,

        timeline =
        {
            TimeEvent(8 * FRAMES, function(inst)
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
    })

AddStategraphState("wilson",State{
        name = "mutatedwarg_howl",
        tags = { "busy", "howling","epic","epic_skill" },

        onenter = function(inst)
            inst.Physics:Stop()
            inst.AnimState:PlayAnimation("howl")
            inst.SoundEmitter:PlaySound("rifts3/mutated_varg/howl")
            inst:PerformBufferedAction()
        end,

        timeline =
        {
            TimeEvent(10 * FRAMES, function(inst)
				SpawnHounds(inst)
            end),
			FrameEvent(36, function(inst)
				inst.sg:AddStateTag("caninterrupt")
			end),
			FrameEvent(45, function(inst)
				if inst.sg:HasStateTag("caninterrupt") then
					inst.sg:RemoveStateTag("busy")
				end
			end),
        },

        events =
        {
            EventHandler("animover", function(inst)
                inst.sg:GoToState("epic_idle")
            end),
        },
    })

AddStategraphState("wilson",State{
		name = "mutatedwarg_flamethrower_pre",
		tags = { "epic","epic_skill", "busy" },

		onenter = function(inst)
			inst.components.locomotor:Stop()
			inst.AnimState:PlayAnimation("atk_breath_pre")
			inst.Transform:SetEightFaced()
            inst:RemoveTag("mutatedwarg_flamethrower")
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
                inst.sg.statemem.targetpos = Vector3(inst._facepoint_x, inst._facepoint_y, inst._facepoint_z)
			end
            inst:PerformBufferedAction()
		end,

		onupdate = function(inst)
			local target = inst.sg.statemem.target
            local targetpos = inst.sg.statemem.targetpos
			if targetpos then
				local p = targetpos
                if target and target:IsValid() then
                    p.x, p.y, p.z = target.Transform:GetWorldPosition()
                end
				local rot = inst.Transform:GetRotation()
				local rot1 = inst:GetAngleToPoint(p)
				local drot = ReduceAngle(rot1 - rot)
				if math.abs(drot) < 90 then
					rot1 = rot + math.clamp(drot / 2, -1, 1)
					--snap to 45's
					inst.Transform:SetRotation(math.floor(rot1 / 45 + .5) * 45)
				end
                if inst.sg.statemem.angle ~= nil then
                    DoFlamethrowerAOE(inst, inst.sg.statemem.angle, inst.sg.statemem.targets)
                end
			end
		end,

		timeline =
		{
			FrameEvent(0, function(inst) inst.SoundEmitter:PlaySound("rifts3/mutated_varg/blast_pre_f0") end),
			FrameEvent(16, function(inst)
				inst.sg.statemem.target = nil
				inst.sg.statemem.targets = {}
			end),

			FrameEvent(17, function(inst)
				inst.SoundEmitter:PlaySound("rifts3/mutated_varg/blast_pre_f17")
				inst.SoundEmitter:PlaySound("rifts3/mutated_varg/blast_lp", "loop")
			end),
			FrameEvent(19, function(inst) SpawnBreathFX(inst, -40, 4, inst.sg.statemem.targets) end),

			FrameEvent(20, function(inst) inst.sg.statemem.angle = -45 end),
			FrameEvent(21, function(inst) SpawnBreathFX(inst, -45, 6, inst.sg.statemem.targets) end),
			FrameEvent(24, function(inst) SpawnBreathFX(inst, -45, 8, inst.sg.statemem.targets) end),
			FrameEvent(27, function(inst) SpawnBreathFX(inst, -45, 9, inst.sg.statemem.targets) end),

			FrameEvent(29, function(inst) SpawnCloseEmberFX(inst, -45) end),
			FrameEvent(26, function(inst) SpawnBreathFX(inst, -45, 5, inst.sg.statemem.targets) end),
			FrameEvent(29, function(inst) SpawnBreathFX(inst, -45, 7, inst.sg.statemem.targets) end),

			--frame 30 is start of "flamethrower_loop"
		},

		events =
		{
			EventHandler("animover", function(inst)
				if inst.AnimState:AnimDone() then
					inst.sg.statemem.attacking = true
					inst.sg:GoToState("mutatedwarg_flamethrower_loop", {targets = inst.sg.statemem.targets})
				end
			end),
		},

		onexit = function(inst)
			if not inst.sg.statemem.attacking then
				inst.Transform:SetSixFaced()
				inst.SoundEmitter:KillSound("loop")
			end
		end,
	})

AddStategraphState("wilson",State{
		name = "mutatedwarg_flamethrower_loop",
		tags = { "busy","epic","epic_skill","nopredict", "nomorph" },

		onenter = function(inst, data)
			inst.components.locomotor:Stop()
			inst.AnimState:PlayAnimation("atk_breath_loop")
			inst.Transform:SetEightFaced()
			inst.sg.statemem.targets = data and data.targets or {}
			inst.sg.statemem.angle = -45
            inst.sg.statemem.flame_num = data and data.num or 3
			if not inst.SoundEmitter:PlayingSound("loop") then
				inst.SoundEmitter:PlaySound("rifts3/mutated_varg/blast_lp", "loop")
			end
		end,

		onupdate = function(inst)
			DoFlamethrowerAOE(inst, inst.sg.statemem.angle, inst.sg.statemem.targets)
		end,

		timeline =
		{
			--FrameEvent(-1, function(inst) SpawnCloseEmberFX(inst, -45) end),
			--FrameEvent(-4, function(inst) SpawnBreathFX(inst, -45, 5, inst.sg.statemem.targets) end),
			--FrameEvent(-1, function(inst) SpawnBreathFX(inst, -45, 7, inst.sg.statemem.targets) end),
			FrameEvent(3, function(inst) SpawnBreathFX(inst, -45, 9, inst.sg.statemem.targets) end),

			FrameEvent(2, function(inst) inst.sg.statemem.angle = -27 end),
			FrameEvent(3, function(inst) SpawnCloseEmberFX(inst, -27) end),
			FrameEvent(0, function(inst) SpawnBreathFX(inst, -27, 5, inst.sg.statemem.targets) end),
			FrameEvent(3, function(inst) SpawnBreathFX(inst, -27, 7, inst.sg.statemem.targets) end),
			FrameEvent(7, function(inst) SpawnBreathFX(inst, -27, 9, inst.sg.statemem.targets) end),

			FrameEvent(4, function(inst) inst.sg.statemem.angle = -9 end),
			FrameEvent(5, function(inst) SpawnCloseEmberFX(inst, -9) end),
			FrameEvent(2, function(inst) SpawnBreathFX(inst, -9, 5, inst.sg.statemem.targets) end),
			FrameEvent(5, function(inst) SpawnBreathFX(inst, -9, 7, inst.sg.statemem.targets) end),
			FrameEvent(9, function(inst) SpawnBreathFX(inst, -9, 9, inst.sg.statemem.targets) end),

			FrameEvent(6, function(inst) inst.sg.statemem.angle = 9 end),
			FrameEvent(7, function(inst) SpawnCloseEmberFX(inst, 9) end),
			FrameEvent(4, function(inst) SpawnBreathFX(inst, 9, 5, inst.sg.statemem.targets) end),
			FrameEvent(7, function(inst) SpawnBreathFX(inst, 9, 7, inst.sg.statemem.targets) end),
			FrameEvent(11, function(inst) SpawnBreathFX(inst, 9, 9, inst.sg.statemem.targets) end),

			FrameEvent(9, function(inst) inst.sg.statemem.angle = 27 end),
			FrameEvent(10, function(inst) SpawnCloseEmberFX(inst, 27) end),
			FrameEvent(7, function(inst) SpawnBreathFX(inst, 27, 5, inst.sg.statemem.targets) end),
			FrameEvent(10, function(inst) SpawnBreathFX(inst, 27, 7, inst.sg.statemem.targets) end),
			FrameEvent(14, function(inst) SpawnBreathFX(inst, 27, 9, inst.sg.statemem.targets) end),

			FrameEvent(12, function(inst) inst.sg.statemem.angle = 45 end),
			FrameEvent(13, function(inst) SpawnCloseEmberFX(inst, 45) end),
			FrameEvent(10, function(inst) SpawnBreathFX(inst, 45, 5, inst.sg.statemem.targets) end),
			FrameEvent(13, function(inst) SpawnBreathFX(inst, 45, 7, inst.sg.statemem.targets) end),
			FrameEvent(17, function(inst) SpawnBreathFX(inst, 45, 9, inst.sg.statemem.targets) end),

			FrameEvent(15, function(inst) inst.sg.statemem.angle = 27 end),
			FrameEvent(16, function(inst) SpawnCloseEmberFX(inst, 27) end),
			FrameEvent(13, function(inst) SpawnBreathFX(inst, 27, 5, inst.sg.statemem.targets) end),
			FrameEvent(16, function(inst) SpawnBreathFX(inst, 27, 7, inst.sg.statemem.targets) end),
			FrameEvent(20, function(inst) SpawnBreathFX(inst, 27, 9, inst.sg.statemem.targets) end),

			FrameEvent(18, function(inst) inst.sg.statemem.angle = 9 end),
			FrameEvent(19, function(inst) SpawnCloseEmberFX(inst, 9) end),
			FrameEvent(16, function(inst) SpawnBreathFX(inst, 9, 5, inst.sg.statemem.targets) end),
			FrameEvent(19, function(inst) SpawnBreathFX(inst, 9, 7, inst.sg.statemem.targets) end),
			FrameEvent(23, function(inst) SpawnBreathFX(inst, 9, 9, inst.sg.statemem.targets) end),

			FrameEvent(21, function(inst) inst.sg.statemem.angle = -9 end),
			FrameEvent(22, function(inst) SpawnCloseEmberFX(inst, -9) end),
			FrameEvent(19, function(inst) SpawnBreathFX(inst, -9, 5, inst.sg.statemem.targets) end),
			FrameEvent(22, function(inst) SpawnBreathFX(inst, -9, 7, inst.sg.statemem.targets) end),
			FrameEvent(26, function(inst) SpawnBreathFX(inst, -9, 9, inst.sg.statemem.targets) end),

			FrameEvent(24, function(inst) inst.sg.statemem.angle = -27 end),
			FrameEvent(25, function(inst) SpawnCloseEmberFX(inst, -27) end),
			FrameEvent(22, function(inst) SpawnBreathFX(inst, -27, 5, inst.sg.statemem.targets) end),
			FrameEvent(25, function(inst) SpawnBreathFX(inst, -27, 7, inst.sg.statemem.targets) end),
			--FrameEvent(29, function(inst) SpawnBreathFX(inst, -27, 9, inst.sg.statemem.targets) end),

			FrameEvent(27, function(inst) inst.sg.statemem.angle = -45 end),
			FrameEvent(28, function(inst) SpawnCloseEmberFX(inst, -45) end),
			FrameEvent(25, function(inst) SpawnBreathFX(inst, -45, 5, inst.sg.statemem.targets) end),
			FrameEvent(28, function(inst) SpawnBreathFX(inst, -45, 7, inst.sg.statemem.targets) end),
			--FrameEvent(32, function(inst) SpawnBreathFX(inst, -45, 9, inst.sg.statemem.targets) end),

			--frame 29 and beyond goes to "flamethrower_pst"
		},

		events =
		{
			EventHandler("animover", function(inst)
				if inst.AnimState:AnimDone() then
					inst.sg.statemem.attacking = true
                    local data = {
                        targets = inst.sg.statemem.targets,
                        num = inst.sg.statemem.flame_num - 1
                    }
					if inst.sg.statemem.flame_num>0 then
						SpawnBreathFX(inst, -27, 9, inst.sg.statemem.targets)
						inst.sg:GoToState("mutatedwarg_flamethrower_loop", data)
					else
						inst.sg:GoToState("mutatedwarg_flamethrower_pst", inst.sg.statemem.targets)
					end
				end
			end),
		},

		onexit = function(inst)
			if not inst.sg.statemem.attacking then
				inst.Transform:SetSixFaced()
				inst.SoundEmitter:KillSound("loop")
			end
		end,
	})

AddStategraphState("wilson",State{
		name = "mutatedwarg_flamethrower_pst",
		tags = { "busy","epic","epic_skill","nopredict", "nomorph" },

		onenter = function(inst, targets)
			inst.components.locomotor:Stop()
			inst.AnimState:PlayAnimation("atk_breath_pst")
			inst.Transform:SetEightFaced()
			inst.SoundEmitter:PlaySound("rifts3/mutated_varg/blast_pst")
			inst.sg.statemem.targets = targets or {}
		end,

		timeline =
		{
			FrameEvent(0, function(inst) SpawnBreathFX(inst, -27, 9, inst.sg.statemem.targets) end),

			FrameEvent(3, function(inst) SpawnBreathFX(inst, -45, 9, inst.sg.statemem.targets) end),

			FrameEvent(4, function(inst)
				inst.sg:AddStateTag("caninterrupt")
			end),
			FrameEvent(6, function(inst) inst.SoundEmitter:KillSound("loop") end),
			FrameEvent(13, function(inst)
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
			inst.Transform:SetSixFaced()
			inst.SoundEmitter:KillSound("loop")
		end,
	})

AddStategraphState("wilson",State{
		name = "mutatedbearger_butt_pre",
		tags = { "epic","epic_skill","busy" },

		onenter = function(inst)
			inst.components.locomotor:Stop()
            inst:RemoveTag("mutatedbearger_butt_skill")
            local target = nil
            local buffaction = inst:GetBufferedAction()
            if buffaction then
				if buffaction.pos then
					inst._facepoint_x,inst._facepoint_y,inst._facepoint_z = buffaction:GetActionPoint():Get()
                elseif buffaction.target and buffaction.target:IsValid() then
                    local x, y, z = buffaction.target.Transform:GetWorldPosition()
                    inst._facepoint_x, inst._facepoint_y, inst._facepoint_z = x, y, z
                    target = buffaction.target
                    inst.sg.statemem.target = target
                end
                inst.sg.statemem.targetpos = buffaction:GetActionPoint()
			end
			local left
            local x1, y1, z1 = inst._facepoint_x,inst._facepoint_y,inst._facepoint_z
            if inst.sg.statemem.targetpos then
                x1, y1, z1 = inst.sg.statemem.targetpos:Get()
            else
                inst.sg.statemem.targetpos = Vector3(inst._facepoint_x,inst._facepoint_y,inst._facepoint_z)
            end

            local rot = inst.Transform:GetRotation()
            local facing_diff = ReduceAngle(inst:GetAngleToPoint(x1, y1, z1) - rot)
            if math.abs(facing_diff) < 90 then
                local px, py, pz = inst.Transform:GetWorldPosition()
                x1 = 2 * px - x1
                y1 = 2 * py - y1
                z1 = 2 * pz - z1
                inst._facepoint_x, inst._facepoint_y, inst._facepoint_z = x1, y1, z1
                inst.sg.statemem.targetpos = Vector3(x1, y1, z1)
            end

			local rot = inst.Transform:GetRotation()
			local rot1 = inst:GetAngleToPoint(x1, y1, z1) + 180
			local drot = ReduceAngle(rot1 - rot)
			if drot ~= 0 and math.abs(drot) < 90 then
				left = drot > 0
				inst.sg.statemem.left = left
			end

			if left == nil then
				left = math.random() < 0.5
			end
			inst.AnimState:PlayAnimation(left and "butt_pre_L" or "butt_pre_R")
            inst:PerformBufferedAction()
		end,

		timeline =
		{
			FrameEvent(0, function(inst) inst.SoundEmitter:PlaySound("dontstarve_DLC001/creatures/bearger/attack") end),
			FrameEvent(23, function(inst)
				local p = inst.sg.statemem.targetpos
				if p ~= nil then
					local rot2
					local target = inst.sg.statemem.target
                    local x1, y1, z1 = inst.sg.statemem.targetpos:Get()
					if target ~= nil and target:IsValid() then
						x1, y1, z1 = target.Transform:GetWorldPosition()
                    end
						local rot = inst.Transform:GetRotation()
						local rot1 = inst:GetAngleToPoint(x1, y1, z1) + 180
						local drot = ReduceAngle(rot1 - rot)
						local left = drot > 0
						if drot ~= 0 and math.abs(drot) < (left == inst.sg.statemem.left and 90 or 30) then
							rot2 = rot + drot / 2
							p.x, p.y, p.z = x1, y1, z1
						end
					if rot2 == nil then
						rot2 = inst:GetAngleToPoint(p) + 180
					end
					inst.Transform:SetRotation(rot2)
				end
			end),
		},

		events =
		{
			EventHandler("animover", function(inst)
				if inst.AnimState:AnimDone() then
					local data = inst.sg.statemem.targetpos ~= nil and {
						targetpos = inst.sg.statemem.targetpos,
						target = inst.sg.statemem.target,
					} or nil
					inst.sg:GoToState("mutatedbearger_butt", data)
				end
			end),
		},
	})

AddStategraphState("wilson",State{
		name = "mutatedbearger_butt",
		tags = { "busy", "jumping", "nointerrupt" ,"epic","epic_skill","nopredict", "nomorph"},

		onenter = function(inst, data)
			inst.components.locomotor:Stop()
			inst.AnimState:PlayAnimation("butt")
			local dist
			if data ~= nil then
				if data.running then
					dist = 6
				else
					local x, y, z = inst.Transform:GetWorldPosition()

					local x1, y1, z1 = data.targetpos:Get()
                    if data.target ~= nil and data.target:IsValid() then
                        x1, y1, z1 = data.target.Transform:GetWorldPosition()
                    end
					local dx = x1 - x
					local dz = z1 - z
					if dx ~= 0 or dz ~= 0 then
						local rot = inst.Transform:GetRotation() * DEGREES
						local rot1 = math.atan2(-dz, dx) + PI
						local diff = DiffAngleRad(rot, rot1)
						if diff < PI / 4 then
							dist = math.sqrt(dx * dx + dz * dz)
							dist = dist * math.cos(diff)
						end
					end

					if dist == nil and data.targetpos ~= nil then
						local dx = data.targetpos.x - x
						local dz = data.targetpos.z - z
						if dx ~= 0 or dz ~= 0 then
							dist = math.sqrt(dx * dx + dz * dz)
						end
					end
				end
				inst.sg.statemem.original_target = data.target --remember for onmissother event
			end
			dist = math.clamp(dist or 3, 3, 6)
			inst.Physics:SetMotorVelOverride(-dist / inst.AnimState:GetCurrentAnimationLength(), 0, 0)
		end,

		timeline =
		{
			FrameEvent(8, function(inst)
				local pt = inst:GetPosition()
				local rot = inst.Transform:GetRotation() * DEGREES
				local dist = -1
				pt.x = pt.x + dist * math.cos(rot)
				pt.y = 0
				pt.z = pt.z - dist * math.sin(rot)

				inst.sg.statemem.targets = {}
				inst.components.groundpounder:GroundPound(pt, inst.sg.statemem.targets)
				inst.SoundEmitter:PlaySound("rifts3/mutated_bearger/buttslam")
			end),
			FrameEvent(9, function(inst)
				local x, y, z = inst.Transform:GetWorldPosition()
				local rot = inst.Transform:GetRotation() * DEGREES
				local dist = -1
				x = x + dist * math.cos(rot)
				z = z - dist * math.sin(rot)

				--extra "true" to knockback existing targets from groundpound
				DoAOEAttack(inst, dist, 4, 1.2, 1.5, nil, inst.sg.statemem.targets, true)

				local sinkhole = SpawnPrefab("bearger_sinkhole")
				sinkhole.Transform:SetPosition(x, 0, z)
				sinkhole:PushEvent("docollapse")

				ShakeAllCameras(CAMERASHAKE.VERTICAL, .7, .025, 1.25, inst, 40)
			end),
		},

		events =
		{
			EventHandler("animover", function(inst)
				if inst.AnimState:AnimDone() then
					inst.sg.statemem.butt = true
					inst.sg:GoToState("mutatedbearger_butt_pst", {
						target = inst.sg.statemem.original_target,
						targets = inst.sg.statemem.targets,
					})
				end
			end),
		},

		onexit = function(inst)
			if not inst.sg.statemem.butt then
				inst.Physics:ClearMotorVelOverride()
				inst.Physics:Stop()
			end
		end,
	})

AddStategraphState("wilson",State{
		name = "mutatedbearger_butt_pst",
		tags = { "busy", "jumping", "noelectrocute","epic","epic_skill","nopredict", "nomorph" },

		onenter = function(inst, data)
			inst.components.locomotor:Stop()
			inst.AnimState:PlayAnimation("butt_pst")
            inst.AnimState:PushAnimation("to_bi",false)
			if data ~= nil and data.targets ~= nil then
				DoAOEAttack(inst, -1, 4, 1.2, 1.5, nil, data.targets)
				if next(data.targets) == nil then
					inst:PushEvent("onmissother", { target = data.target }) --for ChaseAndAttack
				end
			end
		end,

		timeline =
		{
			FrameEvent(0, function(inst) inst.Physics:SetMotorVelOverride(-4, 0, 0) end),
			FrameEvent(1, function(inst) inst.Physics:SetMotorVelOverride(-2, 0, 0) end),
			FrameEvent(2, function(inst) inst.Physics:SetMotorVelOverride(-1, 0, 0) end),
			FrameEvent(3, function(inst) inst.Physics:SetMotorVelOverride(-0.5, 0, 0) end),
			FrameEvent(4, function(inst)
				inst.Physics:ClearMotorVelOverride()
				inst.Physics:Stop()
				inst.sg:RemoveStateTag("jumping")
			end),
			FrameEvent(41, function(inst)
				inst.sg:RemoveStateTag("noelectrocute")
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
		end,
	})

AddStategraphState("wilson",State{
		name = "mutateddeerclops_icelance",
		tags = { "epic","epic_skill","busy" },

		onenter = function(inst)
			inst.components.locomotor:Stop()
			inst.Transform:SetEightFaced()
			if not inst.replica.wereepic._mutated_ice:value() then
				inst.AnimState:PlayAnimation("throw")
			else
				inst.AnimState:PlayAnimation("throw_2")
			end

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
                    inst.sg.statemem.original_target = buffaction.target
                end
                inst.sg.statemem.targetpos = Vector3(inst._facepoint_x, inst._facepoint_y, inst._facepoint_z)
			end
            inst:PerformBufferedAction()
		end,

		onupdate = function(inst)
			local target = inst.sg.statemem.target
			local p = inst.sg.statemem.targetpos
            if target and target:IsValid() then
                p.x, p.y, p.z = target.Transform:GetWorldPosition()
            end
            local rot = inst.Transform:GetRotation()
			local rot1 = inst:GetAngleToPoint(p)
			local drot = ReduceAngle(rot1 - rot)
			if math.abs(drot) < 90 then
				rot1 = rot + math.clamp(drot / 2, -1, 1)
				inst.Transform:SetRotation(rot1)
			end
		end,

		timeline =
		{
			FrameEvent(8, function(inst) inst.SoundEmitter:PlaySound("rifts3/mutated_deerclops/ice_throw_f13") end),
			FrameEvent(30, function(inst)
				inst.sg.statemem.target = nil

				local range = TUNING.MUTATED_DEERCLOPS_ICELANCE_RANGE
				local p = inst.sg.statemem.targetpos
				local x, y, z = inst.Transform:GetWorldPosition()
				local rot = inst.Transform:GetRotation() * DEGREES
				local dist
				if p ~= nil then
					local dx = p.x - x
					local dz = p.z - z
					if dx ~= 0 or dz ~= 0 then
						local rot1 = math.atan2(-dz, dx)
						local diff = DiffAngleRad(rot, rot1)
						if diff * RADIANS < 90 then
							dist = math.sqrt(dx * dx + dz * dz) * math.cos(diff)
							dist = math.clamp(dist, range.min, range.max)
						else
							dist = range.min
						end
					else
						dist = range.min
					end
					p.y = 0
				else
					dist = (range.min + range.max) * 0.5
					p = Vector3(0, 0, 0)
					inst.sg.statemem.targetpos = p
				end
				p.x = x + math.cos(rot) * dist
				p.z = z - math.sin(rot) * dist

				inst.sg.statemem.ping = SpawnPrefab("deerclops_icelance_ping_fx")
				inst.sg.statemem.ping.Transform:SetPosition(p:Get())
			end),
			FrameEvent(34, function(inst)
				inst.components.burnable:Extinguish()
			end),
			FrameEvent(47, function(inst) inst.SoundEmitter:PlaySound("rifts3/mutated_deerclops/ice_throw_f47") end),
			FrameEvent(56, function(inst)
				DeerclopsFootstep(inst, false, true)
			end),
			FrameEvent(60, function(inst)
				inst.SoundEmitter:PlaySound("dontstarve/creatures/deerclops/attack")
				inst.sg.statemem.ping:KillFX()
				inst.sg.statemem.ping = nil

				local lance = SpawnPrefab("deerclops_impact_circle_fx")
				lance.Transform:SetPosition(inst.sg.statemem.targetpos:Get())
				inst.sg.statemem.targets = {}
				inst.components.combat:SetDefaultDamage(TUNING.MUTATED_DEERCLOPS_ICELANCE_DAMAGE)
				DoIceLanceAOE(inst, inst.sg.statemem.targetpos, inst.sg.statemem.targets)
			end),
			FrameEvent(61, function(inst)
				DoIceLanceAOE(inst, inst.sg.statemem.targetpos, inst.sg.statemem.targets)
			end),
			FrameEvent(62, function(inst)
				DoIceLanceAOE(inst, inst.sg.statemem.targetpos, inst.sg.statemem.targets)
				if next(inst.sg.statemem.targets) == nil then
					inst:PushEvent("onmissother", { target = inst.sg.statemem.original_target }) --for ChaseAndAttack
				end
			end),
		},

		events =
		{
			EventHandler("animover", function(inst)
				if inst.AnimState:AnimDone() then
                    if inst.replica.wereepic._mutated_ice:value() then
                        inst.sg:GoToState("mutateddeerclops_icegrow")
                    else
                        inst.sg:GoToState("epic_idle")
                    end
				end
			end),
		},

		onexit = function(inst)
			inst.Transform:SetFourFaced()
			if not inst.replica.wereepic._mutated_ice:value() then
				inst.AnimState:Hide("ice_0")
                inst.replica.wereepic._mutated_ice:set(true)
			elseif inst.replica.wereepic._mutated_ice:value() then
				inst.AnimState:Hide("ice_1")
			end
			if inst.sg.statemem.ping ~= nil then
				inst.sg.statemem.ping:KillFX()
			end
			inst.components.combat:SetDefaultDamage(TUNING.MUTATED_DEERCLOPS_DAMAGE)
		end,
	})

AddStategraphState("wilson",State{
		name = "mutateddeerclops_icegrow",
		tags = { "icegrow", "busy","epic","epic_skill","nopredict", "nomorph" },

		onenter = function(inst)
			inst.components.locomotor:Stop()
			inst.AnimState:PlayAnimation("ice_grow")

			inst.SoundEmitter:PlaySound("rifts3/mutated_deerclops/ice_crackling_LP", "loop")

            if inst.components.playercontroller then
                inst.components.playercontroller:RemotePausePrediction()
            end
		end,

		timeline =
		{
			FrameEvent(7, function(inst)
				DeerclopsFootstep(inst, false, true)
			end),
			FrameEvent(9, function(inst)
				inst.components.burnable:Extinguish()
				if inst.sg.mem.mutateddeerclops_circle == nil then
					inst.sg.mem.mutateddeerclops_circle = SpawnPrefab("deerclops_aura_circle_fx")
					local x, y, z = inst.Transform:GetWorldPosition()
					inst.sg.mem.mutateddeerclops_circle.Transform:SetPosition(x, 0, z)
					inst.sg.mem.mutateddeerclops_circle:GrowFX()
				end
			end),
			FrameEvent(5, function(inst) inst.SoundEmitter:PlaySound("dontstarve/creatures/deerclops/taunt_grrr") end),
			FrameEvent(6, function(inst)
				inst.SoundEmitter:PlaySound("rifts3/mutated_deerclops/ice_grow_4f_leadin")
			end),
			FrameEvent(9, function(inst)
				inst.SoundEmitter:PlaySound("rifts3/mutated_deerclops/ice_grow_4f_leadin")
			end),
			FrameEvent(13, function(inst)
				inst.SoundEmitter:KillSound("loop")
                inst.replica.wereepic._mutated_ice:set(false)
			end),
		},

		events =
		{
			EventHandler("animover", function(inst)
				if inst.AnimState:AnimDone() then
					inst.sg:GoToState("mutateddeerclops_icegrow_pst")
				end
			end),
		},

		onexit = function(inst)
			inst.AnimState:Show("ice_1")
			inst.AnimState:Show("ice_0")
			inst.SoundEmitter:KillSound("loop")
            inst.replica.wereepic._mutated_ice:set(false)
		end,
	})

AddStategraphState("wilson",State{
		name = "mutateddeerclops_icegrow_pst",
		tags = { "busy","epic","epic_skill","nopredict", "nomorph" },

		onenter = function(inst)
			inst.AnimState:PlayAnimation("ice_grow_pst")
		end,

		timeline =
		{
			FrameEvent(14, function(inst)
				inst.sg:GoToState("epic_idle")
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

AddStategraphPostInit("wilson", function(sg)
---actionhandlers
---ATTACK
    local old_attack_handler_deststate = sg.actionhandlers[ACTIONS.ATTACK].deststate
    sg.actionhandlers[ACTIONS.ATTACK].deststate = function(inst, action)
        if inst:HasTag("epic") then
            inst.sg.mem.localchainattack = not action.forced or nil
			local playercontroller = inst.components.playercontroller
			local attack_tag =
				playercontroller ~= nil and
				playercontroller.remote_authority and
				playercontroller.remote_predicting and
				"abouttoattack" or
				"attack"
			if not (inst.sg:HasStateTag(attack_tag) and action.target == inst.sg.statemem.attacktarget or inst.components.health:IsDead()) then
                return "epic_attack"
            end
        else
            return old_attack_handler_deststate(inst, action)
        end
    end

---events
---blocked
    local old_blocked_fn = sg.events.blocked.fn
    sg.events.blocked.fn = function(inst, data)
        if inst:HasTag("epic") then
            if inst.components.health and not inst.components.health:IsDead() and inst.sg:HasStateTag("epic")
            and not inst.sg:HasAnyStateTag("busy","epic_skill","attack")
            then
                inst.sg:GoToState("epic_hit")
            else
                return
            end
        else
            return old_blocked_fn(inst, data)
        end
    end

---attacked
    local old_attacked_fn = sg.events.attacked.fn
    sg.events.attacked.fn = function(inst, data)
        if inst:HasTag("epic") then
            if inst.components.health and not inst.components.health:IsDead() then
                if inst:HasTag("stalker_atrium_shield") then
                    local shieldtype = PickShield(inst)
                    if shieldtype ~= nil then
                        local fx = SpawnPrefab("stalker_shield"..tostring(shieldtype))
                        fx.entity:SetParent(inst.entity)
                        if shieldtype < 3 and math.random() < .5 then
                            fx.AnimState:SetScale(-2.36, 2.36, 2.36)
                        end
                    end
                elseif inst.sg:HasStateTag("shield") then
                    inst.sg:GoToState("phase1_shield_hit")
                elseif data.weapon ~= nil and data.weapon:HasTag("tranquilizer") and inst.sg:HasAnyStateTag("bedroll", "knockout") then
                    return
                elseif inst.sg:HasStateTag("hitwakeup") then
                    inst.sg:GoToState("epic_hit")
                elseif inst.sg:HasStateTag("sleeping") then
                    inst.sg:GoToState("epic_wakeup")
                elseif inst.sg:HasStateTag("nointerrupt") then
                    if data.stimuli == "electric" and not inst.components.inventory:IsInsulated() and inst.sg:HasStateTag("canelectrocute") then
                        inst.sg:GoToState("epic_electrocute", { attackdata = data })
                    else
                        inst.SoundEmitter:PlaySound("dontstarve/wilson/hit")
                        DoHurtSound(inst)
                    end
                elseif data.stimuli == "electric" and inst.sg:HasStateTag("electrocute") and inst.sg:GetTimeInState() < 3 * FRAMES then
                    return
                elseif data.stimuli == "electric" and not (inst.components.inventory:IsInsulated() or inst.sg:HasStateTag("noelectrocute")) then
                    inst.sg:GoToState("epic_electrocute", { attackdata = data })
                elseif inst.sg:HasStateTag("electrocute") then
                    inst.SoundEmitter:PlaySound("dontstarve/wilson/hit")
                    DoHurtSound(inst)
                elseif not inst.sg:HasAnyStateTag("busy","epic_skill","attack")
                and inst.sg:HasStateTag("epic") then
                    local t = GetTime()
                    local stunlock =
                        data.stimuli ~= "stun" and
                        data.attacker ~= nil and
                        not (inst.sg:HasStateTag("idle") and inst.sg.timeinstate > 0) and
                        data.attacker.components.combat ~= nil and
                        data.attacker.components.combat.playerstunlock or
                        nil
                    if stunlock ~= nil and
                        t - (inst.sg.mem.laststuntime or 0) <
                        (   (stunlock == PLAYERSTUNLOCK.NEVER and math.huge) or
                            (stunlock == PLAYERSTUNLOCK.RARELY and TUNING.STUNLOCK_TIMES.RARELY) or
                            (stunlock == PLAYERSTUNLOCK.SOMETIMES and TUNING.STUNLOCK_TIMES.SOMETIMES) or
                            (stunlock == PLAYERSTUNLOCK.OFTEN and TUNING.STUNLOCK_TIMES.OFTEN) or
                            0
                        ) then
                        -- don't go to full hit state, just play sounds
                        inst.SoundEmitter:PlaySound("dontstarve/wilson/hit")
                        DoHurtSound(inst)
                    else
                        inst.sg:GoToState("epic_hit")
                    end
                end
            else
                return
            end
        elseif inst.sg:HasStateTag("epic_transform") then
            inst.SoundEmitter:PlaySound("dontstarve/wilson/hit")
            DoHurtSound(inst)
        else
            return old_attacked_fn(inst, data)
        end
    end
---freeze
    local old_freeze_fn = sg.events.freeze.fn
    sg.events.freeze.fn = function (inst)
        if inst:HasTag("epic") then
            if inst:HasTag("epic_immune_freeze") then
                return
            else
                if inst.components.health ~= nil and not inst.components.health:IsDead() then
                    inst.sg:GoToState("epic_frozen")
                end
            end
        else
            return old_freeze_fn(inst)
        end
    end
---knockedout
    local old_knockedout_fn = sg.events.knockedout.fn
    sg.events.knockedout.fn = function (inst)
        if inst:HasTag("epic") then
            if inst:HasTag("epic_immune_sleep") then
                return
            else
                if inst.sg:HasStateTag("knockout") then
                    inst.sg.statemem.cometo = nil
                elseif not (inst.sg:HasStateTag("sleeping") or inst.sg:HasStateTag("bedroll") or inst.sg:HasStateTag("tent") or inst.sg:HasStateTag("drowning") or inst.sg:HasStateTag("falling")) then
                    if inst.sg:HasStateTag("jumping") then
                        inst.sg.statemem.queued_post_land_state = "epic_knockout"
                    else
                        inst.sg:GoToState("epic_knockout")
                    end
                end
            end
        else
            return old_knockedout_fn(inst)
        end
    end
---yawn
    local old_yawn_fn = sg.events.yawn.fn
    sg.events.yawn.fn = function (inst,data)
        if inst:HasTag("epic") then
            if inst:HasTag("epic_immune_sleep") then
                return
            else
                if not (inst.components.health:IsDead() or
                        inst.sg:HasStateTag("sleeping") or
                        (inst.components.freezable ~= nil and inst.components.freezable:IsFrozen()) or
                        (inst.components.pinnable ~= nil and inst.components.pinnable:IsStuck())) then
                    inst.sg:GoToState("epic_knockout",{source = "yawn"})
                end
            end
        else
            return old_yawn_fn(inst,data)
        end
    end
---death
    local old_death_fn = sg.events.death.fn
    sg.events.death.fn = function (inst,data)
        if inst:HasTag("epic") then
            local mode = inst.components.wereepic and inst.components.wereepic:GetEpicMode()
            if mode=="stalker_atrium" then
                inst.sg:GoToState("stalker_atrium_death_pre",data)
            else
                inst.sg:GoToState("epic_death",data)
            end
        else
            return old_death_fn(inst,data)
        end
    end
---electrocute
    local old_electrocute_fn = sg.events.electrocute.fn
    sg.events.electrocute.fn = function (inst,data)
        if inst:HasTag("epic") then
            if inst:HasTag("epic_immune_electrocute") then
                return
            else
                return onelectrocute(inst,data)
            end
        else
            return old_electrocute_fn(inst,data)
        end
    end
---souloverload
    local old_souloverload_fn = sg.events.souloverload.fn
    sg.events.souloverload.fn = function (inst)
        if inst:HasTag("epic") then
            return
        else
            return old_souloverload_fn(inst)
        end
    end
---snared
    local old_snared_fn = sg.events.snared.fn
    sg.events.snared.fn = function (inst)
        if inst:HasTag("epic") then
            return
        else
            return old_snared_fn(inst)
        end
    end
----startled
    local old_startled_fn = sg.events.startled.fn
    sg.events.startled.fn = function (inst)
        if inst:HasTag("epic") then
            return
        else
            return old_startled_fn(inst)
        end
    end
---spooked
    local old_spooked_fn = sg.events.spooked.fn
    sg.events.spooked.fn = function (inst)
        if inst:HasTag("epic") then
            return
        else
            return old_spooked_fn(inst)
        end
    end
---repelled
    local old_repelled_fn = sg.events.repelled.fn
    sg.events.repelled.fn = function (inst,data)
        if inst:HasTag("epic") then
            return
        else
            return old_repelled_fn(inst,data)
        end
    end
---knockback
    local old_knockback_fn = sg.events.knockback.fn
    sg.events.knockback.fn = function (inst,data)
        if inst:HasTag("epic") then
            return
        else
            return old_knockback_fn(inst,data)
        end
    end
---feetslipped
    local old_feetslipped_fn = sg.events.feetslipped.fn
    sg.events.feetslipped.fn = function (inst)
        if inst:HasTag("epic") then
            return
        else
            return old_feetslipped_fn(inst)
        end
    end
---bucked
    local old_bucked_fn = sg.events.bucked.fn
    sg.events.bucked.fn = function (inst,data)
        if inst:HasTag("epic") then
            return
        else
            return old_bucked_fn(inst,data)
        end
    end
---pinned
    local old_pinned_fn = sg.events.pinned.fn
    sg.events.pinned.fn = function (inst,data)
        if inst:HasTag("epic") then
            return
        else
            return old_pinned_fn(inst,data)
        end
    end
---suspended
    local old_suspended_fn = sg.events.suspended.fn
    sg.events.suspended.fn = function (inst,attacker)
        if inst:HasTag("epic") then
            return
        else
            return old_suspended_fn(inst,attacker)
        end
    end
---devoured
    local old_devoured_fn = sg.events.devoured.fn
    sg.events.devoured.fn = function (inst,data)
        if inst:HasTag("epic") then
            return
        else
            return old_devoured_fn(inst,data)
        end
    end
---mindcontrolled
    local old_mindcontrolled_fn = sg.events.mindcontrolled.fn
    sg.events.mindcontrolled.fn = function (inst)
        if inst:HasTag("epic") then
            return
        else
            return old_mindcontrolled_fn(inst)
        end
    end
---onsink
    local old_onsink_fn = sg.events.onsink.fn
    sg.events.onsink.fn = function (inst,data)
        if inst:HasTag("epic") then
            return
        else
            return old_onsink_fn(inst,data)
        end
    end
---onfallinvoid
    local old_onfallinvoid_fn = sg.events.onfallinvoid.fn
    sg.events.onfallinvoid.fn = function (inst,data)
        if inst:HasTag("epic") then
            return
        else
            return old_onfallinvoid_fn(inst,data)
        end
    end
---powerup
    local old_powerup_fn = sg.events.powerup.fn
    sg.events.powerup.fn = function (inst)
        if inst:HasTag("epic") then
            return
        else
            return old_powerup_fn(inst)
        end
    end
---powerdown
    local old_powerdown_fn = sg.events.powerdown.fn
    sg.events.powerdown.fn = function (inst)
        if inst:HasTag("epic") then
            return
        else
            return old_powerdown_fn(inst)
        end
    end
---wx78_spark
    local old_wx78_spark_fn = sg.events.wx78_spark.fn
    sg.events.wx78_spark.fn = function (inst)
        if inst:HasTag("epic") then
            return
        else
            return old_wx78_spark_fn(inst)
        end
    end
---becomeyounger_wanda
    local old_becomeyounger_wanda_fn = sg.events.becomeyounger_wanda.fn
    sg.events.becomeyounger_wanda.fn = function (inst)
        if inst:HasTag("epic") then
            return
        else
            return old_becomeyounger_wanda_fn(inst)
        end
    end
---becomeolder_wanda
    local old_becomeolder_wanda_fn = sg.events.becomeolder_wanda.fn
    sg.events.becomeolder_wanda.fn = function (inst)
        if inst:HasTag("epic") then
            return
        else
            return old_becomeolder_wanda_fn(inst)
        end
    end
---powerup_wurt
    local old_powerup_wurt_fn = sg.events.powerup_wurt.fn
    sg.events.powerup_wurt.fn = function (inst)
        if inst:HasTag("epic") then
            return
        else
            return old_powerup_wurt_fn(inst)
        end
    end
---powerdown_wurt
    local old_powerdown_wurt_fn = sg.events.powerdown_wurt.fn
    sg.events.powerdown_wurt.fn = function (inst)
        if inst:HasTag("epic") then
            return
        else
            return old_powerdown_wurt_fn(inst)
        end
    end
---emote
 local old_emote_fn = sg.events.emote.fn
 sg.events.emote.fn = function (inst,data)
    if inst:HasTag("epic") then
        return
    else
        return old_emote_fn(inst,data)
    end
 end
---monkeycursehit
local old_monkeycursehit_fn = sg.events.monkeycursehit.fn
sg.events.monkeycursehit.fn = function (inst,data)
    if inst:HasTag("epic") then
        return
    else
        return old_monkeycursehit_fn(inst,data)
    end
end

---locomote
    local old_locomote_fn = sg.events.locomote.fn
    sg.events.locomote.fn = function(inst, data)
        if inst.sg:HasAnyStateTag("busy", "overridelocomote") then
            return
        end
        local is_moving = inst.sg:HasStateTag("moving")
        local should_move = inst.components.locomotor:WantsToMoveForward()

        if is_moving and not should_move and inst:HasTag("epic") then
            inst.sg:GoToState("epic_walk_stop")
        elseif not is_moving and should_move and inst:HasTag("epic") then
			if data and data.dir then
				inst.components.locomotor:SetMoveDir(data.dir)
			end
            inst.sg:GoToState("epic_walk_start")
        else
            return old_locomote_fn(inst,data)
        end
    end

---state
---epic_death
    local epic_death_state = sg.states["epic_death"]
    local old_epic_death_fn = epic_death_state.events.animover.fn
    epic_death_state.events.animover.fn = function (inst)
        local data = inst.sg.statemem.epicdeathdata
        if inst.components.wereepic then
            inst.components.wereepic:OnBecameHuman()
        end
        if data then
            return old_death_fn(inst,data)
        else
            if inst.sg.statemem.epicmode~="stalker_atrium" then
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
end)