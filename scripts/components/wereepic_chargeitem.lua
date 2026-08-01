local Wereepic_ChargeItem = Class(function(self, inst)
    self.inst = inst
end,
nil,
{

})

function Wereepic_ChargeItem:Charge(invobject, target)
    local rechargeable = target.components.rechargeable
    if rechargeable and not rechargeable:IsCharged()  then
        local recharge_time = rechargeable:GetRechargeTime()
        if recharge_time > 0 then
            local current_pct = rechargeable:GetPercent()
            local new_pct = current_pct + 60 / recharge_time
            rechargeable:SetPercent(math.min(new_pct, 1))
        end
    end

    if invobject.components.stackable then
        invobject.components.stackable:Get():Remove()
    else
        invobject:Remove()
    end
    return true
end

return Wereepic_ChargeItem