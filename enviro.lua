-- ENVIRO block: change physics and skybox for players
-- note: nonadmin players are limited in changes ( cant change skybox and have limits on other allowed changes)

-- rnd 2016:

local enviro = {};
enviro.skyboxes = {
	["default"]={type = "regular", tex = {}}, 
	["space"]={type="skybox", tex={"sky_pos_y.png","sky_neg_y.png","sky_pos_z.png","sky_neg_z.png","sky_neg_x.png","sky_pos_x.png",}},
	["caves"]={type = "cavebox", tex = {"black.png","black.png","black.png","black.png","black.png","black.png",}}};


	
local enviro_update_form = function (pos)
	
		local meta = minetest.get_meta(pos);
	
		local x0,y0,z0;
		x0=meta:get_int("x0");y0=meta:get_int("y0");z0=meta:get_int("z0");

		local skybox = meta:get_string("skybox");
		local skylist = "";
		local sky_ind,j;
		j=1;sky_ind = 3;
		for i,_ in pairs(enviro.skyboxes) do
			if i == skybox then sky_ind = j end
			skylist = skylist .. i .. ",";
			j=j+1;
		end
		local r = meta:get_int("r");
		local speed,jump, g, sneak;
		speed = meta:get_float("speed");jump = meta:get_float("jump");
		g = meta:get_float("g"); sneak = meta:get_int("sneak");
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
		"dropdown[0.,3.35;3,1;skybox;"..skylist..";".. sky_ind .."]"..
		"button_exit[3.25,3.25;1,1;OK;OK]";
		meta:set_string("formspec",form);

end
	
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
		meta:set_int("sneak",1);
		meta:set_int("admin",0);
		local name = placer:get_player_name();
		meta:set_string("owner",name);
		local privs = minetest.get_player_privs(name);
		if privs.privs then meta:set_int("admin",1) end
		
		enviro_update_form(pos);
	end,
		
	mesecons = {effector = { 
		action_on = function (pos, node,ttl) 
			local meta = minetest.get_meta(pos);
			local admin = meta:get_int("admin");
			
			local x0,y0,z0,r,skybox,speed,jump,g,sneak;
			x0=meta:get_int("x0"); y0=meta:get_int("y0");z0=meta:get_int("z0"); -- target
			r= meta:get_int("r",5); skybox=meta:get_string("skybox");
			speed=meta:get_float("speed");jump=	meta:get_float("jump");
			g=meta:get_float("g");sneak=meta:get_int("sneak"); if sneak~=0 then sneak = true else sneak = false end
			
			local players = minetest.get_connected_players();
			for _,player in pairs(players) do
				local pos1 = player:getpos();
				local dist = math.sqrt((pos1.x-pos.x)^2 + (pos1.y-pos.y)^2 + (pos1.z-pos.z)^2 );
				if dist<=r then
					player:set_physics_override({speed=speed,jump=jump,gravity=g,sneak=sneak})
					if admin == 1 then -- only admin can change skybox
						local sky = enviro.skyboxes[skybox];
						player:set_sky(0,sky["type"],sky["tex"]);
					end
				end
				
			end
		end
	}
	},
	
	
	on_receive_fields = function(pos, formname, fields, sender)
		
		local name = sender:get_player_name();if minetest.is_protected(pos,name) then return end
		
		if fields.OK then
			local privs = minetest.get_player_privs(sender:get_player_name());
			local meta = minetest.get_meta(pos);
			local x0=0; local y0=0; local z0=0;
			--minetest.chat_send_all("form at " .. dump(pos) .. " fields " .. dump(fields))
			if fields.x0 then x0 = tonumber(fields.x0) or 0 end
			if fields.y0 then y0 = tonumber(fields.y0) or 0 end
			if fields.z0 then z0 = tonumber(fields.z0) or 0 end
			if not privs.privs and (math.abs(x0)>10 or math.abs(y0)>10 or math.abs(z0) > 10) then return end
			
			meta:set_int("x0",x0);meta:set_int("y0",y0);meta:set_int("z0",z0);
			if privs.privs then -- only admin can set sky
				if fields.skybox then meta:set_string("skybox", fields.skybox) end
			end
			if fields.r then 
				local r = tonumber(fields.r) or 0;
				if r > 10 and not privs.privs then return end
				meta:set_int("r", r) 
			end
			if fields.g then 
				local g = tonumber(fields.g) or 1;
				if (g<0.1 or g>40) and not privs.privs then return end
				meta:set_float("g", g) 
			end
			if fields.speed then 
				local speed = tonumber(fields.speed) or 1;
				if (speed>1 or speed < 0) and not privs.privs then return end
				meta:set_float("speed", speed) 
			end
			if fields.jump then 
				local jump = tonumber(fields.jump) or 1;
				if (jump<0 or jump>2) and not privs.privs then return end
				meta:set_float("jump", jump) 
			end
			if fields.sneak then 
				meta:set_int("sneak", tonumber(fields.sneak) or 0) 
			end
			
		
			enviro_update_form(pos);
		end
	end
})



-- DEFAULT (SPAWN) PHYSICS VALUE/SKYBOX

local reset_player_physics = function(player)
	if player then
		player:set_physics_override({speed=1,jump=0.6,gravity=0.2,sneak=true}) -- value set for extreme test space spawn
		local skybox = enviro.skyboxes["space"]; -- default skybox is "default"
		player:set_sky(0,skybox["type"],skybox["tex"]);
	end
end

-- globally available function
enviro_adjust_physics = function(player) -- adjust players physics/skybox 1 second after various events
	minetest.after(1, function()
		if player then
			local pos = player:getpos(); if not pos then return end
			if pos.y > 9000 then -- is player in space or not?
				player:set_physics_override({speed=1,jump=0.6,gravity=0.2,sneak=true}) -- value set for extreme test space spawn
				local skybox = enviro.skyboxes["space"];
				player:set_sky(0,skybox["type"],skybox["tex"]);
			else
				player:set_physics_override({speed=1,jump=1,gravity=1,sneak=true}) -- value set for extreme test space spawn
				local skybox = enviro.skyboxes["default"];
				player:set_sky(0,skybox["type"],skybox["tex"]);
			end
		end
	end)
end






-- restore default values/skybox on respawn of player
minetest.register_on_respawnplayer(reset_player_physics)

-- when player joins, check where he is and adjust settings
minetest.register_on_joinplayer(enviro_adjust_physics)


-- INSERT SIMILIAR CODE IN ALL EVENTS THAT CHANGE POSITIONS LIKE /spawn


-- RECIPE: extremely expensive

minetest.register_craft({
	output = "basic_machines:enviro",
	recipe = {
		{"basic_machines:generator", "basic_machines:clockgen","basic_machines:generator"},
		{"basic_machines:generator", "basic_machines:generator","basic_machines:generator"},
		{"basic_machines:generator", "basic_machines:generator", "basic_machines:generator"}
	}
})