---@module "ragdollpuppeteer.constants"
local constants = include("ragdollpuppeteer/constants.lua")
local helpers = {}

local RAGDOLL_HEIGHT_DIFFERENCE = constants.RAGDOLL_HEIGHT_DIFFERENCE

---@param color Color
---@return string colorString A Color formatted as a string ("# # #" or "#,#,#").
function helpers.getStringFromColor(color)
	local str = ("%d %d %d"):format(color.r, color.g, color.b)
	return str
end

---@param str string A Color formatted as a string ("# # #" or "#,#,#").
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
---@return number rootHeightDifference The half root height difference of the entity
function helpers.getRootHeightDifferenceOf(entity)
	local min = entity:WorldSpaceAABB()
	local zMin = min.z
	local height = entity:GetPos().z
	return math.abs(height - zMin)
end

---Big ragdolls such as the hl2 strider may not stand from the ground up. This compensates for that by checking
---if the difference between the puppeteer's set position and its lower position from the AABB is significantly
---different
---@param targetEntity Entity The entity to correctly offset from the floor
---@param referenceEntity Entity? The entity as a basis for offset measurements
---@param sign integer? The direction to offset the entity
---@param difference number? The half-height of the entity's bounding box
function helpers.floorCorrect(targetEntity, referenceEntity, sign, difference)
	sign = sign or 1
	referenceEntity = IsValid(referenceEntity) and referenceEntity or targetEntity
	difference = difference or helpers.getRootHeightDifferenceOf(referenceEntity)
	if difference > RAGDOLL_HEIGHT_DIFFERENCE then
		targetEntity:SetPos(referenceEntity:GetPos() + sign * Vector(0, 0, difference))
	end
end

return helpers
