-- rnd: code borrowed from machines, mark.lua

-- need for marking
machines = {}; 

machines.pos1 = {};machines.pos11 = {}; machines.pos2 = {}; 
machines.marker1 = {}
machines.marker11 = {}
machines.marker2 = {}
machines.marker_region = {}


--marks machines region position 1
machines.mark_pos1 = function(name)
	local pos1, pos2 = machines.pos1[name], machines.pos2[name]

	if pos1 ~= nil then
		--make area stay loaded
		local manip = minetest.get_voxel_manip()
		manip:read_from_map(pos1, pos1)
	end
	
	if not machines[name] then machines[name]={} end
	machines[name].timer = 10;
	if machines.marker1[name] ~= nil then --marker already exists
		machines.marker1[name]:remove() --remove marker
		machines.marker1[name] = nil
	end
	if pos1 ~= nil then
		--add marker
		machines.marker1[name] = minetest.add_entity(pos1, "machines:pos1")
		if machines.marker1[name] ~= nil then
			machines.marker1[name]:get_luaentity().name = name
		end
	end
end

--marks machines region position 1
machines.mark_pos11 = function(name)
	local pos11 = machines.pos11[name];

	if pos11 ~= nil then
		--make area stay loaded
		local manip = minetest.get_voxel_manip()
		manip:read_from_map(pos11, pos11)
	end
	
	if not machines[name] then machines[name]={} end
	machines[name].timer = 10;
	if machines.marker11[name] ~= nil then --marker already exists
		machines.marker11[name]:remove() --remove marker
		machines.marker11[name] = nil
	end
	if pos11 ~= nil then
		--add marker
		machines.marker11[name] = minetest.add_entity(pos11, "machines:pos11")
		if machines.marker11[name] ~= nil then
			machines.marker11[name]:get_luaentity().name = name
		end
	end
end

--marks machines region position 2
machines.mark_pos2 = function(name)
	local pos1, pos2 = machines.pos1[name], machines.pos2[name]

	if pos2 ~= nil then
		--make area stay loaded
		local manip = minetest.get_voxel_manip()
		manip:read_from_map(pos2, pos2)
	end
	
	if not machines[name] then machines[name]={} end
	machines[name].timer = 10;
	if machines.marker2[name] ~= nil then --marker already exists
		machines.marker2[name]:remove() --remove marker
		machines.marker2[name] = nil
	end
	if pos2 ~= nil then
		--add marker
		machines.marker2[name] = minetest.add_entity(pos2, "machines:pos2")
		if machines.marker2[name] ~= nil then
			machines.marker2[name]:get_luaentity().name = name
		end
	end
end



minetest.register_entity(":machines:pos1", {
	initial_properties = {
		visual = "cube",
		visual_size = {x=1.1, y=1.1},
		textures = {"machines_pos1.png", "machines_pos1.png",
			"machines_pos1.png", "machines_pos1.png",
			"machines_pos1.png", "machines_pos1.png"},
		collisionbox = {-0.55, -0.55, -0.55, 0.55, 0.55, 0.55},
		physical = false,
	},
	on_step = function(self, dtime)
		if not machines[self.name] then machines[self.name]={}; machines[self.name].timer = 10 end
		machines[self.name].timer = machines[self.name].timer - dtime
		if machines[self.name].timer<=0 or machines.marker1[self.name] == nil then
			self.object:remove()
		end
	end,
	on_punch = function(self, hitter)
		self.object:remove()
		machines.marker1[self.name] = nil
		machines[self.name].timer = 10
	end,
})

minetest.register_entity(":machines:pos11", {
	initial_properties = {
		visual = "cube",
		visual_size = {x=1.1, y=1.1},
		textures = {"machines_pos11.png", "machines_pos11.png",
			"machines_pos11.png", "machines_pos11.png",
			"machines_pos11.png", "machines_pos11.png"},
		collisionbox = {-0.55, -0.55, -0.55, 0.55, 0.55, 0.55},
		physical = false,
	},
	on_step = function(self, dtime)
		if not machines[self.name] then machines[self.name]={}; machines[self.name].timer = 10 end
		machines[self.name].timer = machines[self.name].timer - dtime
		if machines[self.name].timer<=0 or machines.marker11[self.name] == nil then
			self.object:remove()
		end
	end,
	on_punch = function(self, hitter)
		self.object:remove()
		machines.marker11[self.name] = nil
		machines[self.name].timer = 10
	end,
})

minetest.register_entity(":machines:pos2", {
	initial_properties = {
		visual = "cube",
		visual_size = {x=1.1, y=1.1},
		textures = {"machines_pos2.png", "machines_pos2.png",
			"machines_pos2.png", "machines_pos2.png",
			"machines_pos2.png", "machines_pos2.png"},
		collisionbox = {-0.55, -0.55, -0.55, 0.55, 0.55, 0.55},
		physical = false,
	},
	on_step = function(self, dtime)
		if not machines[self.name] then machines[self.name]={}; machines[self.name].timer = 10 end
		if machines[self.name].timer<=0 or machines.marker2[self.name] == nil then
			self.object:remove()
		end
	end,
})
