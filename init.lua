
local wrench_debug = 0
-- Hack to compute pitch based on eye position instead of feet position
local eye_offset_hack = 1.7
-- Number of uses of a steel wench. The actual number may be slightly
-- lower, depending on how well this number divides 65535
local wrench_uses_steel = 450
local disable_wooden_wrench = true
local mod_name = "rotate"
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
		up =	{north="east", east="south", south="west", west="north"},
		down =	{north="west", west="south", south="east", east="north"},
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

-- Mapping of minetest orientation to north-based orientation
-- (e.g. a block seen from the east looks identical to the same
--       block, seen from the north, after rotating it left)
local mt_orientation_to_facing = {
	north = "none",
	south = "reverse",
	east = "right",
	west = "left",
	up = {
		north = { "cw", "cw", "up" },
		south = "down",
		east = { "cw", "left" },
		west = { "ccw", "right" },
		},
	down = {
		north = { "cw", "cw", "down" },
		south = "up",
		east = { "ccw", "left" },
		west = { "cw", "right" },
		},
	}

-- Reverse mapping of mt_orientation_to_facing
local facing_orientation_to_mt = {
	north = "none",
	south = "reverse",
	east = "left",
	west = "right",
	up = {
		north = { "down", "cw", "cw" },
		south = "up",
		east = { "right", "ccw" },
		west = { "left", "cw" },
		},
	down = {
		north = { "up", "cw", "cw" },
		south = "down",
		east = { "right", "cw" },
		west = { "left", "ccw" },
		},
	}

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

local dpos_to_pointing_map = {
	["-1,0,0"] = "west",
	["0,-1,0"] = "down",
	["0,0,-1"] = "south",
	["1,0,0"] = "east",
	["0,1,0"] = "up",
	["0,0,1"] = "north",
	}

-- Given a pointed thing and a player, compute:
-- - the compass direction (NESW) the player is facing
-- - which side of the 'under' node the player is facing most
-- - which side of the 'under' node the player is pointing at
-- return:
-- { facing_direction = <direction (NESW)>, faced_side = <direction (NESWUD)>, pointed_side = <direction (NESWUD)> }
local function player_node_state(player, pointed_thing)
	local c
	local v
	local player_pos = player:getpos()
	local node_pos = pointed_thing.under

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

	-- Compute pointed side of the node
	local node_pos2 = pointed_thing.above
	local dpos = {x = node_pos2.x-node_pos.x, y = node_pos2.y-node_pos.y, z = node_pos2.z-node_pos.z}
	result.pointed_side = dpos_to_pointing_map[string.format("%d,%d,%d", dpos.x, dpos.y, dpos.z)]

	if not result.faced_side or not result.facing_direction or not result.pointed_side then
		minetest.log("error",string.format("[%s]: player_node_state: internal error: facing_direction = %s, faced_side=%s, pointed_side=%s",
			mod_name_upper,result.facing_direction, result.faced_side, result.pointed_side))
	end
	return result
end

-- Given the player's state (see player_node_state()) and desired rotation
-- direction, lookup the equivalent clockwise rotation side of the node.
-- i.e. the side of the node, that will rotate clockwise.
local function clockwise_rotation_side(state, rotation)
	local rot_side = state.pointed_side
	if rotation ~= "cw" then
		rot_side = rotation_specifications[rot_side][rotation]
		if type(rot_side) == "table" then
			rot_side = rot_side[state.facing_direction]
		end
	end
	return rot_side
end

local function mt_to_relative_orientation(state, orientation)
	local rotate = mt_orientation_to_facing[state.pointed_side]
	if type(rotate) == "table" then
		rotate = rotate[state.facing_direction]
	end
	if rotate == "none" then
		rotate = {}
	elseif rotate == "reverse" then
		rotate = {"left", "left"}
	elseif type(rotate) ~= "table" then
		rotate = {rotate}
	end
	local step
	for _,step in ipairs(rotate) do
		local clockwise_side
		clockwise_side = clockwise_rotation_side(state, step)
		orientation = mt_clockwise_rotation_map[clockwise_side][orientation]
	end
	return orientation
end

local function relative_to_mt_orientation(state, orientation)
	local rotate = facing_orientation_to_mt[state.pointed_side]
	if type(rotate) == "table" then
	    rotate = rotate[state.facing_direction]
	end
	if rotate == "none" then
		rotate = {}
	elseif rotate == "reverse" then
		rotate = {"left", "left"}
	elseif type(rotate) ~= "table" then
		rotate = {rotate}
	end
	local step
	for _,step in ipairs(rotate) do
		local clockwise_side
		clockwise_side = clockwise_rotation_side(state, step)
		orientation = mt_clockwise_rotation_map[clockwise_side][orientation]
	end
	return orientation
end

-- Perform the actual rotation lookup. Pretty straightforward...
local function lookup_node_rotation(pointed_thing, old_orientation, player, rotation)
	local state = player_node_state(player, pointed_thing)
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

local function get_node_absolute_orientation_mode(pointed_thing)
	if pointed_thing.type ~= "node" then
		return
	end

	local pos = pointed_thing.under

	local node = minetest.get_node(pos)
	local ndef = minetest.registered_nodes[node.name]
	if not ndef or ndef.paramtype2 ~= "facedir" or
			(ndef.drawtype == "nodebox" and
			ndef.node_box.type ~= "fixed") or
			node.param2 == nil then
		return "00"
	else
		local param2 = node.param2
		local axis = bit.band(bit.rshift(param2, 2), 0x7)
		local rot = bit.band(param2, 0x3)
		return string.format("a%d%d",axis,rot)
	end
end

local function get_node_relative_orientation_mode(player, pointed_thing)
	if pointed_thing.type ~= "node" then
		return
	end

	local pos = pointed_thing.under

	local node = minetest.get_node(pos)
	local ndef = minetest.registered_nodes[node.name]
	if not ndef or ndef.paramtype2 ~= "facedir" or
			(ndef.drawtype == "nodebox" and
			ndef.node_box.type ~= "fixed") or
			node.param2 == nil then
		return "00"
	else
		local param2 = node.param2
		local state = player_node_state(player, pointed_thing)
		local relative = mt_to_relative_orientation(state, param2)
		local axis = bit.band(bit.rshift(relative, 2), 0x7)
		local rot = bit.band(relative, 0x3)
		return string.format("r%d%d",axis,rot)
	end
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

	-- Set param2
	local old_param2 = node.param2
	if string.match(mode, "[0-9]") then
		local axis = tonumber(string.sub(mode, 2, 2))
		local rot = tonumber(string.sub(mode, 3, 3))
		local orientation = bit.bor(bit.lshift(axis, 2), rot)
		if string.sub(mode, 1, 1) == "a" then
		    node.param2 = orientation
		elseif string.sub(mode, 1, 1) == "r" then
		    local state = player_node_state(player, pointed_thing)
		    node.param2 = relative_to_mt_orientation(state, orientation)
		else
		    minetest.log("error", "Internal error: wrench has unrecognised mode ("..mode..")")
		    node.param2 = 0
		end
	else
		node.param2 = lookup_node_rotation(pointed_thing, old_param2, player, mode)
	end

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
local wrench_modes = {
	[""]="cw", cw="ccw", ccw="right", right="left", left="up", up="down", down="cw",
	-- For the following, there exists no 'next mode'
	["a00"]="a00", ["a01"]="a01", ["a02"]="a02", ["a03"]="a03",
	["a10"]="a10", ["a11"]="a11", ["a12"]="a12", ["a13"]="a13",
	["a20"]="a00", ["a21"]="a21", ["a22"]="a22", ["a23"]="a23",
	["a30"]="a30", ["a31"]="a31", ["a32"]="a32", ["a33"]="a33",
	["a40"]="a40", ["a41"]="a41", ["a42"]="a42", ["a43"]="a43",
	["a50"]="a50", ["a51"]="a51", ["a52"]="a52", ["a53"]="a53",
	["r00"]="r00", ["r01"]="r01", ["r02"]="r02", ["r03"]="r03",
	["r10"]="r10", ["r11"]="r11", ["r12"]="r12", ["r13"]="r13",
	["r20"]="r00", ["r21"]="r21", ["r22"]="r22", ["r23"]="r23",
	["r30"]="r30", ["r31"]="r31", ["r32"]="r32", ["r33"]="r33",
	["r40"]="r40", ["r41"]="r41", ["r42"]="r42", ["r43"]="r43",
	["r50"]="r50", ["r51"]="r51", ["r52"]="r52", ["r53"]="r53",
	}
local wrench_materials = {
	-- Wooden wrench is an extra - for players who have not mined metals yet
	-- Its low usage count is intentional: it is dirt-cheap, and they shouldn't
	-- be needed anyway.
	wood = {
		description = "Wooden",
		ingredient = "group:stick",
		use_factor = 10/wrench_uses_steel,
		disabled = disable_wooden_wrench,
		},
	steel = {
		description = "Steel",
		ingredient = "default:steel_ingot",
		use_factor = 1,
		},
	copper = {
		description = "Copper",
		ingredient = "default:copper_ingot",
		use_factor = 1.55,
		},
	gold = {
		description = "Gold",
		ingredient = "default:gold_ingot",
		use_factor = 2.1,
		},
	}

local function register_wrench_rotating(material, material_descr, uses, mode, next_mode)
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
		groups = { wrench = 1, ["wrench_"..material.."_rot"] = 1, not_in_creative_inventory = notcrea },
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

local function register_wrench_positioning(material, material_descr, uses, mode)
	local notcrea = 1
	if mode == "a00" or mode == "r00" then
		notcrea = 0
	end
	local wrench_image = "wrench_" .. material ..".png"
	local axis_image = "wrench_axismode_" .. string.sub(mode, 2, 2) .. "_" .. string.sub(mode, 1, 1) .. "pos.png"
	local rotation_image = "wrench_rotmode_" .. string.sub(mode, 3, 3) .. "_" .. string.sub(mode, 1, 1) .. "pos.png"

	minetest.register_tool(mod_name .. ":wrench_" .. material .. "_" .. mode, {
		description = material_descr .. " wrench (" .. mode .. "; left-click positions, right-click sets mode)",
		wield_image = "wrench_" .. material .. ".png",
		inventory_image = wrench_image .. "^" .. axis_image .. "^" .. rotation_image,
		groups = { wrench = 1, ["wrench_"..material.."_"..string.sub(mode,1,1).."pos"] = 1, not_in_creative_inventory = notcrea },
		on_use = function(itemstack, player, pointed_thing)
			wrench_handler(itemstack, player, pointed_thing, mode, material, uses)
			return itemstack
		end,
		on_place = function(itemstack, player, pointed_thing)
			local new_mode
			if string.sub(mode,1,1) == "r" then
			    new_mode = get_node_relative_orientation_mode(player, pointed_thing)
			else
			    new_mode = get_node_absolute_orientation_mode(pointed_thing)
			end
			itemstack:set_name(mod_name .. ":wrench_" .. material .. "_" .. new_mode)
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
		if not material_spec.disabled then
			local mode, next_mode
			for mode,next_mode in pairs(wrench_modes) do
				if string.match(mode, "[0-9]") then
					register_wrench_positioning(material, material_spec.description, math.ceil(wrench_uses_steel * material_spec.use_factor), mode)
				else
					register_wrench_rotating(material, material_spec.description, math.ceil(wrench_uses_steel * material_spec.use_factor), mode, next_mode)
				end
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
			-- Convert rotating wrench to positioning wrench (relative mode)
			minetest.register_craft({
				output = mod_name .. ":wrench_" .. material .. "_r00",
				recipe = {{"group:wrench_" .. material .. "_rot"}},
				})
			-- Convert positioning wrench (relative mode) to positioning wrench (absolute mode)
			minetest.register_craft({
				output = mod_name .. ":wrench_" .. material .. "_a00",
				recipe = {{"group:wrench_" .. material .. "_rpos"}},
				})
			-- Convert positioning wrench (absolute mode) to rotating wrench
			minetest.register_craft({
				output = mod_name .. ":wrench_" .. material,
				recipe = {{"group:wrench_" .. material .. "_apos"}},
				})
		end
	end

	-- When crafting a wrench from a wrench, keep its wear...
	minetest.register_on_craft(function(itemstack, player, old_craft_grid, craft_inv)
						if string.find(itemstack:get_name(), mod_name..":wrench_", 1, true) then
							local i, ingredient
							for i = 1, 9 do
								if old_craft_grid[i]:get_count() > 0 then
									if ingredient == nil then
										ingredient = old_craft_grid[i]
									else
										return
									end
								end
							end
							if string.find(ingredient:get_name(), mod_name..":wrench_", 1, true) then
								itemstack:set_wear(ingredient:get_wear())
							end
						end
					end)
end
--
-- Setup / initialize wrench mod
--
compute_wrench_orientation_codes()
precompute_clockwise_rotations()
register_all_wrenches()

