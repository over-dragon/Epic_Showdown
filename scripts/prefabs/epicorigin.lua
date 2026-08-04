local Origin = require("epic_keepsakes")

local prefabs =
{
    "epic_castfx"
}

local function OnDischarged(inst)
    inst:AddTag("epicorigin_discharged")
end

local function OnCharged(inst)
    inst:RemoveTag("epicorigin_discharged")
end

local function MakeEpicOrigin(epic_mode)
    local assets =
    {
        Asset("ANIM", "anim/epic_origin.zip"),
        Asset("IMAGE","images/inventoryimages/"..epic_mode.."_origin.tex"),
	    Asset("ATLAS", "images/inventoryimages/"..epic_mode.."_origin.xml"),
    }

    local function fn()
        local inst = CreateEntity()

        inst.entity:AddTransform()
        inst.entity:AddAnimState()
        inst.entity:AddLight()
        inst.entity:AddNetwork()

        MakeInventoryPhysics(inst)

        inst.AnimState:SetBank("epic_origin")
        inst.AnimState:SetBuild("epic_origin")
        inst.AnimState:PlayAnimation(epic_mode,true)
        inst.scrapbook_anim = epic_mode

        inst:AddTag("epicorigin")
        inst:AddTag(epic_mode.."_origin")

        inst.Light:SetFalloff(0.8)
        inst.Light:SetIntensity(.7)
        inst.Light:SetRadius(1)
        inst.Light:SetColour(150 / 255, 180 / 255, 200 / 255)
        inst.Light:Enable(true)

        inst.entity:SetPristine()

        if not TheWorld.ismastersim then
            return inst
        end

        inst:AddComponent("inspectable")
        inst:AddComponent("inventoryitem")
        inst.components.inventoryitem.imagename = epic_mode.."_origin"
        inst.components.inventoryitem.atlasname = "images/inventoryimages/"..epic_mode.."_origin.xml"
        inst.components.inventoryitem.nobounce = true

        inst:AddComponent("wereepic_useableitem")

        inst:AddComponent("rechargeable")
        inst.components.rechargeable:SetOnDischargedFn(OnDischarged)
        inst.components.rechargeable:SetOnChargedFn(OnCharged)

        inst.epic_mode = epic_mode

        return inst
    end

    return Prefab(epic_mode.."_origin", fn, assets, prefabs)
end

local ret = {}
for i, v in ipairs(Origin) do
    table.insert(ret, MakeEpicOrigin(v.name))
end

return unpack(ret)