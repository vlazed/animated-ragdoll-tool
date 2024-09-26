---@module "ragdollpuppeteer.constants"
local constants = include("ragdollpuppeteer/constants.lua")
local util = {}

local RAGDOLL_HEIGHT_DIFFERENCE = constants.RAGDOLL_HEIGHT_DIFFERENCE

---Big ragdolls such as the hl2 strider may not stand from the ground up. This compensates for that by checking
---if the difference between the puppeteer's set position and its lower position from the AABB is significantly
---different
---@param targetEntity Entity
---@param referenceEntity Entity?
---@param sign integer
function util.floorCorrect(targetEntity, referenceEntity, sign)
	sign = sign or 1
	referenceEntity = IsValid(referenceEntity) and referenceEntity or targetEntity
	local min = referenceEntity:WorldSpaceAABB()
	local zMin = min.z
	local height = referenceEntity:GetPos().z
	local difference = math.abs(height - zMin)
	if difference > RAGDOLL_HEIGHT_DIFFERENCE then
		targetEntity:SetPos(referenceEntity:GetPos() + sign * Vector(0, 0, difference))
	end
end

return util
