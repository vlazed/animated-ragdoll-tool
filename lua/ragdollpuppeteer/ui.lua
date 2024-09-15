---@module "ragdollpuppeteer.smh"
local SMH = include("ragdollpuppeteer/smh.lua")

---@class BoneTreeNode: DTree_Node
---@field locked boolean
---@field boneIcon string
---@field boneId integer

---@class PoseParameterSlider
---@field slider DNumSlider
---@field name string

---@class PanelChildren
---@field puppetLabel DLabel
---@field smhBrowser DFileBrowser
---@field smhList DListView
---@field sequenceList DListView
---@field nonPhysCheckBox DCheckBoxLabel
---@field numSlider DNumSlider
---@field searchBar DTextEntry
---@field sourceBox DComboBox
---@field angOffset DNumSlider[]
---@field poseParams PoseParameterSlider[]
---@field findFloor DCheckBoxLabel
---@field boneTree DTree
---@field offsetRoot DCheckBoxLabel

---@class PanelProps
---@field puppet Entity
---@field physicsCount integer
---@field puppeteer Entity
---@field zeroPuppeteer Entity
---@field model string

---@class PanelState
---@field maxFrames integer
---@field previousPuppeteer Entity?
---@field defaultBonePose DefaultBonePose
---@field physicsObjects PhysicsObject[]

local DEFAULT_MAX_FRAME = 60
local SEQUENCE_CHANGE_DELAY = 0.2

local UI = {}

local currentSequence = {
	label = "",
}

local function compressTableToJSON(tab)
	return util.Compress(util.TableToJSON(tab))
end

---@param physicsCount integer
---@return PhysicsObject[]
local function getPhysObjectStructure(physicsCount)
	local physicsObjects = {}
	for i = 0, physicsCount - 1 do
		local parent = net.ReadInt(10)
		local name = net.ReadString()
		physicsObjects[i] = { parent = parent, name = name }
	end
	return physicsObjects
end

---@package
---@param cPanel DForm
---@param model string
---@return DLabel
function UI.PuppetLabel(cPanel, model)
	local panel = cPanel:Help("Current Puppet: " .. model)
	---@cast panel DLabel
	return panel
end

---@package
---@param cPanel DForm
---@return DTextEntry
function UI.SearchBar(cPanel)
	---@diagnostic disable-next-line
	local panel = cPanel:TextEntry("Search Bar:")
	---@cast panel DTextEntry
	panel:SetPlaceholderText("Search for a sequence...")

	return panel
end

---@package
---@param cPanel DForm
---@return DComboBox
function UI.AnimationSourceBox(cPanel)
	---@diagnostic disable-next-line
	local panel = cPanel:ComboBox("Source")
	---@cast panel DComboBox

	panel:AddChoice("Sequence")
	panel:AddChoice("Stop Motion Helper")
	panel:ChooseOption("Sequence", 1)

	return panel
end

---@package
---@param cPanel DForm
---@param puppeteer Entity
---@return DButton
function UI.UpdatePuppeteerButton(cPanel, puppeteer)
	local panel = cPanel:Button("Update Puppeteer Position", "ragdollpuppeteer_updateposition", puppeteer)
	---@cast panel DButton
	return panel
end

---@package
---@param cPanel DForm
---@param label string
---@return DNumSlider
function UI.FrameSlider(cPanel, label)
	label = label or "Frame"
	local panel = cPanel:NumSlider(label, "ragdollpuppeteer_frame", 0, DEFAULT_MAX_FRAME - 1, 0)
	---@cast panel DNumSlider
	return panel
end

---@package
---@param cPanel DForm
---@return DCheckBoxLabel
function UI.NonPhysCheckBox(cPanel)
	local panel = cPanel:CheckBox("Animate Nonphysical Bones", "ragdollpuppeteer_animatenonphys")
	---@cast panel DCheckBoxLabel
	return panel
end

---@package
---@param cPanel DForm
---@return DCheckBoxLabel
function UI.OffsetRoot(cPanel)
	local panel = cPanel:CheckBox("Offset Root", "ragdollpuppeteer_offsetroot")
	---@cast panel DCheckBoxLabel
	return panel
end

---@package
---@param cPanel DForm
---@return DCheckBoxLabel
function UI.FindFloor(cPanel)
	local panel = cPanel:CheckBox("Teleport to Floor", "ragdollpuppeteer_updateposition_floors")
	---@cast panel DCheckBoxLabel
	return panel
end

---@package
---@param cPanel DForm
---@return DListView
function UI.SequenceList(cPanel)
	local animationList = vgui.Create("DListView", cPanel)
	animationList:SetMultiSelect(false)
	animationList:AddColumn("Id")
	animationList:AddColumn("Name")
	animationList:AddColumn("FPS")
	animationList:AddColumn("Duration (frames)")
	cPanel:AddItem(animationList)
	return animationList
end

---@package
---@param cPanel DForm
---@return DListView
function UI.SMHEntityList(cPanel)
	local animationList = vgui.Create("DListView", cPanel)
	animationList:SetMultiSelect(false)
	animationList:AddColumn("Name")
	animationList:AddColumn("Duration (frames)")
	cPanel:AddItem(animationList)
	return animationList
end

---@package
---@param cPanel DForm
---@return DFileBrowser
function UI.SMHFileBrowser(cPanel)
	local fileBrowser = vgui.Create("DFileBrowser", cPanel)
	fileBrowser:SetPath("DATA")
	fileBrowser:SetBaseFolder("smh")
	fileBrowser:SetCurrentFolder("smh")
	cPanel:AddItem(fileBrowser)
	return fileBrowser
end

---@package
---@param dForm DForm
---@param names string[]
---@return DNumSlider[]
function UI.AngleNumSliders(dForm, names)
	local sliders = {}
	for i = 1, 3 do
		local slider = dForm:NumSlider(names[i], "", -180, 180)
		---@cast slider DNumSlider
		slider:Dock(TOP)
		slider:SetValue(0)
		sliders[i] = slider
	end
	return sliders
end

---@package
---@param cPanel DForm
---@param names string[]
---@param label string
---@return DNumSlider[]
function UI.AngleNumSliderTrio(cPanel, names, label)
	local dForm = vgui.Create("DForm")
	dForm:SetLabel(label)
	local angleSliders = UI.AngleNumSliders(dForm, names)
	cPanel:AddItem(dForm)
	---@diagnostic disable-next-line
	local resetAngles = dForm:Button("Reset Angles")
	function resetAngles:DoClick()
		for i = 1, 3 do
			angleSliders[i]:SetValue(0)
		end
	end

	dForm:DoExpansion(false)

	return angleSliders
end

---@param index integer
---@param entity Entity
---@param dForm DForm
---@return PoseParameterSlider
local function poseParameterSlider(index, entity, dForm)
	local poseParameterName = entity:GetPoseParameterName(index - 1)
	local min, max = entity:GetPoseParameterRange(index - 1)

	local paramSlider = dForm:NumSlider(poseParameterName, "", min, max)
	---@cast paramSlider DNumSlider
	paramSlider:Dock(TOP)
	paramSlider:SetDefaultValue(0)
	paramSlider:SetValue(0)

	return { slider = paramSlider, name = poseParameterName }
end

---@package
---@param cPanel DForm
---@param puppeteer Entity
---@return PoseParameterSlider[]
function UI.PoseParameters(cPanel, puppeteer)
	---@type PoseParameterSlider[]
	local poseParams = {}

	---@type DForm
	local dForm = vgui.Create("DForm")
	dForm:SetLabel("Pose Parameters")
	local numParameters = puppeteer:GetNumPoseParameters()

	for i = 1, numParameters do
		poseParams[i] = poseParameterSlider(i, puppeteer, dForm)
	end

	---@diagnostic disable-next-line
	local resetParams = dForm:Button("Reset parameters")
	function resetParams:DoClick()
		for i = 1, numParameters do
			poseParams[i].slider:ResetToDefaultValue()
		end
		puppeteer:ClearPoseParameters()
	end

	cPanel:AddItem(dForm)
	dForm:DoExpansion(false)

	return poseParams
end

local function getAngleTrio(trio)
	return { trio[1]:GetValue(), trio[2]:GetValue(), trio[3]:GetValue() }
end

---@param dList DListView
function UI.ClearList(dList)
	for i = 1, #dList:GetLines() do
		dList:RemoveLine(i)
	end
end

---Populate the DList with compatible SMH entities (compatible meaning the SMH entity has the same model as the puppet)
---@param seqList DListView
---@param model string
---@param data SMHFile?
---@param predicate fun(SMHProperties: SMHProperties): boolean
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
		---@cast line DListView_Line

		line:SetSortValue(3, physFrames)
		line:SetSortValue(4, nonPhysFrames)
	end
end

---Find the longest animation of the sequence
---The longest animation is assumed to be the main animation for the sequence
---@param sequenceInfo SequenceInfo
---@param puppeteer Entity
---@return table|unknown
local function findLongestAnimationIn(sequenceInfo, puppeteer)
	local longestAnim = {
		numframes = -1,
	}

	for _, anim in pairs(sequenceInfo.anims) do
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

---@package
---Populate the DList with the puppeteer sequence
---@param seqList DListView
---@param puppeteer Entity
---@param predicate fun(seqInfo: SequenceInfo): boolean
function UI.PopulateSequenceList(seqList, puppeteer, predicate)
	local defaultFPS = 30
	for i = 0, puppeteer:GetSequenceCount() - 1 do
		local seqInfo = puppeteer:GetSequenceInfo(i)
		if not predicate(seqInfo) then
			continue
		end
		local longestAnim = findLongestAnimationIn(seqInfo, puppeteer)
		local fps = defaultFPS
		local maxFrame = DEFAULT_MAX_FRAME
		-- Assume the first animation is the "base", which may have the maximum number of frames compared to other animations in the sequence
		if longestAnim.numframes > -1 then
			maxFrame = longestAnim.numframes
			fps = longestAnim.fps
		end

		seqList:AddLine(i, seqInfo.label, fps, maxFrame)
	end
end

---@param sequenceList DListView
---@param smhList DListView
---@param smhBrowser DFileBrowser
---@param puppeteer Entity
function UI.Layout(sequenceList, smhList, smhBrowser, puppeteer)
	sequenceList:Dock(TOP)
	smhList:Dock(TOP)
	smhBrowser:Dock(TOP)

	UI.PopulateSequenceList(sequenceList, puppeteer, function(_)
		return true
	end)

	smhList:SizeTo(-1, 0, 0.5)
	smhBrowser:SizeTo(-1, 0, 0.5)
	sequenceList:SizeTo(-1, 500, 0.5)
end

---@param panelChildren PanelChildren
---@param panelProps PanelProps
---@param panelState PanelState
function UI.NetHookPanel(panelChildren, panelProps, panelState)
	local numSlider = panelChildren.numSlider

	-- Network hooks from server
	net.Receive("onFramePrevious", function()
		numSlider:SetValue((numSlider:GetValue() - 1) % numSlider:GetMax())
	end)
	net.Receive("onFrameNext", function()
		numSlider:SetValue((numSlider:GetValue() + 1) % numSlider:GetMax())
	end)
	net.Receive("queryPhysObjects", function()
		local newPhysicsObjects = getPhysObjectStructure(panelProps.physicsCount)
		panelState.physicsObjects = newPhysicsObjects
		PrintTable(newPhysicsObjects)
	end)

	-- Initially, we don't have the phys objects, or the phys objects are different from the last entity
	net.Start("queryPhysObjects")
	net.SendToServer()
end

---@package
---Container for ConVar settings
---@param cPanel DForm
---@return DForm
function UI.Settings(cPanel)
	local settings = vgui.Create("DForm", cPanel)
	settings:SetLabel("Settings")

	cPanel:AddItem(settings)

	return settings
end

---@package
---Container for lists
---@param cPanel DForm
---@return DForm
function UI.Lists(cPanel)
	local lists = vgui.Create("DForm", cPanel)
	lists:SetLabel("Hide Animation List")
	cPanel:AddItem(lists)

	function lists:OnToggle(expanded)
		if expanded then
			lists:SetLabel("Hide Animation List")
		else
			lists:SetLabel("Show Animation List")
		end
	end

	return lists
end

---@package
---Container for timelines
---@param cPanel DForm
---@return DForm
function UI.Timelines(cPanel)
	local timelines = vgui.Create("DForm", cPanel)
	timelines:SetLabel("Timelines")
	cPanel:AddItem(timelines)

	return timelines
end

local boneIcons = {
	"icon16/brick.png",
	"icon16/connect.png",
	"icon16/lock.png",
}

---@param bone integer
---@param puppet Entity
---@return string
local function boneIcon(bone, puppet)
	local physOrNonPhys = puppet:TranslateBoneToPhysBone(bone) > -1 and 1 or 2

	return boneIcons[physOrNonPhys]
end

---Add the bone nodes for the boneTree from the puppet
---@param puppet Entity
---@param boneTree DTree
local function setupBoneNodesOf(puppet, boneTree)
	---@type BoneTreeNode[]
	local nodes = {}

	for b = 0, puppet:GetBoneCount() - 1 do
		local boneIcon = boneIcon(b, puppet)
		local boneName = puppet:GetBoneName(b)
		if boneName == "__INVALIDBONE__" then
			continue
		end

		local boneParent = puppet:GetBoneParent(b)

		if boneParent == -1 then
			---@diagnostic disable-next-line
			nodes[b + 1] = boneTree:AddNode(boneName, boneIcon)
			nodes[b + 1].boneIcon = boneIcon
			nodes[b + 1].boneId = b
		else
			local boneParentName = puppet:GetBoneName(boneParent)
			for c = 0, puppet:GetBoneCount() - 1 do
				if nodes[c + 1] and nodes[c + 1]:GetText() == boneParentName then
					---@diagnostic disable-next-line
					nodes[b + 1] = nodes[c + 1]:AddNode(boneName, boneIcon)
					nodes[b + 1].boneIcon = boneIcon
					nodes[b + 1].boneId = b
					break
				end
			end
		end
	end
end

---@package
---@param cPanel DForm
---@return DTree
function UI.BoneTree(cPanel)
	local boneTreeContainer = vgui.Create("DForm", cPanel)
	cPanel:AddItem(boneTreeContainer)
	boneTreeContainer:SetLabel("Filter Bone Tree")
	boneTreeContainer:Help("Toggle bones for animation by clicking on a node on the tree.")
	boneTreeContainer:Dock(TOP)

	local boneTree = vgui.Create("DTree", boneTreeContainer)
	boneTreeContainer:AddItem(boneTree)
	boneTree:Dock(TOP)

	boneTree:SizeTo(-1, 250, 0)

	boneTreeContainer:SetExpanded(false)

	return boneTree
end

---Construct the ragdoll puppeteer control panel and return its components
---@param panelProps PanelProps
---@return PanelChildren
function UI.ConstructPanel(cPanel, panelProps)
	local model = panelProps.model
	local puppeteer = panelProps.puppeteer

	local puppetLabel = UI.PuppetLabel(cPanel, model)
	local timelines = UI.Timelines(cPanel)
	local numSlider = UI.FrameSlider(timelines, "Base")
	local angOffset = UI.AngleNumSliderTrio(cPanel, { "Pitch", "Yaw", "Roll" }, "Angle Offset")
	local poseParams = UI.PoseParameters(cPanel, puppeteer)
	local settings = UI.Settings(cPanel)
	local nonPhysCheckbox = UI.NonPhysCheckBox(settings)
	local findFloor = UI.FindFloor(settings)
	local offsetRoot = UI.OffsetRoot(settings)
	local updatePuppeteerButton = UI.UpdatePuppeteerButton(settings, puppeteer)

	local boneTree = UI.BoneTree(cPanel)

	local lists = UI.Lists(cPanel)

	local sourceBox = UI.AnimationSourceBox(lists)
	local searchBar = UI.SearchBar(lists)
	local sequenceList = UI.SequenceList(lists)
	local smhBrowser = UI.SMHFileBrowser(lists)
	local smhList = UI.SMHEntityList(lists)

	return {
		puppetLabel = puppetLabel,
		numSlider = numSlider,
		angOffset = angOffset,
		nonPhysCheckBox = nonPhysCheckbox,
		updatePuppeteerButton = updatePuppeteerButton,
		sourceBox = sourceBox,
		searchBar = searchBar,
		sequenceList = sequenceList,
		smhBrowser = smhBrowser,
		smhList = smhList,
		poseParams = poseParams,
		findFloor = findFloor,
		boneTree = boneTree,
		offsetRoot = offsetRoot,
	}
end

---@param puppeteer Entity
---@param sequenceIndex integer
local function setSequenceOf(puppeteer, sequenceIndex)
	puppeteer:ResetSequence(sequenceIndex)
	puppeteer:SetCycle(0)
	puppeteer:SetPlaybackRate(0)
end

---@param panelChildren PanelChildren
---@param panelProps PanelProps
---@param panelState PanelState
function UI.HookPanel(panelChildren, panelProps, panelState)
	local prevFrame = 0

	local smhList = panelChildren.smhList
	local sequenceList = panelChildren.sequenceList
	local smhBrowser = panelChildren.smhBrowser
	local numSlider = panelChildren.numSlider
	local sourceBox = panelChildren.sourceBox
	local nonPhysCheckbox = panelChildren.nonPhysCheckBox
	local searchBar = panelChildren.searchBar
	local angOffset = panelChildren.angOffset
	local poseParams = panelChildren.poseParams
	local boneTree = panelChildren.boneTree

	local animPuppeteer = panelProps.puppeteer
	local zeroPuppeteer = panelProps.zeroPuppeteer
	local puppet = panelProps.puppet
	local model = panelProps.model
	local physicsCount = panelProps.physicsCount

	local smhData

	setupBoneNodesOf(puppet, boneTree)

	local filteredBones = {}
	for b = 1, puppet:GetBoneCount() do
		filteredBones[b] = false
	end

	---@param node BoneTreeNode
	function boneTree:DoClick(node)
		node.locked = not node.locked
		node:SetIcon(node.locked and boneIcons[#boneIcons] or node.boneIcon)
		filteredBones[node.boneId + 1] = node.locked
		net.Start("onBoneFilterChange")
		net.WriteTable(filteredBones, true)
		net.SendToServer()
	end

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

	---https://github.com/penolakushari/StandingPoseTool/blob/b7dc7b3b57d2d940bb6a4385d01a4b003c97592c/lua/autorun/standpose.lua#L42
	---@param ent Entity
	---@param rag Entity
	---@param physicsCount integer
	---@param physicsObjects PhysicsObject[]
	---@param originEnt Entity
	local function writeSequencePose(ent, rag, physicsCount, physicsObjects, originEnt)
		-- TODO: Use nonphysical bones move physical bones implementation
		local willOffset = GetConVar("ragdollpuppeteer_offsetroot"):GetInt() > 0

		-- Origin position and angles in world coordinates
		local originBone = rag:TranslatePhysBoneToBone(0)
		local originPos, originAng = originEnt:GetBonePosition(originBone)

		local newPose = {}

		if game.SinglePlayer() then
			for i = 0, physicsCount - 1 do
				local b = rag:TranslatePhysBoneToBone(i)
				local p = physicsObjects[i].parent
				local pos, ang = ent:GetBonePosition(b)
				if pos == ent:GetPos() then
					local matrix = ent:GetBoneMatrix(b)
					if matrix then
						pos = matrix:GetTranslation()
						ang = matrix:GetAngles()
					end
				end

				-- If we're offsetting from the puppeteer, we're animating limbs with respect to the root/pelvis bone
				if willOffset then
					-- Query for the root/pelvis bone
					if p == -1 or i == 0 then
						-- FIXME: Offset angles rotate root bone inconsistently
						-- Obtain the offset. Why? We want to preserve pelvis movements from sequence, so it won't look stiff
						local offsetPos, offsetAng = WorldToLocal(pos, ang, originPos, originAng)
						local bMatrix = rag:GetBoneMatrix(b)
						-- Replace pos, ang with the current position of the puppet's root/pelvis
						pos, ang = bMatrix:GetTranslation(), bMatrix:GetAngles()
						-- Move pelvis with offset
						-- pos, ang = LocalToWorld(offsetPos, offsetAng, pos, ang)
					else
						-- We have a parent, so obtain offset and angles with respect to the parent bone's location
						if newPose[p] then
							-- Get position and angles of the new parent pose, in world coordinates
							local parentPos, parentAng = newPose[p][1], newPose[p][2]
							-- Get position and angles of the old parent pose, in world coordinates
							local parentBone = rag:TranslatePhysBoneToBone(p)
							local puppeteerParentPos, puppeteerParentAng = ent:GetBonePosition(parentBone)
							-- Get relative position and angles of child bone with respect to parent pose
							pos, ang = WorldToLocal(pos, ang, puppeteerParentPos, puppeteerParentAng)
							-- Get world position and angles of child bone with respect to new parent pose
							pos, ang = LocalToWorld(pos, ang, parentPos, parentAng)
						end
					end
				end

				-- Save the current bone pose, so later iterations can use it to offset their own bone poses with respect to this one
				newPose[i] = { pos, ang }

				net.WriteVector(pos)
				net.WriteAngle(ang)
			end
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

	angOffset[1].OnValueChanged = onAngleTrioValueChange
	angOffset[2].OnValueChanged = onAngleTrioValueChange
	angOffset[3].OnValueChanged = onAngleTrioValueChange

	---@param newValue number
	---@param paramName string
	---@param slider DNumSlider
	local function onPoseParamChange(newValue, paramName, slider)
		animPuppeteer:SetPoseParameter(paramName, newValue)
		animPuppeteer:InvalidateBoneCache()

		-- If the user has stopped dragging on the sequence, send the update
		timer.Simple(SEQUENCE_CHANGE_DELAY, function()
			if sourceBox:GetSelected() == "Sequence" and not slider:IsEditing() then
				net.Start("onPoseParamChange", true)
				net.WriteBool(nonPhysCheckbox:GetChecked())
				net.WriteFloat(newValue)
				net.WriteString(paramName)
				writeSequencePose(animPuppeteer, puppet, physicsCount, panelState.physicsObjects, zeroPuppeteer)
				net.SendToServer()
			end
		end)
	end

	for i = 1, #poseParams do
		poseParams[i].slider.OnValueChanged = function(_, newValue)
			onPoseParamChange(newValue, poseParams[i].name, poseParams[i].slider)
		end
	end

	function searchBar:OnEnter(text)
		---@cast text string
		if sourceBox:GetSelected() == "Sequence" then
			UI.ClearList(sequenceList)
			UI.PopulateSequenceList(sequenceList, animPuppeteer, function(seqInfo)
				---@cast seqInfo SequenceInfo

				if text:len() > 0 then
					local result = string.find(seqInfo.label:lower(), text:lower())
					return result ~= nil
				else
					return true
				end
			end)
		else
			UI.ClearList(smhList)
			populateSMHEntitiesList(smhList, model, smhData, function(entProp)
				if text:len() > 0 then
					local result = entProp.Class:lower():find(text:lower())
						or entProp.Model:lower():find(text:lower())
						or entProp.Name:lower():find(text:lower())

					return result ~= nil
				else
					return true
				end
			end)
		end
	end

	function sequenceList:OnRowSelected(index, row)
		local currentIndex = row:GetValue(1)
		local seqInfo = animPuppeteer:GetSequenceInfo(currentIndex)
		if currentSequence.label ~= seqInfo.label then
			currentSequence = seqInfo
			setSequenceOf(animPuppeteer, currentIndex)
			setSequenceOf(zeroPuppeteer, currentIndex)

			numSlider:SetMax(row:GetValue(4) - 1)
			panelState.maxFrames = row:GetValue(4) - 1

			timer.Simple(SEQUENCE_CHANGE_DELAY, function()
				net.Start("onSequenceChange")
				net.WriteBool(true)
				net.WriteInt(currentIndex, 14)
				net.WriteBool(nonPhysCheckbox:GetChecked())
				writeSequencePose(animPuppeteer, puppet, physicsCount, panelState.physicsObjects, zeroPuppeteer)
				net.SendToServer()
			end)
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
			writeSequencePose(animPuppeteer, puppet, physicsCount, panelState.physicsObjects, zeroPuppeteer)
			net.SendToServer()
		else
			writeSMHPose("onFrameChange", val)
		end

		prevFrame = val
	end

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
		panelState.maxFrames = row:GetValue(2)
		writeSMHPose("onSequenceChange", 0)
	end

	function smhBrowser:OnSelect(filePath)
		UI.ClearList(smhList)
		smhData = SMH.parseSMHFile(filePath, model)
		populateSMHEntitiesList(smhList, model, smhData, function(_)
			return true
		end)
	end
end

return UI
