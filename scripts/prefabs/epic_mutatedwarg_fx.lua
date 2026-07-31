local function Mutated_CreateGestaltFlame()
	local inst = CreateEntity()

	inst.entity:AddTransform()
	inst.entity:AddAnimState()
	inst.entity:AddFollower()
    inst.entity:AddNetwork()

	inst.Transform:SetSixFaced()

	inst.AnimState:SetBank("lunar_flame")
	inst.AnimState:SetBuild("lunar_flame")
	inst.AnimState:PlayAnimation("gestalt_eye", true)
	inst.AnimState:SetMultColour(1, 1, 1, 0.6)
	inst.AnimState:SetLightOverride(0.1)
	inst.AnimState:SetBloomEffectHandle("shaders/anim.ksh")
	inst.AnimState:UsePointFiltering(true)

    inst:AddTag("FX")

    inst.entity:SetPristine()

    if not TheWorld.ismastersim then
        return inst
    end

	inst.persists = false

	return inst
end

local function Mutated_CreateEyeFlame()
	local inst = CreateEntity()

	inst.entity:AddTransform()
	inst.entity:AddAnimState()
	inst.entity:AddFollower()
    inst.entity:AddNetwork()

	inst.Transform:SetSixFaced()

	inst.AnimState:SetBank("lunar_flame")
	inst.AnimState:SetBuild("lunar_flame")
	inst.AnimState:PlayAnimation("flameanim", true)
	inst.AnimState:SetMultColour(1, 1, 1, 0.6)
	inst.AnimState:SetLightOverride(0.1)
	inst.AnimState:SetBloomEffectHandle("shaders/anim.ksh")

    inst:AddTag("FX")

    inst.entity:SetPristine()

    if not TheWorld.ismastersim then
        return inst
    end

	inst.persists = false

	return inst
end

local function Mutated_CreateMouthFlame()
	local inst = CreateEntity()

	inst.entity:AddTransform()
	inst.entity:AddAnimState()
	inst.entity:AddFollower()
    inst.entity:AddNetwork()

	inst.Transform:SetSixFaced()

	inst.AnimState:SetBank("lunar_flame")
	inst.AnimState:SetBuild("lunar_flame")
	inst.AnimState:PlayAnimation("mouthflameanim", true)
	inst.AnimState:SetMultColour(1, 1, 1, 0.6)
	inst.AnimState:SetLightOverride(0.1)
	inst.AnimState:SetBloomEffectHandle("shaders/anim.ksh")

    inst:AddTag("FX")

    inst.entity:SetPristine()

    if not TheWorld.ismastersim then
        return inst
    end

	inst.persists = false

	return inst
end

return Prefab("epic_mutatedwarg_gestaltflame_fx", Mutated_CreateGestaltFlame),
    Prefab("epic_mutatedwarg_eyeflame_fx",Mutated_CreateEyeFlame),
    Prefab("epic_mutatedwarg_mouthflame_fx",Mutated_CreateMouthFlame)