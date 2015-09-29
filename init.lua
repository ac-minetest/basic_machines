dofile(minetest.get_modpath("basic_machines").."/mark.lua") -- used for markings, borrowed and adapted from worldedit mod
dofile(minetest.get_modpath("basic_machines").."/mover.lua")
dofile(minetest.get_modpath("basic_machines").."/recycler.lua")
dofile(minetest.get_modpath("basic_machines").."/autocrafter.lua") -- borrowed from pipeworks mod

-- IF USING UNTERNULL GAME COMMENT THE FOLLOWING
minetest.after(1, function() -- if you want keypad to open doors 
	dofile(minetest.get_modpath("basic_machines").."/mesecon_doors.lua")
end)
