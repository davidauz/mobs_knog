
MARK_HELP = 0
MARK_FOLIAGE = 1
MARK_SOLID = 2
MARK_TARGET_ENTITY = 3
MARK_WATER = 4
MARK_RAYCAST_BUILDING=5
MARK_HIGHLIGHT_BUILDING=6
MARK_BOULDER=7

local VELOCITY_NORMAL=1
local VELOCITY_TOWARDS_ENTITY=2
local VELOCITY_TOWARDS_PLAYER=3

stand_and_do_nothing = function(kn_inst)
	kn_inst.timer_down=true
	kn_inst.status="status_stand"
	kn_inst.object:set_velocity(
	{	x = 0
	,	y = 0
	,	z = 0
	})
	kn_inst.object:set_animation (
	{		x = kn_inst.animation.stand_start
	,		y = kn_inst.animation.stand_end 
	} ,		kn_inst.animation.speed_normal
	,		0
	)
	kn_inst.timer=math.random(50,100)
	kn_inst.timer_down=true
end




function do_advance (kn_inst) -- [
	if get_velocity(kn_inst) > 0.5
	and kn_inst.object:get_velocity().y ~= 0 then
		return false -- already jumping
	end

	local yaw = kn_inst.object:get_yaw()
	local pos = kn_inst.object:get_pos()
	local nod = {name="default:stone"}
-- components of vector pointing front: Front Vector X and Z
	local fvx = -math.sin(yaw) -- Front Vector X
	local fvz = math.cos(yaw) -- Front Vector Y
-- position in front of mob, forward a little: Mob Front X and Z
	local mfx = fvx * (kn_inst.collisionbox[4] ) -- Mob front X
	local mfz = fvz * (kn_inst.collisionbox[6] ) -- Mob front Z
	local highest_solid_node=-50
	local sample_pos
-- scanning the nodes in a vertical plane perpendicular to yaw
-- first scan for foliage TODO: may get stuck when facing cliff and foliage over head
	for vsr=kn_inst.collisionbox[5]+1, kn_inst.collisionbox[2], -1 do -- vertical scan range
		for hsr=kn_inst.collisionbox[1]-1, kn_inst.collisionbox[4]+1 do -- horizontal scan range
			for depth=1,2,0.5 do
				sample_pos={
					x=pos.x+depth*mfx+fvz*hsr, -- using fvz on X to go left because cos(a-PI/2) = -sin(a)
					y=pos.y+vsr,
					z=pos.z+depth*mfz-fvx*hsr -- sin(a-PI/2) = -cos(a)
				}
				if MARK_FOLIAGE==kn_inst.MARKING_WHAT then add_marker(kn_inst, sample_pos) end
				nod=node_registered_or_nil(sample_pos)
				if nod ~= nil then
					if
					(	minetest.get_item_group(nod.name, "tree")>0 
					or	minetest.get_item_group(nod.name, "leaves")>0 
					or	nod.name == "default:apple"
					) then
-- special case of animation ouside the finite state automaton just to clear passage in woods
						kn_inst.object:set_animation (
						{		x = kn_inst.animation.punch_start
						,		y = kn_inst.animation.punch_end
						} ,		kn_inst.animation.speed_normal
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
	for vsr=kn_inst.collisionbox[5], kn_inst.collisionbox[2], -1 do -- vertical scan range
		for hsr=kn_inst.collisionbox[1], kn_inst.collisionbox[4] do -- horizontal scan range
			for depth=1.5,2,0.5 do
				sample_pos={
					x=pos.x+depth*mfx+fvz*hsr, -- using fvz on X to go left because cos(a-PI/2) = -sin(a)
					y=pos.y+vsr,
					z=pos.z+depth*mfz-fvx*hsr -- sin(a-PI/2) = -cos(a)
				}
				if MARK_SOLID==kn_inst.MARKING_WHAT then add_marker(kn_inst, sample_pos) end
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
	local vsr=kn_inst.collisionbox[2]-0.5
	for hsr=kn_inst.collisionbox[1], kn_inst.collisionbox[4] do -- horizontal scan range
		for depth=1,2,0.5 do
			sample_pos={
				x=pos.x+depth*mfx+fvz*hsr,
				y=pos.y+vsr,
				z=pos.z+depth*mfz-fvx*hsr
			}
			nod=node_registered_or_nil(sample_pos)
			if "4"==kn_inst.MARKING_WHAT then add_marker(kn_inst, sample_pos) end
			if nod ~= nil then
				if	string.find(nod.name, "water") 
				or	string.find(nod.name, "fire") 
				or	string.find(nod.name, "lava") 
				then
					return change_direction_and_walk(kn_inst)
				end
			end
		end
	end

	local jump_velocity=0
	highest_solid_node = 2 + highest_solid_node
	if 0 < highest_solid_node then
		jump_velocity = 1+math.sqrt(-2*highest_solid_node*kn_inst.object:get_acceleration().y )
		if jump_velocity<1 and jump_velocity>0 then
			jump_velocity=1
		end
		local v = kn_inst.object:get_velocity()
		v.y = jump_velocity
		kn_inst.object:set_velocity(v)
		set_velocity_to_yaw(kn_inst, VELOCITY_NORMAL)
	end
	return false
end -- ]


look_for_building = function(kn_instance)
	local	yaw=kn_instance.object:get_yaw()
	local	pos=kn_instance.object:get_pos()
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

	kn_instance.target_position = nil
	for dist=1, kn_instance.BUILDING_SEARCH_RANGE, 3 do -- distance from starting point
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
				if MARK_RAYCAST_BUILDING==kn_instance.MARKING_WHAT then add_marker(kn_instance, pos_sample) end
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
						kn_instance.target_position = pos_sample
						kn_instance.target_type = "building"
						if MARK_HIGHLIGHT_BUILDING==kn_instance.MARKING_WHAT then 
							for i=1, kn_instance.CURRENT_MARKERS do
								pos_sample.y = 2+pos_sample.y
								add_marker(kn_instance, pos_sample)
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

do_building_down = function(kn_inst)
	local radius = 3
	local knog_pos = kn_inst.object:get_pos()
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
	kn_inst.target_position=nil
	kn_inst.target_type = nil
	kn_inst.target_entity = nil
	kn_inst.status="status_stand"
end



hungry_for_apples = function(kn_inst)
	if "status_SITTING" == kn_inst.status then
		kn_inst.status = "status_EATING"
		kn_inst.object:set_animation (
		{		x = kn_inst.animation.eating_start
		,		y = kn_inst.animation.eating_stop
		} ,		kn_inst.animation.speed_normal
		,		0
		)
		kn_inst.timer=50
		kn_inst.timer_down=true
		kn_inst.object:set_velocity(
		{	x = 0
		,	y = 0
		,	z = 0
		})
	elseif "status_EATING" == kn_inst.status then
-- continue eating while there are apples
		local yaw = kn_inst.object:get_yaw( )
		local pos = kn_inst.object:get_pos( )
		local fvx = -math.sin(yaw) -- Front Vector X
		local fvz = math.cos(yaw) -- Front Vector Y
		local depth=4
		local sample_pos={
			x=pos.x+depth*fvx,
			y=pos.y,
			z=pos.z+depth*fvz
		}
		for index,object in pairs(minetest.get_objects_inside_radius(sample_pos, 3.0)) do
			local ent = object:get_luaentity()
			if ent and "default:apple" == ent.itemstring then
				object:remove()
				return
			end
		end
-- apples gone!
		kn_inst.status = "status_stand"
	else
-- look for apples
		local yaw = kn_inst.object:get_yaw( )
		local pos = kn_inst.object:get_pos( )
		local fvx = -math.sin(yaw) -- Front Vector X
		local fvz = math.cos(yaw) -- Front Vector Y
		local depth=4
		local sample_pos={
			x=pos.x+depth*fvx,
			y=pos.y,
			z=pos.z+depth*fvz
		}
		for index,object in pairs(minetest.get_objects_inside_radius(sample_pos, 3.0)) do
			local ent = object:get_luaentity()
			if ent then
				local itemstring = ent.itemstring
				if("default:apple"==itemstring) then
					kn_inst.status = "status_SITTING"
					kn_inst.object:set_animation (
					{		x = kn_inst.animation.sitting_start
					,		y = kn_inst.animation.sitting_end 
					} ,		kn_inst.animation.speed_normal
					,		0
					)
					kn_inst.timer=50
					kn_inst.timer_down=true
					kn_inst.object:set_velocity(
					{	x = 0
					,	y = 0
					,	z = 0
					})
				end
			end
		end
	end
end

function check_target_action(kn_inst)
	if ( "building" == kn_inst.target_type ) then
		do_towards_building(kn_inst)
	elseif ( "player" == kn_inst.target_type ) then
		do_towards_player(kn_inst)
	elseif ( "entity" == kn_inst.target_type ) then
		do_towards_entity(kn_inst)
	end
end



do_walk_to_target = function(kn_inst)
	if nil ~= kn_inst.target_position then
		set_yaw_towards_target(kn_inst, kn_inst.target_position)
		kn_inst.status="status_walking_to_target"
		set_velocity_to_yaw(kn_inst, VELOCITY_TOWARDS_ENTITY)
		kn_inst.object:set_animation (
		{		x = kn_inst.animation.walk_start
		,		y = kn_inst.animation.walk_end 
		} ,		kn_inst.animation.speed_sprint
		,		0
		)
		kn_inst.timer=50
		kn_inst.timer_down=true
	else
-- no target
		kn_inst.status="status_stand"
	end
end




set_next_target = function(kn_inst)
-- look if mob in sight
	kn_inst.target_type = nil
	look_for_entity(kn_inst)
	if kn_inst.target_type == nil then -- no entity found
		if(5<math.random(0,10)) then
			look_for_building(kn_inst)
		end
	end
	if nil == kn_inst.target_type  then
		kn_inst.status="status_stand"
		kn_inst.timer=50
		kn_inst.timer_down=true
		return
	end
-- at this point next target is set already but we do a little animation anyway
	kn_inst.object:set_velocity(
	{	x = 0
	,	y = 0
	,	z = 0
	})
	kn_inst.object:set_animation (
	{		x = kn_inst.animation.gaze_start
	,		y = kn_inst.animation.gaze_end 
	} ,		kn_inst.animation.speed_normal
	,		0
	)
	if  nil ~= kn_inst.target_position then
		kn_inst.status="status_targeted"
		kn_inst.timer=25 -- don't waste too much time running after an entity
		kn_inst.timer_down=true
	else
		kn_inst.status="status_stand"
		kn_inst.timer=50
		kn_inst.timer_down=true
	end
end



change_direction_and_walk = function(kn_inst)
	kn_inst.object:set_yaw( kn_inst.object:get_yaw() + math.random(-0.2,0.2) )
	set_velocity_to_yaw(kn_inst, VELOCITY_NORMAL)
	kn_inst.status="status_walking"
	kn_inst.object:set_animation (
	{		x = kn_inst.animation.walk_start
	,		y = kn_inst.animation.walk_end 
	} ,		kn_inst.animation.speed_normal
	,		0
	)
	kn_inst.timer=math.random(50,100)
	kn_inst.timer_down=true
end





look_for_entity = function(kn_inst)
	local knog_pos = kn_inst.object:get_pos()
	local objs = minetest.get_objects_inside_radius( knog_pos, kn_inst.ENTITY_SEARCH_RADIUS)
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
		kn_inst.target_type = nil
		kn_inst.target_entity = nil
		kn_inst.target_position =  nil
		return
	end
	if min_dist_ent ~= nil and min_dist_pl==nil then
		kn_inst.target_type = "entity"
		kn_inst.target_entity = min_dist_ent
		kn_inst.target_position =  min_dist_ent.object:get_pos()
		return
	end
	if min_dist_ent == nil and min_dist_pl~=nil then
		kn_inst.target_type = "player"
		kn_inst.target_entity = min_dist_pl
		kn_inst.target_position =  min_dist_pl:get_pos()
		return
	end
	if mind_ent < mind_pl then
		kn_inst.target_type = "entity"
		kn_inst.target_entity = min_dist_ent
		kn_inst.target_position =  min_dist_ent.object:get_pos()
		return
	else
		kn_inst.target_type = "player"
		kn_inst.target_entity = min_dist_pl
		kn_inst.target_position =  min_dist_pl:get_pos()
		return
	end
end 

function do_towards_building(kn_inst) 
	local dist= get_distance_horizontal(kn_inst.object:get_pos(), kn_inst.target_position)
	if(3>dist) then
		kn_inst.object:set_animation (
		{		x = kn_inst.animation.punch_start
		,		y = kn_inst.animation.punch_end
		} ,		kn_inst.animation.speed_normal
		,		0
		)
		kn_inst.object:set_velocity(
		{	x = 0
		,	y = 0
		,	z = 0
		})
		kn_inst.timer=150
		kn_inst.timer_down=true
		kn_inst.status="status_building_down"
	else
		set_yaw_towards_target(kn_inst, kn_inst.target_position)
		kn_inst.object:set_animation (
		{		x = kn_inst.animation.walk_start
		,		y = kn_inst.animation.walk_end 
		} ,		kn_inst.animation.speed_normal
		,		0
		)
		set_velocity_to_yaw(kn_inst, VELOCITY_NORMAL)
	end
end




function do_towards_entity(kn_inst) 
-- update target position (entity may move)
	if nil == kn_inst.target_entity then return end
	if nil == kn_inst.target_entity.object then return end
	kn_inst.target_position = kn_inst.target_entity.object:get_pos()
	local dist= get_distance_horizontal(kn_inst.object:get_pos(), kn_inst.target_position)
	if nil == dist then -- something went really wrong
		kn_inst.status="status_stand"				
		kn_inst.target_position = nil
		kn_inst.target_entity = nil
		kn_inst.target_type = nil
		return
	end
	if(4>dist) then
		kn_inst.object:set_animation (
		{		x = kn_inst.animation.punch_start
		,		y = kn_inst.animation.punch_start+20
		} ,		kn_inst.animation.speed_normal
		,		0
		)
		kn_inst.object:set_velocity(
		{	x = 0
		,	y = 0
		,	z = 0
		})
		kn_inst.timer=50
		kn_inst.timer_down=true
		if nil == kn_inst.target_entity then
llog("NIL!:"..dump(kn_inst)) -- error - should not happen
			return
		end
		kn_inst.target_entity.object:punch(kn_inst.object, 1.0, kn_inst.k_tool_capabilities, nil )
--                                                           |     |    |                             | 
--                                                           |     |    |                             \ direction
--                                                           |     |    \ tool_capabilities
--                                                           |     \ time_from_last_punch
--                                                           \ puncher
		kn_inst.status="status_punchd_ent"
	else -- 4 < distance
-- here we are still far from target entity
		do_advance(kn_inst)
		if MARK_TARGET_ENTITY==kn_inst.MARKING_WHAT then add_marker(kn_inst, kn_inst.target_position) end
		set_yaw_towards_target(kn_inst, kn_inst.target_position)
		kn_inst.object:set_animation (
		{		x = kn_inst.animation.walk_start
		,		y = kn_inst.animation.walk_end 
		} ,		kn_inst.animation.speed_normal
		,		0
		)
		set_velocity_to_yaw(kn_inst, VELOCITY_TOWARDS_ENTITY)
	end
end


throw_boulder_at_target = function(kn_inst)
	local kn_pos = kn_inst.object:get_pos()
	kn_pos.y=kn_pos.y+kn_inst.collisionbox[5] -- ymax
	local tg_pos = kn_inst.target_entity:get_pos()
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
	local flying_boulder = minetest.add_entity(kn_pos, "knog:boulder")
	flying_boulder:set_velocity(
	{	x=vx
	,	y=vy
	,	z=vz
	})
	flying_boulder:set_acceleration(
	{	x=0
	,	y=Vgravity
	,	z=0
	})
end



function do_towards_player(kn_inst) 
-- update target position (target may move)
	kn_inst.target_position = kn_inst.target_entity:get_pos()
	local dist= get_distance_horizontal(kn_inst.object:get_pos(), kn_inst.target_position)
	if nil == dist then -- something went really wrong
		kn_inst.status="status_stand"				
		kn_inst.target_position = nil
		kn_inst.target_entity = nil
		kn_inst.target_type = nil
		return
	end
	if(4>dist) then
-- we are very close: SMASH!
		kn_inst.object:set_animation (
		{		x = kn_inst.animation.punch_start
		,		y = kn_inst.animation.punch_start+20
		} ,		kn_inst.animation.speed_normal
		,		0
		)
		kn_inst.object:set_velocity(
		{	x = 0
		,	y = 0
		,	z = 0
		})
		kn_inst.timer=50
		kn_inst.timer_down=true
		if nil == kn_inst.target_entity then
llog("NIL!:"..dump(kn_inst)) -- error - should not happen
			return
		end
		kn_inst.target_entity:punch(kn_inst.object, 1.0, kn_inst.k_tool_capabilities, nil )
		kn_inst.status="status_punchd_ent"
	elseif 15<dist then
-- too distant.  give up or throw boulder
		if 60 < math.random(0,100) or nil ~= kn_inst.flying_boulder then
			change_direction_and_walk(kn_inst)	--> status_walking
		else
			kn_inst.object:set_animation (
			{		x = kn_inst.animation.punch_start
			,		y = kn_inst.animation.punch_start+20
			} ,		kn_inst.animation.speed_normal
			,		0
			)
			kn_inst.timer=20
			kn_inst.timer_down=true
			kn_inst.status="status_punchd_ent"
			throw_boulder_at_target(kn_inst)
		end
	else -- 4 < distance
-- still far from target entity
		do_advance(kn_inst)
		if MARK_TARGET_ENTITY==kn_inst.MARKING_WHAT then add_marker(kn_inst, kn_inst.target_position) end
		set_yaw_towards_target(kn_inst, kn_inst.target_position)
		kn_inst.object:set_animation (
		{		x = kn_inst.animation.walk_start
		,		y = kn_inst.animation.walk_end 
		} ,		kn_inst.animation.speed_fly
		,		0
		)
		set_velocity_to_yaw(kn_inst, VELOCITY_TOWARDS_PLAYER)
	end
end



choose_random_action = function(kn_inst)
		local next_action_n = math.random(0,100)
		if 50 < next_action_n then
			change_direction_and_walk(kn_inst)	--> status_walking
		elseif 20 < next_action_n then
			set_next_target(kn_inst)
		else
			stand_and_do_nothing(kn_inst)
		end
end



-- Return: Whether knog died. If true, Do not do anything further with knog as
-- the entity has already been destroyed.
function check_env_damage(kn_inst)
	local kn_pos = kn_inst.object:get_pos()
	kn_pos.y = kn_pos.y + 0.25
	local standing_in_node = node_registered_or_nil(kn_pos)
	if nil==standing_in_node then return end
	local standing_in = standing_in_node.name
	if nil ==standing_in then return end
	local nodef = minetest.registered_nodes[standing_in]
	if nodef.groups.water then
		kn_inst.object:set_hp( kn_inst.object:get_hp() - 10*kn_inst.BASE_ENV_DAMAGE )
llog("IS WATER:"..kn_inst.object:get_hp())
	end
	if	nodef.groups.lava
	or	string.find(nodef.name, "fire") 
	or	string.find(nodef.name, "lava") 
	then
		kn_inst.object:set_hp( kn_inst.object:get_hp() - 30*kn_inst.BASE_ENV_DAMAGE )
	end

    if (kn_inst.object:get_hp() <= 0) then
        kn_inst.object:remove()
        return true
    end
end




