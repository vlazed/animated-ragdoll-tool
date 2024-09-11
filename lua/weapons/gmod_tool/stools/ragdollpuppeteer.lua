-- TODO: move clientside code to another file

---@alias DefaultBonePose table<Vector, Angle, Vector, Angle>

---@class AnimInfo
---@field numframes number

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

local function compressTableToJSON(tab)
	return util.Compress(util.TableToJSON(tab))
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

---@module "ragdollpuppeteer.smh"
local SMH = include("ragdollpuppeteer/smh.lua")

---@type DefaultBonePose
local defaultBonePose = {}

---@type CSEnt?
local prevClientAnimPuppeteer = nil
local currentSequence = {
	label = "",
}

local maxAnimFrames = 0

TOOL:BuildConVarList()

local function styleClientPuppeteer(puppeteer)
	puppeteer:SetColor(Color(0, 0, 255, 128))
	puppeteer:SetRenderMode(RENDERMODE_TRANSCOLOR)
end

local function constructSequenceList(cPanel)
	local animationList = vgui.Create("DListView", cPanel)
	animationList:SetMultiSelect(false)
	animationList:AddColumn("Id")
	animationList:AddColumn("Name")
	animationList:AddColumn("FPS")
	animationList:AddColumn("Duration (frames)")
	cPanel:AddItem(animationList)
	return animationList
end

local function constructSMHEntityList(cPanel)
	local animationList = vgui.Create("DListView", cPanel)
	animationList:SetMultiSelect(false)
	animationList:AddColumn("Name")
	animationList:AddColumn("Duration (frames)")
	cPanel:AddItem(animationList)
	return animationList
end

local function constructSMHFileBrowser(cPanel)
	local fileBrowser = vgui.Create("DFileBrowser", cPanel)
	fileBrowser:SetPath("DATA")
	fileBrowser:SetBaseFolder("smh")
	fileBrowser:SetCurrentFolder("smh")
	cPanel:AddItem(fileBrowser)
	return fileBrowser
end

local function constructAngleNumSliders(dForm, names)
	local sliders = {}
	for i = 1, 3 do
		local slider = dForm:NumSlider(names[i], "", -180, 180)
		slider:Dock(TOP)
		slider:SetValue(0)
		sliders[i] = slider
	end
	return sliders
end

local function constructAngleNumSliderTrio(cPanel, names, label)
	local dForm = vgui.Create("DForm")
	dForm:SetLabel(label)
	local angleSliders = constructAngleNumSliders(dForm, names)
	cPanel:AddItem(dForm)
	local resetAngles = dForm:Button("Reset Angles")
	function resetAngles:DoClick()
		for i = 1, 3 do
			angleSliders[i]:SetValue(0)
		end
	end
	return angleSliders
end

---Find the longest animation of the sequence
---The longest animation is assumed to be the main animation for the sequence
---@param sequenceInfo SequenceInfo
---@param puppeteer Entity
---@return AnimInfo
local function findLongestAnimationIn(sequenceInfo, puppeteer)
	local longestAnim = {
		numframes = -1,
	}

	for _, anim in pairs(sequenceInfo.anims) do
		---@type AnimInfo?
		local animInfo = puppeteer:GetAnimInfo(anim)
		if not (animInfo and animInfo.numframes) then
			continue
		end
		if animInfo.numframes > longestAnim.numframes then
			longestAnim = animInfo
		end
	end

	return longestAnim
end

-- Populate the DList with compatible SMH entities (compatible meaning the SMH entity has the same model as the puppet)
local function populateSMHEntitiesList(seqList, model, data, predicate)
	if not data then
		return
	end
	local maxFrames = 0
	for _, entity in pairs(data.Entities) do
		if entity.Properties.Model ~= model then
			continue
		end
		if not predicate(entity.Properties) then
			continue
		end
		local physFrames = {}
		local nonPhysFrames = {}
		local pFrames = 0
		local nFrames = 0
		local lmax = 0
		for _, fdata in pairs(entity.Frames) do
			if fdata.EntityData and fdata.EntityData.physbones then
				table.insert(physFrames, fdata)
				pFrames = fdata.Position
			end

			if fdata.EntityData and fdata.EntityData.bones then
				table.insert(nonPhysFrames, fdata)
				nFrames = fdata.Position
			end

			lmax = (pFrames > nFrames) and pFrames or nFrames
			if lmax > maxFrames then
				maxFrames = lmax
			end
		end

		local line = seqList:AddLine(entity.Properties.Name, maxFrames)
		line:SetSortValue(3, physFrames)
		line:SetSortValue(4, nonPhysFrames)
	end
end

-- Populate the DList with the puppeteer sequence
local function populateSequenceList(seqList, puppeteer, predicate)
	local defaultMaxFrame = 60
	local defaultFPS = 30
	for i = 0, puppeteer:GetSequenceCount() - 1 do
		local seqInfo = puppeteer:GetSequenceInfo(i)
		if not predicate(seqInfo) then
			continue
		end
		local longestAnim = findLongestAnimationIn(seqInfo, puppeteer)
		local fps = defaultFPS
		local maxFrame = defaultMaxFrame
		-- Assume the first animation is the "base", which may have the maximum number of frames compared to other animations in the sequence
		if longestAnim.numframes > -1 then
			maxFrame = longestAnim.numframes
			fps = longestAnim.fps
		end

		seqList:AddLine(i, seqInfo.label, fps, maxFrame)
	end
end

local function clearList(dList)
	for i = 1, #dList:GetLines() do
		dList:RemoveLine(i)
	end
end

local function getAngleTrio(trio)
	return { trio[1]:GetValue(), trio[2]:GetValue(), trio[3]:GetValue() }
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

	local defaultMaxFrame = 60
	local prevFrame = 0
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
	local puppetLabel = cPanel:Help("Current Puppet: " .. model)
	local numSlider = cPanel:NumSlider("Frame", "ragdollpuppeteer_frame", 0, defaultMaxFrame - 1, 0)
	local angOffset = constructAngleNumSliderTrio(cPanel, { "Pitch", "Yaw", "Roll" }, "Angle Offset")
	local nonPhysCheckbox = cPanel:CheckBox("Animate Nonphysical Bones", "ragdollpuppeteer_animatenonphys")
	cPanel:Button("Update Puppeteer Position", "ragdollpuppeteer_updateposition", animPuppeteer)
	local sourceBox = cPanel:ComboBox("Source")
	sourceBox:AddChoice("Sequence")
	sourceBox:AddChoice("Stop Motion Helper")
	sourceBox:ChooseOption("Sequence", 1)
	local searchBar = cPanel:TextEntry("Search Bar:")
	searchBar:SetPlaceholderText("Search for a sequence...")
	local sequenceList = constructSequenceList(cPanel)
	local smhBrowser = constructSMHFileBrowser(cPanel)
	local smhList = constructSMHEntityList(cPanel)
	sequenceList:Dock(TOP)
	smhList:Dock(TOP)
	smhBrowser:Dock(TOP)
	populateSequenceList(sequenceList, animPuppeteer, function(_)
		return true
	end)
	smhList:SizeTo(-1, 0, 0.5)
	smhBrowser:SizeTo(-1, 0, 0.5)
	sequenceList:SizeTo(-1, 500, 0.5)

	local function encodePose(pose)
		net.WriteUInt(#pose, 16)
		for i = 0, #pose do
			net.WriteVector(pose[i].Pos or vector_origin)
			net.WriteAngle(pose[i].Ang or angle_zero)
			net.WriteVector(pose[i].Scale or Vector(-1, -1, -1))
			net.WriteVector(pose[i].LocalPos or Vector(-16384, -16384, -16384))
			net.WriteAngle(pose[i].LocalAng or Angle(0, 0, 0))
		end
	end

	local function writeSMHPose(netString, frame)
		if not smhList:GetSelected()[1] then
			return
		end
		local physBonePose = SMH.getPoseFromSMHFrames(frame, smhList:GetSelected()[1]:GetSortValue(3), "physbones")
		local compressedOffset = compressTableToJSON(getAngleTrio(angOffset))
		net.Start(netString, true)
		net.WriteBool(false)
		encodePose(physBonePose)
		net.WriteUInt(#compressedOffset, 16)
		net.WriteData(compressedOffset)
		net.WriteBool(nonPhysCheckbox:GetChecked())
		if nonPhysCheckbox:GetChecked() then
			local nonPhysBoneData = SMH.getPoseFromSMHFrames(frame, smhList:GetSelected()[1]:GetSortValue(4), "bones")
			local compressedNonPhysPose = compressTableToJSON(nonPhysBoneData)
			net.WriteUInt(#compressedNonPhysPose, 16)
			net.WriteData(compressedNonPhysPose)
		end

		net.SendToServer()
	end

	local function onAngleTrioValueChange()
		writeSMHPose("onFrameChange", numSlider:GetValue())
	end

	-- UI Hooks
	function searchBar:OnEnter(text)
		if sourceBox:GetSelected() == "Sequence" then
			clearList(sequenceList)
			populateSequenceList(sequenceList, animPuppeteer, function(seqInfo)
				if text:len() > 0 then
					return string.find(seqInfo.label, text)
				else
					return true
				end
			end)
		else
			populateSMHEntitiesList(smhList, animPuppeteer, function(entProp)
				if text:len() > 0 then
					return entProp == text
				else
					return true
				end
			end)
		end
	end

	function sequenceList:OnRowSelected(index, row)
		local seqInfo = animPuppeteer:GetSequenceInfo(row:GetValue(1))
		if currentSequence.label ~= seqInfo.label then
			currentSequence = seqInfo
			animPuppeteer:ResetSequence(row:GetValue(1))
			animPuppeteer:SetCycle(0)
			animPuppeteer:SetPlaybackRate(0)
			numSlider:SetMax(row:GetValue(4) - 1)
			maxAnimFrames = row:GetValue(4) - 1
			net.Start("onSequenceChange")
			net.WriteBool(true)
			net.WriteInt(row:GetValue(1), 14)
			net.WriteBool(nonPhysCheckbox:GetChecked())
			net.SendToServer()
		end
	end

	-- TODO: Set a limit to how many times a new frame can be sent to the server to prevent spamming
	function numSlider:OnValueChanged(val)
		-- Only send when we go frame by frame
		if math.abs(prevFrame - val) < 1 then
			return
		end
		local option, _ = sourceBox:GetSelected()
		if option == "Sequence" then
			if not currentSequence.anims then
				return
			end
			if not IsValid(animPuppeteer) then
				return
			end
			local numframes = findLongestAnimationIn(currentSequence, animPuppeteer).numframes - 1
			numSlider:SetValue(math.Clamp(val, 0, numframes))
			local cycle = val / numframes
			animPuppeteer:SetCycle(cycle)
			net.Start("onFrameChange", true)
			net.WriteBool(true)
			net.WriteFloat(cycle)
			net.WriteBool(nonPhysCheckbox:GetChecked())
			net.SendToServer()
		else
			writeSMHPose("onFrameChange", val)
		end

		prevFrame = val
	end

	angOffset[1].OnValueChanged = onAngleTrioValueChange
	angOffset[2].OnValueChanged = onAngleTrioValueChange
	angOffset[3].OnValueChanged = onAngleTrioValueChange
	function sourceBox:OnSelect(ind, val, data)
		if val == "Sequence" then
			smhList:SizeTo(-1, 0, 0.5)
			smhBrowser:SizeTo(-1, 0, 0.5)
			sequenceList:SizeTo(-1, 500, 0.5)
		else
			sequenceList:SizeTo(-1, 0, 0.5)
			smhList:SizeTo(-1, 250, 0.5)
			smhBrowser:SizeTo(-1, 250, 0.5)
		end
	end

	function smhList:OnRowSelected(index, row)
		numSlider:SetMax(row:GetValue(2))
		maxAnimFrames = row:GetValue(2)
		writeSMHPose("onSequenceChange", 0)
	end

	function smhBrowser:OnSelect(filePath)
		clearList(smhList)
		local data = SMH.parseSMHFile(filePath, model)
		populateSMHEntitiesList(smhList, model, data, function(_)
			return true
		end)
	end

	-- Network hooks from server
	net.Receive("onFramePrevious", function()
		numSlider:SetValue((numSlider:GetValue() - 1) % numSlider:GetMax())
	end)
	net.Receive("onFrameNext", function()
		numSlider:SetValue((numSlider:GetValue() + 1) % numSlider:GetMax())
	end)
	net.Receive("updateClientPosition", function()
		setPlacementOf(animPuppeteer, puppet, ply)
	end)
	net.Receive("removeClientAnimPuppeteer", function()
		if IsValid(animPuppeteer) then
			animPuppeteer:Remove()
			prevClientAnimPuppeteer = nil
			clearList(sequenceList)
			clearList(smhList)
			puppetLabel:SetText("No puppet selected.")
		end
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

	-- End of lifecycle events
	puppet:CallOnRemove("RemoveAnimPuppeteer", function()
		if IsValid(animPuppeteer) then
			animPuppeteer:Remove()
			prevClientAnimPuppeteer = nil
			clearList(sequenceList)
			clearList(smhList)
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

-- Relative sizes with respect to the width and height of the tool screen
local TEXT_WIDTH_MODIFIER = 0.5
local TEXT_HEIGHT_MODIFIER = 0.428571429
local BAR_HEIGHT = 0.0555555556
local BAR_Y_POS = 0.6015625

local lastWidth
local lastFrame = GetConVar("ragdollpuppeteer_frame"):GetFloat()

function TOOL:DrawToolScreen(width, height)
	local y = height * BAR_Y_POS
	local ySize = height * BAR_HEIGHT
	local frame = GetConVar("ragdollpuppeteer_frame"):GetFloat()
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
