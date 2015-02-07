
local wrench_debug = 0
-- Hack to compute pitch based on eye position instead of feet position
local eye_offset_hack = 1.7
-- Number of uses of a steel wench. The actual number may be slightly
-- lower, depending on how well this number divides 65535
local wrench_uses_steel = 450
local disable_wooden_wrench = true
local mod_name = "rotate"

-- Choose recipe.
-- Options:
-- 	"beak_north"		-- may conflict with another wrench (technic ?)
--	"beak_northwest"
--	"beak_west"
--	"beak_southwest"
--	"beak_south"
local craft_recipe = "beak_west"
-- Register a second, alternate recipe
local alt_recipe = false

-- How to incidate the orientation of the positioning wrenches.
-- "axis_rot": uses the 'axismode' and 'rotmode' images
-- "cube": use an exploded cube with different colors
-- "linear": use images 'wrench_mode_<mode>.png'. E.g.: wrench_mode_s53.png
--	(Note: such images do not exist yet...)
local wrench_orientation_indicator = "cube"

----------------------------------------
----- END OF CONFIGURATION SECTION -----
----------------------------------------
