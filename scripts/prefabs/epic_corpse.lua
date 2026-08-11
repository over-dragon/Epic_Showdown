local EPIC = require("wereepic_boss")

local function MakeCorpse(name,data)
    local function fn()
        local inst = CreateEntity()
        inst.entity:AddTransform()
        inst.entity:AddNetwork()
        inst.entity:AddAnimState()

        local s = data.scale or 1
        inst.Transform:SetScale(s,s,s)

        if string.find(name,"alterguardian") then
            inst.AnimState:SetBank("alterguardian_spawn_death")
            inst.AnimState:SetBuild("alterguardian_spawn_death")
        else
            inst.AnimState:SetBank(data.bank)
            inst.AnimState:SetBuild(data.build)
        end

        inst.AnimState:SetFinalOffset(-1)
        if name=="daywalker" or name=="daywalker2" then
            inst.AnimState:PlayAnimation("defeat_idle_pre")
            inst.AnimState:PushAnimation("defeat_idle_loop",true)
        elseif name=="alterguardian_phase1" then
            inst.AnimState:PlayAnimation("phase1_death_idle")
        elseif name=="alterguardian_phase2" then
            inst.AnimState:PlayAnimation("phase2_death_idle")
        elseif name=="alterguardian_phase3" then
            inst.AnimState:PlayAnimation("phase3_death_pst")
        elseif name=="stalker_atrium" then
            inst.AnimState:PlayAnimation("death3")
        elseif name=="ancient_hulk" then
            inst.AnimState:PlayAnimation("death")
        else
            inst.AnimState:PlayAnimation("corpse")
        end

        if name=="daywalker2" then
            inst.AnimState:AddOverrideBuild("daywalker_phase3")
        end

        inst:AddTag("FX")
        inst:AddTag("NOCLICK")
        inst.entity:SetPristine()
        if not TheWorld.ismastersim then
            return inst
        end

        inst.persists=false
        return inst
    end

    return Prefab("epic_"..name.."_corpse",fn)
end

local ret = {}
for k, v in pairs(EPIC) do
    table.insert(ret, MakeCorpse(k,v))
end

return unpack(ret)