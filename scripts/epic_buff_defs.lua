local function nodmgshielded(inst, amount, overtime, cause, ignore_invincible, afflicter, ignore_absorb)
    return amount <= 0
end
local epic_buffs = {
    dragonfly_enraged = {
        duration = 30,
        onattachedfn = function (inst,target)
            target.AnimState:SetBuild(target.dragonfly_yule and "dragonfly_fire_yule_build" or "dragonfly_fire_build")

            target:AddTag("dragonfly_enraged")

            if target.components.locomotor then
                target.components.locomotor:SetExternalSpeedMultiplier(target,"dragonfly_enraged_speed",1.25)
            end
            target.components.combat:SetDefaultDamage(TUNING.DRAGONFLY_FIRE_DAMAGE)
            target.components.combat:SetRange(TUNING.DRAGONFLY_FIRE_HIT_RANGE)

            target.Light:Enable(true)
            target.components.propagator:StartSpreading()

            target.components.moisture:DoDelta(-target.components.moisture:GetMoisture())

            target.components.freezable:SetResistance(TUNING.DRAGONFLY_ENRAGED_FREEZE_THRESHOLD)
        end,
        onextendedfn = nil,
        ondetachedfn = function (inst,target)
            if target:HasTag("epic") and not target.sg:HasStateTag("epic_death") then
                target.sg:GoToState("dragonfly_transform_normal")
            else
                target.SoundEmitter:KillSound("fireflying")

                target:RemoveTag("dragonfly_enraged")

                target.components.locomotor:RemoveExternalSpeedMultiplier(target,"dragonfly_enraged_speed")

                target.components.propagator:StopSpreading()
            end
        end
    },

    stalker_atrium_shield = {
        duration = 10,
        onattachedfn = function (inst,target)
            target:AddTag("stalker_atrium_shield")
            local health = target.components.health or nil
            local wereepic = target.components.wereepic or nil
            if health and wereepic then
                if wereepic.health_redirect==nil then
                    wereepic.health_redirect = health.redirect
                end
                health.redirect = nodmgshielded
            end
        end,
        onextendedfn = nil,
        ondetachedfn = function (inst,target)
            target:RemoveTag("stalker_atrium_shield")
            local health = target.components.health or nil
            local wereepic = target.components.wereepic or nil
            if health and wereepic then
                health.redirect = wereepic.health_redirect
            end
        end
    },
}

return epic_buffs