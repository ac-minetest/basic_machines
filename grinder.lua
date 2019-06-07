-- There is a certain fuel cost to operate

-- recipe list: [in] ={fuel cost, out, quantity of material required for processing}
basic_machines.grinder_recipes = {
	["default:stone"] = {2,"default:sand",1},
	["default:desert_stone"] = {2,"default:desert_sand 4",1},
	["default:cobble"] = {1,"default:gravel",1},
	["default:gravel"] = {0.5,"default:dirt",1},
	["default:dirt"] = {0.5,"default:clay_lump 4",1},
	["default:obsidian_shard"] = {199,"default:lava_source",1},
	["gloopblocks:basalt"] = {1, "default:cobble",1}, -- enable coble farms with gloopblocks mod
	["default:ice"] = {1, "default:snow 4",1},
	["darkage:silt_lump"]={1,"darkage:chalk_powder",1},
};


local grinder_process = function(pos) 
	
	local node = minetest.get_node({x=pos.x,y=pos.y-1,z=pos.z}).name;
	local meta = minetest.get_meta(pos);local inv = meta:get_inventory();
	
	-- activation limiter: 1/s
	local t0 = meta:get_int("t")
	local t1 = minetest.get_gametime();
	
	if t1-t0>0 then
		meta:set_int("t",t1)
	else 
		return
	end
	
	-- PROCESS: check out inserted items
	local stack = inv:get_stack("src",1);
	if stack:is_empty() then return end; -- nothing to do

	local src_item = stack:to_string();
	local p=string.find(src_item," "); if p then src_item = string.sub(src_item,1,p-1) else p = 0 end -- take first word to determine what item was 
	
	local def = basic_machines.grinder_recipes[src_item];
	if not def then 
		meta:set_string("infotext", "please insert valid materials"); return
	end-- unknown node
	
	local steps = math.floor(stack:get_count() / def[3]) -- how many steps to process inserted stack
	
	if steps<1 then
		meta:set_string("infotext", "Recipe requires at least " .. def[3] .. " " .. src_item);
		return
	end

	local upgrade = meta:get_int("upgrade")+1
	if steps>upgrade then steps = upgrade end
	
	-- FUEL CHECK
	local fuel = meta:get_float("fuel");
	local fuel_req = def[1]*steps; 
	
	if fuel-fuel_req <0 then -- we need new fuel, check chest below
		local fuellist = inv:get_list("fuel") 
		if not fuellist then return end
		
		local fueladd, afterfuel = minetest.get_craft_result({method = "fuel", width = 1, items = fuellist}) 
		
		local supply=0;
		if fueladd.time == 0 then -- no fuel inserted, try look for outlet
				-- No valid fuel in fuel list
				supply = basic_machines.check_power({x=pos.x,y=pos.y-1,z=pos.z} , fuel_req) or 0; -- tweaked so 1 coal = 1 energy
				if supply>0 then 
					fueladd.time = supply -- same as 10 coal
				else
					meta:set_string("infotext", "Please insert fuel");
					return;
				end
		else
			if supply==0 then -- Take fuel from fuel list if no supply available
				inv:set_stack("fuel",1,afterfuel.items[1])
				fueladd.time=fueladd.time*0.1/4 -- thats 1 for coal
			end
		end 
		if fueladd.time>0 then 
			fuel=fuel + fueladd.time
			meta:set_float("fuel",fuel);
			meta:set_string("infotext", "added fuel furnace burn time " .. fueladd.time .. ", fuel status " .. fuel);
		end
		if fuel-fuel_req<0 then 
			meta:set_string("infotext", "need at least " .. fuel_req-fuel .. " fuel to complete operation ");  return 
		end
		
	end

	-- process items
		local addstack = ItemStack(def[2]);
		if steps>1 then  -- multiply stack
			local count = addstack:get_count();
			addstack:set_count(count*steps)
		end
		if inv:room_for_item("dst", addstack) then
			inv:add_item("dst",addstack);
		else return
		end
	
		--take 'steps' items from src inventory for each activation
		stack=stack:take_item(steps); inv:remove_item("src", stack)
		
		minetest.sound_play("grinder", {pos=pos,gain=0.5,max_hear_distance = 16,})
		
		fuel = fuel-fuel_req; -- burn fuel
		meta:set_float("fuel",fuel);
		meta:set_string("infotext", "fuel " .. fuel);
		 
end


local grinder_update_meta = function(pos)
	local meta = minetest.get_meta(pos);
	local list_name = "nodemeta:"..pos.x..','..pos.y..','..pos.z 
	local form  = 
		"size[8,8]"..		-- width, height
		--"size[6,10]"..	-- width, height
		"label[0,0;IN] label[1,0;OUT] label[0,2;FUEL] label[5,0;UPGRADE]"..
		"list["..list_name..";src;0.,0.5;1,1;]".. 
		"list["..list_name..";dst;1.,0.5;3,3;]"..
		"list["..list_name..";fuel;0.,2.5;1,1;]".. 
		"list["..list_name..";upgrade;5.,0.5;2,1;]"..
		"list[current_player;main;0,4;8,4;]"..
		"button[7,0.5;1,1;OK;OK]"..
		"button[7,1.5;1,1;help;help]"..
		"listring["..list_name..";dst]"..
		"listring[current_player;main]"..
		"listring["..list_name..";src]"..
		"listring[current_player;main]"..
		"listring["..list_name..";fuel]"..
		"listring[current_player;main]"
	meta:set_string("formspec", form)
end

local upgrade_grinder = function(meta)
	local inv = meta:get_inventory();
	local stack = inv:get_stack("upgrade", 1); local item = stack:get_name(); local count = stack:get_count();
	if item ~= "basic_machines:grinder" then count = 0 end;	meta:set_int("upgrade", count)
end

minetest.register_node("basic_machines:grinder", {
	description = "Grinder",
	tiles = {"grinder.png"},
	groups = {cracky=3, mesecon_effector_on = 1},
	sounds = default.node_sound_wood_defaults(),
	after_place_node = function(pos, placer)
		local meta = minetest.get_meta(pos);
		meta:set_string("infotext", "Grinder: To operate it insert fuel, then insert item to grind or use keypad to activate it.")
		meta:set_string("owner", placer:get_player_name());
		meta:set_float("fuel",0);
		local inv = meta:get_inventory();inv:set_size("src", 1);inv:set_size("dst",9);inv:set_size("fuel",1);
		inv:set_size("upgrade",1);
	end,
	
	on_rightclick = function(pos, node, player, itemstack, pointed_thing)
		local meta = minetest.get_meta(pos);
		local privs = minetest.get_player_privs(player:get_player_name());
		if minetest.is_protected(pos, player:get_player_name()) and not privs.privs then return end -- only owner can interact with recycler
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
	
	on_metadata_inventory_take = function(pos, listname, index, stack, player) 
		if listname == "upgrade" then upgrade_grinder(minetest.get_meta(pos))	end
	end,
	
	on_metadata_inventory_put = function(pos, listname, index, stack, player) 
		if listname =="dst" then return end
		if listname == "upgrade" then upgrade_grinder(minetest.get_meta(pos))	end
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
		
		if fields.help then
			--recipe list: [in] ={fuel cost, out, quantity of material required for processing}
			--basic_machines.grinder_recipes 
			local text = "HELP & RECIPES\n\nTo upgrade grinder put grinders in upgrade slot. Each upgrade adds ability to process additional materials.\n\n";
			for key,v in pairs(basic_machines.grinder_recipes) do
				text = text .. "INPUT ".. key .. " " .. v[3] .. " OUTPUT " ..  v[2] .. "\n"
			end
			
			local form = "size [6,7] textarea[0,0;6.5,8.5;grinderhelp;GRINDER RECIPES;".. text.."]"
			minetest.show_formspec(sender:get_player_name(), "grinderhelp", form)
		
		end
		grinder_update_meta(pos);
	end,
	
	can_dig = function(pos)
			local meta = minetest.get_meta(pos);
			local inv = meta:get_inventory();
			
			if not (inv:is_empty("fuel")) or not (inv:is_empty("src")) or not (inv:is_empty("dst")) then return false end -- all inv must be empty to be dug
			
			return true
			
		end

})


-- minetest.register_craft({
	-- output = "basic_machines:grinder",
	-- recipe = {
		-- {"default:diamond","default:mese","default:diamond"},
		-- {"default:mese","default:diamondblock","default:mese"},
		-- {"default:diamond","default:mese","default:diamond"},
		
	-- }
-- })




-- REGISTER DUSTS
-- dust_00 (mix)-> extractor (smelt) -> dust_33 (smelt) -> dust_66 (smelt) -> ingot

local function register_dust(name,input_node_name,ingot,grindcost,cooktime,R,G,B)
	
	if not R then R = "FF" end 
	if not G then G = "FF" end 
	if not B then B = "FF" end 
	
	local purity_table = {"00","33","66"};
	
	for i = 1,#purity_table do
		local purity = purity_table[i];
		minetest.register_craftitem("basic_machines:"..name.."_dust_".. purity, {
			description = name.. " dust purity " .. purity .. "%" .. (purity=="00" and " (combine with chemicals to create " .. name .. " extractor )" or " (smelt to increase purity)") ,
			inventory_image = "basic_machines_dust.png^[colorize:#"..R..G..B..":180",
		})
	end
	
	basic_machines.grinder_recipes[input_node_name] = {grindcost,"basic_machines:"..name.."_dust_".. purity_table[1].." 2",1} -- register grinder recipe
	
	if ingot~="" then
		
		for i = 2,#purity_table-1 do -- all dusts but first one are cookable
			minetest.register_craft({
				type = "cooking",
				recipe = "basic_machines:"..name.."_dust_".. purity_table[i],
				output = "basic_machines:"..name.."_dust_".. purity_table[i+1],
				cooktime = cooktime
			})
		end
		
		minetest.register_craft({
				type = "cooking",
				recipe = "basic_machines:"..name.."_dust_".. purity_table[#purity_table],
				groups = {not_in_creative_inventory=1},
				output = ingot,
				cooktime = cooktime
			})
	
	end
end


register_dust("iron","default:iron_lump","default:steel_ingot",4,8,"99","99","99")
register_dust("copper","default:copper_lump","default:copper_ingot",4,8,"C8","80","0D") --c8800d
register_dust("tin","default:tin_lump","default:tin_ingot",4,8,"9F","9F","9F")
register_dust("gold","default:gold_lump","default:gold_ingot",6,25,"FF","FF","00")

--  grinding ingots gives dust too
basic_machines.grinder_recipes["default:steel_ingot"] = {4,"basic_machines:iron_dust_00 2",1};
basic_machines.grinder_recipes["default:copper_ingot"] = {4,"basic_machines:copper_dust_00 2",1};
basic_machines.grinder_recipes["default:gold_ingot"] = {6,"basic_machines:gold_dust_00 2",1};
basic_machines.grinder_recipes["default:tin_ingot"] = {4,"basic_machines:tin_dust_00 2",1};

-- are moreores (tin, silver, mithril) present?

local table = minetest.registered_items["moreores:tin_lump"]; if table then 
	--register_dust("tin","moreores:tin_lump","moreores:tin_ingot",4,8,"FF","FF","FF")
	register_dust("silver","moreores:silver_lump","moreores:silver_ingot",5,15,"BB","BB","BB")
	register_dust("mithril","moreores:mithril_lump","moreores:mithril_ingot",16,750,"00","00","FF")
	
	basic_machines.grinder_recipes["moreores:tin_ingot"] = {4,"basic_machines:tin_dust_00 2",1};
	basic_machines.grinder_recipes["moreores:silver_ingot"] = {5,"basic_machines:silver_dust_33 2",1}; -- silver doesnt need extractor yet
	basic_machines.grinder_recipes["moreores:mithril_ingot"] = {16,"basic_machines:mithril_dust_00 2",1};
end


register_dust("mese","default:mese_crystal","default:mese_crystal",8,250,"CC","CC","00")
register_dust("diamond","default:diamond","default:diamond",16,500,"00","EE","FF") -- 0.3hr cooking time to make diamond!

-- darkage recipes and ice
minetest.register_craft({
	type = "cooking",
	recipe = "default:ice",
	output = "default:water_flowing",
	cooktime = 4
})

minetest.register_craft({
	type = "cooking",
	recipe = "default:stone",
	output = "darkage:basalt",
	cooktime = 60
})

minetest.register_craft({
	type = "cooking",
	recipe = "darkage:slate",
	output = "darkage:schist",
	cooktime = 20
})

-- dark age recipe: cook schist to get gneiss

minetest.register_craft({
	type = "cooking",
	recipe = "darkage:gneiss",
	output = "darkage:marble",
	cooktime = 20
})


minetest.register_craft({
	output = "darkage:serpentine",
	recipe = {
		{"darkage:marble","default:cactus"}
	}
})

minetest.register_craft({
	output = "darkage:mud",
	recipe = {
		{"default:dirt","default:water_flowing"}
	}
})


-- EXTRACTORS, their recipes and smelting recipes

local function register_extractor(name, R,G,B)
	
	if not R then R = "FF" end 
	if not G then G = "FF" end 
	if not B then B = "FF" end 

	minetest.register_craftitem("basic_machines:"..name.."_extractor", {
		description = "smelt to get " .. name ,
		inventory_image = "ore_extractor.png^[colorize:#"..R..G..B..":180",
	})
	
	
end

register_extractor("iron","99","99","99")
register_extractor("copper","C8","80","0D")
register_extractor("tin","C8","9F","9F")
register_extractor("gold","FF","FF","00")
register_extractor("mese","CC","CC","00")
register_extractor("diamond","00","EE","FF")
register_extractor("mithril","00","00","FF")

minetest.register_craft({
	output = 'basic_machines:iron_extractor',
	recipe = {
		{'default:leaves','default:leaves','basic_machines:iron_dust_00'},
	}
})

--  extractor smelts to dust_33

minetest.register_craft({ 
	type = "cooking",
	recipe = "basic_machines:iron_extractor",
	output = "basic_machines:iron_dust_33",
	cooktime = 10
})

minetest.register_craft({
	output = 'basic_machines:copper_extractor',
	recipe = {
		{'default:papyrus','default:papyrus','basic_machines:copper_dust_00'},
	}
})

minetest.register_craft({ 
	type = "cooking",
	recipe = "basic_machines:copper_extractor",
	output = "basic_machines:copper_dust_33",
	cooktime = 10
})

minetest.register_craft({
	output = 'basic_machines:tin_extractor',
	recipe = {
		{'farming:cocoa_beans','farming:cocoa_beans','basic_machines:tin_dust_00'},
	}
})

minetest.register_craft({ 
	type = "cooking",
	recipe = "basic_machines:tin_extractor",
	output = "basic_machines:tin_dust_33",
	cooktime = 10
})

minetest.register_craft({
	output = 'basic_machines:gold_extractor',
	recipe = {
		{'basic_machines:tin_extractor','basic_machines:copper_extractor','basic_machines:gold_dust_00'},
	}
})

minetest.register_craft({ 
	type = "cooking",
	recipe = "basic_machines:gold_extractor",
	output = "basic_machines:gold_dust_33",
	cooktime = 10
})

minetest.register_craft({
	output = 'basic_machines:mese_extractor',
	recipe = {
		{'farming:rhubarb','farming:rhubarb', 'basic_machines:mese_dust_00'},
	}
})

minetest.register_craft({ 
	type = "cooking",
	recipe = "basic_machines:mese_extractor",
	output = "basic_machines:mese_dust_33",
	cooktime = 10
})

minetest.register_craft({
	output = 'basic_machines:diamond_extractor',
	recipe = {
		{'farming:wheat','farming:cotton', 'basic_machines:diamond_dust_00'},
	}
})

minetest.register_craft({ 
	type = "cooking",
	recipe = "basic_machines:diamond_extractor",
	output = "basic_machines:diamond_dust_33",
	cooktime = 10
})

minetest.register_craft({
	output = 'basic_machines:mithril_extractor',
	recipe = {
		{'flowers:geranium','flowers:geranium', 'basic_machines:mithril_dust_00'}, -- blue flowers
	}
})


minetest.register_craft({ 
	type = "cooking",
	recipe = "basic_machines:mithril_extractor",
	output = "basic_machines:mithril_dust_33",
	cooktime = 10
})