-- BALL: energy ball that flies around, can bounce and activate stuff
-- rnd 2016:

local function round(x)
	if x < 0 then 
		return -math.floor(-x+0.5);
	else 
		return math.floor(x+0.5);
	end
end

minetest.register_entity("basic_machines:ball",{
	timer = 0, 
	lifetime = 20, -- how long it exists before disappearing
	energy = 1, -- if negative it will deactivate stuff
	owner = "",
	origin = {x=0,y=0,z=0},
	hp_max = 1,
	elasticity = 0.8, -- speed gets multiplied by this after bounce
	visual="sprite",
	visual_size={x=.6,y=.6},
	collisionbox = {0,0,0,0,0,0},
	physical=false,
	--textures={"basic_machines_ball"},
		on_punch=function(self, puncher, time_from_last_punch, tool_capabilities, dir) -- ball is punched
			
		end,
	on_activate = function(self, staticdata)
		self.object:set_properties({textures={"basic_machines_ball.png"}})
		self.object:setvelocity({x=0,y=0,z=0})
		self.timer = 0;self.owner = "";
		self.origin = self.object:getpos();
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
		if math.abs(pos.x-origin.x)>r or math.abs(pos.y-origin.y)>r or math.abs(pos.z-origin.z)>r then -- remove if it goes too far
			self.object:remove() 
			return 
		end
		
		local nodename = minetest.get_node(pos).name;
		local walkable = false;
		if nodename ~= "air" then 
			walkable = minetest.registered_nodes[nodename].walkable;
		end

		if walkable then -- we hit a node
			--minetest.chat_send_all(" hit node at " .. minetest.pos_to_string(pos))
			
			if minetest.is_protected(pos,self.owner) then return end
			local node = minetest.get_node(pos);
			local table = minetest.registered_nodes[node.name];
			if table and table.mesecons and table.mesecons.effector then
				local effector = table.mesecons.effector;
				if self.energy>0 then
					if not effector.action_on then return end
					effector.action_on(pos,node,16); 
				elseif self.energy<0 then
					if not effector.action_off then return end
					effector.action_off(pos,node,16); 
				end
				self.object:remove() 
			else -- bounce ( copyright rnd, 2016 )
				local v = self.object:getvelocity();
				local opos = {x=round(pos.x),y=round(pos.y), z=round(pos.z)}; -- obstacle
				
				local bpos ={ x=(pos.x-opos.x),y=(pos.y-opos.y),z=(pos.z-opos.z)};
				
				-- try to determine exact point of entry 
				local vm = math.sqrt(v.x*v.x+v.y*v.y+v.z*v.z); if vm == 0 then vm = 1 end
				local vn = {x=-v.x/vm,y=-v.y/vm, z= -v.z/vm};
				
				local t1=2; local t2 = 2; local t3 = 2;
				local t0;
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
				local n = {x=0,y=0,z=0};
				
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
	end,

	mesecons = {effector = {
		action_on = function (pos, node,ttl) 
			if ttl<0 then return end
			local obj = minetest.add_entity({x=pos.x,y=pos.y,z=pos.z}, "basic_machines:ball");
			local luaent = obj:get_luaentity();
			luaent.energy = 1;
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
})


minetest.register_craft({
	output = "basic_machines:ball_spawner",
	recipe = {
		{"basic_machines:power_cell"},
		{"basic_machines:keypad"}
	}
})