local machines_timer = basic_machines.machines_timer or 5
local machines_minstep = basic_machines.machines_minstep or 1

-- BATTERY

local battery_update_meta = function(pos)
	local meta = minetest.get_meta(pos)
	local list_name = "nodemeta:"..pos.x..','..pos.y..','..pos.z 
	local capacity = meta:get_float("capacity")
	local maxpower = meta:get_float("maxpower")
	local energy = math.ceil(10*meta:get_float("energy"))/10

	local form = 
		"size[8,6.5]"..	-- width, height
		"bgcolor[#333333;false]"..
		"label[0,0;FUEL] ".."label[6,0;UPGRADE] "..
		"box[1.45,0.48;2.15,1.01;#222222]"..
		"list["..list_name..";fuel;0.,0.5;1,1;]"..
		"list["..list_name..";upgrade;6.,0.5;2,2;]"..
		"list[current_player;main;0,2.5;8,4;]"..

		"image_button[4.3,0.5;1.6,0.5;wool_black.png;help;help]"..
		"image_button[4.3,1;1.6,0.5;wool_black.png;OK;refresh]"..

		"image[1.5,0.5;0.5,0.5;basic_machine_generator.png]"..
		"image[1.5,1;0.5,0.5;power_cell.png]"..

		"label[2,0.5;Power: " .. maxpower .. "]"..
		"label[2,1;Capacity: " .. capacity .. "]"..

		"button_exit[4.1,7.4;2,0.5;OK;close]"..
		"listring["..list_name..";fuel]"..
		"listring[current_player;main]"..
		"listring["..list_name..";upgrade]"..
		"listring[current_player;main]"
	
	-- local form  = 
		-- "size[8,6.5]"..	-- width, height
		-- "label[0,0;FUEL] ".."label[6,0;UPGRADE] "..
		-- "label[0.,1.5;UPGRADE: diamond/mese block for power/capacity]".. 
		-- "label[0.,1.75;UPGRADE: maxpower ".. maxpower .. " / CAPACITY " .. meta:get_int("capacity") .. "]"..
		-- "list["..list_name..";fuel;0.,0.5;1,1;]".. "list["..list_name..";upgrade;6.,0.5;2,2;]" ..
		-- "list[current_player;main;0,2.5;8,4;]"..
		-- "button[4.5,0.35;1.5,1;OK;REFRESH]"..
		-- "listring["..list_name..";upgrade]"..
		-- "listring[current_player;main]"..
		-- "listring["..list_name..";fuel]"..
		-- "listring[current_player;main]"
	meta:set_string("formspec", form)		
end

--[power crystal name] = energy provided
basic_machines.energy_crystals = {
	["basic_machines:power_cell"]=1,
	["basic_machines:power_block"]=11,
	["basic_machines:power_rod"]=100,
}


battery_recharge = function(pos)
	
	local meta = minetest.get_meta(pos);
	local energy = meta:get_float("energy");
	local capacity = meta:get_float("capacity");
	local inv = meta:get_inventory();
	local stack = inv:get_stack("fuel", 1); local item = stack:get_name();
	local crystal = false;
	
	local add_energy=0;
	add_energy = basic_machines.energy_crystals[item] or 0;
	
	if add_energy>0 then
		if pos.y>1500 then add_energy=2*add_energy end -- in space recharge is more efficient
		crystal = true;
		if add_energy<=capacity then
			stack:take_item(1); 
			inv:set_stack("fuel", 1, stack)
		else
			meta:set_string("infotext", "recharge problem: capacity " .. capacity .. ", needed " .. energy+add_energy)
			return energy
		end
	else -- try do determine caloric value of fuel inside battery
		local fuellist = inv:get_list("fuel");if not fuellist then return energy end
		local fueladd, afterfuel = minetest.get_craft_result({method = "fuel", width = 1, items = fuellist}) 
		if fueladd.time > 0 then 
			add_energy = fueladd.time/40;
			if energy+add_energy<=capacity then
				inv:set_stack("fuel", 1, afterfuel.items[1]);
			else 
				meta:set_string("infotext", "recharge problem: capacity " .. capacity .. ", needed " .. energy+add_energy)
				return energy
			end
		end
	end
		
	if add_energy>0 then
		energy=energy+add_energy
		if energy<0 then energy = 0 end
		if energy>capacity then energy = capacity end -- excess energy is wasted
		meta:set_float("energy",energy);
		meta:set_string("infotext", "(R) energy: " .. math.ceil(energy*10)/10 .. " / ".. capacity);
		minetest.sound_play("electric_zap", {pos=pos,gain=0.05,max_hear_distance = 8,})
	end
	
	local full_coef = math.floor(energy/capacity*3);
    if capacity == 0 then full_coef = 0 end
    if full_coef > 2 then full_coef = 2 end
	minetest.swap_node(pos,{name = "basic_machines:battery_".. full_coef}) -- graphic energy
	
	return energy; -- new battery energy level
end

battery_upgrade = function(pos)
	local meta = minetest.get_meta(pos);
	local inv = meta:get_inventory();
	local count1,count2;count1=0;count2=0;
	local stack,item,count;
	for i=1,4 do
		stack = inv:get_stack("upgrade", i);item = stack:get_name();count= stack:get_count();
		if item == "default:mese" then 
			count1=count1+count 
		elseif item == "default:diamondblock" then 
			count2=count2+count 
		end
	end
	--if count1<count2 then count =count1 else count=count2 end
	
	if pos.y>1500 then count1 = 2*count1; count2=2*count2 end -- space increases efficiency
	
	
	meta:set_int("upgrade",count2); -- diamond for power
	-- adjust capacity
	--yyy
	local capacity = 3+3*count1; -- mese for capacity
	local maxpower = 1+count2*2;  -- old 99 upgrade -> 200 power
	
	capacity = math.ceil(capacity*10)/10;
	local energy = 0;
	meta:set_float("capacity",capacity)
	meta:set_float("maxpower",maxpower)
	meta:set_float("energy",0)	
	meta:set_string("infotext", "energy: " .. math.ceil(energy*10)/10 .. " / ".. capacity);
end

local machines_activate_furnace = minetest.registered_nodes["default:furnace"].on_metadata_inventory_put; -- this function will activate furnace

minetest.register_node("basic_machines:battery_0", {
	description = "battery - stores energy, generates energy from fuel, can power nearby machines, or accelerate/run furnace above it. Its upgradeable.",
	tiles = {"basic_machine_outlet.png","basic_machine_battery.png","basic_machine_battery_0.png"},
	groups = {cracky=3},
	sounds = default.node_sound_wood_defaults(),
	
	after_place_node = function(pos, placer)
		local meta = minetest.get_meta(pos);
		meta:set_string("infotext","battery - stores energy, generates energy from fuel, can power nearby machines, or accelerate/run furnace above it when activated by keypad"); 
		meta:set_string("owner",placer:get_player_name());
		local inv = meta:get_inventory();inv:set_size("fuel", 1*1); -- place to put crystals
		inv:set_size("upgrade", 2*2); 
		meta:set_int("upgrade",0); -- upgrade level determines energy storage capacity and max energy output
		meta:set_float("capacity",3);meta:set_float("maxpower",1);
		meta:set_float("energy",0);
	end,
	
	effector = {
		action_on = function (pos, node,ttl) 
			if type(ttl)~="number" then ttl = 1 end
			if ttl<0 then return end -- machines_TTL prevents infinite recursion
			
			local meta = minetest.get_meta(pos);
			local energy = meta:get_float("energy");
			local capacity = meta:get_float("capacity");
			local full_coef = math.floor(energy/capacity*3); 
			
			-- try to power furnace on top of it
			if energy>=1 then -- need at least 1 energy
				pos.y=pos.y+1; local node = minetest.get_node(pos).name; 
				
				if node== "default:furnace" or node=="default:furnace_active" then 
					local fmeta = minetest.get_meta(pos);
					local fuel_totaltime = fmeta:get_float("fuel_totaltime") or 0;
					local fuel_time = fmeta:get_float("fuel_time") or 0;
					local t0 = meta:get_int("ftime"); -- furnace time
					local t1 = minetest.get_gametime();
					
					if t1-t0<machines_minstep then  -- to prevent too quick furnace acceleration, punishment is cooking reset
						fmeta:set_float("src_time",0); return 
					end
					meta:set_int("ftime",t1);
					
					local upgrade = meta:get_int("upgrade");upgrade=upgrade*0.1;
					
					--if fuel_time>4 then  --  accelerated cooking
					local src_time = fmeta:get_float("src_time") or 0
					energy = energy - 0.25*upgrade; -- use energy to accelerate burning
					
					
					if fuel_time>40 or fuel_totaltime == 0 or node=="default:furnace" then -- to add burn time: must burn for at least 40 secs or furnace out of fuel
						
						fmeta:set_float("fuel_totaltime",60);fmeta:set_float("fuel_time",0) -- add 60 second burn time to furnace
						energy=energy-0.5; -- use up energy to add fuel
						
						-- make furnace start if not already started
						if node~="default:furnace_active" and machines_activate_furnace then machines_activate_furnace(pos) end
						-- update energy display
					end
					
					
					if energy<0 then 
						energy = 0 
					else  -- only accelerate if we had enough energy, note: upgrade*0.1*0.25<power_rod is limit upgrade, so upgrade = 40*100 = 4000
						fmeta:set_float("src_time",src_time+machines_timer*upgrade); -- accelerated smelt: with 99 upgrade battery furnace works 11x faster 
					end
					
					meta:set_float("energy",energy);
					meta:set_string("infotext", "energy: " .. math.ceil(energy*10)/10 .. " / ".. capacity);
					
					
					if energy>=1 then -- no need to recharge yet, will still work next time
						local full_coef_new = math.floor(energy/capacity*3); if full_coef_new>2 then full_coef_new = 2 end
                        if capacity == 0 then full_coef_new = 0 end
						pos.y = pos.y-1;
						if full_coef_new ~= full_coef then minetest.swap_node(pos,{name = "basic_machines:battery_".. full_coef_new}) end
						return 
					else
						local infotext = meta:get_string("infotext");
						local new_infotext = "furnace needs at least 1 energy";
						if new_infotext~=infotext then -- dont update unnecesarilly
							meta:set_string("infotext", new_infotext);
							pos.y=pos.y-1; -- so that it points to battery again!
						end
					end 
				else
					pos.y=pos.y-1;
				end
							
			end

			-- try to recharge by converting inserted fuel/power cells into energy 
			
			if energy<capacity then -- not full, try to recharge
				battery_recharge(pos);
				return
			end
			
			local full_coef_new = math.floor(energy/capacity*3); if full_coef_new>2 then full_coef_new = 2 end
			if full_coef_new ~= full_coef then minetest.swap_node(pos,{name = "basic_machines:battery_".. full_coef_new}) end
			
		end
		},
		
		on_rightclick = function(pos, node, player, itemstack, pointed_thing)
			local meta = minetest.get_meta(pos);
			local privs = minetest.get_player_privs(player:get_player_name());
			if minetest.is_protected(pos,player:get_player_name()) and not privs.privs then return end -- only owner can interact with recycler
			battery_update_meta(pos);
		end,
		
		on_receive_fields = function(pos, formname, fields, sender) 
			if fields.quit then return end
			local meta = minetest.get_meta(pos);
			
			
			if fields.OK then battery_update_meta(pos) return end
			if fields.help then
				local name = sender:get_player_name();
				local text = "Battery provides power to machines or furnace. It can either "..
				"use power cells or convert ordinary furnace fuels into energy. 1 coal lump gives 1 energy.\n\n"..
				"UPGRADE with diamondblocks for more available power output or with "..
				"meseblocks for more power storage capacity"
				
				local form = "size [6,7] textarea[0,0;6.5,8.5;help;BATTERY HELP;".. text.."]"
				minetest.show_formspec(name, "basic_machines:help_battery", form)
			end
		end,
		
		allow_metadata_inventory_put = function(pos, listname, index, stack, player)
			local meta = minetest.get_meta(pos);
			local privs = minetest.get_player_privs(player:get_player_name());
			if minetest.is_protected(pos,player:get_player_name()) and not privs.privs then return 0 end
			return stack:get_count();
		end,
	
		allow_metadata_inventory_take = function(pos, listname, index, stack, player)
			local meta = minetest.get_meta(pos);
			local privs = minetest.get_player_privs(player:get_player_name());
			if minetest.is_protected(pos,player:get_player_name()) and not privs.privs then return 0 end
			return stack:get_count();
		end,
	
		on_metadata_inventory_put = function(pos, listname, index, stack, player) 
			if listname=="fuel" then
				battery_recharge(pos);
				battery_update_meta(pos);
			elseif listname == "upgrade" then
				battery_upgrade(pos);
				battery_update_meta(pos);
			end
			return stack:get_count();
		end,
		
		on_metadata_inventory_take = function(pos, listname, index, stack, player) 
			if listname == "upgrade" then
				battery_upgrade(pos);
				battery_update_meta(pos);
			end
			return stack:get_count();
		end,
	
		allow_metadata_inventory_move = function(pos, from_list, from_index, to_list, to_index, count, player)
			return 0;
		end,
		
		can_dig = function(pos)
			local meta = minetest.get_meta(pos);
			local inv = meta:get_inventory();
			
			if not (inv:is_empty("fuel")) or not (inv:is_empty("upgrade")) then return false end -- fuel AND upgrade inv must be empty to be dug
			
			return true
			
		end
	
})



-- GENERATOR

local generator_update_meta = function(pos)
		local meta = minetest.get_meta(pos);
		local list_name = "nodemeta:"..pos.x..','..pos.y..','..pos.z 
		
		local form  = 
			"size[8,6.5]" ..  -- width, height
			"label[0,0;POWER CRYSTALS] ".."label[6,0;UPGRADE] "..
			"label[1,1;UPGRADE LEVEL ".. meta:get_int("upgrade").." (generator)]"..
			"list["..list_name..";fuel;0.,0.5;1,1;]"..
			"list["..list_name..";upgrade;6.,0.5;2,1;]"..
			"list[current_player;main;0,2.5;8,4;]"..
			"button[4.5,1.5;1.5,1;OK;REFRESH]"..
			"button[6,1.5;1.5,1;help;help]"..
			"listring["..list_name..";fuel]"..
			"listring[current_player;main]"..
			"listring["..list_name..";upgrade]"..
			"listring[current_player;main]"	
		meta:set_string("formspec", form)
end



generator_upgrade = function(pos)
	local meta = minetest.get_meta(pos);
	local inv = meta:get_inventory();
	local stack,item,count;
	count = 0
	for i=1,2 do
		stack = inv:get_stack("upgrade", i);item = stack:get_name();
		if item == "basic_machines:generator" then 
			count= count + stack:get_count();
		end
	end
	meta:set_int("upgrade",count);
end

--local genstat = {}; -- generator statistics for each player
minetest.register_node("basic_machines:generator", {
	description = "Generator - very expensive, generates power crystals that provide power. Its upgradeable.",
	tiles = {"basic_machine_generator.png"},
	groups = {cracky=3},
	sounds = default.node_sound_wood_defaults(),
	after_place_node = function(pos, placer)

		--check to prevent too many generators being placed at one place
		if minetest.find_node_near(pos, 15, {"basic_machines:generator"}) then
			minetest.set_node(pos,{name="air"})
			minetest.add_item(pos,"basic_machines:generator")
			minetest.chat_send_player(placer:get_player_name(),"#generator: interference from nearby generator detected.")
			return
		end
		
		local meta = minetest.get_meta(pos);
		meta:set_string("infotext","generator - generates power crystals that provide power. Upgrade with up to 50 generators."); 
		meta:set_string("owner",placer:get_player_name());
		local inv = meta:get_inventory();
		inv:set_size("fuel", 1*1); -- here generated power crystals are placed
		inv:set_size("upgrade", 2*1); 
		meta:set_int("upgrade",0); -- upgrade level determines quality of produced crystals
		
	end,
	
	on_rightclick = function(pos, node, player, itemstack, pointed_thing)
		local meta = minetest.get_meta(pos);
		local privs = minetest.get_player_privs(player:get_player_name());
		if minetest.is_protected(pos,player:get_player_name()) and not privs.privs then return end -- only owner can interact with recycler
		generator_update_meta(pos);
	end,
	
	on_receive_fields = function(pos, formname, fields, sender) 
		if fields.quit then return end
		if fields.help then
			local text = "Generator slowly produces power crystals. Those can be used to recharge batteries and come in 3 flavors:\n\n low level (0-4), medium level (5-19) and high level (20+). Upgrading the generator (upgrade with generators) will increase the rate at which the crystals are produced.\n\nYou can automate the process of battery recharging by using mover in inventory mode, taking from inventory \"fuel\"";
			local form = "size [6,7] textarea[0,0;6.5,8.5;help;GENERATOR HELP;".. text.."]"
			minetest.show_formspec(sender:get_player_name(), "basic_machines:help_mover", form)
			return
		end
		local meta = minetest.get_meta(pos);
		generator_update_meta(pos);
	end,
	
	allow_metadata_inventory_put = function(pos, listname, index, stack, player)
		local meta = minetest.get_meta(pos);
		local privs = minetest.get_player_privs(player:get_player_name());
		if minetest.is_protected(pos,player:get_player_name()) and not privs.privs then return 0 end
		return stack:get_count();
	end,

	allow_metadata_inventory_take = function(pos, listname, index, stack, player)
		local meta = minetest.get_meta(pos);
		local privs = minetest.get_player_privs(player:get_player_name());
		if minetest.is_protected(pos,player:get_player_name()) and not privs.privs then return 0 end
		return stack:get_count();
	end,

	on_metadata_inventory_put = function(pos, listname, index, stack, player) 
		if listname == "upgrade" then
			generator_upgrade(pos);
			generator_update_meta(pos);
		end
		return stack:get_count();
	end,
	
	on_metadata_inventory_take = function(pos, listname, index, stack, player) 
		if listname == "upgrade" then
			generator_upgrade(pos);
			generator_update_meta(pos);
		end
		return stack:get_count();
	end,

	allow_metadata_inventory_move = function(pos, from_list, from_index, to_list, to_index, count, player)
		return 0;
	end,
	
	can_dig = function(pos)
		local meta = minetest.get_meta(pos);
		local inv = meta:get_inventory();
		
		if not inv:is_empty("upgrade") then return false end  -- fuel inv is not so important as generator generates it
		
		return true
	end,
})

minetest.register_abm({ 
	nodenames = {"basic_machines:generator"},
	neighbors = {},
	interval = 19,
	chance = 1,
	action = function(pos, node, active_object_count, active_object_count_wider)
		local meta = minetest.get_meta(pos);
		
		local upgrade = meta:get_int("upgrade");
		local inv = meta:get_inventory();
		local stack = inv:get_stack("fuel", 1); 
		local crystal, text;
		
		if upgrade > 50 then meta:set_string("infotext","error: max upgrade is 50"); return end
		
		if upgrade >= 20 then 
			crystal = "basic_machines:power_rod " .. math.floor(1+(upgrade-20)*9/178)
			text = "high upgrade: power rod";
			elseif upgrade >=5 then 
				crystal ="basic_machines:power_block " .. math.floor(1+(upgrade-5)*9/15);
				text = "medium upgrade: power block";
			else 
				crystal ="basic_machines:power_cell " .. math.floor(1+2*upgrade);
				text = "low upgrade: power cell";
		end
		local morecrystal = ItemStack(crystal)
		stack:add_item(morecrystal);
		inv:set_stack("fuel", 1, stack)
		meta:set_string("infotext",text)
	end
})




-- API for power distribution
function basic_machines.check_power(pos, power_draw) -- mover checks power source - battery

	local batname = "basic_machines:battery";
	if not string.find(minetest.get_node(pos).name,batname) then -- check with hashtables probably faster?
		return -1 -- battery not found!
	end
	
	local meta = minetest.get_meta(pos);
	local energy = meta:get_float("energy"); 
	local capacity = meta:get_float("capacity"); 
	local maxpower = meta:get_float("maxpower"); 
	local full_coef = math.floor(energy/capacity*3); -- 0,1,2
	
	if power_draw>maxpower then 
		meta:set_string("infotext", "Power draw required : " .. power_draw .. " maximum power output " .. maxpower .. ". Please upgrade battery") 
		return 0;
	end
	
	if power_draw>energy then
		energy = battery_recharge(pos); -- try recharge battery and continue operation immidiately
		if not energy then return 0 end
	end 
	
	energy = energy-power_draw;
	if energy<0 then 
		meta:set_string("infotext", "used fuel provides too little power for current power draw ".. power_draw);
		return 0 
	end -- recharge wasnt enough, needs to be repeated manually, return 0 power available
	meta:set_float("energy", energy);
	-- update energy display
	meta:set_string("infotext", "energy: " .. math.ceil(energy*10)/10 .. " / ".. capacity);
	
	local full_coef_new = math.floor(energy/capacity*3); if full_coef_new>2 then full_coef_new = 2 end
	if full_coef_new ~= full_coef then minetest.swap_node(pos,{name = "basic_machines:battery_".. full_coef_new}) end -- graphic energy level display
	
	return power_draw;
	
end

------------------------
-- CRAFTS
------------------------

-- minetest.register_craft({
	-- output = "basic_machines:battery",
	-- recipe = {
		-- {"","default:steel_ingot",""},
		-- {"default:steel_ingot","default:mese","default:steel_ingot"},
		-- {"","default:diamond",""},
		
	-- }
-- })

-- minetest.register_craft({
	-- output = "basic_machines:generator",
	-- recipe = {
		-- {"","",""},
		-- {"default:diamondblock","basic_machines:battery","default:diamondblock"},
		-- {"default:diamondblock","default:diamondblock","default:diamondblock"}
		
	-- }
-- })

minetest.register_craftitem("basic_machines:power_cell", {
	description = "Power cell - provides 1 power",
	inventory_image = "power_cell.png",
	stack_max = 25
})

minetest.register_craftitem("basic_machines:power_block", {
	description = "Power block - provides 11 power",
	inventory_image = "power_block.png",
	stack_max = 25
})

minetest.register_craftitem("basic_machines:power_rod", {
	description = "Power rod - provides 100 power",
	inventory_image = "power_rod.png",
	stack_max = 25
})

-- various battery levels: 0,1,2 (2 >= 66%, 1 >= 33%,0>=0%)
local batdef = {};
for k,v in pairs(minetest.registered_nodes["basic_machines:battery_0"]) do batdef[k] = v end

for i = 1,2 do
	batdef.tiles[3] = "basic_machine_battery_" .. i ..".png"
	minetest.register_node("basic_machines:battery_"..i, batdef)
end
