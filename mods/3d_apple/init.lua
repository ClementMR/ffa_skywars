local box = {
		type = "fixed",
		fixed = {
				{-0.1875, -0.4375, -0.1875, 0.1875, 0.0625, 0.1875}, -- Bottom
				{-0.25, -0.375, -0.25, 0.25, 0, 0.25}, -- Middle
				-- {-0.1875, 0.0625, -0.1875, 0.1875, 0, 0.1875}, -- Top
				{-0.0625, 0.0625, -0.0625, 0, 0.125, 0}, -- NodeBox4
				{0.0625, 0.0625, 0.0625, 0, 0.125, 0}, -- NodeBox5
				{0.0625, 0.125, -0.0625, 0, 0.1875, 0}, -- NodeBox4
				{-0.0625, 0.125, 0.0625, 0, 0.1875, 0}, -- NodeBox5
		}
	}

minetest.override_item("default:apple",{
	drawtype = "nodebox",
	paramtype = "light",
	node_box = box,
	selection_box = box,
	tiles = { -- +Y, -Y, +X, -X, +Z, -Z
		"apple_bottom.png^apple_top_overlay.png",
		"apple_bottom.png",
		"apple_side.png",
		"apple_side.png",
		"apple_side.png",
		"apple_side.png",
	},
})
