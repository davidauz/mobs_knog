-- VERSION: 0.0.1
function llog(message)
	minetest.log(message)
	minetest.chat_send_all(message)
end

local MARK_HELP = 0
local MARK_FOLIAGE = 1
local MARK_SOLID = 2
local MARK_TARGET_ENTITY = 3
local MARK_WATER = 4
local MARK_RAYCAST_BUILDING=5
local MARK_HIGHLIGHT_BUILDING=6
local MARK_BOULDER=7

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
	},
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


local get_distance_horizontal = function(a, b)
	if(nil == b) then
		llog("b is NIL!")
	else
		local x, z = a.x - b.x, a.z - b.z
		return math.sqrt(x * x + z * z)
	end
end


minetest.register_chatcommand("kn_t", {
	description = 'KNOG TEST FUNCTIO -- debugN',
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
			llog("TERMINATE=8")
			llog("THROW=9")
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
			KNOG_instance.throw_boulder_at_target( KNOG_instance )
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



function node_registered_or_nil(pos) 
	local node = minetest.get_node_or_nil(pos) 
	if node and minetest.registered_nodes[node.name] then
		return node
	end 
	return nil
end

local get_velocity = function(self)
	local v = self.object:get_velocity()
	return (v.x * v.x + v.z * v.z) ^ 0.5
end

local check_flying_boulders = function(kn_inst)
	if nil == kn_inst.flying_boulder then return end
	local b_pos = kn_inst.flying_boulder:get_pos()
	if nil == b_pos then return end
	b_pos.y = b_pos.y-1.5
	if MARK_BOULDER==kn_inst.MARKING_WHAT then add_marker(kn_inst, b_pos) end					
	local b_node=minetest.get_node(b_pos)
	local radius=3
	if "air" ~= b_node.name and not string.find(b_node.name, "water") then 
		local objs = minetest.get_objects_inside_radius(b_pos, radius)
		for _, obj in pairs(objs) do
			if obj:is_player() then
				obj:set_hp(obj:get_hp() - 50)
				kn_inst.flying_boulder:remove()
				kn_inst.flying_boulder=nil
				local node_drops = minetest.get_node_drops("default:stone", nil)
				for i=1, #node_drops do
					minetest.add_item(b_pos, node_drops[i])
				end
			return
			end
		end
		kn_inst.flying_boulder:remove()
		kn_inst.flying_boulder=nil
		b_pos.y = b_pos.y+1
		minetest.env:add_node(b_pos, {name="default:stone"})
		return
	end
end

local check_env_damage = function (self)
	if 5 > self.object:get_hp() then
		self.object:remove()
	end
	local kn_pos = self.object:get_pos()
	kn_pos.y = kn_pos.y + 0.25
	local standing_in_node = node_registered_or_nil(kn_pos)
	if nil==standing_in_node then return end
	local standing_in = standing_in_node.name
	if nil ==standing_in then return end
	local nodef = minetest.registered_nodes[standing_in]
	if nodef.groups.water then
		self.object:set_hp( self.object:get_hp() - self.BASE_ENV_DAMAGE )
		return
	end
	if	nodef.groups.lava
	or	string.find(nodef.name, "fire") 
	or	string.find(nodef.name, "lava") 
	then
		self.object:set_hp( self.object:get_hp() - 3*self.BASE_ENV_DAMAGE )
		return
	end
end

local stand_and_do_nothing = function(self)
	self.timer_down=true
	self.status="status_stand"
	self.object:set_velocity(
	{	x = 0
	,	y = 0
	,	z = 0
	})
	self.object:set_animation (
	{		x = self.animation.stand_start
	,		y = self.animation.stand_end 
	} ,		self.animation.speed_normal
	,		0
	)
	self.timer=math.random(50,100)
	self.timer_down=true
end

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

local do_advance = function(self) -- [
	if get_velocity(self) > 0.5
	and self.object:get_velocity().y ~= 0 then
		return false -- already jumping
	end

	local yaw = self.object:get_yaw()
	local pos = self.object:get_pos()
	local nod = {name="default:stone"}
-- components of vector pointing front: Front Vector X and Z
	local fvx = -math.sin(yaw) -- Front Vector X
	local fvz = math.cos(yaw) -- Front Vector Y
-- position in front of mob, forward a little: Mob Front X and Z
	local mfx = fvx * (self.collisionbox[4] ) -- Mob front X
	local mfz = fvz * (self.collisionbox[6] ) -- Mob front Z
	local highest_solid_node=-50
	local jump_velocity=0
	local sample_pos
-- scanning the nodes in a vertical plane perpendicular to yaw
-- first scan for foliage TODO: may get stuck when facing cliff and foliage over head
	for vsr=self.collisionbox[5]+1, self.collisionbox[2], -1 do -- vertical scan range
		for hsr=self.collisionbox[1]-1, self.collisionbox[4]+1 do -- horizontal scan range
			for depth=1,2,0.5 do
				sample_pos={
					x=pos.x+depth*mfx+fvz*hsr, -- using fvz on X to go left because cos(a-PI/2) = -sin(a)
					y=pos.y+vsr,
					z=pos.z+depth*mfz-fvx*hsr -- sin(a-PI/2) = -cos(a)
				}
				if MARK_FOLIAGE==self.MARKING_WHAT then add_marker(self, sample_pos) end
				nod=node_registered_or_nil(sample_pos)
				if nod ~= nil then
					if ( minetest.get_item_group(nod.name, "tree")>0 
					or minetest.get_item_group(nod.name, "leaves")>0 ) then
-- special case of animation ouside the finite state automaton just to clear passage in woods
						self.object:set_animation (
						{		x = self.animation.punch_start
						,		y = self.animation.punch_end
						} ,		self.animation.speed_normal
						,		0
						)
						local node_drops = minetest.get_node_drops(nod.name, nil)
						minetest.remove_node(sample_pos)
						for i=1, #node_drops do
							minetest.add_item(sample_pos, node_drops[i])
						end
						return
					end
				end
			end
		end
	end
-- here we are sure there is no foliage; look for solid objects to jump over
	for vsr=self.collisionbox[5], self.collisionbox[2], -1 do -- vertical scan range
		for hsr=self.collisionbox[1], self.collisionbox[4] do -- horizontal scan range
			for depth=1,1.5,0.5 do
				sample_pos={
					x=pos.x+depth*mfx+fvz*hsr, -- using fvz on X to go left because cos(a-PI/2) = -sin(a)
					y=pos.y+vsr,
					z=pos.z+depth*mfz-fvx*hsr -- sin(a-PI/2) = -cos(a)
				}
				if MARK_SOLID==self.MARKING_WHAT then add_marker(self, sample_pos) end
				nod=node_registered_or_nil(sample_pos)
				if nod ~= nil then
					if minetest.registered_nodes[nod.name].walkable == true then
						if vsr > highest_solid_node then -- otherwise jump over obstacles
							highest_solid_node=vsr
						end
					end
				end
			end
		end
	end
-- now look for water  (gorillas hate water) and fire (they hate fire even more than water)
	local vsr=self.collisionbox[2]-0.5
	for hsr=self.collisionbox[1], self.collisionbox[4] do -- horizontal scan range
		for depth=1,2,0.5 do
			sample_pos={
				x=pos.x+depth*mfx+fvz*hsr,
				y=pos.y+vsr,
				z=pos.z+depth*mfz-fvx*hsr
			}
			nod=node_registered_or_nil(sample_pos)
			if "4"==self.MARKING_WHAT then add_marker(self, sample_pos) end
			if nod ~= nil then
				if	string.find(nod.name, "water") 
				or	string.find(nod.name, "fire") 
				or	string.find(nod.name, "lava") 
				then
					return self.change_direction_and_walk(self)
				end
			end
		end
	end

	highest_solid_node = 2 + highest_solid_node
	if 0 < highest_solid_node then
		jump_velocity=1+math.sqrt(1+highest_solid_node*2*10)
		if jump_velocity<1 and jump_velocity>0 then
			jump_velocity=1
		end
		local v = self.object:get_velocity()
		v.y = jump_velocity
		self.object:set_velocity(v)
		self.set_velocity_to_yaw(self, 1)
	end
	return false
end -- ]

local get_distance = function(a, b)
	if(nil == b) then
		minetest.log("get_distance: b is NIL!")
	else
		local x, y, z = a.x - b.x, a.y - b.y, a.z - b.z
		return math.sqrt(x * x + y * y + z * z)
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
	,	flying_boulder = nil
	,	markers_index = 1
	,	MARKING_WHAT = 0
	,	MAX_HEALTH = 500
	,	BASE_ENV_DAMAGE=5
	,	timer_down=true
	,	target_entity = nil
	,	target_position = nil
	,	visual = "mesh"
	,	timer=20
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
	,		punch_loop = true
	,		current=""
	}
	,	on_activate = function(self, staticdata)
			self.object:set_acceleration({x=0, y=-10, z=0})
			self.object:set_hp(self.MAX_HEALTH)
			for i=1, self.TOTAL_MARKERS do
				self.markers_positions[i] = nil
			end
	end
	,	look_for_building = function(self)
		local	yaw=self.object:get_yaw()
		local	pos=self.object:get_pos()
		local	fvx =-math.sin(yaw) -- front vector X
		local	fvz = math.cos(yaw) -- front vector Z (Y is up)
		local	nod = nil
		local	max_depth_scan = 25
		local	pos_casted={}
		local	pos_sample={}
		local	status_sky		= 0
		local	status_stone		= 1
		local	status_covered		= 2
		local	curr_status = status_sky
		local	lateral_range

		self.target_position = nil
		for dist=1, self.BUILDING_SEARCH_RANGE, 3 do -- distance from starting point
			lateral_range=dist/3
			for lateral_range=-lateral_range, lateral_range, 3 do
				pos_casted={
					x=pos.x+dist*fvx-lateral_range*fvz,
					y=pos.y+15, -- begin looking above head
					z=pos.z+dist*fvz+lateral_range*fvx
				}
-- for each sample look at nodes below pos_casted
-- sky +air=sky,+stone=1,+other=return
-- stone +stone=stone,+air=2,+other=return
-- covered +air=covered,+walkable=HIT,+other=return
				curr_status=status_sky
				for sample_depth=0, max_depth_scan, 1 do -- do not go too much underground
					pos_sample= {
						x=pos_casted.x,
						y=pos_casted.y - sample_depth,
						z=pos_casted.z
					}
					if MARK_RAYCAST_BUILDING==self.MARKING_WHAT then add_marker(self, pos_sample) end
					nod = node_registered_or_nil( pos_sample )
					if( nil == nod ) then 
						sample_depth = 1+max_depth_scan -- exit sample loop on nil
					elseif status_sky==curr_status then
						if minetest.get_item_group(nod.name, "stone") > 0 then curr_status=status_stone
						elseif ("air" ~= nod.name) then sample_depth = 1+max_depth_scan
						end
					elseif status_stone==curr_status then
						if ("air" == nod.name) then curr_status=status_covered
						elseif ("air" ~= nod.name) then sample_depth = 1+max_depth_scan
						end
					elseif status_covered==curr_status then
						if minetest.registered_nodes[nod.name].walkable then -- HIT
							curr_status = status_found_target
							pos_sample.y = pos_sample.y - 1
							self.target_position = pos_sample
							self.target_type = "building"
							if MARK_HIGHLIGHT_BUILDING==self.MARKING_WHAT then 
								for i=1, self.CURRENT_MARKERS do
									pos_sample.y = 2+pos_sample.y
									add_marker(self, pos_sample)
								end
							end
							return
						elseif ("air" ~= nod.name) then sample_depth = 1+max_depth_scan
						end
					end
				end
			end
		end
	end
--	,	on_rightclick = function (self, clicker)
---- rotate (debug)
--			local yaw= self.object:get_yaw();
--			yaw=yaw + 0.3;
--			yaw=math.fmod(yaw, 2*math.pi)
--			self.object:set_yaw( yaw )
--			self.object:set_velocity({
--				x = 0,
--				y = 0,
--				z = 0
--			})
--	end
	,	set_velocity_to_yaw = function(self, multiplier)
			local yaw = self.object:get_yaw()
			local x = math.sin(yaw) * -1
			local z = math.cos(yaw)
 			local y = self.object:get_velocity().y
 			self.object:set_velocity({
				x = multiplier*x,
				y = multiplier*y,
				z = multiplier*z
 			})
		end
	,	set_yaw_towards_target = function(self, target_position)
			local s = self.object:get_pos()
			local p = target_position
			if	s.x == p.x
			and	s.y == p.y
			and	s.z == p.z
			then return end
			local vec = {
				x = p.x - s.x,
				z = p.z - s.z
			}
			local yaw = (math.atan(vec.z / vec.x) + math.pi / 2)
			if p.x > s.x then yaw = yaw + math.pi end
			self.object:set_yaw( yaw )
	end
	,	do_building_down = function(self)
			local radius = 3
			local knog_pos = self.object:get_pos()
			local stone_node_pos = minetest.find_node_near(knog_pos, radius, {"group:stone"}, true)
			while stone_node_pos ~= nil do
				local stone_node=minetest.get_node(stone_node_pos)
				local node_drops = minetest.get_node_drops(stone_node.name, nil)
				minetest.remove_node(stone_node_pos)
				for i=1, #node_drops do
					minetest.add_item(stone_node_pos, node_drops[i])
				end
				stone_node_pos = minetest.find_node_near(knog_pos, radius, {"group:stone"}, true)
			end
			self.target_position=nil
			self.target_type = nil
			self.target_entity = nil
			self.status="status_stand"
		end
	, check_target_action = function(self)
			if ( "building" == self.target_type ) then
				self.do_towards_building(self)
			elseif ( "player" == self.target_type ) then
				self.do_towards_player(self)
			elseif ( "entity" == self.target_type ) then
				self.do_towards_entity(self)
			end
		end
	,	do_walk_to_target = function(self)
			if nil ~= self.target_position then
				self.set_yaw_towards_target(self, self.target_position)
				self.status="status_walking_to_target"
				self.set_velocity_to_yaw(self, 1.5)
				self.object:set_animation (
				{		x = self.animation.walk_start
				,		y = self.animation.walk_end 
				} ,		self.animation.speed_sprint
				,		0
				)
				self.timer=50
				self.timer_down=true
			else
-- no target
				self.status="status_stand"
			end
		end
	,	set_next_target = function(self)
-- look if mob in sight
			self.target_type = nil
			self.look_for_entity(self)
			if self.target_type == nil then -- no entity found
				if(5<math.random(0,10)) then
					self.look_for_building(self)
				end
			end
			if nil == self.target_type  then
				self.status="status_stand"
				self.timer=50
				self.timer_down=true
				return
			end
-- at this point next target is set already but we do a little animation anyway
			self.object:set_velocity(
			{	x = 0
			,	y = 0
			,	z = 0
			})
			self.object:set_animation (
			{		x = self.animation.gaze_start
			,		y = self.animation.gaze_end 
			} ,		self.animation.speed_normal
			,		0
			)
			if  nil ~= self.target_position then
				self.status="status_targeted"
				self.timer=25 -- don't waste too much time running after an entity
				self.timer_down=true
			else
				self.status="status_stand"
				self.timer=50
				self.timer_down=true
			end
		end
	,	change_direction_and_walk = function(self)
			self.object:set_yaw( self.object:get_yaw() + math.random(-0.2,0.2) )
			self.set_velocity_to_yaw(self, 1)
			self.status="status_walking"
			self.object:set_animation (
			{		x = self.animation.walk_start
			,		y = self.animation.walk_end 
			} ,		self.animation.speed_normal
			,		0
			)
			self.timer=math.random(50,100)
			self.timer_down=true
		end
	,		look_for_entity = function(self)
			local knog_pos = self.object:get_pos()
			local objs = minetest.get_objects_inside_radius( knog_pos, self.ENTITY_SEARCH_RADIUS)
			local min_dist_ent = nil
			local min_dist_pl = nil
			local dist, mind_ent, mind_pl
			mind_ent=999
			for n = 1, #objs do
				local ent = objs[n]:get_luaentity()
				if ent ~= nil and ent.name ~= "mobs_knog:knog" and ent.type ~= nil then
				dist= get_distance_horizontal(ent.object:get_pos(), knog_pos)
					if dist < mind_ent then
						mind_ent = dist
						min_dist_ent = ent
					end
				end
			end
-- look for players
			mind_pl=999
			for _,p in ipairs(minetest.get_connected_players()) do
				dist=get_distance_horizontal(p:get_pos(), knog_pos)
				if dist < mind_pl then
					mind_pl = dist
					min_dist_pl = p
				end
			end
			if min_dist_ent == nil and min_dist_pl==nil then
				self.target_type = nil
				self.target_entity = nil
				self.target_position =  nil
				return
			end
			if min_dist_ent ~= nil and min_dist_pl==nil then
				self.target_type = "entity"
				self.target_entity = min_dist_ent
				self.target_position =  min_dist_ent.object:get_pos()
				return
			end
			if min_dist_ent == nil and min_dist_pl~=nil then
				self.target_type = "player"
				self.target_entity = min_dist_pl
				self.target_position =  min_dist_pl:get_pos()
				return
			end
			if mind_ent < mind_pl then
				self.target_type = "entity"
				self.target_entity = min_dist_ent
				self.target_position =  min_dist_ent.object:get_pos()
				return
			else
				self.target_type = "player"
				self.target_entity = min_dist_pl
				self.target_position =  min_dist_pl:get_pos()
				return
			end
		end 
	,	do_towards_building = function(self) 
			local dist= get_distance_horizontal(self.object:get_pos(), self.target_position)
			if(3>dist) then
				self.object:set_animation (
				{		x = self.animation.punch_start
				,		y = self.animation.punch_end
				} ,		self.animation.speed_normal
				,		0
				)
				self.object:set_velocity(
				{	x = 0
				,	y = 0
				,	z = 0
				})
				self.timer=150
				self.timer_down=true
				self.status="status_building_down"
			else
				self.set_yaw_towards_target(self, self.target_position)
				self.object:set_animation (
				{		x = self.animation.walk_start
				,		y = self.animation.walk_end 
				} ,		self.animation.speed_normal
				,		0
				)
				self.set_velocity_to_yaw(self, 1)
			end
		end
	,	do_towards_entity = function(self) 
-- update target position (entity may move)
			if nil == self.target_entity then return end
			if nil == self.target_entity.object then return end
			self.target_position = self.target_entity.object:get_pos()
			local dist= get_distance_horizontal(self.object:get_pos(), self.target_position)
			if nil == dist then -- something went really wrong
				self.status="status_stand"				
				self.target_position = nil
				self.target_entity = nil
				self.target_type = nil
				return
			end
			if(4>dist) then
				self.object:set_animation (
				{		x = self.animation.punch_start
				,		y = self.animation.punch_start+20
				} ,		self.animation.speed_normal
				,		0
				)
				self.object:set_velocity(
				{	x = 0
				,	y = 0
				,	z = 0
				})
				self.timer=50
				self.timer_down=true
				if nil == self.target_entity then
llog("NIL!:"..dump(self)) -- error - should not happen
					return
				end
				self.target_entity.object:punch(self.object, 1.0, self.k_tool_capabilities, nil )
--                                                                      |     |    |                        | 
--                                                                      |     |    |                        \ direction
--                                                                      |     |    \ tool_capabilities
--                                                                      |     \ time_from_last_punch
--                                                                      \ puncher
				self.status="status_punchd_ent"
			else -- 4 < distance
-- here we are still far from target entity
				do_advance(self)
				if MARK_TARGET_ENTITY==self.MARKING_WHAT then add_marker(self, self.target_position) end
				self.set_yaw_towards_target(self, self.target_position)
				self.object:set_animation (
				{		x = self.animation.walk_start
				,		y = self.animation.walk_end 
				} ,		self.animation.speed_normal
				,		0
				)
				self.set_velocity_to_yaw(self, 1)
			end
		end
	,	throw_boulder_at_target = function(self)
			local kn_pos = self.object:get_pos()
			kn_pos.y=kn_pos.y+self.collisionbox[5] -- ymax
			local tg_pos = self.target_entity:get_pos()
			local Vxz=10 -- XZ scalar velocity of boulder
			local Vgravity=-10
			local xdelta=tg_pos.x - kn_pos.x
			local zdelta=tg_pos.z - kn_pos.z
			local hor_dist=math.sqrt(xdelta*xdelta+zdelta*zdelta)
			local vx=Vxz*xdelta/hor_dist
			local vz=Vxz*zdelta/hor_dist
			local Tt=hor_dist/Vxz -- time to target
			local vy=(tg_pos.y-kn_pos.y-Vgravity*((Tt-1)*Tt/2))/Tt
			local Yt=tg_pos.y-kn_pos.y
			local vy=(Yt-Vgravity*Tt*Tt/2)/Tt
			self.flying_boulder = minetest.add_entity(kn_pos, "knog:boulder")
			self.flying_boulder:set_velocity(
			{	x=vx
			,	y=vy
			,	z=vz
			})
			self.flying_boulder:set_acceleration(
			{	x=0
			,	y=Vgravity
			,	z=0
			})
		end
	,	do_towards_player = function(self) 
-- update target position (target may move)
			self.target_position = self.target_entity:get_pos()
			local dist= get_distance_horizontal(self.object:get_pos(), self.target_position)
			if nil == dist then -- something went really wrong
				self.status="status_stand"				
				self.target_position = nil
				self.target_entity = nil
				self.target_type = nil
				return
			end
			if(4>dist) then
-- we are very close: SMASH!
				self.object:set_animation (
				{		x = self.animation.punch_start
				,		y = self.animation.punch_start+20
				} ,		self.animation.speed_normal
				,		0
				)
				self.object:set_velocity(
				{	x = 0
				,	y = 0
				,	z = 0
				})
				self.timer=50
				self.timer_down=true
				if nil == self.target_entity then
llog("NIL!:"..dump(self)) -- error - should not happen
					return
				end
				self.target_entity:punch(self.object, 1.0, self.k_tool_capabilities, nil )
				self.status="status_punchd_ent"
			elseif 15<dist then
-- too distant.  give up or throw boulder
				if 99 < math.random(0,100) then -- TODO adjust
					self.change_direction_and_walk(self)	--> status_walking
				else
					self.object:set_animation (
					{		x = self.animation.punch_start
					,		y = self.animation.punch_start+20
					} ,		self.animation.speed_normal
					,		0
					)
					self.timer=20
					self.timer_down=true
					self.status="status_punchd_ent"
					self.throw_boulder_at_target(self)
				end
			else -- 4 < distance
-- still far from target entity
				do_advance(self)
				if MARK_TARGET_ENTITY==self.MARKING_WHAT then add_marker(self, self.target_position) end
				self.set_yaw_towards_target(self, self.target_position)
				self.object:set_animation (
				{		x = self.animation.walk_start
				,		y = self.animation.walk_end 
				} ,		self.animation.speed_fly
				,		0
				)
				self.set_velocity_to_yaw(self, 1)
			end
		end
	,	choose_random_action = function(self)
			local next_action_n = math.random(0,100)
 			if 50 < next_action_n then
				self.change_direction_and_walk(self)	--> status_walking
			elseif 20 < next_action_n then
				self.set_next_target(self)
			else
				stand_and_do_nothing(self)
			end
	end
	,	on_step = function(self, dtime)
			check_env_damage(self)
			if nil ~= self.flying_boulder then check_flying_boulders(self) end
-- main routine for behaviour
			local action
			if ( true == self.timer_down ) then
				self.timer = self.timer - 1
				if( 0 > self.timer ) then
-- finite automaton for choosing next action on the basis of the last finished one
					local next_actions = {
						["status_targeted"] = function(x) self.do_walk_to_target(x) end,	-->	status_walking_to_target
															-->	status_stand

						["status_walking_to_target"] = function(x) self.check_target_action(x) end, --> status_building_down

						["status_building_down"] = function(x) self.do_building_down(x) end,	-->	status_stand

						["status_stand"] = function(x) self.choose_random_action(x) end, 	-->	status_walking
															--	status_targeted
															--	status_stand

						["status_punchd_ent"] =  function(x) self.choose_random_action(x) end, 	-->	status_walking
															--	status_targeted
															--	status_stand
						["status_walking"] =  function(x) self.choose_random_action(x) end, 	-->	status_walking
															--	status_targeted
															--	status_stand
					}
					next_actions[self.status](self)
				end
			end
			do_advance(self)
		end
	}) -- end of register_entity


