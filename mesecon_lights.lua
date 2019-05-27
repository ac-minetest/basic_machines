-- make other light blocks work with mesecon signals - can toggle on/off

local function enable_toggle_light(name)

local table = minetest.registered_nodes[name]; if not table then return end
	local table2 = {}
	for i,v in pairs(table) do table2[i] = v end
	
	if table2.mesecons then return end -- we dont want to overwrite existing stuff!
	
	local offname = "basic_machines:"..string.gsub(name, ":", "_").. "_OFF";
	
	table2.mesecons = {effector = { -- action to toggle light off
		action_off  =  function (pos,node,ttl)
			minetest.swap_node(pos,{name = offname});
		end
		}
	};
	
	table2.after_place_node = function(pos, placer)
		minetest.after(5, -- fixes mesecons turning light off after place
			function()
				if minetest.get_node(pos).name == offname then
					minetest.swap_node(pos,{name = name})
				end
			end
		)
	end
	
	minetest.register_node(":"..name, table2) -- redefine item

	-- STRANGE BUG1: if you dont make new table table3 and reuse table2 definition original node (definition one line above) is changed by below code too!???
	-- STRANGE BUG2: if you dont make new table3.. original node automatically changes to OFF node when placed ????
	
	local table3 = {}
	for i,v in pairs(table) do
		table3[i] = v
	end
	
	table3.light_source = 0; -- off block has light off
	table3.mesecons = {effector = {
		action_on  =  function (pos,node,ttl)
			minetest.swap_node(pos,{name = name});
		end
		}
	};
	 
	-- REGISTER OFF BLOCK 
	minetest.register_node(":"..offname, table3);

end


enable_toggle_light("xdecor:wooden_lightbox");
enable_toggle_light("xdecor:iron_lightbox");
enable_toggle_light("moreblocks:slab_meselamp_1");
enable_toggle_light("moreblocks:slab_super_glow_glass");

enable_toggle_light("darkage:lamp");