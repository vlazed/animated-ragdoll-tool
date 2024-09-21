include("shared.lua")

function ENT:Initialize()
	self:PhysicsInit(SOLID_NONE)
	self:SetMoveType(MOVETYPE_NONE)
end

function ENT:Draw()
	self:DrawModel()
end
