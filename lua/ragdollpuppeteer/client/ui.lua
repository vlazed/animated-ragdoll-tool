---@module "ragdollpuppeteer.lib.smh"
local smh = include("ragdollpuppeteer/lib/smh.lua")
---@module "ragdollpuppeteer.constants"
local constants = include("ragdollpuppeteer/constants.lua")
---@module "ragdollpuppeteer.client.components"
local components = include("components.lua")
---@module "ragdollpuppeteer.lib.vendor"
local vendor = include("ragdollpuppeteer/lib/vendor.lua")
---@module "ragdollpuppeteer.lib.quaternion"
local quaternion = include("ragdollpuppeteer/lib/quaternion.lua")
---@module "ragdollpuppeteer.lib.helpers"
local helpers = include("ragdollpuppeteer/lib/helpers.lua")

local COLOR_BLUE = constants.COLOR_BLUE

local DEFAULT_MAX_FRAME = constants.DEFAULT_MAX_FRAME
local SEQUENCE_CHANGE_DELAY = 0.2

local UI = {}

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

local function compressTableToJSON(tab)
	return util.Compress(util.TableToJSON(tab))
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
		UI.PopulateSequenceList(list, puppeteer, function(_)
			return true
		end)
	end

	-- TODO: Rewrite UI for switching between animation lists.
	-- FIXME: List goes out of the CPanel
	sequenceSheet:SizeTo(-1, 500, 0.5)
	smhList:SizeTo(-1, 0, 0.5)
	smhBrowser:SizeTo(-1, 0, 0.5)
end

---@param pose SMHFramePose[]
---@param puppeteer RagdollPuppeteer
local function encodePose(pose, puppeteer)
	local b = puppeteer:TranslatePhysBoneToBone(0)
	local matrix = puppeteer:GetBoneMatrix(b)
	local bPos, bAng = matrix:GetTranslation(), matrix:GetAngles()

	net.WriteUInt(#pose, 16)
	for i = 0, #pose do
		net.WriteVector(pose[i].Pos or vector_origin)
		net.WriteAngle(pose[i].Ang or angle_zero)
		net.WriteVector(pose[i].Scale or Vector(-1, -1, -1))
		net.WriteVector(pose[i].LocalPos or Vector(-16384, -16384, -16384))
		net.WriteAngle(pose[i].LocalAng or Angle(0, 0, 0))
		net.WriteVector(bPos)
		net.WriteAngle(bAng)
	end
end

local lastPose = {}
local lastGesturePose = {}

---Send the client's sequence bone positions, first mutating the puppeteer with the gesturer
---https://github.com/penolakushari/StandingPoseTool/blob/b7dc7b3b57d2d940bb6a4385d01a4b003c97592c/lua/autorun/standpose.lua#L42
---@param puppeteers Entity[]
---@param puppet Entity | ResizedRagdoll
---@param physicsCount integer
---@param gesturers Entity[]
---@param defaultBonePose DefaultBonePose
local function writeSequencePose(puppeteers, puppet, physicsCount, gesturers, defaultBonePose)
	if not IsValid(puppeteers[1]) or not IsValid(puppet) then
		return
	end

	if game.SinglePlayer() then
		local baseGesturer = gesturers[1]
		local animGesturer = gesturers[2]
		local animPuppeteer = puppeteers[1]
		local basePuppeteer = puppeteers[2]
		local viewPuppeteer = puppeteers[3]
		local newPose = {}
		for i = 0, physicsCount - 1 do
			local b = puppet:TranslatePhysBoneToBone(i)

			if defaultBonePose and currentGesture.anims then
				local gesturePos, gestureAng
				if puppeteers[1]:GetBoneParent(b) > -1 then
					local gPos, gAng = vendor.getBoneOffsetsOf(animGesturer, b, defaultBonePose)
					local oPos, oAng = vendor.getBoneOffsetsOf(baseGesturer, b, defaultBonePose)

					local oQuat = quaternion()
					local gQuat = quaternion()
					oQuat:SetAngle(oAng)
					gQuat:SetAngle(gAng)
					local dQuat = gQuat * oQuat:Invert()

					local dPos = gPos - oPos
					local dAng = dQuat:Angle()
					gesturePos, gestureAng = dPos, dAng
				else
					local gPos, gAng = animGesturer:GetBonePosition(b)
					local oPos, oAng = baseGesturer:GetBonePosition(b)
					if gPos and gAng and oPos and oAng then
						local _, dAng = WorldToLocal(gPos, gAng, oPos, oAng)
						local dPos = gPos - oPos
						dPos, _ = LocalToWorld(dPos, angle_zero, vector_origin, puppeteers[1]:GetAngles())

						gesturePos, gestureAng = dPos, dAng
					elseif lastGesturePose[b] then
						gesturePos, gestureAng = lastGesturePose[b][1], lastGesturePose[b][2]
					end
				end

				if gesturePos then
					animPuppeteer:ManipulateBonePosition(b, gesturePos)
					basePuppeteer:ManipulateBonePosition(b, gesturePos)
					viewPuppeteer:ManipulateBonePosition(b, gesturePos)
				end
				if gestureAng then
					animPuppeteer:ManipulateBoneAngles(b, gestureAng)
					basePuppeteer:ManipulateBoneAngles(b, gestureAng)
					viewPuppeteer:ManipulateBonePosition(b, gesturePos)
				end
				lastGesturePose[b] = { gesturePos, gestureAng }
			end

			local pos, ang = puppeteers[1]:GetBonePosition(b)
			if puppet:GetClass() == "prop_physics" then
				pos, ang = puppeteers[1]:GetPos(), puppeteers[1]:GetAngles()
			end

			if not pos and lastPose[i] then
				pos = lastPose[i][1]
			end

			if not ang and lastPose[i] then
				ang = lastPose[i][2]
			end

			if pos == animPuppeteer:GetPos() then
				local matrix = animPuppeteer:GetBoneMatrix(b)
				if matrix then
					pos = matrix:GetTranslation()
					ang = matrix:GetAngles()
				end
			end

			if i == 0 then
				local baseMatrix = basePuppeteer:GetBoneMatrix(b)
				local animMatrix = animPuppeteer:GetBoneMatrix(b)
				if baseMatrix and animMatrix and puppet.SavedBoneMatrices and puppet.SavedBoneMatrices[b] then
					local scale = puppet.SavedBoneMatrices[b]:GetScale()
					local offsetPos = (animMatrix:GetTranslation() - baseMatrix:GetTranslation()) * scale
					pos = baseMatrix:GetTranslation() + offsetPos
				end
			end

			-- Save the current bone pose, so later iterations can use it if the bone matrix doesn't exist for some reason
			newPose[i] = { pos, ang }

			net.WriteVector(pos)
			net.WriteAngle(ang)
		end

		lastPose = newPose
	end
end

---@param netString string
---@param frame integer
---@param physFrames SMHFrameData[]
---@param nonPhysFrames SMHFrameData[]
---@param nonPhys boolean
local function writeSMHPose(netString, frame, physFrames, nonPhysFrames, nonPhys, puppeteer)
	local physBonePose = smh.getPoseFromSMHFrames(frame, physFrames, "physbones")
	net.Start(netString, true)
	net.WriteBool(false)
	encodePose(physBonePose, puppeteer)
	net.WriteBool(nonPhys)
	if nonPhys then
		local nonPhysBoneData = smh.getPoseFromSMHFrames(frame, nonPhysFrames, "bones")
		local compressedNonPhysPose = compressTableToJSON(nonPhysBoneData)
		net.WriteUInt(#compressedNonPhysPose, 16)
		net.WriteData(compressedNonPhysPose)
	end

	net.SendToServer()
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
local function createPlaybackTimer(panelChildren, panelProps, panelState)
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

				net.Start("onFrameChange", true)
				net.WriteBool(true)
				net.WriteFloat(cycle)
				net.WriteBool(nonPhysCheckbox:GetChecked())
				writeSequencePose(
					{ animPuppeteer, basePuppeteer, viewPuppeteer },
					puppet,
					physicsCount,
					{ baseGesturer, animGesturer },
					panelState.defaultBonePose
				)
				net.SendToServer()
			else
				if smhList:GetSelected()[1] then
					writeSMHPose(
						"onFrameChange",
						baseSlider:GetValue(),
						smhList:GetSelected()[1]:GetSortValue(3),
						smhList:GetSelected()[1]:GetSortValue(4),
						nonPhysCheckbox:GetChecked(),
						animPuppeteer
					)
				end
			end
		end
	end)
end

local function removePlaybackTimer()
	timer.Remove("ragdollpuppeteer_playback")
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
function UI.NetHookPanel(panelChildren, panelProps, panelState)
	local baseSlider = panelChildren.baseSlider
	local gestureSlider = panelChildren.gestureSlider

	-- Network hooks from server
	net.Receive("onFramePrevious", function()
		local increment = net.ReadFloat()
		moveSliderBy(baseSlider, gestureSlider, -increment, panelChildren.incrementGestures:GetChecked())
	end)
	net.Receive("onFrameNext", function()
		local increment = net.ReadFloat()
		moveSliderBy(baseSlider, gestureSlider, increment, panelChildren.incrementGestures:GetChecked())
	end)
	net.Receive("enablePuppeteerPlayback", function(len, ply)
		createPlaybackTimer(panelChildren, panelProps, panelState)
	end)
	net.Receive("disablePuppeteerPlayback", removePlaybackTimer)
	net.Receive("onSequenceChange", function()
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
			setSequenceOf(panelProps.viewPuppeteer, sequenceId)
			setSequenceOf(panelProps.puppeteer, sequenceId)
			setSequenceOf(panelProps.basePuppeteer, sequenceId)

			local poseParams = panelChildren.poseParams
			local sequenceList = panelChildren.sequenceList
			---@diagnostic disable-next-line
			local scrollBar = sequenceList.VBar
			---@cast scrollBar DVScrollBar
			local baseSlider = panelChildren.baseSlider
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

local boneIcons = {
	"icon16/brick.png",
	"icon16/connect.png",
	"icon16/lock.png",
}

-- FIXME: Obtain the nonphysical bones

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

---Construct the ragdoll puppeteer control panel and return its components
---@param cPanel DForm
---@param panelProps PanelProps
---@return PanelChildren
function UI.ConstructPanel(cPanel, panelProps)
	local model = panelProps.model
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

	local poseParams = components.PoseParameters(cPanel, puppeteer)

	local settings = components.Settings(cPanel)
	local settingsSheet = components.Sheet(settings)
	local generalContainer, tab = components.Container(settingsSheet, "#ui.ragdollpuppeteer.label.general")
	local nonPhysCheckbox = components.CheckBox(
		generalContainer,
		"#ui.ragdollpuppeteer.label.nonphys",
		"ragdollpuppeteer_animatenonphys",
		"#ui.ragdollpuppeteer.tooltip.nonphys"
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
	local recoverPuppeteer = components.RecoverPuppeteer(generalContainer)

	local puppeteerContainer, tab2 = components.Container(settingsSheet, "#ui.ragdollpuppeteer.label.puppeteer")
	local puppeteerColor = components.PuppeteerColors(puppeteerContainer)
	local puppeteerIgnoreZ = components.CheckBox(
		puppeteerContainer,
		"#ui.ragdollpuppeteer.label.ignorez",
		"ragdollpuppeteer_ignorez",
		"#ui.ragdollpuppeteer.tooltip.ignorez"
	)

	-- Hack: Switch the active tab to set the size based on the contents of the puppeteer tab
	settingsSheet:SetActiveTab(tab2.Tab)
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

	local sourceBox = components.AnimationSourceBox(lists)
	local searchBar = components.SearchBar(lists)
	local removeGesture = components.RemoveGesture(lists)
	local sequenceSheet = components.Sheet(lists)
	local sequenceList = components.SequenceList(sequenceSheet, "#ui.ragdollpuppeteer.label.base")
	local sequenceList2 = components.SequenceList(sequenceSheet, "#ui.ragdollpuppeteer.label.gesture")
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
		sourceBox = sourceBox,
		searchBar = searchBar,
		sequenceList = sequenceList,
		sequenceList2 = sequenceList2,
		sequenceSheet = sequenceSheet,
		smhBrowser = smhBrowser,
		smhList = smhList,
		poseParams = poseParams,
		boneTree = boneTree,
		showPuppeteer = showPuppeteer,
		removeGesture = removeGesture,
		floorCollisions = floorCollisions,
		recoverPuppeteer = recoverPuppeteer,
		shouldIncrement = shouldIncrement,
		playButton = playButton,
		fpsWang = fpsWang,
		heightOffset = heightOffset,
		puppeteerColor = puppeteerColor,
		puppeteerIgnoreZ = puppeteerIgnoreZ,
		attachToGround = attachToGround,
		anySurface = anySurface,
		incrementGestures = incrementGestures,
	}
end

---@param panelChildren PanelChildren
---@param panelProps PanelProps
---@param panelState PanelState
function UI.HookPanel(panelChildren, panelProps, panelState)
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

	local animPuppeteer = panelProps.puppeteer
	local animGesturer = panelProps.gesturer
	local basePuppeteer = panelProps.basePuppeteer
	local baseGesturer = panelProps.baseGesturer
	local puppet = panelProps.puppet
	local model = panelProps.model
	local physicsCount = panelProps.physicsCount
	local floor = panelProps.floor
	local viewPuppeteer = panelProps.viewPuppeteer

	local smhData

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
			createPlaybackTimer(panelChildren, panelProps, panelState)
			playButton:SetText("#ui.ragdollpuppeteer.label.stop")
		else
			removePlaybackTimer()
			playButton:SetText("#ui.ragdollpuppeteer.label.play")
		end
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

			net.Start("onFrameChange", true)
			net.WriteBool(true)
			net.WriteFloat(cycle)
			net.WriteBool(nonPhysCheckbox:GetChecked())
			writeSequencePose(
				{ animPuppeteer, basePuppeteer, viewPuppeteer },
				puppet,
				physicsCount,
				{ baseGesturer, animGesturer },
				panelState.defaultBonePose
			)
			net.SendToServer()
		else
			if smhList:GetSelected()[1] then
				writeSMHPose(
					"onFrameChange",
					baseSlider:GetValue(),
					smhList:GetSelected()[1]:GetSortValue(3),
					smhList:GetSelected()[1]:GetSortValue(4),
					nonPhysCheckbox:GetChecked(),
					animPuppeteer
				)
			end
		end
	end

	angOffset[1].OnValueChanged = onAngleTrioValueChange
	angOffset[2].OnValueChanged = onAngleTrioValueChange
	angOffset[3].OnValueChanged = onAngleTrioValueChange

	---@param newValue number
	---@param paramName string
	---@param slider DNumSlider
	local function onPoseParamChange(newValue, paramName, slider)
		local _, option = sourceBox:GetSelected()

		-- Set the pose parameter in the floor. The floor will automatically set the pose parameters through there
		floor["Set" .. paramName](floor, newValue)

		-- If the user has stopped dragging on the sequence, send the update
		timer.Simple(SEQUENCE_CHANGE_DELAY, function()
			if option == "sequence" and not slider:IsEditing() then
				net.Start("onPoseParamChange", true)
				net.WriteBool(nonPhysCheckbox:GetChecked())
				net.WriteFloat(newValue)
				net.WriteString(paramName)
				writeSequencePose(
					{ animPuppeteer, basePuppeteer, viewPuppeteer },
					puppet,
					physicsCount,
					{ baseGesturer, animGesturer },
					panelState.defaultBonePose
				)
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
		local _, option = sourceBox:GetSelected()
		---@cast text string
		if option == "sequence" then
			---@diagnostic disable-next-line
			local activeList = sequenceSheet:GetActiveTab():GetPanel()
			---@cast activeList DListView
			UI.ClearList(activeList)
			UI.PopulateSequenceList(activeList, animPuppeteer, function(seqInfo)
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

	local function rowSelected(row, slider, puppeteer, mutatedSequence, sendNet, isGesture)
		local currentIndex = row:GetValue(1)
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
				net.Start("onSequenceChange")
				net.WriteBool(true)
				net.WriteInt(currentIndex, 14)
				net.WriteBool(nonPhysCheckbox:GetChecked())
				writeSequencePose(
					{ animPuppeteer, basePuppeteer, viewPuppeteer },
					puppet,
					physicsCount,
					{ baseGesturer, animGesturer },
					panelState.defaultBonePose
				)
				net.SendToServer()
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
				net.Start("onFrameChange", true)
				net.WriteBool(true)
				net.WriteFloat(cycle)
				net.WriteBool(nonPhysCheckbox:GetChecked())
				writeSequencePose(
					{ animPuppeteer, basePuppeteer, viewPuppeteer },
					puppet,
					physicsCount,
					{ baseGesturer, animGesturer },
					panelState.defaultBonePose
				)
				net.SendToServer()
				sendingFrame = false
			end
		else
			if sendNet then
				if smh and smhList:GetSelected()[1] then
					writeSMHPose(
						"onFrameChange",
						val,
						smhList:GetSelected()[1]:GetSortValue(3),
						smhList:GetSelected()[1]:GetSortValue(4),
						nonPhysCheckbox:GetChecked(),
						animPuppeteer
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
			smhList:SizeTo(-1, 0, 0.5)
			smhBrowser:SizeTo(-1, 0, 0.5)
			sequenceSheet:SizeTo(-1, 500, 0.5)
		else
			gestureSlider:SetEnabled(false)
			removeGesture:SetEnabled(false)
			sequenceSheet:SizeTo(-1, 0, 0.5)
			smhList:SizeTo(-1, 250, 0.5)
			smhBrowser:SizeTo(-1, 250, 0.5)
		end
	end

	function smhList:OnRowSelected(_, row)
		baseSlider:SetMax(row:GetValue(2))
		panelState.maxFrames = row:GetValue(2)
		writeSMHPose(
			"onSequenceChange",
			0,
			smhList:GetSelected()[1]:GetSortValue(3),
			smhList:GetSelected()[1]:GetSortValue(4),
			nonPhysCheckbox:GetChecked(),
			animPuppeteer
		)
	end

	function smhBrowser:OnSelect(filePath)
		UI.ClearList(smhList)
		smhData = smh.parseSMHFile(filePath, model)
		populateSMHEntitiesList(smhList, model, smhData, function(_)
			return true
		end)
	end
end

return UI
