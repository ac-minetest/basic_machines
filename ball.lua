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
	visual="sprite",
	visual_size={x=.50,y=.50},
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
		local r = 20;
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
				bpos.x = round(10*(bpos.x + t*vn.x+opos.x))/10;
				bpos.y = round(10*(bpos.y + t*vn.y+opos.y))/10;
				bpos.z = round(10*(bpos.z + t*vn.z+opos.z))/10;
				
				self.object:setpos({x= bpos.x,y=bpos.y,z=bpos.z}) -- place object at entry point
				
				
				if t<0 or t>1 then self.object:remove() return end -- FAILED!
				
				-- attempt to determine direction
				bpos ={ x=math.abs(bpos.x-opos.x),y=math.abs(bpos.y-opos.y),z=math.abs(bpos.z-opos.z)};
				local maxo = math.max(bpos.x,bpos.y,bpos.z);
			
				if bpos.x == maxo then
					v.x=-v.x
				elseif bpos.y == maxo then
					v.y=-v.y
				else
					v.z=-v.z				
				end
				self.object:setvelocity(v);
				
			end
			
			return
		end
	end,
})


minetest.register_node("basic_machines:ball_spawner", {
	description = "Spawns energy ball one block above",
	tiles = {"basic_machines_ball.png"},
	groups = {oddly_breakable_by_hand=2,mesecon_effector_on = 1},
	drawtype = "liquid",
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