local assets =
{
    Asset("ANIM", "anim/epic_casting_fx.zip"),
    Asset("ANIM", "anim/epic_keepsakes_fx.zip")
}

--------------------------------------------------------------------------------------------------------------

local function OverrideSymbol(inst,mode)
    inst.AnimState:OverrideSymbol("keepsake","epic_keepsakes_fx",mode)
end

local function MakeFx(data)
    local function fn()
        local inst = CreateEntity()

        inst.entity:AddTransform()
        inst.entity:AddAnimState()
        inst.entity:AddSoundEmitter()
        inst.entity:AddNetwork()

        inst:AddTag("FX")

        inst.Transform:SetFourFaced()

        inst.AnimState:SetBank("epic_casting_fx")
        inst.AnimState:SetBuild("epic_casting_fx")
        inst.AnimState:PlayAnimation(data.anim)
        inst.AnimState:SetFinalOffset(1)

        if data.commonpostinit ~= nil then
            data.commonpostinit(inst, data)
        end

        inst.entity:SetPristine()

        if not TheWorld.ismastersim then
            return inst
        end

        inst.persists = false

        inst.symbol = OverrideSymbol

        inst:ListenForEvent("animover", inst.Remove)

        return inst
    end

    return Prefab(data.name, fn, assets)
end

--------------------------------------------------------------------------------------------------------------
local function PureBrilliancePostInit(inst, data)
    inst.AnimState:SetBloomEffectHandle("shaders/anim.ksh")
    inst.AnimState:SetSymbolLightOverride("pb_energy_loop", .3)
    inst.AnimState:SetSymbolLightOverride("pb_ray", .3)
    inst.AnimState:SetSymbolLightOverride("SparkleBit", .3)
    inst.AnimState:SetLightOverride(.1)
end
--------------------------------------------------------------------------------------------------------------

return
    MakeFx({
        name = "epic_castfx",
        anim = "epic_cast",
        commonpostinit = PureBrilliancePostInit,
    })
