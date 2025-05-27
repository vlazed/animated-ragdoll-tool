---@module "ragdollpuppeteer.lib.smh"
local smh = include("ragdollpuppeteer/lib/smh.lua")
---@module "ragdollpuppeteer.constants"
local constants = include("ragdollpuppeteer/constants.lua")
---@module "ragdollpuppeteer.client.components"
local components = include("components.lua")
---@module "ragdollpuppeteer.lib.vendor"
local vendor = include("ragdollpuppeteer/lib/vendor.lua")
---@module "ragdollpuppeteer.lib.helpers"
local helpers = include("ragdollpuppeteer/lib/helpers.lua")
---@module "ragdollpuppeteer.client.pose"
local pose = include("ragdollpuppeteer/lib/pose.lua")

local COLOR_BLUE = constants.COLOR_BLUE
local PREFIXES = constants.PREFIXES
local SUFFIXES = constants.SUFFIXES
local FILTER = constants.POSEFILTER
local DEFAULT_MAX_FRAME = constants.DEFAULT_MAX_FRAME
local LOCOMOTION_POSEPARAMS = constants.LOCOMOTION_POSEPARAMS
local LOCOMOTION = constants.LOCOMOTION
local SEQUENCE_CHANGE_DELAY = 0.2

local UI = {}

local requestMessages = {
	language.GetPhrase("ui.ragdollpuppeteer.chat.ratelimited"),
	language.GetPhrase("ui.ragdollpuppeteer.chat.invalidmodel"),
}

local function alwaysTrue(_)
	return true
end

---@param trio DNumSlider[]
---@return number[]
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
	local requireSameModel = GetConVar("ragdollpuppeteer_smhrequiresmodel"):GetBool()

	for _, entity in pairs(data.Entities) do
		if requireSameModel and entity.Properties.Model ~= model then
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
		local maxFrames = 0

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
		line:SetSortValue(5, entity.Properties.Model)
	end
end

---Find the longest animation of the sequence
---The longest animation is assumed to be the main animation for the sequence
---@param sequenceInfo SequenceInfo
---@param puppeteer Entity
---@return table|unknown longestAnim The longest animation of the puppeteer's sequence
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
	local done = false
	local co = coroutine.wrap(function()
		for i = 0, puppeteer:GetSequenceCount() - 1 do
			if not IsValid(puppeteer) then
				break
			end
			local seqInfo = puppeteer:GetSequenceInfo(i)
			if not seqInfo then
				break
			end

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

			if IsValid(seqList) then
				seqList:AddLine(i, seqInfo.label, fps, maxFrame)
			else
				break
			end

			coroutine.yield()
		end
		done = true
	end)

	local timerId = "ragdollpuppeteer_populatesequence_" .. seqList:GetName()
	timer.Remove(timerId)
	timer.Create(timerId, 0, -1, function()
		if done then
			timer.Stop(timerId)
		else
			co()
		end
	end)
end

---@param panelChildren PanelChildren
---@param puppeteer RagdollPuppeteer
function UI.Layout(panelChildren, puppeteer)
	local sequenceSheet = panelChildren.sequenceSheet
	local smhList = panelChildren.smhList
	local smhBrowser = panelChildren.smhBrowser

	sequenceSheet:Dock(TOP)
	smhList:Dock(TOP)
	smhBrowser:Dock(TOP)

	local sequenceSheetItems = sequenceSheet:GetItems()
	for i = 1, #sequenceSheetItems do
		local list = sequenceSheetItems[i]["Panel"]
		UI.PopulateSequenceList(list, puppeteer, alwaysTrue)
	end

	-- TODO: Rewrite UI for switching between animation lists.
	-- FIXME: List goes out of the CPanel
	sequenceSheet:SizeTo(-1, 500, 0.5)
	smhList:SizeTo(-1, 0, 0.5)
	smhBrowser:SizeTo(-1, 0, 0.5)
end

local baseFPS = 30

---@param baseSlider DNumSlider
---@param gestureSlider DNumSlider
---@param val number
---@param incrementGestures boolean
local function moveSliderBy(baseSlider, gestureSlider, val, incrementGestures)
	if not IsValid(baseSlider) then
		return
	end
	baseSlider:SetValue((baseSlider:GetValue() + val) % baseSlider:GetMax())
	if incrementGestures then
		gestureSlider:SetValue((gestureSlider:GetValue() + val) % gestureSlider:GetMax())
	end
end

---@param panelChildren PanelChildren
---@param panelProps PanelProps
---@param panelState PanelState
---@param currentGesture SequenceInfo
local function createPlaybackTimer(panelChildren, panelProps, panelState, currentGesture)
	local baseSlider = panelChildren.baseSlider
	local gestureSlider = panelChildren.gestureSlider
	local sourceBox = panelChildren.sourceBox
	local nonPhysCheckbox = panelChildren.nonPhysCheckBox
	local angOffset = panelChildren.angOffset
	local smhList = panelChildren.smhList

	local animPuppeteer = panelProps.puppeteer
	local basePuppeteer = panelProps.basePuppeteer
	local viewPuppeteer = panelProps.viewPuppeteer
	local baseGesturer = panelProps.baseGesturer
	local animGesturer = panelProps.gesturer
	local puppet = panelProps.puppet
	local physicsCount = panelProps.physicsCount

	local playbackEnabled = GetConVar("sv_ragdollpuppeteer_allow_playback")
		and GetConVar("sv_ragdollpuppeteer_allow_playback"):GetBool()
	if not playbackEnabled then
		chat.AddText("Ragdoll Puppeteer: " .. language.GetPhrase("ui.ragdollpuppeteer.chat.playbackdisabled1"))
		if game.SinglePlayer() then
			chat.AddText("Ragdoll Puppeteer: " .. language.GetPhrase("ui.ragdollpuppeteer.chat.playbackdisabled2"))
		end
		return
	end

	timer.Remove("ragdollpuppeteer_playback")
	timer.Create("ragdollpuppeteer_playback", 1 / baseFPS, -1, function()
		if not IsValid(animPuppeteer) or not IsValid(puppet) then
			return
		end

		local fps = GetConVar("ragdollpuppeteer_fps") and GetConVar("ragdollpuppeteer_fps"):GetInt() or baseFPS

		local shouldIncrement = GetConVar("ragdollpuppeteer_playback_shouldincrement")
			and GetConVar("ragdollpuppeteer_playback_shouldincrement"):GetInt() > 0
		local incrementGestures = GetConVar("ragdollpuppeteer_playback_incrementgestures")
			and GetConVar("ragdollpuppeteer_playback_incrementgestures"):GetInt() > 0
		if shouldIncrement then
			local increment = fps / baseFPS
			moveSliderBy(baseSlider, gestureSlider, increment, incrementGestures)
		else
			local _, option = sourceBox:GetSelected()
			if option == "sequence" then
				local numframes = baseSlider:GetMax()
				local val = baseSlider:GetValue()
				local cycle = val / numframes
				animPuppeteer:SetCycle(cycle)
				viewPuppeteer:SetCycle(cycle)

				net.Start("rp_onFrameChange", true)
				net.WriteBool(true)
				net.WriteFloat(cycle)
				net.WriteBool(nonPhysCheckbox:GetChecked())
				pose.writeSequence(
					{ animPuppeteer, basePuppeteer, viewPuppeteer },
					puppet,
					physicsCount,
					{ baseGesturer, animGesturer },
					currentGesture,
					panelState
				)
				net.SendToServer()
			else
				if smhList:GetSelected()[1] then
					pose.writeSMH(
						"rp_onFrameChange",
						baseSlider:GetValue(),
						smhList:GetSelected()[1]:GetSortValue(3),
						smhList:GetSelected()[1]:GetSortValue(4),
						nonPhysCheckbox:GetChecked(),
						animPuppeteer,
						puppet,
						smhList:GetSelected()[1]:GetSortValue(5),
						panelState
					)
				end
			end
		end
	end)

	net.Start("rp_onPuppeteerPlayback")
	net.WriteBool(true)
	net.SendToServer()
end

local function removePlaybackTimer()
	timer.Remove("ragdollpuppeteer_playback")
	net.Start("rp_onPuppeteerPlayback")
	net.WriteBool(false)
	net.SendToServer()
end

---@param puppeteer Entity
---@param sequenceIndex integer
local function setSequenceOf(puppeteer, sequenceIndex)
	puppeteer:ResetSequence(sequenceIndex)
	puppeteer:SetCycle(0)
	puppeteer:SetPlaybackRate(0)
end

---@param option string
---@param text string
---@param panelProps PanelProps
---@param panelChildren PanelChildren
---@param panelState PanelState
---@param modelChanged boolean
local function populateLists(option, text, panelChildren, panelProps, panelState, modelChanged)
	local animPuppeteer = panelProps.puppeteer
	local model = panelState.model
	local smhData = panelState.smhData
	local smhList = panelChildren.smhList
	local sequenceSheet = panelChildren.sequenceSheet

	if option == "sequence" then
		---@type DListView[]
		local lists = {}
		if modelChanged then
			for _, sheetInfo in ipairs(sequenceSheet:GetItems()) do
				table.insert(lists, sheetInfo.Panel)
			end
		else
			---@diagnostic disable-next-line
			table.insert(lists, sequenceSheet:GetActiveTab():GetPanel())
		end
		for _, list in ipairs(lists) do
			UI.ClearList(list)
			UI.PopulateSequenceList(list, animPuppeteer, function(seqInfo)
				---@cast seqInfo SequenceInfo

				if text:len() > 0 then
					local result = string.find(seqInfo.label:lower(), text:lower())
					return result ~= nil
				else
					return true
				end
			end)
		end
	else
		---@cast smhData SMHFile
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

---@param puppeteers Entity[]
local function changeModelOf(puppeteers, newModel)
	for i = 1, #puppeteers do
		puppeteers[i]:SetModel(newModel)
		setSequenceOf(puppeteers[i], 0)
	end
end

local boneTypes = {
	"icon16/brick.png",
	"icon16/connect.png",
	"icon16/error.png",
	"icon16/lock.png",
}

---@param parentNode DTree|BoneTreeNode
---@param childName string
---@param boneType integer
---@return BoneTreeNode
local function addBoneNode(parentNode, childName, boneType)
	local child = parentNode:AddNode(childName)
	---@cast child BoneTreeNode
	child.boneIcon = boneTypes[boneType]
	child:SetIcon(child.boneIcon)
	child:SetExpanded(true, false)
	return child
end

---@param entity Entity
---@param boneIndex integer
---@return integer
local function getBoneType(entity, boneIndex)
	local boneType = 2
	local isPhysicalBone = entity:TranslatePhysBoneToBone(entity:TranslateBoneToPhysBone(boneIndex)) == boneIndex

	if entity:BoneHasFlag(boneIndex, 4) then
		boneType = 3
	elseif isPhysicalBone then
		boneType = 1
	end

	return boneType
end

---@param poseParams PoseParameterSlider[]
---@param sequenceName string
local function setPoseParamsFromLocomotion(poseParams, sequenceName)
	for _, poseParam in ipairs(poseParams) do
		if not LOCOMOTION_POSEPARAMS[poseParam.name] then
			continue
		end

		local shouldSet = false
		for _, keyword in ipairs(LOCOMOTION) do
			if string.find(sequenceName, keyword) then
				shouldSet = true
				break
			end
		end

		if shouldSet then
			poseParam.slider:SetValue(poseParam.slider:GetMax())
		end
	end
end

---Add the bone nodes for the boneTree from the puppet
---@param puppet Entity
---@param boneTree DTree
local function setupBoneNodesOf(puppet, boneTree)
	---@type BoneTreeNode[]
	local parentSet = {}
	for b = 0, puppet:GetBoneCount() - 1 do
		if puppet:GetBoneName(b) == "__INVALIDBONE__" then
			continue
		end

		local boneType = getBoneType(puppet, b)

		local parent = puppet:GetBoneParent(b)
		if parent > -1 and parentSet[parent] then
			parentSet[b] = addBoneNode(parentSet[parent], puppet:GetBoneName(b), boneType)
			parentSet[b].boneId = b
		else
			parentSet[b] = addBoneNode(boneTree, puppet:GetBoneName(b), boneType)
			parentSet[b].boneId = b
		end
	end
end

---Construct the ragdoll puppeteer control panel and return its components
---@param cPanel DForm
---@param panelProps PanelProps
---@param panelState PanelState
---@return PanelChildren
function UI.ConstructPanel(cPanel, panelProps, panelState)
	local model = panelState.model
	local puppeteer = panelProps.puppeteer

	local puppetLabel = components.PuppetLabel(cPanel, model)
	local timelines = components.Timelines(cPanel)
	local baseSlider = components.FrameSlider(
		timelines,
		"ragdollpuppeteer_baseframe",
		language.GetPhrase("#ui.ragdollpuppeteer.label.base")
	)
	local gestureSlider = components.FrameSlider(
		timelines,
		"ragdollpuppeteer_gestureframe",
		language.GetPhrase("#ui.ragdollpuppeteer.label.gesture"),
		language.GetPhrase("#ui.ragdollpuppeteer.tooltip.gesture")
	)
	local playButton = components.PlayButton()
	local fpsWang = components.FPSWang()
	timelines:AddItem(playButton, fpsWang)
	playButton:Dock(LEFT)
	fpsWang:Dock(RIGHT)

	local offsets = components.Offsets(cPanel)
	local angOffset = components.AngleNumSliderTrio(
		offsets,
		{ "#ui.ragdollpuppeteer.label.pitch", "#ui.ragdollpuppeteer.label.yaw", "#ui.ragdollpuppeteer.label.roll" },
		"#ui.ragdollpuppeteer.label.angleoffset"
	)
	local heightOffset = components.HeightSlider(offsets)
	local scaleOffset = components.ScaleSlider(offsets)

	---@type DForm
	local poseParamsCategory = vgui.Create("DForm")
	poseParamsCategory:SetLabel("#ui.ragdollpuppeteer.label.poseparams")

	cPanel:AddItem(poseParamsCategory)
	local poseParams = components.PoseParameters(poseParamsCategory, puppeteer)
	local resetParams = components.ResetPoseParameters(poseParamsCategory, poseParams, puppeteer)

	local settings = components.Settings(cPanel)
	local settingsSheet = components.Sheet(settings)
	local generalContainer, tab = components.Container(settingsSheet, "#ui.ragdollpuppeteer.label.general")
	local nonPhysCheckbox = components.CheckBox(
		generalContainer,
		"#ui.ragdollpuppeteer.label.nonphys",
		"ragdollpuppeteer_animatenonphys",
		"#ui.ragdollpuppeteer.tooltip.nonphys"
	)
	local resetNonPhys = components.CheckBox(
		generalContainer,
		"#ui.ragdollpuppeteer.label.resetnonphys",
		"ragdollpuppeteer_resetnonphys",
		"#ui.ragdollpuppeteer.tooltip.resetnonphys"
	)
	local showPuppeteer = components.CheckBox(
		generalContainer,
		"#ui.ragdollpuppeteer.label.showpuppeteer",
		"ragdollpuppeteer_showpuppeteer",
		"#ui.ragdollpuppeteer.tooltip.showpuppeteer"
	)
	local floorCollisions = components.CheckBox(
		generalContainer,
		"#ui.ragdollpuppeteer.label.floorworld",
		"ragdollpuppeteer_floor_worldcollisions",
		"#ui.ragdollpuppeteer.tooltip.showpuppeteer"
	)
	local shouldIncrement = components.CheckBox(
		generalContainer,
		"#ui.ragdollpuppeteer.label.shouldincrement",
		"ragdollpuppeteer_playback_shouldincrement",
		"#ui.ragdollpuppeteer.tooltip.shouldincrement"
	)
	local incrementGestures = components.CheckBox(
		generalContainer,
		"#ui.ragdollpuppeteer.label.incrementgestures",
		"ragdollpuppeteer_playback_incrementgestures",
		"#ui.ragdollpuppeteer.tooltip.incrementgestures"
	)
	local attachToGround = components.CheckBox(
		generalContainer,
		"#ui.ragdollpuppeteer.label.attachtoground",
		"ragdollpuppeteer_attachtoground",
		"#ui.ragdollpuppeteer.tooltip.attachtoground"
	)
	local anySurface = components.CheckBox(
		generalContainer,
		"#ui.ragdollpuppeteer.label.anysurface",
		"ragdollpuppeteer_anysurface",
		"#ui.ragdollpuppeteer.tooltip.anysurface"
	)
	local faceMe = components.CheckBox(
		generalContainer,
		"#ui.ragdollpuppeteer.label.faceme",
		"ragdollpuppeteer_faceme",
		"#ui.ragdollpuppeteer.tooltip.faceme"
	)
	local poseLocomotion = components.CheckBox(
		generalContainer,
		"#ui.ragdollpuppeteer.label.poselocomotion",
		"ragdollpuppeteer_autopose_locomotion",
		"#ui.ragdollpuppeteer.tooltip.poselocomotion"
	)
	local recoverPuppeteer = components.RecoverPuppeteer(generalContainer)

	local smhContainer, tab2 = components.Container(settingsSheet, "#ui.ragdollpuppeteer.label.smh")
	local disableTween = components.CheckBox(
		smhContainer,
		"#ui.ragdollpuppeteer.label.disabletween",
		"ragdollpuppeteer_disabletween",
		"#ui.ragdollpuppeteer.tooltip.disabletween"
	)
	local requireSMHModel = components.CheckBox(
		smhContainer,
		"#ui.ragdollpuppeteer.label.smhrequiresmodel",
		"ragdollpuppeteer_smhrequiresmodel",
		"#ui.ragdollpuppeteer.tooltip.smhrequiresmodel"
	)

	local puppeteerContainer, puppeteerTab = components.Container(settingsSheet, "#ui.ragdollpuppeteer.label.puppeteer")
	local puppeteerColor = components.PuppeteerColors(puppeteerContainer)
	local puppeteerIgnoreZ = components.CheckBox(
		puppeteerContainer,
		"#ui.ragdollpuppeteer.label.ignorez",
		"ragdollpuppeteer_ignorez",
		"#ui.ragdollpuppeteer.tooltip.ignorez"
	)

	-- Hack: Switch the active tab to set the size based on the contents of the puppeteer tab
	settingsSheet:SetActiveTab(puppeteerTab.Tab)
	settingsSheet:NoClipping(true)
	settingsSheet:InvalidateChildren(true)
	generalContainer:InvalidateChildren(true)
	puppeteerContainer:InvalidateChildren(true)
	puppeteerContainer:SizeToChildren(false, true)
	generalContainer:SizeToChildren(false, true)
	settingsSheet:SizeToChildren(false, true)
	settingsSheet:SetActiveTab(tab.Tab)

	local boneTree = components.BoneTree(cPanel)

	local lists = components.Lists(cPanel)

	local modelPath =
		components.SearchBar(lists, "#ui.ragdollpuppeteer.label.modelpath", "#ui.ragdollpuppeteer.tooltip.modelpath")
	modelPath:SetHistoryEnabled(true)
	local sourceBox = components.AnimationSourceBox(lists)
	local searchBar = components.SearchBar(lists)
	local removeGesture = components.RemoveGesture(lists)
	local randomPose = components.RandomPose(lists)
	local sequenceSheet = components.Sheet(lists)
	local sequenceList = components.SequenceList(sequenceSheet, "#ui.ragdollpuppeteer.label.base")
	sequenceList:SetName("base")
	local sequenceList2 = components.SequenceList(sequenceSheet, "#ui.ragdollpuppeteer.label.gesture")
	sequenceList:SetName("gesture")
	local smhBrowser = components.SMHFileBrowser(lists)
	local smhList = components.SMHEntityList(lists)

	gestureSlider:SetEnabled(game.SinglePlayer())
	removeGesture:SetEnabled(game.SinglePlayer())
	if not game.SinglePlayer() then
		sequenceSheet:CloseTab(sequenceSheet:GetItems()[2].Tab, false)
	end

	return {
		angOffset = angOffset,
		puppetLabel = puppetLabel,
		baseSlider = baseSlider,
		gestureSlider = gestureSlider,
		nonPhysCheckBox = nonPhysCheckbox,
		poseLocomotion = poseLocomotion,
		sourceBox = sourceBox,
		searchBar = searchBar,
		sequenceList = sequenceList,
		sequenceList2 = sequenceList2,
		sequenceSheet = sequenceSheet,
		smhBrowser = smhBrowser,
		smhList = smhList,
		poseParams = poseParams,
		resetParams = resetParams,
		poseParamsCategory = poseParamsCategory,
		boneTree = boneTree,
		showPuppeteer = showPuppeteer,
		removeGesture = removeGesture,
		floorCollisions = floorCollisions,
		recoverPuppeteer = recoverPuppeteer,
		shouldIncrement = shouldIncrement,
		playButton = playButton,
		fpsWang = fpsWang,
		resetNonPhys = resetNonPhys,
		heightOffset = heightOffset,
		puppeteerColor = puppeteerColor,
		puppeteerIgnoreZ = puppeteerIgnoreZ,
		attachToGround = attachToGround,
		anySurface = anySurface,
		incrementGestures = incrementGestures,
		modelPath = modelPath,
		faceMe = faceMe,
		disableTween = disableTween,
		randomPose = randomPose,
		scaleOffset = scaleOffset,
		requireSMHModel = requireSMHModel,
	}
end

---@param panelChildren PanelChildren
---@param panelProps PanelProps
---@param panelState PanelState
---@param poseOffsetter ragdollpuppeteer_poseoffsetter
function UI.HookPanel(panelChildren, panelProps, panelState, poseOffsetter)
	local currentSequence = {
		label = "",
		numframes = 1,
		anims = {},
	}

	local currentGesture = {
		label = "",
		numframes = 1,
		anims = {},
	}

	local smhList = panelChildren.smhList
	local sequenceList = panelChildren.sequenceList
	local sequenceList2 = panelChildren.sequenceList2
	local sequenceSheet = panelChildren.sequenceSheet
	local smhBrowser = panelChildren.smhBrowser
	local baseSlider = panelChildren.baseSlider
	local gestureSlider = panelChildren.gestureSlider
	local sourceBox = panelChildren.sourceBox
	local nonPhysCheckbox = panelChildren.nonPhysCheckBox
	local searchBar = panelChildren.searchBar
	local poseParams = panelChildren.poseParams
	local resetParams = panelChildren.resetParams
	local poseParamsCategory = panelChildren.poseParamsCategory
	local boneTree = panelChildren.boneTree
	local showPuppeteer = panelChildren.showPuppeteer
	local removeGesture = panelChildren.removeGesture
	local angOffset = panelChildren.angOffset
	local playButton = panelChildren.playButton
	local heightOffset = panelChildren.heightOffset
	local puppeteerColor = panelChildren.puppeteerColor
	local puppeteerIgnoreZ = panelChildren.puppeteerIgnoreZ
	local attachToGround = panelChildren.attachToGround
	local anySurface = panelChildren.anySurface
	local modelPath = panelChildren.modelPath
	local disableTween = panelChildren.disableTween
	local faceMe = panelChildren.faceMe
	local randomPose = panelChildren.randomPose
	local scaleOffset = panelChildren.scaleOffset
	local disableSMHModelCheck = panelChildren.disableSMHModelCheck
	local poseLocomotion = panelChildren.poseLocomotion

	local animPuppeteer = panelProps.puppeteer
	local animGesturer = panelProps.gesturer
	local basePuppeteer = panelProps.basePuppeteer
	local baseGesturer = panelProps.baseGesturer
	local puppet = panelProps.puppet
	local model = panelState.model
	local physicsCount = panelProps.physicsCount
	local floor = panelProps.floor
	local viewPuppeteer = panelProps.viewPuppeteer

	local smhData = panelState.smhData

	modelPath:AddHistory(model)

	-- Set min and max of height slider for Resized Ragdolls
	---@diagnostic disable-next-line
	if puppet.SavedBoneMatrices then
		---@diagnostic disable-next-line
		local scale = math.max(puppet.SavedBoneMatrices[0]:GetScale():Unpack())
		heightOffset:SetMin(-scale * 100)
		heightOffset:SetMax(scale * 100)
	end

	setupBoneNodesOf(puppet, boneTree)

	local filteredBones = {}
	for b = 1, puppet:GetBoneCount() do
		filteredBones[b] = false
	end

	local convarChanging = false
	local colorConVar = GetConVar("ragdollpuppeteer_color")
	local alphaConVar = GetConVar("ragdollpuppeteer_alpha")

	-- If I add a remove change callback in the hook, nothing will go wrong.
	cvars.RemoveChangeCallback("ragdollpuppeteer_color", "ragdollpuppeteer_colorChanged")
	cvars.AddChangeCallback("ragdollpuppeteer_color", function(cvar, oldVal, newVal)
		convarChanging = true
		puppeteerColor:SetColor(helpers.getColorFromString(newVal) or COLOR_BLUE)
		convarChanging = false
	end, "ragdollpuppeteer_colorChanged")

	---@param newVal boolean
	function attachToGround:OnChange(newVal)
		anySurface:SetEnabled(newVal)
	end

	---@param color Color
	function puppeteerColor:OnValueChanged(color)
		viewPuppeteer:SetColor4Part(color.r, color.g, color.b, alphaConVar and alphaConVar:GetInt() or 100)
		if convarChanging then
			return
		end
		colorConVar = colorConVar or GetConVar("ragdollpuppeteer_color")
		if colorConVar then
			colorConVar:SetString(helpers.getStringFromColor(color))
		end
	end
	puppeteerColor:SetColor(colorConVar and helpers.getColorFromString(colorConVar:GetString()) or COLOR_BLUE)

	function heightOffset:OnValueChanged(newValue)
		---@diagnostic disable-next-line
		floor:SetHeight(newValue)
	end

	function playButton:OnToggled(on)
		if on then
			createPlaybackTimer(panelChildren, panelProps, panelState, currentGesture)
			playButton:SetText("#ui.ragdollpuppeteer.label.stop")
		else
			removePlaybackTimer()
			playButton:SetText("#ui.ragdollpuppeteer.label.play")
		end
	end

	---@param node BoneTreeNode
	function boneTree:DoClick(node)
		node.locked = not node.locked
		node:SetIcon(node.locked and boneTypes[#boneTypes] or node.boneIcon)
		filteredBones[node.boneId + 1] = node.locked
		net.Start("rp_onBoneFilterChange")
		net.WriteTable(filteredBones, true)
		net.SendToServer()
	end

	local function onAngleTrioValueChange()
		local angleTrio = getAngleTrio(angOffset)
		local angleOffset = Angle(angleTrio[1], angleTrio[2], angleTrio[3])
		floor:SetAngleOffset(angleOffset)

		local _, option = sourceBox:GetSelected()
		if option == "sequence" then
			local numframes = baseSlider:GetMax()
			local val = baseSlider:GetValue()
			local cycle = val / numframes
			animPuppeteer:SetCycle(cycle)
			viewPuppeteer:SetCycle(cycle)

			net.Start("rp_onFrameChange", true)
			net.WriteBool(true)
			net.WriteFloat(cycle)
			net.WriteBool(nonPhysCheckbox:GetChecked())
			pose.writeSequence(
				{ animPuppeteer, basePuppeteer, viewPuppeteer },
				puppet,
				physicsCount,
				{ baseGesturer, animGesturer },
				currentGesture,
				panelState
			)
			net.SendToServer()
		else
			if smhList:GetSelected()[1] then
				pose.writeSMH(
					"rp_onFrameChange",
					baseSlider:GetValue(),
					smhList:GetSelected()[1]:GetSortValue(3),
					smhList:GetSelected()[1]:GetSortValue(4),
					nonPhysCheckbox:GetChecked(),
					animPuppeteer,
					puppet,
					smhList:GetSelected()[1]:GetSortValue(5)
				)
			end
		end
	end

	---@param entity Entity
	local function setPoseOffsetterEntity(entity)
		-- We set this on the next frame because if we do it on the same frame, the bones may have not initialized yet,
		-- resulting in __INVALIDBONE__'s
		timer.Simple(0.1, function()
			poseOffsetter:SetEntity(entity)
		end)
	end

	setPoseOffsetterEntity(animPuppeteer)

	panelState.selectedBone = -1
	panelState.offsets = {}
	function poseOffsetter:OnBoneSelect(bone)
		panelState.puppet = panelProps.viewPuppeteer
		panelState.selectedBone = bone

		self:SetTransform(panelState.offsets[bone])
	end

	function poseOffsetter:OnTransformChange(bone, pos, ang)
		panelState.offsets[bone] = {
			pos = pos,
			ang = ang,
		}
		onAngleTrioValueChange()
	end

	function poseOffsetter:OnSavePreset()
		return {
			model = panelState.puppet:GetModel(),
			offsets = panelState.offsets,
		}
	end

	function poseOffsetter:OnSaveSuccess()
		notification.AddLegacy("Offsets saved", NOTIFY_GENERIC, 5)
	end

	function poseOffsetter:OnSaveFailure(msg)
		notification.AddLegacy("Failed to save offsets: " .. msg, NOTIFY_ERROR, 5)
	end

	function scaleOffset:OnValueChanged(newVal)
		-- FIXME: We probably don't want to cache multiple versions of the same model
		vendor.getDefaultBonePoseOf(animPuppeteer, animPuppeteer:GetModel() .. "_scale_" .. newVal)

		floor:SetPuppeteerScale(newVal)
	end

	angOffset[1].OnValueChanged = onAngleTrioValueChange
	angOffset[2].OnValueChanged = onAngleTrioValueChange
	angOffset[3].OnValueChanged = onAngleTrioValueChange

	---@param newValue number
	---@param paramName string
	---@param slider DNumSlider
	local function rp_onPoseParamChange(newValue, paramName, slider)
		local _, option = sourceBox:GetSelected()

		-- Set the pose parameter in the floor. The floor will automatically set the pose parameters through there
		floor["Set" .. paramName](floor, newValue)

		-- If the user has stopped dragging on the sequence, send the update
		timer.Simple(SEQUENCE_CHANGE_DELAY, function()
			if option == "sequence" and not slider:IsEditing() then
				net.Start("rp_onPoseParamChange", true)
				net.WriteBool(nonPhysCheckbox:GetChecked())
				net.WriteFloat(newValue)
				net.WriteString(paramName)
				pose.writeSequence(
					{ animPuppeteer, basePuppeteer, viewPuppeteer },
					puppet,
					physicsCount,
					{ baseGesturer, animGesturer },
					currentGesture,
					panelState
				)
				net.SendToServer()
			end
		end)
	end

	local function hookPoseParams()
		for i = 1, #poseParams do
			poseParams[i].slider.OnValueChanged = function(_, newValue)
				rp_onPoseParamChange(newValue, poseParams[i].name, poseParams[i].slider)
			end
		end
	end

	hookPoseParams()

	-- We want to save the original model path: if an invalid one was entered in,
	-- we can revert to the old one
	local currentModel = animPuppeteer:GetModel()
	modelPath:SetValue(currentModel)
	modelPath.currentModel = currentModel

	function modelPath:OnEnter(text)
		net.Start("rp_onPuppeteerChangeRequest", true)
		net.WriteString(text)
		net.SendToServer()
	end

	function searchBar:OnEnter(searchText)
		local _, option = sourceBox:GetSelected()
		---@cast searchText string
		populateLists(option, searchText, panelChildren, panelProps, panelState, false)
	end

	local function rowSelected(row, slider, puppeteer, mutatedSequence, sendNet, isGesture)
		local currentIndex = row:GetValue(1)
		---@type SequenceInfo
		local seqInfo = puppeteer:GetSequenceInfo(currentIndex)
		if mutatedSequence.label ~= seqInfo.label then
			mutatedSequence = seqInfo
			setSequenceOf(puppeteer, currentIndex)
			if isGesture then
				setSequenceOf(baseGesturer, currentIndex)
			else
				setSequenceOf(basePuppeteer, currentIndex)
				setSequenceOf(viewPuppeteer, currentIndex)
				baseFPS = row:GetValue(3)
				panelState.maxFrames = row:GetValue(4) - 1
			end

			slider:SetMax(row:GetValue(4) - 1)
		end

		if sendNet then
			timer.Simple(SEQUENCE_CHANGE_DELAY, function()
				net.Start("rp_onSequenceChange")
				net.WriteBool(true)
				net.WriteInt(currentIndex, 14)
				net.WriteBool(nonPhysCheckbox:GetChecked())
				pose.writeSequence(
					{ animPuppeteer, basePuppeteer, viewPuppeteer },
					puppet,
					physicsCount,
					{ baseGesturer, animGesturer },
					currentGesture,
					panelState
				)
				net.SendToServer()

				if poseLocomotion:GetChecked() then
					setPoseParamsFromLocomotion(poseParams, seqInfo.label)
				end
			end)
		end

		return mutatedSequence
	end

	function removeGesture:DoClick()
		local seqInfo = animGesturer:GetSequenceInfo(0)
		if currentGesture.label ~= seqInfo.label then
			currentGesture = seqInfo
			setSequenceOf(animGesturer, 0)
			setSequenceOf(baseGesturer, 0)

			gestureSlider:SetMax(60)
		end
	end

	function sequenceList:OnRowSelected(_, row)
		currentSequence = rowSelected(row, baseSlider, animPuppeteer, currentSequence, true, false)
	end

	function sequenceList2:OnRowSelected(_, row)
		currentGesture = rowSelected(row, gestureSlider, animGesturer, currentGesture, false, true)
	end

	function randomPose:DoClick()
		local sequences = sequenceList:GetLines()
		local nonGestures = {}
		for _, line in ipairs(sequences) do
			if line:GetValue(4) == 1 then
				continue
			end
			local filtered = false

			---@type string
			local name = line:GetValue(2):lower()
			for _, prefix in ipairs(PREFIXES) do
				if name:sub(1, 3):find(prefix, 1, true) then
					filtered = true
					break
				end
			end
			if filtered then
				continue
			end

			for _, suffix in ipairs(SUFFIXES) do
				if name:sub(-1, -3):find(suffix, 1, true) then
					filtered = true
					break
				end
			end
			if filtered then
				continue
			end

			for _, filter in ipairs(FILTER) do
				if name:find(filter) then
					filtered = true
					break
				end
			end
			if filtered then
				continue
			end

			table.insert(nonGestures, line)
		end

		local pose = nonGestures[math.random(#nonGestures)]
		local sequenceId = pose:GetValue(1)
		sequenceList:ClearSelection()
		sequenceList:SelectItem(pose)
		---@diagnostic disable-next-line
		local scrollBar = sequenceList.VBar
		---@cast scrollBar DVScrollBar
		scrollBar:AnimateTo(sequenceId * sequenceList:GetDataHeight(), 0.5)

		baseSlider:SetValue(math.random(baseSlider:GetMax()))
	end

	local sendingFrame = false
	local function sliderValueChanged(slider, val, sequence, puppeteer, smh, sendNet)
		local _, option = sourceBox:GetSelected()
		if option == "sequence" then
			if not sequence.anims then
				return
			end
			if not IsValid(puppeteer) then
				return
			end
			local numframes = slider:GetMax()
			slider:SetValue(val)
			local cycle = val / numframes
			puppeteer:SetCycle(cycle)

			if sendNet then
				if sendingFrame then
					return
				end

				sendingFrame = true
				net.Start("rp_onFrameChange", true)
				net.WriteBool(true)
				net.WriteFloat(cycle)
				net.WriteBool(nonPhysCheckbox:GetChecked())
				pose.writeSequence(
					{ animPuppeteer, basePuppeteer, viewPuppeteer },
					puppet,
					physicsCount,
					{ baseGesturer, animGesturer },
					currentGesture,
					panelState
				)
				net.SendToServer()
				sendingFrame = false
			end
		else
			if sendNet then
				if smh and smhList:GetSelected()[1] then
					pose.writeSMH(
						"rp_onFrameChange",
						val,
						smhList:GetSelected()[1]:GetSortValue(3),
						smhList:GetSelected()[1]:GetSortValue(4),
						nonPhysCheckbox:GetChecked(),
						animPuppeteer,
						puppet,
						smhList:GetSelected()[1]:GetSortValue(5)
					)
				end
			end
		end
		slider.prevFrame = val
	end

	function baseSlider:OnValueChanged(val)
		local prevFrame = self.prevFrame
		if math.abs(prevFrame - val) < 1 / baseFPS then
			return
		end
		sliderValueChanged(self, val, currentSequence, animPuppeteer, true, true)
		sliderValueChanged(self, val, currentSequence, viewPuppeteer, true, false)
	end

	function gestureSlider:OnValueChanged(val)
		local prevFrame = self.prevFrame
		if math.abs(prevFrame - val) < 1 / baseFPS then
			return
		end
		sliderValueChanged(self, val, currentGesture, animGesturer, false, true)
	end

	function sourceBox:OnSelect(_, _, option)
		if option == "sequence" then
			gestureSlider:SetEnabled(game.SinglePlayer())
			removeGesture:SetEnabled(game.SinglePlayer())
			randomPose:SetEnabled(true)
			smhList:SizeTo(-1, 0, 0.5)
			smhBrowser:SizeTo(-1, 0, 0.5)
			sequenceSheet:SizeTo(-1, 500, 0.5)
		else
			gestureSlider:SetEnabled(false)
			removeGesture:SetEnabled(false)
			randomPose:SetEnabled(false)
			sequenceSheet:SizeTo(-1, 0, 0.5)
			smhList:SizeTo(-1, 250, 0.5)
			smhBrowser:SizeTo(-1, 250, 0.5)
		end
	end

	function smhList:OnRowSelected(_, row)
		baseSlider:SetMax(row:GetValue(2))
		panelState.maxFrames = row:GetValue(2)
		pose.writeSMH(
			"rp_onSequenceChange",
			0,
			smhList:GetSelected()[1]:GetSortValue(3),
			smhList:GetSelected()[1]:GetSortValue(4),
			nonPhysCheckbox:GetChecked(),
			animPuppeteer,
			puppet,
			smhList:GetSelected()[1]:GetSortValue(5)
		)
	end

	function smhBrowser:OnSelect(filePath)
		UI.ClearList(smhList)
		smhData = smh.parseSMHFile(filePath, model)
		populateSMHEntitiesList(smhList, model, smhData, alwaysTrue)
	end

	-- Network hooks from server
	net.Receive("rp_onFramePrevious", function()
		local increment = net.ReadFloat()
		moveSliderBy(baseSlider, gestureSlider, -increment, panelChildren.incrementGestures:GetChecked())
	end)
	net.Receive("rp_onFrameNext", function()
		local increment = net.ReadFloat()
		moveSliderBy(baseSlider, gestureSlider, increment, panelChildren.incrementGestures:GetChecked())
	end)
	net.Receive("rp_onPuppeteerChangeRequest", function()
		local result = net.ReadBool()
		local errorInt = net.ReadUInt(3)

		-- If we can change the model
		if result then
			-- Get the valid model from the model path text entry
			local newModel = modelPath:GetValue()
			modelPath.currentModel = newModel

			-- Change the serverside puppeteer model
			net.Start("rp_onPuppeteerChange")
			net.WriteString(modelPath.currentModel)
			net.SendToServer()
			UI.ClearList(sequenceList)
			UI.ClearList(smhList)

			-- Update the puppeteers' models and use the new model sequences
			local _, option = sourceBox:GetSelected()
			changeModelOf({
				animPuppeteer,
				basePuppeteer,
				animGesturer,
				baseGesturer,
				viewPuppeteer,
			}, newModel)
			setPoseOffsetterEntity(animPuppeteer)

			for i = 1, #poseParams do
				poseParams[i].slider:Remove()
			end
			resetParams:Remove()
			poseParams = components.PoseParameters(poseParamsCategory, animPuppeteer)
			resetParams = components.ResetPoseParameters(poseParamsCategory, poseParams, animPuppeteer)
			hookPoseParams()
			-- FIXME: InstallDataTable seems like an unintuitive way of resetting the network vars. What better method exists?
			floor:InstallDataTable()
			---@diagnostic disable-next-line: undefined-field
			floor:SetupDataTables()

			populateLists(option, "", panelChildren, panelProps, panelState, true)
			panelState.model = newModel
			panelState.boneMap = nil
			panelState.inverseBoneMap = nil

			modelPath:AddHistory(newModel)
		else
			-- Save the original model path to the history so users can iterate on this
			modelPath:AddHistory(modelPath:GetValue())
			-- Reset the model path
			modelPath:SetText(modelPath.currentModel)
			-- Notify the user what happened and changed clipboard state
			chat.AddText("Ragdoll Puppeteer: " .. requestMessages[errorInt])
			chat.AddText("Ragdoll Puppeteer: " .. language.GetPhrase("ui.ragdollpuppeteer.chat.history"))
		end
	end)
	net.Receive("rp_enablePuppeteerPlayback", function(len, ply)
		createPlaybackTimer(panelChildren, panelProps, panelState, currentGesture)
	end)

	net.Receive("rp_disablePuppeteerPlayback", removePlaybackTimer)
	net.Receive("rp_onSequenceChange", function()
		-- Handle pasting of NPC sequences onto the puppet
		local sequence = net.ReadString()
		local cycle = net.ReadFloat()
		local poseParamValues = {}
		for i = 1, panelProps.puppeteer:GetNumPoseParameters() do
			local val = net.ReadFloat()
			if val then
				poseParamValues[i] = val
			end
		end

		local sequenceId = panelProps.puppeteer:LookupSequence(sequence)
		if sequenceId > 0 then
			setSequenceOf(viewPuppeteer, sequenceId)
			setSequenceOf(animPuppeteer, sequenceId)
			setSequenceOf(basePuppeteer, sequenceId)

			---@diagnostic disable-next-line
			local scrollBar = sequenceList.VBar
			local row = sequenceList:GetLine(sequenceId + 1)
			---@cast row DListView_Line
			sequenceList:SelectItem(row)
			-- Move the scrollbar to the location of the highlighted sequence item in the sequence list
			scrollBar:AnimateTo(sequenceId * sequenceList:GetDataHeight(), 0.5)
			-- Send all frame and pose parameter updates to the server
			baseSlider:SetValue(cycle * (row:GetValue(4) - 1))
			for i, poseParamValue in ipairs(poseParamValues) do
				poseParams[i].slider:SetValue(poseParamValue)
			end
		else
			notification.AddLegacy(
				language.GetPhrase("ui.ragdollpuppeteer.notify.pastefailed"):format(sequence),
				NOTIFY_ERROR,
				5
			)
		end
	end)
end

return UI
