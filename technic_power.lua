local machines_timer=5
local machines_minstep = 1

-- BATTERY

local battery_update_meta = function(pos)
		local meta = minetest.get_meta(pos);
		local list_name = "nodemeta:"..pos.x..','..pos.y..','..pos.z 
		local capacity = meta:get_float("capacity");
		local maxpower = meta:get_float("maxpower");
		local energy = math.ceil(10*meta:get_float("energy"))/10;
		local form  = 
		"size[8,6.5]" ..  -- width, height
		"label[0,0;FUEL] ".."label[6,0;UPGRADE] "..
		"label[1,0;ENERGY ".. energy .."/ ".. capacity..", maximum power output ".. maxpower .."]"..
		"label[1,1;UPGRADE LEVEL ".. meta:get_int("upgrade") .. " (mese and diamond block)]"..
		"list["..list_name..";fuel;0.,0.5;1,1;]".. "list["..list_name..";upgrade;6.,0.5;2,1;]" ..
		"list[current_player;main;0,2.5;8,4;]"..
		"button[4.5,0.35;1.5,1;OK;REFRESH]";
		meta:set_string("formspec", form);
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
		crystal = true;
		if energy+add_energy<=capacity then
			stack:take_item(1); 
			inv:set_stack("fuel", 1, stack)
		else 
			meta:set_string("infotext", "recharge problem: capacity " .. capacity .. ", needed " .. energy+add_energy)
		end
	else -- try do determine caloric value
		local fuellist = inv:get_list("fuel");if not fuellist then return energy end
		local fueladd, afterfuel = minetest.get_craft_result({method = "fuel", width = 1, items = fuellist}) 
		if fueladd.time > 0 then 
			add_energy = fueladd.time/40;
			if energy+add_energy<=capacity then
				inv:set_stack("fuel", 1, afterfuel.items[1]);
			end
		end
	end
		
	if add_energy>0 then
		if energy+add_energy<=capacity then
			energy=energy+add_energy
			meta:set_float("energy",energy);
			meta:set_string("infotext", "(R) energy: " .. math.ceil(energy*10)/10 .. " / ".. capacity);
			--TODO2: add entity power status display
			minetest.sound_play("electric_zap", {pos=pos,gain=0.03,max_hear_distance = 8,})
		end
	end
	
	return energy; -- new battery energy level
end

battery_upgrade = function(pos)
	local meta = minetest.get_meta(pos);
	local inv = meta:get_inventory();
	local count1,count2;count1=0;count2=0;
	local stack,item,count;
	for i=1,2 do
		stack = inv:get_stack("upgrade", i);item = stack:get_name();count= stack:get_count();
		if item == "default:mese" then 
			count1=count1+count 
		elseif item == "default:diamondblock" then 
			count2=count2+count 
		end
	end
	if count1<count2 then count =count1 else count=count2 end
	meta:set_int("upgrade",count);
	-- adjust capacity
	local capacity = 10+20*count;
	local maxpower = capacity*0.1;
	
	capacity = math.ceil(capacity*10)/10;
	local energy = 0;
	meta:set_float("capacity",capacity)
	meta:set_float("maxpower",maxpower)
	meta:set_float("energy",0)	
	meta:set_string("infotext", "energy: " .. math.ceil(energy*10)/10 .. " / ".. capacity);
end

local machines_activate_furnace = minetest.registered_nodes["default:furnace"].on_metadata_inventory_put; -- this function will activate furnace

minetest.register_node("basic_machines:battery", {
	description = "battery - stores energy, generates energy from fuel, can power nearby machines, or accelerate/run furnace above it. Its upgradeable.",
	tiles = {"basic_machine_outlet.png","basic_machine_side.png","basic_machine_battery.png"},
	groups = {oddly_breakable_by_hand=2,mesecon_effector_on = 1},
	sounds = default.node_sound_wood_defaults(),
	after_place_node = function(pos, placer)
		local meta = minetest.get_meta(pos);
		meta:set_string("infotext","battery - stores energy, generates energy from fuel, can power nearby machines, or accelerate/run furnace above it when activated by keypad"); 
		meta:set_string("owner",placer:get_player_name());
		local inv = meta:get_inventory();inv:set_size("fuel", 1*1); -- place to put crystals
		inv:set_size("upgrade", 2*1); 
		meta:set_int("upgrade",0); -- upgrade level determines energy storage capacity and max energy output
		meta:set_float("capacity",10);meta:set_float("maxpower",1);
		meta:set_float("energy",0);
	end,
	
	mesecons = {effector = { 
		action_on = function (pos, node,ttl) 
			if type(ttl)~="number" then ttl = 1 end
			if ttl<0 then return end -- machines_TTL prevents infinite recursion
			
			local meta = minetest.get_meta(pos);
			local energy = meta:get_float("energy");
			local capacity = meta:get_float("capacity");
			
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
					fmeta:set_float("src_time",src_time+machines_timer*upgrade); -- with max 99 upgrades battery furnace works 6x faster
					--end
					
					if fuel_time>40 or fuel_totaltime == 0 or node=="default:furnace" then -- must burn for at least 40 secs or furnace out of fuel
						
						fmeta:set_float("fuel_totaltime",60);fmeta:set_float("fuel_time",0) -- add 60 second burn time to furnace
						energy=energy-0.5; -- use up energy to add fuel
						
						-- make furnace start if not already started
						if node~="default:furnace_active" then machines_activate_furnace(pos) end
						-- update energy display
					end
					
					meta:set_float("energy",energy);
					meta:set_string("infotext", "energy: " .. math.ceil(energy*10)/10 .. " / ".. capacity);
					
					
					if energy>=1 then -- no need to recharge yet, will still work next time
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
			end
			
		end
		}},
		
		on_rightclick = function(pos, node, player, itemstack, pointed_thing)
			local meta = minetest.get_meta(pos);
			local privs = minetest.get_player_privs(player:get_player_name());
			if minetest.is_protected(pos,player:get_player_name()) and not privs.privs then return end -- only owner can interact with recycler
			battery_update_meta(pos);
		end,
		
		on_receive_fields = function(pos, formname, fields, sender) 
			if fields.quit then return end
			local meta = minetest.get_meta(pos);
			battery_update_meta(pos);
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
			if meta:get_int("upgrade")~=0 then return false else return true end
		end
	
})



-- GENERATOR

local generator_update_meta = function(pos)
		local meta = minetest.get_meta(pos);
		local list_name = "nodemeta:"..pos.x..','..pos.y..','..pos.z 
		
		local form  = 
		"size[8,6.5]" ..  -- width, height
		"label[0,0;POWER CRYSTALS] ".."label[6,0;UPGRADE] "..
		"label[1,1;UPGRADE LEVEL ".. meta:get_int("upgrade") .. " (gold and diamond block)]"..
		"list["..list_name..";fuel;0.,0.5;1,1;]".. "list["..list_name..";upgrade;6.,0.5;2,1;]" ..
		"list[current_player;main;0,2.5;8,4;]"..
		"button[4.5,0.35;1.5,1;OK;REFRESH]";
		meta:set_string("formspec", form);
end



generator_upgrade = function(pos)
	local meta = minetest.get_meta(pos);
	local inv = meta:get_inventory();
	local count1,count2;count1=0;count2=0;
	local stack,item,count;
	for i=1,2 do
		stack = inv:get_stack("upgrade", i);item = stack:get_name();count= stack:get_count();
		if item == "default:goldblock" then 
			count1=count1+count 
		elseif item == "default:diamondblock" then 
			count2=count2+count 
		end
	end
	if count1<count2 then count =count1 else count=count2 end
	meta:set_int("upgrade",count);
end

minetest.register_node("basic_machines:generator", {
	description = "Generator - very expensive, generates power crystals that provide power. Its upgradeable.",
	tiles = {"basic_machine_side.png","basic_machine_side.png","basic_machine_generator.png"},
	groups = {oddly_breakable_by_hand=2,mesecon_effector_on = 1},
	sounds = default.node_sound_wood_defaults(),
	after_place_node = function(pos, placer)
		local meta = minetest.get_meta(pos);
		meta:set_string("infotext","generator - generates power crystals that provide power. Upgrade with up to 99 gold/diamond blocks."); 
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
			if meta:get_int("upgrade")~=0 then return false else return true end
		end
	
})


minetest.register_abm({ 
	nodenames = {"basic_machines:generator"},
	neighbors = {""},
	interval = 20,
	chance = 1,
	action = function(pos, node, active_object_count, active_object_count_wider)
		local meta = minetest.get_meta(pos);
		local upgrade = meta:get_int("upgrade");
		local inv = meta:get_inventory();
		local stack = inv:get_stack("fuel", 1); 
		local crystal, text;
		
		if upgrade >= 99 then 
			crystal = "basic_machines:power_rod"
			text = "upgrade level 99: generating power rod";
			elseif upgrade >=20 then 
				crystal ="basic_machines:power_block"
				text = "upgrade level 20: generating power block";
			else 
				crystal ="basic_machines:power_cell"
				text = "upgrade level 0: generating power cell";
		end
		local morecrystal = ItemStack(crystal)
		stack:add_item(morecrystal);
		inv:set_stack("fuel", 1, stack)
		meta:set_string("infotext",text)
	end
})




-- API for power distribution
function basic_machines.check_power(pos, power_draw) -- mover checks power source - battery

	--minetest.chat_send_all(" battery: check_power " .. minetest.pos_to_string(pos) .. " " .. power_draw)
	
	if minetest.get_node(pos).name ~= "basic_machines:battery"
		then return 0 
	end
	
	local meta = minetest.get_meta(pos);
	local energy = meta:get_float("energy"); 
	local capacity = meta:get_float("capacity"); 
	local maxpower = meta:get_float("maxpower"); 
	
	if power_draw>maxpower then 
		meta:set_string("infotext", "Power draw required : " .. power_draw .. " maximum power output " .. maxpower .. ". Please upgrade battery") 
		return 0;
	end
	
	if power_draw>energy then
		energy = battery_recharge(pos); -- try recharge battery and continue operation immidiately
	end 
	
	energy = energy-power_draw;
	if energy<0 then 
		meta:set_string("infotext", "used fuel provides too little power for current power draw ".. power_draw);
		return 0 
	end -- recharge wasnt enough, needs to be repeated manually, return 0 power available
	meta:set_float("energy", energy);
	-- update energy display
	meta:set_string("infotext", "energy: " .. math.ceil(energy*10)/10 .. " / ".. capacity);
	return power_draw;
	
end

------------------------
-- CRAFTS
------------------------

minetest.register_craft({
	output = "basic_machines:battery",
	recipe = {
		{"","default:steel_ingot",""},
		{"default:steel_ingot","default:mese","default:steel_ingot"},
		{"","default:diamond",""},
		
	}
})

minetest.register_craft({
	output = "basic_machines:generator",
	recipe = {
		{"","",""},
		{"default:diamondblock","basic_machines:battery","default:diamondblock"},
		{"default:diamondblock","default:diamondblock","default:diamondblock"}
		
	}
})

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