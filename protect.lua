-- adds event handler for attempt to dig in protected area

-- tries to activate specially configured nearby distributor at points with coordinates of form 20i, registers dig attempts in radius 10 around
-- distributor must have first target filter set to 0 ( disabled ) to handle dig events

local old_is_protected = minetest.is_protected

function minetest.is_protected(pos, digger)
	
	local is_protected = old_is_protected(pos, digger);
	if is_protected then -- only if protected
		local p = {x=math.floor((pos.x)/20)*20,y=math.floor((pos.y)/20)*20,z=math.floor((pos.z)/20)*20}
		if minetest.get_node(p).name == "basic_machines:distributor" then -- attempt to activate distributor at special grid location: coordinates of the form 10+20*i
			local meta = minetest.get_meta(p);
			if meta:get_int("active1") == 0 then -- first output is disabled, indicating ready to be used as event handler
				if meta:get_int("x1") ~= 0 then -- trigger protection event
					meta:set_string("infotext",digger); -- record diggers name onto distributor
					local table = minetest.registered_nodes["basic_machines:distributor"];
					local effector=table.mesecons.effector;
					local node = nil;
					effector.action_on(p,node,machines_TTL); 
				end
			end
		end
	end
	return is_protected;

end

minetest.register_on_chat_message(function(name, message)
	local player = minetest.get_player_by_name(name);
	local pos = player:getpos();
	local p = {x=math.floor((pos.x)/20)*20,y=math.floor((pos.y)/20)*20,z=math.floor((pos.z)/20)*20}
	if minetest.get_node(p).name == "basic_machines:distributor" then -- attempt to activate distributor at special grid location: coordinates of the form 10+20*i
			local meta = minetest.get_meta(p);
			if meta:get_int("active1") == 0 then -- first output is disabled, indicating ready to be used as event handler
				local y1 = meta:get_int("y1");
				if y1 ~= 0 then -- chat event, positive relays message, negative drops it
					meta:set_string("infotext",message); -- record diggers message
					local table = minetest.registered_nodes["basic_machines:distributor"];
					local effector=table.mesecons.effector;
					local node = nil;
					effector.action_on(p,node,machines_TTL); 
					if y1<0 then return true
				end
			end
		end
	end
end
)