------------------------------------------------------------------------------------------------------------------------------------
-- BASIC MACHINES MOD by rnd
-- mod with basic simple automatization for minetest. No background processing, no abm's or other lag causing background processing.
------------------------------------------------------------------------------------------------------------------------------------

-- MOVER: universal moving machine, requires coal in nearby chest to operate
-- can take item from chest and place it in chest or as a node outside at ranges -5,+5
-- it can be used for filtering by setting "filter". if set to "object" it will teleport all objects at start location.
-- if set to "drop" it will drop node at target location, if set to "dig" it will dig out nodes and return appropriate drops.

-- input is: where to take and where to put
-- to operate mese power is needed

-- KEYPAD: can serve as a button to activate machines ( partially mesecons compatible ). Can be password protected. Can serve as a
-- replacement for mesecons blinky plant, limited to max 100 operations.
-- As a simple example it can be used to open doors, which close automatically after 5 seconds.


MOVER_FUEL_STORAGE_CAPACITY =  5; -- how many operations from one coal lump
minetest.register_node("basic_machines:mover", {
	description = "Mover",
	tiles = {"default_furnace_top.png"},
	groups = {oddly_breakable_by_hand=2,mesecon_effector_on = 1},
	sounds = default.node_sound_wood_defaults(),
	after_place_node = function(pos, placer)
		local meta = minetest.env:get_meta(pos)
		meta:set_string("infotext", "Mover block. Right click to set it up. Or set positions by punching it.")
		meta:set_string("owner", placer:get_player_name()); meta:set_int("public",0);
		meta:set_int("x0",0);meta:set_int("y0",-1);meta:set_int("z0",0); -- source1
		meta:set_int("x1",0);meta:set_int("y1",-1);meta:set_int("z1",0); -- source2: defines cube
		meta:set_int("pc",0); meta:set_int("dim",1);-- current cube position and dimensions
		meta:set_int("x2",0);meta:set_int("y2",1);meta:set_int("z2",0);
		meta:set_float("fuel",0)
		meta:set_string("prefer", "");
	end,
		
	mesecons = {effector = {
		action_on = function (pos, node) 
		local meta = minetest.get_meta(pos);
		local fuel = meta:get_float("fuel");
		
		--minetest.chat_send_all("mover mesecons: runnning with pos " .. pos.x .. " " .. pos.y .. " " .. pos.z)
		
		local x0,y0,z0,x1,y1,z1;
			x0=meta:get_int("x0");y0=meta:get_int("y0");z0=meta:get_int("z0");
			local pos1 = {x=x0+pos.x,y=y0+pos.y,z=z0+pos.z}; -- where to take from
			local pos2 = {x=meta:get_int("x2")+pos.x,y=meta:get_int("y2")+pos.y,z=meta:get_int("z2")+pos.z}; -- where to put

			local pc = meta:get_int("pc"); local dim = meta:get_int("dim");	pc = (pc+1) % dim;meta:set_int("pc",pc) -- cycle position
			x1=meta:get_int("x1")-x0+1;y1=meta:get_int("y1")-y0+1;z1=meta:get_int("z1")-z0+1; -- get dimensions
			
			--pc = z*a*b+x*b+y, from x,y,z to pc
			-- set current input position
			pos1.y = y0 + (pc % y1); pc = (pc - (pc % y1))/y1;
			pos1.x = x0 + (pc % x1); pc = (pc - (pc % x1))/x1;
			pos1.z = z0 + pc;
			pos1.x = pos.x+pos1.x;pos1.y = pos.y+pos1.y;pos1.z = pos.z+pos1.z;
	
		if fuel<=0 then -- needs fuel to operate, find nearby open chest with fuel within radius 1
			local r = 1;
		
			local positions = minetest.find_nodes_in_area( --find furnace with fuel
			{x=pos.x-r, y=pos.y-r, z=pos.z-r},
			{x=pos.x+r, y=pos.y+r, z=pos.z+r},
			"default:chest")
			local fpos = nil;
			for _, p in ipairs(positions) do
				-- dont take coal from source or target location
				if (p.x ~= pos1.x or p.y~=pos1.y or p.z ~= pos1.z) and (p.x ~= pos2.x or p.y~=pos2.y or p.z ~= pos2.z) then
					fpos = p;
				end
			end
			
			if not fpos then return end -- no chest found
			local cmeta = minetest.get_meta(fpos);
			local inv = cmeta:get_inventory();
			local fuels = {["default:coal_lump"]=1,["default:cactus"]=1,["default:coalblock"]=10};
			local found_fuel = nil;local stack;
			for i,v in pairs(fuels) do
				stack = ItemStack({name=i})
				if inv:contains_item("main", stack) then found_fuel = v break end
			end
			 -- check for this fuel
			if found_fuel~=nil then
				--minetest.chat_send_all(" refueled ")
				inv:remove_item("main", stack)
				meta:set_float("fuel", fuel+MOVER_FUEL_STORAGE_CAPACITY*found_fuel);
				fuel = fuel+MOVER_FUEL_STORAGE_CAPACITY*found_fuel;
				meta:set_string("infotext", "Mover block. Fuel "..MOVER_FUEL_STORAGE_CAPACITY);
			else meta:set_string("infotext", "Mover block. Out of fuel.");return
			end
			--check fuel
			if fuel == 0 then return  end
		end 

	local owner = meta:get_string("owner");

	-- check protections
	if minetest.is_protected(pos1, owner) or minetest.is_protected(pos2, owner) then
		meta:set_float("fuel", -1);
		meta:set_string("infotext", "Mover block. Protection fail. Deactivated.")
	return end
	
	local prefer = meta:get_string("prefer"); local mode = meta:get_string("mode");
	
	if mode == "reverse" then -- reverse pos1, pos2
		local post = {x=pos1.x,y=pos1.y,z=pos1.z};
		pos1 = {x=pos2.x,y=pos2.y,z=pos2.z};
		pos2 = {x=post.x,y=post.y,z=post.z};
	end
	local node1 = minetest.get_node(pos1);local node2 = minetest.get_node(pos2);
	
	if mode == "object" then -- teleport objects, for free
		for _,obj in pairs(minetest.get_objects_inside_radius(pos1, 2)) do
			obj:moveto(pos2, false) 	
		end
		minetest.sound_play("transporter", {pos=pos2,gain=1.0,max_hear_distance = 32,})
		--meta:set_float("fuel", fuel - 1);
		return 
	end
	
	local dig=false; if mode == "dig" then dig = true; end -- digs at target location
	local drop = false; if mode == "drop" then drop = true; end -- drops node instead of placing it
	
	-- decide what to do if source or target are chests
	local source_chest=false; if string.find(node1.name,"default:chest") then source_chest=true end
	if node1.name == "air" then return end -- nothing to move

	local target_chest = false
	if node2.name == "default:chest" or node2.name == "default:chest_locked" then
		target_chest = true
	end
	if not target_chest and minetest.get_node(pos2).name ~= "air" then return end -- do nothing if target nonempty and not chest

	-- filtering
	if prefer~="" then -- prefered node set
		if prefer~=node1.name and not source_chest  then return end -- only take prefered node or from chests
		if source_chest then -- take stuff from chest
			--minetest.chat_send_all(" source chest detected")
			local cmeta = minetest.get_meta(pos1);
			local inv = cmeta:get_inventory();
			local stack = ItemStack({name=prefer})
			if inv:contains_item("main", stack) then
				inv:remove_item("main", stack);
				else return
			end
		end
		node1 = {}; node1.name = prefer; 
	end
	
	if source_chest and prefer == "" then return end -- doesnt know what to take out of chest
	--minetest.chat_send_all(" moving ")
	
	-- if target chest put in chest
	if target_chest then
		local cmeta = minetest.get_meta(pos2);
		local inv = cmeta:get_inventory();
		
		-- dig tree or cactus
		local count = 0;
		if dig then 
			-- check for cactus or tree
			local dig_up = false
			local dig_up_table = {"default:cactus","default:tree","default:jungletree","default:papyrus"};
			for i,v in pairs(dig_up_table) do
				if node1.name==v then dig_up = true break end
			end
			
			
			if dig_up == true then -- dig up to height 10, break sooner if needed
				for i=0,10 do
					local pos3 = {x=pos1.x,y=pos1.y+i,z=pos1.z};
					local dname= minetest.get_node(pos3).name;
					if dname ~=node1.name then break end
					minetest.set_node(pos3,{name="air"}); count = count+1;
				end
			end
			
			-- read what to drop, if none just keep original node
			local table = minetest.registered_items[node1.name];
			if table~=nil then 
				if table.drop~= nil and table.drop~="" then 
					node1={}; node1.name = table.drop;
				end
			end
			
		end

		local stack = ItemStack(node1.name)
		if count>0 then stack = ItemStack({name=node1.name, count=count}) end
		
		if inv:room_for_item("main", stack) then
			inv:add_item("main", stack);
		end
	end	
	
	minetest.sound_play("transporter", {pos=pos2,gain=1.0,max_hear_distance = 32,})
	fuel = fuel -1;	meta:set_float("fuel", fuel); -- burn fuel
	meta:set_string("infotext", "Mover block. Fuel "..fuel);
	
	
	if not target_chest then
		if not drop then minetest.set_node(pos2, {name = node1.name}); end
		if drop then 
			local stack = ItemStack(node1.name);minetest.add_item(pos2,stack) -- drops it
		end
	end 
	if not source_chest then
		if dig then minetest.dig_node(pos1);nodeupdate(pos1) end
		minetest.set_node(pos1, {name = "air"});
		end
	end
	}
	},
	on_rightclick = function(pos, node, player, itemstack, pointed_thing)
		local meta = minetest.get_meta(pos);
		if meta:get_string("owner")~=player:get_player_name() then return end -- only owner can set up mover
		
		local x0,y0,z0,x1,y1,z1,x2,y2,z2,prefer,mode;
		x0=meta:get_int("x0");y0=meta:get_int("y0");z0=meta:get_int("z0");
		x1=meta:get_int("x1");y1=meta:get_int("y1");z1=meta:get_int("z1");
		x2=meta:get_int("x2");y2=meta:get_int("y2");z2=meta:get_int("z2");
		prefer = meta:get_string("prefer");mode = meta:get_string("mode");
		local form  = 
		"size[3,5]" ..  -- width, height
		"field[0.25,0.5;1,1;x0;source1;"..x0.."] field[1.25,0.5;1,1;y0;;"..y0.."] field[2.25,0.5;1,1;z0;;"..z0.."]"..
		"field[0.25,1.5;1,1;x1;source2;"..x1.."] field[1.25,1.5;1,1;y1;;"..y1.."] field[2.25,1.5;1,1;z1;;"..z1.."]"..
		"field[0.25,2.5;1,1;x2;Target;"..x2.."] field[1.25,2.5;1,1;y2;;"..y2.."] field[2.25,2.5;1,1;z2;;"..z2.."]"..
		"button[2,4.25.;1,1;OK;OK] field[0.25,3.5;3,1;prefer;filter only block;"..prefer.."]"..
		"field[0.25,4.5;2,1;mode;mode;"..mode.."]";
		minetest.show_formspec(player:get_player_name(), "basic_machines:mover_"..minetest.pos_to_string(pos), form)
	end
})

-- KEYPAD

minetest.register_node("basic_machines:keypad", {
	description = "Keypad",
	tiles = {"keypad.png"},
	groups = {oddly_breakable_by_hand=2},
	sounds = default.node_sound_wood_defaults(),
	after_place_node = function(pos, placer)
		local meta = minetest.env:get_meta(pos)
		meta:set_string("infotext", "Keypad. Right click to set it up. Or punch it while holding sneak.")
		meta:set_string("owner", placer:get_player_name()); meta:set_int("public",1);
		meta:set_int("x0",0);meta:set_int("y0",1);meta:set_int("z0",0); -- target
		meta:set_string("pass", "");
		meta:set_int("iter",1);
	end,
		
	mesecons = {effector = {
		action_on = function (pos, node) 
		local meta = minetest.get_meta(pos);
		-- not yet defined ... ???
	end
	}
	},
	on_rightclick = function(pos, node, player, itemstack, pointed_thing)
		local meta = minetest.get_meta(pos);
		if meta:get_string("owner")~= player:get_player_name() then return end -- only owner can setup keypad
		local x0,y0,z0,pass,iter;
		x0=meta:get_int("x0");y0=meta:get_int("y0");z0=meta:get_int("z0");iter=meta:get_int("iter") or 1;
		
		pass = meta:get_string("pass");
		local form  = 
		"size[3,2.75]" ..  -- width, height
		"field[0.25,0.5;1,1;x0;target;"..x0.."] field[1.25,0.5;1,1;y0;;"..y0.."] field[2.25,0.5;1,1;z0;;"..z0.."]"..
		"button[0.,2.25;1,1;OK;OK] field[0.25,1.5;3,1;pass;Password: ;"..pass.."]" .. "field[1.25,2.5;2,1;iter;Repeat;".. iter .."]";
		minetest.show_formspec(player:get_player_name(), "basic_machines:keypad_"..minetest.pos_to_string(pos), form)
	end
})

local function use_keypad(pos,name)
	
		
	local meta = minetest.get_meta(pos);	
	local name =  meta:get_string("owner");
	if minetest.is_protected(pos,name) then meta:set_string("infotext", "Protection fail. reset."); meta:set_int("count",0) end
	local count = meta:get_int("count") or 0;
		
	if count<=0 then return end; count = count - 1; meta:set_int("count",count);
	minetest.after(5, function() use_keypad(pos) end )  -- repeat operation as many times as set with "iter"
	
	local x0,y0,z0;
	x0=meta:get_int("x0");y0=meta:get_int("y0");z0=meta:get_int("z0");
	x0=pos.x+x0;y0=pos.y+y0;z0=pos.z+z0;
	--minetest.chat_send_all("KEYPAD USED. TARGET ".. x0 .. " " .. y0 .. " " .. z0);
	local tpos = {x=x0,y=y0,z=z0};
	
	local node = minetest.get_node(tpos);if not node.name then return end -- error
	
	
	local table = minetest.registered_nodes[node.name];
	if not table then return end -- error
	if not table.mesecons then return end -- error
	if not table.mesecons.effector then return end -- error
	local effector=table.mesecons.effector;
	if not effector.action_on then return end
	
	effector.action_on(tpos,node); -- run
	--minetest.chat_send_all("MESECONS RUN")
			
end


local function check_keypad(pos,name)
	local meta = minetest.get_meta(pos);
	local pass =  meta:get_string("pass");
	if pass == "" then meta:set_int("count",meta:get_int("iter")); use_keypad(pos) return end
	pass = ""
	local form  = 
		"size[3,1]" ..  -- width, height
		"button[0.,0.5;1,1;OK;OK] field[0.25,0.25;3,1;pass;Enter Password: ;".."".."]";
		minetest.show_formspec(name, "basic_machines:check_keypad_"..minetest.pos_to_string(pos), form)

end

-- DETECTOR

minetest.register_node("basic_machines:detector", { -- TO DO
	description = "Detector",
	tiles = {"detector.png"},
	groups = {oddly_breakable_by_hand=2},
	sounds = default.node_sound_wood_defaults(),
	after_place_node = function(pos, placer)
		local meta = minetest.env:get_meta(pos)
		meta:set_string("infotext", "Detector. Right click/punch to set it up.")
		meta:set_string("owner", placer:get_player_name()); meta:set_int("public",0);
		meta:set_int("x1",0);meta:set_int("y1",-1);meta:set_int("z0",0); -- source: read
		meta:set_int("x2",0);meta:set_int("y2",-1);meta:set_int("z2",0); -- target: activate
	end,
		
	mesecons = {effector = {
		action_on = function (pos, node) 
		local meta = minetest.get_meta(pos);
		-- not yet defined ... ???
	end
	}
	},
	on_rightclick = function(pos, node, player, itemstack, pointed_thing)
		local meta = minetest.get_meta(pos);
		if meta:get_string("owner")~= player:get_player_name() then return end -- only owner can setup keypad
		local x0,y0,z0,pass,iter;
		x0=meta:get_int("x0");y0=meta:get_int("y0");z0=meta:get_int("z0");iter=meta:get_int("iter") or 1;
		
		pass = meta:get_string("pass");
		local form  = 
		"size[3,2.75]" ..  -- width, height
		"field[0.25,0.5;1,1;x0;target;"..x0.."] field[1.25,0.5;1,1;y0;;"..y0.."] field[2.25,0.5;1,1;z0;;"..z0.."]"..
		"button[0.,2.25;1,1;OK;OK] field[0.25,1.5;3,1;pass;Password: ;"..pass.."]" .. "field[1.25,2.5;2,1;iter;Repeat;".. iter .."]";
		minetest.show_formspec(player:get_player_name(), "basic_machines:keypad_"..minetest.pos_to_string(pos), form)
	end
})






local punchset = {}; 
punchset.known_nodes = {["basic_machines:mover"]=true,["basic_machines:keypad"]=true};

-- handles set up punches
minetest.register_on_punchnode(function(pos, node, puncher, pointed_thing)
	local name = puncher:get_player_name(); if name==nil then return end
	if punchset[name]== nil then  -- set up punchstate
		punchset[name] = {} 
		punchset[name].node = ""
		punchset[name].pos1 = {x=0,y=0,z=0};punchset[name].pos2 = {x=0,y=0,z=0};punchset[name].pos = {x=0,y=0,z=0};
		punchset[name].state = 0; -- 0 ready for punch, 1 ready for start position, 2 ready for end position
		return
	end

	-- check for known node names in case of first punch
	if punchset[name].state == 0 and not punchset.known_nodes[node.name] then return end
	-- from now on only punches with mover/keypad/... or setup punches
	
	if punchset.known_nodes[node.name] then  -- check if owner of machine is punching or if machine public
			local meta = minetest.get_meta(pos);
			if not (meta:get_int("public") == 1) then
				if meta:get_string("owner")~= name then return end
			end
	end
	
	if node.name == "basic_machines:mover" then -- mover init code
		if punchset[name].state == 0 then 
			minetest.chat_send_player(name, "mover setup: Now punch starting and end position to set up mover.")
			punchset[name].node = node.name;punchset[name].pos = {x=pos.x,y=pos.y,z=pos.z};
			punchset[name].state = 1 
			return
		end
	end
	
	 if punchset[name].node == "basic_machines:mover" then -- mover code
		if punchset[name].state == 1 then 
			if math.abs(punchset[name].pos.x - pos.x)>5 or math.abs(punchset[name].pos.y - pos.y)>5 or math.abs(punchset[name].pos.z - pos.z)>5 then
					minetest.chat_send_player(name, "mover setup: Punch closer to mover. reseting.")
					punchset[name].state = 0; return
			end
			punchset[name].pos1 = {x=pos.x,y=pos.y,z=pos.z};punchset[name].state = 2;
			minetest.chat_send_player(name, "mover setup: Start position for mover set. Punch again to set end position.")
			return
		end
		
		if punchset[name].state == 2 then 
			if punchset[name].node~="basic_machines:mover" then punchset[name].state = 0 return end
			if math.abs(punchset[name].pos.x - pos.x)>5 or math.abs(punchset[name].pos.y - pos.y)>5 or math.abs(punchset[name].pos.z - pos.z)>5 then
					minetest.chat_send_player(name, "mover setup: Punch closer to mover. reseting.")
					punchset[name].state = 0; return
			end
			punchset[name].pos2 = {x=pos.x,y=pos.y,z=pos.z}; punchset[name].state = 0;
			minetest.chat_send_player(name, "End position for mover set.")
			local x = punchset[name].pos1.x-punchset[name].pos.x;
			local y = punchset[name].pos1.y-punchset[name].pos.y;
			local z = punchset[name].pos1.z-punchset[name].pos.z;
			local meta = minetest.get_meta(punchset[name].pos);
			meta:set_int("x0",x);meta:set_int("y0",y);meta:set_int("z0",z);
			meta:set_int("x1",x);meta:set_int("y1",y);meta:set_int("z1",z);
			x = punchset[name].pos2.x-punchset[name].pos.x;
			y = punchset[name].pos2.y-punchset[name].pos.y;
			z = punchset[name].pos2.z-punchset[name].pos.z;
			meta:set_int("x2",x);meta:set_int("y2",y);meta:set_int("z2",z);
			meta:set_int("pc",0); meta:set_int("dim",1);
			return
		end
	end
	
	if node.name == "basic_machines:keypad" then -- keypad init/usage code
		if not puncher:get_player_control().sneak then
			check_keypad(pos,name)-- not setup, just standard operation
			return
		end
		local meta = minetest.get_meta(pos);
		if meta:get_string("owner")~= name then minetest.chat_send_player(name, "Only owner can set up keypad.") return end
		
		if punchset[name].state == 0 then 
			minetest.chat_send_player(name, "keypad setup: Now punch the target block.")
			punchset[name].node = node.name;punchset[name].pos = {x=pos.x,y=pos.y,z=pos.z};
			punchset[name].state = 1 
			return
		end
	end
	
	if punchset[name].node=="basic_machines:keypad" then -- keypad setup code
		if punchset[name].state == 1 then 
			local meta = minetest.get_meta(punchset[name].pos);
			local x = pos.x-punchset[name].pos.x;
			local y = pos.y-punchset[name].pos.y;
			local z = pos.z-punchset[name].pos.z;
			
			if math.abs(x)>5 or math.abs(y)>5 or math.abs(z)>5 then
					minetest.chat_send_player(name, "keypad setup: Punch closer to keypad. reseting.")
					punchset[name].state = 0; return
			end
			
			meta:set_int("x0",x);meta:set_int("y0",y);meta:set_int("z0",z);	
			punchset[name].state = 0 
			minetest.chat_send_player(name, "keypad setup: Keypad target set with coordinates " .. x .. " " .. y .. " " .. z)
			return
		end
	end
	
end)


-- handles forms processing for all machines
minetest.register_on_player_receive_fields(function(player,formname,fields)
	
	local fname = "basic_machines:mover_"
	if string.sub(formname,0,string.len(fname)) == fname then
		local pos_s = string.sub(formname,string.len(fname)+1); local pos = minetest.string_to_pos(pos_s)
		local name = player:get_player_name(); if name==nil then return end
		local meta = minetest.get_meta(pos)
		if name ~= meta:get_string("owner") or not fields then return end -- only owner can interact
		--minetest.chat_send_all("formname " .. formname .. " fields " .. dump(fields))
		
		if fields.OK == "OK" then
			local x0,y0,z0,x1,y1,z1,x2,y2,z2;
			x0=tonumber(fields.x0) or 0;y0=tonumber(fields.y0) or -1;z0=tonumber(fields.z0) or 0
			x1=tonumber(fields.x1) or 0;y1=tonumber(fields.y1) or -1;z1=tonumber(fields.z1) or 0
			x2=tonumber(fields.x2) or 0;y2=tonumber(fields.y2) or 1;z2=tonumber(fields.z2) or 0;
			if math.abs(x1)>5 or math.abs(y1)>5 or math.abs(z1)>5 or math.abs(x2)>5 or math.abs(y2)>5 or math.abs(z2)>5 then
				minetest.chat_send_player(name,"all coordinates must be between -5 and 5"); return
			end
			if x1<x0 or y1<y0 or z1<z0 then
				minetest.chat_send_player(name,"second source coordinates must all be larger than first source coordinates"); return
			end
			
			meta:set_int("x0",x0);meta:set_int("y0",y0);meta:set_int("z0",z0);
			meta:set_int("x1",x1);meta:set_int("y1",y1);meta:set_int("z1",z1);
			meta:set_int("pc",0); meta:set_int("dim",(x1-x0+1)*(y1-y0+1)*(z1-z0+1))
			meta:set_int("x2",x2);meta:set_int("y2",y2);meta:set_int("z2",z2);
			meta:set_string("prefer",fields.prefer or "");
			meta:set_string("mode",fields.mode or "");
			meta:set_string("infotext", "Mover block. Set up with source coordinates ".. x0 ..","..y0..","..z0.. " -> ".. x1 ..","..y1..","..z1.. " and target coord ".. x2 ..","..y2..",".. z2 .. ". Put chest with coal next to it and start with mese signal.");
			if meta:get_float("fuel")<0 then meta:set_float("fuel",0) end -- reset block
		end
		return
	end
	
	fname = "basic_machines:keypad_"
	if string.sub(formname,0,string.len(fname)) == fname then
		local pos_s = string.sub(formname,string.len(fname)+1); local pos = minetest.string_to_pos(pos_s)
		local name = player:get_player_name(); if name==nil then return end
		local meta = minetest.get_meta(pos)
		if name ~= meta:get_string("owner") or not fields then return end -- only owner can interact
		
		if fields.OK == "OK" then
			local x0,y0,z0,pass;
			x0=tonumber(fields.x0) or 0;y0=tonumber(fields.y0) or 1;z0=tonumber(fields.z0) or 0
			pass = fields.pass or "";
			if math.abs(x0)>5 or math.abs(y0)>5 or math.abs(z0)>5 then
				minetest.chat_send_player(name,"all coordinates must be between -5 and 5"); return
			end
			meta:set_int("x0",x0);meta:set_int("y0",y0);meta:set_int("z0",z0);meta:set_string("pass",pass);
			meta:set_int("iter",math.min(tonumber(fields.iter) or 1,100));
			meta:set_string("infotext", "Punch keypad to use it.");
			if pass~="" then meta:set_string("infotext",meta:get_string("infotext").. ". Password protected."); end
		end
		return
	end
	
	fname = "basic_machines:check_keypad_"
	if string.sub(formname,0,string.len(fname)) == fname then
		local pos_s = string.sub(formname,string.len(fname)+1); local pos = minetest.string_to_pos(pos_s)
		local name = player:get_player_name(); if name==nil then return end
		local meta = minetest.get_meta(pos)
	
		if fields.OK == "OK" then
			local pass;
			pass = fields.pass or "";			
			if pass~=meta:get_string("pass") then
				minetest.chat_send_player(name,"ACCESS DENIED. WRONG PASSWORD.")
				return
			end
		minetest.chat_send_player(name,"ACCESS GRANTED.")
		meta:set_int("count",meta:get_int("iter"));use_keypad(pos)
		return
		end
	end
	
end)

-- CRAFTS

minetest.register_craft({
	output = "basic_machines:mover",
	recipe = {
		{"default:diamond", "default:diamond", "default:diamond"},
		{"default:mese_crystal", "default:mese_crystal","default:mese_crystal"},
		{"default:stone", "default:wood", "default:stone"}
	}
})

minetest.register_craft({
	output = "basic_machines:keypad",
	recipe = {
		{"default:stick"},
		{"default:wood"},
	}
})