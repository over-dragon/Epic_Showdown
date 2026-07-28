local CastSelect = require("widgets/epic_castselect")
AddClassPostConstruct("widgets/controls", function(self)
    if not self.owner then
        return
    end
    self.epiccastselect = self:AddChild(CastSelect(self.owner))
    self.epiccastselect:Hide()

end)