
-- block that can be activated/activate mesecon blocks

local adapter_effector = {
		action_on = function (pos, node,ttl)
			if type(ttl)~="number" then ttl = 2 end
			if not(ttl>0) then return end
			
			pos.y=pos.y+1;
			local node = minetest.get_node(pos);
			if not node.name then return end -- error
			local table = minetest.registered_nodes[node.name];
			if not table then return end
			if table.effector and table.effector.action_on then -- activate basic_machine
				local effector=table.effector;
				effector.action_on(pos,node,ttl); 
			else -- table.mesecons and table.mesecons.effector then -- activate mesecons
				pos.y=pos.y-1
				mesecon.receptor_on(pos, mesecon.rules.buttonlike_get(node))
				--local effector=table.mesecons.effector;
				--effector.action_on(pos,node); 
			end
		end,
		
		action_off = function (pos, node,ttl)
			if type(ttl)~="number" then ttl = 2 end
			if not(ttl>0) then return end
			
			pos.y=pos.y+1;
			local node = minetest.get_node(pos);
			if not node.name then return end -- error
			local table = minetest.registered_nodes[node.name];
			if not table then return end
			if table.effector and table.effector.action_off then -- activate basic_machine
				local effector=table.effector;
				effector.action_off(pos,node,ttl); 
			else -- table.mesecons and table.mesecons.effector then -- activate mesecons
				pos.y=pos.y-1
				mesecon.receptor_off(pos, mesecon.rules.buttonlike_get(node))
				--local effector=table.mesecons.effector;
				--effector.action_off(pos,node); 
			end
		end,
	}

minetest.register_node("basic_machines:mesecon_adapter", {
	description = "interface between machines and mesecons - place block to be activated on top of it.",
	tiles = {"basic_machine_clock_generator.png","basic_machine_clock_generator.png", 
	"jeija_luacontroller_top.png","jeija_luacontroller_top.png","jeija_luacontroller_top.png","jeija_luacontroller_top.png"
	},
	groups = {cracky=3,mesecon_effector_on = 1,mesecon_effector_off=1,mesecon_needs_receiver = 1,},
	sounds = default.node_sound_wood_defaults(),
	
	
	effector = adapter_effector,
	mesecons = {
		effector = adapter_effector,
		receptor = {
			rules = mesecon.rules.buttonlike_get,
			state = mesecon.state.off
		},
	},
	
})