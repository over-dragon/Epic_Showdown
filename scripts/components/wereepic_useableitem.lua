local WereEpic_UseableItem = Class(function(self, inst)
	self.inst = inst
	self.onusefn = nil
	self.inuse = false
end,
nil,
{

})

function WereEpic_UseableItem:CanInteract(doer)
    return not doer.replica.wereepic:IsEpic()
end

function WereEpic_UseableItem:StartUsing(doer)
	if self:CanInteract(doer) then
        if doer.components.wereepic then
            doer.components.wereepic:SetEpicMode(self.inst.epic_mode)
        end
        return true
    else
        return false
    end
end

return WereEpic_UseableItem