-- BALL: energy ball that flies around, can bounce and activate stuff
-- rnd 2016:

local function round(x)
	if x < 0 then 
		return -math.floor(-x+0.5);
	else 
		return math.floor(x+0.5);
	end
end


local ball_spawner_update_form = function (pos)
	
		local meta = minetest.get_meta(pos);
		local x0,y0,z0;
		x0=meta:get_int("x0");y0=meta:get_int("y0");z0=meta:get_int("z0"); -- direction of velocity
		
		local energy,bounce,g,puncheable;
		local speed = meta:get_float("speed"); -- if positive sets initial ball speed
		energy = meta:get_float("energy"); -- if positive activates, negative deactivates, 0 does nothing
		bounce = meta:get_int("bounce"); -- if nonzero bounces when hit obstacle, 0 gets absorbed
		gravity = meta:get_float("gravity");  -- gravity
		puncheable = meta:get_int("puncheable"); -- if 1 can be punched by players in protection, if 2 can be punched by anyone
		local form  = 
		"size[4.25,3.75]" ..  -- width, height
		"field[0.25,0.5;1,1;x0;target;"..x0.."] field[1.25,0.5;1,1;y0;;"..y0.."] field[2.25,0.5;1,1;z0;;"..z0.."]"..
		"field[3.25,0.5;1,1;speed;speed;"..speed.."]"..
		--speed, jump, gravity,sneak
		"field[0.25,1.5;1,1;energy;energy;"..energy.."]"..
		"field[1.25,1.5;1,1;bounce;bounce;".. bounce.."]"..
		"field[2.25,1.5;1,1;gravity;gravity;"..gravity.."]"..
		"field[3.25,1.5;1,1;puncheable;puncheable;"..puncheable.."]"..
		"button_exit[3.25,3.25;1,1;OK;OK]";
		meta:set_string("formspec",form);

end



minetest.register_entity("basic_machines:ball",{
	timer = 0, 
	lifetime = 20, -- how long it exists before disappearing
	energy = 1, -- if negative it will deactivate stuff, positive will activate, 0 wont do anything
	puncheable = 1, -- can be punched by players in protection
	bounce = 0, -- 0: absorbs in block, 1 = proper bounce=lag buggy, -- to do: 2 = line of sight bounce
	gravity = 0,
	speed = 5, -- velocity when punched
	owner = "",
	origin = {x=0,y=0,z=0},
	hp_max = 100,
	elasticity = 0.8, -- speed gets multiplied by this after bounce
	visual="sprite",
	visual_size={x=.6,y=.6},
	collisionbox = {-0.5,-0.5,-0.5, 0.5,0.5,0.5},
	physical=false,

	--textures={"basic_machines_ball"},
		on_punch=function(self, puncher, time_from_last_punch, tool_capabilities, dir) -- ball is punched
			
		end,
	on_activate = function(self, staticdata)
		self.object:set_properties({textures={"basic_machines_ball.png"}})
		self.timer = 0;self.owner = "";
		self.origin = self.object:getpos();
	end,
	
	on_punch = function (self, puncher, time_from_last_punch, tool_capabilities, dir)
		if self.puncheable == 0 then return end
		if self.puncheable == 1 then -- only those in protection
			local name = puncher:get_player_name();
			local pos = self.object:getpos();
			if minetest.is_protected(pos,name) then return end
		end
		--minetest.chat_send_all(minetest.pos_to_string(dir))
		if time_from_last_punch<0.5 then return end
		local v = self.speed or 1;
		
		local velocity = dir; 
		velocity.x = velocity.x*v;velocity.y = velocity.y*v;velocity.z = velocity.z*v;
		self.object:setvelocity(velocity)
	end,
	
	on_step = function(self, dtime)
		self.timer=self.timer+dtime
		if self.timer>self.lifetime then 
			self.object:remove()
			return 
		end
		
		local pos=self.object:getpos()
		
		local origin = self.origin;
		
		local r = 30;-- maximal distance when balls disappear
                local dist = math.max(math.abs(pos.x-origin.x), math.abs(pos.y-origin.y), math.abs(pos.z-origin.z));
		if dist>r then -- remove if it goes too far
			self.object:remove() 
			return 
		end
		
		local nodename = minetest.get_node(pos).name;
		local walkable = false;
		if nodename ~= "air" then 
			walkable = minetest.registered_nodes[nodename].walkable;
                        if nodename == "basic_machines:ball_spawner" and dist>1 then walkable = true end -- ball can activate spawner, just not originating one
		end

		if walkable then -- we hit a node
			--minetest.chat_send_all(" hit node at " .. minetest.pos_to_string(pos))
			
			local node = minetest.get_node(pos);
			local table = minetest.registered_nodes[node.name];
			if table and table.mesecons and table.mesecons.effector then -- activate target
				self.object:remove();
				if minetest.is_protected(pos,self.owner) then return end
				local effector = table.mesecons.effector;
				if self.energy>0 then
					if not effector.action_on then return end
					effector.action_on(pos,node,16); 
				elseif self.energy<0 then
					if not effector.action_off then return end
					effector.action_off(pos,node,16); 
				end
				
			else -- bounce ( copyright rnd, 2016 )
				local bounce = self.bounce;
				if self.bounce == 0 then self.object:remove() return end
				
				local n = {x=0,y=1,z=0}; -- this will be bouncen ormal
				local v = self.object:getvelocity();
				local opos = {x=round(pos.x),y=round(pos.y), z=round(pos.z)}; -- obstacle
				local bpos ={ x=(pos.x-opos.x),y=(pos.y-opos.y),z=(pos.z-opos.z)}; -- boundary position on cube, approximate
				
				if bounce == 2 then -- uses special blocks for exact bouncing: dirt, glass: bounces up/down
					if node.name == "default:dirt_with_grass" then 
						if bpos.y<0 then n.y = -1 else n.y = 1 end
					elseif node.name == "default:glass" then 
						if bpos.y<0 then n.y = -1 else n.y = 1 end
					elseif node.name == "default:wood" then 
						if bpos.z<0 then n.z = -1 else n.z = 1 end
						n.y = 0;
					elseif node.name == "default:junglewood" then 
						if bpos.x<0 then n.x = -1 else n.x = 1 end
						n.y = 0;
					end
				else -- normal bounce..
					
					-- try to determine exact point of entry 
					local vm = math.sqrt(v.x*v.x+v.y*v.y+v.z*v.z); if vm == 0 then vm = 1 end
					local vn = {x=-v.x/vm,y=-v.y/vm, z= -v.z/vm};
					
					local t1=2; local t2 = 2; local t3 = 2;
					local t0;
					-- calculate intersections with cube faces
					t0=0.5;if bpos.x<0 then t0 = -0.5 end;if vn.x~=0 then t1 = (t0-bpos.x)/vn.x end 
					t0=0.5;if bpos.y<0 then t0 = -0.5 end;if vn.y~=0 then t2 = (t0-bpos.y)/vn.y end
					t0=0.5;if bpos.z<0 then t0 = -0.5 end;if vn.z~=0 then t3 = (t0-bpos.z)/vn.z end
					if t1<0 then t1 = 2 end;if t2<0 then t2 = 2 end; if t3<0 then t3 = 2 end
					local t = math.min(t1,t2,t3); 

					-- fixed: entry point
					bpos.x = bpos.x + t*vn.x+opos.x;
					bpos.y = bpos.y + t*vn.y+opos.y;
					bpos.z = bpos.z + t*vn.z+opos.z;
					
					if t<0 or t>1 then 
						t=-0.5; v.x=0;v.y=0;v.z=0;
						self.object:remove() 
					end -- FAILED! go little back and stop
					
					-- attempt to determine direction
					local dpos = { x=(bpos.x-opos.x),y=(bpos.y-opos.y),z=(bpos.z-opos.z)};
					local dposa = { x=math.abs(dpos.x),y=math.abs(dpos.y),z=math.abs(dpos.z)};
					local maxo = math.max(dposa.x,dposa.y,dposa.z);
					
					if dposa.x == maxo then
						if dpos.x>0 then n.x = 1 else n.x = -1 end 
					elseif dposa.y == maxo then
						if dpos.y>0 then n.y = 1 else n.y = -1 end
					else
						if dpos.z>0 then n.z = 1 else n.z = -1 end
					end
					
					--verify normal
					nodename=minetest.get_node({x=opos.x+n.x,y=opos.y+n.y,z=opos.z+n.z}).name
					walkable = false;
					if nodename ~= "air" then 
						walkable = minetest.registered_nodes[nodename].walkable;
					end
					if walkable then -- problem, nonempty node - incorrect normal, fix it
						if n.x ~=0 then  
							n.x=0; 
							if dpos.y>0 then n.y = 1 else n.y = -1 end 
						else
							if dpos.x>0 then n.x = 1 else n.x = -1 end ; n.y = 0;
						end
					end 
				end
				
				local elasticity = self.elasticity;
				
				
				-- bounce
				if n.x~=0 then 
					v.x=-elasticity*v.x 
				elseif n.y~=0 then 
					v.y=-elasticity*v.y 
				elseif n.z~=0 then
					v.z=-elasticity*v.z				
				end
				
				local r = 0.2
				bpos = {x=pos.x+n.x*r,y=pos.y+n.y*r,z=pos.z+n.z*r}; -- point placed a bit further away from box
				self.object:setpos(bpos) -- place object fixed point
				
				self.object:setvelocity(v);
				
				minetest.sound_play("default_dig_cracky", {pos=pos,gain=1.0,max_hear_distance = 8,})
				
			end
			
			return
		end
	end,
})


minetest.register_node("basic_machines:ball_spawner", {
	description = "Spawns energy ball one block above",
	tiles = {"basic_machines_ball.png"},
	groups = {oddly_breakable_by_hand=2,mesecon_effector_on = 1},
	drawtype = "allfaces",
	paramtype = "light",
	param1=1,
	walkable = false,
	alpha = 150,
	sounds = default.node_sound_wood_defaults(),
	after_place_node = function(pos, placer)
		local meta = minetest.env:get_meta(pos)
		meta:set_string("owner", placer:get_player_name()); 
		
		meta:set_float("speed",5); -- if positive sets initial ball speed
		meta:set_float("energy",1); -- if positive activates, negative deactivates, 0 does nothing
		meta:set_int("bounce",0); -- if nonzero bounces when hit obstacle, 0 gets absorbed
		meta:set_float("gravity",0);  -- gravity
		meta:set_int("puncheable",0); -- if 0 not puncheable, if 1 can be punched by players in protection, if 2 can be punched by anyone
		ball_spawner_update_form(pos);
		
	end,

	mesecons = {effector = {
		action_on = function (pos, node,ttl) 
			if ttl<0 then return end
			
			local meta = minetest.get_meta(pos);
			local t0 = meta:get_int("t");
			local t1 = minetest.get_gametime(); 
			local T = meta:get_int("T"); -- temperature
			
			if t0>t1-3 then -- activated before natural time
				T=T+1;
			else
				if T>0 then T=T-1 end
			end
			meta:set_int("T",T);
			meta:set_int("t",t1); -- update last activation time
			
			if T > 2 then -- overheat
					minetest.sound_play("default_cool_lava",{pos = pos, max_hear_distance = 16, gain = 0.25})
					meta:set_string("infotext","overheat: temperature ".. T)
					return
			end
			
			
			local obj = minetest.add_entity({x=pos.x,y=pos.y,z=pos.z}, "basic_machines:ball");
			local luaent = obj:get_luaentity();
			local meta = minetest.get_meta(pos);
			
			local speed,energy,bounce,gravity,puncheable;
			speed = meta:get_float("speed");
			energy = meta:get_float("energy"); -- if positive activates, negative deactivates, 0 does nothing
			bounce = meta:get_int("bounce"); -- if nonzero bounces when hit obstacle, 0 gets absorbed
			gravity = meta:get_float("gravity");  -- gravity
			puncheable = meta:get_int("puncheable"); -- if 1 can be punched by players in protection, if 2 can be punched by anyone
			
			if energy<0 then
				obj:set_properties({textures={"basic_machines_ball.png^[colorize:blue:120"}})
			end
			
			luaent.bounce = bounce;
			luaent.energy = energy;
			if gravity>0 then
				obj:setacceleration({x=0,y=-gravity,z=0});
			end
			luaent.puncheable = puncheable;
			
			local x0,y0,z0;
			x0=meta:get_int("x0");y0=meta:get_int("y0");z0=meta:get_int("z0"); -- direction of velocity
			if speed~=0 and (x0~=0 or y0~=0 or z0~=0) then -- set velocity direction
				local velocity = {x=x0,y=y0,z=z0};
				local v = math.sqrt(velocity.x^2+velocity.y^2+velocity.z^2); if v == 0 then v = 1 end
				v = v / speed;
				velocity.x=velocity.x/v;velocity.y=velocity.y/v;velocity.z=velocity.z/v;
				obj:setvelocity(velocity);
			end
			
			
		end,
		
		action_off = function (pos, node,ttl) 
			if ttl<0 then return end
			local obj = minetest.add_entity({x=pos.x,y=pos.y,z=pos.z}, "basic_machines:ball");
			local luaent = obj:get_luaentity();
			luaent.energy = -1;
			obj:set_properties({textures={"basic_machines_ball.png^[colorize:blue:120"}})
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
			
			local speed,energy,bounce,g,puncheable;
			energy = meta:get_float("energy"); -- if positive activates, negative deactivates, 0 does nothing
			bounce = meta:get_int("bounce"); -- if nonzero bounces when hit obstacle, 0 gets absorbed
			gravity = meta:get_float("gravity");  -- gravity
			puncheable = meta:get_int("puncheable"); -- if 1 can be punched by players in protection, if 2 can be punched by anyone
			
			
			if fields.speed then 
				local speed = tonumber(fields.speed) or 0;
				if (speed > 10 or speed < 0) and not privs.privs then return end
				meta:set_float("speed", speed) 
			end
			
			if fields.energy then 
				local energy = tonumber(fields.energy) or 1;
				meta:set_float("energy", energy) 
			end
			
			if fields.bounce then 
				local bounce = tonumber(fields.bounce) or 1;
				meta:set_int("bounce",bounce) 
			end
			
			if fields.gravity then 
				local gravity = tonumber(fields.gravity) or 1;
				if (gravity<0 or gravity>30) and not privs.privs then return end
				meta:set_float("gravity", gravity) 
			end
			if fields.puncheable then 
				meta:set_int("puncheable", tonumber(fields.puncheable) or 0) 
			end
		
			ball_spawner_update_form(pos);
		end
	end
	
})


minetest.register_craft({
	output = "basic_machines:ball_spawner",
	recipe = {
		{"basic_machines:power_cell"},
		{"basic_machines:keypad"}
	}
})