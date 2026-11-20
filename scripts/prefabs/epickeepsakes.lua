local Keepsakes = require("epic_keepsakes")

local prefabs =
{
    "epic_castfx"
}

local function MakeEpicKeepsake(epic_mode)
    local assets =
    {
        Asset("ANIM", "anim/epic_keepsakes.zip"),
    }

    local function fn()
        local inst = CreateEntity()

        inst.entity:AddTransform()
        inst.entity:AddAnimState()
        inst.entity:AddNetwork()

        MakeInventoryPhysics(inst)

        inst.AnimState:SetBank("epic_keepsakes")
        inst.AnimState:SetBuild("epic_keepsakes")
        inst.AnimState:PlayAnimation(epic_mode)
        inst.AnimState:SetHaunted(true)
        inst.scrapbook_anim = epic_mode

        inst:AddTag("epickeepsake")
        inst:AddTag(epic_mode.."_keepsake")

        MakeInventoryFloatable(inst, "small", .15, { 1.3, 1.1, 1.3 })

        inst.entity:SetPristine()

        if not TheWorld.ismastersim then
            return inst
        end

        inst:AddComponent("inspectable")
        inst:AddComponent("inventoryitem")

        inst:AddComponent("wereepic_useableitem")

        inst:AddComponent("finiteuses")
        inst.components.finiteuses:SetMaxUses(3)
        inst.components.finiteuses:SetUses(3)
        inst.components.finiteuses:SetConsumption(ACTIONS.EPIC_USEITEM, 1)
        inst.components.finiteuses:SetOnFinished(inst.Remove)

        inst.epic_mode = epic_mode

        return inst
    end

    return Prefab(epic_mode.."_keepsake", fn, assets, prefabs)
end

local ret = {}
for i, v in ipairs(Keepsakes) do
    table.insert(ret, MakeEpicKeepsake(v.name))
end

return unpack(ret)