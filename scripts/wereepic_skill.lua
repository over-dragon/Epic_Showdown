local function TransformCool(inst,cooldown)
    cooldown = cooldown or 1
    if inst.components.spellbookcooldowns then
        inst.components.spellbookcooldowns:RestartSpellCooldown("epic_transform", cooldown)
    end
end

local function SkillCool(inst,skillnum,cooldown)
    cooldown = cooldown or 1
    if inst.components.spellbookcooldowns then
        inst.components.spellbookcooldowns:RestartSpellCooldown("epic_skill"..tostring(skillnum), cooldown)
    end
end

local function find_gestalt_target(inst,gestalt)
    if not TheNet:GetPVPEnabled() then
        return
    end
    local gx, gy, gz = gestalt.Transform:GetWorldPosition()
    local target = nil
    local rangesq = 36
    for _, v in ipairs(AllPlayers) do
        if not IsEntityDeadOrGhost(v) and
                not (v.sg:HasStateTag("knockout") or
                    v.sg:HasStateTag("sleeping") or
                    v.sg:HasStateTag("bedroll") or
                    v.sg:HasStateTag("tent") or
                    v.sg:HasStateTag("waking")) and
                v.entity:IsVisible() and v~=inst then

            local distsq = v:GetDistanceSqToPoint(gx, 0, gz)
            if distsq < rangesq then
                rangesq = distsq
                target = v
            end
        end
    end

    return target
end


local MIN_GESTALTS, MAX_GESTALTS = 6, 10
local EXTRA_GESTALTS_BYHEALTH = 12
local MIN_SUMMON_RANGE, MAX_SUMMON_RANGE = 5, 7
local function DoGestaltSummon(inst)
    local ix, iy, iz = inst.Transform:GetWorldPosition()

    local spawn_warning = SpawnPrefab("alterguardian_summon_fx")
    spawn_warning.Transform:SetScale(1.2, 1.2, 1.2)
    spawn_warning.Transform:SetPosition(ix, iy, iz)

    -- A random amount of spawns plus a base amount based on missing health.
    local num_gestalts = GetRandomMinMax(MIN_GESTALTS, MAX_GESTALTS) + math.ceil((1 - inst.components.health:GetPercent()) * EXTRA_GESTALTS_BYHEALTH)

    local angle_increment = 3.75*PI / num_gestalts -- almost 2pi twice; loop 2 times, but slightly offset
    local initial_angle = TWOPI*math.random()

    for i = 1, num_gestalts do
        -- Spawn a collection of gestalts in a haphazard ring around the boss.
        -- The gestalts are undirected, but will target somebody if they're nearby.

        inst:DoTaskInTime(2.0 + (i*4*FRAMES), function(inst2)
            local gestalt = SpawnPrefab("gestalt_alterguardian_projectile")
            if gestalt ~= nil then
                -- NOTE: Deliberately not square rooting this radius;
                -- clustering closer to the boss is fine behaviour.
                local r = GetRandomMinMax(MIN_SUMMON_RANGE, MAX_SUMMON_RANGE)
                local angle = initial_angle + GetRandomWithVariance((i - 1) * angle_increment, PI/8)
                local x, z = r * math.cos(angle), r * math.sin(angle)

                gestalt.Transform:SetPosition(ix + x, iy + 0, iz + z)

                local target = find_gestalt_target(inst,gestalt)
                if target ~= nil then
                    gestalt:ForceFacePoint(target:GetPosition())
                    gestalt:SetTargetPosition(target:GetPosition())
                end
            end
        end)
    end

    inst:DoTaskInTime(2.0 + (num_gestalts*4*FRAMES) + 1.0, function(inst2)
        spawn_warning:PushEvent("endloop")
    end)
end

local WEREEPIC_SKILL = {

    deerclops = {
        skill = function (act)
            return true
        end,

        sounds = {
            step = "dontstarve/creatures/deerclops/step",
            taunt_grrr = "dontstarve/creatures/deerclops/taunt_grrr",
            taunt_howl = "dontstarve/creatures/deerclops/taunt_howl",
            hurt = "dontstarve/creatures/deerclops/hurt",
            death = "dontstarve/creatures/deerclops/death",
            attack = "dontstarve/creatures/deerclops/attack",
            swipe = "dontstarve/creatures/deerclops/swipe",
            charge = "dontstarve/creatures/deerclops/charge",
            walk = nil,
        },

        transform = function (inst)
            if inst._deerclops_hide then
                inst._deerclops_hide = false
                inst.AnimState:Hide("head_neutral")
            else
                inst._deerclops_hide = true
                inst.AnimState:Show("head_neutral")
            end
            TransformCool(inst)
        end,

        stategraphs = {
            skill0 = "deerclops_laserbeam"
        },
    },

    bearger = {
        skill = function (act)
            return true
        end,

        sounds = {
            attack = "dontstarve_DLC001/creatures/bearger/attack",
            death = "dontstarve_DLC001/creatures/bearger/death",
            idle = "dontstarve_DLC001/creatures/bearger/idle",
            sleep = "dontstarve_DLC001/creatures/bearger/sleep",
            taunt = "dontstarve_DLC001/creatures/bearger/taunt",
            taunt_short = "dontstarve_DLC001/creatures/bearger/taunt_short",
            growl = "dontstarve_DLC001/creatures/bearger/grrrr",
            yawn = "dontstarve_DLC001/creatures/bearger/yawn",
        },

        transform = function (inst)
            if inst:HasTag("bearger_run") then
                inst:RemoveTag("bearger_run")
                if inst.components.locomotor then
                    inst.components.locomotor:RemoveExternalSpeedMultiplier(inst,"bearger_run_speed")
                end
            else
                inst:AddTag("bearger_run")
                if inst.components.locomotor then
                    inst.components.locomotor:SetExternalSpeedMultiplier(inst,"bearger_run_speed",5/3)
                end
            end
            TransformCool(inst)
        end,

        skill1 = function (inst)
            if TheWorld.state.season~="autumn" and TheWorld.state.season~="summer" and not inst.sg:HasStateTag("bearger_yawn") and not inst.sg:HasStateTag("busy") then
                inst.sg:GoToState("bearger_yawn")
                SkillCool(inst,1,30)
            end
        end,

        stategraphs = {
            skill0 = "bearger_pound"
        },
    },

    moose = {
        skill = function (act)
            return true
        end,

        sounds = {
            attack = "dontstarve_DLC001/creatures/mossling/attack",
            death = "dontstarve_DLC001/creatures/mossling/death",
            sleep = "dontstarve_DLC001/creatures/mossling/sleep",
            honk = "dontstarve_DLC001/creatures/mossling/honk",
            taunt = "dontstarve_DLC001/creatures/mossling/taunt",
            flap = "dontstarve_DLC001/creatures/mossling/flap",
            strain = "dontstarve_DLC001/creatures/mossling/strain",
            pop = "dontstarve_DLC001/creatures/mossling/pop",
            spin = "dontstarve_DLC001/creatures/mossling/spin",
            dizzy = "dontstarve_DLC001/creatures/mossling/dizzy",
            yawn = "dontstarve_DLC001/creatures/mossling/yawn",
        },

        transform = function (inst)
            if not inst.sg:HasStateTag("spinning") then
                if inst.moose_angery then
                    inst.moose_angery = false
                    inst.AnimState:SetBuild("mossling_build")
                else
                    inst.moose_angery = true
                    inst.AnimState:SetBuild("mossling_angry_build")
                end
                TransformCool(inst)
            end
        end,

        skill1 = function (inst)
            if not inst.sg:HasAnyStateTag("busy","moose_meep") then
                inst.sg:GoToState("moose_meep")
                SkillCool(inst,1)
            end
        end,

        stategraphs = {
            skill0 = "moose_spin_pre"
        },
    },

    antlion = {
        skill = function (act)
            return true
        end,

        attack_timeout = 49*FRAMES,

        sounds = {

        },

        transform = function (inst)
            if not inst.sg:HasAnyStateTag("busy","antlion_hightributeresponse") then
                inst.sg:GoToState("antlion_hightributeresponse")
                TransformCool(inst)
            end
        end,

        skill1 = function (inst)
            if not inst.sg:HasAnyStateTag("busy","antlion_summonwall") then
                inst.sg:GoToState("antlion_summonwall")
                SkillCool(inst,1,10)
            end
        end,

        skill2 = function (inst)
            if not inst.sg:HasAnyStateTag("busy","antlion_eat") then
                inst.sg:GoToState("antlion_eat")
                SkillCool(inst,2,15)
            end
        end,

        stategraphs = {
            skill0 = "antlion_jumpin_out",
            map_teleport = "antlion_jumpin_out",
        },
    },

    malbatross = {
        skill = function (act)
            return true
        end,

        sounds = {

        },

        skill1 = function (inst)
            if not inst.sg:HasAnyStateTag("busy","malbatross_combatdive","malbatross_combatdive_pst") and not inst:IsOnPassablePoint() then
                inst.sg:GoToState("malbatross_combatdive")
                SkillCool(inst,1,5)
            end
        end,

        stategraphs = {
            skill0 = "malbatross_swoop_pre",
            map_teleport = "malbatross_depart",
        },
    },

    beequeen = {
        skill = function (act)
            return true
        end,

        sounds = {

        },

        skill1 = function (inst)
            if not inst.sg:HasAnyStateTag("busy","beequeen_focustarget") then
                inst.sg:GoToState("beequeen_focustarget")
                SkillCool(inst,1,5)
            end
        end,

        skill2 = function (inst)
            if not inst.sg:HasAnyStateTag("busy","beequeen_alertbee") then
                inst.sg:GoToState("beequeen_alertbee")
                SkillCool(inst,2)
            end
        end,

        stategraphs = {
            skill0 = "beequeen_spawnguards",
        },
    },

    dragonfly = {
        skill = function (act)
            return true
        end,

        sounds = {

        },

        transform = function (inst)
            if inst.dragonfly_yule then
                inst.dragonfly_yule = false
                if inst:HasTag("dragonfly_enraged") then
                    inst.AnimState:SetBuild("dragonfly_fire_build")
                else
                    inst.AnimState:SetBuild("dragonfly_build")
                end
            else
                inst.dragonfly_yule = true
                if inst:HasTag("dragonfly_enraged") then
                    inst.AnimState:SetBuild("dragonfly_fire_yule_build")
                else
                    inst.AnimState:SetBuild("dragonfly_yule_build")
                end
            end
            TransformCool(inst)
        end,

        skill1 = function (inst)
            if not inst.sg:HasAnyStateTag("busy","dragonfly_transform_fire") then
                inst.sg:GoToState("dragonfly_transform_fire")
                SkillCool(inst,1,90)
            end
        end,

        skill2 = function (inst)
            if inst:HasTag("dragonfly_enraged") and not inst.sg:HasAnyStateTag("busy","dragonfly_pound_pre","dragonfly_pound","dragonfly_pound_pst") then
                inst.sg:GoToState("dragonfly_pound_pre")
                SkillCool(inst,2,15)
            end
        end,

        stategraphs = {
            skill0 = "dragonfly_lavae"
        },
    },

    daywalker = {
        skill = function (act)
            return true
        end,

        attack_timeout = 82*FRAMES,

        sounds = {

        },

        transform = function (inst)
            if inst:HasTag("daywalker_run") then
                inst:RemoveTag("daywalker_run")
                if inst.components.locomotor then
                    inst.components.locomotor:RemoveExternalSpeedMultiplier(inst,"daywalker_run_speed")
                    if TUNING.EPIC_WORLD.WALKSPEED_CHANGE==1 then
                        inst.components.locomotor.runspeed = 3
                    end
                end
            else
                inst:AddTag("daywalker_run")
                if inst.components.locomotor then
                    inst.components.locomotor:SetExternalSpeedMultiplier(inst,"daywalker_run_speed",1.5)
                    if TUNING.EPIC_WORLD.WALKSPEED_CHANGE==1 then
                        inst.components.locomotor.runspeed = 6
                    end
                end
            end
            TransformCool(inst)
        end,

        stategraphs = {
            skill0 = "daywalker_attack_pounce"
        },
    },

    daywalker2 = {
        skill = function (act)
            return true
        end,

        attack_timeout = 27*FRAMES,

        sounds = {

        },

        transform = function (inst)
            if inst:HasTag("daywalker_run") then
                inst:RemoveTag("daywalker_run")
                if inst.components.locomotor then
                    inst.components.locomotor:RemoveExternalSpeedMultiplier(inst,"daywalker_run_speed")
                    if TUNING.EPIC_WORLD.WALKSPEED_CHANGE==1 then
                        inst.components.locomotor.runspeed = 3
                    end
                end
            else
                inst:AddTag("daywalker_run")
                if inst.components.locomotor then
                    inst.components.locomotor:SetExternalSpeedMultiplier(inst,"daywalker_run_speed",1.5)
                    if TUNING.EPIC_WORLD.WALKSPEED_CHANGE==1 then
                        inst.components.locomotor.runspeed = 6
                    end
                end
            end
            TransformCool(inst)
        end,

        stategraphs = {
            skill0 = function (inst)
                if inst:HasTag("daywalker_run") then
                    return "daywalker2_tackle_pre"
                else
                    return "daywalker2_cannon_pre"
                end
            end
        },
    },

    alterguardian_phase1 = {
        skill = function (act)
            return true
        end,

        attack_timeout = 116*FRAMES,

        sounds = {

        },

        transform = function (inst)
            if inst.sg:HasStateTag("shield") then
                inst.sg:GoToState("phase1_shield_end")
            elseif not inst.sg:HasStateTag("shield") and not inst.sg:HasStateTag("busy") then
                inst.sg:GoToState("phase1_shield_pre")
            end
            TransformCool(inst)
        end,

        skill1 = function (inst)
            if inst.sg:HasStateTag("shield") then
                DoGestaltSummon(inst)
                SkillCool(inst,1,20)
            end
        end,

        stategraphs = {
            skill0 =  "phase1_roll_start"
        },
    },

    alterguardian_phase2 = {
        skill = function (act)
            return true
        end,

        sounds = {

        },

        skill1 = function (inst)
            inst.replica.wereepic._phase2:set(3)
            SkillCool(inst,1,25)
        end,

        skill2 = function (inst)
            if not inst:HasTag("phase2_spin_atk") then
                inst:AddTag("phase2_spin_atk")
            end
            SkillCool(inst,2,15)
        end,

        stategraphs = {
            skill0 = function (inst)
                if inst:HasTag("phase2_spin_atk") then
                    return "epic_spin_pre"
                else
                    return "epic_atk_spike"
                end
            end
        },
    },

    alterguardian_phase3 = {
        skill = function (act)
            return true
        end,

        sounds = {

        },

        skill1 = function (inst)
            if not inst.sg:HasAnyStateTag("busy","phase3_atk_traps") then
                inst.sg:GoToState("phase3_atk_traps")
                SkillCool(inst,1,40)
            end
        end,

        skill2 = function (inst)
            if not inst.sg:HasAnyStateTag("busy","phase3_atk_summon_pre","phase3_atk_summon_loop","phase3_atk_summon_pst") then
                inst.sg:GoToState("phase3_atk_summon_pre")
                SkillCool(inst,2,45)
            end
        end,

        stategraphs = {
            skill0 = function (inst)
                inst._phase3_laser_style = not inst._phase3_laser_style
                return inst._phase3_laser_style and "phase3_atk_beam" or "phase3_atk_sweep"
            end
        },
    },

    stalker_atrium = {
        skill = function (act)
            return true
        end,

        sounds = {

        },

        transform = function (inst)
            if inst.components.debuffable then
                inst.components.debuffable:AddDebuff("stalker_atrium_shield","buff_stalker_atrium_shield")
            end
            TransformCool(inst,20)
        end,

        skill1 = function (inst)
            if not inst.sg:HasAnyStateTag("busy","stalker_atrium_snare") then
                inst.sg:GoToState("stalker_atrium_snare")
                SkillCool(inst,1,10)
            end
        end,

        skill2 = function (inst)
            if not inst.sg:HasAnyStateTag("busy","stalker_atrium_summon_minions_pre","stalker_atrium_summon_minions_loop","stalker_atrium_summon_minions_pst") then
                inst.sg:GoToState("stalker_atrium_summon_minions_pre")
                SkillCool(inst,2,30)
            end
        end,

        skill3 = function (inst)
            if not inst.sg:HasAnyStateTag("busy","stalker_atrium_mindcontrol_pre","stalker_atrium_mindcontrol_loop","stalker_atrium_mindcontrol_pst") then
                inst.sg:GoToState("stalker_atrium_mindcontrol_pre")
                SkillCool(inst,3,15)
            end
        end,

        stategraphs = {
            skill0 = "stalker_atrium_spikes",
        },
    },

    mutatedwarg = {
        skill = function (act)
            return true
        end,

        sounds = {
            idle = "rifts3/mutated_varg/idle",
            howl = "rifts3/mutated_varg/howl",
            hit = "rifts3/mutated_varg/hit",
            attack = "rifts3/mutated_varg/attack",
            death = "rifts3/mutated_varg/death",
            sleep = "rifts3/mutated_varg/sleep",
        },

        skill1 = function (inst)
            if not inst:HasTag("mutatedwarg_flamethrower") then
                inst:AddTag("mutatedwarg_flamethrower")
            end
            SkillCool(inst,1,8)
        end,

        stategraphs = {
            skill0 = function(inst)
                if inst:HasTag("mutatedwarg_flamethrower") then
                    return "mutatedwarg_flamethrower_pre"
                else
                    return "mutatedwarg_howl"
                end
            end,
        },
    },

    mutatedbearger = {
        skill = function (act)
            return true
        end,

        sounds = {
            attack = "dontstarve_DLC001/creatures/bearger/attack",
            death = "dontstarve_DLC001/creatures/bearger/death",
            idle = "dontstarve_DLC001/creatures/bearger/idle",
            sleep = "dontstarve_DLC001/creatures/bearger/sleep",
            taunt = "dontstarve_DLC001/creatures/bearger/taunt",
            taunt_short = "dontstarve_DLC001/creatures/bearger/taunt_short",
            growl = "dontstarve_DLC001/creatures/bearger/grrrr",
            yawn = "dontstarve_DLC001/creatures/bearger/yawn",
        },

        transform = function (inst)
            if inst:HasTag("bearger_run") then
                inst:RemoveTag("bearger_run")
                if inst.components.locomotor then
                    inst.components.locomotor:RemoveExternalSpeedMultiplier(inst,"bearger_run_speed")
                end
            else
                inst:AddTag("bearger_run")
                if inst.components.locomotor then
                    inst.components.locomotor:SetExternalSpeedMultiplier(inst,"bearger_run_speed",5/3)
                end
            end
            TransformCool(inst)
        end,

        skill1 = function (inst)
            if not inst:HasTag("mutatedbearger_butt_skill") then
                inst:AddTag("mutatedbearger_butt_skill")
            end
            SkillCool(inst,1,5)
        end,

        stategraphs = {
            skill0 = function(inst)
                if inst:HasTag("mutatedbearger_butt_skill") then
                    return "mutatedbearger_butt_pre"
                else
                    return "bearger_pound"
                end
            end,
        },
    },

    mutateddeerclops = {
        skill = function (act)
            return true
        end,

        sounds = {
            step = "dontstarve/creatures/deerclops/step",
            taunt_grrr = "dontstarve/creatures/deerclops/taunt_grrr",
            taunt_howl = "dontstarve/creatures/deerclops/taunt_howl",
            hurt = "dontstarve/creatures/deerclops/hurt",
            death = "dontstarve/creatures/deerclops/death",
            attack = "dontstarve/creatures/deerclops/attack",
            swipe = "dontstarve/creatures/deerclops/swipe",
            charge = "dontstarve/creatures/deerclops/charge",
            walk = nil,
        },

        transform = function (inst)
            if inst._deerclops_hide then
                inst._deerclops_hide = false
                inst.AnimState:Hide("head_neutral")
            else
                inst._deerclops_hide = true
                inst.AnimState:Show("head_neutral")
            end
            TransformCool(inst)
        end,

        stategraphs = {
            skill0 = "mutateddeerclops_icelance"
        },
    },

    ancient_hulk = {
        skill = function (act)
            return true
        end,

        sounds = {

        },

        transform = function (inst)
            if not inst:HasTag("ancient_hulk_telport") then
                inst:AddTag("ancient_hulk_telport")
            end
            TransformCool(inst,6)
        end,

        skill1 = function (inst)
            if not inst.sg:HasAnyStateTag("busy","hulk_bomb") then
                inst.sg:GoToState("ancient_hulk_bomb_pre")
                SkillCool(inst,1,5)
            end
        end,

        skill2 = function (inst)
            if not inst.sg:HasAnyStateTag("busy","ancient_hulk_spin") then
                inst.sg:GoToState("ancient_hulk_spin")
                SkillCool(inst,2,10)
            end
        end,

        skill3 = function (inst)
            if not inst.sg:HasAnyStateTag("busy","ancient_hulk_barrier") then
                inst.sg:GoToState("ancient_hulk_barrier")
                SkillCool(inst,3,10)
            end
        end,

        stategraphs = {
            skill0 = function(inst)
                if inst:HasTag("ancient_hulk_telport") then
                    return "ancient_hulk_telportout_pre"
                else
                    return "ancient_hulk_lob"
                end
            end,
            map_teleport = "ancient_hulk_telportout_pre",
        },
    },
}

return WEREEPIC_SKILL