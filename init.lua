minesweeper = {}

local singleplayer = minetest.is_singleplayer()
local setting = minetest.setting_getbool("enable_tnt")
if (not singleplayer and setting ~= true) or (singleplayer and setting == false) then
	function minesweeper.register_placable(v)
	end
	return
end

local mine_index = {}

local creative = minetest.setting_getbool("creative_mode")

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
	minetest.log("action", "minesweeper mine explodes at "..minetest.pos_to_string(pos))
	meta:set_string("minesweeper", "nil")
	tnt.boom(pos, {radius = radius, damage_radius = radius * 2})
end

minetest.register_craftitem("minesweeper:mine", {
	description = "Mine",
	inventory_image = "minesweeper_mine.png",
	wield_image = "minesweeper_mine.png",
	on_place = function(itemstack, placer, pointed_thing)
		if pointed_thing.type == "node" then
			local pos = pointed_thing.under
			local node = minetest.get_node(pos)
			local node_def = minetest.registered_nodes[node.name]
			if not node_def then
				return
			end
			if node_def.buildable_to then
				pos = {x = pos.x, y = pos.y - 1, z = pos.z}
				node = minetest.get_node(pos)
			end
			local player_name = placer:get_player_name()
			if minetest.is_protected(pos, player_name) then
				minetest.record_protection_violation(pos, player_name)
				return
			end
			if minetest.get_item_group(node.name, "place_mine") == 1 then
				local meta = minetest.get_meta(pos)
				if meta:get_string("minesweeper") == "mine" then
					return
				end
				minetest.log("action", player_name.." places minesweeper mine in "..minetest.pos_to_string(pos))
				meta:set_string("minesweeper", "mine")
				table.insert(mine_index, pos)
				if not creative then
					itemstack:take_item()
					return itemstack
				end
			end
		end
	end
})

minetest.register_craftitem("minesweeper:detector", {
	description = "Mine Detector Tool",
	inventory_image = "minesweeper_detector.png",
	wield_image = "minesweeper_detector.png",
	on_place = function(itemstack, placer, pointed_thing)
		local pos = placer:get_pos()
		local flag = false
		for _,v in ipairs(mine_index) do
			if vector.distance(pos, v) < 16 then
				local node = minetest.get_node({x = v.x, y = v.y + 1, z = v.z})
				if node.name ~= "minesweeper:flag" then
					local player_name = placer:get_player_name()
					minetest.chat_send_player(player_name, "Unflaged mines detected nearby.")
					minetest.sound_play({name = "minesweeper_detect", gain = 0.3}, {to_player = player_name}, true)
					return
				else
					flag = true
				end
			end
		end
		if flag then
			minetest.chat_send_player(placer:get_player_name(), "No unflaged mines detected.")
		else
			minetest.chat_send_player(placer:get_player_name(), "No mines detected.")
		end
	end,
	on_secondary_use = function(itemstack, user, pointed_thing)
		local pos = user:get_pos()
		local flag = false
		for _,v in ipairs(mine_index) do
			if vector.distance(pos, v) < 16 then
				local node = minetest.get_node({x = v.x, y = v.y + 1, z = v.z})
				if node.name ~= "minesweeper:flag" then
					local player_name = user:get_player_name()
					minetest.chat_send_player(player_name, "Unflaged mines detected nearby.")
					minetest.sound_play({name = "minesweeper_detect", gain = 0.3}, {to_player = player_name}, true)
					return
				else
					flag = true
				end
			end
		end
		if flag then
			minetest.chat_send_player(user:get_player_name(), "No unflaged mines detected.")
		else
			minetest.chat_send_player(user:get_player_name(), "No mines detected.")
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
	sunlight_propagates = true,
	walkable = false,
	buildable_to = false,
	groups = {dig_immediate = 3},
	selection_box = {
		type = "fixed",
		fixed = {-0.25, -0.5, -0.25, 0.25, 0.3125, 0.25}
	}
})

minetest.register_node("minesweeper:sign", {
	description = "Minefield Warning Sign",
	drawtype = "nodebox",
	paramtype = "light",
	paramtype2 = "facedir",
	tiles = {"minesweeper_sign.png"},
	inventory_image = "minesweeper_sign_inv.png",
	wield_image = "minesweeper_sign_inv.png",
	sunlight_propagates = true,
	walkable = false,
	buildable_to = false,
	groups = {cracky = 2, attached_node = 1},
	sounds = default.node_sound_wood_defaults(),
	node_box = {
		type = "fixed",
		fixed = {
			{-0.375, -0.25, 0.4375, 0.375, 0.5, 0.5},
			{-0.0625, -0.5, 0.4375, 0.0625, -0.25, 0.5}
		}
	},
	on_construct = function(pos)
		local meta = minetest.get_meta(pos)
		meta:set_string("infotext", "Minefield!")
	end
})

minetest.register_craft({
	output = "minesweeper:mine",
	recipe = {
		{"default:steel_ingot", "default:steel_ingot", "default:steel_ingot"},
		{"default:mese_crystal", "tnt:tnt", "default:mese_crystal"},
		{"default:steel_ingot", "default:steel_ingot", "default:steel_ingot"}
	}
})

minetest.register_craft({
	output = "minesweeper:flag 4",
	recipe = {
		{"wool:red"},
		{"default:stick"}
	}
})

minetest.register_craft({
	type = "shapeless",
	output = "minesweeper:sign",
	recipe = {"default:sign_wall_wood", "minesweeper:flag"}
})

minetest.register_craft({
	output = "minesweeper:detector",
	recipe = {
		{"minesweeper:flag"},
		{"default:mese_crystal"},
		{"default:steel_ingot"}
	}
})

for i=1,26 do
	minetest.register_node("minesweeper:num_"..i, {
		description = "Minesweeper Number",
		drawtype = "signlike",
		paramtype = "light",
		paramtype2 = "wallmounted",
		tiles = {"minesweeper_num_"..i..".png"},
		sunlight_propagates = true,
		walkable = false,
		buildable_to = true,
		groups = {not_in_creative_inventory = 1},
		drop = "",
		selection_box = {
			type = "wallmounted",
			wall_top = {-0.5, 0.4375, -0.5, 0.5, 0.5, 0.5},
			wall_bottom = {-0.5, -0.5, -0.5, 0.5, -0.4375, 0.5},
			wall_side = {-0.5, -0.5, -0.5, -0.4375, 0.5, 0.5},
		},
		on_punch = function(pos, node, puncher)
			local item_name = puncher:get_wielded_item():get_name()
			if item_name ~= "default:stick" and item_name ~= "minesweeper:flag" and item_name ~= "minesweeper:detector" then
				minetest.remove_node(pos)
			end
		end
	})
end

minetest.register_globalstep(function(dtime)
	for i,v in ipairs(mine_index) do
		local meta = minetest.get_meta(v)
		if meta:get_string("minesweeper") ~= "mine" then
			table.remove(mine_index, i)
		else
			local node = minetest.get_node_or_nil({x = v.x, y = v.y + 1, z = v.z})
			if node and node.name ~= "minesweeper:flag" then
				local node_def = minetest.registered_nodes[node.name]
				if node_def and not node_def.buildable_to then
					boom(v)
				end
			else
				local objects = minetest.get_objects_inside_radius({x = v.x, y = v.y + 1, z = v.z}, 0.5)
				if objects[1] then
					boom(v)
				else
					local objects = minetest.get_objects_inside_radius({x = v.x, y = v.y + 0.1, z = v.z}, 0.8)
					for _,p in ipairs(objects) do
						if p:is_player() then
							boom(v)
						end
					end
				end
			end
		end
	end
end)

local player_table = {}

minetest.register_globalstep(function(dtime)
	local stack = ItemStack("minesweeper:detector")
	for _,player in ipairs(minetest.get_connected_players()) do
		local inv = player:get_inventory()
		if inv:contains_item("main", stack) then
			local pos = player:get_pos()
			local no_mine = true
			for _,v in ipairs(mine_index) do
				if vector.distance(pos, v) < 16 then
					local node = minetest.get_node({x = v.x, y = v.y + 1, z = v.z})
					if node.name ~= "minesweeper:flag" then
						no_mine = false
						local player_name = player:get_player_name()
						if not player_table[player_name] then
							player_table[player_name] = true
							minetest.chat_send_player(player_name, "Unflaged mines detected nearby.")
							minetest.sound_play({name = "minesweeper_detect", gain = 0.3}, {to_player = player_name}, true)
						end
						break
					end
				end
			end
			if no_mine then
				player_table[player:get_player_name()] = false
			end
		else
			player_table[player:get_player_name()] = nil
		end
	end
end)

minetest.register_abm({
	nodenames = {
		"minesweeper:num_1",
		"minesweeper:num_2",
		"minesweeper:num_3",
		"minesweeper:num_4",
		"minesweeper:num_5",
		"minesweeper:num_6",
		"minesweeper:num_7",
		"minesweeper:num_8",
		"minesweeper:num_9",
		"minesweeper:num_10",
		"minesweeper:num_11",
		"minesweeper:num_12",
		"minesweeper:num_13",
		"minesweeper:num_14",
		"minesweeper:num_15",
		"minesweeper:num_16",
		"minesweeper:num_17",
		"minesweeper:num_18",
		"minesweeper:num_19",
		"minesweeper:num_20",
		"minesweeper:num_21",
		"minesweeper:num_22",
		"minesweeper:num_23",
		"minesweeper:num_24",
		"minesweeper:num_25",
		"minesweeper:num_26"
	},
	interval = 1,
	chance = 1,
	action = function(pos, node)
		local ontopof = minetest.get_meta({x = pos.x, y = pos.y - 1, z = pos.z})
		if ontopof:get_string("minesweeper") == "mine" then
			boom({x = pos.x, y = pos.y - 1, z = pos.z})
		end
		local nodes = minetest.find_nodes_in_area({x = pos.x - 1, y = pos.y - 2, z = pos.z - 1}, {x = pos.x + 1, y = pos.y, z = pos.z + 1}, {"group:place_mine"})
		local mines = {}
		for _,v in ipairs(nodes) do
			local meta = minetest.get_meta(v)
			if meta:get_string("minesweeper") == "mine" then
				table.insert(mines, v)
			end
		end
		if mines[1] then
			minetest.swap_node(pos, {name = "minesweeper:num_"..#mines, param2 = 1})
		else
			minetest.remove_node(pos)
		end
	end
})

minetest.register_lbm({
	name = "minesweeper:look_for_mines",
	nodenames = {"group:place_mine"},
	run_at_every_load = true,
	action = function(pos, node)
		local meta = minetest.get_meta(pos)
		if contains(mine_index, pos) then
			if meta:get_string("minesweeper") ~= "mine" then
				for i,v in ipairs(mine_index) do
					local posv = minetest.pos_to_string(v)
					local poss = minetest.pos_to_string(pos)
					if posv == poss then
						table.remove(mine_index, i)
					end
				end
			end
		elseif meta:get_string("minesweeper") == "mine" then
			table.insert(mine_index, pos)
		end
	end
})

minetest.register_on_punchnode(function(pos, node, puncher, pointed_thing)
	local item_name = puncher:get_wielded_item():get_name()
	if item_name == "default:stick" or item_name == "minesweeper:flag" or item_name == "minesweeper:detector" then
		local node_def = minetest.registered_nodes[node.name]
		local use_pos = pos
		if node_def and node_def.buildable_to then
			use_pos = {x = pos.x, y = pos.y - 1, z = pos.z}
			node_def = minetest.registered_nodes[minetest.get_node(use_pos).name]
		end
		if node_def and node_def.drawtype == "normal" and node_def.walkable and not node_def.buildable_to then
			local nodes = minetest.find_nodes_in_area({x = use_pos.x - 1, y = use_pos.y - 1, z = use_pos.z - 1}, {x = use_pos.x + 1, y = use_pos.y + 1, z = use_pos.z + 1}, {"group:place_mine"})
			local mines = {}
			for _,v in ipairs(nodes) do
				local meta = minetest.get_meta(v)
				if meta:get_string("minesweeper") == "mine" then
					table.insert(mines, v)
				end
			end
			if mines[1] then
				local above = {x = use_pos.x, y = use_pos.y + 1, z = use_pos.z}
				local node = minetest.get_node(above)
				local node_def = minetest.registered_nodes[node.name]
				if node_def and node_def.buildable_to then
					minetest.swap_node(above, {name = "minesweeper:num_"..#mines, param2 = 1})
				end
			end
		end
	end
end)

function minesweeper.register_placable(v)
	local v_def = minetest.registered_nodes[v]
	local groups = table.copy(v_def.groups)
	groups.place_mine = 1
	minetest.override_item(v, {
		groups = groups,
		on_punch = function(pos, node, puncher, pointed_thing)
			local meta = minetest.get_meta(pos)
			if meta:get_string("minesweeper") == "mine" then
				boom(pos)
			else
				minetest.node_punch(pos, node, puncher, pointed_thing)
			end
		end,
		on_blast = function(pos, intensity)
			local meta = minetest.get_meta(pos)
			if meta:get_string("minesweeper") == "mine" then
				boom(pos)
			else
				minetest.remove_node(pos)
				minetest.add_item(pos, v_def.drop)
			end
		end,
		after_destruct = function(pos)
			for i,v in ipairs(mine_index) do
				local posv = minetest.pos_to_string(v)
				local poss = minetest.pos_to_string(pos)
				if posv == poss then
					table.remove(mine_index, i)
					return
				end
			end
		end
	})
end

for _,v in ipairs({
	"default:dirt",
	"default:dirt_with_grass",
	"default:dirt_with_grass_footsteps",
	"default:dirt_with_dry_grass",
	"default:dirt_with_snow",
	"default:dirt_with_rainforest_litter",
	"default:dirt_with_coniferous_litter",
	"default:dry_dirt",
	"default:dry_dirt_with_dry_grass",
	"default:permafrost",
	"default:permafrost_with_stones",
	"default:permafrost_with_moss",
	"default:sand",
	"default:desert_sand",
	"default:silver_sand",
	"default:gravel",
	"default:clay",
	"default:snowblock"
}) do
	minesweeper.register_placable(v)
end
