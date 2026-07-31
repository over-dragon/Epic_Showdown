local EPIC = require("wereepic_boss")
AddPlayerPostInit(function(inst)
    if not TheWorld.ismastersim then
		return inst
	end

    inst:AddComponent("wereepic")

    -- local old_OnDespawn = inst.OnDespawn
    -- inst.OnDespawn = function (inst, migrationdata, ...)
    --     if old_OnDespawn then
    --         return old_OnDespawn(inst,migrationdata,...)
    --     end
    -- end

    -- local old_OnSave = inst.OnSave
    -- inst.OnSave = function (inst,data,...)
    --     if old_OnSave then
    --         old_OnSave(inst,data,...)
    --     end
    -- end

    -- local old_OnPreLoad = inst.OnPreLoad
    -- inst.OnPreLoad = function (inst,data,...)
    --     if old_OnPreLoad then
    --         old_OnPreLoad(inst,data,...)
    --     end
    -- end

    -- local old_OnLoad = inst.OnLoad
    -- inst.OnLoad = function (inst,data,...)
    --     if old_OnLoad then
    --         old_OnLoad(inst,data,...)
    --     end
    -- end
end)


AddPrefabPostInit("wurt", function(inst)
    if not TheWorld.ismastersim then
		return inst
	end
local function EpicHealth(inst)
    if inst:HasTag("epic") then
        inst:DoTaskInTime(0,function()
            local mode = inst.components.wereepic and inst.components.wereepic:GetEpicMode()
            if inst.components.health then
                local ratio=inst.components.health.currenthealth/inst.components.health.maxhealth
                inst.components.health:SetMaxHealth(EPIC[mode].health)
                inst.components.health:SetCurrentHealth(EPIC[mode].health*ratio)
                inst.components.health:DoDelta(0.01,true)
            end
        end)
    end
end

    inst:ListenForEvent("onmermkingcreated_anywhere", function() EpicHealth(inst) end, TheWorld)
    inst:ListenForEvent("onmermkingdestroyed_anywhere", function() EpicHealth(inst) end, TheWorld)
end)

AddPrefabPostInit("beeguard", function(inst)
    if not TheWorld.ismastersim then
		return inst
	end

local function BeeSort(a, b) -- Better than assumption!
    return a.GUID < b.GUID
end

local function AddFriendListener(inst, friend)
    inst._friendref = friend
    inst._friendrefcallback = function()
        inst._friendref = nil
        inst:StartFindingPlayerQueenTasks()
    end
    inst._friendreflistener = inst:ListenForEvent("onremove", inst._friendrefcallback, inst._friendref)
end

local function RemoveFriendListener(inst)
    if inst._friendreflistener then
        inst:RemoveEventCallback("onremove", inst._friendrefcallback, inst._friendref)
        inst._friendref = nil
        inst._friendrefcallback = nil
        inst._friendreflistener = nil
    end
end

local function OnGotCommander(inst, data)
    local queen = inst:GetQueen()
    if queen ~= data.commander then
        local realqueen = false
        if data.commander:HasTag("player") and data.commander:HasTag("beequeen") then
            inst.components.entitytracker:ForgetEntity("queen")
            RemoveFriendListener(inst)
            inst:MakeFriendly(data.commander.userid)
            AddFriendListener(inst, data.commander)
            inst.components.entitytracker:TrackEntity("queen", data.commander)
            realqueen = true
        end

        local allbeeguards = data.commander.components.commander:GetAllSoldiers("beeguard")
        local totalbeeguards = #allbeeguards
        if totalbeeguards > 0 then
            table.sort(allbeeguards, BeeSort)
            local radius = TUNING.BEEGUARD_GUARD_RANGE
            local qx, qy, qz = data.commander.Transform:GetWorldPosition()
            for i, v in ipairs(allbeeguards) do
                local angle = PI2 * (i - math.random()) / totalbeeguards
                local radiusoffset = math.random() * 2 - 1 + 2 * (i % 2)
                local offset = Vector3((radius + radiusoffset) * math.cos(angle), 0, (radius + radiusoffset) * math.sin(angle))
                v.components.knownlocations:RememberLocation("queenoffset", offset, false)

				-- NOTES(JBK): This is an edge case hack fixup so these bees do not get lost from being too far from a real Bee Queen.
				-- V2C: Updated hack to use sleep status instead of range.
				if realqueen and v:IsAsleep() then
					if v.components.health:IsDead() or v.sg:HasStateTag("flight") then
						v:Remove()
					elseif v.components.rooted == nil then
						v.Physics:Teleport(qx + offset.x, qy + offset.y, qz + offset.z)
						if not data.commander:IsAsleep() then
							v.sg:GoToState("spawnin", data.commander)
						end
					end
                end
            end
        end
    end
end

local function CheckBeeQueen(inst, data)
    local commander = inst:GetQueen()
    local target = data.target

    if target ~= nil and target:HasTag("beequeen") and target:HasTag("player") and commander then
        inst:MakeHostile()
        commander.components.commander:RemoveSoldier(inst)
        inst:AddToArmy(target)

        if target.components.combat:HasTarget() then
            inst.components.combat:SetTarget(target.components.combat.target)
        else
            inst.components.combat:SetTarget(commander)
        end
    end
end

local function OnNewTarget(inst, data)
    inst:DoTaskInTime(0.2, CheckBeeQueen, data)
end
local function OnNewCommander(inst, data)
    inst:DoTaskInTime(0.2, OnGotCommander, data)
end

    inst:ListenForEvent("gotcommander", OnNewCommander)
    inst:ListenForEvent("newcombattarget", OnNewTarget)
end)

AddPrefabPostInit("gestalt", function(inst)
    if not TheWorld.ismastersim then
		return inst
	end
    local combat = inst.components.combat or nil
    if combat then
        local old_targetfn = combat.targetfn
        combat.targetfn = function (inst)
            if inst.tracking_target and inst.tracking_target:HasTag("epic_lunar") then
                return nil
            else
                return old_targetfn(inst)
            end
        end
    end
end)

-- local hound = { "hound","firehound","icehound" }
-- for i, v in ipairs(hound) do
--     AddPrefabPostInit(v, function(inst)
--         if not TheWorld.ismastersim then
--             return inst
--         end
--         local follower = inst.components.follower or nil
--         if follower then
--             local old_OnChangedLeader = follower.OnChangedLeader
--             follower.OnChangedLeader = function (inst, new, old)
--                 if new and new:HasTag("epic") and new:HasTag("player") then
--                     inst.forcemutate = true
--                     inst.wargleader = new
--                     follower:KeepLeaderOnAttacked()
--                 else
--                     return old_OnChangedLeader(inst, new, old)
--                 end
--             end
--         end
--     end)
-- end

-- AddPrefabPostInit("wanda", function(inst)
--     if not TheWorld.ismastersim then
-- 		return inst
-- 	end
-- local function becomenew(inst)
--     local mode = inst.components.wereepic and inst.components.wereepic:GetEpicMode()
--     local build = EPIC[mode].build
--     if build=="deerclops_build" then
--         build="deerclops_yule"
--     end
--     if build then
--         inst.AnimState:SetBuild(build)
--     end

--     inst:DoTaskInTime(0,function ()
--         local currbuild = inst.AnimState:GetBuild()
--         if currbuild~=build then
--             inst.AnimState:SetBuild(build)
--         end
--     end)
-- end

-- local function onhealthchange(inst)
--     if inst:HasTag("playerghost") or
--         inst.components.health and inst.components.health:IsDead() or not inst:HasTag("epic") then
--         return
--     end
--     becomenew(inst)
-- end

--     inst:ListenForEvent("healthdelta", onhealthchange)
-- end)

-- AddPrefabPostInit("wormwood", function(inst)
--     if not TheWorld.ismastersim then
-- 		return inst
-- 	end
--     local bloomness = inst.components.bloomness
--     if bloomness then
--         local old_onlevelchangedfn = bloomness.onlevelchangedfn
--         bloomness.onlevelchangedfn = function (inst,stage)
--             old_onlevelchangedfn(inst,stage)
--             if inst:HasTag("epic") then
--                 local mode = inst.components.wereepic and inst.components.wereepic:GetEpicMode()
--                 inst.AnimState:SetBuild(EPIC[mode].build)
--             end
--         end
--     end

--     local old_UpdateBloomStage = inst.UpdateBloomStage
--     inst.UpdateBloomStage = function (inst,stage)
--         old_UpdateBloomStage(inst,stage)
--         if inst:HasTag("epic") then
--             local mode = inst.components.wereepic and inst.components.wereepic:GetEpicMode()
--             inst.AnimState:SetBuild(EPIC[mode].build)
--         end
--     end
-- end)