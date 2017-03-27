-- rnd 2016:

-- CONSTRUCTOR machine: used to make all other basic_machines

basic_machines.craft_recipes = {
["keypad"] = {item = "basic_machines:keypad", description = "Turns on/off lights and activates machines or opens doors", craft = {"default:wood","default:stick"}},
["light"]={item = "basic_machines:light_on", description = "Light in darkness", craft = {"default:torch 4"}},
["mover"]={item = "basic_machines:mover", description = "Can dig, harvest, plant, teleport or move items from/in inventories", craft = {"default:mese_crystal 6","default:stone 2", "basic_machines:keypad"}},

["detector"] = {item = "basic_machines:detector", description = "Detect and measure players, objects,blocks,light level", craft = {"default:mese_crystal 4","basic_machines:keypad"}},

["distributor"]= {item = "basic_machines:distributor", description = "Organize your circuits better", craft = {"default:steel_ingot","default:mese_crystal", "basic_machines:keypad"}},

["clock_generator"]= {item = "basic_machines:clockgen", description = "For making circuits that run non stop", craft = {"default:diamondblock","basic_machines:keypad"}},

["recycler"]= {item = "basic_machines:recycler", description = "Recycle old tools", craft = {"default:mese_crystal 8","default:diamondblock"}},

["enviroment"] = {item = "basic_machines:enviro", description = "Change gravity and more", craft = {"basic_machines:generator 8","basic_machines:clockgen"}},

["ball_spawner"]={item = "basic_machines:ball_spawner", description = "Spawn moving energy balls", craft = {"basic_machines:power_cell","basic_machines:keypad"}},

["battery"]={item = "basic_machines:battery", description = "Power for machines", craft = {"default:steel_ingot 3","default:mese","default:diamond"}},

["generator"]={item = "basic_machines:generator", description = "Generate power crystals", craft = {"default:diamondblock 5","basic_machines:battery"}},

["autocrafter"] = {item = "basic_machines:autocrafter", description = "Automate crafting", craft = { "default:steel_ingot 5", "default:mese_crystal 2", "default:diamondblock 2"}},

["grinder"] = {item = "basic_machines:grinder", description = "Makes dusts and grinds materials", craft = {"default:diamond 13","default:mese 4"}},

["power_block"] = {item = "basic_machines:power_block 5", description = "Energy cell, contains 11 energy units", craft = {"basic_machines:power_rod"}},

["power_cell"] = {item = "basic_machines:power_cell 5", description = "Energy cell, contains 1 energy unit", craft = {"basic_machines:power_block"}},

["coal_lump"] = {item = "default:coal_lump", description = "Coal lump, contains 1 energy unit", craft = {"basic_machines:power_cell 2"}},

}

basic_machines.craft_recipe_order = { -- order in which nodes appear
	"keypad","light","grinder","mover", "battery","generator","detector", "distributor", "clock_generator","recycler","autocrafter","ball_spawner", "enviroment", "power_block", "power_cell", "coal_lump",
}

		

local constructor_process = function(pos) 
	
			local meta = minetest.get_meta(pos);
			local craft = basic_machines.craft_recipes[meta:get_string("craft")];
			if not craft then return end
			local item = craft.item;
			local craftlist = craft.craft;
			
			local inv = meta:get_inventory();
			for _,v in pairs(craftlist) do
				if not inv:contains_item("main", ItemStack(v)) then 
					meta:set_string("infotext", "#CRAFTING: you need " .. v .. " to craft " .. craft.item)
					return 
				end
			end
		
			for _,v in pairs(craftlist) do
				inv:remove_item("main", ItemStack(v));
			end
			inv:add_item("main", ItemStack(item));

end

local constructor_update_meta = function(pos)
		local meta = minetest.get_meta(pos);
		local list_name = "nodemeta:"..pos.x..','..pos.y..','..pos.z 
		local craft = meta:get_string("craft");
		
		local description = basic_machines.craft_recipes[craft];
		local item;
		
		if description then 
			item = description.item;
			local i = 0;
			
			local inv = meta:get_inventory(); -- set up craft list
			for _,v in pairs(description.craft) do
				i=i+1;
				inv:set_stack("recipe", i, ItemStack(v))	
			end
			
			for j = i+1,6 do
				inv:set_stack("recipe", j, ItemStack(""))
			end
			
			description = description.description 
			
		else 
			description = "" 
			item = ""
		end
		
		
		local textlist = " ";
		
		local selected = meta:get_int("selected") or 1;
		for _,v in ipairs(basic_machines.craft_recipe_order) do
			textlist = textlist .. v .. ", ";
			
		end
		
		local form  = 
			"size[8,10]"..
			"textlist[0,0;3,1.5;craft;" .. textlist .. ";" .. selected .."]"..
			"button[3.5,1;1.25,0.75;CRAFT;CRAFT]"..
			"item_image[3.65,0;1,1;".. item .. "]"..
			"label[0,1.85;".. description .. "]"..
			"list[context;recipe;5,0;3,2;]"..
			"label[0,2.3;Put crafting materials here]"..
			"list[context;main;0,2.7;8,3;]"..
			--"list[context;dst;5,0;3,2;]"..
			"label[0,5.5;player inventory]"..
			"list[current_player;main;0,6;8,4;]"..
			"listring[context;main]"..
			"listring[current_player;main]";
		meta:set_string("formspec", form);
end


minetest.register_node("basic_machines:constructor", {
	description = "Constructor: used to make machines",
	tiles = {"grinder.png","default_furnace_top.png", "basic_machine_side.png","basic_machine_side.png","basic_machine_side.png","basic_machine_side.png"},
	groups = {cracky=3, mesecon_effector_on = 1},
	sounds = default.node_sound_wood_defaults(),
	after_place_node = function(pos, placer)
		local meta = minetest.get_meta(pos);
		meta:set_string("infotext", "Constructor: To operate it insert materials, select item to make and click craft button.")
		meta:set_string("owner", placer:get_player_name());
		meta:set_string("craft","keypad")
		meta:set_int("selected",1);
		local inv = meta:get_inventory();inv:set_size("main", 24);--inv:set_size("dst",6);
		inv:set_size("recipe",8);
	end,
	
	on_rightclick = function(pos, node, player, itemstack, pointed_thing)
		local meta = minetest.get_meta(pos);
		local privs = minetest.get_player_privs(player:get_player_name());
		if minetest.is_protected(pos, player:get_player_name()) and not privs.privs then return end -- only owner can interact with recycler
		constructor_update_meta(pos);
	end,
	
	allow_metadata_inventory_put = function(pos, listname, index, stack, player)
		if listname == "recipe" then return 0 end
		local meta = minetest.get_meta(pos);
		local privs = minetest.get_player_privs(player:get_player_name());
		if meta:get_string("owner")~=player:get_player_name() and not privs.privs then return 0 end
		return stack:get_count();
	end,
	
	allow_metadata_inventory_take = function(pos, listname, index, stack, player)
		if listname == "recipe" then return 0 end
		local privs = minetest.get_player_privs(player:get_player_name());
		if minetest.is_protected(pos, player:get_player_name()) and not privs.privs then return 0 end 
		return stack:get_count();
	end,
	
	on_metadata_inventory_put = function(pos, listname, index, stack, player) 
		if listname == "recipe" then return 0 end
		local privs = minetest.get_player_privs(player:get_player_name());
		if minetest.is_protected(pos, player:get_player_name()) and not privs.privs then return 0 end 
		return stack:get_count();
	end,
	
	allow_metadata_inventory_move = function(pos, from_list, from_index, to_list, to_index, count, player)
		return 0;
	end,
	
	mesecons = {effector = { 
		action_on = function (pos, node,ttl) 
			if type(ttl)~="number" then ttl = 1 end
			if ttl<0 then return end -- machines_TTL prevents infinite recursion
			constructor_process(pos);
		end
		}
	},
	
	on_receive_fields = function(pos, formname, fields, sender) 
		
		if minetest.is_protected(pos, sender:get_player_name())  then return end 
		local meta = minetest.get_meta(pos);
		
		if fields.craft then
			if string.sub(fields.craft,1,3)=="CHG" then
				local sel = tonumber(string.sub(fields.craft,5)) or 1
				meta:set_int("selected",sel);
			
				local i = 0;
				for _,v in ipairs(basic_machines.craft_recipe_order) do
					i=i+1;
					if i == sel then meta:set_string("craft",v); break; end
				end
			else 
				return
			end
		end
		
		if fields.CRAFT then
			constructor_process(pos);
		end
		
		constructor_update_meta(pos);
	end,

})


minetest.register_craft({
	output = "basic_machines:constructor",
	recipe = {
		{"default:steel_ingot","default:steel_ingot","default:steel_ingot"},
		{"default:steel_ingot","default:copperblock","default:steel_ingot"},
		{"default:steel_ingot","default:steel_ingot","default:steel_ingot"},
		
	}
})