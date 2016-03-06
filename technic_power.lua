-- rnd 2015, power outlet
-- used to power basic_machines using remaining available power from technic:switching_station. Just place it below mover but within 10 block distance of technich switching station. Each power outlet adds 500 to the power demand. If switching station has not enough unused power ( after technic machines demand), it wont supply power to mover.

local outlet_power_demand = 300;


minetest.register_node("basic_machines:outlet", {
	description = "Power outlet - generates power for machines",
	tiles = {"outlet.png"},
	groups = {oddly_breakable_by_hand=2,mesecon_effector_on = 1},
	sounds = default.node_sound_wood_defaults(),
	after_place_node = function(pos, placer)
		local meta = minetest.get_meta(pos);
		meta:set_string("infotext","outlet: energy production error. please have lava and water bucket in your inventory when placing it or place it near technic switching station with at least 300 free supply(within 10 blocks distance)"); 
	
		-- check player inventory for water and lava bucket xxx
		
		if not placer:is_player() then return end; local inv = placer:get_inventory();
		
		if inv:contains_item("main",ItemStack("bucket:bucket_water")) and inv:contains_item("main",ItemStack("bucket:bucket_lava")) then
			meta:set_int("supply",1); -- will generate power for machines
			inv:remove_item("main", ItemStack("bucket:bucket_water"))
			inv:remove_item("main", ItemStack("bucket:bucket_lava"))
			meta:set_string("infotext","outlet generating power using builtin geothermal generator");
			return;
		end
		
		
		local r = 10;
		local positions = minetest.find_nodes_in_area(
		{x=pos.x-r, y=pos.y-r, z=pos.z-r},
		{x=pos.x+r, y=pos.y+r, z=pos.z+r},
		"technic:switching_station")
		if not positions then 
			return 
		end
		
		local p = positions[1]; if not p then return end
		local smeta = minetest.get_meta(p);
		local bdemand = smeta:get_int("bdemand") or 0;
		bdemand = bdemand + outlet_power_demand; smeta:set_int("bdemand", bdemand);
		--minetest.chat_send_all("demand "..bdemand);
		meta:set_string("infotext","outlet connected to switching station at "..p.x .. " " .. p.y .. " " .. p.z);
		
		meta:set_string("station",minetest.pos_to_string(p)); -- remember where station is
	end,
	
	after_dig_node = function(pos, oldnode, oldmetadata, digger) -- remove demand from switching station
		local r = 10;
		local positions = minetest.find_nodes_in_area(
		{x=pos.x-r, y=pos.y-r, z=pos.z-r},
		{x=pos.x+r, y=pos.y+r, z=pos.z+r},
		"technic:switching_station")
		if not positions then return end
		
		local p = positions[1]; if not p then return end
		local smeta = minetest.get_meta(p);
		local bdemand = smeta:get_int("bdemand") or 0;
		bdemand = math.max(bdemand - outlet_power_demand,0); smeta:set_int("bdemand", bdemand);
		--minetest.chat_send_all("demand "..bdemand);
	end,
	
	mesecons = {effector = { 
		action_on = function (pos, node,ttl) 
			if type(ttl)~="number" then ttl = 1 end
			if ttl<0 then return end -- machines_TTL prevents infinite recursion
			-- provide power to furnace on top of it..
			
			local supply = basic_machines.check_power({x=pos.x,y=pos.y+1,z=pos.z});
			if supply<=0 then return end -- need power!
			
			pos.y=pos.y+1;	
			local node = minetest.get_node(pos).name;
			if node~= "default:furnace" and node~="default:furnace_active" then return end
			local meta = minetest.get_meta(pos);
			local fuel_totaltime = meta:get_float("fuel_totaltime") or 0;
			local fuel_time = meta:get_float("fuel_time") or 0;
			
			meta:set_float("fuel_totaltime",60);meta:set_float("fuel_time",0) -- add 60 second burn time to furnace
			local src_time = meta:get_float("src_time") or 0
			if fuel_time>4 then -- must burn for at least 4 secs before it can be accelerated again
				meta:set_float("src_time",src_time+5); -- twice as fast cooking
			end
			
		end
		}}
	
})

function basic_machines.check_power(pos) -- mover checks power source
	if minetest.get_node({x=pos.x,y=pos.y-1,z=pos.z}).name ~= "basic_machines:outlet"
		then return 0 
	end
	
	local meta = minetest.get_meta({x=pos.x,y=pos.y-1,z=pos.z});
	local supply = meta:get_int("supply"); -- check if outlet itself is generator
	if supply>0 then return supply end
	
	local p = minetest.string_to_pos(meta:get_string("station")); if not p then return end
	local smeta =  minetest.get_meta(p); if not smeta then return end
	local infot = smeta:get_string("infotext");
	--local infot = "Switching Station. Supply: 516 Demand: 0";	
	local i = string.find(infot,"Supply") or 1;
	local j = string.find(infot,"Demand") or 1;
	supply = tonumber(string.sub(infot,i+8,j-1)) or 0;
	local demand = tonumber(string.sub(infot, j+8)) or 0;
	supply= supply-demand-(smeta:get_int("bdemand") or 999999);
	if supply>0 then 
		return supply
		else return 0 
	end
end



minetest.register_craft({
	output = "basic_machines:outlet",
	recipe = {
		{"default:mese_crystal","default:steel_ingot","default:mese_crystal"},
		{"default:mese_crystal","default:diamondblock","default:mese_crystal"},
		{"default:mese_crystal","default:mese_crystal","default:mese_crystal"},
		
	}
})