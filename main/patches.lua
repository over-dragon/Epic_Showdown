local old_ShakeAllCameras = _G.ShakeAllCameras
function _G.ShakeAllCameras(mode, duration, speed, scale, source_or_pt, maxDist)
    for i, v in ipairs(AllPlayers) do
        if not v:HasTag("epic") then
            v:ShakeCamera(mode, duration, speed, scale, source_or_pt, maxDist)
        end
    end
end

-- local old_IsEntityGestaltProtected = _G.IsEntityGestaltProtected
-- function _G.IsEntityGestaltProtected(inst)
--     return inst:HasTag("epic_lunar") or old_IsEntityGestaltProtected(inst)
-- end