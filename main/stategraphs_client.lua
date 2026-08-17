local EPIC = require("wereepic_skill")

local epic_attack_tags_client = {"attack","notalking", "abouttoattack", "epic"}
if TUNING.EPIC_WORLD.ATTACK_LOCOMTE_INTERRUPT~=1 then
    table.insert(epic_attack_tags_client,"busy")
end

local function daywalker_DoFootstep(inst, volume)
	inst.sg.mem.lastfootstep = GetTime()
    if inst.replica.wereepic:GetEpicMode()=="daywalker" then
        inst.SoundEmitter:PlaySound("daywalker/action/step", nil, volume)
    elseif inst.replica.wereepic:GetEpicMode()=="daywalker2" then
        inst.SoundEmitter:PlaySound("qol1/daywalker_scrappy/step", nil, volume)
    end
end

local function phase2_play_foley(inst)
    inst.SoundEmitter:PlaySound("moonstorm/creatures/boss/alterguardian2/foley")
end

local function phase2_play_step(inst)
    inst.SoundEmitter:PlaySound("moonstorm/creatures/boss/alterguardian2/step")
end

local function DeerclopsFootstep(inst, moving, noice)
	inst.SoundEmitter:PlaySound("dontstarve/creatures/deerclops/step")
end

local function DoFootstep(inst)
	-- if inst:IsStandState("quad") then
	-- 	inst.SoundEmitter:PlaySound("dontstarve_DLC001/creatures/bearger/step_soft")
	-- else
		inst.SoundEmitter:PlaySound("dontstarve_DLC001/creatures/bearger/step_stomp")
	-- end
end

local function phase1_play_foley(inst)
    inst.SoundEmitter:PlaySound("moonstorm/creatures/boss/alterguardian1/foley")
end

local function phase1_play_step(inst)
    inst.SoundEmitter:PlaySound("moonstorm/creatures/boss/alterguardian1/step")
end

AddStategraphState("wilson_client",State{
		name = "epic_attack",
		tags = epic_attack_tags_client,

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
                    inst.sg.statemem.ph2_summon = true
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
            else
                inst.sg.statemem.target = target
            end

            inst.sg.statemem.isattack = buffaction.action == ACTIONS.ATTACK or nil
			inst.sg.statemem.epicmode = mode

            inst:PerformPreviewBufferedAction()
            if target ~= nil then
                if target:IsValid() then
                    inst.sg.statemem.attacktarget = target
                    inst.sg.statemem.retarget = target
                end
            end

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
                    end
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
                    if inst.sg.statemem.isattack then
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
                    if inst.sg.statemem.isattack then
                        inst:ClearBufferedAction()
                    end
                    inst.sg:RemoveStateTag("abouttoattack")
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
                    if inst.sg.statemem.isattack then
                        inst:ClearBufferedAction()
                    end
                    inst.sg:RemoveStateTag("abouttoattack")
                end
            end),
            FrameEvent(15, function(inst)
                if inst.sg.statemem.epicmode=="dragonfly" then
                    inst.SoundEmitter:PlaySound("dontstarve_DLC001/creatures/dragonfly/punchimpact")
                    if inst.sg.statemem.isattack then
                        inst:ClearBufferedAction()
                    end
                    inst.sg:RemoveStateTag("abouttoattack")
                elseif inst.sg.statemem.epicmode=="ancient_hulk" then
                    if inst.sg.statemem.isattack then
                        inst:ClearBufferedAction()
                    end
                    inst.sg:RemoveStateTag("abouttoattack")
                end
            end),
            FrameEvent(16, function(inst)
                if inst.sg.statemem.epicmode=="daywalker2" then
                    if inst.sg.statemem.isattack then
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
                    inst.SoundEmitter:PlaySound(EPIC[inst.sg.statemem.epicmode].sounds.attack)
                    if inst.sg.statemem.isattack then
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
                    if inst.sg.statemem.isattack then
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
                end
            end),
            FrameEvent(26, function(inst)
                if inst.sg.statemem.epicmode=="daywalker" then
                    inst.Physics:SetMotorVelOverride(2, 0, 0)
                elseif inst.sg.statemem.epicmode=="alterguardian_phase1" then
                    inst.SoundEmitter:PlaySound("moonstorm/creatures/boss/alterguardian1/tantrum")

                    if inst.sg.statemem.isattack then
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
                elseif inst.sg.statemem.epicmode=="mutatedbearger" and not inst.sg.statemem.mutatedbearger_combo then
                    inst.SoundEmitter:PlaySound("dontstarve_DLC001/creatures/bearger/swhoosh")
                    inst.Physics:SetMotorVelOverride(6, 0, 0)
                elseif inst.sg.statemem.mutatedbearger_combo then
                    if inst.sg.statemem.isattack then
                        inst:ClearBufferedAction()
                    end
                    inst.sg:RemoveStateTag("abouttoattack")
                end
            end),
            FrameEvent(29, function(inst)
                if inst.sg.statemem.epicmode=="antlion" then
                    inst.SoundEmitter:PlaySound("dontstarve/creatures/together/antlion/sfx/ground_break")
                elseif inst.sg.statemem.epicmode=="malbatross" then
                    if inst.sg.statemem.isattack then
                        inst:ClearBufferedAction()
                    end
                    inst.sg:RemoveStateTag("abouttoattack")
                elseif inst.sg.statemem.epicmode=="alterguardian_phase3" then
                    if inst.sg.statemem.isattack then
                        inst:ClearBufferedAction()
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
                if inst.sg.statemem.epicmode=="bearger" or inst.sg.statemem.epicmode=="deerclops" or inst.sg.statemem.epicmode=="mutateddeerclops" then
                    if inst.sg.statemem.isattack then
                        inst:ClearBufferedAction()
                    end
                    inst.sg:RemoveStateTag("abouttoattack")
                elseif inst.sg.statemem.epicmode=="alterguardian_phase2" and inst.sg.statemem.ph2_summon then
                    inst.sg:RemoveStateTag("attack")
                    inst.sg:RemoveStateTag("busy")
                elseif inst.sg.statemem.epicmode=="stalker_atrium" then
                    if inst.sg.statemem.isattack then
                        inst:ClearBufferedAction()
                    end
                    inst.sg:RemoveStateTag("abouttoattack")
                elseif inst.sg.statemem.epicmode=="mutatedbearger" and not inst.sg.statemem.mutatedbearger_combo then
                    if inst.sg.statemem.isattack then
                        inst:ClearBufferedAction()
                    end
                    inst.sg:RemoveStateTag("abouttoattack")
                elseif inst.sg.statemem.mutatedbearger_combo then
                    inst.Physics:SetMotorVelOverride(1.5, 0, 0)
                end
			end),
            FrameEvent(33, function(inst)
				if inst.sg.statemem.mutatedbearger_combo then
                    inst.Physics:SetMotorVelOverride(0.75, 0, 0)
                end
			end),
			FrameEvent(34, function(inst)
                if inst.sg.statemem.epicmode=="deerclops" or inst.sg.statemem.epicmode=="mutateddeerclops" then
                    inst.SoundEmitter:PlaySound(EPIC[inst.sg.statemem.epicmode].sounds.swipe)
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
                    inst.sg:RemoveStateTag("abouttoattack")
                end
            end),
            FrameEvent(46, function(inst)
                if inst.sg.statemem.epicmode=="daywalker" then
                    inst.sg.statemem.speed = 4
                    inst.sg.statemem.decel = -1
                    if inst.sg.statemem.isattack then
                        inst:ClearBufferedAction()
                    end
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
                end
            end),
            FrameEvent(58, function(inst)
                if inst.sg.statemem.epicmode=="alterguardian_phase1" then
                    inst.SoundEmitter:PlaySound("moonstorm/creatures/boss/alterguardian1/tantrum")
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
                end
			end),
            FrameEvent(73, function(inst)
                if inst.sg.statemem.epicmode=="alterguardian_phase1" then
                    inst.SoundEmitter:PlaySound("moonstorm/creatures/boss/alterguardian1/tantrum")

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
                inst.Physics:ClearMotorVelOverride()
                inst.Physics:Stop()
            elseif inst.sg.statemem.epicmode=="daywalker" then
                inst.Physics:ClearMotorVelOverride()
                inst.Physics:Stop()
            end
            if inst.sg:HasStateTag("abouttoattack") then
                inst.replica.combat:CancelAttack()
            end
        end,
	})

local anim_idle_boss = {
    moose = true,
    antlion = true,
    dragonfly = true,
    daywalker = true,
    daywalker2 = true,
    alterguardian_phase1 = true,
    alterguardian_phase2 = true,
    ancient_hulk = true,
}
AddStategraphState("wilson_client",State{
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

            local mode = inst.replica.wereepic:GetEpicMode()
            if anim_idle_boss[mode] then
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
                inst.AnimState:PlayAnimation("idle_loop", true)
            end

            inst.sg.statemem.epicmode = mode
        end,

        timeline =
        {
            TimeEvent(19 * FRAMES, function(inst)
                if inst.sg.statemem.epicmode=="ancient_hulk" then
                    inst.SoundEmitter:SetParameter( "gears", "intensity", .2 )
                end
            end),
            TimeEvent(26 * FRAMES, function(inst)
                if inst.sg.statemem.epicmode=="stalker_atrium" then
                    inst.SoundEmitter:PlaySound("dontstarve/creatures/together/stalker/out")
                end
            end),
            TimeEvent(46 * FRAMES, function(inst)
                if inst.sg.statemem.epicmode=="ancient_hulk" then
                    inst.SoundEmitter:SetParameter( "gears", "intensity", .5 )
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

AddStategraphState("wilson_client",State{
        name = "epic_walk_start",
        tags = { "moving", "walking" , "canrotate","epic"},

        onenter = function(inst)
			local mode = inst.replica.wereepic:GetEpicMode()
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

            if mode=="malbatross" then
                inst:PerformPreviewBufferedAction()
            end
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

AddStategraphState("wilson_client",State{
        name = "epic_walk",
        tags = { "moving", "walking", "canrotate","epic" },

        onenter = function(inst)
			local mode = inst.replica.wereepic:GetEpicMode()
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

            if inst:HasTag("bearger_run") or mode=="malbatross" or inst:HasTag("daywalker_run") then
                inst:PerformPreviewBufferedAction()
            end
        end,

        onupdate = function(inst)
            inst.components.locomotor:RunForward()
        end,

        timeline =
        {
            FrameEvent(0, function(inst)
                if inst:HasTag("bearger_run") then
                    DoFootstep(inst)
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
                    PlayFootstep(inst)
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
                if inst.replica.combat:GetTarget() and math.random() < 0.5 then
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

AddStategraphState("wilson_client",State{
        name = "epic_walk_stop",
        tags = { "canrotate", "idle","epic" },

        onenter = function(inst)
			local mode = inst.replica.wereepic:GetEpicMode()
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

AddStategraphState("wilson_client",State{
        name = "epic_castspell",
        tags = { "doing", "busy" ,"epic_transform"},
        server_states = {"epic_castspell" , "becameepic"},

        onenter = function(inst)
            inst.AnimState:PlayAnimation("cointoss_pre")
            inst.AnimState:PushAnimation("cointoss", false)
            inst.components.locomotor:Stop()

            inst.SoundEmitter:KillSound("epiccastspellsound")
            inst.SoundEmitter:PlaySound("meta4/casting/lunar", "epiccastspellsound")
            inst:PerformPreviewBufferedAction()

            inst.sg:SetTimeout(5)
        end,

        timeline =
        {

        },

        ontimeout = function(inst)
            inst.sg:GoToState("epic_idle")
        end,

        events =
        {

        },

        onexit = function(inst)
            inst.SoundEmitter:KillSound("epiccastspellsound")
        end,
    })

AddStategraphState("wilson_client",State{
        name = "deerclops_laserbeam",
        tags = { "busy","epic_skill","attack","epic" },

        onenter = function(inst)
            inst.Physics:Stop()
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

            inst:PerformPreviewBufferedAction()
        end,

        onupdate = function(inst)
            if inst._facepoint_x and inst._facepoint_y and inst._facepoint_z then
                inst:ForceFacePoint(inst._facepoint_x, inst._facepoint_y, inst._facepoint_z)
            end
        end,

        timeline =
        {
			TimeEvent(FRAMES, function(inst) inst.SoundEmitter:PlaySound("dontstarve/creatures/deerclops/attack", nil) end),
			TimeEvent(4 * FRAMES, function(inst) inst.SoundEmitter:PlaySound("dontstarve/creatures/deerclops/step", nil, .7) end),
            TimeEvent(18 * FRAMES, function(inst)
				inst.SoundEmitter:PlaySound("dontstarve/creatures/deerclops/taunt_howl", nil, .4)
            end),
            TimeEvent(19 * FRAMES, function(inst)
                inst.SoundEmitter:PlaySound("dontstarve/creatures/deerclops/laser")
            end),
            TimeEvent(32 * FRAMES, function(inst)
				inst.SoundEmitter:PlaySound("dontstarve/creatures/deerclops/taunt_grrr", nil, .5)
            end),
			TimeEvent(41 * FRAMES, function(inst) inst.SoundEmitter:PlaySound("dontstarve/creatures/deerclops/step", nil, .7) end),
        },

        events =
        {
            EventHandler("animover", function(inst)
                inst.sg.statemem.keepfacing = true
                inst.sg:GoToState("epic_idle")
            end),
        },

        onexit = function(inst)
			inst.Transform:SetFourFaced()
        end,
    })

AddStategraphState("wilson_client",State{
		name = "bearger_pound",
		tags = { "attack", "busy","epic_skill","epic" },

		onenter = function(inst)
			inst.components.locomotor:StopMoving()
			inst.AnimState:PlayAnimation("ground_pound")
            inst.AnimState:PushAnimation("to_bi",false)
            inst:PerformPreviewBufferedAction()
		end,

		timeline =
		{
			FrameEvent(13, function(inst) inst.SoundEmitter:PlaySound("dontstarve_DLC001/creatures/bearger/swhoosh") end),
			FrameEvent(20, function(inst)
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

AddStategraphState("wilson_client",State{
		name = "moose_spin_pre",
		tags = {"busy","epic","epic_skill"},
        server_states = { "moose_spin_pre", "moose_spin_loop", "moose_spin_pst","moose_spin_pst_loop","moose_spin_pst_loop_pst" },

		onenter = function(inst)
			inst.Physics:Stop()
			inst.AnimState:PlayAnimation("spin_pre")

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
            inst:PerformPreviewBufferedAction()
            inst.sg:SetTimeout(5)
		end,

        ontimeout = function(inst)
            inst:ClearBufferedAction()
            inst.sg:GoToState("epic_idle")
        end,

		timeline =
		{
			TimeEvent(6*FRAMES, function(inst) inst.SoundEmitter:PlaySound("dontstarve_DLC001/creatures/mossling/attack") end),
		},
	})

AddStategraphState("wilson_client",State{
        name = "antlion_jumpin_out",
        tags = { "busy","epic","epic_skill" },
        server_states = { "antlion_jumpin_out","antlion_jumpin_enter" },

        onenter = function(inst)
            inst.components.locomotor:Stop()
            inst.AnimState:PlayAnimation("out")

            inst:PerformPreviewBufferedAction()
            inst.sg:SetTimeout(5)
        end,

        ontimeout = function(inst)
            inst:ClearBufferedAction()
            inst.sg:GoToState("epic_idle")
        end,

        timeline =
        {
            FrameEvent(15, function(inst)
				inst.SoundEmitter:PlaySound("dontstarve/creatures/together/antlion/cast_pre")
			end),
            FrameEvent(31, function(inst)
				inst.SoundEmitter:PlaySound("dontstarve/creatures/together/antlion/cast_post")
			end),
        },
    })

AddStategraphState("wilson_client",State{
        name = "malbatross_depart",
        tags = { "busy","epic","epic_skill","nosleep", "swoop", "flight", "noelectrocute" },
        server_states = { "malbatross_depart","malbatross_arrive" },

        onenter = function(inst)
            inst.components.locomotor:Stop()
            inst.AnimState:PlayAnimation("despawn")
            inst:PerformPreviewBufferedAction()
            inst.sg:SetTimeout(5)
        end,

        ontimeout = function(inst)
            inst:ClearBufferedAction()
            inst.sg:GoToState("epic_idle")
        end,

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

AddStategraphState("wilson_client",State{
        name = "malbatross_swoop_pre",
        tags = {"busy", "swoop","epic","epic_skill"},
        server_states = { "malbatross_swoop_pre","malbatross_swoop_loop","malbatross_swoop_pst","epic_taunt" },

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
            inst:PerformPreviewBufferedAction()
            inst.sg:SetTimeout(5)
        end,

        ontimeout = function(inst)
            inst:ClearBufferedAction()
            inst.sg:GoToState("epic_idle")
        end,

        timeline =
        {
            TimeEvent(6 * FRAMES, function(inst) inst.SoundEmitter:PlaySound("saltydog/creatures/boss/malbatross/eat") end),
            TimeEvent(8 * FRAMES, function(inst) inst.SoundEmitter:PlaySound("saltydog/creatures/boss/malbatross/swoop_pre") end),
        },

    })

AddStategraphState("wilson_client",State{
        name = "beequeen_spawnguards",
        tags = { "spawnguards", "busy", "nosleep", "nofreeze","epic","epic_skill" },

        onenter = function(inst)
            inst.components.locomotor:StopMoving()
            inst.AnimState:PlayAnimation("spawn")
            local target = inst.replica.combat:GetTarget()
            if target ~= nil and target:IsValid() then
                inst:ForceFacePoint(target.Transform:GetWorldPosition())
            end
            inst.SoundEmitter:PlaySound("dontstarve/creatures/together/bee_queen/spawn")
            inst:PerformPreviewBufferedAction()
        end,

        timeline =
        {

        },

        events =
        {
            EventHandler("animover", function (inst)
                inst.sg:GoToState("epic_idle")
            end),
        },
    })

AddStategraphState("wilson_client",State{
        name = "dragonfly_lavae",
        tags = { "busy","epic","epic_skill" },

        onenter = function(inst)
            inst.Transform:SetTwoFaced()
            inst.components.locomotor:StopMoving()
            inst.AnimState:PlayAnimation("vomit")
            inst.SoundEmitter:PlaySound("dontstarve_DLC001/creatures/dragonfly/vomitrumble", "vomitrumble")
            inst:PerformPreviewBufferedAction()
        end,

        timeline =
        {
            TimeEvent(2*FRAMES, function(inst) inst.SoundEmitter:PlaySound("dontstarve_DLC001/creatures/dragonfly/blink") end),
            TimeEvent(55*FRAMES, function(inst)
                inst.SoundEmitter:KillSound("vomitrumble")
                inst.SoundEmitter:PlaySound("dontstarve_DLC001/creatures/dragonfly/vomit")
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
            inst.SoundEmitter:KillSound("vomitrumble")
        end,
    })

AddStategraphState("wilson_client",State{
		name = "daywalker_attack_pounce",
		tags = { "busy", "jumping", "nointerrupt", "notalksound","epic","epic_skill" },
        server_states = { "daywalker_attack_pounce","daywalker_attack_slam" },

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
            inst:PerformPreviewBufferedAction()
		end,

        onupdate = function(inst)
			inst.sg.statemem.speed = inst.sg.statemem.speed * 0.9
			inst.Physics:SetMotorVelOverride(inst.sg.statemem.speed * inst.sg.statemem.speedmult, 0, 0)
		end,

		timeline =
		{
			FrameEvent(10, function(inst) inst.SoundEmitter:PlaySound("daywalker/action/step") end),
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

AddStategraphState("wilson_client",State{
		name = "daywalker2_cannon_pre",
		tags = { "busy", "epic","epic_skill" },
        server_states = { "daywalker2_cannon_pre","daywalker2_cannon" },

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
            inst:PerformPreviewBufferedAction()
            inst.sg:SetTimeout(5)
        end,

        onupdate = function(inst)
			if inst._facepoint_x and inst._facepoint_y and inst._facepoint_z then
                inst:ForceFacePoint(inst._facepoint_x, inst._facepoint_y, inst._facepoint_z)
            end
		end,

        ontimeout = function(inst)
            inst:ClearBufferedAction()
            inst.sg:GoToState("epic_idle")
        end,

	})

AddStategraphState("wilson_client",State{
		name = "daywalker2_tackle_pre",
		tags = { "tackle", "busy", "epic","epic_skill" },
        server_states = { "daywalker2_tackle_pre","daywalker2_tackle_loop","daywalker2_tackle_lift" },

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
            inst:PerformPreviewBufferedAction()
            inst.sg:SetTimeout(5)
		end,

		onupdate = function(inst)
			if inst._facepoint_x and inst._facepoint_y and inst._facepoint_z then
                inst:ForceFacePoint(inst._facepoint_x, inst._facepoint_y, inst._facepoint_z)
            end
		end,

        ontimeout = function(inst)
            inst:ClearBufferedAction()
            inst.sg:GoToState("epic_idle")
        end,

		timeline =
		{
			FrameEvent(6, daywalker_DoFootstep),
		},

		onexit = function(inst)
			if inst.sg:HasStateTag("jumping") then
				inst.Physics:ClearMotorVelOverride()
				inst.Physics:Stop()
			end
		end,
	})

AddStategraphState("wilson_client",State{
        name = "phase1_roll_start",
		tags = { "busy", "canrotate", "charge","epic","epic_skill","ph1_roll" },
        server_states = { "phase1_roll_start","phase1_roll","phase1_roll_stop" },

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
                end
			end

            inst.components.locomotor:Stop()

            inst.AnimState:PlayAnimation("roll_pre")
            inst:PerformPreviewBufferedAction()
            inst.sg:SetTimeout(5)
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

        ontimeout = function(inst)
            inst:ClearBufferedAction()
            inst.sg:GoToState("epic_idle")
        end,

        onexit = function(inst)
            inst.components.locomotor:Stop()
            inst.Physics:ClearMotorVelOverride()
        end,
    })

AddStategraphState("wilson_client",State {
        name = "epic_atk_spike",
        tags = { "busy","epic","epic_skill1"},
        server_states = {"epic_atk_spike","epic_atk_spike_pst"},

        onenter = function(inst, target)
            inst.components.locomotor:StopMoving()

            inst.AnimState:PlayAnimation("attk_stab_pre")
            inst.AnimState:PushAnimation("attk_stab_loop", true)

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

            inst:PerformPreviewBufferedAction()
            inst.sg:SetTimeout(5)
        end,

        timeline =
        {
            TimeEvent(11*FRAMES, function(inst)
                inst.SoundEmitter:PlaySound("moonstorm/creatures/boss/alterguardian2/atk_spike_pre")
            end),
            TimeEvent(28*FRAMES, function(inst)
                inst.SoundEmitter:PlaySound("moonstorm/creatures/boss/alterguardian2/atk_spike")
            end),
        },

        ontimeout = function(inst)
            inst:ClearBufferedAction()
            inst.sg:GoToState("epic_idle")
        end,
    })

AddStategraphState("wilson_client",State {
        name = "epic_spin_pre",
        tags = {"busy", "canrotate", "spin","epic","epic_skill"},
        server_states = {"epic_spin_pre","epic_spin_loop","epic_spin_pst"},

        onenter = function(inst)
            inst.components.locomotor:Stop()
            inst.AnimState:PlayAnimation("attk_spin_pre")

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

            inst:PerformPreviewBufferedAction()
            inst.sg:SetTimeout(5)
        end,

		onupdate = function(inst, dt)
            local target = inst.sg.statemem.target
            if target ~= nil and target:IsValid() then
                inst:ForceFacePoint(target.Transform:GetWorldPosition())
            end
        end,

        timeline =
        {
            TimeEvent(30*FRAMES, function(inst)
                inst.SoundEmitter:PlaySound("moonstorm/creatures/boss/alterguardian2/atk_spin_pre")
            end),
            TimeEvent(32*FRAMES, function(inst)

                local spin_speed = TUNING.ALTERGUARDIAN_PHASE2_SPIN_SPEED
                inst.Physics:SetMotorVelOverride(spin_speed, 0, 0)
            end),
			TimeEvent(35 * FRAMES, function(inst)
				inst.sg.statemem.attack_time = 0
			end),
        },

        ontimeout = function(inst)
            inst:ClearBufferedAction()
            inst.sg:GoToState("epic_idle")
        end,

        onexit = function(inst)
            inst.Physics:ClearMotorVelOverride()
            inst.components.locomotor:Stop()
        end,
    })

AddStategraphState("wilson_client",State{
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
            inst:PerformPreviewBufferedAction()
        end,

        onupdate = function(inst)
            if inst.sg.statemem.target ~= nil and inst.sg.statemem.target:IsValid() then
                inst._facepoint_x, inst._facepoint_y, inst._facepoint_z = inst.sg.statemem.target.Transform:GetWorldPosition()
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

AddStategraphState("wilson_client",State{
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
            inst:PerformPreviewBufferedAction()
        end,

        onupdate = function(inst)
            if inst.sg.statemem.target ~= nil and inst.sg.statemem.target:IsValid() then
                inst._facepoint_x, inst._facepoint_y, inst._facepoint_z = inst.sg.statemem.target.Transform:GetWorldPosition()
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

AddStategraphState("wilson_client",State{
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
            inst:PerformPreviewBufferedAction()
        end,

        timeline =
        {
            TimeEvent(8 * FRAMES, function(inst) inst.SoundEmitter:PlaySound("dontstarve/creatures/together/stalker/out") end),
            TimeEvent(12 * FRAMES, function(inst) inst.SoundEmitter:PlaySound("dontstarve/creatures/together/stalker/in") end),
            TimeEvent(30 * FRAMES, function(inst)
                inst.SoundEmitter:PlaySound("dontstarve/creatures/together/stalker/laugh")
            end),
            TimeEvent(48 * FRAMES, function(inst) inst.SoundEmitter:PlaySound("dontstarve/creatures/together/stalker/taunt_short", nil, .6) end),
            TimeEvent(50 * FRAMES, function(inst) inst.SoundEmitter:PlaySound("dontstarve/creatures/together/stalker/attack1_pbaoe") end),
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

AddStategraphState("wilson_client",State{
        name = "mutatedwarg_howl",
        tags = { "busy", "howling","epic","epic_skill" },

        onenter = function(inst)
            inst.Physics:Stop()
            inst.AnimState:PlayAnimation("howl")
            inst.SoundEmitter:PlaySound("rifts3/mutated_varg/howl")
            inst:PerformPreviewBufferedAction()
        end,

        timeline =
        {
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

AddStategraphState("wilson_client",State{
		name = "mutatedwarg_flamethrower_pre",
		tags = { "epic","epic_skill", "busy" },
        server_states = { "mutatedwarg_flamethrower_pre","mutatedwarg_flamethrower_loop","mutatedwarg_flamethrower_pst" },

		onenter = function(inst)
			inst.components.locomotor:Stop()
			inst.AnimState:PlayAnimation("atk_breath_pre")
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
                    inst.sg.statemem.target = buffaction.target
                end
                inst.sg.statemem.targetpos = Vector3(inst._facepoint_x, inst._facepoint_y, inst._facepoint_z)
			end
            inst:PerformPreviewBufferedAction()
            inst.sg:SetTimeout(5)
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
			end
		end,

		timeline =
		{
			FrameEvent(0, function(inst) inst.SoundEmitter:PlaySound("rifts3/mutated_varg/blast_pre_f0") end),

			FrameEvent(17, function(inst)
				inst.SoundEmitter:PlaySound("rifts3/mutated_varg/blast_pre_f17")
				inst.SoundEmitter:PlaySound("rifts3/mutated_varg/blast_lp", "loop")
			end),
		},

        ontimeout = function(inst)
            inst:ClearBufferedAction()
            inst.sg:GoToState("epic_idle")
        end,

		onexit = function(inst)
			inst.Transform:SetSixFaced()
			inst.SoundEmitter:KillSound("loop")
		end,
	})

AddStategraphState("wilson_client",State{
		name = "mutatedbearger_butt_pre",
		tags = { "epic","epic_skill","busy" },
        server_states = {"mutatedbearger_butt_pre","mutatedbearger_butt","mutatedbearger_butt_pst"},

		onenter = function(inst)
			inst.components.locomotor:Stop()
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
                inst.sg.statemem.targetpos = Vector3(inst._facepoint_x, inst._facepoint_y, inst._facepoint_z)
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
            inst:PerformPreviewBufferedAction()
            inst.sg:SetTimeout(5)
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

		ontimeout = function(inst)
            inst:ClearBufferedAction()
            inst.sg:GoToState("epic_idle")
        end,
	})

AddStategraphState("wilson_client",State{
		name = "mutateddeerclops_icelance",
		tags = { "epic","epic_skill","busy" },
        server_states = {"mutateddeerclops_icelance","mutateddeerclops_icegrow","mutateddeerclops_icegrow_pst"},

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
            inst:PerformPreviewBufferedAction()
            inst.sg:SetTimeout(inst.AnimState:GetCurrentAnimationLength() + 3*FRAMES)
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
			end),
			FrameEvent(47, function(inst) inst.SoundEmitter:PlaySound("rifts3/mutated_deerclops/ice_throw_f47") end),
			FrameEvent(56, function(inst)
				DeerclopsFootstep(inst, false, true)
			end),
			FrameEvent(60, function(inst)
				inst.SoundEmitter:PlaySound("dontstarve/creatures/deerclops/attack")
			end),
		},

        ontimeout = function(inst)
            inst:ClearBufferedAction()
            inst.sg:GoToState("epic_idle")
        end,

		onexit = function(inst)
			inst.Transform:SetFourFaced()
            if not inst.replica.wereepic._mutated_ice:value() then
				inst.AnimState:Hide("ice_0")
			end
		end,
	})

AddStategraphState("wilson_client",State{
        name = "ancient_hulk_lob",
        tags = {"busy","canrotate","epic","epic_skill"},

        onenter = function(inst)
            inst.components.locomotor:StopMoving()
            inst.AnimState:PlayAnimation("atk_lob")

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
            inst:PerformPreviewBufferedAction()
            inst.sg:SetTimeout(inst.AnimState:GetCurrentAnimationLength() + 3*FRAMES)
        end,

        timeline =
        {
            TimeEvent(0*FRAMES, function(inst)
                inst.SoundEmitter:PlaySound("mnh_ancient_hulk_sound/creatures/boss/hulk_metal_robot/laser_pre")
            end),
            TimeEvent(30*FRAMES, function(inst)
                if inst.sg.statemem.target and inst.sg.statemem.target:IsValid() then
                    inst.sg.statemem.targetpos = Vector3(inst.sg.statemem.target.Transform:GetWorldPosition())
                end
                inst.SoundEmitter:PlaySoundWithParams("mnh_ancient_hulk_sound/creatures/boss/hulk_metal_robot/laser", {intensity=math.random()})
            end),
        },

        onupdate = function(inst)
            if inst.sg.statemem.targetpos then
                inst:ForceFacePoint(inst.sg.statemem.targetpos)
            end
        end,

        ontimeout = function(inst)
            inst:ClearBufferedAction()
            inst.sg:GoToState("epic_idle")
        end,
    })

AddStategraphState("wilson_client",State{
        name = "ancient_hulk_telportout_pre",
        tags = {"busy","epic","epic_skill"},
        server_states = { "ancient_hulk_telportout_pre","ancient_hulk_telportout","ancient_hulk_telportin" },

        onenter = function(inst)
            inst.components.locomotor:StopMoving()
            inst.AnimState:PlayAnimation("teleport_out_pre")
            inst:PerformPreviewBufferedAction()
            inst.sg:SetTimeout(5)
        end,

        ontimeout = function(inst)
            inst:ClearBufferedAction()
            inst.sg:GoToState("epic_idle")
        end,

        timeline=
        {
                        ---teleport---
             TimeEvent(18*FRAMES, function(inst) inst.SoundEmitter:PlaySound("mnh_ancient_hulk_sound/creatures/boss/hulk_metal_robot/teleport_out") end),
                    -------------step---------------
             TimeEvent(9*FRAMES, function(inst) inst.SoundEmitter:PlaySound("mnh_ancient_hulk_sound/creatures/boss/hulk_metal_robot/leg/step",nil,.25) end),
             TimeEvent(20*FRAMES, function(inst) inst.SoundEmitter:PlaySound("mnh_ancient_hulk_sound/creatures/boss/hulk_metal_robot/leg/step",nil,.25) end),
        },
    })

AddStategraphPostInit("wilson_client", function(sg)
---actionhandlers
---ATTACK
    local old_attack_handler_deststate = sg.actionhandlers[ACTIONS.ATTACK].deststate
    sg.actionhandlers[ACTIONS.ATTACK].deststate = function(inst, action)
        if inst:HasTag("epic") then
            if not (inst.sg:HasStateTag("attack") and action.target == inst.sg.statemem.attacktarget or IsEntityDead(inst)) then
                return "epic_attack"
            end
        else
            return old_attack_handler_deststate(inst, action)
        end
    end

---events
---locomotor
    local old_locomote_fn = sg.events.locomote.fn
    sg.events.locomote.fn = function (inst,data)
        if inst:HasTag("epic") then
            if inst.sg:HasStateTag("overridelocomote") then
                return
            end

            local is_moving = inst.sg:HasStateTag("moving")
            local should_move = inst.components.locomotor:WantsToMoveForward()

            if not inst.entity:CanPredictMovement() then
                if not inst.sg:HasStateTag("idle") then
                    inst.sg:GoToState("epic_idle")
                end
            elseif is_moving and not should_move then
                inst.sg:GoToState("epic_walk_stop")
            elseif not is_moving and should_move then
                --V2C: Added "dir" param so we don't have to add "canrotate" to all interruptible states
                if data and data.dir then
                    if inst.components.locomotor then
                        inst.components.locomotor:SetMoveDir(data.dir)
                    else
                        inst.Transform:SetRotation(data.dir)
                    end
                end
                inst.sg:GoToState("epic_walk_start")
            end
        else
            return old_locomote_fn(inst,data)
        end
    end
end)