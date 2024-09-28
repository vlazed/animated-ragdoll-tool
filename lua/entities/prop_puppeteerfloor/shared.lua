---@module "ragdollpuppeteer.constants"
local constants = include("ragdollpuppeteer/constants.lua")
---@module "ragdollpuppeteer.lib.helpers"
local helpers = include("ragdollpuppeteer/lib/helpers.lua")

ENT.Type = "anim"
ENT.Base = "base_gmodentity"

ENT.PrintName = "Ragdoll Puppeteer Floor"
ENT.Author = "vlazed"

ENT.Purpose = "Control the position and rotation of the puppeteer using the floor"
ENT.Instructions = "Set the list of puppeteers to move"
ENT.Spawnable = false
ENT.RenderGroup = RENDERGROUP_TRANSLUCENT

local RECOVER_DELAY = 2
local RECOVERY_DISTANCE = 500
local FLOOR_THICKNESS = 1
local LOCAL_INFRONT = Vector(100, 0, 10)
local RAGDOLL_HEIGHT_DIFFERENCE = constants.RAGDOLL_HEIGHT_DIFFERENCE
local floorCorrect = helpers.floorCorrect

---Add a table of puppeteers to the floor
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

---Set the floor's puppet
---@param puppet Entity
function ENT:SetPuppet(puppet)
	self.puppet = puppet
end

---Get the floor's puppet
---@return Entity
function ENT:GetPuppet()
	return self.puppet
end

---Clear the puppeteers but do not remove the entities.
function ENT:ClearPuppeteers()
	if not self.puppeteers then
		return
	end
	self.puppeteers = {}
end

---Remove the puppeteers and clear the entry
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

function ENT:SetAngleOffset(angle)
	self.angleOffset = angle
end

local propertyOrToolFilters = {
	["remover"] = true, -- Remove Property or Remover Tool
	["rb655_dissolve"] = true, -- From Extended Properties
	["creatorspawn"] = true, -- From Entity Group Spawner
	["egsspawn"] = true, -- From Entity Group Spawner
	["egs"] = true, -- From Entity Group Spawner
	["creator"] = true, -- From Entity Group Spawner
	["collision"] = true, -- We don't want this to interact with anything else
}

---Prevent the player from using the Remover tool on this entity
---@param ply Player
---@param tr table
---@param mode string
---@param tool table
---@param button number
---@return boolean
function ENT:CanTool(ply, tr, mode, tool, button)
	if propertyOrToolFilters[mode] then
		if CLIENT then
			notification.AddLegacy("This tool is disabled on the puppeteer!", NOTIFY_ERROR, 3)
		end
		return false
	end

	return true
end

--- Prevent the player from using the Remover from the context menu
---@param ply Player
---@param property string
---@return boolean
function ENT:CanProperty(ply, property)
	if propertyOrToolFilters[property] then
		return false
	end

	return true
end

function ENT:Think()
	if not self.puppeteers or #self.puppeteers == 0 or not self.boxMax then
		self:NextThink(CurTime())
		return true
	end

	local puppeteers = self.puppeteers
	---@cast puppeteers RagdollPuppeteer[]

	if puppeteers[1] and not self.height then
		self.height = helpers.getRootHeightDifferenceOf(puppeteers[1])
	end
	for _, puppeteer in ipairs(puppeteers) do
		if IsValid(puppeteer) then
			puppeteer:SetPos(self:GetPos() - Vector(0, 0, FLOOR_THICKNESS))
			if SERVER then
				puppeteer:SetAngles(self:GetAngles() + self.angleOffset)
			else
				local angleOffset = puppeteer.angleOffset or angle_zero
				puppeteer:SetAngles(self:GetAngles() + angleOffset)
			end
			if self.height > RAGDOLL_HEIGHT_DIFFERENCE then
				floorCorrect(puppeteer, puppeteer, 1, self.height)
			end
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
