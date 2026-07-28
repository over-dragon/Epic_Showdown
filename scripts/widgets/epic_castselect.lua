local Widget = require "widgets/widget"
local UIAnim = require "widgets/uianim"
local PlayerBadge = require "widgets/playerbadge"
local easing = require "easing"
local EPIC = require("wereepic_skill")


local CastSelect = {
    taunt = {
        pos = { 900, 150 },
        animbank = "epic_castselect_icons",
        animbuild = "epic_castselect_icons",
        animdis = "taunt",
        animfoc = "taunt_focus"
    },
    transform = {
        pos = { 1100, 150 },
        animbank = "epic_castselect_icons",
        animbuild = "epic_castselect_icons",
        animdis = "transform_run",
        animfoc = "transform_run_focus"
    },
    onbecamehuman = {
        pos = { 1300, 150 },
        is_player_badge = true,
    },
    skill1 = {
        pos = { 1500, 150 },
        animbank = "epic_castselect_icons",
        animbuild = "epic_castselect_icons",
        animdis = "skill1",
        animfoc = "skill1_focus"
    },
    skill2 = {
        pos = { 1700, 150 },
        animbank = "epic_castselect_icons",
        animbuild = "epic_castselect_icons",
        animdis = "skill2",
        animfoc = "skill2_focus"
    },
    skill3 = {
        pos = { 1900, 150 },
        animbank = "epic_castselect_icons",
        animbuild = "epic_castselect_icons",
        animdis = "skill3",
        animfoc = "skill3_focus"
    },
}

local function OnSelect(anim)
    if anim.currentAnim == anim.animfoc then return end
    if anim.GetAnimState then
        anim:GetAnimState():PlayAnimation(anim.animfoc, true)
    else
        anim:SetScale(1.4, 1.4)
    end
    anim.currentAnim = anim.animfoc
end

local function OnUnSelect(anim)
    if anim.currentAnim == anim.animdis then return end
    if anim.GetAnimState then
        anim:GetAnimState():PlayAnimation(anim.animdis, true)
    else
        anim:SetScale(1.3, 1.3)
    end
    anim.currentAnim = anim.animdis
end

local Hide_Skill = {
    transform = true,
    skill1 = true,
    skill2 = true,
    skill3 = true,
}

local EpicCastSelect = Class(Widget, function(self, owner)
    Widget._ctor(self, "EpicCastSelect")
    self.owner = owner

    self:SetClickable(true)
    self.casts = {}

    for name, data in pairs(CastSelect) do
        if data.is_player_badge then
            local playerbadge = self:AddChild(PlayerBadge("", {1,1,1,1}, false, 0))
            local function ChangeSkin()
                owner:DoTaskInTime(0.3,function()
                    local prefab = owner.prefab or "wilson"
                    local base_skin = nil
                    pcall(function()
                        local clients = TheNet:GetClientTable()
                        if clients then
                            for _, c in ipairs(clients) do
                                if c.userid == owner.userid then
                                    base_skin = c.base_skin
                                    break
                                end
                            end
                        end
                    end)
                    playerbadge:Set(prefab, {1,1,1,1}, false, 0, base_skin)
                end)
            end
            ChangeSkin()
            playerbadge.animdis = "normal"
            playerbadge.animfoc = "focus"
            playerbadge._ChangeSkin = ChangeSkin

            playerbadge.headframe:SetTexture("images/headframe.xml", "headframe.tex")
            playerbadge.headbg:SetTint(1, 0.5, 0.5, 1)

            playerbadge:SetClickable(true)

            playerbadge.cooldown_anim = playerbadge:AddChild(UIAnim())
            playerbadge.cooldown_anim:GetAnimState():SetBank("epic_castselect_icons")
            playerbadge.cooldown_anim:GetAnimState():SetBuild("epic_castselect_icons")
            playerbadge.cooldown_anim:GetAnimState():SetMultColour(1, 1, 1, 0.5)
            playerbadge.cooldown_anim:SetScale(1.5,1.5)
            playerbadge.cooldown_anim:SetClickable(false)
            playerbadge.cooldown_anim:Hide()

            OnUnSelect(playerbadge)

            self.casts[name] = playerbadge
        else
            local anim = self:AddChild(UIAnim())
            anim:GetAnimState():SetBank(data.animbank)
            anim:GetAnimState():SetBuild(data.animbuild)
            anim.animdis = data.animdis
            anim.animfoc = data.animfoc

            anim.cooldown_anim = anim:AddChild(UIAnim())
            anim.cooldown_anim:GetAnimState():SetBank(data.animbank)
            anim.cooldown_anim:GetAnimState():SetBuild(data.animbuild)
            anim.cooldown_anim:GetAnimState():SetMultColour(1, 1, 1, 0.5)
            anim.cooldown_anim:SetScale(1.5,1.5)
            anim.cooldown_anim:SetClickable(false)
            anim.cooldown_anim:Hide()

            OnUnSelect(anim)
            self.casts[name] = anim
        end
    end

    self.updating = false
    self.current_select = nil
    self.start_time = nil
end)

function EpicCastSelect:HideSkill()
    local mode = self.owner.replica.wereepic:GetEpicMode()
    if EPIC[mode] then
        for k, v in pairs(Hide_Skill) do
            if EPIC[mode][k] then
                self.casts[k]:Show()
            else
                self.casts[k]:Hide()
            end
        end
        if string.find(mode,"alterguardian") then
            self.casts["taunt"]:Hide()
        else
            self.casts["taunt"]:Show()
        end
    end
end

function EpicCastSelect:GetCooldownPercent(name)
    local cd_name = "epic_"..name
    if self.owner.components.spellbookcooldowns then
        local pct = self.owner.components.spellbookcooldowns:GetSpellCooldownPercent(cd_name)
        return pct or 1
    end
end

function EpicCastSelect:IsCoolingDown(name)
    local cd_name = "epic_"..name
    if self.owner.components.spellbookcooldowns then
        return self.owner.components.spellbookcooldowns:IsInCooldown(cd_name)
    end
    return false
end

function EpicCastSelect:UpdateCooldowns()
    for name, anim in pairs(self.casts) do
        if anim.cooldown_anim then
            local pct = self:GetCooldownPercent(name)
            if pct < 1 then
                anim.cooldown_anim:GetAnimState():SetPercent("cooldown", pct)
                anim.cooldown_anim:Show()
                if anim.GetAnimState then
                    anim:GetAnimState():SetMultColour(0.5, 0.5, 0.5, 1)
                end
            else
                anim.cooldown_anim:Hide()
                if anim.GetAnimState then
                    anim:GetAnimState():SetMultColour(1, 1, 1, 1)
                end
            end
        end
    end
end

function EpicCastSelect:CanSelect()
    return not self.updating
end

function EpicCastSelect:Select(name)
    if self.current_select then
        OnUnSelect(self.casts[self.current_select])
        self.current_select = nil
    end

    if name then
        self.current_select = name
        OnSelect(self.casts[name])
    end
end

function EpicCastSelect:OnShow()
    self.start_time = GetTime()
    self.updating = true
    self.casts["onbecamehuman"]:_ChangeSkin()
    self:StartUpdating()
    self:HideSkill()
end

function EpicCastSelect:OnHide()
    self:StopUpdating()
    self.updating = false
    for _, anim in pairs(self.casts) do
        anim:SetPosition(1300, 150)
        OnUnSelect(anim)
    end
    self.hovered_spell = nil
end

local duration = 0.5
function EpicCastSelect:OnUpdate(dt)
    local elapsedTime = GetTime() - self.start_time
    if elapsedTime < duration then
        for name, anim in pairs(self.casts) do
            local target_pos = CastSelect[name].pos
            local x = easing.outQuad(elapsedTime, 1300, target_pos[1]-1300, duration)
            local y = easing.outQuad(elapsedTime, 150, target_pos[2]-150, duration)
            if anim.GetAnimState then
                anim:GetAnimState():SetMultColour(1, 1, 1, elapsedTime / duration)
            end
            anim:SetPosition(x, y)
        end
    else
        -- self:StopUpdating()
        self.updating = false
    end

    self:UpdateCooldowns()

    if self.updating then return end

    local mouse = TheInput:GetScreenPosition()
    local hovered = nil

    if hovered and self:IsCoolingDown(hovered) then
        hovered = nil
    end

    for name, anim in pairs(self.casts) do
        local animPos = anim:GetWorldPosition()
        local halfSize = 51
        if mouse.x >= animPos.x - halfSize and mouse.x <= animPos.x + halfSize and
           mouse.y >= animPos.y - halfSize and mouse.y <= animPos.y + halfSize then
            hovered = name
            break
        end
    end

    for name, anim in pairs(self.casts) do
        if name == hovered then
            OnSelect(anim)
        else
            OnUnSelect(anim)
        end
    end

    self.hovered_spell = hovered
end
function EpicCastSelect:OnMouseButton(button, down, x, y)
    if button == MOUSEBUTTON_LEFT and not down then
        if self.casts[self.hovered_spell] and not self:IsCoolingDown(self.hovered_spell) then
            SendModRPCToServer(MOD_RPC["WEREEPIC"][self.hovered_spell])
        end
        return true
    else
        return false
    end
end

return EpicCastSelect