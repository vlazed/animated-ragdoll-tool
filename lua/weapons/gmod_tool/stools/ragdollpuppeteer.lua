---@alias DefaultBonePose table<Vector, Angle, Vector, Angle>

---@module "ragdollpuppeteer.vendor"
local Vendor = include("ragdollpuppeteer/vendor.lua")

TOOL.Category = "Poser"
TOOL.Name = "#tool.ragdollpuppeteer.name"
TOOL.Command = nil
TOOL.ConfigName = ""
TOOL.ClientConVar["frame"] = 0
TOOL.ClientConVar["animatenonphys"] = "false"
TOOL.ClientConVar["updateposition_floors"] = "false"

if SERVER then
	util.AddNetworkString("onFrameChange")
	util.AddNetworkString("onSequenceChange")
	util.AddNetworkString("onAngleChange")
	util.AddNetworkString("onFrameNext")
	util.AddNetworkString("onFramePrevious")
	-- TODO: direct way to update client animation puppet
	util.AddNetworkString("updateClientPosition")
	util.AddNetworkString("removeClientAnimPuppeteer")
	util.AddNetworkString("queryDefaultBonePoseOfPuppet")
	util.AddNetworkString("queryNonPhysBonePoseOfPuppet")
	util.AddNetworkString("onPoseParamChange")
	util.AddNetworkString("onBoneFilterChange")
end

local EPSILON = 1e-3
local MINIMUM_VECTOR = Vector(-16384, -16384, -16384)
local MAX_PELVIS_LOOKUP = 4

local id = "ragdollpuppeteer_puppet"
local id2 = "ragdollpuppeteer_puppeteer"
local id3 = "ragdollpuppeteer_puppetCount"
local prevServerAnimPuppet = nil
local bonesReset = false
local defaultAngle = angle_zero
local filteredBones = {}

local function styleServerPuppeteer(puppeteer)
	puppeteer:SetColor(Color(255, 255, 255, 0))
	puppeteer:SetRenderMode(RENDERMODE_TRANSCOLOR)
	puppeteer:AddEffects(EF_NODRAW)
end

local function decompressJSONToTable(json)
	return util.JSONToTable(util.Decompress(json))
end

function TOOL:Think()
	-- Do not rebuild control panel for the same puppet
	local currentPuppet = self:GetAnimationPuppet()
	local physicsCount = self:GetPuppetPhysicsCount()

	if (IsValid(currentPuppet) and IsValid(prevServerAnimPuppet)) and currentPuppet == prevServerAnimPuppet then
		return
	end
	prevServerAnimPuppet = currentPuppet
	if CLIENT then
		-- FIXME: Left clicking after right clicking should still rebuild the control panel for the same entity
		self:RebuildControlPanel(currentPuppet, self:GetOwner(), physicsCount)
	end
end

---@return integer
function TOOL:GetPuppetPhysicsCount()
	return self:GetWeapon():GetNW2Int(id3, 0)
end

---@param count integer
function TOOL:SetPuppetPhysicsCount(count)
	self:GetWeapon():SetNW2Int(id3, count)
end

---@param puppet Entity?
function TOOL:SetAnimationPuppet(puppet)
	---@cast puppet Entity
	self:GetWeapon():SetNWEntity(id, puppet)
end

---@return Entity
function TOOL:GetAnimationPuppet()
	return self:GetWeapon():GetNWEntity(id)
end

---@param puppeteer Entity?
function TOOL:SetAnimationPuppeteer(puppeteer)
	---@cast puppeteer Entity
	self:GetWeapon():SetNWEntity(id2, puppeteer)
end

---@return Entity
function TOOL:GetAnimationPuppeteer()
	return self:GetWeapon():GetNWEntity(id2)
end

function TOOL:Cleanup()
	if IsValid(self:GetAnimationPuppeteer()) then
		self:GetAnimationPuppeteer():Remove()
	end
	self:SetAnimationPuppet(nil)
	self:SetAnimationPuppeteer(nil)
	self:SetStage(0)
end

---Set the puppet's physical bones to a target pose specified from the puppeteer, while offsetting with an angle
---Source: https://github.com/Winded/StopMotionHelper/blob/master/lua/smh/modifiers/physbones.lua
---@param puppet Entity
---@param targetPose SMHFramePose
---@param puppeteer Entity
---@param offset Angle
local function setPhysicalBonePoseOf(puppet, targetPose, puppeteer, offset)
	offset = offset and Angle(offset[1], offset[2], offset[3]) or Angle(0, 0, 0)
	for i = 0, puppet:GetPhysicsObjectCount() - 1 do
		local b = puppet:TranslatePhysBoneToBone(i)
		local phys = puppet:GetPhysicsObjectNum(i)
		local parent = puppet:GetPhysicsObjectNum(Vendor.GetPhysBoneParent(puppet, i))
		if not targetPose[i] or filteredBones[b + 1] then
			continue
		end
		if targetPose[i].LocalPos and targetPose[i].LocalPos ~= MINIMUM_VECTOR then
			local pos, ang =
				LocalToWorld(targetPose[i].LocalPos, targetPose[i].LocalAng, parent:GetPos(), parent:GetAngles())
			phys:EnableMotion(false)
			phys:SetPos(pos)
			phys:SetAngles(ang)
			phys:Wake()
		else
			local matrix = puppeteer:GetBoneMatrix(b)
			local bPos, bAng = matrix:GetTranslation(), matrix:GetAngles()
			-- First, set offset angle of puppeteer
			puppeteer:SetAngles(defaultAngle + offset)
			-- Then, set target position of puppet with offset
			local fPos, fAng = LocalToWorld(targetPose[i].Pos, targetPose[i].Ang, bPos, bAng)
			phys:EnableMotion(false)
			phys:SetPos(fPos)
			-- Finally, set angle of puppet itself
			phys:SetAngles(fAng)
			phys:Wake()
		end
	end
end

---Directly influence the ragdoll nonphysical bones from SMH data
---@param puppet Entity
---@param targetPose SMHFramePose
local function setNonPhysicalBonePoseOf(puppet, targetPose)
	for b = 0, puppet:GetBoneCount() - 1 do
		if filteredBones[b + 1] then
			continue
		end

		puppet:ManipulateBonePosition(b, targetPose[b].Pos)
		puppet:ManipulateBoneAngles(b, targetPose[b].Ang)
		if targetPose[b].Scale then
			puppet:ManipulateBoneScale(b, targetPose[b].Scale)
		end
	end
end

---Move and orient each physical bone of the puppet using the poses sent to us from the client
---Source: https://github.com/penolakushari/StandingPoseTool/blob/b7dc7b3b57d2d940bb6a4385d01a4b003c97592c/lua/autorun/standpose.lua
---@param puppet Entity
local function matchPhysicalBonePoseOf(puppet, puppeteer)
	if game.SinglePlayer() then
		for i = 0, puppet:GetPhysicsObjectCount() - 1 do
			local phys = puppet:GetPhysicsObjectNum(i)
			local b = puppet:TranslatePhysBoneToBone(i)

			local pos, ang = net.ReadVector(), net.ReadAngle()
			if filteredBones[b + 1] then
				continue
			end

			phys:EnableMotion(true)
			phys:Wake()
			phys:SetPos(pos)
			phys:SetAngles(ang)
			phys:EnableMotion(false)
			phys:Wake()
		end
	else
		for i = 0, puppet:GetPhysicsObjectCount() - 1 do
			local phys = puppet:GetPhysicsObjectNum(i)
			local b = puppet:TranslatePhysBoneToBone(i)
			if filteredBones[b + 1] then
				continue
			end

			local pos, ang = puppeteer:GetBonePosition(b)

			phys:EnableMotion(true)
			phys:Wake()
			phys:SetPos(pos)
			phys:SetAngles(ang)
			if string.sub(puppet:GetBoneName(b), 1, 4) == "prp_" then
				phys:EnableMotion(true)
				phys:Wake()
			else
				phys:EnableMotion(false)
				phys:Wake()
			end
		end
	end
end

---Instead of finding the default bone pose on the server, find them in the client
---We require the model so that we can build the client model with its default bone pose
---@param model string
---@param ply Player
local function queryDefaultBonePoseOfPuppet(model, ply)
	net.Start("queryDefaultBonePoseOfPuppet", false)
	net.WriteString(model)
	net.Send(ply)
end

---Instead of finding the nonphysical bone poses on the server, find them in the client
---We don't require the puppeteer as we always work with one puppet
---@param ply Player
local function queryNonPhysBonePoseOfPuppet(ply, cycle)
	net.Start("queryNonPhysBonePoseOfPuppet", false)
	net.WriteFloat(cycle)
	net.Send(ply)
end

---Move the puppeteer to the target entity's position, with the option to move to the ground
---@param puppeteer Entity
---@param target Entity
---@param findFloor boolean?
local function setPositionOf(puppeteer, target, findFloor)
	if findFloor then
		local tr = util.TraceLine({
			start = target:GetPos(),
			endpos = target:GetPos() - Vector(0, 0, 3000),
			filter = function(e)
				return e:GetClass() == game.GetWorld()
			end,
		})
		puppeteer:SetPos(tr.HitPos)
	else
		-- If the puppeteer has a root bone in the same position as the its puppeteer:GetPos(), then it may have its pelvis
		-- as a child in the bone tree. We'll use the bone that has a significant difference from puppeteer:GetPos()
		puppeteer:SetPos(target:GetPos())
		local oldBonePos = puppeteer:GetBonePosition(0)
		local puppeteerPos = puppeteer:GetPos()
		local boneIndex = 1
		while boneIndex < MAX_PELVIS_LOOKUP and puppeteerPos:DistToSqr(oldBonePos) < EPSILON do
			oldBonePos = puppeteer:GetBonePosition(boneIndex)
			boneIndex = boneIndex + 1
		end
		local corrector = target:GetPos() - oldBonePos
		puppeteer:SetPos(puppeteer:GetPos() + corrector)
	end
end

---Make the puppeteer face the target
---@param puppeteer Entity
---@param target Entity
local function setAngleOf(puppeteer, target)
	local angle = (target:GetPos() - puppeteer:GetPos()):Angle()
	defaultAngle = angle
	puppeteer:SetAngles(Angle(0, angle.y, 0))
end

---Set the puppeteer's position and angles
---@param puppeteer Entity
---@param puppet Entity
---@param ply Player | Entity
---@param findFloor boolean?
local function setPlacementOf(puppeteer, puppet, ply, findFloor)
	setPositionOf(puppeteer, puppet, findFloor)
	setAngleOf(puppeteer, ply)
end

---@param ent Entity
local function resetAllNonphysicalBonesOf(ent)
	for i = 0, ent:GetBoneCount() - 1 do
		ent:ManipulateBonePosition(i, vector_origin)
		ent:ManipulateBoneAngles(i, angle_zero)
	end

	bonesReset = true
end

---@param puppet Entity
---@param puppetModel string
---@param ply Player
---@return Entity
local function createServerPuppeteer(puppet, puppetModel, ply)
	local puppeteer = ents.Create("prop_dynamic")
	puppeteer:SetModel(puppetModel)
	setPlacementOf(puppeteer, puppet, ply, true)
	puppeteer:Spawn()
	styleServerPuppeteer(puppeteer)

	return puppeteer
end

---Select a ragdoll as a puppet to puppeteer
---@param tr TraceResult
---@return boolean
function TOOL:LeftClick(tr)
	---@type Player
	local ply = self:GetOwner()

	local ragdollPuppet = tr.Entity
	do
		local validPuppet = IsValid(ragdollPuppet)
		local isRagdoll = ragdollPuppet:IsRagdoll()
		local samePuppet = IsValid(self:GetAnimationPuppet()) and self:GetAnimationPuppet() == prevServerAnimPuppet
		if not validPuppet or not isRagdoll or samePuppet then
			return false
		end
	end

	if CLIENT then
		return false
	end

	self:SetPuppetPhysicsCount(ragdollPuppet:GetPhysicsObjectCount())

	local puppetModel = ragdollPuppet:GetModel()

	---@type Entity
	local animPuppeteer = createServerPuppeteer(ragdollPuppet, puppetModel, ply)
	if self:GetAnimationPuppet() ~= ragdollPuppet then
		self:Cleanup()
	end
	self:SetAnimationPuppet(ragdollPuppet)
	self:SetAnimationPuppeteer(animPuppeteer)
	queryDefaultBonePoseOfPuppet(puppetModel, ply)

	local currentIndex = 0

	---Decode the SMH pose from the client
	---@return SMHFramePose
	local function decodePose()
		local pose = {}
		local poseSize = net.ReadUInt(16)
		for i = 0, poseSize do
			pose[i] = {
				Pos = 0,
				Ang = 0,
				Scale = 0,
				LocalPos = 0,
				LocalAng = 0,
			}

			pose[i].Pos = net.ReadVector()
			pose[i].Ang = net.ReadAngle()
			pose[i].Scale = net.ReadVector()
			pose[i].LocalPos = net.ReadVector()
			pose[i].LocalAng = net.ReadAngle()
		end
		return pose
	end

	---Helper for setting poses for SMH animations
	local function readSMHPose()
		-- Assumes that we are in the networking scope
		local targetPose = decodePose()
		local angOffsetLength = net.ReadUInt(16)
		local angOffset = decompressJSONToTable(net.ReadData(angOffsetLength))
		local animatingNonPhys = net.ReadBool()
		setPhysicalBonePoseOf(ragdollPuppet, targetPose, animPuppeteer, angOffset)
		if animatingNonPhys then
			local tPNPLength = net.ReadUInt(16)
			local targetPoseNonPhys = decompressJSONToTable(net.ReadData(tPNPLength))
			setNonPhysicalBonePoseOf(ragdollPuppet, targetPoseNonPhys)
		elseif not bonesReset then
			resetAllNonphysicalBonesOf(ragdollPuppet)
		end
	end

	---Helper for setting poses for sequences
	---@param cycle number
	---@param animatingNonPhys boolean
	local function setPuppeteerPose(cycle, animatingNonPhys)
		-- This statement mimics a sequence change event, so it offsets its sequence to force an animation change. Might test without statement.
		animPuppeteer:ResetSequence((currentIndex == 0) and (currentIndex + 1) or (currentIndex - 1))
		animPuppeteer:ResetSequence(currentIndex)
		animPuppeteer:SetCycle(cycle)
		animPuppeteer:SetPlaybackRate(0)
		matchPhysicalBonePoseOf(ragdollPuppet, animPuppeteer)
		if animatingNonPhys then
			queryNonPhysBonePoseOfPuppet(ply, cycle)
		elseif not bonesReset then
			resetAllNonphysicalBonesOf(ragdollPuppet)
		end
	end

	-- Network hooks from client
	net.Receive("onFrameChange", function()
		local isSequence = net.ReadBool()
		if isSequence then
			local cycle = net.ReadFloat()
			local animatingNonPhys = net.ReadBool()
			setPuppeteerPose(cycle, animatingNonPhys)
		else
			readSMHPose()
		end
	end)

	net.Receive("onSequenceChange", function()
		if not IsValid(animPuppeteer) then
			return
		end
		local isSequence = net.ReadBool()
		if isSequence then
			local seqIndex = net.ReadInt(14)
			local animatingNonPhys = net.ReadBool()
			currentIndex = seqIndex
			setPuppeteerPose(0, animatingNonPhys)
		else
			readSMHPose()
		end

		net.Start("onSequenceChange")
		net.Send(ply)
	end)

	net.Receive("onSequenceChange", function()
		if not IsValid(animPuppeteer) then
			return
		end
		local isSequence = net.ReadBool()
		if isSequence then
			local seqIndex = net.ReadInt(14)
			local animatingNonPhys = net.ReadBool()
			currentIndex = seqIndex
			setPuppeteerPose(0, animatingNonPhys)
		else
			readSMHPose()
		end

		net.Start("onSequenceChange")
		net.Send(ply)
	end)

	net.Receive("onPoseParamChange", function()
		local animatingNonPhys = net.ReadBool()
		local paramValue = net.ReadFloat()
		local paramName = net.ReadString()
		animPuppeteer:SetPoseParameter(paramName, paramValue)
		setPuppeteerPose(currentIndex, animatingNonPhys)
	end)

	net.Receive("onBoneFilterChange", function()
		filteredBones = net.ReadTable(true)
	end)

	net.Receive("queryNonPhysBonePoseOfPuppet", function(_)
		local newPose = {}
		for b = 1, animPuppeteer:GetBoneCount() do
			newPose[b - 1] = {}
			newPose[b - 1].Pos = net.ReadVector()
			newPose[b - 1].Ang = net.ReadAngle()
		end
		setNonPhysicalBonePoseOf(ragdollPuppet, newPose)
	end)

	-- End of lifecycle events
	ragdollPuppet:CallOnRemove("RemoveAnimPuppeteer", function()
		self:Cleanup()
	end)
	-- Set stages for showing control panel for selected puppet
	self:SetStage(1)
	return true
end

---Stop puppeteering a ragdoll
---@param tr TraceResult
---@return boolean?
function TOOL:RightClick(tr)
	-- FIXME: Properly clear any animation entities, clientside and serverside
	if IsValid(self:GetAnimationPuppet()) then
		self:Cleanup()
		prevServerAnimPuppet = nil
		net.Start("removeClientAnimPuppeteer")
		net.Send(self:GetOwner())
		return true
	end
end

-- Concommands
concommand.Add("ragdollpuppeteer_updateposition", function(ply, _, _)
	if not IsValid(ply) then
		return
	end

	local findFloor = GetConVar("ragdollpuppeteer_updateposition_floors"):GetInt()
	local findFloorBool = false
	if findFloor <= 0 then
		findFloorBool = false
	else
		findFloorBool = true
	end

	local tool = ply:GetTool("ragdollpuppeteer")
	local puppeteer = tool:GetAnimationPuppeteer()
	local puppet = tool:GetAnimationPuppet()
	if not IsValid(puppet) or not IsValid(puppeteer) then
		return
	end
	setPlacementOf(puppeteer, puppet, ply, findFloorBool)
	-- Update client puppeteer position, which calls the above function for the client puppeteer
	net.Start("updateClientPosition")
	net.Send(ply)
end)

concommand.Add("ragdollpuppeteer_previousframe", function(ply)
	net.Start("onFramePrevious")
	net.Send(ply)
end)

concommand.Add("ragdollpuppeteer_nextframe", function(ply)
	net.Start("onFrameNext")
	net.Send(ply)
end)

if SERVER then
	return
end

---@module "ragdollpuppeteer.ui"
local UI = include("ragdollpuppeteer/ui.lua")

---@type PanelState
local panelState = {
	maxFrames = 0,
	defaultBonePose = {},
	previousPuppeteer = nil,
	stateChange = false,
}

local lastFrame = 0

TOOL:BuildConVarList()

---@param puppeteer Entity
local function styleClientPuppeteer(puppeteer)
	puppeteer:SetColor(Color(0, 0, 255, 128))
	puppeteer:SetRenderMode(RENDERMODE_TRANSCOLOR)
end

---Get the pose of every bone of the entity, for nonphysical bone matching
---Source: https://github.com/NO-LOAFING/AnimpropOverhaul/blob/a3a6268a5d57655611a8b8ed43dcf43051ecd93a/lua/entities/prop_animated.lua#L3550
---@param ent Entity
---@return DefaultBonePose
local function getDefaultBonePoseOf(ent)
	local defaultPose = {}
	local entPos = ent:GetPos()
	local entAngles = ent:GetAngles()
	for b = 0, ent:GetBoneCount() - 1 do
		local parent = ent:GetBoneParent(b)
		local bMatrix = ent:GetBoneMatrix(b)
		local pos1, ang1 = WorldToLocal(bMatrix:GetTranslation(), bMatrix:GetAngles(), entPos, entAngles)
		local pos2, ang2 = pos1 * 1, ang1 * 1
		if parent > -1 then
			local pMatrix = ent:GetBoneMatrix(parent)
			pos2, ang2 = WorldToLocal(
				bMatrix:GetTranslation(),
				bMatrix:GetAngles(),
				pMatrix:GetTranslation(),
				pMatrix:GetAngles()
			)
		end

		defaultPose[b + 1] = { pos1, ang1, pos2, ang2 }
	end
	return defaultPose
end

---Calculate the bone offsets with respect to the parent
---Source: https://github.com/NO-LOAFING/AnimpropOverhaul/blob/a3a6268a5d57655611a8b8ed43dcf43051ecd93a/lua/entities/prop_animated.lua#L1889
---@param puppeteer Entity
---@param child integer
---@return Vector
---@return Angle
local function getBoneOffsetsOf(puppeteer, child)
	local defaultBonePose = panelState.defaultBonePose
	local parent = puppeteer:GetBoneParent(child)
	---@type VMatrix
	local cMatrix = puppeteer:GetBoneMatrix(child)
	---@type VMatrix
	local pMatrix = puppeteer:GetBoneMatrix(parent)

	local fPos, fAng =
		WorldToLocal(cMatrix:GetTranslation(), cMatrix:GetAngles(), pMatrix:GetTranslation(), pMatrix:GetAngles())
	local dPos = fPos - defaultBonePose[child + 1][3]

	local m = Matrix()
	m:Translate(defaultBonePose[parent + 1][1])
	m:Rotate(defaultBonePose[parent + 1][2])
	m:Rotate(fAng)

	local _, dAng =
		WorldToLocal(m:GetTranslation(), m:GetAngles(), defaultBonePose[child + 1][1], defaultBonePose[child + 1][2])

	return dPos, dAng
end

---@alias BoneOffset table<Vector, Angle>
---@alias BoneOffsetArray BoneOffset[]

---Try to manipulate the bone angles of the puppet to match the puppeteer
---@param puppeteer Entity
---@return BoneOffsetArray
local function matchNonPhysicalBonePoseOf(puppeteer)
	local newPose = {}

	for b = 0, puppeteer:GetBoneCount() - 1 do
		-- Reset bone position and angles
		if puppeteer:GetBoneParent(b) > -1 then
			newPose[b + 1] = {}
			local dPos, dAng = getBoneOffsetsOf(puppeteer, b)
			newPose[b + 1][1] = dPos
			newPose[b + 1][2] = dAng
		else
			newPose[b + 1] = {}
			newPose[b + 1][1] = vector_origin
			newPose[b + 1][2] = angle_zero
		end
	end

	return newPose
end

---@param puppeteer CSEnt
local function disablePuppeteerJiggle(puppeteer)
	for b = 0, puppeteer:GetBoneCount() - 1 do
		puppeteer:ManipulateBoneJiggle(b, 0)
	end
end

---@param model string
---@param puppet Entity
---@param ply Player
---@return CSEnt
local function createClientPuppeteer(model, puppet, ply)
	local puppeteer = ClientsideModel(model, RENDERGROUP_TRANSLUCENT)
	if panelState.previousPuppeteer and IsValid(panelState.previousPuppeteer) then
		panelState.previousPuppeteer:Remove()
	end
	puppeteer:SetModel(model)
	setPlacementOf(puppeteer, puppet, ply, true)
	puppeteer:Spawn()
	disablePuppeteerJiggle(puppeteer)
	styleClientPuppeteer(puppeteer)
	return puppeteer
end

function TOOL.BuildCPanel(cPanel, puppet, ply, physicsCount)
	if not puppet or not IsValid(puppet) then
		cPanel:Help("No puppet selected")
		return
	end

	local model = puppet:GetModel()

	---@type CSEnt
	local animPuppeteer = createClientPuppeteer(model, puppet, ply)

	local panelProps = {
		model = model,
		puppeteer = animPuppeteer,
		puppet = puppet,
		physicsCount = physicsCount,
	}

	-- UI Elements
	local panelChildren = UI.ConstructPanel(cPanel, panelProps)

	UI.Layout(panelChildren.sequenceList, panelChildren.smhList, panelChildren.smhBrowser, animPuppeteer)

	-- UI Hooks
	UI.HookPanel(panelChildren, panelProps, panelState)

	UI.NetHookPanel(panelChildren.numSlider)

	net.Receive("updateClientPosition", function()
		setPlacementOf(animPuppeteer, puppet, ply, panelChildren.findFloor:GetChecked())
	end)

	net.Receive("removeClientAnimPuppeteer", function()
		if IsValid(animPuppeteer) then
			animPuppeteer:Remove()
			panelState.previousPuppeteer = nil
			UI.ClearList(panelChildren.sequenceList)
			UI.ClearList(panelChildren.smhList)
			panelChildren.puppetLabel:SetText("No puppet selected.")
		end
	end)

	local floor = math.floor
	local ceil = math.ceil
	local abs = math.abs
	-- Workaround for ensuring nonphysical bones are moved on sequence change
	local correctionCount = 0
	local defaultCorrection = 1 / 24

	-- Make corrections for about this amount multiplied by the max bones of the entity
	local maxCountHeuristic = 0.25
	net.Receive("onSequenceChange", function()
		-- On a different sequence, we want to reset
		correctionCount = 0
	end)

	net.Receive("queryNonPhysBonePoseOfPuppet", function(_, _)
		if #panelState.defaultBonePose == 0 or correctionCount == 0 then
			return
		end

		-- When the difference between frames are high, then we need to correct more
		local currentFrame = net.ReadFloat() / panelState.maxFrames
		local correctionModifier = defaultCorrection / ceil(abs(currentFrame - lastFrame))

		-- If we only changed to a frame of the animation, we assume that this frame's pose
		-- and the previous frame's pose is almost similar. Our heuristic is to divide the
		-- correction count so we can account for this, though this would only be effective
		-- if we incremented (or decremented) the ragdollpuppeteer_frame one at a time.
		correctionCount = floor(correctionCount * correctionModifier)
	end)

	-- Because the puppeteer is playing a sequence, it must build its bone positions at every tick.
	-- This would be unnecessary if the sequence is paused, but this unique behavior allows us to
	-- correct the serverside puppet's nonphysical bones at every tick
	local callbackId = animPuppeteer:AddCallback("BuildBonePositions", function(ent, maxBoneCount)
		-- If the correction count is greater than a heuristic for the minimal number of counts needed to
		-- closely approximate the nonphysical bone pose, it will make unnecessary client calculations and
		-- calls to the server
		if correctionCount >= floor(maxBoneCount * maxCountHeuristic) then
			return
		end

		-- Make sure no other network messages are happening
		if panelState.stateChange then
			return
		end

		-- Correct the nonphysical bone pose on the server
		local newPose = matchNonPhysicalBonePoseOf(ent)
		net.Start("queryNonPhysBonePoseOfPuppet")
		for b = 1, maxBoneCount do
			net.WriteVector(newPose[b][1])
			net.WriteAngle(newPose[b][2])
		end
		net.SendToServer()

		-- Increment and try again
		correctionCount = correctionCount + 1
	end)

	-- End of lifecycle events
	puppet:CallOnRemove("RemoveAnimPuppeteer", function()
		if IsValid(animPuppeteer) then
			animPuppeteer:RemoveCallback("BuildBonePositions", callbackId)
			animPuppeteer:Remove()
			panelState.previousPuppeteer = nil
			UI.ClearList(panelChildren.sequenceList)
			UI.ClearList(panelChildren.smhList)
			panelChildren.puppetLabel:SetText("No puppet selected.")
		end
	end)

	panelState.previousPuppeteer = animPuppeteer
end

net.Receive("queryDefaultBonePoseOfPuppet", function(_, _)
	net.Start("queryDefaultBonePoseOfPuppet")
	local netModel = net.ReadString()
	local csModel = ents.CreateClientProp()
	csModel:SetModel(netModel)
	csModel:DrawModel()
	csModel:SetupBones()
	csModel:InvalidateBoneCache()
	local defaultBonePose = getDefaultBonePoseOf(csModel)
	panelState.defaultBonePose = defaultBonePose

	for b = 1, csModel:GetBoneCount() do
		net.WriteTable(defaultBonePose[b], true)
	end

	csModel:Remove()
	net.SendToServer()
end)

local COLOR_WHITE = Color(200, 200, 200)
local COLOR_WHITE_BRIGHT = Color(255, 255, 255)
local COLOR_GREY = Color(128, 128, 128)

-- Relative sizes with respect to the width and height of the tool screen
local TEXT_WIDTH_MODIFIER = 0.5
local TEXT_HEIGHT_MODIFIER = 0.428571429
local BAR_HEIGHT = 0.0555555556
local BAR_Y_POS = 0.6015625

local lastWidth

function TOOL:DrawToolScreen(width, height)
	local y = height * BAR_Y_POS
	local ySize = height * BAR_HEIGHT
	local frame = GetConVar("ragdollpuppeteer_frame"):GetFloat()
	local maxAnimFrames = panelState.maxFrames

	draw.SimpleText(
		"Ragdoll Puppeteer",
		"DermaLarge",
		width * TEXT_WIDTH_MODIFIER,
		height * TEXT_HEIGHT_MODIFIER,
		COLOR_WHITE,
		TEXT_ALIGN_CENTER,
		TEXT_ALIGN_BOTTOM
	)
	draw.SimpleText(
		"Current Frame: " .. tostring(frame),
		"GModToolSubtitle",
		width * 0.5,
		height * 0.5,
		COLOR_WHITE,
		TEXT_ALIGN_CENTER,
		TEXT_ALIGN_CENTER
	)

	-- Don't calculate the bar width if the last frame is the same as the first
	if lastFrame ~= frame or not lastWidth then
		lastWidth = width * frame / maxAnimFrames
	end

	draw.RoundedBox(0, 0, y, width, ySize, COLOR_GREY)
	draw.RoundedBox(0, 0, y, lastWidth, ySize, COLOR_WHITE_BRIGHT)

	lastFrame = frame
end

TOOL.Information = {
	{
		name = "info",
		stage = 1,
	},
	{
		name = "left",
		stage = 0,
	},
	{
		name = "right",
		stage = 1,
	},
}

language.Add("tool.ragdollpuppeteer.name", "Ragdoll Puppeteer")
language.Add("tool.ragdollpuppeteer.desc", "Puppeteer a ragdoll to any animation frame")
language.Add("tool.ragdollpuppeteer.0", "Select a ragdoll to puppeteer")
language.Add("tool.ragdollpuppeteer.1", "Play animations through the context menu")
language.Add("tool.ragdollpuppeteer.left", "Add puppeteer to ragdoll")
language.Add("tool.ragdollpuppeteer.right", "Remove puppeteer from ragdoll")
