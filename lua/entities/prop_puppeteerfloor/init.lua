AddCSLuaFile("cl_init.lua")
AddCSLuaFile("shared.lua")

include("shared.lua")

function ENT:Initialize()
	self:SetModel("models/props_junk/watermelon01.mdl")
	-- self:PhysicsInitConvex(POINTS)
	-- self:SetMoveType(MOVETYPE_VPHYSICS)
	-- self:SetSolid(SOLID_VPHYSICS)
	-- self:SetCollisionGroup(COLLISION_GROUP_WORLD)

	-- local phys = self:GetPhysicsObject()
	-- if phys:IsValid() then
	-- 	phys:Wake()
	-- end
end
