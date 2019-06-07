-- make doors open/close with signal

tablecopy = function(a)
	local b = {};
	for k,v in pairs(a) do 
		if type(v) == "table" then
			b[k] = tablecopy(v)
		else
			b[k]=v 
		end
	end
	return b
end

local function door_signal_overwrite(name)
	local table = minetest.registered_nodes[name]; if not table then return end
	--if table.mesecons then return end -- already exists, don't change
	local door_on_rightclick = table.on_rightclick;	
	
	
	minetest.override_item(name,
		{mesecons = {effector = {
			action_on  =  function (pos,node)
				local meta = minetest.get_meta(pos);local name = meta:get_string("owner");
				-- create virtual player
				local clicker = {}; 
				function clicker:get_wielded_item() 
					local item = {}
					function item:get_name() return "" end 
					return item 
				end
				function clicker:get_player_name() return name end; -- define method get_player_name() returning owner name so that we can call on_rightclick function in door
				function clicker:is_player() return true end; -- method needed for mods that check this: like denaid areas mod
				if door_on_rightclick then  door_on_rightclick(pos, nil, clicker,ItemStack(""),{}) end -- safety if it doesnt exist
				--minetest.swap_node(pos, {name = "protector:trapdoor", param1 = node.param1, param2 = node.param2}) -- more direct approach?, need to set param2 then too
			end
			}
		}
})
		
end

	door_signal_overwrite("doors:door_wood");door_signal_overwrite("doors:door_steel")
	door_signal_overwrite("doors:door_wood_a");door_signal_overwrite("doors:door_wood_b");
	door_signal_overwrite("doors:door_steel_a");door_signal_overwrite("doors:door_steel_b");
	door_signal_overwrite("doors:door_glass_a");door_signal_overwrite("doors:door_glass_b");
	door_signal_overwrite("doors:door_obsidian_glass_a");door_signal_overwrite("doors:door_obsidian_glass_b");
	
	door_signal_overwrite("doors:trapdoor");door_signal_overwrite("doors:trapdoor_open");
	door_signal_overwrite("doors:trapdoor_steel");door_signal_overwrite("doors:trapdoor_steel_open");

local function make_it_noclip(name)
	minetest.override_item(name,{walkable = false}); -- cant be walked on
end 

make_it_noclip("doors:trapdoor_open");
make_it_noclip("doors:trapdoor_steel_open");

-- minetest bug: using override_item  to change group.level = 99 does nothing - door still diggable
-- using minetest.register_node(":"..name, table2) with table2.group.level = 99 does work. why?

--[[

local function make_it_nondiggable_but_removable(name, dropname)
	
	local table = minetest.registered_nodes[name]; if not table then return end
	local table2 = tablecopy(table.groups);
	
	table2.level = 99; -- cant be digged, but it can be removed by owner or if not protected
	
	minetest.override_item(name,
	{
	on_punch = function(pos, node, puncher, pointed_thing) -- remove node if owner repeatedly punches it 3x
		local pname = puncher:get_player_name();
		local meta = minetest.get_meta(pos);
		local owner = meta:get_string("doors_owner")
		if pname==owner or not minetest.is_protected(pos,pname) then -- can be dug by owner or if unprotected
			local t0 = meta:get_int("punchtime");local count = meta:get_int("punchcount");
			local t = minetest.get_gametime();
			
			if t-t0<2 then count = (count +1 ) % 3 else count =  0 end

			if count == 1 then
				minetest.chat_send_player(pname, "#steel door: punch me one more time to remove me");
			end
			if count == 2 then -- remove steel door and drop it
				minetest.set_node(pos, {name = "air"});
				local stack = ItemStack(dropname);minetest.add_item(pos,stack)
			end
			
			meta:set_int("punchcount",count);meta:set_int("punchtime",t);
			--minetest.chat_send_all("punch by "..name .. " count " .. count)
		end
	end
	})
	
	minetest.override_item(name, {diggable = false})

	--minetest.register_node(":"..name, table2)
end 

--minetest.after(0,function()
	make_it_nondiggable_but_removable("doors:door_steel_a","doors:door_steel");	
	make_it_nondiggable_but_removable("doors:door_steel_b","doors:door_steel");
	
	make_it_nondiggable_but_removable("doors:trapdoor_steel","doors:trapdoor_steel");
	make_it_nondiggable_but_removable("doors:trapdoor_steel_open","doors:trapdoor_steel");
--end);
--]]