---@type Entity
local ENT = ENT

ENT.Type = "anim"
ENT.Base = "base_gmodentity"

ENT.PrintName = "Ragdoll Puppeteer Entity"
ENT.Author = "vlazed"

ENT.Purpose = "Make a puppet follow the pose of itself"
ENT.Instructions = "Set the list of puppeteers to move"
ENT.Spawnable = false
ENT.Editable = false
ENT.RenderGroup = RENDERGROUP_TRANSLUCENT

function ENT:Think()
	self:NextThink(CurTime())

	return true
end
