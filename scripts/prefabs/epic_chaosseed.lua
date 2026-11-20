local easing = require("easing")

local assets =
{
    Asset("ANIM", "anim/epic_chaos_seed.zip"),
}

local assets_icon =
{
    Asset("IMAGE", "images/map_icons/epic_chaosseed.tex"),
    Asset("ATLAS", "images/map_icons/epic_chaosseed.xml"),
}

local prefabs =
{
    "epic_chaosseed_icon",
}

local prefabs_icon =
{
    "globalmapicon",
}

local function cancelblink(inst)
    if inst._blinktask ~= nil then
        inst._blinktask:Cancel()
        inst._blinktask = nil
    end
end

local function updateblink(inst, data)
    local c = easing.outQuad(data.blink, 0, 1, 1)
    inst.AnimState:SetAddColour(c, c, c, 0)
    if data.blink > 0 then
        data.blink = math.max(0, data.blink - .05)
    else
        inst._blinktask:Cancel()
        inst._blinktask = nil
    end
end

local function blink(inst)
    if inst._blinktask ~= nil then
        inst._blinktask:Cancel()
    end
    local data = { blink = 1 }
    inst._blinktask = inst:DoPeriodicTask(FRAMES, updateblink, nil, data)
    updateblink(inst, data)
end

local function dodropsound(inst, taskid, volume)
    inst.SoundEmitter:PlaySound("dontstarve/movement/bodyfall_dirt", nil, volume)
    inst._tasks[taskid] = nil
end

local function canceldropsounds(inst)
    local k, v = next(inst._tasks)
    while k ~= nil do
        v:Cancel()
        inst._tasks[k] = nil
        k, v = next(inst._tasks)
    end
end

local function scheduledropsounds(inst)
    inst._tasks[1] = inst:DoTaskInTime(6 * FRAMES, dodropsound, 1)
    inst._tasks[2] = inst:DoTaskInTime(13 * FRAMES, dodropsound, 2, .5)
    inst._tasks[3] = inst:DoTaskInTime(18 * FRAMES, dodropsound, 2, .15)
end

local function onturnon(inst)
    if not inst.SoundEmitter:PlayingSound("idlesound") then
        inst.SoundEmitter:PlaySound("dontstarve/common/together/celestial_orb/idle_LP", "idlesound")
    end
end

local function onturnoff(inst)
    canceldropsounds(inst)
    inst.SoundEmitter:KillSound("idlesound")
    if not inst.components.inventoryitem:IsHeld() then
        scheduledropsounds(inst)
    end
end

local function onactivate(inst)
    blink(inst)
    inst.SoundEmitter:PlaySound("dontstarve/common/together/celestial_orb/active")
    inst._fx:push()
end

local function storeincontainer(inst, container)
    if container ~= nil and container.components.container ~= nil then
        inst:ListenForEvent("onputininventory", inst._oncontainerownerchanged, container)
        inst:ListenForEvent("ondropped", inst._oncontainerownerchanged, container)
        inst:ListenForEvent("onremove", inst._oncontainerremoved, container)
        inst._container = container
    end
end

local function unstore(inst)
    if inst._container ~= nil then
        inst:RemoveEventCallback("onputininventory", inst._oncontainerownerchanged, inst._container)
        inst:RemoveEventCallback("ondropped", inst._oncontainerownerchanged, inst._container)
        inst:RemoveEventCallback("onremove", inst._oncontainerremoved, inst._container)
        inst._container = nil
    end
end

local function tostore(inst, owner)
    if inst._container ~= owner then
        unstore(inst)
        storeincontainer(inst, owner)
    end
    owner = owner.components.inventoryitem ~= nil and owner.components.inventoryitem:GetGrandOwner() or owner
    if inst._owner ~= owner then
        inst._owner = owner
        inst.icon.entity:SetParent(owner.entity)
    end
end

local function topocket(inst, owner)
    cancelblink(inst)
    onturnoff(inst)
    tostore(inst, owner)
end

local function toground(inst)
    if inst.components.prototyper.on then
        onturnon(inst)
    end
    unstore(inst)
    inst._owner = nil
    inst.icon.entity:SetParent(inst.entity)
end

local function OnFX(inst)
    if not inst:HasTag("INLIMBO") then
        local fx = CreateEntity()

        fx:AddTag("FX")
        --[[Non-networked entity]]
        fx.entity:SetCanSleep(false)
        fx.persists = false

        fx.entity:AddTransform()
        fx.entity:AddAnimState()

        fx.Transform:SetFromProxy(inst.GUID)

        fx.AnimState:SetBank("epic_chaos_seed")
        fx.AnimState:SetBuild("epic_chaos_seed")
        fx.AnimState:PlayAnimation("use")
        fx.AnimState:SetFinalOffset(3)

        fx:ListenForEvent("animover", fx.Remove)
    end
end

local function OnSpawned(inst)
    if not (inst.components.prototyper.on or inst.components.inventoryitem:IsHeld()) then
        canceldropsounds(inst)
        scheduledropsounds(inst)
    end
end

local function OnRemoveEntity(inst)
    if inst.icon ~= nil then
        inst.icon:Remove()
    end
end

local function OnHaunt(inst,doer)
    if doer:HasTag("playerghost") then
        doer:PushEvent("respawnfromghost", { source = inst })
        local health = doer.components.health or nil
        local sanity = doer.components.sanity or nil
        if health then
            health:DoDelta(-49,false, nil, true)
        end
        if sanity then
            sanity.current = 0
        end
        return true
    else
        return false
    end
end

local function fn()
    local inst = CreateEntity()

    inst.entity:AddTransform()
    inst.entity:AddAnimState()
    inst.entity:AddSoundEmitter()
    inst.entity:AddLight()
    inst.entity:AddNetwork()

    MakeInventoryPhysics(inst)

    inst.AnimState:SetBank("epic_chaos_seed")
    inst.AnimState:SetBuild("epic_chaos_seed")
    inst.AnimState:PlayAnimation("proximity_loop",true)

    inst:AddTag("irreplaceable")
    inst:AddTag("nonpotatable")
	inst:AddTag("epicorigin_station")
    inst:AddTag("outofreach")

    inst._fx = net_event(inst.GUID, "chaosseed._fx")

    inst.Light:SetFalloff(0.8)
    inst.Light:SetIntensity(.7)
    inst.Light:SetRadius(2)
    inst.Light:SetColour(150 / 255, 180 / 255, 200 / 255)
    inst.Light:Enable(true)

    if not TheNet:IsDedicated() then
        inst:ListenForEvent("chaosseed._fx", OnFX)
    end

    inst.entity:SetPristine()

    if not TheWorld.ismastersim then
        return inst
    end

    inst._tasks = {}
    inst._owner = nil
    inst._container = nil

    inst._oncontainerownerchanged = function(container)
        tostore(inst, container)
    end

    inst._oncontainerremoved = function()
        unstore(inst)
    end

    inst:AddComponent("inspectable")

    inst:AddComponent("inventoryitem")
    inst.components.inventoryitem.nobounce = true

    inst:AddComponent("prototyper")
    inst.components.prototyper.onturnon = onturnon
    inst.components.prototyper.onturnoff = onturnoff
    inst.components.prototyper.onactivate = onactivate
    inst.components.prototyper.trees = TUNING.PROTOTYPER_TREES.EPICORIGIN_TWO

    inst:AddComponent("hauntable")
    inst.components.hauntable:SetOnHauntFn(OnHaunt)

    inst.icon = SpawnPrefab("epic_chaosseed_icon")
    inst.icon.entity:SetParent(inst.entity)
    inst:ListenForEvent("onputininventory", topocket)
    inst:ListenForEvent("ondropped", toground)

    inst.OnSpawned = OnSpawned
    inst.OnRemoveEntity = OnRemoveEntity

    return inst
end

local function icon_init(inst)
    inst.icon = SpawnPrefab("globalmapicon")
    inst.icon.MiniMapEntity:SetPriority(11)
    inst.icon:TrackEntity(inst)
end

local function iconfn()
    local inst = CreateEntity()

    inst.entity:AddTransform()
    inst.entity:AddMiniMapEntity()
    inst.entity:AddNetwork()

    inst.MiniMapEntity:SetIcon("epic_chaosseed.tex")
    inst.MiniMapEntity:SetPriority(11)
    inst.MiniMapEntity:SetCanUseCache(false)
    inst.MiniMapEntity:SetDrawOverFogOfWar(true)

    inst:AddTag("CLASSIFIED")

    inst.entity:SetPristine()

    if not TheWorld.ismastersim then
        return inst
    end

    inst.icon = nil
    inst:DoTaskInTime(0, icon_init)
	inst.OnRemoveEntity = OnRemoveEntity
    inst.persists = false

    return inst
end

return Prefab("epic_chaosseed", fn, assets, prefabs),
    Prefab("epic_chaosseed_icon", iconfn, assets_icon, prefabs_icon)
