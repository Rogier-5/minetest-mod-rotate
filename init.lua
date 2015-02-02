
local wrench_debug = 0
-- Hack to compute pitch based on eye position instead of feet position
local eye_offset_hack = 1.7
-- Number of uses of a steel wench. The actual number may be slightly
-- lower, depending on how well this number divides 65535
local wrench_uses_steel = 450
local mod_name = "wrench"
-- Choose recipe.
--local craft_recipe = "beak_north"		-- conflicts with technic wrench
--local craft_recipe = "beak_northwest"
local craft_recipe = "beak_west"
--local craft_recipe = "beak_southwest"
--local craft_recipe = "beak_south"
local alt_recipe = true				-- Register a second, alternate recipe

local PI = math.atan2(0,-1)
local mod_name_upper=string.upper(mod_name)

local opposite = {
	north = "south",
	south = "north",
	east = "west",
	west = "east",
	up = "down",
	down = "up",
	front = "back",
	back = "front",
	top = "bottom",
	bottom = "top",
	left = "right",
	right = "left",
	}

local function dup_table(t)
	local k,v
	local dup = {}
	for k,v in pairs(t) do
		dup[k] = v
	end
	return t
end

local or11n_directions = {"up", "north", "east"}
local or11n_code_prefix = "UNE="
local function or11n_code(node_or11n)
	local or11n_prefix=""
	local node_or11n_code=""
	for i,dir in ipairs(or11n_directions) do
		node_or11n_code = node_or11n_code .. "," .. node_or11n[dir]
	end
	node_or11n_code = or11n_code_prefix .. string.sub(node_or11n_code,2)
	return node_or11n_code
end

local function rotate_node(node_or11n, rotation_spec)
	local dir
	local rotated_node_or11n = {}
	for _,dir in ipairs(or11n_directions) do
		if rotation_spec[dir] then
			local new_dir = rotation_spec[dir]
			if node_or11n[new_dir] then
				rotated_node_or11n[new_dir] = node_or11n[dir]
			else
				rotated_node_or11n[opposite[new_dir]] = opposite[node_or11n[dir]]
			end
		else
			rotated_node_or11n[dir] = node_or11n[dir]
		end
	end
	return rotated_node_or11n
end

-- Define rotations when looking at a specific side of the object.
-- clockwise rotations are defined.
-- non-clockwise rotations are mapped to clockwise rotations
-- mappings have the following format:
-- - string: use the clockwise rotation for the specified side
-- - table: use the player's facing direction to find the side whose clockwise rotation to use
local rotation_specifications = {
	north = {
		cw =	{up="west", west="down", down="east", east="up"},
		ccw =	"south",
		up =	"west",
		down =	"east",
		left =	"up",
		right = "down",
		},
	south = {
		cw =	{up="east", east="down", down="west", west="up"},
		ccw =	"north",
		up =	"east",
		down =	"west",
		left =	"up",
		right =	"down",
		},
	east = {
		cw =	{up="north", north="down", down="south", south="up"},
		ccw =	"west",
		up =	"north",
		down =	"south",
		left =	"up",
		right =	"down",
		},
	west = {
		cw =	{up="south", south="down", down="north", north="up"},
		ccw =	"east",
		up =	"south",
		down =	"north",
		left =	"up",
		right =	"down",
		},
	up = {
		cw =	{north="east", east="south", south="west", west="north"},
		ccw =	"down",
		up =	{north="east", east="south", south="west", west="north"},
		down =	{north="west", west="south", south="east", east="north"},
		left =	{north="north", east="east", south="south", west="west"},
		right =	{north="south", east="west", south="north", west="east"},
		},
	down = {
		cw =	{north="west", west="south", south="east", east="north"},
		ccw =	"up",
		up =	{north="west", west="south", south="east", east="north"},
		down =	{north="east", east="south", south="west", west="north"},
		left =	{north="south", east="west", south="north", west="east"},
		right =	{north="north", east="east", south="south", west="west"},
		},
	}

-- Specification of minetest node orientation behavior
--
-- A node is defined as having 6 sides: left, right, front, back, top, bottom
-- Each of these could be oriented in one of 6 'compass' directions: north,
-- east, south, west, up or down.
-- The facing direction of 3 sides is sufficient to define the orientation of
-- a node.
--
-- Every orientation is specified by listing which sides of a node face in
-- each of 3 of the compass directions: up, north, east. E.g.:
--	{up="top", north="front", east="right"}
--
-- Every rotation is specfied by listing, for every compass direction, where
-- the side of the node that faced there previously will be facing next.
-- Directions which don't change don't need to be specified. E.g.:
--	{north="east", east="south", south="west", west="north"}
-- (i.e.: the rotation will move the side of the node that faced north, to
--        the west)
--
-- Minetest specifies the orientation of a node using two parameters:
-- - axis: specfiying the direction in which the originally vertical axis points
--   	   (6 values, as there are 6 possible directions)
-- - rotation: specifying the rotation around this axis, in 90-degrees steps
--         (0, 90, 180, 270 degrees - 4 possible rotations)
--
-- Table fields:
-- - axis_or11n: table specifying which side of an node faces which direction
--   with just the given axis orientation (i.e. rotation not changed)
-- - rot_cycle: table specifying how the sides change when rotation is applied
--   Default orientation of a node is defined as: {up="top", north="front", east="right"}
local mt_orientation = {
	[0] = { axis_or11n={up="top", north="front", east="right"},	rot_cycle={north="east", east="south", south="west", west="north"} },
	[1] = { axis_or11n={up="back", north="top", east="right"},	rot_cycle={up="west", west="down", down="east", east="up"} },
	[2] = { axis_or11n={up="front", north="bottom", east="right"},	rot_cycle={down="west", west="up", up="east", east="down"} },
	[3] = { axis_or11n={up="left", north="front", east="top"},	rot_cycle={north="down", down="south", south="up", up="north"} },
	[4] = { axis_or11n={up="right", north="front", east="bottom"},	rot_cycle={north="up", up="south", south="down", down="north"} },
	[5] = { axis_or11n={up="bottom", north="front", east="left"},	rot_cycle={north="west", west="south", south="east", east="north"} },
	}

-- Table of mappings between minetest orientation code (0..23) and this mod's
-- own orientation code.
-- Wrench orientation consists of list of sides facing up, north and east
-- shorthand code of the form 'UNE=<up-side>,<north-side>,<east-side>'
-- (contents are computed at startup, and only used at startup)
--
-- entries:
--	<int> = { code=<code>, node=<node orientation table> }
--	<code> = <int>
-- Example entries:
--	[0] = { code="UNE=top,front,right", node={up="top", north="front", east="right"},
--	["UNE=top,front,right"] = 0
--
local mt_wrench_orientation_map = {}

-- Table of defined rotations - used at runtine to lookup the rotations
-- for every side of a node the user can be facing (north, east, ...), it contains a table
-- of minetest orientation code (0..23) to clockwise rotated minetest orientation code.
-- e.g.:
-- { north = { [0] = 1, [1] = 4, [...], [23] = 5 },
--   south = { [...] },
--   [...] }
-- (contents are computed at startup)
local mt_clockwise_rotation_map = {}

-- Table of nodes previously rotated by users.
-- (used to avoid wearing the tool for multiple consecutive rotations of the same node)
local player_rotation_history = {}


local function compute_wrench_orientation_codes()
	local mt_axis
	for mt_axis = 0,5 do
		local mt_axis_spec = mt_orientation[mt_axis]
		local mt_rot=0
		local node_or11n = dup_table(mt_axis_spec.axis_or11n)
		for mt_rot = 0, 3 do
			local mt_orientation_code = bit.bor(bit.lshift(mt_axis, 2), mt_rot)
			local node_or11n_code=or11n_code(node_or11n)
			mt_wrench_orientation_map[mt_orientation_code] = { code = node_or11n_code, node = node_or11n }
			if not mt_wrench_orientation_map[node_or11n_code] then
				--Different values of mt_orientation_code will map to the same code...
				mt_wrench_orientation_map[node_or11n_code] = mt_orientation_code
			end
			node_or11n = rotate_node(node_or11n, mt_axis_spec.rot_cycle, true)
		end
	end
	if wrench_debug >= 2 then
		local k,v
		for k,v in pairs(mt_wrench_orientation_map) do
			if type(k) == "string" then
				print(string.format("Wrench orientation[WR]: %s -> %d", k, v))
			else
				print(string.format("Wrench orientation[MT]: %d -> { %s %s %s (%s) }", k, v.node.up, v.node.north, v.node.east, v.code))
			end
		end
	end
end

local function precompute_clockwise_rotations()
	local mt_or11n
	for mt_or11n = 0, 23 do
		local facing
		for facing, rotation_spec in pairs(rotation_specifications) do
			local node_or11n = dup_table(mt_wrench_orientation_map[mt_or11n].node)
			if not mt_clockwise_rotation_map[facing] then
				mt_clockwise_rotation_map[facing] = {}
			end
			node_or11n = rotate_node(node_or11n, rotation_spec.cw, true)
			local node_or11n_code = or11n_code(node_or11n)
			mt_clockwise_rotation_map[facing][mt_or11n] = mt_wrench_orientation_map[node_or11n_code]
		end
	end
	-- Just in case...:
--	for mt_or11n = 24, 31 do
--		for facing, rotation_spec in pairs(rotation_specifications) do
--			mt_clockwise_rotation_map[facing][mt_or11n] = 0
--		end
--	end
	if wrench_debug >= 2 then
		local k0, v0
		for k0,v0 in pairs(mt_clockwise_rotation_map) do
			io.write(string.format("%-10s:", k0))
			local i
			for i = 0, 23 do
				if v0[i] then
					io.write(string.format(" %2d",v0[i]))
				else
					io.write(string.format(" --"))
				end
			end
			io.write("\n")
		end
	end
end


-- mapping of:
-- - <pitch quadrant> to facing direction
-- - <yaw quadrant,pitch quadrant> to faced side of the node
local quadrant_to_facing_map = {
	["-2"] = "south",
	["-1"] = "west",
	["0"] = "north",
	["1"] = "east",
	["2"] = "south",
	["-2,-1"] = "up",
	["-1,-1"] = "up",
	["0,-1"] = "up",
	["1,-1"] = "up",
	["2,-1"] = "up",
	["-2,0"] = "north",
	["-1,0"] = "east",
	["0,0"] = "south",
	["1,0"] = "west",
	["2,0"] = "north",
	["-2,1"] = "down",
	["-1,1"] = "down",
	["0,1"] = "down",
	["1,1"] = "down",
	["2,1"] = "down",
	}

-- Given a node's position and a player, compute:
-- - the compass direction (NESW) the player is facing
-- - which side of the node the player is faacing most
-- return:
-- { facing_direction = <direction (NESW)>, faced_side = <direction (NESWUD)> }
local function player_node_state(player, node_pos)
	local c
	local v
	local player_pos = player:getpos()

	-- TODO: compute pitch based on actual eye position (is that possible at all ??)
	player_pos.y = player_pos.y + eye_offset_hack
	local node_dir = {}
	for _,c in ipairs({"x", "y", "z"}) do
		node_dir[c] = node_pos[c] - player_pos[c]
	end
	local result = {}

	-- Compute facing direction
	local yaw = math.atan2(node_dir.x, node_dir.z)
	local hquadrant = math.floor((yaw + (PI/4)) / (PI/2))
	result.facing_direction = quadrant_to_facing_map[string.format("%d",hquadrant)]

	-- Compute faced side of the node
	local pitch = math.atan2(node_dir.y, math.sqrt(node_dir.x*node_dir.x+node_dir.z*node_dir.z))
	local vquadrant = math.floor((pitch + (PI/4)) / (PI/2))
	result.faced_side = quadrant_to_facing_map[string.format("%d,%d",hquadrant,vquadrant)]

	if not result.faced_side or not result.facing_direction then
		minetest.log("error",string.format("[%s]: player_node_state: internal error: facing_direction = %s, faced_side=%s",
			mod_name_upper,result.facing_direction, result.faced_side))
	end
	return result
end

-- Given the player's state (see player_node_state()) and desired rotation
-- direction, lookup the equivalent clockwise rotation side of the node.
-- i.e. the side of the node, that will rotate clockwise.
local function clockwise_rotation_side(state, rotation)
	local rot_side = state.faced_side
	if rotation ~= "cw" then
		rot_side = rotation_specifications[state.faced_side][rotation]
		if type(rot_side) == "table" then
			rot_side = rotation_specifications[state.facing_direction]
		end
	end
	return rot_side
end

-- Perform the actual rotation lookup. Pretty straightforward...
local function lookup_node_rotation(node_pos, old_orientation, player, rotation)
	local state = player_node_state(player, node_pos)
	local clockwise_side = clockwise_rotation_side(state, rotation)
	return mt_clockwise_rotation_map[clockwise_side][old_orientation]
end

local function creative_mode(player)
	-- support unified inventory's creative priv.
	return minetest.setting_getbool("creative_mode") or
		minetest.get_player_privs(player:get_player_name()).creative
end

-- Check whether this is the same node as previously rotated
-- (if so, return true, else false)
-- and remember this node for the next time.
local function repeated_rotation(player, node, pos)
	local player_name = player:get_player_name()
	local old_history = player_rotation_history[player_name]
	local new_history = {}
	new_history.time = os.time()
	new_history.node_name = node.name
	new_history.node_pos = dup_table(pos)
	player_rotation_history[player_name] = new_history
	return old_history ~= nil
		and new_history.time - old_history.time < 60
		and new_history.node_name == old_history.node_name
		and new_history.node_pos.x == old_history.node_pos.x
		and new_history.node_pos.y == old_history.node_pos.y
		and new_history.node_pos.z == old_history.node_pos.z
end

-- Main rotation function
local function wrench_handler(itemstack, player, pointed_thing, mode, material, max_uses)

	if pointed_thing.type ~= "node" then
		return
	end

	local pos = pointed_thing.under

	if minetest.is_protected(pos, player:get_player_name()) then
		minetest.record_protection_violation(pos, player:get_player_name())
		return
	end

	local node = minetest.get_node(pos)
	local ndef = minetest.registered_nodes[node.name]
	if not ndef or ndef.paramtype2 ~= "facedir" or
			(ndef.drawtype == "nodebox" and
			ndef.node_box.type ~= "fixed") or
			node.param2 == nil then
		return
	end

	if ndef.can_dig and not ndef.can_dig(pos, player) then
		return
	end

	-- Set param2
	local old_param2 = node.param2
	node.param2 = lookup_node_rotation(pos, old_param2, player, mode)

	if wrench_debug >= 1 then
		minetest.chat_send_player(player:get_player_name(),
				string.format("Node wrenched: axis %d, rot %d (%d) ->  axis: %d, rot: %d (%d)",
					bit.band(bit.rshift(old_param2, 2), 0x7),
					bit.band(old_param2, 0x3),
					old_param2,
					bit.band(bit.rshift(node.param2, 2), 0x7),
					bit.band(node.param2, 0x3),
					node.param2))
	end

	minetest.swap_node(pos, node)

	if not creative_mode(player) and not repeated_rotation(player, node, pos) then
		-- 'ceil' ensures that the minimum wear is *always* 1
		-- (and makes the tools wear a tiny bit faster)
		itemstack:add_wear(math.ceil(65535 / max_uses))
	end

	return itemstack
end

-- Table of valid wrench modes, mapped to the next mode in the cycle
-- "" is the initial mode - which is non-operational (i.e. does nothing)
local wrench_modes = { [""]= "cw", cw="ccw", ccw="right", right="left", left="up", up="down", down="cw" }
local wrench_materials = {
	-- Wooden wrench is extra - for players who have not mined metals yet
	-- Its low usage count is intentional: to encourage players to craft metal wrenches
	wood = {
		description = "Wooden",
		ingredient = "group:stick",
		use_factor = 0.1
		},
	steel = {
		description = "Steel",
		ingredient = "default:steel_ingot",
		use_factor = 1
		},
	copper = {
		description = "Copper",
		ingredient = "default:copper_ingot",
		use_factor = 1.55
		},
	gold = {
		description = "Gold",
		ingredient = "default:gold_ingot",
		use_factor = 2.1
		},
	}

local function register_wrench(material, material_descr, uses, mode, next_mode)
	local sep = "_"
	local notcrea = 1
	local descr_extra = "; "
	if mode == "" then
		sep = ""
		notcrea = 0
		descr_extra = ""
	end
	minetest.register_tool(mod_name .. ":wrench_" .. material .. sep .. mode, {
		description = material_descr .. " wrench (" .. mode .. descr_extra .. "left-click rotates, right-click cycles mode)",
		wield_image = "wrench_" .. material .. ".png",
		inventory_image = "wrench_" .. material .. sep .. mode ..".png",
		groups = { not_in_creative_inventory = notcrea },
		on_use = function(itemstack, player, pointed_thing)
			if mode == "" then
				minetest.chat_send_player(player:get_player_name(), "ALERT: Wrench is not configured yet. Right-click to set / cycle modes")
				return
			end
			wrench_handler(itemstack, player, pointed_thing, mode, material, uses)
			return itemstack
		end,
		on_place = function(itemstack, player, pointed_thing)
			itemstack:set_name(mod_name .. ":wrench_" .. material .. "_" .. next_mode)
			return itemstack
		end,
	})
end

local function make_recipe(ingredient, dummy)
	if craft_recipe == "beak_north" then
		return {
			{ingredient,	dummy,		ingredient},
			{"",		ingredient,	""	},
			{"",		ingredient,	""	},
			}
	elseif craft_recipe == "beak_northwest" then
		return {
			{dummy,		ingredient,	""	},
			{ingredient,	ingredient,	""	},
			{"",		"",		ingredient},
			}
	elseif craft_recipe == "beak_west" then
		return {
			{ingredient,	"",		""	},
			{dummy,		ingredient,	ingredient},
			{ingredient,	"",		""	},
			}
	elseif craft_recipe == "beak_southwest" then
		return {
			{"",		"",		ingredient},
			{ingredient,	ingredient,	""	},
			{dummy,		ingredient,	""	},
			}
	elseif craft_recipe == "beak_south" then
		return {
			{"",		ingredient,	""	},
			{"",		ingredient,	""	},
			{ingredient,	dummy,		ingredient},
			}
	else
		error(string.format("[%s] unrecognised recipe selected: '%s'",mod_name_upper,craft_recipe))
	end

end

local function register_all_wrenches()
	local material, material_spec
	for material, material_spec in pairs(wrench_materials) do
		local mode, next_mode
		for mode,next_mode in pairs(wrench_modes) do
			register_wrench(material, material_spec.description, math.ceil(wrench_uses_steel * material_spec.use_factor), mode, next_mode)
		end

		minetest.register_craft({
			output = mod_name .. ":wrench_" .. material,
			recipe = make_recipe(material_spec.ingredient, "")
		})
		if alt_recipe == true then
			minetest.register_craft({
				output = mod_name .. ":wrench_" .. material,
				recipe = make_recipe(material_spec.ingredient, "group:wood")
			})
		end
	end
end

--
-- Setup / initialize wrench mod
--
compute_wrench_orientation_codes()
precompute_clockwise_rotations()
register_all_wrenches()

