---@module "ragdollpuppeteer.constants"
local constants = include("ragdollpuppeteer/constants.lua")
include("shared.lua")

---@return Color, IMaterial
function ENT:GetPuppeteerAppearance()
	---@type Entity
	local puppeteer = self.puppeteers[1]
	-- We store this material in ui.lua
	---@diagnostic disable-next-line
	local material = puppeteer.ragdollpuppeteer_currentMaterial or constants.PUPPETEER_MATERIAL
	return puppeteer:GetColor(), material
end

function ENT:DrawTranslucent()
	if not self.boxMin then
		return
	end

	local color, material = self:GetPuppeteerAppearance()
	-- print(color, material)

	render.SetMaterial(material)
	render.DrawBox(self:GetPos(), self:GetAngles(), self.boxMin, self.boxMax, color)
end
