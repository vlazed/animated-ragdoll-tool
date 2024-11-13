AddCSLuaFile("cl_init.lua")
AddCSLuaFile("shared.lua")

include("shared.lua")
---@module "ragdollpuppeteer.lib.pid"
local pid = include("ragdollpuppeteer/lib/pid.lua")

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
	self.pid = pid.new(-100, 100, 1.25, 2.5, 0.01)
end

---@param ply any
function ENT:SetPlayerOwner(ply)
	self.playerOwner = ply
end

---@return Player
function ENT:GetPlayerOwner()
	return self.playerOwner
end
