local sharkboi = EPIC_SHOWDOWN_TUNING.SHARKBOI
local vpg = EPIC_SHOWDOWN_TUNING.VAULT_PILLAR_GUARD
local klaus = EPIC_SHOWDOWN_TUNING.KLAUS
EPIC_SHOWDOWN_FNS =
{
    SHARKBOI = {

        DoImpactShake = function(self, inst)
            ShakeAllCameras(CAMERASHAKE.VERTICAL, 1, 0.02, 0.3, inst, 30)
        end,

        DoJumpOutShake = function(self, inst)
            ShakeAllCameras(CAMERASHAKE.FULL, 0.6, 0.02, 0.2, inst, 30)
        end,

        DoDiggingShake = function(self, inst)
            ShakeAllCameras(CAMERASHAKE.FULL, 0.6, 0.015, 0.15, inst, 30)
        end,

        _AOEAttack = function(self, inst, dig, dist, radius, arc, heavymult, mult, forcelanded, targets)
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
                    --min-x for testing points converted to local space
                    arcx = x + math.cos(arc / 2 * DEGREES) * radius
                end
            end
            for i, v in ipairs(TheSim:FindEntities(x, y, z, radius + sharkboi.AOE_RANGE_PADDING, sharkboi.AOE_TARGET_MUSTHAVE_TAGS, sharkboi.AOE_TARGET_CANT_TAGS)) do
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
                        --convert to local space x, and test against arcx
                        (arcx == nil or x + cos_theta * dx - sin_theta * dz > arcx) and
                        inst.components.combat:CanTarget(v)
                    then
                        if dig and v.components.locomotor == nil then
                            v.components.health:Kill()
                        else
                            if targets and mult and v.components.rider and v.components.rider.mount then
                                targets[v.components.rider.mount] = true
                            end
                            inst.components.combat:DoAttack(v)
                            if mult then
                                local strengthmult = (v.components.inventory and v.components.inventory:ArmorHasTag("heavyarmor") or v:HasTag("heavybody")) and heavymult or mult
                                v:PushEvent("knockback", { knocker = inst, radius = radius + dist, strengthmult = strengthmult, forcelanded = forcelanded })
                            end
                        end
                        if targets then
                            targets[v] = true
                        end
                    end
                end
            end
            inst.components.combat.ignorehitrange = false
        end,

        DoAOEWork = function(self, inst, dig, dist, radius, arc, targets)
            local actions = dig and sharkboi.COLLAPSIBLE_WORK_AND_DIG_ACTIONS or sharkboi.COLLAPSIBLE_WORK_ACTIONS
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
                    --min-x for testing points converted to local space
                    arcx = x + math.cos(arc / 2 * DEGREES) * radius
                end
            end
            for i, v in ipairs(TheSim:FindEntities(x, y, z, radius + sharkboi.WORK_RADIUS_PADDING, nil, sharkboi.NON_COLLAPSIBLE_TAGS, dig and sharkboi.COLLAPSIBLE_DIG_TAGS or sharkboi.COLLAPSIBLE_TAGS)) do
                if not (targets and targets[v]) and v:IsValid() and not v:IsInLimbo() then
                    local inrange = true
                    if arcx then
                        --convert to local space x, and test against arcx
                        local x1, y1, z1 = v.Transform:GetWorldPosition()
                        inrange = x + cos_theta * (x1 - x) - sin_theta * (z1 - z) > arcx
                    end
                    if inrange then
                        local isworkable = false
                        if v.components.workable then
                            local work_action = v.components.workable:GetWorkAction()
                            --V2C: nil action for NPC_workable (e.g. campfires)
                            --     allow digging spawners (e.g. rabbithole)
                            isworkable = (
                                (work_action == nil and v:HasTag("NPC_workable")) or
                                (v.components.workable:CanBeWorked() and work_action and actions[work_action.id])
                            )
                        end
                        if isworkable then
                            v.components.workable:Destroy(inst)
                            if dig and v:IsValid() and v:HasTag("stump") then
                                v:Remove()
                            end
                            if targets then
                                targets[v] = true
                            end
                        elseif dig and v.components.pickable and v.components.pickable:CanBePicked() and not v:HasTag("intense") then
                            v.components.pickable:Pick(TheWorld)
                            if targets then
                                targets[v] = true
                            end
                        end
                    end
                end
            end
        end,

        TossLaunch = function(self, inst, launcher, basespeed, startheight, startradius)
            local x0, y0, z0 = launcher.Transform:GetWorldPosition()
            local x1, y1, z1 = inst.Transform:GetWorldPosition()
            local dx, dz = x1 - x0, z1 - z0
            local dsq = dx * dx + dz * dz
            local angle
            if dsq > 0 then
                local dist = math.sqrt(dsq)
                angle = math.atan2(dz / dist, dx / dist) + (math.random() * 20 - 10) * DEGREES
            else
                angle = TWOPI * math.random()
            end
            local sina, cosa = math.sin(angle), math.cos(angle)
            local speed = basespeed + math.random()
            TryTeleportToLaunchPos(inst, x0 + startradius * cosa, startheight, z0 + startradius * sina)
            inst.Physics:SetVel(cosa * speed, speed * 5 + math.random() * 2, sina * speed)
        end,

        TossItems = function(self, inst, dist, radius)
            local x, y, z = inst.Transform:GetWorldPosition()
            if dist ~= 0 then
                local rot = inst.Transform:GetRotation() * DEGREES
                x = x + dist * math.cos(rot)
                z = z - dist * math.sin(rot)
            end
            for i, v in ipairs(TheSim:FindEntities(x, 0, z, radius + sharkboi.WORK_RADIUS_PADDING, sharkboi.TOSSITEM_MUST_TAGS, sharkboi.TOSSITEM_CANT_TAGS)) do
                if v.prefab == "ice" then
                    v:Remove()
                else
                    DeactivateInventoryItemBeforeLaunch(v)
                    if not v.components.inventoryitem.nobounce and v.Physics and v.Physics:IsActive() then
                        self:TossLaunch(v, inst, .8 + radius, radius * .4, radius + v:GetPhysicsRadius(0))
                    end
                end
            end
        end,

        DoAOEAttackAndWork = function(self, inst, dist, radius, heavymult, mult, forcelanded, targets)
            self:DoAOEWork(inst, false, dist, radius, nil, targets)
            self:_AOEAttack(inst, false, dist, radius, nil, heavymult, mult, forcelanded, targets)
        end,

        DoAOEAttackAndDig = function(self, inst, dist, radius, heavymult, mult, forcelanded, targets)
            self:DoAOEWork(inst, true, dist, radius, nil, targets)
            self:_AOEAttack(inst, true, dist, radius, nil, heavymult, mult, forcelanded, targets)
            self:TossItems(inst, dist, radius)
        end,

        DoArcAttack = function(self, inst, dist, radius, arc, heavymult, mult, forcelanded, targets)
            self:DoAOEWork(inst, false, dist, radius, arc, targets)
            self:_AOEAttack(inst, false, dist, radius, arc, heavymult, mult, forcelanded, targets)
        end,

        DoAOEAttack = function(self, inst, dist, radius, heavymult, mult, forcelanded, targets)
            self:DoAOEWork(inst, false, dist, radius, nil, targets)
            self:_AOEAttack(inst, false, dist, radius, nil, heavymult, mult, forcelanded, targets)
        end,

        DoRunWork = function(self, inst)
            self:DoAOEWork(inst, false, 1, 2)
        end,

        DoLandingWork = function(self, inst)
            self:DoAOEWork(inst, false, 0, 2)
        end,

        DoFinWork = function(self, inst)
            self:DoAOEWork(inst, true, 0.3, 0.8)
            self:TossItems(inst, 0.3, 0.8)
        end,

        SpawnSwipeFX = function(self, inst, offset, reverse)
            --spawn 3 frames early (with 3 leading blank frames) since anim is super short, and tends to get lost with network timing
            inst.sg.statemem.fx = SpawnPrefab("sharkboi_swipe_fx")
            inst.sg.statemem.fx.entity:SetParent(inst.entity)
            inst.sg.statemem.fx.Transform:SetPosition(offset, 0, 0)
            if reverse then
                inst.sg.statemem.fx:Reverse()
            end
        end,

        KillSwipeFX = function(self, inst)
            if inst.sg.statemem.fx ~= nil then
                if inst.sg.statemem.fx:IsValid() then
                    inst.sg.statemem.fx:Remove()
                end
                inst.sg.statemem.fx = nil
            end
        end,

        SpawnIcePlowFX = function(self, inst, sideoffset)
            local x, y, z = inst.Transform:GetWorldPosition()
            if sideoffset and sideoffset ~= 0 then
                local theta = (inst.Transform:GetRotation() + 90) * DEGREES
                x = x + math.cos(theta) * sideoffset
                z = z - math.sin(theta) * sideoffset
            end
            local fx = SpawnPrefab("sharkboi_iceplow_fx")
            fx.Transform:SetPosition(x, 0, z)
        end,

        SpawnIceImpactFX = function(self, inst, x, z)
            if x == nil then
                local y
                x, y, z = inst.Transform:GetWorldPosition()
            end
            local fx = SpawnPrefab("sharkboi_iceimpact_fx")
            fx.Transform:SetPosition(x, 0, z)
        end,

        SpawnIceTrailFX = function(self, inst)
            local x, y, z = inst.Transform:GetWorldPosition()
            local fx = SpawnPrefab("sharkboi_icetrail_fx")
            fx.Transform:SetPosition(x, 0, z)
            fx.Transform:SetRotation(inst.Transform:GetRotation())
        end,

        SpawnIceHoleFX = function(self, inst, x, z)
            if x == nil then
                local y
                x, y, z = inst.Transform:GetWorldPosition()
            end
            local fx = SpawnPrefab("sharkboi_icehole_fx")
            fx.Transform:SetPosition(x, 0, z)
            return fx
        end,

        IsSpawnPointClear = function(self, pt)
            return #TheSim:FindEntities(pt.x, 0, pt.z, 2, sharkboi.SPAWN_CHECK_TAGS, sharkboi.SPAWN_CHECK_NOTAGS) == 0
        end,

        DoFootstep = function(self, inst, volume)
            inst.sg.mem.sharkboi_lastfootstep = GetTime()
            PlayFootstep(inst, volume)
        end,
    },

    VAULT_PILLAR_GUARD = {

        Shake_Heavy = function(self, inst)     ShakeAllCameras(CAMERASHAKE.FULL, 0.8, 0.03, 0.35, inst, 40) end,
        Shake_Med = function(self, inst)       ShakeAllCameras(CAMERASHAKE.FULL, 0.8, 0.028, 0.3, inst, 40) end,
        Shake_Light = function(self, inst)     ShakeAllCameras(CAMERASHAKE.FULL, 0.6, 0.025, 0.25, inst, 30) end,
        Shake_Lift = function(self, inst)      ShakeAllCameras(CAMERASHAKE.FULL, 0.5, 0.035, 0.15, inst, 30) end,
        Shake_Activate = function(self, inst)  ShakeAllCameras(CAMERASHAKE.FULL, 0.6, 0.025, 0.15, inst, 30) end,
        Shake_Footstep = function(self, inst)  ShakeAllCameras(CAMERASHAKE.FULL, 0.5, 0.028, 0.3, inst, 40) end,
        Shake_Smallstep = function(self, inst) ShakeAllCameras(CAMERASHAKE.FULL, 0.5, 0.025, 0.22, inst, 40) end,
        Shake_Pound = function(self, inst)     ShakeAllCameras(CAMERASHAKE.VERTICAL, 0.8, 0.03, 0.6, inst, 40) end,

        _PlayFootstep = function(self, inst, volume)
            inst.SoundEmitter:PlaySound("rifts7/pillar_guard/footstep", nil, volume)
        end,

        DoFootstep = function(self, inst)
            self:_PlayFootstep(inst)
            self:Shake_Footstep(inst)
        end,

        DoSmallstep = function(self, inst)
            self:_PlayFootstep(inst)
            self:Shake_Smallstep(inst)
        end,

        SwitchToNoFaced = function(self, inst)
            if not inst.sg.mem.nofaced then
                inst.sg.mem.nofaced = true
                inst.Transform:SetNoFaced()
            end
        end,

        SwitchToFourFaced = function(self, inst)
            if inst.sg.mem.nofaced then
                inst.sg.mem.nofaced = nil
                inst.Transform:SetFourFaced()
            end
        end,

        SetShadowScale = function(self, inst, scale)
            inst.DynamicShadow:SetSize(6 * scale, 3.5 * math.min(1, scale))
        end,

        TriggerDebris = function(self, inst)
            inst:TriggerDebris(true)
        end,

        CancelDebris = function(self, inst)
            inst:TriggerDebris(false)
        end,

        ShouldCombo = function(self, inst, target)
            if not (target and target:IsValid()) then
                return false
            elseif target.components.health and target.components.health:IsDead() then
                return false
            end
            local rotation = inst.Transform:GetRotation()
            local angle = inst:GetAngleToPoint(target.Transform:GetWorldPosition())
            return DiffAngle(rotation, angle) < 75
        end,

        _AOEAttack = function(self, inst, dig, dist, radius, arc, heavymult, mult, forcelanded, targets, repeatdelay)
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
                    --min-x for testing points converted to local space
                    arcx = x + math.cos(arc / 2 * DEGREES) * radius
                end
            end
            local t = repeatdelay and GetTime()
            for i, v in ipairs(TheSim:FindEntities(x, y, z, radius + vpg.AOE_RANGE_PADDING, vpg.AOE_TARGET_MUSTHAVE_TAGS, vpg.AOE_TARGET_CANT_TAGS)) do
                if v ~= inst and
                    not (   targets and
                            targets[v] and
                            not (repeatdelay and type(targets[v]) == "number" and targets[v] < t)
                        ) and
                    v:IsValid() and not v:IsInLimbo() and
                    not (v.components.health and v.components.health:IsDead())
                then
                    local range = radius + v:GetPhysicsRadius(0)
                    local x1, y1, z1 = v.Transform:GetWorldPosition()
                    local dx = x1 - x
                    local dz = z1 - z
                    if dx * dx + dz * dz < range * range and
                        --convert to local space x, and test against arcx
                        (arcx == nil or x + cos_theta * dx - sin_theta * dz > arcx) and
                        inst.components.combat:CanTarget(v)
                    then
                        if targets then
                            targets[v] = repeatdelay == nil or t + repeatdelay
                        end
                        if dig and v.components.locomotor == nil then
                            v.components.health:Kill()
                        else
                            if targets and mult and v.components.rider and v.components.rider.mount then
                                targets[v.components.rider.mount] = targets[v]
                            end
                            inst.components.combat:DoAttack(v)
                            if mult then
                                local strengthmult = (v.components.inventory and v.components.inventory:ArmorHasTag("heavyarmor") or v:HasTag("heavybody")) and heavymult or mult
                                v:PushEvent("knockback", { knocker = inst, radius = radius + dist, strengthmult = strengthmult, forcelanded = forcelanded })
                            end
                        end
                    end
                end
            end
            inst.components.combat.ignorehitrange = false
        end,

        _AOEWork = function(self, inst, dig, dist, radius, arc, targets)
            local actions = dig and vpg.COLLAPSIBLE_WORK_AND_DIG_ACTIONS or vpg.COLLAPSIBLE_WORK_ACTIONS
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
                    --min-x for testing points converted to local space
                    arcx = x + math.cos(arc / 2 * DEGREES) * radius
                end
            end
            for i, v in ipairs(TheSim:FindEntities(x, y, z, radius + vpg.WORK_RADIUS_PADDING, nil, vpg.NON_COLLAPSIBLE_TAGS, dig and vpg.COLLAPSIBLE_DIG_TAGS or vpg.COLLAPSIBLE_TAGS)) do
                if not (targets and targets[v]) and v:IsValid() and not v:IsInLimbo() then
                    local inrange = true
                    if arcx then
                        --convert to local space x, and test against arcx
                        local x1, y1, z1 = v.Transform:GetWorldPosition()
                        inrange = x + cos_theta * (x1 - x) - sin_theta * (z1 - z) > arcx
                    end
                    if inrange then
                        local isworkable = false
                        if v.components.workable then
                            local work_action = v.components.workable:GetWorkAction()
                            --V2C: nil action for NPC_workable (e.g. campfires)
                            isworkable =
                                (   work_action == nil and v:HasTag("NPC_workable") ) or
                                (   v.components.workable:CanBeWorked() and
                                    work_action and
                                    actions[work_action.id] and
                                    not (dig and (v.components.spawner or v.components.childspawner))
                                )
                        end
                        if isworkable then
                            v.components.workable:Destroy(inst)
                            if dig and v:IsValid() and v:HasTag("stump") then
                                v:Remove()
                            end
                            if targets then
                                targets[v] = true
                            end
                        elseif dig and
                            v.components.pickable and
                            v.components.pickable:CanBePicked() and
                            not v:HasTag("intense") and
                            v.prefab ~= "vault_key_pedestal"
                        then
                            v.components.pickable:Pick(TheWorld)
                            if targets then
                                targets[v] = true
                            end
                        end
                    end
                end
            end
        end,

        TossLaunch = function(self, inst, launcher, basespeed, startheight, startradius)
            local x0, y0, z0 = launcher.Transform:GetWorldPosition()
            local x1, y1, z1 = inst.Transform:GetWorldPosition()
            local dx, dz = x1 - x0, z1 - z0
            local dsq = dx * dx + dz * dz
            local angle
            if dsq > 0 then
                local dist = math.sqrt(dsq)
                angle = math.atan2(dz / dist, dx / dist) + (math.random() * 20 - 10) * DEGREES
                startradius = math.max(dist, startradius)
            else
                angle = TWOPI * math.random()
            end
            local sina, cosa = math.sin(angle), math.cos(angle)
            local speed = basespeed + math.random()
            TryTeleportToLaunchPos(inst, x0 + startradius * cosa, startheight, z0 + startradius * sina)
            inst.Physics:SetVel(cosa * speed, speed * 2.5 + math.random(), sina * speed)
        end,

        TossItems = function(self, inst, dist, radius, targets)
            local x, y, z = inst.Transform:GetWorldPosition()
            if dist ~= 0 then
                local theta = inst.Transform:GetRotation() * DEGREES
                x = x + dist * math.cos(theta)
                z = z - dist * math.sin(theta)
            end
            for i, v in ipairs(TheSim:FindEntities(x, 0, z, radius + vpg.WORK_RADIUS_PADDING, vpg.TOSSITEM_MUST_TAGS, vpg.TOSSITEM_CANT_TAGS)) do
                if not (targets and targets[v]) then
                    DeactivateInventoryItemBeforeLaunch(v)
                    if not v.components.inventoryitem.nobounce and v.Physics and v.Physics:IsActive() then
                        self:TossLaunch(v, inst, radius * 0.4, 0.5, radius)
                    end
                    if targets then
                        targets[v] = true
                    end
                end
            end
        end,

        DoWalkCollide = function(self, inst)
            self:_AOEWork(inst, false, 0, 2.5)
        end,

        DoWalkStomp = function(self, inst)
            self:_AOEWork(inst, false, 0, 2.5)
            self:TossItems(inst, 0, 2.5)
        end,

        DoActivateStomp = function(self, inst, r)
            self:_AOEWork(inst, false, 0, r)
            self:TossItems(inst, 0, r)
        end,

        DoPunchAOE = function(self, inst)
            self:_AOEWork(inst, false, 1, 4, 180, inst.sg.statemem.targets)
            self:_AOEAttack(inst, false, 1, 4, 180, 1, 1.25, true, inst.sg.statemem.targets)
        end,

        DoSmashAOE = function(self, inst)
            self:_AOEWork(inst, true, 0, 4, nil, inst.sg.statemem.targets)
            self:_AOEAttack(inst, true, 0, 4, nil, nil, 1, nil, inst.sg.statemem.targets)
            self:TossItems(inst, 0, 4, inst.sg.statemem.tosstargets)
        end,

        DoSpinAOE = function(self, inst)
            self:_AOEWork(inst, false, 0, 5.6, nil, inst.sg.statemem.targets)
            self:_AOEAttack(inst, false, 0, 5.6, nil, 0.8, 1, true, inst.sg.statemem.targets, 0.5)
        end,

        SpawnSwipeFX = function(self, inst, reverse)
            --spawn 3 frames early (with 3 leading blank frames) since anim is super short, and tends to get lost with network timing
            inst.sg.statemem.fx = SpawnPrefab("vault_pillar_guard_swipe_fx")
            inst.sg.statemem.fx.entity:SetParent(inst.entity)
            inst.sg.statemem.fx.Transform:SetPosition(1, 0, 0)
            if reverse then
                inst.sg.statemem.fx:Reverse()
            end
        end,

        SpawnSmashFx = function(self, inst)
            --spawn 3 frames early (with 3 leading blank frames) since anim is super short, and tends to get lost with network timing
            inst.sg.statemem.fx = SpawnPrefab("vault_pillar_guard_smash_fx")
            inst.sg.statemem.fx.entity:SetParent(inst.entity)
        end,

        KillSwipeOrSmashFx = function(self, inst)
            if inst.sg.statemem.fx then
                if inst.sg.statemem.fx:IsValid() then
                    inst.sg.statemem.fx:Remove()
                end
                inst.sg.statemem.fx = nil
            end
        end,

        SetStunnedDamageMult = function(self, inst, stunned)
            if stunned then
                inst.components.combat.externaldamagetakenmultipliers:SetModifier(inst, TUNING.VAULT_PILLAR_GUARD_STAGGER_DAMAGE_MULT, "stunned")
            else
                inst.components.combat.externaldamagetakenmultipliers:RemoveModifier(inst, "stunned")
            end
        end,
    },

    KLAUS = {
        ShakeIfClose = function(self, inst)
            if inst:HasTag("klaus_angery") then
                ShakeAllCameras(CAMERASHAKE.FULL, .5, .02, .15, inst, 30)
            end
        end,

        DoRoarShake = function(self, inst)
            ShakeAllCameras(CAMERASHAKE.FULL, 1.5, .015, inst:HasTag("klaus_angery") and .3 or .15, inst, 30)
        end,

        DoRoarAlert = function(self, inst)
            inst.components.epicscare:Scare(klaus.ROAR_SCARE_TIME)
        end,

        DoChompShake = function(self, inst)
            ShakeAllCameras(CAMERASHAKE.FULL, 1.5, .015, inst:HasTag("klaus_angery") and .2 or .1, inst, 20)
        end,

        DoLanding = function(self, inst)
            inst.SoundEmitter:PlaySound("dontstarve/creatures/together/klaus/step")
            ShakeAllCameras(CAMERASHAKE.FULL, .5, .02, inst:HasTag("klaus_angery") and .2 or .1, inst, 30)
        end,

        DoSwipeSound = function(self, inst)
            inst.SoundEmitter:PlaySound("dontstarve/creatures/together/klaus/swipe", nil, not inst:HasTag("klaus_angery") and .7 or nil)
        end,

        DoScratchSound = function(self, inst)
            inst.SoundEmitter:PlaySound("dontstarve/creatures/together/klaus/scratch")
        end,

        DoBodyfall = function(self, inst)
            inst.SoundEmitter:PlaySound("dontstarve/creatures/together/klaus/bodyfall")
            self:ShakeIfClose(inst)
        end,

        DoFootstep = function(self, inst, volume)
            inst.SoundEmitter:PlaySound("dontstarve/creatures/together/klaus/step", nil, volume)
            self:ShakeIfClose(inst)
        end,

        DoFoleySounds = function(self, inst, volume)
            if inst:HasTag("klaus_chained") then
                inst.SoundEmitter:PlaySound("dontstarve/creatures/together/klaus/chain_foley", nil, volume)
            end
        end,

        FindChompTarget = function(self, inst)
            local chomp_range = inst:HasTag("klaus_angery") and klaus.CHOMP_RANGE_ANGRY or klaus.CHOMP_RANGE
            local chomp_min_range = inst:HasTag("klaus_angery") and klaus.CHOMP_MIN_RANGE_ANGRY or klaus.CHOMP_MIN_RANGE
            local chomp_range_sq = chomp_range * chomp_range
            local chomp_min_range_sq = chomp_min_range * chomp_min_range
            local fartargets, neartargets = {}, {}
            for i, v in ipairs(AllPlayers) do
                if not (v.components.health:IsDead() or v:HasTag("playerghost")) then
                    local distsq = inst:GetDistanceSqToInst(v)
                    if distsq < chomp_range_sq then
                        table.insert(distsq >= chomp_min_range_sq and fartargets or neartargets, v)
                    end
                end
            end
            return (#fartargets > 0 and fartargets[math.random(#fartargets)])
                or (#neartargets > 0 and neartargets[math.random(#neartargets)])
                or inst.components.combat.target
                or nil
        end,

        CalcChompSpeed = function(self, inst, target,x2,y2,z2)
            local x, y, z = x2,y2,z2
            if target then
                x, y, z = target.Transform:GetWorldPosition()
            end
            local distsq = inst:GetDistanceSqToPoint(x, y, z)
            if distsq > 0 then
                inst:ForceFacePoint(x, y, z)
                local dist = target and math.sqrt(distsq) - (inst:GetPhysicsRadius(0) + target:GetPhysicsRadius(0)) or math.sqrt(distsq) - inst:GetPhysicsRadius(0)
                if dist > 0 then
                    local range = inst:HasTag("klaus_angery") and klaus.CHOMP_RANGE_ANGRY or klaus.CHOMP_RANGE
                    return math.min(range, dist) / (klaus.CHOMP_SPEED_FRAMES * FRAMES)
                end
            end
            return 0
        end,

        SetChompHitRange = function(self, inst)
            inst.components.combat:SetRange(inst:HasTag("klaus_angery") and klaus.CHOMP_HIT_RANGE_ANGRY or klaus.CHOMP_HIT_RANGE)
        end,

        ResetAttackRange = function(self, inst)
            inst.components.combat:SetRange(
                inst:HasTag("klaus_angery") and klaus.ATTACK_RANGE_ANGRY or klaus.ATTACK_RANGE,
                inst:HasTag("klaus_angery") and klaus.HIT_RANGE_ANGRY or klaus.HIT_RANGE
            )
        end,

        DeerCanCast = function(self, deer)
            return not (deer.shouldavoidmagic or
                        deer.components.health.takingfiredamage or
                        deer.components.hauntable.panic or
                        deer.components.health:IsDead() or
                        deer.components.sleeper:IsAsleep() or
                        (deer.components.freezable ~= nil and deer.components.freezable:IsFrozen()) or
                        (deer.components.burnable ~= nil and deer.components.burnable:IsBurning()))
        end,

        PickCommandDeer = function(self, inst, highprio, lowprio)
            local deer, lowpriodeer
            for i, v in ipairs(inst.components.commander:GetAllSoldiers()) do
                if self:DeerCanCast(v) and v:FindCastTargets() ~= nil then
                    if v == highprio then
                        return v
                    elseif v == lowprio then
                        lowpriodeer = v
                    elseif highprio == nil then
                        return v
                    elseif deer == nil then
                        deer = v
                    end
                end
            end
            return deer or lowpriodeer
        end,

        UpdateDeerOffsets = function (self, inst)
            if inst.components.commander:GetNumSoldiers() > 0 then
                local deers = inst.components.commander:GetAllSoldiers()
                local theta = inst.Transform:GetRotation() * DEGREES
                local xoffs = inst:HasTag("klaus_angery") and 4.9 or 3.5 * math.sin(theta)
                local zoffs = inst:HasTag("klaus_angery") and 4.9 or 3.5 * math.cos(theta)
                local x, y, z = inst.Transform:GetWorldPosition()
                local x1, z1 = x - xoffs, z - zoffs
                x, z = x + xoffs, z + zoffs
                if #deers > 1 then
                    local score1 = deers[1]:GetDistanceSqToPoint(x, 0, z) + deers[2]:GetDistanceSqToPoint(x1, 0, z1)
                    local score2 = deers[2]:GetDistanceSqToPoint(x, 0, z) + deers[1]:GetDistanceSqToPoint(x1, 0, z1)
                    if score1 < score2 then
                        deers[1]:OnUpdateOffset(Vector3(xoffs, 0, zoffs))
                        deers[2]:OnUpdateOffset(Vector3(-xoffs, 0, -zoffs))
                    else
                        deers[2]:OnUpdateOffset(Vector3(xoffs, 0, zoffs))
                        deers[1]:OnUpdateOffset(Vector3(-xoffs, 0, -zoffs))
                    end
                elseif #deers > 0 then
                    deers[1]:OnUpdateOffset(deers[1]:GetDistanceSqToPoint(x, 0, z) < deers[1]:GetDistanceSqToPoint(x1, 0, z1) and Vector3(xoffs, 0, zoffs) or Vector3(-xoffs, 0, -zoffs))
                end
            end
        end,

        SetPhysicalScale = function (self, inst, scale)
            local xformscale = 1.2 * scale
            inst.Transform:SetScale(xformscale, xformscale, xformscale)
            inst.DynamicShadow:SetSize(3.5 * scale, 1.5 * scale)
            if scale > 1 then
                inst.Physics:SetMass(1000 * scale)
                inst.Physics:SetCapsule(1.2 * scale, 1)
            end
        end,

        SetStatScale = function (self,inst, scale)
            inst.components.combat:SetRange(TUNING.KLAUS_HIT_RANGE * scale)

            scale = scale * scale * scale
            local health_percent = inst.components.health:GetPercent()
            inst.components.health:SetMaxHealth(TUNING.KLAUS_HEALTH * scale * TUNING.EPIC_WORLD.HEALTH)
            inst.components.health:SetPercent(health_percent)
            inst.components.health.externalabsorbmodifiers:SetModifier(inst, scale > 1 and 1 - 1 / scale or 0, "klaus_angery")
            inst.components.combat:SetDefaultDamage(TUNING.KLAUS_DAMAGE * scale * TUNING.EPIC_WORLD.DAMAGE)
        end,

        Enrage = function (self, inst)
            inst.Physics:Stop()
            inst.Physics:Teleport(inst.Transform:GetWorldPosition())
            self:SetPhysicalScale(inst, TUNING.KLAUS_ENRAGE_SCALE)
            self:SetStatScale(inst, TUNING.KLAUS_ENRAGE_SCALE)
        end,

        SummonHelpers = function (self, inst)
            local x, y, z = inst.Transform:GetWorldPosition()
            local rangesq = TUNING.KLAUS_DEAGGRO_DIST * TUNING.KLAUS_DEAGGRO_DIST
            local num = 0
            for k, v in pairs(inst.klaus_recentattackers) do
                if k:IsValid() and not (k.components.health:IsDead() or k:HasTag("playerghost")) then
                    local distsq = k:GetDistanceSqToPoint(x, y, z)
                    if distsq < rangesq then
                        for i = 1, 2 do
                            local krampus = SpawnPrefab("krampus")
                            krampus.Transform:SetPosition(x + math.random(3,5),0,z + math.random(3,5))
                            krampus:AddComponent("follower")
                            krampus.components.follower:SetLeader(inst)
                            krampus.components.combat:SetTarget(k)
                            krampus.persists = false
                        end
                        num = num + 2
                        if num>=6 then
                            break
                        end
                    end
                end
            end
        end
    }
}

EpicShowDownState = {}

local EPIC = require("wereepic_skill")

EpicShowDownState.AddEpicAttackState = function (statename,onenterfns,onenter_timeout,onupdatefns,timelinefns,onexitfns)
    AddStategraphState("wilson",State{
		name = statename,
		tags = Epic_Showdown_Attack_Tags_Server,

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

            if onenterfns then
                onenterfns(inst,target)
            end

            inst.sg.statemem.target = target

            if target ~= nil then
                if target:IsValid() then
                    inst.sg.statemem.attacktarget = target
                    inst.sg.statemem.retarget = target
                end
            end

            inst.sg.statemem.isattack = buffaction ~= nil and buffaction.action == ACTIONS.ATTACK or nil

            if onenter_timeout then
                onenter_timeout(inst)
            elseif EPIC[mode].attack_timeout then
                inst.sg:SetTimeout(EPIC[mode].attack_timeout)
            else
                inst.sg:SetTimeout(inst.AnimState:GetCurrentAnimationLength()- 6 * FRAMES)
            end
		end,

		onupdate = onupdatefns,

		timeline = timelinefns,

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
            if onexitfns then
                onexitfns(inst)
            end
            inst.components.combat:SetTarget(nil)
            if inst.sg:HasStateTag("abouttoattack") then
                inst.components.combat:CancelAttack()
            end
        end,
	})
end

EpicShowDownState.AddEpicWalkStartState = function (statename,onenterfns,timelinefns,nextstate,onexitfns,client)
    AddStategraphState(client and "wilson_client" or "wilson",State{
        name = statename,
        tags = { "moving", "walking" , "canrotate", "autopredict" ,"epic"},

        onenter = function(inst)
            inst.components.locomotor:RunForward()
            if onenterfns then
                onenterfns(inst)
            else
                inst.AnimState:PlayAnimation("walk_pre")
            end
        end,

        onupdate = function(inst)
            inst.components.locomotor:RunForward()
        end,

        timeline = timelinefns,

        events =
        {
			EventHandler("animover", function(inst)
                if inst.AnimState:AnimDone() then
					inst.sg.statemem.walking = true
                    inst.sg:GoToState(nextstate)
                end
            end),
        },

        onexit = onexitfns
    })
end

EpicShowDownState.AddEpicWalkState = function (statename,onenterfns,timelinefns,onexitfns,client)
    AddStategraphState(client and "wilson_client" or "wilson",State{
        name = statename,
        tags = { "moving", "walking", "canrotate", "autopredict","epic"},

        onenter = function(inst)
            inst.components.locomotor:RunForward()
            if onenterfns then
                onenterfns(inst)
            else
                inst.AnimState:PlayAnimation("walk_loop")
            end
            inst.sg:SetTimeout(inst.AnimState:GetCurrentAnimationLength())
        end,

        onupdate = function(inst)
            inst.components.locomotor:RunForward()
        end,

        timeline = timelinefns,

        ontimeout = function(inst)
            inst.sg.statemem.walking = true
			inst.sg:GoToState(statename)
        end,

        onexit = onexitfns
    })
end

EpicShowDownState.AddEpicWalkStopState = function (statename,onenterfns,timelinefns,onexitfns,client)
    AddStategraphState(client and "wilson_client" or "wilson",State{
        name = statename,
        tags = { "canrotate", "idle", "autopredict","epic"},

        onenter = function(inst)
            inst.components.locomotor:Stop()
            if onenterfns then
                onenterfns(inst)
            else
                inst.AnimState:PlayAnimation("walk_pst")
            end
        end,

        timeline = timelinefns,

        events =
        {
            EventHandler("animover", function(inst)
                if inst.AnimState:AnimDone() then
                    inst.sg:GoToState("epic_idle")
                end
            end),
        },

        onexit = onexitfns
    })
end

EpicShowDownState.AddClientEpicAttackState = function (statename,onenterfns,onenter_timeout,onupdatefns,timelinefns,onexitfns)
    AddStategraphState("wilson_client",State{
		name = statename,
		tags = Epic_Showdown_Attack_Tags_Client,

		onenter = function(inst)
            local combat = inst.replica.combat
            if combat:InCooldown() then
                inst.sg:RemoveStateTag("abouttoattack")
                inst:ClearBufferedAction()
                inst.sg:GoToState("epic_idle", true)
                return
            end

            if inst.sg.laststate == inst.sg.currentstate then
                inst.sg.statemem.chained = true
            end
			combat:StartAttack()

			local mode = inst.replica.wereepic:GetEpicMode()
            local buffaction = inst:GetBufferedAction()
            local target = buffaction ~= nil and buffaction.target or nil
            inst.components.locomotor:Stop()

            if onenterfns then
                onenterfns(inst,target)
            end

            inst.sg.statemem.target = target

            inst.sg.statemem.isattack = buffaction ~= nil and buffaction.action == ACTIONS.ATTACK or nil

            inst:PerformPreviewBufferedAction()
            if target ~= nil then
                if target:IsValid() then
                    inst.sg.statemem.attacktarget = target
                    inst.sg.statemem.retarget = target
                end
            end

            if onenter_timeout then
                onenter_timeout(inst)
            elseif EPIC[mode].attack_timeout then
                inst.sg:SetTimeout(EPIC[mode].attack_timeout)
            else
                inst.sg:SetTimeout(inst.AnimState:GetCurrentAnimationLength()- 6 * FRAMES)
            end
		end,

		onupdate = onupdatefns,

		timeline = timelinefns,

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
            if onexitfns then
                onexitfns(inst)
            end
            if inst.sg:HasStateTag("abouttoattack") then
                inst.replica.combat:CancelAttack()
            end
        end,
	})
end

EpicShowDownState.AddEpicDeathState = function (statename,onenterfns,timelinefns,onexitfns,corpsemode,corpsefns)
    AddStategraphState("wilson",State{
        name = statename,
        tags = { "busy", "pausepredict", "nomorph" ,"epic","noattack","epic_death"},

        onenter = function(inst, data)
            inst.components.locomotor:Stop()
            inst.components.locomotor:Clear()
            inst:ClearBufferedAction()

            if inst.components.playercontroller then
                inst.components.playercontroller:RemotePausePrediction()
            end

            if onenterfns then
                onenterfns(inst,data)
            end

			inst.SoundEmitter:PlaySound(inst.deathsoundoverride)

            if data then
                inst.sg.statemem.epicdeathdata = data
            end

        end,

        timeline = timelinefns,

        events =
        {
            EventHandler("animover", function(inst)
                if inst.AnimState:AnimDone() then
                    local data = inst.sg.statemem.epicdeathdata
                    if data == nil then
                        if corpsemode then
                            local corpse = SpawnPrefab("epic_"..corpsemode.."_corpse")
                            local x,y,z = inst.Transform:GetWorldPosition()
                            corpse.Transform:SetPosition(x,y,z)
                            if corpsefns then
                                corpsefns(inst,corpse)
                            end
                            inst._epic_corpse = corpse
                        end
                        inst.components.wereepic:OnBecameHuman()
                        inst.sg:GoToState("epic_gravestone_rebirth")
                    elseif inst:HasTag("epic_nextmode") then
                        inst:RemoveTag("epic_nextmode")
                        inst.sg:GoToState("epic_transform_newmode",{newmode = data.epic_nextmode})
                    end
                end
            end),
        },

		onexit = onexitfns
    })

    AddStategraphPostInit("wilson", function(sg)
        local old_death_fn = sg.events.death.fn

        local epic_death_state = sg.states[statename]
        assert(epic_death_state ~= nil, "AddEpicDeathState: state "..statename.." not found")
        local old_epic_death_fn = epic_death_state.events.animover.fn
        epic_death_state.events.animover.fn = function (inst)
            if inst.AnimState:AnimDone() then
                local data = inst.sg.statemem.epicdeathdata
                if data and not inst:HasTag("epic_nextmode") then
                    inst.components.wereepic:OnBecameHuman()
                    inst.components.inventory:Close()
                    return old_death_fn(inst,data)
                else
                    return old_epic_death_fn(inst)
                end
            end
        end
    end)
end

EpicShowDownState.AddEpicBecameState = function (statename,onenterfns,timelinefns,onupdatefns,nextstate,onexitfns,nolightning)
    AddStategraphState("wilson",State{
        name = statename,
        tags = { "busy","epic","nopredict", "nomorph"},

        onenter = function(inst)
            inst.components.locomotor:Stop()

            if onenterfns then
                onenterfns(inst)
            end

            if not nolightning then
                local x, y, z = inst.Transform:GetWorldPosition()
                local lightning = SpawnPrefab("lightning")
                lightning.Transform:SetPosition(x,y,z)
            end
        end,

        timeline = timelinefns,

        onupdate = onupdatefns,

        events =
        {
            EventHandler("animover", function(inst)
                if inst.AnimState:AnimDone() then
                    inst.sg:GoToState(nextstate or "epic_idle")
                end
            end),
        },

        onexit = onexitfns
    })
end

EpicShowDownState.AddEpicTauntState = function (statename,onenterfns,timelinefns,onexitfns)
    AddStategraphState("wilson",State{
        name = statename,
        tags = { "epic_taunt","pausepredict", "epic","epic_skill","busy"},

        onenter = function(inst)
            inst.components.locomotor:Stop()
            if onenterfns then
                onenterfns(inst)
            end

            if inst.components.playercontroller then
                inst.components.playercontroller:RemotePausePrediction()
            end
        end,

        timeline = timelinefns,

        events =
        {
            EventHandler("animover", function(inst)
                if inst.AnimState:AnimDone() then
                    inst.sg:GoToState("epic_idle")
                end
            end),
        },

        onexit = onexitfns
    })
end

-- timelinefns里面不要忘记
-- TimeEvent(42 * FRAMES, function(inst)
--     inst.sg:RemoveStateTag("hitwakeup")
-- 	inst.sg:AddStateTag("sleeping")
-- end),
EpicShowDownState.AddEpicKnockoutState = function (statename,onenterfns,time,wakeupstate,timelinefns,onexitfns)
    AddStategraphState("wilson",State{
        name = statename,
        tags = { "busy", "knockout", "nopredict", "nomorph","epic" },

        onenter = function(inst,data)
            inst.components.locomotor:Stop()
            inst:ClearBufferedAction()
            if onenterfns then
                onenterfns(inst,data)
            else
                inst.AnimState:PlayAnimation("sleep_pre")
                inst.AnimState:PushAnimation("sleep_loop",true)
            end

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

            if data and data.source=="yawn" then
                inst.sg:SetTimeout(time and time*2 or TUNING.MANDRAKE_SLEEP_TIME*2)
            else
                inst.sg:SetTimeout(time or TUNING.MANDRAKE_SLEEP_TIME)
            end
            inst.sg:AddStateTag("hitwakeup")
        end,

        ontimeout = function(inst)
            inst.sg:GoToState(wakeupstate)
        end,

        timeline = timelinefns,

        events =
        {
            EventHandler("firedamage", function(inst)
                if inst.sg:HasStateTag("sleeping") and not inst.sg:HasStateTag("drowning") and not inst.sg:HasStateTag("falling") then
                    inst.sg.statemem.iswaking = true
                    inst.sg:GoToState(wakeupstate)
                else
                    inst.sg.statemem.cometo = true
                end
            end),
            EventHandler("cometo", function(inst)
                if inst.sg:HasStateTag("sleeping") and not inst.sg:HasStateTag("drowning") and not inst.sg:HasStateTag("falling") then
                    inst.sg.statemem.iswaking = true
                    inst.sg:GoToState(wakeupstate)
                else
                    inst.sg.statemem.cometo = true
                end
            end),
            EventHandler("animover", function(inst)
                if inst.AnimState:AnimDone() then
                    if inst.sg.statemem.cometo then
                        inst.sg.statemem.iswaking = true
                        inst.sg:GoToState(wakeupstate)
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
            if onexitfns then
                onexitfns(inst)
            end
        end,
    })
end

EpicShowDownState.AddEpicWakeupState = function (statename,onenterfns,timelinefns,onexitfns)
    AddStategraphState("wilson",State{
        name = statename,
        tags = { "busy", "waking", "nomorph", "nodangle","epic" },

        onenter = function(inst, data)
            if inst.components.playercontroller ~= nil then
                inst.components.playercontroller:Enable(false)
            end
            if onenterfns then
                onenterfns(inst,data)
            else
                inst.AnimState:PlayAnimation("sleep_pst")
            end
        end,

        timeline = timelinefns,

        events =
        {
            EventHandler("animover", function(inst)
                if inst.AnimState:AnimDone() then
                    inst.sg:GoToState("epic_idle")
                end
            end),
        },

        onexit = function(inst)
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
            if onexitfns then
                onexitfns(inst)
            end
        end,
    })
end

-- EpicShowDownState.AddEpicHitState = function ()

-- end

GLOBAL.EPIC_SHOWDOWN_FNS = EPIC_SHOWDOWN_FNS
GLOBAL.EpicShowDownState = EpicShowDownState