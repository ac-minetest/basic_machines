basic_machines = {};

dofile(minetest.get_modpath("basic_machines").."/mark.lua") -- used for markings, borrowed and adapted from worldedit mod
dofile(minetest.get_modpath("basic_machines").."/technic_power.lua") -- technic power for mover
dofile(minetest.get_modpath("basic_machines").."/mover.lua")
dofile(minetest.get_modpath("basic_machines").."/recycler.lua")
dofile(minetest.get_modpath("basic_machines").."/grinder.lua")
--dofile(minetest.get_modpath("basic_machines").."/cpu.lua") -- experimental

dofile(minetest.get_modpath("basic_machines").."/autocrafter.lua") -- borrowed and adapted from pipeworks mod

minetest.after(0, function() -- if you want keypad to open/close doors
	dofile(minetest.get_modpath("basic_machines").."/mesecon_doors.lua")
end)



print("[basic machines] loaded")

-- machines fuel related recipes

minetest.register_craftitem("basic_machines:charcoal", {
	description = "Wood charcoal",
	inventory_image = "default_coal_lump.png",
})

minetest.register_craft({
	type = 'cooking',
	recipe = "default:tree",
	cooktime = 30,
	output = "basic_machines:charcoal",
})

minetest.register_craft({
	output = "default:coal_lump",
	recipe = {
		{"basic_machines:charcoal"},
		{"basic_machines:charcoal"},
	}
})

minetest.register_craft({
	type = "fuel",
	recipe = "basic_machines:charcoal",
	-- note: to make it you need to use 1 tree block for fuel + 1 tree block, thats 2, caloric value 2*30=60
	burntime = 40, -- coal lump has 40, tree block 30, coal block 370 (9*40=360!)
})