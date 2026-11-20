local Layouts = require("map/layouts").Layouts
local StaticLayout = require("map/static_layout")

Layouts["epic_origin_tiles"] = StaticLayout.Get("map/static_layouts/epic_origin")
Layouts["epic_origin_tiles"].min_dist_from_land = 0
Layouts["epic_origin_tiles"].add_topology = { room_id = "StaticLayoutIsland:epic_origin_tiles", tags = {"epic_origin"} }
AddRoomPreInit("OceanRough", function(room)
    if room.contents.countstaticlayouts then
       room.contents.countstaticlayouts["epic_origin_tiles"] = 1
    end
end)

AddLevelPreInitAny(function(level)
    if level.location ~= "forest" then return end

    local _G = GLOBAL
    local rawget = GLOBAL.rawget

    local old_Ocean_PlaceSetPieces = rawget(_G, "Ocean_PlaceSetPieces")
    if not old_Ocean_PlaceSetPieces then return end

    _G.Ocean_PlaceSetPieces = function(set_pieces, add_entity, obj_layout, populating_tile,
        min_dist_from_land, encoded_topology, map_width, map_height)

        local result = old_Ocean_PlaceSetPieces(set_pieces, add_entity, obj_layout, populating_tile,
            min_dist_from_land, encoded_topology, map_width, map_height)

        local WT = rawget(_G, "WORLD_TILES")
        if WT and populating_tile == WT.OCEAN_ROUGH
            and set_pieces and set_pieces["epic_origin_tiles"] then

            local entities = add_entity.args.entitiesOut

            if entities and entities["epic_chaosseed"] then
                local chaos = entities["epic_chaosseed"][1]
                local TILE_SCALE = 4

                local center_tx = math.floor(chaos.x / TILE_SCALE + map_width / 2)
                local center_ty = math.floor(chaos.z / TILE_SCALE + map_height / 2)

                local worm1_tx = center_tx + 10
                local worm1_ty = center_ty + 10

                local WorldSim = rawget(_G, "WorldSim")
                local land_tx, land_ty
                if WorldSim then
                    local LAND_TILES = {
                        [WT.DIRT] = true,
                        [WT.SAVANNA] = true, [WT.GRASS] = true,
                        [WT.FOREST] = true, [WT.MARSH] = true,
                        [WT.WOODFLOOR] = true, [WT.CARPET] = true,
                        [WT.CHECKER] = true,
                    }
                    local start_x = math.random(5, map_width - 5)
                    local start_y = math.random(5, map_height - 5)
                    for radius = 0, math.max(map_width, map_height) do
                        for dx = -radius, radius do
                            for dy = -radius, radius do
                                if math.max(math.abs(dx), math.abs(dy)) == radius then
                                    local x = start_x + dx
                                    local y = start_y + dy
                                    if x >= 0 and x < map_width and y >= 0 and y < map_height then
                                        if LAND_TILES[WorldSim:GetTile(x, y)] then
                                            land_tx = x
                                            land_ty = y
                                            break
                                        end
                                    end
                                end
                            end
                            if land_tx then break end
                        end
                        if land_tx then break end
                    end
                end

                if land_tx then
                    local id1 = 2305000
                    local id2 = 2305001
                    local wx1 = math.floor((worm1_tx - map_width / 2) * TILE_SCALE * 10) / 10
                    local wz1 = math.floor((worm1_ty - map_height / 2) * TILE_SCALE * 10) / 10
                    local wx2 = math.floor((land_tx - map_width / 2) * TILE_SCALE * 10) / 10
                    local wz2 = math.floor((land_ty - map_height / 2) * TILE_SCALE * 10) / 10

                    if entities["wormhole"] == nil then
                        entities["wormhole"] = {}
                    end

                    table.insert(entities["wormhole"], {
                        id = id1, x = wx1, z = wz1,
                        data = { teleporter = { target = id2 } },
                    })
                    table.insert(entities["wormhole"], {
                        id = id2, x = wx2, z = wz2,
                        data = { teleporter = { target = id1 } },
                    })

                    print(string.format("[epic_origin] 虫洞: 起源端(%d,%d) <-> 大陆端(%d,%d)",
                        worm1_tx, worm1_ty, land_tx, land_ty))
                else
                    print("[epic_origin_tiles] 未找到陆地，跳过虫洞")
                end
            else
                print("[epic_origin_tiles] entities 里没有 epic_chaosseed，跳过虫洞")
            end
        end

        return result
    end
end)

local function DeepFindPrefab(obj, prefab, visited)
    if type(obj) ~= "table" then return false end
    visited = visited or {}
    if visited[obj] then return false end
    visited[obj] = true
    if obj.prefab == prefab then return true end
    for _, v in pairs(obj) do
        if type(v) == "table" and DeepFindPrefab(v, prefab, visited) then
            return true
        end
    end
    return false
end

local function HasEpicOriginIsland(savedata, world_map)
    if savedata.ents["epic_chaosseed"] ~= nil
        and #savedata.ents["epic_chaosseed"] > 0 then
        return true
    end

    if savedata.map ~= nil and savedata.map.topology ~= nil
        and savedata.map.topology.ids ~= nil then
        for _, id in ipairs(savedata.map.topology.ids) do
            if id == "StaticLayoutIsland:epic_origin_tiles" then
                return true
            end
        end
    end

    for _, ents in pairs(savedata.ents) do
        for _, rec in ipairs(ents) do
            local d = rec.data
            if d ~= nil
                and (d.container ~= nil)
                and DeepFindPrefab(d, "epic_chaosseed") then
                return true
            end
        end
    end

    return false
end
local old_DoRetrofitting = require("map/retrofit_savedata").DoRetrofitting
local EpicOriginRetrofitting_EpicOrigin = require("map/ocean_retrofit_epic_origin")
require("map/retrofit_savedata").DoRetrofitting = function (savedata, world_map)
    if savedata.map ~= nil and savedata.map.prefab == "forest"
        and not HasEpicOriginIsland(savedata, world_map) then
        EpicOriginRetrofitting_EpicOrigin(world_map, savedata)
    end
    if old_DoRetrofitting then
        old_DoRetrofitting(savedata, world_map)
    end
end