require "entity"
require "quaternion"
require "mesh"

Camera = Entity:new()

local hw, hh = love.graphics.getWidth()/2, love.graphics.getHeight()/2

function Camera:Camera(vfov)
	self.focallen = .5/math.tan(vfov/2)
	self.pos = Vector:new(0, 0, 0)
	self.rot = Quaternion:fromAngle(0, 0, 0);
end


-- UGLY OPTIMIZATION ZONE BELOW

local sqrt = math.sqrt
local nverts, sverts, depth = {}, {}, {}

local tempvec, edgeo, edget, avg, lightvec, lightnorm = Vector:new(0, 0, 0),
	Vector:new(0, 0, 0), Vector:new(0, 0, 0), Vector:new(0, 0, 0),
	Vector:new(0, 0, 0), Vector:new(0, 0, 2)
-- Draw a model
function Camera:draw(mdl)
	love.graphics.push()
	love.graphics.translate(hw, hh)
	love.graphics.scale(love.graphics.getWidth())

	local depthn = 0
	local flen, rot = self.focallen, self.rot
	local mrot = mdl.rot
	local mpos = mdl.pos-self.pos

	lightvec = self.rot:fastrotate(Vector(0, 0, 2) - self.pos)

	for i = 1, #mdl.vertices do
		if not nverts[i] then nverts[i] = Vector:new() sverts[i] = {0, 0} end
		local nv = nverts[i]
		tempvec.x, tempvec.y, tempvec.z = mrot:inlinerotate(mdl.vertices[i])
		nv.x, nv.y, nv.z = rot:inlinerotate(tempvec:fastadd(tempvec, mpos))

		sverts[i].x = nv.x * (flen/nv.z)
		sverts[i].y = nv.y * (flen/nv.z)

		if nverts[i].z < 0 then sverts[i].x = math.huge sverts[i].y = math.huge end
	end

	for i = 1, #mdl.faces do
		local v = mdl.faces[i]
		local n1, n2, n3 = nverts[v[1]], nverts[v[2]], nverts[v[3]]
		avg.x, avg.y, avg.z = 
			(n1.x+n2.x+n3.x)/3,
			(n1.y+n2.y+n3.y)/3,
			(n1.z+n2.z+n3.z)/3

		edgeo = edgeo:fastsub(n3, n1)
		edget = edget:fastsub(n3, n2)	

		local tempvec = tempvec:fastcross(edgeo, edget)
		tempvec:fastnormal(tempvec)
		local ang = n1:dot(tempvec)

		lightnorm:fastsub(lightvec, avg)
		lightnorm:fastnormal(lightnorm)
		local l = math.max(tempvec:dot(lightnorm), 0)

		if ang < 0 then
			love.graphics.setColor(mdl.color.x*l*255, mdl.color.y*l*255, mdl.color.z*l*255)
			love.graphics.triangle("fill", 
				sverts[v[1]].x, sverts[v[1]].y,
				sverts[v[2]].x, sverts[v[2]].y,
				sverts[v[3]].x, sverts[v[3]].y
			)
		end
	end

	love.graphics.pop()
end

function Camera:drawsorted(mdl)
	love.graphics.push()
	love.graphics.translate(hw, hh)
	love.graphics.scale(love.graphics.getWidth())

	local flen, rot = self.focallen, self.rot
	local mrot = mdl.rot
	local mpos = mdl.pos-self.pos

	lightvec = self.rot:fastrotate(Vector(0, 0, 2) - self.pos)

	if not nverts[mdl] then 
		nverts[mdl] = {}
		sverts[mdl] = {}
		depth[mdl] = {}

		for i = 1, #mdl.faces do
			depth[mdl][i] = {0, 0}
		end
	end

	local depth = depth[mdl]

	for i = 1, #mdl.vertices do
		if not nverts[i] then nverts[i] = Vector:new() sverts[i] = {0, 0} end
		local nv = nverts[i]
		tempvec.x, tempvec.y, tempvec.z = mrot:inlinerotate(mdl.vertices[i])
		nv.x, nv.y, nv.z = rot:inlinerotate(tempvec:fastadd(tempvec, mpos))

		sverts[i].x = nv.x * (flen/nv.z)
		sverts[i].y = nv.y * (flen/nv.z)

		if nverts[i].z < 0 then sverts[i].x = math.huge sverts[i].y = math.huge end
	end

	local td = depth[#mdl.faces+1]
	depth[#mdl.faces+1] = nil
	for i = 1, #mdl.faces do
		local v = mdl.faces[i]
		local v1 = v[1]

		n1, n2, n3 = nverts[v1], nverts[v[2]], nverts[v[3]]

		avg.x, avg.y, avg.z = 
			(n1.x+n2.x+n3.x)/3,
			(n1.y+n2.y+n3.y)/3,
			(n1.z+n2.z+n3.z)/3

		--print(i)
		depth[i][1] = i
		depth[i][2] = sqrt(avg.x*avg.x+avg.y*avg.y+avg.z*avg.z)
	end

	table.sort(depth, function(a,b) return a[2]<b[2] end)

	for i = #depth, 1, -1 do
		local v = mdl.faces[depth[i][1]]
		local n1, n2, n3 = nverts[v[1]], nverts[v[2]], nverts[v[3]]
		avg.x, avg.y, avg.z = 
			(n1.x+n2.x+n3.x)/3,
			(n1.y+n2.y+n3.y)/3,
			(n1.z+n2.z+n3.z)/3

		edgeo = edgeo:fastsub(n3, n1)
		edget = edget:fastsub(n3, n2)	

		tempvec:fastcross(edgeo, edget)
		tempvec:fastnormal(tempvec)
		local ang = n1:dot(tempvec)

		lightnorm:fastsub(lightvec, avg)
		lightnorm:fastnormal(lightnorm)
		local l = math.min(math.max(tempvec:dot(lightnorm), 0) + .2, 1)

		if ang < 0 then
			love.graphics.setColor(	math.min(mdl.color.x*l*255, 255),
									math.min(mdl.color.y*l*255, 255),
									math.min(mdl.color.z*l*255, 255) )

			love.graphics.polygon("fill", 
				sverts[v[1]].x, sverts[v[1]].y,
				sverts[v[2]].x, sverts[v[2]].y,
				sverts[v[3]].x, sverts[v[3]].y
			)
		end
	end

	love.graphics.pop()
end