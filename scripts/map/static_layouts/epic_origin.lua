local objects = {
    {
      name = "",
      type = "watertree_pillar",
      shape = "rectangle",
      x = 544,
      y = 544,
      width = 0,
      height = 0,
      visible = true,
      properties = {}
    },
    {
      name = "",
      type = "watertree_pillar",
      shape = "rectangle",
      x = 928,
      y = 928,
      width = 0,
      height = 0,
      visible = true,
      properties = {}
    },
    {
      name = "",
      type = "watertree_pillar",
      shape = "rectangle",
      x = 544,
      y = 928,
      width = 0,
      height = 0,
      visible = true,
      properties = {}
    },
    {
      name = "",
      type = "watertree_pillar",
      shape = "rectangle",
      x = 928,
      y = 544,
      width = 0,
      height = 0,
      visible = true,
      properties = {}
    },
    {
      name = "",
      type = "epic_chaosseed",
      shape = "rectangle",
      x = 736,
      y = 736,
      width = 0,
      height = 0,
      visible = true,
      properties = {}
    },
    {
      name = "",
      type = "nightmaregrowth",
      shape = "rectangle",
      x = 1376,
      y = 736,
      width = 0,
      height = 0,
      visible = true,
      properties = {}
    },
}

local CX, CY = 736, 736
local TS = 64
for r = 2, 20, 2 do
  local radius = r * TS * 0.75
  local spacing = 0.7
  local num = math.max(6, math.floor(2 * math.pi * r / spacing))
  for i = 0, num - 1 do
      local angle = 2 * math.pi * i / num
      table.insert(objects, {
        name = "",
        type = "fireflies",
        shape = "rectangle",
        x = CX + math.cos(angle) * radius,
        y = CY + math.sin(angle) * radius,
        width = 0,
        height = 0,
        visible = true,
        properties = {},
      })
  end
end

local SX = 763
local SY = 256
for i = 1, 6, 1 do
  table.insert(objects, {
    name = "",
    type = "skeleton",
    shape = "rectangle",
    x = SX + math.random(-i,i) *TS,
    y = SY + math.random(-i/2,i/2) *TS,
    width = 0,
    height = 0,
    visible = true,
    properties = {},
  })
  if math.random()<0.6 then
    table.insert(objects, {
      name = "",
      type = "papyrus",
      shape = "rectangle",
      x = SX + math.random(-i,i) *TS,
      y = SY + math.random(-i/2,i/2) *TS,
      width = 0,
      height = 0,
      visible = true,
      properties = {},
    })
  end
  if math.random()<0.3 then
    table.insert(objects, {
      name = "",
      type = "featherpencil",
      shape = "rectangle",
      x = SX + math.random(-i,i) *TS,
      y = SY + math.random(-i/2,i/2) *TS,
      width = 0,
      height = 0,
      visible = true,
      properties = {},
    })
  end
end

for i = 1, 10, 1 do
  table.insert(objects, {
    name = "",
    type = "moon_tree_tall",
    shape = "rectangle",
    x = math.random(2,6) *TS,
    y = math.random(2,21) *TS,
    width = 0,
    height = 0,
    visible = true,
    properties = {},
  })
end

for i = 1, 4, 1 do
  table.insert(objects, {
    name = "",
    type = "houndmound",
    shape = "rectangle",
    x = 1120 + i*TS,
    y = 128 + math.random(1,i*4)*TS,
    width = 0,
    height = 0,
    visible = true,
    properties = {},
  })
  if math.random()<0.1 or i==4 then
    table.insert(objects, {
      name = "",
      type = "cane",
      shape = "rectangle",
      x = 1120 + math.random(0,3)*TS,
      y = 128 + math.random(1,i*4)*TS,
      width = 0,
      height = 0,
      visible = true,
      properties = {},
    })
  end
end

-- if math.random()<0.5 then
  table.insert(objects, {
    name = "",
    type = "ancient_altar_broken",
    shape = "rectangle",
    x = 1312,
    y = 1312,
    width = 0,
    height = 0,
    visible = true,
    properties = {},
  })
-- end

return {
  version = "1.1",
  luaversion = "5.1",
  orientation = "orthogonal",
  width = 23,
  height = 23,
  tilewidth = 64,
  tileheight = 64,
  properties = {},
  tilesets = {
    {
      name = "tiles",
      firstgid = 1,
      tilewidth = 64,
      tileheight = 64,
      spacing = 0,
      margin = 0,
      image = "../../../../tools/tiled/dont_starve/tiles.png",
      imagewidth = 512,
      imageheight = 128,
      properties = {},
      tiles = {}
    }
  },
  layers = {
    {
      type = "tilelayer",
      name = "BG_TILES",
      x = 0,
      y = 0,
      width = 23,
      height = 23,
      visible = true,
      opacity = 1,
      properties = {},
      encoding = "lua",
      data = {
        18, 18, 18, 18, 18, 18, 18, 18, 18, 18, 18, 18, 18, 18, 18, 18, 18, 18, 18, 18, 18, 18, 18,
        18, 34, 34, 34, 34, 34, 34, 34, 34, 34, 34, 34, 25, 25, 25, 25, 25, 25, 25, 25, 25, 25, 18,
        18, 34, 34, 34, 34, 34, 34, 34, 34, 34, 34, 25, 25, 25, 25, 25, 25, 25, 25, 25, 25, 25, 18,
        18, 34, 34, 34, 34, 34, 34, 34, 34, 34, 34, 34, 25, 25, 25, 25, 25, 25, 25, 25, 25, 25, 18,
        18, 34, 34, 34, 34, 34, 34, 34, 34, 34, 34, 25, 25, 25, 25, 25, 25, 25, 25, 25, 25, 25, 18,
        18, 34, 34, 34, 34, 34, 34, 34, 34, 34, 34, 34, 25, 25, 25, 25, 25, 25, 25, 25, 25, 25, 18,
        18, 34, 34, 34, 34, 34, 34, 34, 34, 34, 34, 25, 25, 25, 25, 25, 25, 25, 25, 25, 25, 25, 18,
        18, 34, 34, 34, 34, 34, 34, 18, 18, 18, 18, 18, 18, 18, 18, 18, 25, 25, 25, 25, 25, 25, 18,
        18, 34, 34, 34, 34, 34, 34, 18, 18, 18, 18, 18, 18, 18, 18, 18, 25, 25, 25, 25, 25, 25, 18,
        18, 34, 34, 34, 34, 34, 34, 18, 18, 18, 18, 18, 18, 18, 18, 18, 25, 25, 25, 25, 25, 25, 18,
        18, 34, 34, 34, 34, 34, 34, 18, 18, 18, 18, 18, 18, 18, 18, 18, 25, 25, 25, 25, 25, 25, 18,
        18, 34, 34, 34, 34, 34, 34, 18, 18, 18, 18, 18, 18, 18, 18, 18, 25, 25, 25, 25, 25, 25, 18,
        18, 34, 34, 34, 34, 34, 34, 18, 18, 18, 18, 18, 18, 18, 18, 18, 25, 25, 25, 25, 25, 25, 18,
        18, 34, 34, 34, 34, 34, 34, 18, 18, 18, 18, 18, 18, 18, 18, 18, 25, 25, 25, 25, 25, 25, 18,
        18, 34, 34, 34, 34, 34, 34, 18, 18, 18, 18, 18, 18, 18, 18, 18, 25, 25, 25, 25, 25, 25, 18,
        18, 34, 34, 34, 34, 34, 34, 18, 18, 18, 18, 18, 18, 18, 18, 18, 25, 25, 25, 25, 25, 25, 18,
        18, 34, 34, 34, 34, 34, 34, 34, 34, 34, 34, 34, 25, 25, 25, 25, 25, 25, 25, 25, 25, 25, 18,
        18, 34, 34, 34, 34, 34, 34, 34, 34, 34, 34, 25, 25, 25, 25, 25, 25, 25, 25, 25, 25, 25, 18,
        18, 34, 34, 34, 34, 34, 34, 34, 34, 34, 34, 34, 25, 25, 25, 25, 25, 25, 25, 25, 25, 25, 18,
        18, 34, 34, 34, 34, 34, 34, 34, 34, 34, 34, 25, 25, 25, 25, 25, 25, 25, 25, 25, 25, 25, 18,
        18, 34, 34, 34, 34, 34, 34, 34, 34, 34, 34, 34, 25, 25, 25, 25, 25, 25, 25, 25, 25, 25, 18,
        18, 34, 34, 34, 34, 34, 34, 34, 34, 34, 34, 25, 25, 25, 25, 25, 25, 25, 25, 25, 25, 25, 18,
        18, 18, 18, 18, 18, 18, 18, 18, 18, 18, 18, 18, 18, 18, 18, 18, 18, 18, 18, 18, 18, 18, 18
      }
    },

    {
      type = "objectgroup",
      name = "FG_OBJECTS",
      visible = true,
      opacity = 1,
      properties = {},
      objects = objects
    }
  }
}
