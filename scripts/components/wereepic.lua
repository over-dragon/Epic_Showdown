local EPIC = require("wereepic_boss")
local WereEpic = Class(function(self, inst)
    self.inst = inst
    self.mode = "none"
    self.sanityfn = nil
    self.max_temp = TUNING.MAX_ENTITY_TEMP
    self.min_temp = TUNING.MIN_ENTITY_TEMP
    self.drownable = false
    self.canbepinned = true
    self.maxhealth = 150
    self.planar = false
end,
nil,
{

})

local function SetVision(self,bool)
    self.inst.replica.wereepic._epic_mode:set(self.mode)
    self.inst.replica.wereepic._is_epic:set(bool)
end

local shatterfx =
{
    character = "shatter",
}
local burnfx =
{
    character = "character_fire",
    generic = "fire",
}
local function HugeFreezableCharacter(inst, sym, offset)
    local freezable = inst.components.freezable or nil
    if freezable then
        freezable:SetShatterFXLevel(5)
        freezable:SetResistance(4)
        freezable:AddShatterFX(shatterfx.character, offset or Vector3(0, 0, 0), sym)
    else
        freezable = inst:AddComponent("freezable")
        freezable:SetShatterFXLevel(5)
        freezable:SetResistance(4)
        freezable:AddShatterFX(shatterfx.character, offset or Vector3(0, 0, 0), sym)
    end
    return freezable
end
local function LargePropagator(inst)
    local propagator = inst.components.propagator or nil
    if propagator then
        propagator.acceptsheat = true
        propagator:SetOnFlashPoint(DefaultIgniteFn)
        propagator.flashpoint = 45+math.random()*10
        propagator.decayrate = 0.5
        propagator.propagaterange = 6 + math.random()*2
        propagator.heatoutput = 6 + math.random()*3.5--12

        propagator.damagerange = 3
        propagator.damages = true
    else
        propagator = inst:AddComponent("propagator")
        propagator.acceptsheat = true
        propagator:SetOnFlashPoint(DefaultIgniteFn)
        propagator.flashpoint = 45+math.random()*10
        propagator.decayrate = 0.5
        propagator.propagaterange = 6 + math.random()*2
        propagator.heatoutput = 6 + math.random()*3.5--12

        propagator.damagerange = 3
        propagator.damages = true
    end

    return propagator
end
local function LargeBurnableCharacter(inst, sym, offset, scale)
    local burnable = inst.components.burnable or nil
    if burnable then
        burnable:SetFXLevel(3)
        burnable.canlight = false
        burnable:SetBurnTime(10)
        burnable:AddBurnFX(burnfx.character, offset or (sym and Vector3(0, 0, 0.1) or Vector3(0, 0.1, 0)), sym, nil, scale)
    else
        burnable = inst:AddComponent("burnable")
        burnable:SetFXLevel(3)
        burnable.canlight = false
        burnable:SetBurnTime(10)
        burnable:AddBurnFX(burnfx.character, offset or (sym and Vector3(0, 0, 0.1) or Vector3(0, 0.1, 0)), sym, nil, scale)
    end

    local propagator = LargePropagator(inst)
    propagator.acceptsheat = false

    return burnable, propagator
end
local function GiantCharacterPhysics(inst, mass, rad)
    local phys = inst.Physics or nil
    if phys then
        phys:SetMass(mass)
        phys:SetFriction(0)
        phys:SetDamping(5)
        phys:SetCollisionGroup(COLLISION.GIANTS)
        phys:SetCollisionMask(
            COLLISION.WORLD,
            COLLISION.OBSTACLES,
            COLLISION.CHARACTERS,
            COLLISION.GIANTS
        )
        phys:SetCapsule(rad, 1)
    else
        phys = inst.entity:AddPhysics()
        phys:SetMass(mass)
        phys:SetFriction(0)
        phys:SetDamping(5)
        phys:SetCollisionGroup(COLLISION.GIANTS)
        phys:SetCollisionMask(
            COLLISION.WORLD,
            COLLISION.OBSTACLES,
            COLLISION.CHARACTERS,
            COLLISION.GIANTS
        )
        phys:SetCapsule(rad, 1)
    end

    return phys
end
local function CharacterPhysics(inst, mass, rad)
    local phys = inst.Physics or nil
    if phys then
        phys:SetMass(mass)
        phys:SetFriction(0)
        phys:SetDamping(5)
        phys:SetCollisionGroup(COLLISION.CHARACTERS)
        phys:SetCollisionMask(
            COLLISION.WORLD,
            COLLISION.OBSTACLES,
            COLLISION.SMALLOBSTACLES,
            COLLISION.CHARACTERS,
            COLLISION.GIANTS
        )
        phys:SetCapsule(rad, 1)
    else
        phys = inst.entity:AddPhysics()
        phys:SetMass(mass)
        phys:SetFriction(0)
        phys:SetDamping(5)
        phys:SetCollisionGroup(COLLISION.CHARACTERS)
        phys:SetCollisionMask(
            COLLISION.WORLD,
            COLLISION.OBSTACLES,
            COLLISION.SMALLOBSTACLES,
            COLLISION.CHARACTERS,
            COLLISION.GIANTS
        )
        phys:SetCapsule(rad, 1)
    end

    return phys
end
local function SmallPropagator(inst)
    local propagator = inst.components.propagator or nil
    if propagator then
        propagator.acceptsheat = true
        propagator:SetOnFlashPoint(DefaultIgniteFn)
        propagator.flashpoint = 5 + math.random()*5
        propagator.decayrate = 0.5
        propagator.propagaterange = 3 + math.random()*2
        propagator.heatoutput = 3 + math.random()*2--8

        propagator.damagerange = 2
        propagator.damages = true
    else
        propagator = inst:AddComponent("propagator")
        propagator.acceptsheat = true
        propagator:SetOnFlashPoint(DefaultIgniteFn)
        propagator.flashpoint = 5 + math.random()*5
        propagator.decayrate = 0.5
        propagator.propagaterange = 3 + math.random()*2
        propagator.heatoutput = 3 + math.random()*2--8

        propagator.damagerange = 2
        propagator.damages = true
    end

    return propagator
end
local function MediumBurnableCharacter(inst, sym, offset)
    local burnable = inst.components.burnable or nil
    if burnable then
        burnable:SetFXLevel(2)
        burnable.canlight = false
        burnable:SetBurnTime(8)
	    burnable:AddBurnFX(burnfx.character, offset or (sym and Vector3(0, 0, 0.1) or Vector3(0, 0.1, 0)), sym)
    else
        burnable = inst:AddComponent("burnable")
        burnable:SetFXLevel(2)
        burnable.canlight = false
        burnable:SetBurnTime(8)
	    burnable:AddBurnFX(burnfx.character, offset or (sym and Vector3(0, 0, 0.1) or Vector3(0, 0.1, 0)), sym)
    end

    local propagator = SmallPropagator(inst)
    propagator.acceptsheat = false

    return burnable, propagator
end
local function LargeFreezableCharacter(inst, sym, offset)
    local freezable = inst.components.freezable or nil
    if freezable then
        freezable:SetShatterFXLevel(4)
        freezable:SetResistance(3)
        freezable:AddShatterFX(shatterfx.character, offset or Vector3(0, 0, 0), sym)
    else
        freezable = inst:AddComponent("freezable")
        freezable:SetShatterFXLevel(4)
        freezable:SetResistance(3)
        freezable:AddShatterFX(shatterfx.character, offset or Vector3(0, 0, 0), sym)
    end

    return freezable
end

local skill_names = {"taunt", "transform", "skill1", "skill2", "skill3"}

function WereEpic:SetEpicMode(mode)
    self.mode = mode
end

function WereEpic:GetEpicMode()
    return self.mode
end

function WereEpic:IsEpic()
    return EPIC[self.mode]
end

function WereEpic:InitEpic()
    if EPIC[self.mode]==nil then
        return
    end

    self.inst.AnimState:SetBank(EPIC[self.mode].bank)
    self.inst.AnimState:SetBuild(EPIC[self.mode].build)

    local s = EPIC[self.mode].scale or 1
    self.inst.Transform:SetScale(s, s, s)

    self.inst.DynamicShadow:SetSize(unpack(EPIC[self.mode].dyshadow))

    GiantCharacterPhysics(self.inst, 1000, EPIC[self.mode].phyrad)
    self.inst.Physics:SetCollisionCallback(EPIC[self.mode].oncollide)

    self.inst:AddTag("epic")
    self.inst:AddTag("toughworker")
    if EPIC[self.mode].gogglevision then
        self.inst:AddTag("epic_gogglevision")
    end

    SetVision(self,true)

    self.hurtsoundoverride = self.inst.hurtsoundoverride
    self.deathsoundoverride = self.inst.deathsoundoverride
    self.inst.hurtsoundoverride = EPIC[self.mode].hurtsoundoverride
    self.inst.deathsoundoverride = EPIC[self.mode].deathsoundoverride

    HugeFreezableCharacter(self.inst, EPIC[self.mode].freezable)
    LargeBurnableCharacter(self.inst, EPIC[self.mode].burnable or "swap_fire")

    if not GetGameModeProperty("no_hunger") and self.inst.components.hunger then
        self.inst.components.hunger:Pause()
    end
    if self.inst.components.skinner then
        self.inst.components.skinner:HideAllClothing(self.inst.AnimState)
    end

    if self.inst.components.locomotor then
        self.inst.components.locomotor:SetExternalSpeedMultiplier(self.inst,"epic_scale_speed",1/s)
        if TUNING.EPIC_WORLD.WALKSPEED_CHANGE==1 and EPIC[self.mode].walkspeed then
            self.inst.components.locomotor.runspeed = EPIC[self.mode].walkspeed
        end
    end

    if self.inst.components.health then
        self.maxhealth = self.inst.components.health.maxhealth
        local ratio=self.inst.components.health.currenthealth/self.inst.components.health.maxhealth
        self.inst.components.health:SetMaxHealth(EPIC[self.mode].health)
		self.inst.components.health:SetCurrentHealth(EPIC[self.mode].health*ratio)
		self.inst.components.health:DoDelta(0.01,true)
        if EPIC[self.mode].burnable_damage then
            self.fire_damage_scale = self.inst.components.health.fire_damage_scale
            self.inst.components.health.fire_damage_scale = 0
        end
    end

    if self.inst.components.combat then
        self.inst.components.combat:SetDefaultDamage(EPIC[self.mode].damage)
        self.inst.components.combat:SetRange(EPIC[self.mode].range)
    end

    if self.inst.components.talker then
        self.inst.components.talker:IgnoreAll("becameepic")
    end

    if self.inst.components.sanity then
        self.sanityfn = self.inst.components.sanity.custom_rate_fn or nil
        self.inst.components.sanity.custom_rate_fn = function (inst,dt)
            if EPIC[self.mode].enablelunacy then
                return -TUNING.WERE_SANITY_PENALTY*3
            else
                return TUNING.WERE_SANITY_PENALTY*1.5
            end
        end
    end

    if self.inst.components.temperature then
        self.max_temp = self.inst.components.temperature.maxtemp
        self.min_temp = self.inst.components.temperature.mintemp
        self.inst.components.temperature.maxtemp = 70
        self.inst.components.temperature.mintemp = 0
    end

    -- if self.inst.components.moisture then
    --     self.inst.components.moisture:SetInherentWaterproofness(TUNING.WATERPROOFNESS_ABSOLUTE)
    -- end

    if self.inst.components.catcher then
        self.inst.components.catcher:SetEnabled(false)
    end

    if self.inst.components.sandstormwatcher then
        self.inst.components.sandstormwatcher:SetSandstormSpeedMultiplier(1)
    end
    if self.inst.components.moonstormwatcher then
        self.inst.components.moonstormwatcher:SetMoonstormSpeedMultiplier(1)
    end
    if self.inst.components.miasmawatcher then
        self.inst.components.miasmawatcher:SetMiasmaSpeedMultiplier(1)
    end
    if self.inst.components.carefulwalker then
        self.inst.components.carefulwalker:SetCarefulWalkingSpeedMultiplier(1)
    end

    if self.inst.components.drownable then
        self.drownable = self.inst.components.drownable.enabled
        self.inst.components.drownable.enabled = false
    end

    if self.inst.components.pinnable then
        self.canbepinned = self.inst.components.pinnable.canbepinned
        self.inst.components.pinnable.canbepinned = false
    end

    if self.inst.components.inventory then
        self.inst.components.inventory:Close()
        self.inst.components.inventory:DropEquipped(true,true)
    end

    if EPIC[self.mode].freezable_resistance and self.inst.components.freezable then
        self.resistance = self.inst.components.freezable.resistance
        self.inst.components.freezable:SetResistance(EPIC[self.mode].freezable_resistance)
    end
end

function WereEpic:InitHuman()
    if self.mode=="none" then
        return
    end

    self.inst.AnimState:SetBank("wilson")

    self.inst.Transform:SetScale(1, 1, 1)

    self.inst.DynamicShadow:SetSize(1.3, .6)

    CharacterPhysics(self.inst, 75, .5)
    self.inst.Physics:SetCollisionCallback(nil)

    self.inst:RemoveTag("epic")
    self.inst:RemoveTag("toughworker")

    if EPIC[self.mode].gogglevision then
        self.inst:RemoveTag("epic_gogglevision")
    end
    self.inst.hurtsoundoverride = self.hurtsoundoverride
    self.inst.deathsoundoverride = self.deathsoundoverride

    MediumBurnableCharacter(self.inst, "torso")
    self.inst.components.burnable:SetBurnTime(TUNING.PLAYER_BURN_TIME)
    self.inst.components.burnable.nocharring = true

    LargeFreezableCharacter(self.inst, "torso")
    if self.inst.prefab~="willow" then
        self.inst.components.freezable:SetResistance(4)
    end
    self.inst.components.freezable:SetDefaultWearOffTime(TUNING.PLAYER_FREEZE_WEAR_OFF_TIME)

    if not GetGameModeProperty("no_hunger") and self.inst.components.hunger then
        self.inst.components.hunger:Resume()
    end

    if self.inst.components.skinner then
        if self.inst.prefab=="wurt" then
            if self.inst.royal then
                self.inst.components.skinner:SetSkinMode("powerup","wurt_stage2")
            else
                self.inst.components.skinner:SetSkinMode("normal_skin","wurt")
            end
        elseif self.inst.prefab=="wanda" then
            local age = self.inst.age_state
            local skin_mode = tostring(age).."_skin"
            self.inst.components.skinner:SetSkinMode(skin_mode, "wilson")
        elseif self.inst.prefab=="wolfgang" then
            local mightiness = self.inst.components.mightiness or nil
            if mightiness then
                if mightiness:IsMighty() then
                    self.inst.components.skinner:SetSkinMode("mighty_skin", "wolfgang_mighty")
                elseif mightiness:IsWimpy() then
                    self.inst.components.skinner:SetSkinMode("wimpy_skin", "wolfgang_skinny")
                else
                    self.inst.components.skinner:SetSkinMode("normal_skin", "wolfgang")
                end
            end
        elseif self.inst.prefab=="wormwood" then
            local level = self.inst.components.bloomness and self.inst.components.bloomness:GetLevel() or nil
            if level and level>=1 and level<=3 then
                local skin_mode = "stage_"..tostring(level+1)
                self.inst.components.skinner:SetSkinMode(skin_mode,"wilson")
            else
                self.inst.components.skinner:SetSkinMode("normal_skin","wilson")
            end
        else
            self.inst.components.skinner:SetSkinMode("normal_skin")
        end
    end

    if self.inst.components.locomotor then
        self.inst.components.locomotor:RemoveExternalSpeedMultiplier(self.inst,"epic_scale_speed")
        if TUNING.EPIC_WORLD.WALKSPEED_CHANGE==1 and EPIC[self.mode].walkspeed then
            self.inst.components.locomotor.runspeed = 6
        end
    end

    if self.inst.components.health then
        if self.inst.prefab=="wurt" then
            if self.inst.royal then
                self.maxhealth = TUNING.WURT_HEALTH_KINGBONUS
            else
                self.maxhealth = TUNING.WURT_HEALTH
            end
        end
        local ratio=math.min(1,self.inst.components.health.currenthealth/self.inst.components.health.maxhealth)
        self.inst.components.health:SetMaxHealth(self.maxhealth)
		self.inst.components.health:SetCurrentHealth(self.maxhealth*ratio)
		self.inst.components.health:DoDelta(0.01,true)
        if EPIC[self.mode].burnable_damage then
            self.inst.components.health.fire_damage_scale = self.fire_damage_scale
        end
    end

    if self.inst.components.combat then
        self.inst.components.combat:SetDefaultDamage(TUNING.UNARMED_DAMAGE)
        self.inst.components.combat:SetRange(TUNING.DEFAULT_ATTACK_RANGE)
    end

    if self.inst.components.talker then
        self.inst.components.talker:StopIgnoringAll("becameepic")
    end

    if self.inst.components.sanity then
        self.inst.components.sanity.custom_rate_fn = self.sanityfn
    end

    if self.inst.components.temperature then
        self.inst.components.temperature.maxtemp = self.max_temp
        self.inst.components.temperature.mintemp = self.min_temp
    end

    -- if self.inst.components.moisture then
    --     self.inst.components.moisture:SetInherentWaterproofness(0)
    -- end

    if self.inst.components.catcher then
        self.inst.components.catcher:SetEnabled(true)
    end

    if self.inst.components.sandstormwatcher then
        self.inst.components.sandstormwatcher:SetSandstormSpeedMultiplier(TUNING.SANDSTORM_SPEED_MOD)
    end
    if self.inst.components.moonstormwatcher then
        self.inst.components.moonstormwatcher:SetMoonstormSpeedMultiplier(TUNING.MOONSTORM_SPEED_MOD)
    end
    if self.inst.components.miasmawatcher then
        self.inst.components.miasmawatcher:SetMiasmaSpeedMultiplier(TUNING.MIASMA_SPEED_MOD)
    end
    if self.inst.components.carefulwalker then
        self.inst.components.carefulwalker:SetCarefulWalkingSpeedMultiplier(TUNING.CAREFUL_SPEED_MOD)
    end

    if self.inst.components.drownable then
        if self.inst:HasTag("flying") then
            self.inst:DoTaskInTime(0.1,function()
                self.inst.components.drownable.enabled = self.drownable
            end)
        else
            self.inst.components.drownable.enabled = self.drownable
        end
    end

    if self.inst.components.pinnable then
        self.inst.components.pinnable.canbepinned = self.canbepinned
    end

    if self.inst.components.inventory then
        self.inst.components.inventory:Open()
    end

    if EPIC[self.mode].freezable_resistance and self.inst.components.freezable then
        self.inst.components.freezable:SetResistance(self.resistance)
    end
end

function WereEpic:OnBecameEpic()
    if EPIC[self.mode]==nil then
        return
    end
    self:InitEpic()
    if EPIC[self.mode].master_postinit then
        EPIC[self.mode].master_postinit(self.inst)
    end
    if self.planar then
        if self.inst.components.planardamage then
            self.inst.components.planardamage:AddBonus(self.inst, 30, "epic_planardamage")
        end
        if self.inst.components.planardefense then
            self.inst.components.planardefense:AddBonus(self.inst, 15, "epic_planardefense")
        end
    end
end

function WereEpic:OnBecameHuman()
    if self.mode=="none" then
        return
    end
    self:InitHuman()
    if EPIC[self.mode].master_human then
        EPIC[self.mode].master_human(self.inst)
    end
    self.mode = "none"
    SetVision(self,false)
    for _, name in ipairs(skill_names) do
        self.inst.components.spellbookcooldowns:StopSpellCooldown("epic_"..name)
    end
    local owner = self.inst.components.upgrademoduleowner or nil
    if owner then
        local level = owner:GetChargeLevel()
        owner:SetChargeLevel(level)
        for _, module in ipairs(owner:GetAllModules()) do
            local um = module.components.upgrademodule
            if um ~= nil and um.activated and
                (module.prefab == "wx78module_light" or module.prefab == "wx78module_light2") then
                um:TryDeactivate()
                um:TryActivate(false)
            end
        end
    end
    if self.planar then
        if self.inst.components.planardamage then
            self.inst.components.planardamage:RemoveBonus(self.inst, "epic_planardamage")
        end
        if self.inst.components.planardefense then
            self.inst.components.planardefense:RemoveBonus(self.inst, "epic_planardefense")
        end
        self.planar = false
    end
end

function WereEpic:OnSave()
    return {
        mode = self.mode,
        planar = self.planar
    }
end
function WereEpic:OnLoad(data)
    if data~=nil then
        if data.planar then
            self.planar = data.planar
        end
        if EPIC[data.mode] then
            self.mode = data.mode
            self.inst:PushEvent("onload_wereepic",{mode = self.mode})
        end
    end
end

return WereEpic