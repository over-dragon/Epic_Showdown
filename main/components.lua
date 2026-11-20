local EPIC = require("wereepic_boss")
-- AddComponentPostInit("mightiness", function(self)
--     local old_UpdateSkinMode = self.UpdateSkinMode
--     function self:UpdateSkinMode(skin_data, delay)
--         if self.inst:HasTag("epic") then
--             return
--         else
--             return old_UpdateSkinMode(self,skin_data,delay)
--         end
--     end
-- end)

AddComponentPostInit("skinner", function(self)
    local old_SetSkinMode = self.SetSkinMode
    function self:SetSkinMode(skintype, default_build)
        if self.inst:HasTag("player") and self.inst:HasTag("epic") then
            return
        else
            return old_SetSkinMode(self,skintype,default_build)
        end
    end
end)

AddComponentPostInit("wereness", function(self)
    local old_SetWereMode = self.SetWereMode
    function self:SetWereMode(weremode)
        if self.inst:HasTag("epic") and self.inst:HasTag("player") then
            return
        else
            return old_SetWereMode(self,weremode)
        end
    end

    local old_SetPercent = self.SetPercent
    function self:SetPercent(percent, overtime)
        if self.inst:HasTag("epic") and self.inst:HasTag("player") then
            return
        else
            return old_SetPercent(self,percent,overtime)
        end
    end
end)

AddComponentPostInit("upgrademoduleowner", function(self)
    local old_SetChargeLevel = self.SetChargeLevel
    function self:SetChargeLevel(new_level)
        if self.inst:HasTag("epic") and self.inst:HasTag("player") then
            return
        else
            return old_SetChargeLevel(self,new_level)
        end
    end
end)

AddComponentPostInit("locomotor", function(self)
    local original_ScanForPlatform = self.ScanForPlatform
    function self:ScanForPlatform(...)
        local can_hop, hop_x, hop_z, target_platform, blocked = original_ScanForPlatform(self, ...)

        if self.inst:HasTag("epic") and self.inst:HasTag("player") then
            can_hop = false
            blocked = true
        end

        return can_hop, hop_x, hop_z, target_platform, blocked
    end
end)

AddComponentPostInit("entitytracker", function(self)
    local old_TrackEntity = self.TrackEntity
    function self:TrackEntity(name,inst)
        old_TrackEntity(self,name,inst)
        local dragonfly = inst.components.wereepic and inst.components.wereepic:GetEpicMode() or nil
        if dragonfly=="dragonfly" and self.inst:HasTag("lavae") then
            self.inst:RemoveTag("hostile")
            self.inst:AddTag("NOBLOCK")
            self.inst:AddTag("companion")
            self.inst:ListenForEvent("death",function (inst,data)
                local mother = inst.components.entitytracker:GetEntity("mother")
                if mother then
                    if mother.dragonfly_child then
                        mother.dragonfly_child = mother.dragonfly_child - 1
                    end
                    if mother.components.spellbookcooldowns and mother.components.spellbookcooldowns:IsInCooldown("epic_skill1") then
                        mother.components.spellbookcooldowns:ReduceSpellCooldown("epic_skill1", 0.2)
                    end
                end
            end)
        end
    end
end)

AddComponentPostInit("spellbookcooldowns", function(self)
    function self:ReduceSpellCooldown(spellname, percent)
        local cd = self.cooldowns[hash(spellname)]
        if cd then
            local new_pct = math.max(0, cd:GetPercent() - percent)
            if new_pct <= 0 then
                cd:Remove()
            else
                cd.pct = new_pct
                cd._pct:set(math.max(1, math.ceil(new_pct * 180 - 0.5)))
                cd.syncdelay = 1
            end
        end
    end
end)

AddComponentPostInit("health", function(self)
    local old_SetVal = self.SetVal
    function self:SetVal(val, cause, afflicter)
        if self.inst:HasTag("epic_nextmode") then
            return
        elseif val <= 0 and self.currenthealth > 0 and self.inst:HasTag("epic") and self.inst.isplayer then
            local mode = self.inst.components.wereepic and self.inst.components.wereepic:GetEpicMode()
            local boss = EPIC[mode]
            if boss and boss.nextmode and boss.nextmode.condition(self.inst,afflicter) then
                self.inst:AddTag("epic_nextmode")
                self.inst.sg:HandleEvent("death", { cause = cause, afflicter = afflicter, corpsing = false, epic_nextmode = boss.nextmode.mode})
                return
            end
        end
        return old_SetVal(self, val, cause, afflicter)
    end

    local old_OnSave = self.OnSave
    function self:OnSave()
        local data = old_OnSave(self)
        local wereepic = self.inst.components.wereepic or nil
        if wereepic and wereepic:IsEpic() and data then
            local currenthealth = self.currenthealth/self.maxhealth * wereepic.maxhealth
            data.health = currenthealth
        end
        return data
    end
end)

AddComponentPostInit("cursable", function(self)
    local old_IsCursable = self.IsCursable
    function self:IsCursable(item)
        if self.inst:HasTag("epic") and self.inst:HasTag("player") then
            return false
        else
            return old_IsCursable(self, item)
        end
    end

    -- local old_ApplyCurse = self.ApplyCurse
    -- function self:ApplyCurse(item, curse)
    --     if self.inst:HasTag("epic") and self.inst:HasTag("player") then
    --         self.inst:Remove()
    --     else
    --         return old_ApplyCurse(self, item, curse)
    --     end
    -- end
end)

AddComponentPostInit("playercontroller", function(self)
    local old_GetGroundUseSpecialAction = self.GetGroundUseSpecialAction
    function self:GetGroundUseSpecialAction(position, right)
        --local islocal = position == nil
        if self.inst:HasTag("epic") then
            position = position or
                (self.reticule ~= nil and self.reticule.targetpos) or
                (self.terraformer ~= nil and self.terraformer:GetPosition()) or
                self:GetPlacerPosition() or
                self.inst:GetPosition()

            return CanEntitySeePoint(self.inst, position:Get())
                and self.inst.components.playeractionpicker:GetPointSpecialActions(position, nil, right)[1]
                or nil
        else
            return old_GetGroundUseSpecialAction(self,position,right)
        end
    end

    local old_DoAttackButton = self.DoAttackButton
    function self:DoAttackButton(retarget, isleftmouse)
        if self.inst:HasTag("sharkboi_fin") then
            return
        end
        return old_DoAttackButton(self, retarget, isleftmouse)
    end

    local old_DoControllerAttackButton = self.DoControllerAttackButton
    function self:DoControllerAttackButton(target)
        if self.inst:HasTag("sharkboi_fin") then
            return
        end
        return old_DoControllerAttackButton(self, target)
    end
end)

AddComponentPostInit("combat", function(self)
    local old_CanTarget = self.CanTarget
    function self:CanTarget(target)
        if self.inst.isplayer and TUNING.EPIC_WORLD.COMBAT_TARGET~=0 and self.inst:HasTag("epic") and target and target:IsValid() and target:HasTag("companion") then
            return (target.components.combat and target.components.combat.target==self.inst or self.target==target) and old_CanTarget(self,target)
        else
            return old_CanTarget(self,target)
        end
    end
end)