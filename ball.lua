-- BALL: energy ball that flies around, can bounce and activate stuff
-- rnd 2016:

-- TO DO: move mode: ball just rolling around on ground without hopping, also if inside slope it would "roll down", just increased velocity in slope direction

-- SETTINGS

basic_machines.ball = {};
basic_machines.ball.maxdamage  =  10;  -- player health 20
basic_machines.ball.bounce_materials = { -- to be used with bounce setting 2 in ball spawner: 1: bounce in x direction, 2: bounce in z direction, otherwise it bounces in y direction
["default:wood"]=1,
["xpanes:bar_2"]=1,
["xpanes:bar_10"]=1,
["darkage:iron_bars"]=1,
["default:glass"] = 2,
};

-- END OF SETTINGS

local ballcount = {};
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
		
		local energy,bounce,g,puncheable, gravity,hp,hurt,solid;
		local speed = meta:get_float("speed"); -- if positive sets initial ball speed
		energy = meta:get_float("energy"); -- if positive activates, negative deactivates, 0 does nothing
		bounce = meta:get_int("bounce"); -- if nonzero bounces when hit obstacle, 0 gets absorbed
		gravity = meta:get_float("gravity");  -- gravity
		hp = meta:get_float("hp");
		hurt = meta:get_float("hurt");
		puncheable = meta:get_int("puncheable"); -- if 1 can be punched by players in protection, if 2 can be punched by anyone
		solid = meta:get_int("solid"); -- if 1 then entity is solid - cant be walked on
		
		local texture = meta:get_string("texture") or  "basic_machines_ball.png";
		local visual = meta:get_string("visual") or "sprite";
		local scale =  meta:get_int("scale");
		
		local form  = 
		"size[4.25,4.75]" ..  -- width, height
		"field[0.25,0.5;1,1;x0;target;"..x0.."] field[1.25,0.5;1,1;y0;;"..y0.."] field[2.25,0.5;1,1;z0;;"..z0.."]"..
		"field[3.25,0.5;1,1;speed;speed;"..speed.."]"..
		--speed, jump, gravity,sneak
		"field[0.25,1.5;1,1;energy;energy;"..energy.."]"..
		"field[1.25,1.5;1,1;bounce;bounce;".. bounce.."]"..
		"field[2.25,1.5;1,1;gravity;gravity;"..gravity.."]"..
		"field[3.25,1.5;1,1;puncheable;puncheable;"..puncheable.."]"..
		"field[3.25,2.5;1,1;solid;solid;"..solid.."]"..
		"field[0.25,2.5;1,1;hp;hp;"..hp.."]".."field[1.25,2.5;1,1;hurt;hurt;"..hurt.."]"..
		"field[0.25,3.5;4,1;texture;texture;"..minetest.formspec_escape(texture).."]"..
		"field[0.25,4.5;1,1;scale;scale;"..scale.."]".."field[1.25,4.5;1,1;visual;visual;"..visual.."]"..
		"button_exit[3.25,4.25;1,1;OK;OK]";
		
		
		
		if meta:get_int("admin")==1 then 
			local lifetime = meta:get_int("lifetime");
			if lifetime <= 0 then lifetime = 20 end
			form = form .. "field[2.25,2.5;1,1;lifetime;lifetime;"..lifetime.."]"
		end
		
		meta:set_string("formspec",form);

end



minetest.register_entity("basic_machines:ball",{
	timer = 0, 
	lifetime = 20, -- how long it exists before disappearing
	energy = 0, -- if negative it will deactivate stuff, positive will activate, 0 wont do anything
	puncheable = 1, -- can be punched by players in protection
	bounce = 0, -- 0: absorbs in block, 1 = proper bounce=lag buggy, -- to do: 2 = line of sight bounce
	gravity = 0,
	speed = 5, -- velocity when punched
	hurt = 0, -- how much damage it does to target entity, if 0 damage disabled
	owner = "",
	state = false,
	origin = {x=0,y=0,z=0},
	lastpos = {x=0,y=0,z=0}, -- last not-colliding position
	hp_max = 100,
	elasticity = 0.9, -- speed gets multiplied by this after bounce
	visual="sprite",
	visual_size={x=.6,y=.6},
	collisionbox = {-0.5,-0.5,-0.5, 0.5,0.5,0.5},
	physical=false,

	--textures={"basic_machines_ball"},
		
	on_activate = function(self, staticdata)
		self.object:set_properties({textures={"basic_machines_ball.png"}})
		self.object:set_properties({visual_size = {x=1, y=1}});
		self.timer = 0;self.owner = "";
		self.origin = self.object:getpos();
		self.lifetime = 20;
	end,
	
	get_staticdata = function(self) -- this gets called before object put in world and before it hides
		if not self.state then return nil end
		self.object:remove();
		return nil
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
			local count = ballcount[self.owner] or 1; count=count-1; ballcount[self.owner] = count; 
			self.object:remove()
			return 
		end
		
		if not self.state then self.state = true end
		local pos=self.object:getpos()
		
		local origin = self.origin;
		
		local r = 30;-- maximal distance when balls disappear
                local dist = math.max(math.abs(pos.x-origin.x), math.abs(pos.y-origin.y), math.abs(pos.z-origin.z));
		if dist>r then -- remove if it goes too far
			local count = ballcount[self.owner] or 1; count=count-1; ballcount[self.owner] = count; 
			self.object:remove() 
			return 
		end
		
		local nodename = minetest.get_node(pos).name;
		local walkable = false;
		if nodename ~= "air" then 
			walkable = minetest.registered_nodes[nodename].walkable;
                        if nodename == "basic_machines:ball_spawner" and dist>0.5 then walkable = true end -- ball can activate spawner, just not originating one
		end
		if not walkable then 
			self.lastpos = pos 
			if self.hurt~=0 then -- check for coliding nearby objects
				local objects = minetest.get_objects_inside_radius(pos,2);
				if #objects>1 then
					for _, obj in pairs(objects) do
						local p = obj:getpos();
						local d = math.sqrt((p.x-pos.x)^2+(p.y-pos.y)^2+(p.z-pos.z)^2);
						if d>0 then

							--if minetest.is_protected(p,self.owner) then return end
							if math.abs(p.x)<32 and math.abs(p.y)<32 and math.abs(p.z)<32 then return end -- no damage around spawn
							
							if obj:is_player() then --player
								if obj:get_player_name()==self.owner then break end -- dont hurt owner
							
								local hp = obj:get_hp()
								local newhp = hp-self.hurt;
								if newhp<=0 and boneworld and boneworld.killxp then
									local killxp =  boneworld.killxp[self.owner];
									if killxp then
										boneworld.killxp[self.owner] = killxp + 0.01;
									end
								end
								obj:set_hp(newhp)
							else -- non player
								local lua_entity = obj:get_luaentity();
								if lua_entity and lua_entity.itemstring then
									local entname = lua_entity.itemstring;
									if entname == "robot" then 
										self.object:remove()
										return;
									end
								end
								local hp = obj:get_hp()
								local newhp = hp-self.hurt;
								minetest.chat_send_player(self.owner,"#ball: target hp " .. newhp)
								if newhp<=0 then obj:remove() else obj:set_hp(newhp) end
							end
							
							
							
							
							local count = ballcount[self.owner] or 1; count=count-1; ballcount[self.owner] = count; 
							self.object:remove(); 
							return
						end
					end
				end
			end
		end
		
		
		if walkable then -- we hit a node
			--minetest.chat_send_all(" hit node at " .. minetest.pos_to_string(pos))
			
			
			local node = minetest.get_node(pos);
			local table = minetest.registered_nodes[node.name];
			if table and table.effector then -- activate target

				local energy = self.energy;
				if energy~=0 then
					if minetest.is_protected(pos,self.owner) then return end
				end
				local effector = table.effector;
				
				local count = ballcount[self.owner] or 1; count=count-1; ballcount[self.owner] = count; 
				self.object:remove();
				
				if energy>0 then
					if not effector.action_on then return end
					effector.action_on(pos,node,16); 
				elseif energy<0 then
					if not effector.action_off then return end
					effector.action_off(pos,node,16); 
				end
				
				
			else -- bounce ( copyright rnd, 2016 )
				local bounce = self.bounce;
				if self.bounce == 0 then 
					local count = ballcount[self.owner] or 1; count=count-1; ballcount[self.owner] = count; 
					self.object:remove() 
				return end
				
				local n = {x=0,y=0,z=0}; -- this will be bounce normal
				local v = self.object:getvelocity();
				local opos = {x=round(pos.x),y=round(pos.y), z=round(pos.z)}; -- obstacle
				local bpos ={ x=(pos.x-opos.x),y=(pos.y-opos.y),z=(pos.z-opos.z)}; -- boundary position on cube, approximate
				
				if bounce == 2 then -- uses special blocks for non buggy lag proof bouncing: by default it bounces in y direction
					local bounce_direction = basic_machines.ball.bounce_materials[node.name] or 0;
					
					if bounce_direction == 0 then 
						if v.y>=0 then n.y = -1 else n.y = 1 end
					elseif bounce_direction == 1 then 
						if v.x>=0 then n.x = -1 else n.x = 1 end
						n.y = 0;
					elseif bounce_direction == 2 then 
						if v.z>=0 then n.z = -1 else n.z = 1 end
						n.y = 0;
					end
				
				else -- algorithm to determine bounce direction - problem: with lag its impossible to determine reliable which node was hit and which face ..

					if v.x<=0 then n.x = 1 else n.x = -1 end -- possible bounce directions
					if v.y<=0 then n.y = 1 else n.y = -1 end 
					if v.z<=0 then n.z = 1 else n.z = -1 end
					
					local dpos = {};
				
					dpos.x = 0.5*n.x; dpos.y = 0; dpos.z = 0; -- calculate distance to bounding surface midpoints
					
					local d1 = (bpos.x-dpos.x)^2 + (bpos.y)^2 + (bpos.z)^2;
					dpos.x = 0; dpos.y = 0.5*n.y; dpos.z = 0;
					local d2 = (bpos.x)^2 + (bpos.y-dpos.y)^2 + (bpos.z)^2;
					dpos.x = 0; dpos.y = 0; dpos.z = 0.5*n.z;
					local d3 = (bpos.x)^2 + (bpos.y)^2 + (bpos.z-dpos.z)^2;
					local d = math.min(d1,d2,d3); -- we obtain bounce direction from minimal distance
					
					if d1==d then --x
						n.y=0;n.z=0 
					elseif d2==d then --y 
						n.x=0;n.z=0
					elseif d3==d then --z
						n.x=0;n.y=0
					end
					
					
					nodename=minetest.get_node({x=opos.x+n.x,y=opos.y+n.y,z=opos.z+n.z}).name -- verify normal
					walkable = nodename ~= "air";
					if walkable then -- problem, nonempty node - incorrect normal, fix it
						if n.x ~=0 then  -- x direction is wrong, try something else
							n.x=0; 
							if v.y>=0 then n.y = -1 else n.y = 1 end -- try y
							nodename=minetest.get_node({x=opos.x+n.x,y=opos.y+n.y,z=opos.z+n.z}).name -- verify normal
							walkable = nodename ~= "air";
							if walkable then -- still problem, only remaining is z
								n.y=0;
								if v.z>=0 then n.z = -1 else n.z = 1 end
								nodename=minetest.get_node({x=opos.x+n.x,y=opos.y+n.y,z=opos.z+n.z}).name -- verify normal
								walkable = nodename ~= "air";
								if walkable then -- messed up, just remove the ball
									self.object:remove()
									return
								end
								
							end

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
				self.object:setpos(bpos) -- place object at last known outside point
				
				self.object:setvelocity(v);
				
				minetest.sound_play("default_dig_cracky", {pos=pos,gain=1.0,max_hear_distance = 8,})
				
			end
		end
			return
	end,
})


minetest.register_node("basic_machines:ball_spawner", {
	description = "Spawns energy ball one block above",
	tiles = {"basic_machines_ball.png"},
	groups = {cracky=3},
	drawtype = "allfaces",
	paramtype = "light",
	param1=1,
	walkable = false,
	alpha = 150,
	sounds = default.node_sound_wood_defaults(),
	after_place_node = function(pos, placer)
		local meta = minetest.env:get_meta(pos)
		meta:set_string("owner", placer:get_player_name()); 
		local privs = minetest.get_player_privs(placer:get_player_name()); if privs.privs then meta:set_int("admin",1) end
		
		if privs.machines then meta:set_int("machines",1) end
		
		meta:set_float("hurt",0);
		meta:set_string("texture", "basic_machines_ball.png");
		meta:set_float("hp",100);
		meta:set_float("speed",5); -- if positive sets initial ball speed
		meta:set_float("energy",1); -- if positive activates, negative deactivates, 0 does nothing
		meta:set_int("bounce",0); -- if nonzero bounces when hit obstacle, 0 gets absorbed
		meta:set_float("gravity",0);  -- gravity
		meta:set_int("puncheable",0); -- if 0 not puncheable, if 1 can be punched by players in protection, if 2 can be punched by anyone
		meta:set_int("scale",100);
		meta:set_string("visual","sprite"); -- sprite/cube OR particle
		ball_spawner_update_form(pos);
		
	end,

	effector = {
		action_on = function (pos, node,ttl) 
			if type(ttl)~="number" then ttl = 1 end
			if ttl<0 then return end
			
			local meta = minetest.get_meta(pos);
			local t0 = meta:get_int("t");
			local t1 = minetest.get_gametime(); 
			local T = meta:get_int("T"); -- temperature
			
			if t0>t1-2 then -- activated before natural time
				T=T+1;
			else
				if T>0 then 
					T=T-1 
					if t1-t0>5 then T = 0 end
				end
			end
			meta:set_int("T",T);
			meta:set_int("t",t1); -- update last activation time
			
			if T > 2 then -- overheat
					minetest.sound_play("default_cool_lava",{pos = pos, max_hear_distance = 16, gain = 0.25})
					meta:set_string("infotext","overheat: temperature ".. T)
					return
			end

			if meta:get_int("machines")~=1 then -- no machines priv, limit ball count
				local owner = meta:get_string("owner");
				local count = ballcount[owner];
				if not count or count<0 then count = 0 end
				
				if count>=2 then 
					if t1-t0>10 then count = 0 
						else return 
					end
				end
				
				count = count + 1;
				ballcount[owner]=count;
				--minetest.chat_send_all("count " .. count);
			end
			
			pos.x = round(pos.x);pos.y = round(pos.y);pos.z = round(pos.z);
			local obj = minetest.add_entity({x=pos.x,y=pos.y,z=pos.z}, "basic_machines:ball");
			local luaent = obj:get_luaentity();
			local meta = minetest.get_meta(pos);
			
			local speed,energy,bounce,gravity,puncheable,solid;
			speed = meta:get_float("speed");
			energy = meta:get_float("energy"); -- if positive activates, negative deactivates, 0 does nothing
			bounce = meta:get_int("bounce"); -- if nonzero bounces when hit obstacle, 0 gets absorbed
			gravity = meta:get_float("gravity");  -- gravity
			puncheable = meta:get_int("puncheable"); -- if 1 can be punched by players in protection, if 2 can be punched by anyone
			solid = meta:get_int("solid");
			
			if energy<0 then
				obj:set_properties({textures={"basic_machines_ball.png^[colorize:blue:120"}})
			end
			
			luaent.bounce = bounce;
			luaent.energy = energy;
			if gravity>0 then
				obj:setacceleration({x=0,y=-gravity,z=0});
			end
			luaent.puncheable = puncheable;
			luaent.owner = meta:get_string("owner");
			luaent.hurt = meta:get_float("hurt");
			if solid==1 then 
				luaent.physical = true
			end
			
			obj:set_hp( meta:get_float("hp") );
			
			local x0,y0,z0;
			if speed>0 then luaent.speed = speed end
			
			x0=meta:get_int("x0");y0=meta:get_int("y0");z0=meta:get_int("z0"); -- direction of velocity
			if speed~=0 and (x0~=0 or y0~=0 or z0~=0) then -- set velocity direction
				local velocity = {x=x0,y=y0,z=z0};
				local v = math.sqrt(velocity.x^2+velocity.y^2+velocity.z^2); if v == 0 then v = 1 end
				v = v / speed;
				velocity.x=velocity.x/v;velocity.y=velocity.y/v;velocity.z=velocity.z/v;
				obj:setvelocity(velocity);
			end
			
			if meta:get_int("admin")==1 then 
				luaent.lifetime = meta:get_float("lifetime");
			end
			
			
			local visual = meta:get_string("visual")
			obj:set_properties({visual=visual});
			local texture = meta:get_string("texture");
			if visual=="sprite" then
				obj:set_properties({textures={texture}})
			elseif visual == "cube" then
				obj:set_properties({textures={texture,texture,texture,texture,texture,texture}})
			end
			local scale = meta:get_int("scale");if scale<=0 then scale = 1 else scale = scale/100 end
			obj:set_properties({visual_size = {x=scale, y=scale}});
			
			
			
		end,
		
		action_off = function (pos, node,ttl) 
			if type(ttl)~="number" then ttl = 1 end
			if ttl<0 then return end
			pos.x = round(pos.x);pos.y = round(pos.y);pos.z = round(pos.z);
			local obj = minetest.add_entity({x=pos.x,y=pos.y,z=pos.z}, "basic_machines:ball");
			local luaent = obj:get_luaentity();
			luaent.energy = -1;
			obj:set_properties({textures={"basic_machines_ball.png^[colorize:blue:120"}})
		end
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
			
			local speed,energy,bounce,gravity,puncheable,solid;
			energy = meta:get_float("energy"); -- if positive activates, negative deactivates, 0 does nothing
			bounce = meta:get_int("bounce"); -- if nonzero bounces when hit obstacle, 0 gets absorbed
			gravity = meta:get_float("gravity");  -- gravity
			puncheable = meta:get_int("puncheable"); -- if 1 can be punched by players in protection, if 2 can be punched by anyone
			solid = meta:get_int("solid");
			
			
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
			
			if fields.solid then 
				meta:set_int("solid", tonumber(fields.solid) or 0) 
			end
			
			if fields.lifetime then
				meta:set_int("lifetime", tonumber(fields.lifetime) or 0) 
			end
			
			if fields.hurt then
				meta:set_float("hurt", tonumber(fields.hurt) or 0) 
			end
			
			if fields.hp then
				meta:set_float("hp", math.abs(tonumber(fields.hp) or 0)) 
			end
			
			if fields.texture then
				meta:set_string ("texture", fields.texture);
			end
			
			if fields.scale then
				local scale = math.abs(tonumber(fields.scale) or 100);
				if scale>1000 and not privs.privs then scale = 1000 end
				meta:set_int("scale", scale) 
			end
			
			if fields.visual then
				local visual  = fields.visual or "";
				if visual~="sprite" and visual~="cube" then return end
				meta:set_string ("visual", fields.visual);
			end
		
			ball_spawner_update_form(pos);
		end
	end,
	
	after_dig_node = function(pos, oldnode, oldmetadata, digger)
		local name = digger:get_player_name();
		local inv = digger:get_inventory();
		inv:remove_item("main", ItemStack("basic_machines:ball_spawner"));
		local stack = ItemStack("basic_machines:ball_spell");
		local meta = oldmetadata["fields"];
		meta["formspec"]=nil;
		stack:set_metadata(minetest.serialize(meta));
		inv:add_item("main",stack);
	end
	
})


local spelltime = {};

-- ball as magic spell user can cast
minetest.register_tool("basic_machines:ball_spell", {
	description = "ball spawner",
	inventory_image = "basic_machines_ball.png",
	tool_capabilities = {
		full_punch_interval = 2,
		max_drop_level=0,
	},
	on_use = function(itemstack, user, pointed_thing)
		
		local pos = user:getpos();pos.y=pos.y+1;
		local meta = minetest.deserialize(itemstack:get_metadata());
		if not meta then return end
		local owner = meta["owner"] or "";
		
		--if minetest.is_protected(pos,owner) then return end
		
		local t0 = spelltime[owner] or 0;
		local t1 = minetest.get_gametime(); 
		if t1-t0<2 then return end -- too soon
		spelltime[owner]=t1;
		
		
		local obj = minetest.add_entity({x=pos.x,y=pos.y,z=pos.z}, "basic_machines:ball");
		local luaent = obj:get_luaentity();

		
		local speed,energy,bounce,gravity,puncheable;
		speed = tonumber(meta["speed"]) or 0;
		energy = tonumber(meta["energy"]) or 0; -- if positive activates, negative deactivates, 0 does nothing
		bounce = tonumber(meta["bounce"]) or 0; -- if nonzero bounces when hit obstacle, 0 gets absorbed
		gravity = tonumber(meta["gravity"]) or 0;  -- gravity
		puncheable = tonumber(meta["puncheable"]) or 0; -- if 1 can be punched by players in protection, if 2 can be punched by anyone
		
		if energy<0 then
			obj:set_properties({textures={"basic_machines_ball.png^[colorize:blue:120"}})
		end
		
		luaent.bounce = bounce;
		luaent.energy = energy;
		if gravity>0 then
			obj:setacceleration({x=0,y=-gravity,z=0});
		end
		luaent.puncheable = puncheable;
		luaent.owner = meta["owner"];
		luaent.hurt = math.min(tonumber(meta["hurt"]),basic_machines.ball.maxdamage);
		
		obj:set_hp( tonumber(meta["hp"]) );
		
		local x0,y0,z0;
		if speed>0 then luaent.speed = speed end
		
		

		local v = user:get_look_dir();
		v.x=v.x*speed;v.y=v.y*speed;v.z=v.z*speed;
		obj:setvelocity(v);

		
		if tonumber(meta["admin"])==1 then 
			luaent.lifetime = tonumber(meta["lifetime"]);
		end
		
		
		obj:set_properties({textures={meta["texture"]}})
		
		
	end,
	
	
})



-- minetest.register_craft({
	-- output = "basic_machines:ball_spawner",
	-- recipe = {
		-- {"basic_machines:power_cell"},
		-- {"basic_machines:keypad"}
	-- }
-- })