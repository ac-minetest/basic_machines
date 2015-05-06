dofile(minetest.get_modpath("basic_machines").."/mark.lua") -- used for markings, borrowed and adapted from worldedit
dofile(minetest.get_modpath("basic_machines").."/mover.lua")

minetest.after(1, function() -- if you want keypad to open doors 
	dofile(minetest.get_modpath("basic_machines").."/mesecon_doors.lua")
end)
