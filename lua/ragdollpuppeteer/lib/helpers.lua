---@module "ragdollpuppeteer.constants"
local constants = include("ragdollpuppeteer/constants.lua")
local helpers = {}

local RAGDOLL_HEIGHT_DIFFERENCE = constants.RAGDOLL_HEIGHT_DIFFERENCE

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
