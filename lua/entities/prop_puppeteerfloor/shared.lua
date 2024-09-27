---@module "ragdollpuppeteer.constants"
local constants = include("ragdollpuppeteer/constants.lua")
---@module "ragdollpuppeteer.util"
local util = include("ragdollpuppeteer/lib/helpers.lua")

ENT.Type = "anim"
ENT.Base = "base_gmodentity"

ENT.PrintName = "Ragdoll Puppeteer Floor"
ENT.Author = "vlazed"

ENT.Purpose = "Control the position and rotation of the puppeteer using the floor"
ENT.Instructions = "Set the list of puppeteers to move"
ENT.Spawnable = true
ENT.RenderGroup = RENDERGROUP_TRANSLUCENT

local RECOVER_DELAY = 2
local RECOVERY_DISTANCE = 500
local FLOOR_THICKNESS = 1
local LOCAL_INFRONT = Vector(100, 0, 10)
local floorCorrect = util.floorCorrect

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

---@param puppet Entity
function ENT:SetPuppet(puppet)
	self.puppet = puppet
end

---@return Entity
function ENT:GetPuppet()
	return self.puppet
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
		if IsValid(puppeteer) then
			puppeteer:SetPos(self:GetPos() - Vector(0, 0, FLOOR_THICKNESS))
			puppeteer:SetAngles(self:GetAngles())
			floorCorrect(puppeteer)
		end
	end

	if CLIENT then
		local physobj = self:GetPhysicsObject()

		if IsValid(physobj) then
			physobj:SetPos(self:GetPos())
			physobj:SetAngles(self:GetAngles())
		end
	else
		local owner = self:GetPlayerOwner()
		local shouldEnableCollisions = GetConVar("ragdollpuppeteer_floor_worldcollisions")
			and GetConVar("ragdollpuppeteer_floor_worldcollisions"):GetInt() > 0
		local physobj = self:GetPhysicsObject()

		if IsValid(physobj) then
			---@diagnostic disable-next-line
			physobj:EnableCollisions(shouldEnableCollisions)
		end

		local now = CurTime()
		self.shouldRecover = not self:IsInWorld()
		local distance = self:GetPos():Distance(owner:GetPos())
		if self.shouldRecover and now - self.lastRecoveryTime > RECOVER_DELAY and distance > RECOVERY_DISTANCE then
			print("Recovering floor")
			if IsValid(self.puppet) then
				self:SetPos(self.puppet:GetPos())
			elseif IsValid(owner) then
				self:SetPos(owner:LocalToWorld(LOCAL_INFRONT))
			else
				self:SetPos(Vector(0, 0, 0))
			end
			if IsValid(physobj) then
				physobj:Sleep()
			end
			self.lastRecoveryTime = now
		end
	end

	self:NextThink(CurTime())

	return true
end

---@param puppeteer Entity
function ENT:SetPhysicsSize(puppeteer)
	if not puppeteer or not IsValid(puppeteer) then
		return
	end
	local corner = puppeteer:OBBMins()

	local thickness = FLOOR_THICKNESS
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
		end
	end
end
