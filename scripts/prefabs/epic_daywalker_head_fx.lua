local function CreateEyeFlame()
	local inst = CreateEntity()

	inst:AddTag("FX")

	inst.entity:AddTransform()
	inst.entity:AddAnimState()
	inst.entity:AddFollower()
    inst.entity:AddNetwork()

	inst.Transform:SetFourFaced()

	inst.AnimState:SetBank("daywalker")
	inst.AnimState:SetBuild("daywalker_build")
	inst.AnimState:PlayAnimation("flame_loop", true)
	inst.AnimState:SetLightOverride(1)

    inst.entity:SetPristine()

    if not TheWorld.ismastersim then
        return inst
    end

    inst.persists = false

	return inst
end

local function CreateHead()
	local inst = CreateEntity()

	inst:AddTag("FX")

	inst.entity:AddTransform()
	inst.entity:AddAnimState()
	inst.entity:AddFollower()
    inst.entity:AddNetwork()

	inst.Transform:SetFourFaced()

	inst.AnimState:SetBank("daywalker")
	inst.AnimState:SetBuild("daywalker_build")
	inst.AnimState:PlayAnimation("head", true)

    inst.entity:SetPristine()

    if not TheWorld.ismastersim then
        return inst
    end

	inst.eye = SpawnPrefab("daywalker_eye")
	inst.eye.entity:SetParent(inst.entity)
	inst.eye.Follower:FollowSymbol(inst.GUID, "follow_eye", nil, nil, nil, true, true)

	return inst
end

return Prefab("daywalker_head", CreateHead),
    Prefab("daywalker_eye",CreateEyeFlame)