ENT.Type = "anim"
ENT.Base = "base_gmodentity"

ENT.PrintName = "Ragdoll Puppeteer Floor"
ENT.Author = "vlazed"

ENT.Purpose = "Control the position and rotation of the puppeteer using the floor"
ENT.Instructions = "Set the list of puppeteers to move"
ENT.Spawnable = true
ENT.RenderGroup = RENDERGROUP_TRANSLUCENT

---@param puppeteerTable Entity[]
function ENT:AddPuppeteers(puppeteerTable)
	if #puppeteerTable == 0 then
		return
	end

	if not self.puppeteers then
		self.puppeteers = {}
	end
	for _, puppeteer in ipairs(puppeteerTable) do
		table.insert(self.puppeteers, puppeteer)
	end
end

function ENT:ClearPuppeteers()
	if not self.puppeteers then
		return
	end
	self.puppeteers = {}
end

function ENT:RemovePuppeteers()
	if not self.puppeteers then
		return
	end
	for i, puppeteer in ipairs(self.puppeteers) do
		puppeteer:Remove()
		self.puppeteers[i] = nil
	end
end

function ENT:OnRemove()
	self:RemovePuppeteers()
end

function ENT:Think()
	if not self.puppeteers or #self.puppeteers == 0 or not self.boxMax then
		self:NextThink(CurTime())
		return true
	end

	local puppeteers = self.puppeteers
	---@cast puppeteers Entity[]

	for _, puppeteer in ipairs(puppeteers) do
		puppeteer:SetPos(self:GetPos())
		puppeteer:SetAngles(self:GetAngles())
	end

	if CLIENT then
		local physobj = self:GetPhysicsObject()

		if IsValid(physobj) then
			physobj:SetPos(self:GetPos())
			physobj:SetAngles(self:GetAngles())
		end
	end

	self:NextThink(CurTime())

	return true
end

-- FIXME: Make custom collisions, SMH and RGM selections work

---@param puppeteer Entity
function ENT:SetPhysicsSize(puppeteer)
	if not puppeteer or not IsValid(puppeteer) then
		return
	end
	local corner = puppeteer:OBBMins()

	local thickness = 1
	local length = corner.x
	local width = corner.y
	local points = {
		Vector(length, width, thickness),
		Vector(length, width, -thickness),
		Vector(length, -width, thickness),
		Vector(length, -width, -thickness),
		Vector(-length, width, thickness),
		Vector(-length, width, -thickness),
		Vector(-length, -width, thickness),
		Vector(-length, -width, -thickness),
	}

	self.boxMax = Vector(length, width, thickness)
	self.boxMin = Vector(-length, -width, -thickness)

	self:PhysicsInitConvex(points)
	self:EnableCustomCollisions()

	if SERVER then
		self:SetMoveType(MOVETYPE_VPHYSICS)
		self:SetSolid(SOLID_VPHYSICS)
		self:SetCollisionGroup(COLLISION_GROUP_WORLD)
		local dist = self.boxMax:Distance(self.boxMin)

		local phys = self:GetPhysicsObject()
		if IsValid(phys) then
			phys:SetContents(CONTENTS_SOLID)
			phys:SetMass(dist)
			phys:Wake()
		end
	end
end
