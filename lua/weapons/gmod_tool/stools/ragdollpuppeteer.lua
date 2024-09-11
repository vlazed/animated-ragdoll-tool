-- TODO: move clientside code to another file

---@alias DefaultBonePose table<Vector, Angle, Vector, Angle>

---@class SMHBonePose
---@field Pos Vector
---@field LocalPos Vector?
---@field LocalAng Angle?
---@field Ang Angle
---@field Scale Vector

---@alias SMHPose SMHBonePose[]

---@module "ragdollpuppeteer.vendor"
local Vendor = include("ragdollpuppeteer/vendor.lua")

TOOL.Category = "Poser"
TOOL.Name = "#tool.ragdollpuppeteer.name"
TOOL.Command = nil
TOOL.ConfigName = ""
TOOL.ClientConVar["frame"] = 0
TOOL.ClientConVar["animatenonphys"] = "false"

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
end

local id = "ragdollpuppeteer_puppet"
local id2 = "ragdollpuppeteer_puppeteer"
local prevServerAnimPuppet = nil
local bonesReset = false
local defaultAngle = angle_zero

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
	if self:GetAnimationPuppet() == prevServerAnimPuppet then
		return
	end
	prevServerAnimPuppet = self:GetAnimationPuppet()
	print(self:GetAnimationPuppet())
	if CLIENT then
		-- FIXME: Left clicking after right clicking should still rebuild the control panel for the same entity
		self:RebuildControlPanel(self:GetAnimationPuppet(), self:GetOwner())
	end
end

function TOOL:SetAnimationPuppet(puppet)
	return self:GetWeapon():SetNWEntity(id, puppet)
end

function TOOL:GetAnimationPuppet()
	return self:GetWeapon():GetNWEntity(id)
end

function TOOL:SetAnimationPuppeteer(puppeteer)
	return self:GetWeapon():SetNWEntity(id2, puppeteer)
end

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
---@param targetPose SMHPose
---@param puppeteer Entity
---@param offset Angle
local function setPhysicalBonePoseOf(puppet, targetPose, puppeteer, offset)
	local minimumVector = Vector(-16384, -16384, -16384)

	offset = offset and Angle(offset[1], offset[2], offset[3]) or Angle(0, 0, 0)
	for i = 0, puppet:GetPhysicsObjectCount() - 1 do
		local b = puppet:TranslatePhysBoneToBone(i)
		local phys = puppet:GetPhysicsObjectNum(i)
		local parent = puppet:GetPhysicsObjectNum(Vendor.GetPhysBoneParent(puppet, i))
		if not targetPose[i] then
			continue
		end
		if targetPose[i].LocalPos and targetPose[i].LocalPos ~= minimumVector then
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
---@param targetPose SMHPose
local function setNonPhysicalBonePoseOf(puppet, targetPose)
	for b = 0, puppet:GetBoneCount() - 1 do
		puppet:ManipulateBonePosition(b, targetPose[b].Pos)
		puppet:ManipulateBoneAngles(b, targetPose[b].Ang)
		if targetPose[b].Scale then
			puppet:ManipulateBoneScale(b, targetPose[b].Scale)
		end
	end
end

---Move and orient each physical bone of the puppet to the puppeteer
---Source: https://github.com/Winded/StandingPoseTool/blob/master/lua/weapons/gmod_tool/stools/ragdollstand.lua
---@param puppet Entity
---@param puppeteer Entity
local function matchPhysicalBonePoseOf(puppet, puppeteer)
	for i = 0, puppet:GetPhysicsObjectCount() - 1 do
		local phys = puppet:GetPhysicsObjectNum(i)
		local b = puppet:TranslatePhysBoneToBone(i)
		local pos, ang = puppeteer:GetBonePosition(b)
		phys:EnableMotion(false)
		phys:SetPos(pos)
		phys:SetAngles(ang)
		if string.sub(puppet:GetBoneName(b), 1, 4) == "prp_" then
			phys:EnableMotion(true)
			phys:Wake()
		else
			phys:Wake()
		end
	end
end

---Get the pose of every bone of the entity, for nonphysical bone matching
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
local function queryNonPhysBonePoseOfPuppet(ply)
	net.Start("queryNonPhysBonePoseOfPuppet", false)
	net.Send(ply)
end

---Move the puppeteer to the target entity's position, with the option to move to the ground
---@param puppeteer Entity
---@param target Entity
local function setPositionOf(puppeteer, target)
	local tr = util.TraceLine({
		start = target:GetPos(),
		endpos = target:GetPos() - Vector(0, 0, 3000),
		filter = function(e)
			return e:GetClass() == game.GetWorld()
		end,
	})

	puppeteer:SetPos(tr.HitPos)
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

	bonesReset = true
end

-- Select a ragdoll as a puppet to puppeteer
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

	local puppetModel = ragdollPuppet:GetModel()

	---@type Entity
	local animPuppeteer = ents.Create("prop_dynamic")
	if self:GetAnimationPuppet() ~= ragdollPuppet then
		self:Cleanup()
	end
	animPuppeteer:SetModel(puppetModel)
	self:SetAnimationPuppet(ragdollPuppet)
	self:SetAnimationPuppeteer(animPuppeteer)
	setPlacementOf(animPuppeteer, ragdollPuppet, ply)
	animPuppeteer:Spawn()
	styleServerPuppeteer(animPuppeteer)
	queryDefaultBonePoseOfPuppet(puppetModel, ply)

	local currentIndex = 0
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

	local function setPuppeteerPose(cycle, animatingNonPhys)
		-- This statement mimics a sequence change event, so it offsets its sequence to force an animation change. Might test without statement.
		animPuppeteer:ResetSequence((currentIndex == 0) and (currentIndex + 1) or (currentIndex - 1))
		animPuppeteer:ResetSequence(currentIndex)
		animPuppeteer:SetCycle(cycle)
		animPuppeteer:SetPlaybackRate(0)
		matchPhysicalBonePoseOf(ragdollPuppet, animPuppeteer)
		if animatingNonPhys then
			queryNonPhysBonePoseOfPuppet(ply)
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
	end)

	net.Receive("queryNonPhysBonePoseOfPuppet", function(_)
		local newPose = {}
		for b = 1, animPuppeteer:GetBoneCount() do
			newPose[b - 1] = net.ReadTable(true)
			newPose[b - 1].Pos = newPose[b - 1][1]
			newPose[b - 1].Ang = newPose[b - 1][2]
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

-- Stop puppeteering a ragdoll
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
	local tool = ply:GetTool("ragdollpuppeteer")
	local puppeteer = tool:GetAnimationPuppeteer()
	local puppet = tool:GetAnimationPuppet()
	if not IsValid(puppet) or not IsValid(puppeteer) then
		return
	end
	setPlacementOf(puppeteer, puppet, ply)
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

---@type DefaultBonePose
local defaultBonePose = {}

---@type CSEnt?
local prevClientAnimPuppeteer = nil

local maxAnimFrames = 0

TOOL:BuildConVarList()

local function styleClientPuppeteer(puppeteer)
	puppeteer:SetColor(Color(0, 0, 255, 128))
	puppeteer:SetRenderMode(RENDERMODE_TRANSCOLOR)
end

---@param puppeteer Entity
---@param child integer
---@return Vector
---@return Angle
local function getBoneOffsetsOf(puppeteer, child)
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

---Try to manipulate the bone angles of the puppet to match the puppeteer
---@param puppeteer Entity
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

function TOOL.BuildCPanel(cPanel, puppet, ply)
	if not IsValid(puppet) then
		cPanel:Help("No puppet selected")
		return
	end

	local model = puppet:GetModel()

	---@type CSEnt
	local animPuppeteer = ClientsideModel(model, RENDERGROUP_TRANSLUCENT)
	if prevClientAnimPuppeteer and IsValid(prevClientAnimPuppeteer) then
		prevClientAnimPuppeteer:Remove()
	end
	animPuppeteer:SetModel(model)
	setPlacementOf(animPuppeteer, puppet, ply)
	animPuppeteer:Spawn()
	styleClientPuppeteer(animPuppeteer)

	-- UI Elements
	local puppetLabel = UI.PuppetLabel(cPanel, model)
	local numSlider = UI.FrameSlider(cPanel)
	local angOffset = UI.AngleNumSliderTrio(cPanel, { "Pitch", "Yaw", "Roll" }, "Angle Offset")
	local nonPhysCheckbox = UI.NonPhysCheckBox(cPanel)
	local updatePuppeteerButton = UI.UpdatePuppeteerButton(cPanel, animPuppeteer)
	local sourceBox = UI.AnimationSourceBox(cPanel)
	local searchBar = UI.SearchBar(cPanel)
	local sequenceList = UI.SequenceList(cPanel)
	local smhBrowser = UI.SMHFileBrowser(cPanel)
	local smhList = UI.SMHEntityList(cPanel)

	sequenceList:Dock(TOP)
	smhList:Dock(TOP)
	smhBrowser:Dock(TOP)

	UI.PopulateSequenceList(sequenceList, animPuppeteer, function(_)
		return true
	end)

	smhList:SizeTo(-1, 0, 0.5)
	smhBrowser:SizeTo(-1, 0, 0.5)
	sequenceList:SizeTo(-1, 500, 0.5)

	-- UI Hooks
	maxAnimFrames = UI.HookPanel({
		smhBrowser = smhBrowser,
		smhList = smhList,
		numSlider = numSlider,
		angOffset = angOffset,
		sequenceList = sequenceList,
		nonPhysCheckBox = nonPhysCheckbox,
		searchBar = searchBar,
		sourceBox = sourceBox,
	}, {
		model = model,
		puppeteer = animPuppeteer,
		maxFrames = maxAnimFrames,
	})

	UI.NetHookPanel(numSlider)

	net.Receive("updateClientPosition", function()
		setPlacementOf(animPuppeteer, puppet, ply)
	end)

	net.Receive("queryNonPhysBonePoseOfPuppet", function(_, _)
		if #defaultBonePose == 0 then
			return
		end

		net.Start("queryNonPhysBonePoseOfPuppet")
		local newPose = matchNonPhysicalBonePoseOf(animPuppeteer)
		for b = 1, animPuppeteer:GetBoneCount() do
			net.WriteTable(newPose[b], true)
		end
		net.SendToServer()
	end)

	net.Receive("removeClientAnimPuppeteer", function()
		if IsValid(animPuppeteer) then
			animPuppeteer:Remove()
			prevClientAnimPuppeteer = nil
			UI.ClearList(sequenceList)
			UI.ClearList(smhList)
			puppetLabel:SetText("No puppet selected.")
		end
	end)

	-- End of lifecycle events
	puppet:CallOnRemove("RemoveAnimPuppeteer", function()
		if IsValid(animPuppeteer) then
			animPuppeteer:Remove()
			prevClientAnimPuppeteer = nil
			UI.ClearList(sequenceList)
			UI.ClearList(smhList)
			puppetLabel:SetText("No puppet selected.")
		end
	end)

	prevClientAnimPuppeteer = animPuppeteer
end

net.Receive("queryDefaultBonePoseOfPuppet", function(_, _)
	net.Start("queryDefaultBonePoseOfPuppet")
	local netModel = net.ReadString()
	local csModel = ents.CreateClientProp()
	csModel:SetModel(netModel)
	csModel:DrawModel()
	csModel:SetupBones()
	csModel:InvalidateBoneCache()
	defaultBonePose = getDefaultBonePoseOf(csModel)

	for b = 1, csModel:GetBoneCount() do
		net.WriteTable(defaultBonePose[b], true)
	end

	csModel:Remove()
	net.SendToServer()
end)

local COLOR_WHITE = Color(200, 200, 200)
local COLOR_WHITE_BRIGHT = Color(255, 255, 255)
local COLOR_GREY = Color(128, 128, 128)
function TOOL:DrawToolScreen(width, height)
	--surface.SetDrawColor(Color(20, 20, 20))
	local y = 19.25 * height / 32
	local ySize = height / 18
	local frame = GetConVar("ragdollpuppeteer_frame")
	draw.SimpleText(
		"Ragdoll Puppeteer",
		"DermaLarge",
		width / 2,
		height - height / 1.75,
		COLOR_WHITE,
		TEXT_ALIGN_CENTER,
		TEXT_ALIGN_BOTTOM
	)
	draw.SimpleText(
		"Current Frame: " .. frame:GetString(),
		"GModToolSubtitle",
		width / 2,
		height / 2,
		COLOR_WHITE,
		TEXT_ALIGN_CENTER,
		TEXT_ALIGN_CENTER
	)
	draw.RoundedBox(2, 0, y, width, ySize, COLOR_GREY)
	draw.RoundedBox(2, 0, y, width * frame:GetFloat() / maxAnimFrames, ySize, COLOR_WHITE_BRIGHT)
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
