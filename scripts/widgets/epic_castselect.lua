local Widget = require "widgets/widget"
local UIAnim = require "widgets/uianim"
local easing = require "easing"
local EPIC = require("wereepic_skill")

local CastSelect = {
    taunt = {
        pos = { -400, 150 },
        animbank = "epic_castselect_icons",
        animbuild = "epic_castselect_icons",
        animdis = "taunt",
        animfoc = "taunt_focus"
    },
    transform = {
        pos = { -200, 150 },
        animbank = "epic_castselect_icons",
        animbuild = "epic_castselect_icons",
        animdis = "transform",
        animfoc = "transform_focus"
    },
    onbecamehuman = {
        pos = { 0, 150 },
        animbank = "epic_castselect_icons",
        animbuild = "epic_castselect_icons",
        animdis = "onbecamehuman",
        animfoc = "onbecamehuman_focus",
    },
    skill1 = {
        pos = { 200, 150 },
        animbank = "epic_castselect_icons",
        animbuild = "epic_castselect_icons",
        animdis = "skill1",
        animfoc = "skill1_focus"
    },
    skill2 = {
        pos = { 400, 150 },
        animbank = "epic_castselect_icons",
        animbuild = "epic_castselect_icons",
        animdis = "skill2",
        animfoc = "skill2_focus"
    },
    skill3 = {
        pos = { 600, 150 },
        animbank = "epic_castselect_icons",
        animbuild = "epic_castselect_icons",
        animdis = "skill3",
        animfoc = "skill3_focus"
    },
}

local function OnSelect(mode,anim)
    if anim.currentAnim == anim.animfoc then return end
    if EPIC[mode] then
        anim:GetAnimState():PlayAnimation(mode.."_"..anim.animfoc, true)
        anim.currentAnim = anim.animfoc
    else
        anim:GetAnimState():PlayAnimation("cooldown", true)
    end
end

local function OnUnSelect(mode,anim)
    if anim.currentAnim == anim.animdis then return end
    if EPIC[mode] then
        anim:GetAnimState():PlayAnimation(mode.."_"..anim.animdis,true)
        anim.currentAnim = anim.animdis
    else
        anim:GetAnimState():PlayAnimation("cooldown", true)
    end
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

    self:SetHAnchor(ANCHOR_MIDDLE)
    self:SetVAnchor(ANCHOR_BOTTOM)

    self:SetClickable(true)
    self.casts = {}

    for name, data in pairs(CastSelect) do
        local anim = self:AddChild(UIAnim())
        anim:GetAnimState():SetBank(data.animbank)
        anim:GetAnimState():SetBuild(data.animbuild)
        anim.animdis = data.animdis
        anim.animfoc = data.animfoc

        anim.cooldown_anim = anim:AddChild(UIAnim())
        anim.cooldown_anim:GetAnimState():SetBank(data.animbank)
        anim.cooldown_anim:GetAnimState():SetBuild(data.animbuild)
        anim.cooldown_anim:GetAnimState():SetMultColour(1, 1, 1, 0.5)
        -- anim.cooldown_anim:SetScale(1.5,1.5)
        anim.cooldown_anim:SetClickable(false)
        anim.cooldown_anim:Hide()

        OnUnSelect("none",anim)
        self.casts[name] = anim
    end

    self.updating = false
    self.current_select = nil
    self.start_time = nil
    self.mode = "none"
end)

function EpicCastSelect:ShowSkill()
    local mode = self.owner.replica.wereepic:GetEpicMode()
    self.mode = mode
    if EPIC[mode] then
        for k, v in pairs(Hide_Skill) do
            if EPIC[mode][k] then
                self.casts[k]:Show()
                self.casts[k]:GetAnimState():PlayAnimation(mode.."_"..k,true)
            else
                self.casts[k]:Hide()
            end
        end
        if string.find(mode,"alterguardian") then
            self.casts["taunt"]:Hide()
        else
            self.casts["taunt"]:Show()
            self.casts["taunt"]:GetAnimState():PlayAnimation(mode.."_taunt",true)
        end
        self.casts["onbecamehuman"]:GetAnimState():PlayAnimation(mode.."_onbecamehuman",true)
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
        OnUnSelect(self.mode,self.casts[self.current_select])
        self.current_select = nil
    end

    if name then
        self.current_select = name
        OnSelect(self.mode,self.casts[name])
    end
end

function EpicCastSelect:OnShow()
    self:ShowSkill()
    self.start_time = GetTime()
    self.updating = true
    self:StartUpdating()
end

function EpicCastSelect:OnHide()
    self:StopUpdating()
    self.updating = false
    for _, anim in pairs(self.casts) do
        anim:SetPosition(0, 150)
        OnUnSelect("none",anim)
    end
    self.hovered_spell = nil
end

local duration = 0.5
function EpicCastSelect:OnUpdate(dt)
    local elapsedTime = GetTime() - self.start_time
    if elapsedTime < duration then
        for name, anim in pairs(self.casts) do
            local target_pos = CastSelect[name].pos
            local x = easing.outQuad(elapsedTime, 0, target_pos[1], duration)
            local y = easing.outQuad(elapsedTime, 150, target_pos[2]-150, duration)
            anim:GetAnimState():SetMultColour(1, 1, 1, elapsedTime / duration)
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

    for name, anim in pairs(self.casts) do
        local animPos = anim:GetWorldPosition()
        local halfSize = 51
        if mouse.x >= animPos.x - halfSize and mouse.x <= animPos.x + halfSize and
           mouse.y >= animPos.y - halfSize and mouse.y <= animPos.y + halfSize then
            hovered = name
            break
        end
    end

    if hovered and self:IsCoolingDown(hovered) then
        hovered = nil
    end

    for name, anim in pairs(self.casts) do
        if name == hovered then
            OnSelect(self.mode,anim)
        else
            OnUnSelect(self.mode,anim)
        end
    end

    if hovered ~= nil and hovered ~= self.hovered_spell then
        TheFrontEnd:GetSound():PlaySound("epic_castselect_icons/epic_castselect_icons/idle")
    end

    self.hovered_spell = hovered
end
function EpicCastSelect:OnMouseButton(button, down, x, y)
    if button == MOUSEBUTTON_LEFT and not down then
        if self.casts[self.hovered_spell] and not self:IsCoolingDown(self.hovered_spell) then
            TheFrontEnd:GetSound():PlaySound("epic_castselect_icons/epic_castselect_icons/click")
            SendModRPCToServer(MOD_RPC["WEREEPIC"][self.hovered_spell])
        end
        return true
    else
        return false
    end
end

return EpicCastSelect