minesweeper = {}
minesweeper.mines = {}

local singleplayer = minetest.is_singleplayer()
local setting = minetest.setting_getbool("enable_tnt")
if (not singleplayer and setting ~= true) or
		(singleplayer and setting == false) then
	return
end

local contains = function(table, element)
  local elementstring = minetest.pos_to_string(element)
  for _, value in pairs(table) do
    local valuestring = minetest.pos_to_string(value)
    if valuestring == elementstring then
      return true
    end
  end
  return false
end

local radius = tonumber(minetest.setting_get("tnt_radius") or 3)
local boom = function(pos)
  local meta = minetest.get_meta(pos)
  meta:set_string("minesweeper", "nil")
  tnt.boom(pos, {radius = radius, damage_radius = radius * 2})
end

minetest.register_craftitem("minesweeper:mine", {
  description = "Mine",
  inventory_image = "minesweeper_mine.png",
  wield_image = "minesweeper_mine.png",
  on_place = function(itemstack, placer, pointed_thing)
    if pointed_thing.type == "node" then
      local pos = minetest.get_pointed_thing_position(pointed_thing, above)
      local node = minetest.get_node(pos)
			local node = minetest.registered_nodes[node.name]
			if node.buildable_to then
				pos = {x = pos.x, y = pos.y - 1, z = pos.z}
			end
			if minetest.is_protected(pos, placer:get_player_name()) then
				minetest.record_protection_violation(pos, placer:get_player_name())
				return
			end
			local node = minetest.get_node(pos)
      if node.name == "default:dirt" or node.name == "default:dirt_with_grass"
          or node.name == "default:dirt_with_grass_footsteps" or node.name == "default:dirt_with_dry_grass"
          or node.name == "default:dirt_with_snow" then
        local meta = minetest.get_meta(pos)
        meta:set_string("minesweeper", "mine")
        table.insert(minesweeper.mines, pos)
        local creative = minetest.setting_getbool("creative_mode")
        if not creative then
          itemstack:take_item()
          return itemstack
        end
      end
    end
  end
})

minetest.register_node("minesweeper:flag", {
	description = "Minesweeper Flag",
	drawtype = "torchlike",
	paramtype = "light",
	tiles = {"minesweeper_flag.png"},
	inventory_image = "minesweeper_flag.png",
	wield_image = "minesweeper_flag.png",
	walkable = false,
	buildable_to = true,
	groups = {dig_immediate = 2},
	selection_box = {
		type = "fixed",
		fixed = {-0.25, -0.5, -0.25, 0.25, 0.3125, 0.25}
	}
})

minetest.register_craft({
	output = "minesweeper:mine",
	recipe = {
		{"default:steel_ingot", "default:steel_ingot", "default:steel_ingot"},
		{"", "tnt:tnt", ""},
		{"default:steel_ingot", "default:steel_ingot", "default:steel_ingot"}
	}
})

minetest.register_craft({
	output = "minesweeper:flag",
	recipe = {
		{"wool:red"},
		{"default:stick"}
	}
})

for i=1,26 do
	minetest.register_node("minesweeper:num_"..i, {
		description = "Minesweeper Number",
		drawtype = "signlike",
		paramtype = "light",
		paramtype2 = "wallmounted",
		tiles = {"minesweeper_num_"..i..".png"},
		walkable = false,
		buildable_to = true,
		groups = {dig_immediate = 2, not_in_creative_inventory = 1},
		drop = "",
		selection_box = {
			type = "wallmounted",
			wall_top = {-0.5, 0.4375, -0.5, 0.5, 0.5, 0.5},
			wall_bottom = {-0.5, -0.5, -0.5, 0.5, -0.4375, 0.5},
			wall_side = {-0.5, -0.5, -0.5, -0.4375, 0.5, 0.5},
		}
	})
end

local node_types = {
  "default:dirt",
  "default:dirt_with_grass",
  "default:dirt_with_grass_footsteps",
  "default:dirt_with_dry_grass",
  "default:dirt_with_snow"
}
for i,v in ipairs(node_types) do
  minetest.override_item(v, {
    on_punch = function(pos, node, puncher, pointed_thing)
      local meta = minetest.get_meta(pos)
      if meta:get_string("minesweeper") == "mine" then
        for k,v in pairs(minesweeper.mines) do
          local posv = minetest.pos_to_string(v)
          local poss = minetest.pos_to_string(pos)
          if posv == poss then
            table.remove(minesweeper.mines, k)
          end
        end
        boom(pos)
			elseif puncher:get_wielded_item():get_name() == "default:stick" then
				local nodes = minetest.find_nodes_in_area({x = pos.x - 1, y = pos.y - 1, z = pos.z - 1}, {x = pos.x + 1, y = pos.y + 1, z = pos.z + 1}, {
					"default:dirt",
					"default:dirt_with_grass",
					"default:dirt_with_grass_footsteps",
					"default:dirt_with_dry_grass",
					"default:dirt_with_snow"
				})
				local mines = {}
				for k,v in pairs(nodes) do
					local meta = minetest.get_meta(v)
					if meta:get_string("minesweeper") == "mine" then
						table.insert(mines, v)
					end
				end
				if mines[1] then
					local above = {x = pos.x, y = pos.y + 1, z = pos.z}
					local node = minetest.get_node(above)
					local node2 = minetest.registered_nodes[node.name]
					if node2.buildable_to then
						minetest.swap_node(above, {name = "minesweeper:num_"..#mines, param2 = 1})
					end
				end
      end
    end,
    on_blast = function(pos, intensity)
      local meta = minetest.get_meta(pos)
      if meta:get_string("minesweeper") == "mine" then
        for k,v in pairs(minesweeper.mines) do
          local posv = minetest.pos_to_string(v)
          local poss = minetest.pos_to_string(pos)
          if posv == poss then
            table.remove(minesweeper.mines, k)
          end
        end
        boom(pos)
      else
        minetest.remove_node(pos)
        local node = minetest.registered_nodes[v]
        minetest.add_item(pos, node.drop)
      end
    end
  })
end

minetest.register_globalstep(function(dtime)
	for k,v in pairs(minesweeper.mines) do
    local above = {x = v.x, y = v.y + 1, z = v.z}
    local node = minetest.get_node(above)
    local node = minetest.registered_nodes[node.name]
    if not node.buildable_to then
      boom(v)
      table.remove(minesweeper.mines, k)
    else
      local objects = minetest.get_objects_inside_radius(above, 0.5)
      if objects[1] then
        boom(v)
        table.remove(minesweeper.mines, k)
      else
        local objects = minetest.get_objects_inside_radius(above, 1)
        for k2,p in pairs(objects) do
          if p:is_player() then
            boom(v)
            table.remove(minesweeper.mines, k)
          end
        end
      end
    end
	end
end)

minetest.register_lbm({
	name = "minesweeper:look_for_mines",
	nodenames = {
    "default:dirt",
    "default:dirt_with_grass",
    "default:dirt_with_grass_footsteps",
    "default:dirt_with_dry_grass",
    "default:dirt_with_snow"
  },
	run_at_every_load = true,
	action = function(pos, node)
    local meta = minetest.get_meta(pos)
    if contains(minesweeper.mines, pos) then
      if meta:get_string("minesweeper") ~= "mine" then
        for k,v in pairs(minesweeper.mines) do
          local posv = minetest.pos_to_string(v)
          local poss = minetest.pos_to_string(pos)
          if posv == poss then
            table.remove(minesweeper.mines, k)
          end
        end
      end
    elseif meta:get_string("minesweeper") == "mine" then
		  table.insert(minesweeper.mines, pos)
    end
	end
})
