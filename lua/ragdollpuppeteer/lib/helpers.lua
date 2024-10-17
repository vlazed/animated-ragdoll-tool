---@module "ragdollpuppeteer.constants"
local constants = include("ragdollpuppeteer/constants.lua")
local helpers = {}

local RAGDOLL_HEIGHT_DIFFERENCE = constants.RAGDOLL_HEIGHT_DIFFERENCE

---@param color Color
---@return string
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

---@param str string
---@return Color
function helpers.getColorFromString(str)
	local separator = " "
	if string.find(str, ",") then
		separator = ","
	end
	local colors = string.Split(str, separator)
	return Color(colors[1] or 0, colors[2] or 0, colors[3] or 64, 100)
end

---@param entity Entity
---@return number
function helpers.getRootHeightDifferenceOf(entity)
	local min = entity:WorldSpaceAABB()
	local zMin = min.z
	local height = entity:GetPos().z
	return math.abs(height - zMin)
end

---Big ragdolls such as the hl2 strider may not stand from the ground up. This compensates for that by checking
---if the difference between the puppeteer's set position and its lower position from the AABB is significantly
---different
---@param targetEntity Entity
---@param referenceEntity Entity?
---@param sign integer?
---@param difference number?
function helpers.floorCorrect(targetEntity, referenceEntity, sign, difference)
	sign = sign or 1
	referenceEntity = IsValid(referenceEntity) and referenceEntity or targetEntity
	difference = difference or helpers.getRootHeightDifferenceOf(referenceEntity)
	if difference > RAGDOLL_HEIGHT_DIFFERENCE then
		targetEntity:SetPos(referenceEntity:GetPos() + sign * Vector(0, 0, difference))
	end
end

return helpers
