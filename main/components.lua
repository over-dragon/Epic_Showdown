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