-- ENVIRO block
-- TO DO: mod only: skybox, speed > 1, jump?, radius > 10, gravity < 0
-- privs: kick

-- rnd 2016:
basic_machines.skyboxes = {
	["default"]={type = "regular", tex = {}}, 
	["space"]={type="skybox", tex={"sky_pos_y.png","sky_neg_y.png","sky_pos_z.png","sky_neg_z.png","sky_neg_x.png","sky_pos_x.png",}},
	["caves"]={type = "cavebox", tex = {"black.png","black.png","black.png","black.png","black.png","black.png",}}};
	

-- enviroment changer
minetest.register_node("basic_machines:enviro", {
	description = "Changes enviroment for players around target location",
	tiles = {"enviro.png"},
	groups = {oddly_breakable_by_hand=2},
	sounds = default.node_sound_wood_defaults(),
	after_place_node = function(pos, placer)
		local meta = minetest.env:get_meta(pos)
		meta:set_string("infotext", "Right click to set it. Activate by signal.")
		meta:set_string("owner", placer:get_player_name()); meta:set_int("public",1);
		meta:set_int("x0",0);meta:set_int("y0",0);meta:set_int("z0",0); -- target
		meta:set_int("r",5); meta:set_string("skybox","default");
		meta:set_float("speed",1);
		meta:set_float("jump",1);
		meta:set_float("g",1);
		meta:set_float("sneak",1);
		
		
		local name = placer:get_player_name();
		meta:set_string("owner",name);
	end,
		
	mesecons = {effector = { 
		action_on = function (pos, node,ttl) 
		
	end
	}
	},
	on_rightclick = function(pos, node, player, itemstack, pointed_thing)
		local meta = minetest.get_meta(pos);
		local privs = minetest.get_player_privs(player:get_player_name());
		local cant_build = minetest.is_protected(pos,player:get_player_name());
		--meta:get_string("owner")~=player:get_player_name() and 
		if not privs.privs and cant_build then 
			return 
		end -- only  ppl sharing protection can set up keypad
		local x0,y0,z0;
		x0=meta:get_int("x0");y0=meta:get_int("y0");z0=meta:get_int("z0");
		local skybox = meta:get_string("skybox");
		local skylist = "";
		for i,_ in pairs(basic_machines.skyboxes) do
			skylist = skylist .. i .. ",";
		end
		
		machines.pos1[player:get_player_name()] = {x=pos.x+x0,y=pos.y+y0,z=pos.z+z0};machines.mark_pos1(player:get_player_name()) -- mark pos1
		
		
		local r = meta:get_int("r");
		local speed,jump, g, sneak;
		speed = meta:get_float("speed");jump = meta:get_float("jump");
		g = meta:get_float("g"); sneak = meta:get_float("sneak");
		local form  = 
		"size[4.25,3.75]" ..  -- width, height
		"field[0.25,0.5;1,1;x0;target;"..x0.."] field[1.25,0.5;1,1;y0;;"..y0.."] field[2.25,0.5;1,1;z0;;"..z0.."]"..
		"field[3.25,0.5;1,1;r;radius;"..r.."]"..
		--speed, jump, gravity,sneak
		"field[0.25,1.5;1,1;speed;speed;"..speed.."]"..
		"field[1.25,1.5;1,1;jump;jump;".. jump.."]"..
		"field[2.25,1.5;1,1;g;gravity;"..g.."]"..
		"field[3.25,1.5;1,1;sneak;sneak;"..sneak.."]"..
		"label[0.,3.0;Skybox selection]"..
		"dropdown[0.,3.35;3,1;skybox;"..skylist..";".. skybox .."]"..
		"button_exit[3.25,3.25;1,1;OK;OK]";
		minetest.show_formspec(player:get_player_name(), "basic_machines:enviro_"..minetest.pos_to_string(pos), form)
		meta:set_string("formspec",form);
		-- end
	end,
	
	on_receive_fields = function(pos, formname, fields, sender)
		minetest.chat_send_all(" FORM ");
		local meta = minetest.get_meta(pos);
		local x0=0; local y0=0; local z0=0;
		if fields.x0 then x0 = tonumber(fields.x0) or 0 end
		if fields.y0 then y0 = tonumber(fields.y0) or 0 end
		if fields.z0 then z0 = tonumber(fields.z0) or 0 end
		meta:set_int("x0",x0);meta:set_int("y0",y0);meta:set_int("z0",z0);
		-- TO DO..
	end
})