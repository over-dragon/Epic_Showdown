local EPIC = require("wereepic_boss")

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

local function GetEpicAction(inst, target)
    for i, v in ipairs(EPIC_LMB_ACTIONS) do
        if target:HasTag(v.."_workable") then
            return not target:HasTag("sign") and ACTIONS["EPIC_"..v] or nil
        end
    end
end

local function LeftClickPicker(inst, target)
    if target ~= nil and target ~= inst then
        if inst.replica.combat:CanTarget(target) then
            return (not target:HasTag("player") or inst.components.playercontroller:IsControlPressed(CONTROL_FORCE_ATTACK))
                and inst.components.playeractionpicker:SortActionList({ ACTIONS.ATTACK }, target, nil)
                or nil
        end
        local actions = GetEpicAction(inst, target)
        if actions then
            return actions
        end
    end
end

local function RightClickPicker(inst, target, pos)
    if target ~= nil and target ~= inst then
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
        if mode=="antlion" then
            if TheWorld.Map:IsOceanAtPoint(x, y, z) or TheWorld.Map:GetPlatformAtPoint(x, y, z) ~= nil then
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
    return target ~= inst
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
    else
        if self.inst.components.playercontroller ~= nil then
            self.inst.components.playercontroller.actionbuttonoverride = self.actionbuttonoverride
        end
        if self.inst.components.playeractionpicker ~= nil then
            self.inst.components.playeractionpicker.leftclickoverride = self.leftclickoverride
            self.inst.components.playeractionpicker.rightclickoverride = self.rightclickoverride
            self.inst.components.playeractionpicker.pointspecialactionsfn = self.pointspecialactionsfn
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

    if TheWorld.ismastersim then
        self.classified = inst.player_classified
    else
        self:AttachClassified(inst.player_classified)
        -- OnPlayerActivated(inst)
    end

    inst:ListenForEvent("epicdirty", function(inst)
        if self._is_epic:value() then
            self:SetEpicVision()
            SetEpicActions(self,true)
            if not TheWorld.ismastersim then
                if EPIC[self._epic_mode:value()] and TUNING.EPIC_WORLD.BGM==1 then
                    TheWorld:PushEvent("enabledynamicmusic", false)
                    if not TheFocalPoint.SoundEmitter:PlayingSound("epicmusic") then
                        TheFocalPoint.SoundEmitter:PlaySound(
                            EPIC[self._epic_mode:value()].music,"epicmusic")
                    end
                end
                if inst:HasTag("epic_gogglevision") then
                    inst:PushEvent("gogglevision", { enabled = true })
                end
                if self.inst.HUD and self.inst.HUD.controls.epiccastselect then
                    self.inst.HUD.controls.epiccastselect:Show()
                end
                if fly_mode[self._epic_mode:value()] then
                    if inst.components.locomotor then
                        inst.components.locomotor:EnableGroundSpeedMultiplier(false)
                    end
                end
            end
        else
            self:ClearEpicVision()
            SetEpicActions(self,false)
            if not TheWorld.ismastersim then
                TheWorld:PushEvent("enabledynamicmusic", true)
                TheFocalPoint.SoundEmitter:KillSound("epicmusic")
                inst:PushEvent("gogglevision", { enabled = false })
                if self.inst.HUD and self.inst.HUD.controls.epiccastselect then
                    self.inst.HUD.controls.epiccastselect:Hide()
                end
                if inst.components.locomotor then
                    inst.components.locomotor:EnableGroundSpeedMultiplier(true)
                end
            end
        end
    end)
    inst:ListenForEvent("epicmodedirty", function(inst)
        if inst.components.wereepic then
            local mode = inst.components.wereepic:GetEpicMode()
            if mode~=self._epic_mode:value() then
                self:SetEpicMode(mode)
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
        self.inst.components.playervision:PushForcedNightVision(self.inst, 10, EPICVISION_COLOURCUBES, false)
    end
end

function WereEpic:ClearEpicVision()
    if self.inst.components.playervision then
        self.inst.components.playervision:PopForcedNightVision(self.inst)
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