require "constants"
require "mathutil"
require "map/terrain"

local obj_layout = require("map/object_layout")

local function FindEntsInArea(entities, left, top, size, blocking_prefabs)
	local right, bottom = left + size, top + size

	local ents_in_area = {}
	for prefab, ents in pairs(entities) do
		for i, e in ipairs(ents) do
			if e.x > left and e.x < right and e.z > top and e.z < bottom then
				if table.contains(blocking_prefabs, prefab) then
					return nil
				end
				table.insert(ents_in_area, {prefab = prefab, index = i})
			end
		end
	end

	return ents_in_area
end

local function AddSquareTopology(topology, left, top, size, room_id, tags)
	local index = #topology.ids + 1
	topology.ids[index] = room_id
	topology.story_depths[index] = 0

	local node = {}
	node.area = size * size
	node.c = 1 -- colour index
	node.cent = {left + (size / 2), top + (size / 2)}
	node.neighbours = {}
	node.poly = { {left, top},
				  {left + size, top},
				  {left + size, top + size},
				  {left, top + size}
				}
	node.tags  = tags
	node.type = NODE_TYPE.Default
	node.x = node.cent[1]
	node.y = node.cent[2]

	node.validedges = {}

	topology.nodes[index] = node

	return index
end

local function EpicOriginRetrofitting_EpicOrigin(map, savedata)
	local obj_layout = require("map/object_layout")

	local topology = savedata.map.topology
	local map_width = savedata.map.width
	local map_height = savedata.map.height
	local entities = savedata.ents

	local add_fn = {fn=function(prefab, points_x, points_y, current_pos_idx, entitiesOut, width, height, prefab_list, prefab_data, rand_offset)
				local x = (points_x[current_pos_idx] - width/2.0)*TILE_SCALE
				local y = (points_y[current_pos_idx] - height/2.0)*TILE_SCALE
				x = math.floor(x*100)/100.0
				y = math.floor(y*100)/100.0
				if entitiesOut[prefab] == nil then
					entitiesOut[prefab] = {}
				end
				local save_data = {x=x, z=y}
				if prefab_data then

					if prefab_data.data then
						if type(prefab_data.data) == "function" then
							save_data["data"] = prefab_data.data()
						else
							save_data["data"] = prefab_data.data
						end
					end
					if prefab_data.id then
						save_data["id"] = prefab_data.id
					end
					if prefab_data.scenario then
						save_data["scenario"] = prefab_data.scenario
					end
				end
				table.insert(entitiesOut[prefab], save_data)
			end,
			args={entitiesOut=entities, width=map_width, height=map_height, rand_offset = false, debug_prefab_list=nil}
		}

	local function AddWormholes()
		if entities["epic_chaosseed"] == nil then return end
		local chaos = entities["epic_chaosseed"][1]
		if chaos == nil then return end

		local TILE_SCALE = 4
		local center_tx = math.floor(chaos.x / TILE_SCALE + map_width / 2)
		local center_ty = math.floor(chaos.z / TILE_SCALE + map_height / 2)
		local worm1_tx = center_tx + 10
		local worm1_ty = center_ty + 10

		local LAND_TILES = {
			[WORLD_TILES.DIRT] = true,
			[WORLD_TILES.SAVANNA] = true, [WORLD_TILES.GRASS] = true,
			[WORLD_TILES.FOREST] = true, [WORLD_TILES.MARSH] = true,
			[WORLD_TILES.WOODFLOOR] = true, [WORLD_TILES.CARPET] = true,
			[WORLD_TILES.CHECKER] = true,
		}
		local land_tx, land_ty
		local start_x = math.random(5, map_width - 5)
		local start_y = math.random(5, map_height - 5)
		for radius = 0, math.max(map_width, map_height) do
			for dx = -radius, radius do
				for dy = -radius, radius do
					if math.max(math.abs(dx), math.abs(dy)) == radius then
						local x = start_x + dx
						local y = start_y + dy
						if x >= 0 and x < map_width and y >= 0 and y < map_height then
							if LAND_TILES[map:GetTile(x, y)] then
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
			print(string.format("[epic_origin retrofit] 虫洞: 起源端(%d,%d) <-> 大陆端(%d,%d)",
				worm1_tx, worm1_ty, land_tx, land_ty))
		else
			print("[epic_origin retrofit] 未找到陆地，跳过虫洞")
		end
	end

	local function is_rough_ocean(_left, _top, tile_size)
		for x = 0, tile_size do
			for y = 0, tile_size do
				if map:GetTile(_left + x, _top + y) ~= WORLD_TILES.OCEAN_ROUGH then
					return false
				end
			end
		end
		return true
	end
	local function is_rough_or_swell_ocean(_left, _top, tile_size)
		for x = 0, tile_size do
			for y = 0, tile_size do
				local tile = map:GetTile(_left + x, _top + y)
				if tile ~= WORLD_TILES.OCEAN_ROUGH and tile ~= WORLD_TILES.OCEAN_SWELL then
					return false
				end
			end
		end
		return true
	end

	local function TryToAddLayout(name, topology_delta, isvalidareafn)
	    local layout = obj_layout.LayoutForDefinition(name)
		local tile_size = #layout.ground

		topology_delta = topology_delta or 1

		local candidtates = {}
		local foundarea = false
		local num_steps = math.floor((map_width - tile_size) / tile_size)
		for x = 0, num_steps do
			for y = 0, num_steps do
				local left = 8 + (x > 0 and ((x * math.floor(map_width / num_steps)) - tile_size - 16) or 0)
				local top  = 8 + (y > 0 and ((y * math.floor(map_height / num_steps)) - tile_size - 16) or 0)
				if isvalidareafn(left, top, tile_size) then
					table.insert(candidtates, {top = top, left = left})
				end
			end
		end
		print("   " ..tostring(#candidtates) .. " candidtate locations")

		if #candidtates > 0 then
			local world_size = (tile_size + (topology_delta*2))*4

			shuffleArray(candidtates)
			for _, candidtate in ipairs(candidtates) do
				local top, left = candidtate.top, candidtate.left
				local world_top, world_left = (left-topology_delta)*4 - (map_width * 0.5 * 4), (top-topology_delta)*4 - (map_height * 0.5 * 4)

				local ents_to_remove = FindEntsInArea(savedata.ents, world_top - 5, world_left - 5, world_size + 10, {"boat", "malbatross", "oceanfish_shoalspawner", "chester_eyebone", "glommerflower", "klaussackkey"})
				if ents_to_remove ~= nil then
					print("   Removed " .. tostring(#ents_to_remove) .. " entities for static layout:")
					for i = #ents_to_remove, 1, -1 do
						print ("   - " .. tostring(ents_to_remove[i].prefab) .. " " )
						table.remove(savedata.ents[ents_to_remove[i].prefab], ents_to_remove[i].index)
					end

					obj_layout.Place({left, top}, name, add_fn, nil, map)
					if layout.add_topology ~= nil then
						-- NOTE: Ocean doesn't have node id's so it's ok not to add tile node ids for this are
						AddSquareTopology(topology, world_top, world_left, world_size, layout.add_topology.room_id, layout.add_topology.tags)
					end

					return true
				end
			end
		end
		return false
	end

	local success = TryToAddLayout("epic_origin_tiles", 0, is_rough_ocean) or TryToAddLayout("epic_origin_tiles", 0, is_rough_or_swell_ocean)

	if success then
		print("[epic_origin_tiles] 成功添加")
		AddWormholes()
	else
		print("[epic_origin_tiles] 未找到合适的海洋区域")
	end
end


return EpicOriginRetrofitting_EpicOrigin
