-- rnd 2015:

-- this node works as a reverse of crafting process with a 25% loss of items (aka recycling). You can select which recipe to use when recycling.
-- There is a fuel cost to recycle

-- prevent unrealistic recyclings
local no_recycle_list  = {
	["default:steel_ingot"]=1,["default:copper_ingot"]=1,["default:bronze_ingot"]=1,["default:gold_ingot"]=1,
	["dye:white"]=1,["dye:grey"]=1,["dye:dark_grey"]=1,["dye:black"]=1,
	["dye:violet"]=1,["dye:blue"]=1,["dye:cyan"]=1,["dye:dark_green"]=1,
	["dye:green"]=1,["dye:yellow"]=1,["dye:brown"]=1,["dye:orange"]=1,
	["dye:red"]=1,["dye:magenta"]=1,["dye:pink"]=1,
}


local recycler_process = function(pos) 
	
	local node = minetest.get_node({x=pos.x,y=pos.y-1,z=pos.z}).name;
	local meta = minetest.get_meta(pos);local inv = meta:get_inventory();
	
	-- FUEL CHECK
	local fuel = meta:get_float("fuel");
	
	if fuel-1<0 then -- we need new fuel, check chest below
		local fuellist = inv:get_list("fuel") 
		if not fuellist then return end
		
		local fueladd, afterfuel = minetest.get_craft_result({method = "fuel", width = 1, items = fuellist}) 
		
		local supply=0;
		if fueladd.time == 0 then -- no fuel inserted, try look for outlet
				-- No valid fuel in fuel list
				supply = basic_machines.check_power({x=pos.x,y=pos.y-1,z=pos.z},1) or 0;
				if supply>0 then 
					fueladd.time = 40*supply -- same as 10 coal
				else
					meta:set_string("infotext", "Please insert fuel.");
					return;
				end
		else
			if supply==0 then -- Take fuel from fuel list if no supply available
				inv:set_stack("fuel", 1, afterfuel.items[1])
				fueladd.time = fueladd.time*0.1; -- thats 4 for coal
			end
		end 
		if fueladd.time>0 then 
			fuel=fuel + fueladd.time
			meta:set_float("fuel",fuel);
			meta:set_string("infotext", "added fuel furnace burn time " .. fueladd.time .. ", fuel status " .. fuel);
		end
		if fuel-1<0 then return end
	end

	
	
	-- RECYCLING: check out inserted items
	local stack = inv:get_stack("src",1);
		if stack:is_empty() then return end; -- nothing to do

		local src_item = stack:to_string();
		local p=string.find(src_item," "); if p then src_item = string.sub(src_item,1,p-1) end -- take first word to determine what item was 
		
		-- look if we already handled this item
		local known_recipe=true;
		if src_item~=meta:get_string("node") then-- did we already handle this? if yes read from cache
			meta:set_string("node",src_item);
			meta:set_string("itemlist","{}");
			meta:set_int("reqcount",0);
			known_recipe=false;
		end
		
		local itemlist, reqcount;
		reqcount = 1; -- needed count of materials for recycle to work
		
		if not known_recipe then
		
			if no_recycle_list[src_item] then meta:set_string("node","") return end -- dont allow recycling of forbidden items
			
			local recipe = minetest.get_all_craft_recipes( src_item );
			local recipe_id = tonumber(meta:get_int("recipe")) or 1;
			
			if not recipe then 
				return
			else 
				itemlist = recipe[recipe_id];
				if not itemlist then meta:set_string("node","") return end;
				itemlist=itemlist.items;
			end
			local output = recipe[recipe_id].output or "";
			if string.find(output," ") then 
				local par = string.find(output," ");
				--if (tonumber(string.sub(output, par)) or 0)>1 then itemlist = {} end
				
				if par then
					reqcount = tonumber(string.sub(output, par)) or 1;
				end
			
			end 
			
			meta:set_string("itemlist",minetest.serialize(itemlist)); -- read cached itemlist
			meta:set_int("reqcount",reqcount);
		else 
			itemlist=minetest.deserialize(meta:get_string("itemlist")) or {};
			reqcount = meta:get_int("reqcount") or 1;
		end
		
		if stack:get_count()<reqcount then
			meta:set_string("infotext", "at least " .. reqcount .. " of " .. src_item .. " is needed ");
			return
		end
		
		--empty dst inventory before proceeding
		-- local size = inv:get_size("dst"); 
		-- for i=1,size do
			-- inv:set_stack("dst", i, ItemStack(""));
		-- end
		
		--take 1 item from src inventory for each activation
		stack=stack:take_item(reqcount); inv:remove_item("src", stack)
		
		for _,  v in pairs(itemlist) do
			if math.random(1, 4)<=3 then -- probability 3/4 = 75%
				if not string.find(v,"group") then -- dont add if item described with group
					local par = string.find(v,"\"") or 0;
					if inv:room_for_item("dst", ItemStack(v)) then -- can item be put in
						inv:add_item("dst",ItemStack(v));
					else return
					end
				end
			end
		end
	
		
		
		minetest.sound_play("recycler", {pos=pos,gain=0.5,max_hear_distance = 16,})
		
		
		fuel = fuel-1; -- burn fuel on succesful operation
		meta:set_float("fuel",fuel); meta:set_string("infotext", "fuel status " .. fuel .. ", recycling " .. meta:get_string("node"));
end


local recycler_update_meta = function(pos)
	local meta = minetest.get_meta(pos)
	local list_name = "nodemeta:"..pos.x..','..pos.y..','..pos.z 
	local form  = 
		"size[8,8]"..  -- width, heightinv:get_stack
		--"size[6,10]"..  -- width, height
		"label[0,0;IN] label[1,0;OUT] label[0,2;FUEL] "..
		"list["..list_name..";src;0.,0.5;1,1;]"..
		"list["..list_name..";dst;1.,0.5;3,3;]"..
		"list["..list_name..";fuel;0.,2.5;1,1;]"..
		"list[current_player;main;0,4;8,4;]"..
		"field[4.5,0.75;2,1;recipe;select recipe: ;"..(meta:get_int("recipe")).."]"..
		"button[6.5,0.5;1,1;OK;OK]"..
		"listring["..list_name..";dst]"..
		"listring[current_player;main]"..
		"listring["..list_name..";src]"..
		"listring[current_player;main]"..
		"listring["..list_name..";fuel]"..
		"listring[current_player;main]"	
		--"field[0.25,4.5;2,1;mode;mode;"..mode.."]"
	meta:set_string("formspec", form)
end

minetest.register_node("basic_machines:recycler", {
	description = "Recycler - use to get some ingredients back from crafted things",
	tiles = {"recycler.png"},
	groups = {cracky=3, mesecon_effector_on = 1},
	sounds = default.node_sound_wood_defaults(),
	after_place_node = function(pos, placer)
		local meta = minetest.get_meta(pos);
		meta:set_string("infotext", "Recycler: put one item in it (src) and obtain 75% of raw materials (dst). To operate it insert fuel, then insert item to recycle or use keypad to activate it.")
		meta:set_string("owner", placer:get_player_name());
		meta:set_int("recipe",1);
		meta:set_float("fuel",0);
		local inv = meta:get_inventory();inv:set_size("src", 1);inv:set_size("dst",9);inv:set_size("fuel",1);
	end,
	
	on_rightclick = function(pos, node, player, itemstack, pointed_thing)
		local meta = minetest.get_meta(pos);
		local privs = minetest.get_player_privs(player:get_player_name());
		if minetest.is_protected(pos, player:get_player_name()) and not privs.privs then return end -- only owner can interact with recycler
		recycler_update_meta(pos);
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
		if listname =="dst" then return end
		recycler_process(pos);
	end,
	
	allow_metadata_inventory_move = function(pos, from_list, from_index, to_list, to_index, count, player)
		return 0;
	end,
	
	mesecons = {effector = { 
		action_on = function (pos, node,ttl) 
		if type(ttl)~="number" then ttl = 1 end
		if ttl<0 then return end -- machines_TTL prevents infinite recursion
		recycler_process(pos);
	end
	}
	},
	
	on_receive_fields = function(pos, formname, fields, sender) 
		if minetest.is_protected(pos, sender:get_player_name()) then return end
		if fields.quit then return end
		local meta = minetest.get_meta(pos);
		local recipe=1;
		if fields.recipe then
			recipe = tonumber(fields.recipe) or 1;
			else return;
		end
		meta:set_int("recipe",recipe);
		meta:set_string("node",""); -- this will force to reread recipe on next use
		recycler_update_meta(pos);
	end,
	
	can_dig = function(pos)
	
			local meta = minetest.get_meta(pos);
			local inv = meta:get_inventory();
			
			if not (inv:is_empty("fuel")) or not (inv:is_empty("src")) or not (inv:is_empty("dst")) then return false end -- all inv must be empty to be dug
		  			
			return true
			
		end

})


-- minetest.register_craft({
	-- output = "basic_machines:recycler",
	-- recipe = {
		-- {"default:mese_crystal","default:mese_crystal","default:mese_crystal"},
		-- {"default:mese_crystal","default:diamondblock","default:mese_crystal"},
		-- {"default:mese_crystal","default:mese_crystal","default:mese_crystal"},
		
	-- }
-- })