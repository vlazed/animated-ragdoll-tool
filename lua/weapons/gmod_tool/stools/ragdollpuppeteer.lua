---@module "ragdollpuppeteer.constants"
local constants = include("ragdollpuppeteer/constants.lua")
---@module "ragdollpuppeteer.lib.helpers"
local helpers = include("ragdollpuppeteer/lib/helpers.lua")
---@module "ragdollpuppeteer.lib.leakybucket"
local leakyBucket = include("ragdollpuppeteer/lib/leakybucket.lua")
---@module "ragdollpuppeteer.lib.pose"
local pose = include("ragdollpuppeteer/lib/pose.lua")

TOOL.Category = "Poser"
TOOL.Name = "#tool.ragdollpuppeteer.name"
TOOL.Command = nil
TOOL.ConfigName = ""
TOOL.ClientConVar["baseframe"] = 0
TOOL.ClientConVar["gestureframe"] = 0
TOOL.ClientConVar["animatenonphys"] = 0
TOOL.ClientConVar["resetnonphys"] = 1
TOOL.ClientConVar["showpuppeteer"] = 1
TOOL.ClientConVar["floor_worldcollisions"] = 1
TOOL.ClientConVar["playback_shouldincrement"] = 1
TOOL.ClientConVar["playback_incrementgestures"] = 1
TOOL.ClientConVar["fps"] = 30
TOOL.ClientConVar["color"] = "0 0 64"
TOOL.ClientConVar["alpha"] = "100"
TOOL.ClientConVar["ignorez"] = 0
TOOL.ClientConVar["attachtoground"] = 0
TOOL.ClientConVar["anysurface"] = 0
TOOL.ClientConVar["disabletween"] = 0
TOOL.ClientConVar["faceme"] = 1

-- The number of models that the user should not go over
local MAX_MODELS = constants.MAX_MODELS
-- The number of models to leak from the bucket
local MODEL_DEQUE_RATE = constants.MODEL_DEQUE_RATE

local mode = TOOL:GetMode()

local FIND_GROUND_VECTOR = Vector(0, 0, -3000)

local ids = {
	"ragdollpuppeteer_puppet",
	"ragdollpuppeteer_puppeteer",
	"ragdollpuppeteer_puppetCount",
	"ragdollpuppeteer_floor",
	"ragdollpuppeteer_sequence",
	"ragdollpuppeteer_cycle",
	"ragdollpuppeteer_copiedNPC",
}

---@param puppeteer Entity
local function styleServerPuppeteer(puppeteer)
	puppeteer:AddEffects(EF_NODRAW)
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
		if RAGDOLLPUPPETEER_PLAYERS[userId] then
			if IsValid(RAGDOLLPUPPETEER_PLAYERS[userId].puppeteer) then
				RAGDOLLPUPPETEER_PLAYERS[userId].puppeteer:Remove()
			end
			if IsValid(RAGDOLLPUPPETEER_PLAYERS[userId].floor) then
				RAGDOLLPUPPETEER_PLAYERS[userId].floor:Remove()
			end
			RAGDOLLPUPPETEER_PLAYERS[userId].physicsCount = 0
			RAGDOLLPUPPETEER_PLAYERS[userId].puppet = NULL
			RAGDOLLPUPPETEER_PLAYERS[userId].puppeteer = NULL
			RAGDOLLPUPPETEER_PLAYERS[userId].floor = NULL
			RAGDOLLPUPPETEER_PLAYERS[userId].playbackEnabled = false
			RAGDOLLPUPPETEER_PLAYERS[userId].physBones = {}
		end
	end

	if not IsValid(self:GetWeapon()) then
		return
	end

	if IsValid(self:GetAnimationPuppeteer()) then
		self:GetAnimationPuppeteer():Remove()
	end
	self:SetAnimationPuppet(NULL)
	self:SetAnimationPuppeteer(NULL)
	if IsValid(self:GetAnimationFloor()) and SERVER then
		self:GetAnimationFloor():Remove()
	end
	self:SetAnimationFloor(NULL)

	self:SetStage(0)
end

local physicsClasses = {
	["prop_physics"] = true,
	["prop_ragdoll"] = true,
	["gmod_cameraprop"] = true,
	["hl_camera"] = true,
}

---Get the physbones of the ragdoll or physics prop puppet, so we don't perform unnecessary BoneManipulations
---@param puppet Entity
---@return integer[]
local function getPhysBonesOfPuppet(puppet)
	local physbones = {}
	if physicsClasses[puppet:GetClass()] then
		for i = 0, puppet:GetPhysicsObjectCount() - 1 do
			local bone = puppet:TranslatePhysBoneToBone(i)
			if bone and bone > -1 then
				physbones[bone] = i
			end
		end
	end

	return physbones
end

local floorCorrect = helpers.floorCorrect

---Move the puppeteer to the target entity's position, with the option to move to the ground
---@param puppeteer Entity The puppeteer to move
---@param target Entity The target entity that will move the puppeteer
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
---@param entity Entity The entity that will face the target
---@param target Entity Target entity
local function setAngleOf(entity, target)
	local angle = (target:GetPos() - entity:GetPos()):Angle()
	entity:SetAngles(Angle(0, angle.y, 0))
end

---Set the puppeteer's position and angles
---@param puppeteer Entity The puppeteer that will move to the puppet and face the player
---@param puppet Entity The puppet to place the puppeteer
---@param ply Player | Entity Who will make the puppeteer face them
local function setPlacementOf(puppeteer, puppet, ply)
	setPositionOf(puppeteer, puppet)
	setAngleOf(puppeteer, ply)
end

---@param puppet Entity The puppet to create the puppeteer
---@param puppetModel string The puppet's model
---@param ply Player For whom to create the server puppeteer
---@return Entity serverPuppeteer The serverside puppeteer
local function createServerPuppeteer(puppet, puppetModel, ply)
	local puppeteer = ents.Create("prop_dynamic")
	puppeteer:SetModel(puppetModel)
	setPlacementOf(puppeteer, puppet, ply)
	puppeteer:Spawn()
	styleServerPuppeteer(puppeteer)

	return puppeteer
end

---@param puppeteer Entity The puppeteer that will be parented to the floor
---@param puppet Entity The puppet that will be parented to the floor
---@param ply Player For whom to create the puppeteer platform
---@return PuppeteerFloor puppeteerFloor The puppeteer floor
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

	if GetConVar("ragdollpuppeteer_faceme"):GetBool() then
		setAngleOf(puppeteerFloor, ply)
	end

	return puppeteerFloor
end

-- A set of classes for puppeteering
local validPuppetClasses = {
	["prop_ragdoll"] = true,
	["prop_physics"] = true,
	["prop_effect"] = true,
	["prop_dynamic"] = true,
	["prop_resizedragdoll_physparent"] = true,
	["hl_camera"] = true,
	["gmod_cameraprop"] = true,
}

---Select a ragdoll as a puppet to puppeteer
---@param tr TraceResult
---@return boolean
function TOOL:LeftClick(tr)
	---@type Player
	local ply = self:GetOwner()
	local userId = ply:UserID()

	local puppet = tr.Entity
	if puppet:GetClass() == "prop_effect" then
		-- Get the immediate first model that it finds in there
		puppet = #tr.Entity:GetChildren() > 0 and tr.Entity:GetChildren()[1] or tr.Entity
	end
	do
		local validPuppet = IsValid(puppet)
		local isValidClass = validPuppetClasses[puppet:GetClass()]
		if not validPuppet or not isValidClass then
			return false
		end
	end

	if CLIENT then
		return true
	end

	if IsValid(self:GetAnimationPuppet()) then
		-- If we're selecting a different character, cleanup the previous selection
		if self:GetAnimationPuppet() ~= puppet then
			self:Cleanup(userId)
		else
			-- We're selecting the same entity. Don't do anything else
			return false
		end
	end

	local physicsCount = puppet:GetPhysicsObjectCount()
	local puppetModel = puppet:GetModel()

	---@type Entity
	local animPuppeteer = createServerPuppeteer(puppet, puppetModel, ply)
	local puppeteerFloor = createPuppeteerFloor(animPuppeteer, puppet, ply)

	self:SetPuppetPhysicsCount(physicsCount)
	self:SetAnimationPuppet(puppet)
	self:SetAnimationPuppeteer(animPuppeteer)
	self:SetAnimationFloor(puppeteerFloor)

	local userId = ply:UserID()
	if not RAGDOLLPUPPETEER_PLAYERS[userId] then
		RAGDOLLPUPPETEER_PLAYERS[userId] = {
			currentIndex = 0,
			cycle = 0,
			player = ply,
			puppet = puppet,
			puppeteer = animPuppeteer,
			fps = 30,
			physicsCount = physicsCount,
			filteredBones = {},
			bonesReset = false,
			floor = puppeteerFloor,
			lastPose = {},
			poseParams = {},
			playbackEnabled = false,
			physBones = getPhysBonesOfPuppet(puppet),
			bucket = leakyBucket(MAX_MODELS, MODEL_DEQUE_RATE),
		}
	else
		RAGDOLLPUPPETEER_PLAYERS[userId].puppet = puppet
		RAGDOLLPUPPETEER_PLAYERS[userId].puppeteer = animPuppeteer
		RAGDOLLPUPPETEER_PLAYERS[userId].physicsCount = physicsCount
		RAGDOLLPUPPETEER_PLAYERS[userId].player = ply
		RAGDOLLPUPPETEER_PLAYERS[userId].bonesReset = false
		RAGDOLLPUPPETEER_PLAYERS[userId].filteredBones = {}
		RAGDOLLPUPPETEER_PLAYERS[userId].floor = puppeteerFloor
		RAGDOLLPUPPETEER_PLAYERS[userId].lastPose = {}
		RAGDOLLPUPPETEER_PLAYERS[userId].physBones = getPhysBonesOfPuppet(puppet)
	end

	-- End of lifecycle events
	puppet:CallOnRemove("RemoveAnimPuppeteer", function()
		self:Cleanup(userId)
	end)
	-- Set stages for showing control panel for selected puppet
	self:SetStage(1)
	return true
end

---Copy sequence information from an NPC and store it in the tool's networked variables
---@param npc NPC Target NPC to get sequence information
function TOOL:CopySequence(npc)
	local ply = self:GetOwner()
	self:GetWeapon():SetNWInt(ids[5], npc:GetSequence())
	self:GetWeapon():SetNWInt(ids[6], npc:GetCycle())
	self:GetWeapon():SetNWEntity(ids[7], npc)
	local poseParams = {}
	for i = 0, npc:GetNumPoseParameters() - 1 do
		poseParams[i + 1] = npc:GetPoseParameter(i)
	end
	RAGDOLLPUPPETEER_PLAYERS[ply:UserID()].poseParams = poseParams
end

---Paste sequence information to the puppet
---@param ent Entity | PuppeteerFloor
function TOOL:PasteSequence(ent)
	local sequence = self:GetWeapon():GetNWInt(ids[5])
	local cycle = self:GetWeapon():GetNWInt(ids[6])
	---@type NPC
	local npc = self:GetWeapon():GetNWInt(ids[7])
	local ply = self:GetOwner()
	local playerData = RAGDOLLPUPPETEER_PLAYERS[ply:UserID()]
	if sequence and playerData and playerData.puppet and playerData.floor then
		if playerData.puppet == ent or playerData.floor == ent then
			net.Start("onSequenceChange")
			net.WriteString(npc:GetSequenceName(sequence))
			net.WriteFloat(cycle)
			for i = 1, npc:GetNumPoseParameters() do
				net.WriteFloat(playerData.poseParams[i])
			end
			net.Send(ply)
		end
	end
end

-- A set of classes that will obtain the copied sequence information
local validPasteClasses = {
	["prop_ragdoll"] = true,
	["prop_puppeteerfloor"] = true,
}

---Copy a sequence from an NPC or paste to a puppet or floor
---@param tr TraceResult
function TOOL:Reload(tr)
	if tr.Entity and IsValid(tr.Entity) then
		local entity = tr.Entity
		if entity:IsNPC() then
			---@cast entity NPC
			self:CopySequence(entity)
			return true
		elseif validPasteClasses[entity:GetClass()] then
			---@cast entity Entity | PuppeteerFloor
			self:PasteSequence(entity)
			return true
		end
	end
	return false
end

---Stop puppeteering a ragdoll
---@param tr TraceResult
---@return boolean?
function TOOL:RightClick(tr)
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

	net.Receive("onPuppeteerChangeRequest", function(_, sender)
		assert(RAGDOLLPUPPETEER_PLAYERS[sender:UserID()], "Player doesn't exist in hashmap!")
		local playerData = RAGDOLLPUPPETEER_PLAYERS[sender:UserID()]
		local model = net.ReadString()
		local result = false
		local errorInt = 0

		-- Create the bucket if it doesn't exist for some reason
		if not playerData.bucket then
			playerData.bucket = leakyBucket(MAX_MODELS, MODEL_DEQUE_RATE)
		end

		-- Add a model to the bucket. Are we overflowing?
		if playerData.bucket:Add(1) then
			if util.IsValidModel(model) then
				result = true
			else
				errorInt = 2
			end
		else
			errorInt = 1
		end

		net.Start("onPuppeteerChangeRequest")
		net.WriteBool(result)
		net.WriteUInt(errorInt, 3)
		net.Send(sender)
	end)

	net.Receive("onPuppeteerChange", function(_, sender)
		assert(RAGDOLLPUPPETEER_PLAYERS[sender:UserID()], "Player doesn't exist in hashmap!")
		local playerData = RAGDOLLPUPPETEER_PLAYERS[sender:UserID()]
		local puppeteer = playerData.puppeteer
		local puppet = playerData.puppet
		local floor = playerData.floor

		local newModel = net.ReadString()
		puppeteer:SetModel(newModel)
		if puppet:GetModel() ~= newModel then
			timer.Simple(0, function()
				playerData.boneMap = pose.getBoneMap(puppeteer:GetBoneName(0), puppet:GetBoneName(0))
			end)
		end
		-- FIXME: InstallDataTable seems like an unintuitive way of resetting the network vars. What better method exists?
		floor:InstallDataTable()
		---@diagnostic disable-next-line: undefined-field
		floor:SetupDataTables()
	end)

	net.Receive("onPuppeteerPlayback", function(_, sender)
		assert(RAGDOLLPUPPETEER_PLAYERS[sender:UserID()], "Player doesn't exist in hashmap!")
		local playerData = RAGDOLLPUPPETEER_PLAYERS[sender:UserID()]
		playerData.playbackEnabled = net.ReadBool()
	end)

	net.Receive("onFrameChange", function(_, sender)
		assert(RAGDOLLPUPPETEER_PLAYERS[sender:UserID()], "Player doesn't exist in hashmap!")
		local playerData = RAGDOLLPUPPETEER_PLAYERS[sender:UserID()]
		local ragdollPuppet = playerData.puppet

		local isSequence = net.ReadBool()
		if isSequence then
			local cycle = net.ReadFloat()
			local animatingNonPhys = net.ReadBool()
			playerData.cycle = cycle
			pose.readSequence(cycle, animatingNonPhys, playerData)
		else
			pose.readSMH(ragdollPuppet, playerData)
		end
	end)

	net.Receive("onSequenceChange", function(_, sender)
		assert(RAGDOLLPUPPETEER_PLAYERS[sender:UserID()], "Player doesn't exist in hashmap!")
		local playerData = RAGDOLLPUPPETEER_PLAYERS[sender:UserID()]
		local ragdollPuppet = playerData.puppet

		local isSequence = net.ReadBool()
		if isSequence then
			local seqIndex = net.ReadInt(14)
			local animatingNonPhys = net.ReadBool()
			playerData.currentIndex = seqIndex
			pose.readSequence(0, animatingNonPhys, playerData)
		else
			pose.readSMH(ragdollPuppet, playerData)
		end
	end)

	net.Receive("onPoseParamChange", function(_, sender)
		assert(RAGDOLLPUPPETEER_PLAYERS[sender:UserID()], "Player doesn't exist in hashmap!")
		local playerData = RAGDOLLPUPPETEER_PLAYERS[sender:UserID()]
		local floor = playerData.floor
		local cycle = playerData.cycle

		local animatingNonPhys = net.ReadBool()
		local paramValue = net.ReadFloat()
		local paramName = net.ReadString()
		floor["Set" .. paramName](floor, paramValue)
		pose.readSequence(cycle, animatingNonPhys, playerData)
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
		pose.setNonPhysicalPose(
			ragdollPuppet,
			animPuppeteer,
			newPose,
			playerData.filteredBones,
			playerData.physBones,
			playerData.boneMap
		)
	end)

	net.Receive("onFPSChange", function(_, sender)
		local userId = sender:UserID()
		assert(RAGDOLLPUPPETEER_PLAYERS[userId], "Player doesn't exist in hashmap!")
		local fps = net.ReadFloat()
		RAGDOLLPUPPETEER_PLAYERS[sender:UserID()].fps = fps
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

include("ragdollpuppeteer/client/derma/poseoffsetter.lua")

---@type ragdollpuppeteer_poseoffsetter
local poseOffsetter

---@param entity Entity
---@param panelChildren PanelChildren
---@param panelState PanelState
local function refreshPoseOffsetter(entity, panelChildren, panelState)
	local lastVisible = false
	if IsValid(poseOffsetter) then
		lastVisible = poseOffsetter:IsVisible()
		poseOffsetter:Remove()
	end

	poseOffsetter = vgui.Create("ragdollpuppeteer_poseoffsetter")
	poseOffsetter:SetVisible(lastVisible)
	poseOffsetter:SetDirectory("ragdollpuppeteer/presets")
	poseOffsetter:RefreshDirectory()
	timer.Simple(0.1, function()
		poseOffsetter:SetEntity(entity)
	end)
end

local PUPPETEER_MATERIAL = constants.PUPPETEER_MATERIAL
local INVISIBLE_MATERIAL = constants.INVISIBLE_MATERIAL
local COLOR_BLUE = constants.COLOR_BLUE

---@type PanelState
local panelState = {
	maxFrames = 0,
	previousPuppeteer = nil,
	physicsObjects = {},
	model = "",
	selectedBone = -1,
	puppet = NULL,
	offsets = {},
}

local lastFrame = 0

TOOL:BuildConVarList()

---@param puppeteer Entity
local function styleClientPuppeteer(puppeteer)
	puppeteer:SetColor(COLOR_BLUE)
	puppeteer:SetRenderMode(RENDERMODE_TRANSCOLOR)
	puppeteer:SetMaterial(PUPPETEER_MATERIAL:GetName())
	puppeteer.ragdollpuppeteer_currentMaterial = PUPPETEER_MATERIAL
end

---@param puppeteer Entity
local function disablePuppeteerJiggle(puppeteer)
	for b = 0, puppeteer:GetBoneCount() - 1 do
		puppeteer:ManipulateBoneJiggle(b, 0)
	end
end

---@param model string The puppet's model
---@param puppet Entity The puppet to create the puppeteer
---@param ply Player For whom to create the puppeteer
---@return Entity clientPuppeteer The clientside puppeteer
local function createClientPuppeteer(model, puppet, ply)
	local puppeteer = ents.CreateClientside("prop_puppeteer")
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

---If the view puppeteer is a prop_resizedragdoll_parent, resize the puppeteer
---Source: https://github.com/NO-LOAFING/RagdollResizerPhys/blob/461c3779f2581117a2cbdd08f5a9e6fae29f7959/lua/entities/prop_resizedragdoll_physparent.lua#L508
---@param puppeteer Entity The puppeteer to resize
---@param puppet Entity | ResizedRagdoll The puppet that has the Ragdoll Resizer fields
---@param boneCount number The number of bones
local function resizePuppeteerToPuppet(puppeteer, puppet, boneCount)
	if not IsValid(puppeteer) then
		return
	end

	if puppet.SavedBoneMatrices then
		for i = 0, boneCount - 1 do
			---@type VMatrix
			local cMatrix = puppeteer:GetBoneMatrix(i)
			if not cMatrix then
				continue
			end

			-- We have to pass over the puppet's offsets over to the puppeteer, using the offsetting methods from the
			-- resized ragdoll entities
			if puppet.PhysBones[i] then
				local pMatrix = nil
				if puppet.PhysBoneOffsets[i] then
					pMatrix = puppeteer:GetBoneMatrix(puppet.PhysBones[i].parentid)
				end
				if pMatrix then
					pMatrix:Translate(puppet.PhysBoneOffsets[i])
					cMatrix:SetTranslation(pMatrix:GetTranslation())
				end

				-- Scale the puppeteer
				cMatrix:SetScale(puppet.SavedBoneMatrices[i]:GetScale())

				-- Finally, set the puppeteer's positions
				puppeteer:SetBoneMatrix(i, cMatrix)
			else
				local parentboneid = puppeteer:GetBoneParent(i)
				local pMatrix = nil
				if parentboneid and parentboneid ~= -1 then
					pMatrix = puppeteer:GetBoneMatrix(parentboneid)
				else
					local matr = Matrix()
					matr:SetTranslation(puppeteer:GetPos())
					matr:SetAngles(puppeteer:GetAngles())
					pMatrix = matr
				end
				if pMatrix then
					pMatrix:Translate(puppet.BoneOffsets[i]["posoffset"])
					pMatrix:Translate(puppet:GetManipulateBonePosition(i))
					pMatrix:Rotate(puppet.BoneOffsets[i]["angoffset"])
					pMatrix:Rotate(puppet:GetManipulateBoneAngles(i))

					if puppet.SavedBoneMatrices[i] then
						pMatrix:SetScale(puppet.SavedBoneMatrices[i]:GetScale())
					end
					puppeteer:SetBoneMatrix(i, pMatrix)
				end
			end
		end
	end
end

---@param cPanel DForm
---@param puppet Entity | ResizedRagdoll
---@param ply Player
---@param physicsCount integer
---@param floor PuppeteerFloor
function TOOL.BuildCPanel(cPanel, puppet, ply, physicsCount, floor)
	if not puppet or not IsValid(puppet) then
		cPanel:Help("#ui.ragdollpuppeteer.label.none")

		if IsValid(poseOffsetter) then
			hook.Remove("OnContextMenuOpen", "ragdollpuppeteer_hookcontext")
			hook.Remove("OnContextMenuClose", "ragdollpuppeteer_hookcontext")

			poseOffsetter:Remove()
		end
		return
	end

	if not IsValid(floor) then
		chat.AddText("Puppeteer floor did not pass here")
		return
	end

	if puppet.ClassOverride and puppet.ClassOverride == "prop_resizedragdoll_physparent" then
		chat.AddText("Ragdoll Puppeteer: " .. language.GetPhrase("ui.ragdollpuppeteer.notify.ragdollresizersupport"))
	end

	local model = puppet:GetModel()
	panelState.model = model

	-- This gets set behind the scenes.
	local animPuppeteer = createClientPuppeteer(model, puppet, ply)
	animPuppeteer:SetIK(false)
	local animGesturer = createClientPuppeteer(model, puppet, ply)

	-- Used for sequences, these puppeteers are always set to the first frame of the sequence, so we can easily extract the delta position and angle.
	local basePuppeteer = createClientPuppeteer(model, puppet, ply)
	local baseGesturer = createClientPuppeteer(model, puppet, ply)

	-- This is what gets shown to the player.
	local viewPuppeteer = createClientPuppeteer(model, puppet, ply)
	viewPuppeteer:SetIK(false)

	animPuppeteer:SetMaterial(INVISIBLE_MATERIAL:GetName())
	basePuppeteer:SetMaterial(INVISIBLE_MATERIAL:GetName())
	baseGesturer:SetMaterial(INVISIBLE_MATERIAL:GetName())
	animGesturer:SetMaterial(INVISIBLE_MATERIAL:GetName())

	floor:SetPuppet(puppet)

	floor:AddPuppeteers({
		animPuppeteer,
		animGesturer,
		basePuppeteer,
		baseGesturer,
		viewPuppeteer,
	})

	floor:SetPhysicsSize(viewPuppeteer)

	floor:SetPuppet(puppet)

	local panelProps = {
		model = model,
		puppeteer = animPuppeteer,
		gesturer = animGesturer,
		basePuppeteer = basePuppeteer,
		baseGesturer = baseGesturer,
		viewPuppeteer = viewPuppeteer,
		puppet = puppet,
		physicsCount = physicsCount,
		floor = floor,
	}

	-- UI Elements
	local panelChildren = ui.ConstructPanel(cPanel, panelProps, panelState)

	refreshPoseOffsetter(animPuppeteer, panelChildren, panelState)

	ui.Layout(panelChildren, animPuppeteer)

	-- UI Hooks
	ui.HookPanel(panelChildren, panelProps, panelState, poseOffsetter)

	hook.Remove("OnContextMenuOpen", "ragdollpuppeteer_hookcontext")
	if IsValid(poseOffsetter) then
		hook.Add("OnContextMenuOpen", "ragdollpuppeteer_hookcontext", function()
			local tool = LocalPlayer():GetTool()
			if tool and tool.Mode == "ragdollpuppeteer" then
				poseOffsetter:SetVisible(true)
				poseOffsetter:MakePopup()
			end
		end)
	end

	hook.Remove("OnContextMenuClose", "ragdollpuppeteer_hookcontext")
	if IsValid(poseOffsetter) then
		hook.Add("OnContextMenuClose", "ragdollpuppeteer_hookcontext", function()
			poseOffsetter:SetVisible(false)
			poseOffsetter:SetMouseInputEnabled(false)
			poseOffsetter:SetKeyboardInputEnabled(false)
		end)
	end

	local count = 0
	local id = viewPuppeteer:AddCallback("BuildBonePositions", function(ent, boneCount)
		---@cast ent Entity
		resizePuppeteerToPuppet(ent, puppet, boneCount)
		count = count + 1
		-- After a sufficient amount of resizing, the puppeteer should have all its bones resized so that we can finally set the root scale
		if count >= 25 and IsValid(floor) and not floor:GetPuppeteerRootScale() and puppet.SavedBoneMatrices then
			local floorPos = floor:GetPos()
			local pelvisPos = ent:GetBoneMatrix(ent:TranslatePhysBoneToBone(0))
					and ent:GetBoneMatrix(ent:TranslatePhysBoneToBone(0)):GetTranslation()
				or vector_origin
			local min = ent:GetRenderBounds()

			floor:SetPuppeteerRootScale((floorPos - pelvisPos) - min)
		end
	end)

	local function removePuppeteer()
		hook.Remove("EmitSound", "PuppeteerEmitSound")

		if IsValid(animPuppeteer) and IsValid(panelState.previousPuppeteer) then
			viewPuppeteer:RemoveCallback("BuildBonePositions", id)

			animPuppeteer:Remove()
			basePuppeteer:Remove()
			animGesturer:Remove()
			baseGesturer:Remove()
			viewPuppeteer:Remove()
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
		if not IsValid(animPuppeteer) or not IsValid(animGesturer) then
			return
		end

		local newBasePose = pose.getNonPhysicalPose(animPuppeteer, puppet)
		local newGesturePose = pose.getNonPhysicalPose(animGesturer, puppet)
		net.Start("queryNonPhysBonePoseOfPuppet")
		for b = 1, animPuppeteer:GetBoneCount() do
			net.WriteVector((newBasePose[b][1] + newGesturePose[b][1]))
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

do
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
end

do
	local CIRCLE = {

		-- Circle
		{ x = -3, y = -3 },

		{ x = 0, y = -4 },
		{ x = 3, y = -3 },
		{ x = 4, y = 0 },
		{ x = 3, y = 3 },
		{ x = 0, y = 4 },
		{ x = -3, y = 3 },
		{ x = -4, y = 0 },
	}

	local COLOR_GREEN = Color(0, 255, 0, 255)

	function TOOL:DrawHUD()
		local puppet = panelState.puppet
		if panelState.selectedBone > 0 and IsValid(puppet) then
			local matrix = puppet:GetBoneMatrix(panelState.selectedBone)
			if not matrix then
				return
			end
			local pos = matrix:GetTranslation()
			pos = pos:ToScreen()
			local x, y = pos.x, pos.y

			local shape = table.Copy(CIRCLE)
			for _, v in ipairs(shape) do
				v.x = v.x + x
				v.y = v.y + y
			end

			draw.NoTexture()
			surface.SetDrawColor(COLOR_GREEN:Unpack())
			surface.DrawPoly(shape)
		end
	end
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
	{
		name = "reload",
	},
}
