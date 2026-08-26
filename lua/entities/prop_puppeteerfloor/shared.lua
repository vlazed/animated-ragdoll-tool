---@module "ragdollpuppeteer.lib.vendor"
local vendor = include("ragdollpuppeteer/lib/vendor.lua")
---@module "ragdollpuppeteer.constants"
local constants = include("ragdollpuppeteer/constants.lua")
---@module "ragdollpuppeteer.lib.helpers"
local helpers = include("ragdollpuppeteer/lib/helpers.lua")

---@class PuppeteerFloor: ENT
local ENT = ENT

ENT.Type = "anim"
ENT.Base = "base_gmodentity"

ENT.PrintName = "Ragdoll Puppeteer Floor"
ENT.Author = "vlazed"

ENT.Purpose = "Control the position and rotation of the puppeteer using the floor"
ENT.Instructions = "Set the list of puppeteers to move"
ENT.Spawnable = false
ENT.Editable = true
ENT.RenderGroup = RENDERGROUP_TRANSLUCENT

local LOOKAHEAD = 2
local RECOVER_DELAY = 2
local RECOVERY_DISTANCE = 500
local FLOOR_THICKNESS = 1
local LOCAL_INFRONT = Vector(100, 0, 10)
local VECTOR_UP = Vector(0, 0, 1)
local RAGDOLL_HEIGHT_DIFFERENCE = constants.RAGDOLL_HEIGHT_DIFFERENCE
local PUPPETEER_MATERIAL_IGNOREZ = constants.PUPPETEER_MATERIAL_IGNOREZ
local PUPPETEER_MATERIAL = constants.PUPPETEER_MATERIAL
local INVISIBLE_MATERIAL = constants.INVISIBLE_MATERIAL
local projectVectorToPlane = helpers.projectVectorToPlane
local floorCorrect = helpers.floorCorrect

local puppeteerIgnoreZ = GetConVar("ragdollpuppeteer_ignorez")
local puppeteerShow = GetConVar("ragdollpuppeteer_showpuppeteer")
local attachToGround = GetConVar("ragdollpuppeteer_attachtoground")
local anySurface = GetConVar("ragdollpuppeteer_anysurface")

function ENT:SetupDataTables()
	local scale = math.max(
		self.puppet and self.puppet.SavedBoneMatrices and self.puppet.SavedBoneMatrices[0]:GetScale():Unpack() or 1
	) * 100

	-- Wow this looks ugly lmao
	self:NetworkVar("Float", 0, "Height", {
		KeyName = "height",
		Edit = { order = 1, category = "Offset", min = -scale * 100, max = scale * 100, type = "Float" },
	})
	self:NetworkVar(
		"Float",
		1,
		"Pitch",
		{ KeyName = "pitch", Edit = { order = 2, category = "Offset", min = -180, max = 180, type = "Float" } }
	)
	self:NetworkVar(
		"Float",
		2,
		"Yaw",
		{ KeyName = "yaw", Edit = { order = 3, category = "Offset", min = -180, max = 180, type = "Float" } }
	)
	self:NetworkVar(
		"Float",
		3,
		"Roll",
		{ KeyName = "roll", Edit = { order = 4, category = "Offset", min = -180, max = 180, type = "Float" } }
	)
	self:NetworkVar("Float", 4, "MaxPoseParameterSpeed", {
		KeyName = "maxposeparameterspeed",
		Edit = { order = 5, category = "Offset", min = 0, max = 1e4, type = "Float" },
	})

	self:NetworkVarNotify("Pitch", self.UpdateAngleOffset)
	self:NetworkVarNotify("Yaw", self.UpdateAngleOffset)
	self:NetworkVarNotify("Roll", self.UpdateAngleOffset)

	if self.puppeteers and self.puppeteers[#self.puppeteers] then
		---@type RagdollPuppeteer
		local puppeteer = self.puppeteers[#self.puppeteers]
		for i = 0, puppeteer:GetNumPoseParameters() - 1 do
			local min, max = puppeteer:GetPoseParameterRange(i)
			local name = puppeteer:GetPoseParameterName(i)
			self:NetworkVar("Float", 5 + i, name, {
				KeyName = name,
				Edit = { category = "Pose Parameters", min = min, max = max, type = "Float", order = i },
			})
		end
	end
end

function ENT:GetPoseParameters()
	local data = {}
	if self.puppeteers and self.puppeteers[#self.puppeteers] then
		---@type RagdollPuppeteer
		local puppeteer = self.puppeteers[#self.puppeteers]
		for i = 0, puppeteer:GetNumPoseParameters() - 1 do
			local name = puppeteer:GetPoseParameterName(i)
			data[name] = puppeteer:GetPoseParameter(name)
		end
	end
	return data
end

---@enum MovementType
local movementType = {
	YAW = 0, -- HL2: they run constantly but change their movement direction
	YAW_SCALE = 1, -- L4D: their movement is scaled by movement_scale, but they can change their movement direction
	XY = 2, -- TF2: their movement scales their x and y pose parameters
	XY_SCALE = 3, -- TF2: some robots
	XY_YAW_SCALE = 4, -- TF2: some robots
}

local movementPoseParameters = {
	["move_scale"] = movementType.YAW_SCALE,
	["move_yaw"] = movementType.YAW,
	["move_x"] = movementType.XY,
	["move_y"] = movementType.XY,
}

local movementFunctions = {
	---@param ent PuppeteerFloor
	---@param velocity Vector
	[movementType.YAW] = function(ent, velocity)
		local up = ent:GetUp()
		local v = velocity:GetNormalized()
		local forward = ent:GetForward()
		local angle = math.deg(math.atan2(forward:Cross(v):Dot(up), forward:Dot(v)))

		---@diagnostic disable
		if isfunction(ent.Setmove_yaw) then
			ent:Setmove_yaw(angle)
		end
		---@diagnostic enable
	end,
	---@param ent PuppeteerFloor
	---@param velocity Vector
	[movementType.YAW_SCALE] = function(ent, velocity)
		local up = ent:GetUp()
		local v = velocity:GetNormalized()
		local forward = ent:GetForward()
		local angle = math.deg(math.atan2(forward:Cross(v):Dot(up), forward:Dot(v)))

		---@diagnostic disable
		if isfunction(ent.Setmove_yaw) and isfunction(ent.Setmove_scale) then
			ent:Setmove_yaw(angle)
			ent:Setmove_scale(velocity:Length())
		end
		---@diagnostic enable
	end,
	---@param ent PuppeteerFloor
	---@param velocity Vector
	[movementType.XY] = function(ent, velocity)
		local x = ent:GetForward():Dot(velocity)
		local y = ent:GetRight():Dot(velocity)

		local maxSpeed = ent:GetMaxPoseParameterSpeed()
		x, y = x / maxSpeed, y / maxSpeed

		---@diagnostic disable
		if isfunction(ent.Setmove_x) then
			ent:Setmove_x(x)
			ent:Setmove_y(y)
		end
		---@diagnostic enable
	end,
	---@param ent PuppeteerFloor
	---@param velocity Vector
	[movementType.XY_SCALE] = function(ent, velocity)
		local x = ent:GetForward():Dot(velocity)
		local y = ent:GetRight():Dot(velocity)

		---@diagnostic disable
		if isfunction(ent.Setmove_scale) and isfunction(ent.Setmove_x) and isfunction(ent.Setmove_y) then
			ent:Setmove_scale(velocity:Length())
			ent:Setmove_x(x)
			ent:Setmove_y(y)
		end
		---@diagnostic enable
	end,
	---@param ent PuppeteerFloor
	---@param velocity Vector
	[movementType.XY_YAW_SCALE] = function(ent, velocity)
		local up = ent:GetUp()
		local forward = ent:GetForward()
		local x = forward:Dot(velocity)
		local y = ent:GetRight():Dot(velocity)

		local v = velocity:GetNormalized()
		local angle = math.deg(math.atan2(forward:Cross(v):Dot(up), forward:Dot(v)))

		---@diagnostic disable
		if
			isfunction(ent.Setmove_yaw)
			and isfunction(ent.Setmove_scale)
			and isfunction(ent.Setmove_x)
			and isfunction(ent.Setmove_y)
		then
			ent:Setmove_yaw(angle)
			ent:Setmove_scale(velocity:Length())
			ent:Setmove_x(x)
			ent:Setmove_y(y)
		end
		---@diagnostic enable
	end,
}

function ENT:GetMovementPoseParameters()
	if not self.movementParameters then
		self.movementParameters = {}
		self.movementType = -1
		local dt = self:GetNetworkVars()
		for move, type in pairs(movementPoseParameters) do
			if dt[move] then
				table.insert(self.movementParameters, move)
				self.movementType = type
				if #self.movementParameters == 4 then
					self.movementType = movementType.XY_YAW_SCALE
				elseif type == movementType.YAW_SCALE and self.movementType == movementType.YAW then
					self.movementType = movementType.YAW_SCALE
				elseif type == movementType.XY_SCALE and self.movementType == movementType.XY then
					self.movementType = movementType.XY_SCALE
				end
			end
		end
	end

	return self.movementParameters, self.movementType
end

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

	self:SetupDataTables()
end

---Set the floor's puppet
---@param puppet Entity
function ENT:SetPuppet(puppet)
	self.puppet = puppet
end

---Get the floor's puppet
---@return Entity | ResizedRagdoll
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
		if IsValid(puppeteer) then
			puppeteer:Remove()
		end
		self.puppeteers[i] = nil
	end
end

function ENT:OnRemove()
	self:RemovePuppeteers()
end

function ENT:SetAngleOffset(angle)
	self.angleOffset = angle
	self:SetPitch(angle.p) ---@diagnostic disable-line
	self:SetYaw(angle.y) ---@diagnostic disable-line
	self:SetRoll(angle.r) ---@diagnostic disable-line
end

function ENT:UpdateAngleOffset()
	self.angleOffset = Angle(self:GetPitch(), self:GetYaw(), self:GetRoll()) ---@diagnostic disable-line
end

function ENT:GetAngleOffset()
	return self.angleOffset
end

local propertyOrToolFilters = {
	["remover"] = true, -- Remove Property or Remover Tool
	["rb655_dissolve"] = true, -- From Extended Properties
	-- FIXME: How come the EGSSpawn or Creator Spawn aren't removed?
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
			notification.AddLegacy(language.GetPhrase("ui.ragdollpuppeteer.notify.tooldisabled"), NOTIFY_ERROR, 3)
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

function ENT:GetPuppeteerRootScale()
	return self.puppeteerRootScale
end

function ENT:SetPuppeteerRootScale(newScale)
	self.puppeteerRootScale = newScale
end

function ENT:PushQueue(pos)
	table.insert(self.positionQueue, 1, pos)
	if #self.positionQueue > self.maxPositions then
		table.remove(self.positionQueue, #self.positionQueue)
	end
end

---@param queue Vector[]
---@return Vector
local function vectorAverage(queue)
	local total = #queue
	local avg = vector_origin
	for i = 1, total do
		avg = avg + queue[i]
	end

	return avg / total
end

---@param puppeteer RagdollPuppeteer?
---@return Vector puppeteerVelocity
function ENT:GetPuppeteerVelocity(puppeteer)
	if not self.previousPuppeteerPosition then
		self.previousPuppeteerPosition = self:GetPos()
		return vector_origin
	end

	local currentPos = puppeteer:GetPos()
	local time = FrameTime() == 0 and 1 or FrameTime()
	local velocity = (currentPos - self.previousPuppeteerPosition) / time
	self.previousPuppeteerPosition = currentPos
	return velocity
end

---@return Vector puppeteerVelocity
function ENT:GetFloorVelocity()
	if not self.previousFloorPosition then
		self.previousFloorPosition = self:GetPos()
		return vector_origin
	end

	local currentPos = self:GetPos()
	if SERVER then
		currentPos = self:GetPhysicsObject():GetPos()
	end
	local time = FrameTime() == 0 and 1 or FrameTime()
	local velocity = (currentPos - self.previousFloorPosition) / time
	self.previousFloorPosition = currentPos
	return velocity
end

---@param newScale number
function ENT:SetPuppeteerScale(newScale)
	local puppeteers = self.puppeteers
	---@cast puppeteers RagdollPuppeteer[]
	for _, puppeteer in ipairs(puppeteers) do
		puppeteer:SetModelScale(newScale)
	end
end

function ENT:Think()
	if not self.puppeteers or #self.puppeteers == 0 or not self.boxMax then
		self:NextThink(CurTime())
		return true
	end

	if not self:GetAngleOffset() then
		self:SetAngleOffset(angle_zero)
	end
	attachToGround = attachToGround or GetConVar("ragdollpuppeteer_attachtoground")
	anySurface = anySurface or GetConVar("ragdollpuppeteer_anysurface")

	local shouldAttachToGround = attachToGround:GetInt() > 0
	local shouldAttachToAnySurface = anySurface:GetInt() > 0

	local puppeteers = self.puppeteers
	---@cast puppeteers RagdollPuppeteer[]

	local check = puppeteers[#puppeteers]
	local mainPuppeteer = IsValid(check) and check

	if not self.puppeteerHeight and mainPuppeteer then
		self.puppeteerHeight = helpers.getRootHeightDifferenceOf(mainPuppeteer)
	end

	for _, puppeteer in ipairs(puppeteers) do
		if IsValid(puppeteer) then
			local heightOffset = self:GetHeight() or 0 ---@diagnostic disable-line
			local puppeteerRootScale = self:GetPuppeteerRootScale() or vector_origin
			for i = 0, puppeteer:GetNumPoseParameters() - 1 do
				local poseName = puppeteer:GetPoseParameterName(i)
				if self["Get" .. poseName] then
					puppeteer:SetPoseParameter(poseName, self["Get" .. poseName](self))
					if CLIENT then
						puppeteer:InvalidateBoneCache()
					end
				end
			end
			puppeteer:SetPos(self:GetPos())
			puppeteer:SetPos(
				self:LocalToWorld((heightOffset + VECTOR_UP:Dot(puppeteerRootScale) - FLOOR_THICKNESS) * VECTOR_UP)
			)
			local angleOffset = self:GetAngleOffset() or angle_zero
			puppeteer:SetAngles(self:GetAngles() + angleOffset)

			self.groundNormal = vector_up
			if shouldAttachToGround then
				local rayDirection = shouldAttachToAnySurface and -self:GetAngles():Up() or -VECTOR_UP
				---@type TraceResult
				local tr = util.TraceLine({
					start = self:GetPos(),
					endpos = rayDirection * 1e9,
					filter = {
						self,
						puppeteer,
						self.puppet,
						self.puppet:GetParent(),
						unpack(puppeteers),
						"NPC",
						"prop_resizedragdoll_physobj",
					},
				})
				if tr.HitPos then
					puppeteer:SetPos(tr.HitPos + tr.HitNormal * (heightOffset + VECTOR_UP:Dot(puppeteerRootScale)))
					local projectedForward =
						projectVectorToPlane(self:GetAngles():Forward(), tr.HitNormal):GetNormalized()

					puppeteer:SetAngles(projectedForward:AngleEx(tr.HitNormal))
					puppeteer:SetAngles(puppeteer:LocalToWorldAngles(angleOffset))
					self.hitPos = tr.HitPos
					self.hitNormal = tr.HitNormal
				end
			else
				self.hitPos = nil
				self.hitNormal = nil
			end

			if self.puppeteerHeight > RAGDOLL_HEIGHT_DIFFERENCE then
				floorCorrect(puppeteer, puppeteer, 1, self.puppeteerHeight)
			end
		end
	end

	if mainPuppeteer then
		local puppeteer = mainPuppeteer
		local puppet = self.puppet

		local puppeteerVelocity = self:GetPuppeteerVelocity(puppeteer)
		local owner = CLIENT and LocalPlayer() or self:GetPlayerOwner()
		if tobool(owner:GetInfo("ragdollpuppeteer_autopose_locomotion_parameters")) then
			local poseParameters, movementType = self:GetMovementPoseParameters()
			local movementFunction = movementFunctions[movementType]
			local floorVelocity = self:GetFloorVelocity()

			if movementFunction then
				movementFunction(self, (floorVelocity + puppeteerVelocity) * 0.5)
			end
		end

		if CLIENT then
			puppeteerShow = puppeteerShow or GetConVar("ragdollpuppeteer_showpuppeteer")
			puppeteerIgnoreZ = puppeteerIgnoreZ or GetConVar("ragdollpuppeteer_ignorez")
			local showPuppeteer = puppeteerShow:GetInt() > 0
			local ignoreZOn = puppeteerIgnoreZ:GetInt() > 0 and PUPPETEER_MATERIAL_IGNOREZ or PUPPETEER_MATERIAL
			self:SetColor(puppeteer:GetColor())
			if showPuppeteer then
				puppeteer:SetMaterial(ignoreZOn:GetName())
				puppeteer.ragdollpuppeteer_currentMaterial = ignoreZOn
			else
				puppeteer:SetMaterial(INVISIBLE_MATERIAL:GetName())
				puppeteer.ragdollpuppeteer_currentMaterial = constants.INVISIBLE_MATERIAL
			end
		else
			local ownerId = IsValid(owner) and owner:UserID()

			if
				IsValid(puppet)
				and ownerId
				and RAGDOLLPUPPETEER_PLAYERS[ownerId]
				and IsValid(puppet:GetPhysicsObject())
			then
				local physObj = puppet:GetPhysicsObject()
				local ping = owner:Ping() * 1e-3
				local rootPosition = puppeteer.rootPos
					or (
						puppeteer:GetBoneMatrix(puppeteer:TranslatePhysBoneToBone(0))
							and puppeteer:GetBoneMatrix(puppeteer:TranslatePhysBoneToBone(0)):GetTranslation()
						or physObj:GetPos()
					)
				local rootDelta = rootPosition - physObj:GetPos()

				if tobool(owner:GetInfo("ragdollpuppeteer_smooth")) then
					-- Use the puppeteer's velocity instead. This allows attach to ground movement to be smooth
					local delta = puppeteerVelocity * (FrameTime() + ping)
					-- Fix jittering by only moving the puppet when the floor moves
					if RAGDOLLPUPPETEER_PLAYERS[ownerId].playbackEnabled and delta:Length() > 0 then
						-- Instead of relying on the latency from the client to send the position, let's
						-- predict the position using the velocity and the current physics object.
						-- Fixes choppy root movement.

						-- Look ahead of the physobj position and interpolate to our root position. Eliminates choppy root movement
						local newPos =
							vendor.LerpLinearVector(rootPosition + LOOKAHEAD * delta, rootPosition, FrameTime())
						self:PushQueue(newPos)

						-- Perform a average over the window of positions to filter out jitter
						local avgPos = vectorAverage(self.positionQueue)
						physObj:SetPos(avgPos, true)
					else
						physObj:SetPos(rootPosition, true)
					end
				end
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
			if CLIENT then
				print("[Ragdoll Puppeteer] " .. language.GetPhrase("ui.ragdollpuppeteer.notify.outofbounds"))
			end
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
	local length = math.abs(corner.x) + 5
	local width = math.abs(corner.y) + 5
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
