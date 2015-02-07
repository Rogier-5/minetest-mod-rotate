
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

