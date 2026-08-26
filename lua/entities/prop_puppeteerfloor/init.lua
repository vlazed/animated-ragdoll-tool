AddCSLuaFile("cl_init.lua")
AddCSLuaFile("shared.lua")

include("shared.lua")

---@class PuppeteerFloor
local ENT = ENT

function ENT:Initialize()
	self:SetModel("models/props_junk/watermelon01.mdl")
	self:DrawShadow(false)
	self.shouldRecover = false
	self.lastRecoveryTime = CurTime()
	self.puppeteers = {}
	self.puppet = NULL
	self.playerOwner = NULL
	self.angleOffset = angle_zero
	self.positionQueue = {}
	self.maxPositions = 4

	-- Set this to the default run speed
	self:SetMaxPoseParameterSpeed(400)
end

---@param ply any
function ENT:SetPlayerOwner(ply)
	self.playerOwner = ply
end

---@return Player
function ENT:GetPlayerOwner()
	return self.playerOwner
end
