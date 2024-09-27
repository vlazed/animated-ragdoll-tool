---@module "ragdollpuppeteer.vendor"
local vendor = include("ragdollpuppeteer/lib/vendor.lua")
---@module "ragdollpuppeteer.constants"
local constants = include("ragdollpuppeteer/constants.lua")
---@module "ragdollpuppeteer.util"
local helpers = include("ragdollpuppeteer/lib/helpers.lua")

TOOL.Category = "Poser"
TOOL.Name = "#tool.ragdollpuppeteer.name"
TOOL.Command = nil
TOOL.ConfigName = ""
TOOL.ClientConVar["baseframe"] = 0
TOOL.ClientConVar["gestureframe"] = 0
TOOL.ClientConVar["animatenonphys"] = 0
TOOL.ClientConVar["showpuppeteer"] = 1
TOOL.ClientConVar["floor_worldcollisions"] = 1
TOOL.ClientConVar["fps"] = 30

local mode = TOOL:GetMode()

local MINIMUM_VECTOR = Vector(-16384, -16384, -16384)
local FIND_GROUND_VECTOR = Vector(0, 0, -3000)

local ids = {
	"ragdollpuppeteer_puppet",
	"ragdollpuppeteer_puppeteer",
	"ragdollpuppeteer_puppetCount",
	"ragdollpuppeteer_floor",
}

---@param puppeteer Entity
local function styleServerPuppeteer(puppeteer)
	puppeteer:AddEffects(EF_NODRAW)
end

---@param json string
---@return table
local function decompressJSONToTable(json)
	return util.JSONToTable(util.Decompress(json))
end

---@param ragdoll Entity
---@param physicsCount integer
---@param player Player
local function queryPhysObjects(ragdoll, physicsCount, player)
	net.Start("queryPhysObjects", false)
	for i = 0, physicsCount do
		net.WriteInt(vendor.GetPhysBoneParent(ragdoll, i), 10)
		net.WriteString(ragdoll:GetBoneName(ragdoll:TranslatePhysBoneToBone(i)))
	end
	net.Send(player)
end

local lastPuppet = NULL
local lastValidPuppet = false
function TOOL:Think()
	if CLIENT then
		-- Do not rebuild control panel for the same puppet
		local currentPuppet = self:GetAnimationPuppet()
		local physicsCount = self:GetPuppetPhysicsCount()
		if currentPuppet == lastPuppet and IsValid(currentPuppet) == lastValidPuppet then
			return
		end

		lastPuppet = currentPuppet
		lastValidPuppet = IsValid(lastPuppet)
		self:RebuildControlPanel(currentPuppet, self:GetOwner(), physicsCount, self:GetAnimationFloor())
	end
end

---@return integer
function TOOL:GetPuppetPhysicsCount()
	return self:GetWeapon():GetNW2Int(ids[3], 0)
end

---@param count integer
function TOOL:SetPuppetPhysicsCount(count)
	self:GetWeapon():SetNW2Int(ids[3], count)
end

---@param puppet Entity?
function TOOL:SetAnimationPuppet(puppet)
	---@cast puppet Entity
	self:GetWeapon():SetNWEntity(ids[1], puppet)
end

---@return Entity
function TOOL:GetAnimationPuppet()
	return self:GetWeapon():GetNWEntity(ids[1])
end

---@return Entity
function TOOL:GetAnimationFloor()
	return self:GetWeapon():GetNWEntity(ids[4])
end

---@param puppeteerFloor PuppeteerFloor
function TOOL:SetAnimationFloor(puppeteerFloor)
	self:GetWeapon():SetNWEntity(ids[4], puppeteerFloor)
end

---@param puppeteer Entity?
function TOOL:SetAnimationPuppeteer(puppeteer)
	---@cast puppeteer Entity
	self:GetWeapon():SetNWEntity(ids[2], puppeteer)
end

---@return Entity
function TOOL:GetAnimationPuppeteer()
	return self:GetWeapon():GetNWEntity(ids[2])
end

function TOOL:Cleanup(userId)
	if SERVER then
		if RAGDOLLPUPPETEER_PLAYERS[userId] and IsValid(RAGDOLLPUPPETEER_PLAYERS[userId].puppeteer) then
			RAGDOLLPUPPETEER_PLAYERS[userId].puppeteer:Remove()
		end

		RAGDOLLPUPPETEER_PLAYERS[userId].physicsCount = 0
		RAGDOLLPUPPETEER_PLAYERS[userId].puppet = NULL
		RAGDOLLPUPPETEER_PLAYERS[userId].puppeteer = NULL
		RAGDOLLPUPPETEER_PLAYERS[userId].floor = NULL
	end

	if not IsValid(self:GetWeapon()) then
		return
	end

	if IsValid(self:GetAnimationPuppeteer()) then
		self:GetAnimationPuppeteer():Remove()
	end
	self:SetAnimationPuppet(NULL)
	self:SetAnimationPuppeteer(NULL)
	if IsValid(self:GetAnimationFloor()) then
		self:GetAnimationFloor():Remove()
	end

	self:SetStage(0)
end

---Set the puppet's physical bones to a target pose specified from the puppeteer, while offsetting with an angle
---Source: https://github.com/Winded/StopMotionHelper/blob/master/lua/smh/modifiers/physbones.lua
---@param puppet Entity
---@param targetPose SMHFramePose
---@param puppeteer Entity
---@param filteredBones integer[]
local function setPhysicalBonePoseOf(puppet, targetPose, puppeteer, filteredBones)
	for i = 0, puppet:GetPhysicsObjectCount() - 1 do
		local b = puppet:TranslatePhysBoneToBone(i)
		local phys = puppet:GetPhysicsObjectNum(i)
		local parent = puppet:GetPhysicsObjectNum(vendor.GetPhysBoneParent(puppet, i))
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
---@param filteredBones integer[]
local function setNonPhysicalBonePoseOf(puppet, targetPose, filteredBones)
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
---@param filteredBones integer[]
local function matchPhysicalBonePoseOf(puppet, puppeteer, filteredBones)
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

local floorCorrect = helpers.floorCorrect

---Move the puppeteer to the target entity's position, with the option to move to the ground
---@param puppeteer Entity
---@param target Entity
local function setPositionOf(puppeteer, target)
	local targetPosition = target:GetPos()
	local tr = util.TraceLine({
		start = targetPosition,
		endpos = targetPosition + FIND_GROUND_VECTOR,
		filter = function(e)
			return e:GetClass() == game.GetWorld()
		end,
	})
	puppeteer:SetPos(tr.HitPos)
	floorCorrect(puppeteer)
end

---Make some entity face the target
---@param entity Entity
---@param target Entity
local function setAngleOf(entity, target)
	local angle = (target:GetPos() - entity:GetPos()):Angle()
	entity:SetAngles(Angle(0, angle.y, 0))
end

---Set the puppeteer's position and angles
---@param puppeteer Entity
---@param puppet Entity
---@param ply Player | Entity
local function setPlacementOf(puppeteer, puppet, ply)
	setPositionOf(puppeteer, puppet)
	setAngleOf(puppeteer, ply)
end

---@param ent Entity
local function resetAllNonphysicalBonesOf(ent)
	for i = 0, ent:GetBoneCount() - 1 do
		ent:ManipulateBonePosition(i, vector_origin)
		ent:ManipulateBoneAngles(i, angle_zero)
	end
end

---@param puppet Entity
---@param puppetModel string
---@param ply Player
---@return Entity
local function createServerPuppeteer(puppet, puppetModel, ply)
	local puppeteer = ents.Create("prop_dynamic")
	puppeteer:SetModel(puppetModel)
	setPlacementOf(puppeteer, puppet, ply)
	puppeteer:Spawn()
	styleServerPuppeteer(puppeteer)

	return puppeteer
end

---@param puppeteer Entity
---@param puppet Entity
---@param ply Player
---@return PuppeteerFloor
local function createPuppeteerFloor(puppeteer, puppet, ply)
	local puppeteerFloor = ents.Create("prop_puppeteerfloor")
	---@cast puppeteerFloor PuppeteerFloor
	puppeteerFloor:Spawn()
	puppeteerFloor:SetPos(puppeteer:GetPos() + Vector(0, 0, 10))
	floorCorrect(puppeteerFloor, puppeteer, -1)

	puppeteerFloor:AddPuppeteers({ puppeteer })
	puppeteerFloor:SetPhysicsSize(puppeteer)
	puppeteerFloor:SetPlayerOwner(ply)
	puppeteerFloor:SetPuppet(puppet)

	setAngleOf(puppeteerFloor, ply)

	return puppeteerFloor
end

---Select a ragdoll as a puppet to puppeteer
---@param tr TraceResult
---@return boolean
function TOOL:LeftClick(tr)
	---@type Player
	local ply = self:GetOwner()
	local userId = ply:UserID()

	local ragdollPuppet = tr.Entity
	do
		local validPuppet = IsValid(ragdollPuppet)
		local isRagdoll = ragdollPuppet:IsRagdoll()
		if not validPuppet or not isRagdoll then
			return false
		end
	end

	if CLIENT then
		return true
	end

	local physicsCount = ragdollPuppet:GetPhysicsObjectCount()
	local puppetModel = ragdollPuppet:GetModel()

	---@type Entity
	local animPuppeteer = createServerPuppeteer(ragdollPuppet, puppetModel, ply)
	local puppeteerFloor = createPuppeteerFloor(animPuppeteer, ragdollPuppet, ply)

	-- If we're selecting a different character, cleanup the previous selection
	if IsValid(self:GetAnimationPuppet()) and self:GetAnimationPuppet() ~= ragdollPuppet then
		self:Cleanup(userId)
	end

	self:SetPuppetPhysicsCount(physicsCount)
	self:SetAnimationPuppet(ragdollPuppet)
	self:SetAnimationPuppeteer(animPuppeteer)
	self:SetAnimationFloor(puppeteerFloor)

	local userId = ply:UserID()
	if not RAGDOLLPUPPETEER_PLAYERS[userId] then
		RAGDOLLPUPPETEER_PLAYERS[userId] = {
			currentIndex = 0,
			cycle = 0,
			player = ply,
			puppet = ragdollPuppet,
			puppeteer = animPuppeteer,
			fps = 30,
			physicsCount = physicsCount,
			filteredBones = {},
			bonesReset = false,
			floor = puppeteerFloor,
		}
	else
		RAGDOLLPUPPETEER_PLAYERS[userId].puppet = ragdollPuppet
		RAGDOLLPUPPETEER_PLAYERS[userId].puppeteer = animPuppeteer
		RAGDOLLPUPPETEER_PLAYERS[userId].physicsCount = physicsCount
		RAGDOLLPUPPETEER_PLAYERS[userId].player = ply
		RAGDOLLPUPPETEER_PLAYERS[userId].bonesReset = false
		RAGDOLLPUPPETEER_PLAYERS[userId].filteredBones = {}
		RAGDOLLPUPPETEER_PLAYERS[userId].floor = puppeteerFloor
	end

	queryDefaultBonePoseOfPuppet(puppetModel, ply)

	-- End of lifecycle events
	ragdollPuppet:CallOnRemove("RemoveAnimPuppeteer", function()
		self:Cleanup(userId)
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
	local ply = self:GetOwner()
	local userId = ply:UserID()
	if IsValid(self:GetAnimationPuppet()) then
		self:Cleanup(userId)
		if CLIENT then
			return true
		end
		net.Start("removeClientAnimPuppeteer")
		net.Send(self:GetOwner())
		return true
	end
end

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
---@param puppet Entity
---@param puppeteer Entity
---@param playerData RagdollPuppeteerPlayerField
local function readSMHPose(puppet, puppeteer, playerData)
	-- Assumes that we are in the networking scope
	local targetPose = decodePose()
	local animatingNonPhys = net.ReadBool()
	setPhysicalBonePoseOf(puppet, targetPose, puppeteer, playerData.filteredBones)
	if animatingNonPhys then
		local tPNPLength = net.ReadUInt(16)
		local targetPoseNonPhys = decompressJSONToTable(net.ReadData(tPNPLength))
		setNonPhysicalBonePoseOf(puppet, targetPoseNonPhys, playerData.filteredBones)
		playerData.bonesReset = false
	elseif not playerData.bonesReset then
		resetAllNonphysicalBonesOf(puppet)
		playerData.bonesReset = true
	end
end

---Helper for setting poses for sequences
---@param cycle number
---@param animatingNonPhys boolean
---@param playerData RagdollPuppeteerPlayerField
local function setPuppeteerPose(cycle, animatingNonPhys, playerData)
	local player = playerData.player
	local puppet = playerData.puppet
	local puppeteer = playerData.puppeteer
	local currentIndex = playerData.currentIndex

	if not IsValid(puppet) or not IsValid(puppeteer) then
		return
	end

	-- This statement mimics a sequence change event, so it offsets its sequence to force an animation change. Might test without statement.
	puppeteer:ResetSequence((currentIndex == 0) and (currentIndex + 1) or (currentIndex - 1))
	puppeteer:ResetSequence(currentIndex)
	puppeteer:SetCycle(cycle)
	puppeteer:SetPlaybackRate(0)
	matchPhysicalBonePoseOf(puppet, puppeteer, playerData.filteredBones)
	if animatingNonPhys then
		queryNonPhysBonePoseOfPuppet(player, cycle)
		playerData.bonesReset = false
	elseif not playerData.bonesReset then
		resetAllNonphysicalBonesOf(puppet)
		playerData.bonesReset = true
	end
end

-- Network hooks from client
if SERVER then
	hook.Add("PlayerSpawn", "ragdollpuppeteer_spawnCleanup", function(player)
		---@cast player Player

		local tool = player:GetTool(mode)
		local userId = player:UserID()

		if tool then
			tool:Cleanup(userId)
		end
	end)

	net.Receive("onFrameChange", function(_, sender)
		assert(RAGDOLLPUPPETEER_PLAYERS[sender:UserID()], "Player doesn't exist in hashmap!")
		local playerData = RAGDOLLPUPPETEER_PLAYERS[sender:UserID()]
		local ragdollPuppet = playerData.puppet
		local animPuppeteer = playerData.puppeteer

		local isSequence = net.ReadBool()
		if isSequence then
			local cycle = net.ReadFloat()
			local animatingNonPhys = net.ReadBool()
			playerData.cycle = cycle
			setPuppeteerPose(cycle, animatingNonPhys, playerData)
		else
			readSMHPose(ragdollPuppet, animPuppeteer, playerData)
		end
	end)

	net.Receive("onSequenceChange", function(_, sender)
		assert(RAGDOLLPUPPETEER_PLAYERS[sender:UserID()], "Player doesn't exist in hashmap!")
		local playerData = RAGDOLLPUPPETEER_PLAYERS[sender:UserID()]
		local ragdollPuppet = playerData.puppet
		local animPuppeteer = playerData.puppeteer

		if not IsValid(animPuppeteer) then
			return
		end
		local isSequence = net.ReadBool()
		if isSequence then
			local seqIndex = net.ReadInt(14)
			local animatingNonPhys = net.ReadBool()
			playerData.currentIndex = seqIndex
			setPuppeteerPose(0, animatingNonPhys, playerData)
		else
			readSMHPose(ragdollPuppet, animPuppeteer, playerData)
		end

		net.Start("onSequenceChange")
		net.Send(sender)
	end)

	net.Receive("onPoseParamChange", function(_, sender)
		assert(RAGDOLLPUPPETEER_PLAYERS[sender:UserID()], "Player doesn't exist in hashmap!")
		local playerData = RAGDOLLPUPPETEER_PLAYERS[sender:UserID()]
		local animPuppeteer = playerData.puppeteer
		local cycle = playerData.cycle

		local animatingNonPhys = net.ReadBool()
		local paramValue = net.ReadFloat()
		local paramName = net.ReadString()
		animPuppeteer:SetPoseParameter(paramName, paramValue)
		setPuppeteerPose(cycle, animatingNonPhys, playerData)
	end)

	net.Receive("onBoneFilterChange", function(_, sender)
		assert(RAGDOLLPUPPETEER_PLAYERS[sender:UserID()], "Player doesn't exist in hashmap!")
		local playerData = RAGDOLLPUPPETEER_PLAYERS[sender:UserID()]

		playerData.filteredBones = net.ReadTable(true)
	end)

	net.Receive("queryNonPhysBonePoseOfPuppet", function(_, sender)
		assert(RAGDOLLPUPPETEER_PLAYERS[sender:UserID()], "Player doesn't exist in hashmap!")
		local playerData = RAGDOLLPUPPETEER_PLAYERS[sender:UserID()]
		local animPuppeteer = playerData.puppeteer
		local ragdollPuppet = playerData.puppet

		if not IsValid(animPuppeteer) or not IsValid(ragdollPuppet) then
			return
		end

		local newPose = {}
		for b = 1, animPuppeteer:GetBoneCount() do
			newPose[b - 1] = {}
			newPose[b - 1].Pos = net.ReadVector()
			newPose[b - 1].Ang = net.ReadAngle()
		end
		setNonPhysicalBonePoseOf(ragdollPuppet, newPose, playerData.filteredBones)
	end)

	net.Receive("queryPhysObjects", function(_, sender)
		assert(RAGDOLLPUPPETEER_PLAYERS[sender:UserID()], "Player doesn't exist in hashmap!")
		local playerData = RAGDOLLPUPPETEER_PLAYERS[sender:UserID()]
		local ragdollPuppet = playerData.puppet
		local physicsCount = playerData.physicsCount

		queryPhysObjects(ragdollPuppet, physicsCount, sender)
	end)

	net.Receive("onFPSChange", function(_, sender)
		local userId = sender:UserID()
		assert(RAGDOLLPUPPETEER_PLAYERS[userId], "Player doesn't exist in hashmap!")
		local fps = net.ReadFloat()
		RAGDOLLPUPPETEER_PLAYERS[sender:UserID()].fps = fps
		net.Start("enablePuppeteerPlayback")
		net.WriteFloat(fps)
		net.Send(sender)
	end)
end

if SERVER then
	return
end

cvars.AddChangeCallback("ragdollpuppeteer_fps", function(_, _, newValue)
	if not newValue then
		return
	end

	local newFPS = tonumber(newValue)
	if type(newFPS) == "number" then
		net.Start("onFPSChange")
		net.WriteFloat(newFPS)
		net.SendToServer()
	end
end)

---@module "ragdollpuppeteer.ui"
local ui = include("ragdollpuppeteer/client/ui.lua")

local PUPPETEER_MATERIAL = constants.PUPPETEER_MATERIAL
local INVISIBLE_MATERIAL = constants.INVISIBLE_MATERIAL
local COLOR_BLUE = Color(0, 0, 64, 100)

---@type PanelState
local panelState = {
	maxFrames = 0,
	defaultBonePose = {},
	previousPuppeteer = nil,
	physicsObjects = {},
}

local lastFrame = 0

TOOL:BuildConVarList()

---@param puppeteer Entity
local function styleClientPuppeteer(puppeteer)
	puppeteer:SetColor(COLOR_BLUE)
	puppeteer:SetRenderMode(RENDERMODE_TRANSCOLOR)
	puppeteer:SetMaterial("!" .. PUPPETEER_MATERIAL:GetName())
	puppeteer.ragdollpuppeteer_currentMaterial = PUPPETEER_MATERIAL
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
			local dPos, dAng = vendor.getBoneOffsetsOf(puppeteer, b, panelState.defaultBonePose)
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

---@param puppeteer Entity
local function disablePuppeteerJiggle(puppeteer)
	for b = 0, puppeteer:GetBoneCount() - 1 do
		puppeteer:ManipulateBoneJiggle(b, 0)
	end
end

---@param model string
---@param puppet Entity
---@param ply Player
---@return Entity
local function createClientPuppeteer(model, puppet, ply)
	local puppeteer = ClientsideModel(model, RENDERGROUP_TRANSLUCENT)
	if panelState.previousPuppeteer and IsValid(panelState.previousPuppeteer) then
		panelState.previousPuppeteer:Remove()
	end
	puppeteer:SetModel(model)
	setPlacementOf(puppeteer, puppet, ply)
	puppeteer:Spawn()
	disablePuppeteerJiggle(puppeteer)
	styleClientPuppeteer(puppeteer)
	return puppeteer
end

---@param cPanel DForm
---@param puppet Entity
---@param ply Player
---@param physicsCount integer
---@param floor PuppeteerFloor
function TOOL.BuildCPanel(cPanel, puppet, ply, physicsCount, floor)
	if not puppet or not IsValid(puppet) then
		cPanel:Help("#ui.ragdollpuppeteer.label.none")
		return
	end

	if not IsValid(floor) then
		chat.AddText("Puppeteer floor did not pass here")
		return
	end

	local model = puppet:GetModel()

	local animPuppeteer = createClientPuppeteer(model, puppet, ply)
	animPuppeteer:SetIK(false)
	local animGesturer = createClientPuppeteer(model, puppet, ply)

	-- Used for sequences, these puppeteers are always set to the first frame of the sequence, so we can easily extract the delta position and angle.
	local basePuppeteer = createClientPuppeteer(model, puppet, ply)
	local baseGesturer = createClientPuppeteer(model, puppet, ply)
	basePuppeteer:SetMaterial("!" .. INVISIBLE_MATERIAL:GetName())
	baseGesturer:SetMaterial("!" .. INVISIBLE_MATERIAL:GetName())
	animGesturer:SetMaterial("!" .. INVISIBLE_MATERIAL:GetName())

	floor:AddPuppeteers({
		animPuppeteer,
		animGesturer,
		basePuppeteer,
		baseGesturer,
	})

	floor:SetPhysicsSize(animPuppeteer)

	local panelProps = {
		model = model,
		puppeteer = animPuppeteer,
		gesturer = animGesturer,
		basePuppeteer = basePuppeteer,
		baseGesturer = baseGesturer,
		puppet = puppet,
		physicsCount = physicsCount,
	}

	-- UI Elements
	local panelChildren = ui.ConstructPanel(cPanel, panelProps)

	ui.Layout(panelChildren.sequenceSheet, panelChildren.smhList, panelChildren.smhBrowser, animPuppeteer)

	-- UI Hooks
	ui.HookPanel(panelChildren, panelProps, panelState)

	ui.NetHookPanel(panelChildren, panelProps, panelState)

	local function removePuppeteer()
		if IsValid(animPuppeteer) and IsValid(panelState.previousPuppeteer) then
			animPuppeteer:Remove()
			basePuppeteer:Remove()
			animGesturer:Remove()
			baseGesturer:Remove()
			panelState.previousPuppeteer = NULL

			if IsValid(panelChildren.sequenceList) then
				ui.ClearList(panelChildren.sequenceList)
			end
			if IsValid(panelChildren.smhList) then
				ui.ClearList(panelChildren.smhList)
			end
			if IsValid(panelChildren.puppetLabel) then
				panelChildren.puppetLabel:SetText("#ui.ragdollpuppeteer.label.none")
			end
		end
	end

	net.Receive("removeClientAnimPuppeteer", function()
		removePuppeteer()
	end)

	net.Receive("queryNonPhysBonePoseOfPuppet", function(_, _)
		local newBasePose = matchNonPhysicalBonePoseOf(animPuppeteer)
		local newGesturePose = matchNonPhysicalBonePoseOf(animGesturer)
		net.Start("queryNonPhysBonePoseOfPuppet")
		for b = 1, animPuppeteer:GetBoneCount() do
			net.WriteVector(newBasePose[b][1] + newGesturePose[b][1])
			net.WriteAngle(newBasePose[b][2] + newGesturePose[b][2])
		end
		net.SendToServer()
	end)

	-- End of lifecycle events
	puppet:CallOnRemove("RemoveAnimPuppeteer", function()
		removePuppeteer()
	end)

	panelState.previousPuppeteer = animPuppeteer
end

net.Receive("queryDefaultBonePoseOfPuppet", function(_, _)
	local netModel = net.ReadString()
	local csModel = ents.CreateClientProp()
	csModel:SetModel(netModel)
	csModel:DrawModel()
	csModel:SetupBones()
	csModel:InvalidateBoneCache()
	local defaultBonePose = vendor.getDefaultBonePoseOf(csModel)
	panelState.defaultBonePose = defaultBonePose

	if #defaultBonePose == 0 then
		return
	end
	csModel:Remove()

	net.Start("queryDefaultBonePoseOfPuppet")

	for b = 1, csModel:GetBoneCount() do
		net.WriteTable(defaultBonePose[b], true)
	end

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
	local frame = GetConVar("ragdollpuppeteer_baseframe"):GetFloat()
	local maxAnimFrames = panelState.maxFrames

	draw.SimpleText(
		"#tool.ragdollpuppeteer.name",
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
