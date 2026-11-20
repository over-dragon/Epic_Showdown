local EPIC = require("wereepic_skill")

AddModRPCHandler("WEREEPIC", "taunt", function(inst)
    if inst and inst.replica.wereepic:IsEpic() then
        local mode = inst.components.wereepic and inst.components.wereepic:GetEpicMode()
        if mode=="sharkboi" and inst:HasTag("sharkboi_fin") then
            return
        elseif EPIC[mode] and not inst.sg:HasAnyStateTag("epic_death","epic_taunt","busy") and not inst.components.spellbookcooldowns:IsInCooldown("epic_taunt") then
            inst.sg:GoToState(EPIC_SHOWDOWN_TUNING.EPIC_TAUNT[mode] or "epic_taunt")
            inst.components.spellbookcooldowns:RestartSpellCooldown("epic_taunt", 1)
        end
    end
end)

AddModRPCHandler("WEREEPIC", "transform", function(inst)
    if inst and inst.replica.wereepic:IsEpic() then
        local mode = inst.components.wereepic and inst.components.wereepic:GetEpicMode()
        if EPIC[mode] and EPIC[mode].transform then
            EPIC[mode].transform(inst)
        end
    end
end)

AddModRPCHandler("WEREEPIC", "onbecamehuman", function(inst)
    if inst and inst.replica.wereepic:IsEpic() then
        local mode = inst.components.wereepic and inst.components.wereepic:GetEpicMode()
        if EPIC[mode] and not inst.sg:HasStateTag("epic_death") and not inst.sg:HasStateTag("stalker_atrium_death_pre") then
            if mode=="stalker_atrium" then
                inst.sg:GoToState("stalker_atrium_death_pre")
            else
                inst.sg:GoToState(EPIC_SHOWDOWN_TUNING.EPIC_DEATH[mode] or "epic_death")
            end
        end
    end
end)

AddModRPCHandler("WEREEPIC", "skill1", function(inst)
    if inst and inst.replica.wereepic:IsEpic() then
        local mode = inst.components.wereepic and inst.components.wereepic:GetEpicMode()
        if EPIC[mode] and EPIC[mode].skill1 then
            EPIC[mode].skill1(inst)
        end
    end
end)

AddModRPCHandler("WEREEPIC", "skill2", function(inst)
    if inst and inst.replica.wereepic:IsEpic() then
        local mode = inst.components.wereepic and inst.components.wereepic:GetEpicMode()
        if EPIC[mode] and EPIC[mode].skill2 then
            EPIC[mode].skill2(inst)
        end
    end
end)

AddModRPCHandler("WEREEPIC", "skill3", function(inst)
    if inst and inst.replica.wereepic:IsEpic() then
        local mode = inst.components.wereepic and inst.components.wereepic:GetEpicMode()
        if EPIC[mode] and EPIC[mode].skill3 then
            EPIC[mode].skill3(inst)
        end
    end
end)