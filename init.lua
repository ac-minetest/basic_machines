-- BASIC_MACHINES: lightweight automation mod for minetest
-- minetest 0.4.14
-- (c) 2015-2016 rnd

-- This program is free software: you can redistribute it and/or modify
-- it under the terms of the GNU General Public License as published by
-- the Free Software Foundation, either version 3 of the License, or
-- (at your option) any later version.

-- This program is distributed in the hope that it will be useful,
-- but WITHOUT ANY WARRANTY; without even the implied warranty of
-- MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
-- GNU General Public License for more details.

-- You should have received a copy of the GNU General Public License
-- along with this program.  If not, see <http://www.gnu.org/licenses/>.


basic_machines = {};


dofile(minetest.get_modpath("basic_machines").."/mark.lua") -- used for markings, borrowed and adapted from worldedit mod
dofile(minetest.get_modpath("basic_machines").."/mover.lua")
dofile(minetest.get_modpath("basic_machines").."/technic_power.lua") -- technic power for mover
dofile(minetest.get_modpath("basic_machines").."/recycler.lua")
dofile(minetest.get_modpath("basic_machines").."/grinder.lua")
--dofile(minetest.get_modpath("basic_machines").."/cpu.lua") -- experimental

dofile(minetest.get_modpath("basic_machines").."/autocrafter.lua") -- borrowed and adapted from pipeworks mod

minetest.after(0, function() -- if you want keypad to open/close doors
	dofile(minetest.get_modpath("basic_machines").."/mesecon_doors.lua")
end)



print("[basic machines] loaded")

-- machines fuel related recipes


-- CHARCOAL


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