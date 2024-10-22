---@module "ragdollpuppeteer.constants"
local constants = include("ragdollpuppeteer/constants.lua")
include("shared.lua")

local BLANK_COLOR = Color(255, 255, 255, 255)
local BLANK_MATERIAL = Material("debug/white")

---@return Color, IMaterial
function ENT:GetPuppeteerAppearance()
	---@type RagdollPuppeteer
	local puppeteer = self.puppeteers[#self.puppeteers]
	-- We store this material in ui.lua
	if IsValid(puppeteer) then
		local material = puppeteer.ragdollpuppeteer_currentMaterial or constants.PUPPETEER_MATERIAL
		return puppeteer:GetColor(), material
	else
		return BLANK_COLOR, BLANK_MATERIAL
	end
end

function ENT:DrawTranslucent()
	if not self.boxMin then
		return
	end

	local color, material = self:GetPuppeteerAppearance()

	render.SetMaterial(material)
	render.DrawBox(self:GetPos(), self:GetAngles(), self.boxMin, self.boxMax, color)
	if self.hitPos then
		local inverted = Color(255 - color.r, 255 - color.g, 255 - color.b)
		if material:GetName() ~= constants.INVISIBLE_MATERIAL:GetName() then
			render.DrawLine(self:GetPos(), self.hitPos, inverted, false)
		end
	end
end
