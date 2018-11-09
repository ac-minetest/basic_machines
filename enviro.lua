-- ENVIRO block: change physics and skybox for players
-- note: nonadmin players are limited in changes ( cant change skybox and have limits on other allowed changes)

-- rnd 2016:

local enviro = {};
enviro.skyboxes = {
	["default"]={type = "regular", tex = {}}, 
	--["space"]={type="skybox", tex={"sky_pos_y.jpg","sky_neg_y.jpg","sky_pos_z.jpg","sky_neg_z.jpg","sky_neg_x.jpg","sky_pos_x.jpg",}}, -- need textures installed!
	["space"]={type="skybox", tex={"basic_machines_stars.png","basic_machines_stars.png","basic_machines_stars.png","basic_machines_stars.png","basic_machines_stars.png","basic_machines_stars.png",}}, -- need textures installed!
	["caves"]={type = "cavebox", tex = {"black.png","black.png","black.png","black.png","black.png","black.png",}},
	};
	
local space_start = 1100;
local ENABLE_SPACE_EFFECTS = false -- enable damage outside protected areas
	
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
		local list_name = "nodemeta:"..pos.x..','..pos.y..','..pos.z;
		
		local form  = 
			"size[8,8.5]"..	-- width, height
			"field[0.25,0.5;1,1;x0;target;"..x0.."] field[1.25,0.5;1,1;y0;;"..y0.."] field[2.25,0.5;1,1;z0;;"..z0.."]"..
			"field[3.25,0.5;1,1;r;radius;"..r.."]"..
			--speed, jump, gravity,sneak
			"field[0.25,1.5;1,1;speed;speed;"..speed.."]"..
			"field[1.25,1.5;1,1;jump;jump;"..jump.."]"..
			"field[2.25,1.5;1,1;g;gravity;"..g.."]"..
			"field[3.25,1.5;1,1;sneak;sneak;"..sneak.."]"..
			"label[0.,3.0;Skybox selection]"..
			"dropdown[0.,3.35;3,1;skybox;"..skylist..";"..sky_ind.."]"..
			"button_exit[3.25,3.25;1,1;OK;OK]"..
			"list["..list_name..";fuel;3.25,2.25;1,1;]"..
			"list[current_player;main;0,4.5;8,4;]"..
			"listring[current_player;main]"..
			"listring["..list_name..";fuel]"..
			"listring[current_player;main]"
		meta:set_string("formspec",form)
end
	
-- enviroment changer
minetest.register_node("basic_machines:enviro", {
	description = "Changes enviroment for players around target location",
	tiles = {"enviro.png"},
	drawtype = "allfaces",
	paramtype = "light",
	param1=1,
	groups = {cracky=3, mesecon_effector_on = 1},
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
		if privs.machines then meta:set_int("machines",1) end

		local inv = meta:get_inventory();
		inv:set_size("fuel",1*1);
		
		enviro_update_form(pos);
	end,
		
	mesecons = {effector = { 
		action_on = function (pos, node,ttl) 
			local meta = minetest.get_meta(pos);
			local machines = meta:get_int("machines");
			if not machines == 1 then meta:set_string("infotext","Error. You need machines privs.") return end
			
			local admin = meta:get_int("admin");
			
			local inv = meta:get_inventory(); local stack = ItemStack("default:diamond 1");
			
			if inv:contains_item("fuel", stack) then
				inv:remove_item("fuel", stack);
			else
				meta:set_string("infotext","Error. Insert diamond in fuel inventory") 
				return
			end
			
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
			
			-- attempt to set acceleration to balls, if any around
			local objects =  minetest.get_objects_inside_radius(pos, r)
			
			for _,obj in pairs(objects) do
				if obj:get_luaentity() then
					local obj_name = obj:get_luaentity().name or ""
					if obj_name == "basic_machines:ball" then
						obj:setacceleration({x=0,y=-g,z=0});
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
	end,
	
	allow_metadata_inventory_take = function(pos, listname, index, stack, player)
		local meta = minetest.get_meta(pos);
		local privs = minetest.get_player_privs(player:get_player_name());
		if meta:get_string("owner")~=player:get_player_name() and not privs.privs then return 0 end
		return stack:get_count();
	end,
	
	allow_metadata_inventory_put = function(pos, listname, index, stack, player)
		local meta = minetest.get_meta(pos);
		local privs = minetest.get_player_privs(player:get_player_name());
		if meta:get_string("owner")~=player:get_player_name() and not privs.privs then return 0 end
		return stack:get_count();
	end,
		
	can_dig = function(pos, player) -- dont dig if fuel is inside, cause it will be destroyed
		local meta = minetest.get_meta(pos);
		local inv = meta:get_inventory();
		return inv:is_empty("fuel")
	end,
	
})


-- DEFAULT (SPAWN) PHYSICS VALUE/SKYBOX

local reset_player_physics = function(player)
	if player then
		player:set_physics_override({speed=1,jump=1,gravity=1}) -- value set for extreme test space spawn
		local skybox = enviro.skyboxes["default"]; -- default skybox is "default"
		player:set_sky(0,skybox["type"],skybox["tex"]);
	end
end

-- globally available function
enviro_adjust_physics = function(player) -- adjust players physics/skybox 1 second after various events
	minetest.after(1, function()
		if player then
			local pos = player:getpos(); if not pos then return end
			if pos.y > space_start then -- is player in space or not?
				player:set_physics_override({speed=1,jump=0.5,gravity=0.1}) -- value set for extreme test space spawn
				local skybox = enviro.skyboxes["space"];
				player:set_sky(0,skybox["type"],skybox["tex"]);
			else
				player:set_physics_override({speed=1,jump=1,gravity=1}) -- value set for extreme test space spawn
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


-- SERVER GLOBAL SPACE CODE: uncomment to enable it

local round = math.floor;
local protector_position = function(pos) 
	local r = 20;
	local ry = 2*r;
	return {x=round(pos.x/r+0.5)*r,y=round(pos.y/ry+0.5)*ry,z=round(pos.z/r+0.5)*r};
end

local stimer = 0
local enviro_space = {};
minetest.register_globalstep(function(dtime)
	stimer = stimer + dtime;
	if stimer >= 5 then
		stimer = 0;
		local players = minetest.get_connected_players();
		for _,player in pairs(players) do
			local name = player:get_player_name();
			local pos = player:getpos();
			local inspace=0; if pos.y>space_start then inspace = 1 end
			local inspace0=enviro_space[name];
			if inspace~=inspace0 then -- only adjust player enviroment ONLY if change occured ( earth->space or space->earth !)
				enviro_space[name] = inspace;
				enviro_adjust_physics(player);
			end
			
			if ENABLE_SPACE_EFFECTS and inspace==1 then -- special space code
				
					
					if pos.y<1500 and pos.y>1120 then
						local hp = player:get_hp();
						
						if hp>0 then
							minetest.chat_send_player(name,"WARNING: you entered DEADLY RADIATION ZONE");
							local privs = minetest.get_player_privs(name)
							if not privs.kick then player:set_hp(hp-15) end
						end
						return
					else
					
						local ppos = protector_position(pos);
						local populated = (minetest.get_node(ppos).name=="basic_protect:protector");
						if populated then 
							if minetest.get_meta(ppos):get_int("space") == 1 then populated = false end
						end
						
						if not populated then -- do damage if player found not close to protectors
							local hp = player:get_hp();
							local privs = minetest.get_player_privs(name);
							if hp>0 and not privs.kick then
								player:set_hp(hp-10); -- dead in 20/10 = 2 events
								minetest.chat_send_player(name,"WARNING: in space you must stay close to spawn or protected areas");
							end
						end
					end
			
			end
		end
	end
end)

-- END OF SPACE CODE


-- AIR EXPERIMENT
-- minetest.register_node("basic_machines:air", {
	-- description = "enables breathing in space",
	-- drawtype = "liquid",
	-- tiles =  {"default_water_source_animated.png"},
	
	-- drawtype = "glasslike",
	-- paramtype = "light",
	-- alpha =  150,
	-- sunlight_propagates = true, -- Sunlight shines through
	-- walkable     = false, -- Would make the player collide with the air node
	-- pointable    = false, -- You can't select the node
	-- diggable     = false, -- You can't dig the node
	-- buildable_to = true,
	-- drop = "",
	-- groups = {not_in_creative_inventory=1},
	-- after_place_node = function(pos, placer, itemstack, pointed_thing) 
		-- local r = 3;
		-- for i = -r,r do
			-- for j = -r,r do
				-- for k = -r,r do
					-- local p = {x=pos.x+i,y=pos.y+j,z=pos.z+k};
					-- if minetest.get_node(p).name == "air" then
						-- minetest.set_node(p,{name = "basic_machines:air"})
					-- end
				-- end
			-- end
		-- end
	-- end
	
-- })

-- minetest.register_abm({ 
	-- nodenames = {"basic_machines:air"},
	-- neighbors = {"air"},
	-- interval = 10,
	-- chance = 1,
	-- action = function(pos, node, active_object_count, active_object_count_wider)
			-- minetest.set_node(pos,{name = "air"})
		-- end
	-- });

	
minetest.register_on_punchplayer( -- bring gravity closer to normal with each punch
	function(player, hitter, time_from_last_punch, tool_capabilities, dir, damage)
	
		if player:get_physics_override() == nil then return end
		local pos = player:getpos(); if pos.y>= space_start then return end
		
		local gravity = player:get_physics_override().gravity;
		if gravity<1 then
			gravity = 1;
			player:set_physics_override({gravity=gravity})
		end
	end
	
)

	

-- RECIPE: extremely expensive

-- minetest.register_craft({
	-- output = "basic_machines:enviro",
	-- recipe = {
		-- {"basic_machines:generator", "basic_machines:clockgen","basic_machines:generator"},
		-- {"basic_machines:generator", "basic_machines:generator","basic_machines:generator"},
		-- {"basic_machines:generator", "basic_machines:generator", "basic_machines:generator"}
	-- }
-- })