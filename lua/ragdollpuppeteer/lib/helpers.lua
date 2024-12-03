---@module "ragdollpuppeteer.constants"
local constants = include("ragdollpuppeteer/constants.lua")
local helpers = {}

local RAGDOLL_HEIGHT_DIFFERENCE = constants.RAGDOLL_HEIGHT_DIFFERENCE
local TOLERANCE = 5

---@param color Color Color to stringify
---@return string colorString A Color formatted as a string ("# # #" or "#,#,#").
function helpers.getStringFromColor(color)
	local str = ("%d %d %d"):format(color.r, color.g, color.b)
	return str
end

---@param v Vector Vector to project
---@param n Vector Normal vector of plane
---@return Vector projection Projection of vector on the plane
function helpers.projectVectorToPlane(v, n)
	local projection = v - v:Dot(n) / n:LengthSqr() ^ 2 * n
	return projection
end

---@param str string A Color formatted as a string ("# # #" or "#,#,#").
---@return Color color Parsed Color from string
function helpers.getColorFromString(str)
	local separator = " "
	if string.find(str, ",") then
		separator = ","
	end
	local colors = string.Split(str, separator)
	return Color(colors[1] or 0, colors[2] or 0, colors[3] or 64, 100)
end

---@param entity Entity Entity to find half root height difference
---@return number rootHeightDifference The half root height difference of the entity
function helpers.getRootHeightDifferenceOf(entity)
	local min = entity:WorldSpaceAABB()
	local zMin = min.z
	local height = entity:GetPos().z
	return math.abs(height - zMin)
end

local RED = Color(255, 0, 0)
---Big ragdolls such as the hl2 strider may not stand from the ground up. This compensates for that by checking
---if the difference between the puppeteer's set position and its lower position from the AABB is significantly
---different
---@param targetEntity Entity The entity to correctly offset from the floor
---@param floor Entity The entity as a basis for offset measurements
function helpers.floorCorrect(targetEntity, floor, floorPos, attachToGround)
	local min, max = targetEntity:GetRotatedAABB(targetEntity:OBBMins(), targetEntity:OBBMaxs())
	local startPos = targetEntity:LocalToWorld(vector_up * min.z)
	local endPos = targetEntity:LocalToWorld(vector_up * max.z)
	local distance = math.huge

	print(vector_up * min.z)
	print(vector_up * max.z)

	local count = 0
	debugoverlay.Line(startPos, endPos, 0, RED, true)
	debugoverlay.Sphere(floorPos, TOLERANCE, 0, constants.COLOR_BLUE, true)
	---@type TraceResult
	local tr = {}
	while distance > TOLERANCE and count < 5 do
		count = count + 1
		util.TraceLine({
			start = startPos,
			endPos = endPos,
			filter = { floor },
			whitelist = not attachToGround,
			ignoreworld = not attachToGround,
			output = tr,
		})
		if tr.Hit then
			local length = tr.HitPos:Distance(startPos)
			distance = floorPos:DistToSqr(tr.HitPos)
			debugoverlay.Sphere(tr.HitPos, 10, 0, RED, true)
			targetEntity:SetPos(targetEntity:LocalToWorld(vector_up * length))

			startPos = targetEntity:LocalToWorld(vector_up * min.z)
			endPos = targetEntity:LocalToWorld(vector_up * max.z)
		else
			break
		end
	end
	-- print(count)
end

return helpers
