local CastSelect = require("widgets/epic_castselect")
local function IsHUDScreen()
	local screen = TheFrontEnd:GetActiveScreen()
    return screen and screen.name == "HUD"
end

local modid = 'epic_showdown'
local taunt_keydown = GetModConfigData(modid..'taunt_keydown') or 0
local transform_keydown = GetModConfigData(modid..'transform_keydown') or 0
local onbecamehuman_keydown = GetModConfigData(modid..'onbecamehuman_keydown') or 0
local skill1_keydown = GetModConfigData(modid..'skill1_keydown') or 0
local skill2_keydown = GetModConfigData(modid..'skill2_keydown') or 0
local skill3_keydown = GetModConfigData(modid..'skill3_keydown') or 0
local pad_cast = GetModConfigData(modid..'_pad_cast') or 0


local function IsCoolingDown(owner,name)
    local cd_name = "epic_"..name
    if owner.components.spellbookcooldowns then
        return owner.components.spellbookcooldowns:IsInCooldown(cd_name)
    end
    return false
end
AddClassPostConstruct("widgets/controls", function(self)
    if not self.owner then
        return
    end
    self.epiccastselect = self:AddChild(CastSelect(self.owner))
    self.epiccastselect:Hide()

    if self.owner:HasTag("player") then
        self['epic_castselect_handle'] = {}
        self.inst:ListenForEvent("onremove", function()
            for _, handler in pairs(self['epic_castselect_handle']) do
                handler:Remove()
            end
        end)
        if taunt_keydown~=0 then
            self['epic_castselect_handle'].taunt_keydown = TheInput:AddKeyDownHandler(taunt_keydown, function()
                if IsHUDScreen() and self.owner:HasTag("epic") then
                    if not IsCoolingDown(self.owner,"taunt") then
                        if TUNING.EPIC_WORLD.CASTSELECT_MUSIC==1 and self.owner==ThePlayer then
                            TheFocalPoint.SoundEmitter:PlaySound("epic_castselect_icons/epic_castselect_icons/click")
                        end
                        SendModRPCToServer(MOD_RPC["WEREEPIC"]["taunt"])
                    end
                end
            end)
        end
        if transform_keydown~=0 then
            self['epic_castselect_handle'].transform_keydown = TheInput:AddKeyDownHandler(transform_keydown, function()
                if IsHUDScreen() and self.owner:HasTag("epic") then
                    if not IsCoolingDown(self.owner,"transform") then
                        if TUNING.EPIC_WORLD.CASTSELECT_MUSIC==1 and self.owner==ThePlayer then
                            TheFocalPoint.SoundEmitter:PlaySound("epic_castselect_icons/epic_castselect_icons/click")
                        end
                        SendModRPCToServer(MOD_RPC["WEREEPIC"]["transform"])
                    end
                end
            end)
        end
        if onbecamehuman_keydown~=0 then
            self['epic_castselect_handle'].onbecamehuman_keydown = TheInput:AddKeyDownHandler(onbecamehuman_keydown, function()
                if IsHUDScreen() and self.owner:HasTag("epic") then
                    if not IsCoolingDown(self.owner,"onbecamehuman") then
                        if TUNING.EPIC_WORLD.CASTSELECT_MUSIC==1 and self.owner==ThePlayer then
                            TheFocalPoint.SoundEmitter:PlaySound("epic_castselect_icons/epic_castselect_icons/click")
                        end
                        SendModRPCToServer(MOD_RPC["WEREEPIC"]["onbecamehuman"])
                    end
                end
            end)
        end
        if skill1_keydown~=0 then
            self['epic_castselect_handle'].skill1_keydown = TheInput:AddKeyDownHandler(skill1_keydown, function()
                if IsHUDScreen() and self.owner:HasTag("epic") then
                    if not IsCoolingDown(self.owner,"skill1") then
                        if TUNING.EPIC_WORLD.CASTSELECT_MUSIC==1 and self.owner==ThePlayer then
                            TheFocalPoint.SoundEmitter:PlaySound("epic_castselect_icons/epic_castselect_icons/click")
                        end
                        SendModRPCToServer(MOD_RPC["WEREEPIC"]["skill1"])
                    end
                end
            end)
        end
        if skill2_keydown~=0 then
            self['epic_castselect_handle'].skill2_keydown = TheInput:AddKeyDownHandler(skill2_keydown, function()
                if IsHUDScreen() and self.owner:HasTag("epic") then
                    if not IsCoolingDown(self.owner,"skill2") then
                        if TUNING.EPIC_WORLD.CASTSELECT_MUSIC==1 and self.owner==ThePlayer then
                            TheFocalPoint.SoundEmitter:PlaySound("epic_castselect_icons/epic_castselect_icons/click")
                        end
                        SendModRPCToServer(MOD_RPC["WEREEPIC"]["skill2"])
                    end
                end
            end)
        end
        if skill3_keydown~=0 then
            self['epic_castselect_handle'].skill3_keydown = TheInput:AddKeyDownHandler(skill3_keydown, function()
                if IsHUDScreen() and self.owner:HasTag("epic") then
                    if not IsCoolingDown(self.owner,"skill3") then
                        if TUNING.EPIC_WORLD.CASTSELECT_MUSIC==1 and self.owner==ThePlayer then
                            TheFocalPoint.SoundEmitter:PlaySound("epic_castselect_icons/epic_castselect_icons/click")
                        end
                        SendModRPCToServer(MOD_RPC["WEREEPIC"]["skill3"])
                    end
                end
            end)
        end
        if pad_cast ~= 0 then
            self['epic_castselect_handle'].pad_cast = TheInput:AddControlHandler(pad_cast, function(digitalvalue)
                if not TheInput:ControllerAttached() then return end
                local bar = self.epiccastselect
                if not digitalvalue then
                    local spell = (IsHUDScreen() and self.owner:HasTag("epic")) and bar.pad_hovered or nil
                    local active = bar.pad_selecting
                    bar.pad_selecting = false
                    bar.pad_hovered = nil
                    bar.pad_index = nil
                    if spell and not IsCoolingDown(self.owner, spell) then
                        if TUNING.EPIC_WORLD.CASTSELECT_MUSIC==1 and self.owner==ThePlayer then
                            TheFocalPoint.SoundEmitter:PlaySound("epic_castselect_icons/epic_castselect_icons/click")
                        end
                        SendModRPCToServer(MOD_RPC["WEREEPIC"][spell])
                    end
                    if active then
                        bar:Hide()
                    end
                elseif IsHUDScreen() and self.owner:HasTag("epic") then
                    bar:Show()
                    bar.pad_selecting = true
                    bar.pad_index = nil
                end
            end)
        end
    end
end)