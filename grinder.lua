-- rnd 2016:

-- this node works as technic grinder
-- There is a certain fuel cost to operate

-- recipe list: [in] ={fuel cost, out}
basic_machines.grinder_recipes = {
	["default:stone"] = {4,"default:sand"},
	["default:cobble"] = {4,"default:gravel"},
	["default:gravel"] = {1,"default:dirt"},
};


local grinder_process = function(pos) 
	
	local node = minetest.get_node({x=pos.x,y=pos.y-1,z=pos.z}).name;
	local meta = minetest.get_meta(pos);local inv = meta:get_inventory();
	
	-- FUEL CHECK
	local fuel = meta:get_float("fuel");
	
	if fuel<=0 then -- we need new fuel, check chest below
		local fuellist = inv:get_list("fuel") 
		if not fuellist then return end
		
		local fueladd, afterfuel = minetest.get_craft_result({method = "fuel", width = 1, items = fuellist}) 
		
		local supply=0;
		if fueladd.time == 0 then -- no fuel inserted, try look for outlet
				-- No valid fuel in fuel list
				supply = basic_machines.check_power({x=pos.x,y=pos.y,z=pos.z}) or 0;
				if supply>0 then 
					fueladd.time = 40 -- same as 10 coal
				else
					meta:set_string("infotext", "Please insert fuel.");
					return;
				end
		else
			if supply==0 then -- Take fuel from fuel list if no supply available
				inv:set_stack("fuel", 1, afterfuel.items[1])
			end
		end 
		if fueladd.time>0 then 
			fuel=fuel + fueladd.time*0.1
			meta:set_float("fuel",fuel);
			meta:set_string("infotext", "added fuel furnace burn time " .. fueladd.time .. ", fuel status " .. fuel);
		end
		if fuel<=0 then return end
	end

	
	
	-- PROCESS: check out inserted items
	local stack = inv:get_stack("src",1);
		if stack:is_empty() then return end; -- nothing to do

		local src_item = stack:to_string();
		local pos=string.find(src_item," "); if pos then src_item = string.sub(src_item,1,pos-1) end -- take first word to determine what item was 
		
		local def = basic_machines.grinder_recipes[src_item];
		if not def then 
			meta:set_string("infotext", "please insert valid materials"); return
		end-- unknown node
		
		fuel = fuel-def[1]; -- burn fuel
		if fuel<0 then meta:set_string("infotext", "need at least " .. def[1] .. " fuel to complete operation "); return end
		
		inv:add_item("dst",ItemStack(def[2]));
	
		--take 1 item from src inventory for each activation
		stack=stack:take_item(1); inv:remove_item("src", stack)
		
		meta:set_float("fuel",fuel); meta:set_string("infotext", "fuel status " .. fuel);
end


local grinder_update_meta = function(pos)
		local meta = minetest.get_meta(pos);
		local list_name = "nodemeta:"..pos.x..','..pos.y..','..pos.z 
		local form  = 
		"size[8,8]" ..  -- width, height
		--"size[6,10]" ..  -- width, height
		"label[0,0;IN] label[1,0;OUT] label[0,2;FUEL] "..
		"list["..list_name..";src;0.,0.5;1,1;]".. 
		"list["..list_name..";dst;1.,0.5;3,3;]"..
		"list["..list_name..";fuel;0.,2.5;1,1;]".. 
		"list[current_player;main;0,4;8,4;]"..
		"button[6.5,0.5;1,1;OK;OK]";
		meta:set_string("formspec", form);
end

minetest.register_node("basic_machines:grinder", {
	description = "Grinder",
	tiles = {"grinder.png"},
	groups = {oddly_breakable_by_hand=2,mesecon_effector_on = 1},
	sounds = default.node_sound_wood_defaults(),
	after_place_node = function(pos, placer)
		local meta = minetest.get_meta(pos);
		meta:set_string("infotext", "Grinder: To operate it insert fuel, then insert item to grind or use keypad to activate it.")
		meta:set_string("owner", placer:get_player_name());
		meta:set_float("fuel",0);
		local inv = meta:get_inventory();inv:set_size("src", 1);inv:set_size("dst",9);inv:set_size("fuel",1);
	end,
	
	on_rightclick = function(pos, node, player, itemstack, pointed_thing)
		local meta = minetest.get_meta(pos);
		local privs = minetest.get_player_privs(player:get_player_name());
		if meta:get_string("owner")~=player:get_player_name() and not privs.privs then return end -- only owner can interact with recycler
		grinder_update_meta(pos);
	end,
	
	allow_metadata_inventory_put = function(pos, listname, index, stack, player)
		local meta = minetest.get_meta(pos);
		local privs = minetest.get_player_privs(player:get_player_name());
		if meta:get_string("owner")~=player:get_player_name() and not privs.privs then return 0 end
		return stack:get_count();
	end,
	
	allow_metadata_inventory_take = function(pos, listname, index, stack, player)
		local meta = minetest.get_meta(pos);
		local privs = minetest.get_player_privs(player:get_player_name());
		if meta:get_string("owner")~=player:get_player_name() and not privs.privs then return 0 end
		return stack:get_count();
	end,
	
	on_metadata_inventory_put = function(pos, listname, index, stack, player) 
		if listname == "fuel" or listname =="dst" then return end -- just put fuel in, nothing else
		grinder_process(pos);
	end,
	
	allow_metadata_inventory_move = function(pos, from_list, from_index, to_list, to_index, count, player)
		return 0;
	end,
	
	mesecons = {effector = { 
		action_on = function (pos, node,ttl) 
		if type(ttl)~="number" then ttl = 1 end
		if ttl<0 then return end -- machines_TTL prevents infinite recursion
		grinder_process(pos);
	end
	}
	},
	
	on_receive_fields = function(pos, formname, fields, sender) 
		if fields.quit then return end
		local meta = minetest.get_meta(pos);
		grinder_update_meta(pos);
	end,

})


minetest.register_craft({
	output = "basic_machines:grinder",
	recipe = {
		{"default:diamond","default:mese","default:diamond"},
		{"default:mese","default:diamondblock","default:mese"},
		{"default:diamond","default:mese","default:diamond"},
		
	}
})




-- REGISTER DUSTS


local function register_dust(name,input_node_name,ingot,cooktime)
	
	minetest.register_craftitem("basic_machines:"..name.."_dust", {
		description = name.. " dust",
		inventory_image = "basic_machines_"..name.."_dust.png",
	})
	
	basic_machines.grinder_recipes[input_node_name] = {1,"basic_machines:"..name.."_dust 2"} -- register grinder recipe
	
	if ingot~="" then
		minetest.register_craft({
			type = "cooking",
			recipe = "basic_machines:"..name.."_dust",
			output = ingot,
			cooktime = cooktime
		})
	end
end


register_dust("iron","default:iron_lump","default:steel_ingot",10)
register_dust("copper","default:copper_lump","default:copper_ingot",10)
register_dust("gold","default:gold_lump","default:gold_ingot",10)
register_dust("diamond","default:diamond","default:diamond",3600) -- 1hr cooking time (rougly 100 coal) to make diamond!