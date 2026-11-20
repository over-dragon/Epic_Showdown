local EPICVISION_COLOURCUBES = {
    day       = "images/colour_cubes/identity_colourcube.tex",
    dusk      = "images/colour_cubes/identity_colourcube.tex",
    night     = "images/colour_cubes/identity_colourcube.tex",
    full_moon = "images/colour_cubes/identity_colourcube.tex",
}
local EPIC_LMB_ACTIONS =
{
    "CHOP",
    "MINE",
    "DIG",
}
local EPIC_TARGET_EXCLUDE_TAGS = { "FX", "NOCLICK", "DECOR", "INLIMBO", "catchable", "sign" }

local function GetEpicAction(inst, target,left)
    if inst:HasTag("sharkboi_fin") then
        return nil
    end
    for i, v in ipairs(EPIC_LMB_ACTIONS) do
        if target:HasTag(v.."_workable") then
            return not target:HasTag("sign") and (left and inst.components.playeractionpicker:SortActionList({ ACTIONS["EPIC_"..v] }, target, nil) or ACTIONS["EPIC_"..v]) or nil
        end
    end
end

local function LeftClickPicker(inst, target)
    if target ~= nil and target ~= inst then
        if inst:HasTag("sharkboi_fin") then
            return nil
        end
        if inst.replica.combat:CanTarget(target) then
            return (not target:HasTag("player") or inst.components.playercontroller:IsControlPressed(CONTROL_FORCE_ATTACK))
                and inst.components.playeractionpicker:SortActionList({ ACTIONS.ATTACK }, target, nil)
                or nil
        end
        local actions = GetEpicAction(inst, target,true)
        if actions then
            return actions
        end
    end
end

local function RightClickPicker(inst, target, pos)
    if target ~= nil and target ~= inst then
        if inst:HasTag("sharkboi_fin") then
            return inst.components.playeractionpicker:SortActionList({ ACTIONS.EPIC_SKILL }, target or pos, nil)
        end
        local actions =
        (   target:HasTag("HAMMER_workable") and
            inst.components.playeractionpicker:SortActionList({ ACTIONS.EPIC_HAMMER }, target, nil)
        ) or
        (   target:HasTag("DIG_workable") and
            target:HasTag("sign") and
            inst.components.playeractionpicker:SortActionList({ ACTIONS.EPIC_DIG }, target, nil)
        ) or
        (
            target:HasTag("pickable") and
            inst.components.playeractionpicker:SortActionList({ ACTIONS.EPIC_SCYTHE }, target, nil)
        ) or
        nil
        if actions then
            return actions
        end
    elseif inst.checkingmapactions and inst.checkingmapactions_pos and inst:HasTag("epic_map_teleport") then
        local x, y, z = inst.checkingmapactions_pos:Get()
        local mode = inst.replica.wereepic:GetEpicMode()
        if mode=="antlion" or mode=="ancient_hulk" then
            if TheWorld.Map:IsOceanAtPoint(x, y, z) or TheWorld.Map:GetPlatformAtPoint(x, y, z) ~= nil or (mode=="ancient_hulk" and not inst:HasTag("ancient_hulk_telport")) then
                return nil
            else
                return inst.components.playeractionpicker:SortActionList({ ACTIONS.EPIC_MAP_TELEPORT },target or pos, nil)
            end
        elseif mode=="malbatross" then
            if not TheWorld.Map:IsVisualGroundAtPoint(x,y,z) then
                return inst.components.playeractionpicker:SortActionList({ ACTIONS.EPIC_MAP_TELEPORT },target or pos, nil)
            else
                return nil
            end
        end
    end
    return target ~= inst and not inst:HasTag("epic_noskill0")
        and (
                not inst.components.playercontroller.isclientcontrollerattached and
                inst.components.playeractionpicker:SortActionList({ ACTIONS.EPIC_SKILL }, target or pos, nil)
            )
        or nil
end

local function PointSpecialActions(inst, pos, useitem, right)
    return right and inst.components.playercontroller:IsEnabled() and { ACTIONS.EPIC_SKILL } or {}
end

local function EpicActionButton(inst, force_target)
    if not inst.components.playercontroller:IsDoingOrWorking() then
        if force_target == nil then
            local x, y, z = inst.Transform:GetWorldPosition()
            local ents = TheSim:FindEntities(x, y, z, inst.components.playercontroller.directwalking and 3 or 6, nil, EPIC_TARGET_EXCLUDE_TAGS, nil)
            for i, v in ipairs(ents) do
                if v ~= inst and v.entity:IsVisible() and CanEntitySeeTarget(inst, v) then
                    local action = GetEpicAction(inst, v)
                    if action ~= nil then
                        return BufferedAction(inst, v, action)
                    end
                end
            end
        elseif inst:GetDistanceSqToInst(force_target) <= (inst.components.playercontroller.directwalking and 9 or 36) then
            local action = GetEpicAction(inst, force_target)
            if action ~= nil then
                return BufferedAction(inst, force_target, action)
            end
        end
    end
end

local function ReticuleTargetFn(inst)
    local player = ThePlayer
    local ground = TheWorld.Map
    local pos = Vector3()

    for r = 7, 0, -.25 do
        pos.x, pos.y, pos.z = player.entity:LocalToWorldSpace(r, 0, 0)
        if ground:IsPassableAtPoint(pos.x, 0, pos.z, true) and not ground:IsGroundTargetBlocked(pos) then
            break
        end
    end
    return pos
end

local function SetEpicActions(self,isepic)
    if isepic then
        if self.inst.components.playercontroller ~= nil then
            self.actionbuttonoverride = self.inst.components.playercontroller.actionbuttonoverride
            self.inst.components.playercontroller.actionbuttonoverride = EpicActionButton
        end
        if self.inst.components.playeractionpicker ~= nil then
            self.leftclickoverride = self.inst.components.playeractionpicker.leftclickoverride
            self.rightclickoverride = self.inst.components.playeractionpicker.rightclickoverride
            self.pointspecialactionsfn = self.inst.components.playeractionpicker.pointspecialactionsfn
            self.inst.components.playeractionpicker.leftclickoverride = LeftClickPicker
            self.inst.components.playeractionpicker.rightclickoverride = RightClickPicker
            self.inst.components.playeractionpicker.pointspecialactionsfn = PointSpecialActions
        end

        if self.inst.components.reticule == nil then
            self.inst:AddComponent("reticule")
            self.noreticule = true
        else
            self.noreticule = nil
            self.targetfn = self.inst.components.reticule.targetfn
            self.ease = self.inst.components.reticule.ease
            self.twinstickcheckscheme = self.inst.components.reticule.twinstickcheckscheme
            self.twinstickmode = self.inst.components.reticule.twinstickmode
            self.twinstickrange = self.inst.components.reticule.twinstickrange
            self.ispassableatallpoints = self.inst.components.reticule.ispassableatallpoints
        end
        self.inst.components.reticule.targetfn = ReticuleTargetFn
        self.inst.components.reticule.ease = true
        self.inst.components.reticule.twinstickcheckscheme = true
        self.inst.components.reticule.twinstickmode = 1
        self.inst.components.reticule.twinstickrange = 15
        self.inst.components.reticule.ispassableatallpoints = true
        if self.inst.components.playercontroller ~= nil and self.inst == ThePlayer then
            self.inst.components.playercontroller:RefreshReticule()
        end
    else
        if self.inst.components.playercontroller ~= nil then
            self.inst.components.playercontroller.actionbuttonoverride = self.actionbuttonoverride
        end
        if self.inst.components.playeractionpicker ~= nil then
            self.inst.components.playeractionpicker.leftclickoverride = self.leftclickoverride
            self.inst.components.playeractionpicker.rightclickoverride = self.rightclickoverride
            self.inst.components.playeractionpicker.pointspecialactionsfn = self.pointspecialactionsfn
        end
        if self.inst.components.reticule ~= nil then
            if self.noreticule then
                self.inst:RemoveComponent("reticule")
            else
                self.inst.components.reticule.targetfn = self.targetfn
                self.inst.components.reticule.ease = self.ease
                self.inst.components.reticule.twinstickcheckscheme = self.twinstickcheckscheme
                self.inst.components.reticule.twinstickmode = self.twinstickmode
                self.inst.components.reticule.twinstickrange = self.twinstickrange
                self.inst.components.reticule.ispassableatallpoints = self.ispassableatallpoints
            end
            if self.inst.components.playercontroller ~= nil and self.inst == ThePlayer then
                self.inst.components.playercontroller:RefreshReticule()
            end
        end
    end
end

local function OnPlayerActivated(inst)
    inst.HUD.epicOL = inst.HUD.over_root:AddChild(Image("images/global.xml", "square.tex"))
    inst.HUD.epicOL:SetVRegPoint(ANCHOR_MIDDLE)
    inst.HUD.epicOL:SetHRegPoint(ANCHOR_MIDDLE)
    inst.HUD.epicOL:SetVAnchor(ANCHOR_MIDDLE)
    inst.HUD.epicOL:SetHAnchor(ANCHOR_MIDDLE)
    inst.HUD.epicOL:SetScaleMode(SCALEMODE_FILLSCREEN)
    inst.HUD.epicOL:SetClickable(false)
    inst.HUD.epicOL:MoveToFront()
    inst.HUD.epicOL:SetTint(1, 1, 1, 0)
    inst.HUD.epicOL:Hide()
end

local fly_mode = {
    malbatross = true,
    beequeen = true,
    dragonfly = true,
    alterguardian_phase3 = true
}

local WereEpic = Class(function(self, inst)
    self.inst = inst

    self._is_epic = net_bool(inst.GUID, "wereepic._is_epic", "epicdirty")
    self._epic_mode = net_string(inst.GUID, "wereepic._epic_mode","epicmodedirty")
    self._phase2 = net_int(inst.GUID, "alterguardian.epic_phase2_summon","alterguardian_phase2_atk_summon")
    self._mutated_ice = net_bool(inst.GUID, "mutateddeerclops.epic_mutated_ice","mutateddeerclops_epic_mutated_ice")

    if TheWorld.ismastersim then
        self.classified = inst.player_classified
    else
        self:AttachClassified(inst.player_classified)
        -- OnPlayerActivated(inst)
    end

    inst:ListenForEvent("epicdirty", function(inst)
        if self._is_epic:value() then
            if self.actions_installed then return end
            self.actions_installed = true
            self:SetEpicVision()
            SetEpicActions(self,true)
        else
            if not self.actions_installed then return end
            self.actions_installed = false
            self:ClearEpicVision()
            SetEpicActions(self,false)
        end
    end)
    inst:ListenForEvent("epicmodedirty", function(inst)
        if inst.components.wereepic then
            local mode = inst.components.wereepic:GetEpicMode()
            if mode~=self._epic_mode:value() then
                self._epic_mode:set(mode)
            end
        end
    end)
end)

function WereEpic:AttachClassified(classified)
    self.classified = classified
    self.ondetachclassified = function() self:DetachClassified() end
    self.inst:ListenForEvent("onremove", self.ondetachclassified, classified)
end

function WereEpic:DetachClassified()
    self.classified = nil
    self.ondetachclassified = nil
end

function WereEpic:SetEpicVision()
    if self.inst.components.playervision then
        self.inst.components.playervision:PushForcedNightVision("epic_vision", 10, EPICVISION_COLOURCUBES, false)
        if self.inst:HasTag("epic_gogglevision") then
            self.inst.components.playervision:ForceGoggleVision(true)
        end
    end
end

function WereEpic:ClearEpicVision()
    if self.inst.components.playervision then
        self.inst.components.playervision:PopForcedNightVision("epic_vision")
        self.inst.components.playervision:ForceGoggleVision(false)
    end
end

function WereEpic:GetPh2Atk()
    return self._phase2:value()
end

function WereEpic:GetEpicMode()
    return self._epic_mode:value()
end

function WereEpic:IsEpic()
    return self._is_epic:value()
end

return WereEpic