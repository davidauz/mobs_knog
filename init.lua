-- VERSION: 0.2.0

local path = minetest.get_modpath("mobs_knog")

dofile(path .. "/boulder.lua")
dofile(path .. "/generic_functions.lua")
dofile(path .. "/kn_functions.lua")


-- raw meat
minetest.register_craftitem("mobs_knog:meat_chunk", {
	description = "Chunk of meat",
	inventory_image = "meat_chunk.png",
	on_use = minetest.item_eat(10),
})


-- used for debug
minetest.register_entity(":knog:marker", {
	initial_properties = {
		visual = "cube",
		visual_size = {x=1.1, y=1.1},
		textures = {"knog_marker.png", "knog_marker.png",
			"knog_marker.png", "knog_marker.png",
			"knog_marker.png", "knog_marker.png"},
		collisionbox = {-0.55, -0.55, -0.55, 0.55, 0.55, 0.55},
		physical = false,
		static_save = false,
	},
	on_punch = function(self, hitter)
		self.object:remove()
	end,
	on_blast = function(self, damage)
		return false, false, {} -- don't damage or knockback
	end,
})


minetest.register_chatcommand("kn_t", {
	description = 'KNOG TEST FUNCTION -- debug',
	params = "<what>",
	func = function(player_name,param)
		local KNOG_instance=nil
		if ""==param then
			return
		end
		if "0"==param then
			llog("MARK_HELP = 0")
			llog("MARK_FOLIAGE = 1")
			llog("MARK_SOLID = 2")
			llog("MARK_TARGET_ENTITY = 3")
			llog("MARK_WATER = 4")
			llog("MARK_RAYCAST_BUILDING=5")
			llog("MARK_HIGHLIGHT_BUILDING=6")
			llog("MARK boulder=7")
			llog("KILL KNOG=8")
			llog("THROW BOULDER=9")
			return
		end
		for index,an_entity in pairs(minetest.luaentities) do
			if an_entity.name ~= nil and an_entity.name == "mobs_knog:knog" then
				KNOG_instance=an_entity
			end
		end

		if nil ==KNOG_instance then return end
		if "8"==param then
			llog('Terminated')
			KNOG_instance.object:remove()
			return
		end
		if "9"==param then
			KNOG_instance.target_entity= minetest.get_player_by_name(player_name)
			throw_boulder_at_target( KNOG_instance )
			return
		end
		local what_to_log, how_many_markers = param:match("(.+)%s+(.+)")
		if nil== what_to_log then return end
		if nil == how_many_markers or ""==how_many_markers then how_many_markers=10 end
		KNOG_instance.MARKING_WHAT = 0+what_to_log
		KNOG_instance.CURRENT_MARKERS = 0+how_many_markers
		if KNOG_instance.CURRENT_MARKERS > KNOG_instance.TOTAL_MARKERS then 
			KNOG_instance.CURRENT_MARKERS = KNOG_instance.TOTAL_MARKERS
		end

		for i=1, KNOG_instance.TOTAL_MARKERS do
			local curr_marker_struct = KNOG_instance.markers_positions[ i ]
			if nil ~= curr_marker_struct then
				curr_marker_struct:remove()
			end
			KNOG_instance.markers_positions[i] = nil
		end

llog("marking '"..KNOG_instance.CURRENT_MARKERS.."' of '"..KNOG_instance.MARKING_WHAT.."'")
	end
})


function add_marker(self, pos)
	local curr_marker_struct = self.markers_positions[ self.markers_index ]
	if nil ~= curr_marker_struct then
		curr_marker_struct:remove()
	end
	self.markers_positions[ self.markers_index ] = minetest.add_entity(pos, "knog:marker")
	self.markers_index = 1 + self.markers_index
	if self.CURRENT_MARKERS < self.markers_index then
		self.markers_index = 1
	end
end



mobs:register_egg("mobs_knog:knog", "Knog", "knog_egg.png", 1)


minetest.register_entity("mobs_knog:knog", 
	{	name="Knog"
	,	type = "animal"
	,	description = "Knog"
	,	mesh = "knog.b3d"
	,	status = "status_stand"
	,	TOTAL_MARKERS=2000
	,	CURRENT_MARKERS=50
	,	BUILDING_SEARCH_RANGE=35
	,	ENTITY_SEARCH_RADIUS=35
	,	markers_positions = {}
	,	markers_index = 1
	,	MARKING_WHAT = 0
	,	MAX_HEALTH = 500
	,	BASE_ENV_DAMAGE=5
	,	timer_down=true
	,	target_entity = nil
	,	target_position = nil
	,	visual = "mesh"
	,	timer=20
	,	timed_actions_timer = 0
        ,	physical = true
	,	visual_size = {x=8, y=8}
	,	k_tool_capabilities = {
			full_punch_interval=0.1,
			damage_groups=
			{	fleshy=500
			,	wood=500
			,	leaves=500
			}
		}
	,	collisionbox = {
	-2,	-- xmin[1]
	0,	-- ymin[2]
	-2,	-- zmin[3]
	2, 	-- xmax[4]
	7,	-- ymax[5]
	2}	-- zmax[6]
	,	textures = {
		"knog1.png"
	}
	,	animation = 
	{		speed_normal = 10
	,		speed_sprint = 15
	,		speed_fly = 25
	,		stand_start = 1
	,		stand_end = 19
	,		walk_start = 20
	,		walk_end = 70
	,		gaze_start = 120
	,		gaze_end = 154
	,		punch_start = 71
	,		punch_end = 118
	,		sitting_start=154
	,		sitting_end=163
	,		eating_start=163
	,		eating_stop=197
	,		punch_loop = true
	,		current=""
	}
	,	on_death = function(self, killer)
		local	pos=self.object:get_pos()
		pos.y = pos.y+2
		local obj
		for i=1, 20 do
			obj=minetest.add_item(pos, "mobs_knog:meat_chunk")
			obj:set_acceleration({x = 0, y = -10, z = 0})
			obj:set_velocity({x = math.random(-1, 1),
					y = math.random(0, 5),
					z = math.random(-1, 1)})
		end
	end
	,	on_activate = function(self, staticdata)
			self.object:set_acceleration({x=0, y=-10, z=0})
			self.object:set_hp(self.MAX_HEALTH)
			for i=1, self.TOTAL_MARKERS do
				self.markers_positions[i] = nil
			end
	end
	,	on_rightclick = function (self, clicker)
-- rotate (debug)
			local yaw= self.object:get_yaw();
			yaw=yaw + 0.3;
			yaw=math.fmod(yaw, 2*math.pi)
			self.object:set_yaw( yaw )
			self.object:set_velocity({
				x = 0,
				y = 0,
				z = 0
			})
	end
	
	,	on_step = function(self, dtime)
			-- Check for damage every second
			local timed_actions_timer = self.timed_actions_timer
			timed_actions_timer = timed_actions_timer + dtime
			if (timed_actions_timer > 1) then
				self.timed_actions_timer = 0
				check_for_apples(self)
				local died = check_env_damage(self)
				if (died) then
					return
				end
			else
				self.timed_actions_timer = timed_actions_timer
			end
-- main routine for behaviour
			if ( true == self.timer_down ) then
				self.timer = self.timer - 1
				if( 0 > self.timer ) then
-- finite automaton for choosing next action on the basis of the previous one
					local next_actions = {
						["status_targeted"] = function(x) do_walk_to_target(x) end,	-->	status_walking_to_target
														-->	status_stand

						["status_walking_to_target"] = function(x) check_target_action(x) end, --> status_building_down

						["status_building_down"] = function(x) do_building_down(x) end,	-->	status_stand

						["status_stand"] = function(x) choose_random_action(x) end, 	-->	status_walking
														--	status_targeted
														--	status_stand

						["status_punchd_ent"] =  function(x) choose_random_action(x) end, 	-->	status_walking
															--	status_targeted
															--	status_stand
						["status_walking"] =  function(x) choose_random_action(x) end, 	-->	status_walking

						[ "status_SITTING" ]  =  function(x) check_for_apples(x) end,
						[ "status_EATING" ]  =  function(x) check_for_apples(x) end,
					}
					next_actions[self.status](self)
				end
			end
			do_advance(self)
		end
	}) -- end of register_entity


