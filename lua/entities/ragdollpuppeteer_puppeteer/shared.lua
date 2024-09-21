ENT.Type = "anim"
ENT.Base = "base_anim"
ENT.PrintName = "Ragdoll Puppeteer"
ENT.AutomaticFrameAdvance = true
ENT.PhysgunDisabled = true

function ENT:Think()
	self:NextThink(CurTime())
	return true
end
