
minetest.register_entity(":knog:boulder", {
	initial_properties = {
		visual = "cube",
		visual_size = {x=1.5, y=1.5, z=1.5},
		textures = {"knog_boulder.png", "knog_boulder.png",
			"knog_boulder.png", "knog_boulder.png",
			"knog_boulder.png", "knog_boulder.png"},
		collisionbox = {-0.75, -0.75, -0.75, 0.75, 0.75, 0.75},
		physical = true,
		static_save = false,
		b_tool_capabilities = {
			full_punch_interval=0.1,
			damage_groups=
			{	fleshy=50
			,	wood=50
			,	leaves=50
			}
		}
	}
	,	on_step = function(self, dtime)
		local b_pos = self.object:get_pos()
		if nil == b_pos then return end
		b_pos.y = b_pos.y-1.5
		local objs = minetest.get_objects_inside_radius(b_pos, 2)
		for _, obj in pairs(objs) do
			if obj:is_player() then
				obj:set_hp(obj:get_hp() - 30) -- sorry
			end
		end
		local b_node=minetest.get_node(b_pos)
		if minetest.registered_nodes[b_node.name].walkable == true then
-- hit something
        		self.object:remove()
			b_pos.y = b_pos.y+1
			minetest.env:add_node(b_pos, {name="default:stone"})
		end
	end
})


