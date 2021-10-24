
function llog(message)
	minetest.log(message)
	minetest.chat_send_all(message)
end

function get_distance_horizontal(a, b)
	if(nil == b) then
		llog("b is NIL!")
	else
		local x, z = a.x - b.x, a.z - b.z
		return math.sqrt(x * x + z * z)
	end
end


function node_registered_or_nil(pos) 
	local node = minetest.get_node_or_nil(pos) 
	if node and minetest.registered_nodes[node.name] then
		return node
	end 
	return nil
end

function get_velocity  (self)
	local v = self.object:get_velocity()
	return (v.x * v.x + v.z * v.z) ^ 0.5
end


function get_distance  (a, b)
	if(nil == b) then
		minetest.log("get_distance: b is NIL!")
	else
		local x, y, z = a.x - b.x, a.y - b.y, a.z - b.z
		return math.sqrt(x * x + y * y + z * z)
	end
end


function set_velocity_to_yaw  (self, multiplier)
	local yaw = self.object:get_yaw()
	local x = math.sin(yaw) * -1
	local z = math.cos(yaw)
	local y = self.object:get_velocity().y
	self.object:set_velocity({
		x = multiplier*x,
		y = y,
		z = multiplier*z
	})
end


function set_yaw_towards_target  (self, target_position)
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



