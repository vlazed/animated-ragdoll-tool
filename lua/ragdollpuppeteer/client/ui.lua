---@module "ragdollpuppeteer.lib.smh"
local smh = include("ragdollpuppeteer/lib/smh.lua")
---@module "ragdollpuppeteer.constants"
local constants = include("ragdollpuppeteer/constants.lua")
---@module "ragdollpuppeteer.client.components"
local components = include("components.lua")
---@module "ragdollpuppeteer.lib.vendor"
local vendor = include("ragdollpuppeteer/lib/vendor.lua")
---@module "ragdollpuppeteer.lib.quaternion"
include("ragdollpuppeteer/lib/quaternion.lua")

local PUPPETEER_MATERIAL = constants.PUPPETEER_MATERIAL
local INVISIBLE_MATERIAL = constants.INVISIBLE_MATERIAL

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

---@param sequenceSheet DPropertySheet
---@param smhList DListView
---@param smhBrowser DFileBrowser
---@param puppeteer Entity
function UI.Layout(sequenceSheet, smhList, smhBrowser, puppeteer)
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

	smhList:SizeTo(-1, 0, 0.5)
	smhBrowser:SizeTo(-1, 0, 0.5)
	sequenceSheet:SizeTo(-1, 500, 0.5)
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

local lastPose = {}

---Send the client's sequence bone positions, first mutating the puppeteer with the gesturer
---https://github.com/penolakushari/StandingPoseTool/blob/b7dc7b3b57d2d940bb6a4385d01a4b003c97592c/lua/autorun/standpose.lua#L42
---@param puppeteer Entity
---@param puppet Entity
---@param physicsCount integer
---@param gesturers Entity[]
---@param defaultBonePose DefaultBonePose
local function writeSequencePose(puppeteer, puppet, physicsCount, gesturers, defaultBonePose)
	if not IsValid(puppeteer) or not IsValid(puppet) then
		return
	end

	if game.SinglePlayer() then
		local baseGesturer = gesturers[1]
		local animGesturer = gesturers[2]
		local newPose = {}
		for i = 0, physicsCount - 1 do
			local b = puppet:TranslatePhysBoneToBone(i)

			if defaultBonePose and currentGesture.anims then
				local gesturePos, gestureAng
				if puppeteer:GetBoneParent(b) > -1 then
					local gPos, gAng = vendor.getBoneOffsetsOf(animGesturer, b, defaultBonePose)
					local oPos, oAng = vendor.getBoneOffsetsOf(baseGesturer, b, defaultBonePose)

					local oQuat = Quaternion()
					local gQuat = Quaternion()
					oQuat:SetAngle(oAng)
					gQuat:SetAngle(gAng)
					local dQuat = gQuat * oQuat:Invert()

					local dPos = gPos - oPos
					local dAng = dQuat:Angle()
					gesturePos, gestureAng = dPos, dAng
				else
					local gPos, gAng = animGesturer:GetBonePosition(b)
					local oPos, oAng = baseGesturer:GetBonePosition(b)
					local _, dAng = WorldToLocal(gPos, gAng, oPos, oAng)
					local dPos = gPos - oPos
					dPos, _ = LocalToWorld(dPos, angle_zero, vector_origin, puppeteer:GetAngles())

					gesturePos, gestureAng = dPos, dAng
				end

				puppeteer:ManipulateBonePosition(b, gesturePos)
				puppeteer:ManipulateBoneAngles(b, gestureAng)
			end

			local pos, ang = puppeteer:GetBonePosition(b)

			if not pos and lastPose[i] then
				pos = lastPose[i][1]
			end

			if not ang and lastPose[i] then
				ang = lastPose[i][2]
			end

			if pos == puppeteer:GetPos() then
				local matrix = puppeteer:GetBoneMatrix(b)
				if matrix then
					pos = matrix:GetTranslation()
					ang = matrix:GetAngles()
				end
			end

			-- Save the current bone pose, so later iterations can use it to offset their own bone poses with respect to this one
			newPose[i] = { pos, ang }

			net.WriteVector(pos)
			net.WriteAngle(ang)
		end

		lastPose = newPose
	end
end

---@param netString string
---@param frame integer
---@param angOffset table<Angle, Angle, Angle>
---@param smhList DListView
---@param nonPhysCheckbox DCheckBoxLabel
local function writeSMHPose(netString, frame, angOffset, smhList, nonPhysCheckbox)
	if not smhList:GetSelected()[1] then
		return
	end
	local physBonePose = smh.getPoseFromSMHFrames(frame, smhList:GetSelected()[1]:GetSortValue(3), "physbones")
	local compressedOffset = compressTableToJSON(getAngleTrio(angOffset))
	net.Start(netString, true)
	net.WriteBool(false)
	encodePose(physBonePose)
	net.WriteUInt(#compressedOffset, 16)
	net.WriteData(compressedOffset)
	net.WriteBool(nonPhysCheckbox:GetChecked())
	if nonPhysCheckbox:GetChecked() then
		local nonPhysBoneData = smh.getPoseFromSMHFrames(frame, smhList:GetSelected()[1]:GetSortValue(4), "bones")
		local compressedNonPhysPose = compressTableToJSON(nonPhysBoneData)
		net.WriteUInt(#compressedNonPhysPose, 16)
		net.WriteData(compressedNonPhysPose)
	end

	net.SendToServer()
end

local baseFPS = 30

---@param panelChildren PanelChildren
---@param panelProps PanelProps
---@param panelState PanelState
function UI.NetHookPanel(panelChildren, panelProps, panelState)
	local baseSlider = panelChildren.baseSlider
	local gestureSlider = panelChildren.gestureSlider
	local sourceBox = panelChildren.sourceBox
	local nonPhysCheckbox = panelChildren.nonPhysCheckBox
	local angOffset = panelChildren.angOffset
	local smhList = panelChildren.smhList

	local animPuppeteer = panelProps.puppeteer
	local baseGesturer = panelProps.baseGesturer
	local animGesturer = panelProps.gesturer
	local puppet = panelProps.puppet
	local physicsCount = panelProps.physicsCount

	local function moveSliderBy(val)
		if not IsValid(baseSlider) then
			return
		end
		baseSlider:SetValue((baseSlider:GetValue() + val) % baseSlider:GetMax())
		gestureSlider:SetValue((gestureSlider:GetValue() + val) % gestureSlider:GetMax())
	end

	-- Network hooks from server
	net.Receive("onFramePrevious", function()
		moveSliderBy(-1)
	end)
	net.Receive("onFrameNext", function()
		moveSliderBy(1)
	end)
	net.Receive("enablePuppeteerPlayback", function(len, ply)
		local fps = net.ReadFloat()
		timer.Remove("ragdollpuppeteer_playback")
		timer.Create("ragdollpuppeteer_playback", 1 / baseFPS, -1, function()
			if not IsValid(animPuppeteer) then
				return
			end

			local shouldIncrement = GetConVar("ragdollpuppeteer_playback_shouldincrement")
				and GetConVar("ragdollpuppeteer_playback_shouldincrement"):GetInt() > 0
			if shouldIncrement then
				local increment = fps / baseFPS
				moveSliderBy(increment)
			else
				local _, option = sourceBox:GetSelected()
				if option == "sequence" then
					local numframes = baseSlider:GetMax()
					local val = baseSlider:GetValue()
					local cycle = val / numframes
					animPuppeteer:SetCycle(cycle)

					net.Start("onFrameChange", true)
					net.WriteBool(true)
					net.WriteFloat(cycle)
					net.WriteBool(nonPhysCheckbox:GetChecked())
					writeSequencePose(
						animPuppeteer,
						puppet,
						physicsCount,
						{ baseGesturer, animGesturer },
						panelState.defaultBonePose
					)
					net.SendToServer()
				else
					writeSMHPose("onFrameChange", baseSlider:GetValue(), angOffset, smhList, nonPhysCheckbox)
				end
			end
		end)
	end)
	net.Receive("disablePuppeteerPlayback", function(len, ply)
		timer.Remove("ragdollpuppeteer_playback")
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
	local angOffset = components.AngleNumSliderTrio(
		cPanel,
		{ "#ui.ragdollpuppeteer.label.pitch", "#ui.ragdollpuppeteer.label.yaw", "#ui.ragdollpuppeteer.label.roll" },
		"#ui.ragdollpuppeteer.label.angleoffset"
	)
	local poseParams = components.PoseParameters(cPanel, puppeteer)

	local settings = components.Settings(cPanel)
	local nonPhysCheckbox = components.NonPhysCheckBox(settings)
	local showPuppeteer = components.PuppeteerVisible(settings)
	local floorCollisions = components.FloorWorldCollisions(settings)
	local shouldIncrement = components.ShouldIncrement(settings)
	local recoverPuppeteer = components.RecoverPuppeteer(settings)

	local boneTree = components.BoneTree(cPanel)

	local lists = components.Lists(cPanel)

	local sourceBox = components.AnimationSourceBox(lists)
	local searchBar = components.SearchBar(lists)
	local removeGesture = components.RemoveGesture(lists)
	local sequenceSheet = components.SequenceSheet(lists)
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

	local animPuppeteer = panelProps.puppeteer
	local animGesturer = panelProps.gesturer
	local basePuppeteer = panelProps.basePuppeteer
	local baseGesturer = panelProps.baseGesturer
	local puppet = panelProps.puppet
	local model = panelProps.model
	local physicsCount = panelProps.physicsCount

	local smhData

	setupBoneNodesOf(puppet, boneTree)

	local filteredBones = {}
	for b = 1, puppet:GetBoneCount() do
		filteredBones[b] = false
	end

	local lastCheck
	function showPuppeteer:OnChange(checked)
		-- FIXME: This gets called twice, which makes the statement below necessary; maybe due to the cvar?
		if lastCheck ~= nil and lastCheck == checked then
			return
		end

		if not IsValid(animPuppeteer) then
			return
		end

		if checked then
			animPuppeteer:SetMaterial("!" .. PUPPETEER_MATERIAL:GetName())
			animPuppeteer.ragdollpuppeteer_currentMaterial = PUPPETEER_MATERIAL
		else
			animPuppeteer:SetMaterial("!" .. INVISIBLE_MATERIAL:GetName())
			animPuppeteer.ragdollpuppeteer_currentMaterial = INVISIBLE_MATERIAL
		end
		lastCheck = checked
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
		animPuppeteer.angleOffset = angleOffset

		local _, option = sourceBox:GetSelected()
		if option == "sequence" then
			local numframes = baseSlider:GetMax()
			local val = baseSlider:GetValue()
			local cycle = val / numframes
			animPuppeteer:SetCycle(cycle)

			net.Start("onFrameChange", true)
			net.WriteBool(true)
			net.WriteFloat(cycle)
			net.WriteBool(nonPhysCheckbox:GetChecked())
			writeSequencePose(
				animPuppeteer,
				puppet,
				physicsCount,
				{ baseGesturer, animGesturer },
				panelState.defaultBonePose
			)
			net.SendToServer()
		else
			writeSMHPose("onFrameChange", baseSlider:GetValue(), angOffset, smhList, nonPhysCheckbox)
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

		animPuppeteer:SetPoseParameter(paramName, newValue)
		animPuppeteer:InvalidateBoneCache()

		-- If the user has stopped dragging on the sequence, send the update
		timer.Simple(SEQUENCE_CHANGE_DELAY, function()
			if option == "sequence" and not slider:IsEditing() then
				net.Start("onPoseParamChange", true)
				net.WriteBool(nonPhysCheckbox:GetChecked())
				net.WriteFloat(newValue)
				net.WriteString(paramName)
				writeSequencePose(
					animPuppeteer,
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
			setSequenceOf(basePuppeteer, currentIndex)
			if isGesture then
				setSequenceOf(baseGesturer, currentIndex)
			else
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
					animPuppeteer,
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
	local function sliderValueChanged(slider, val, sequence, puppeteer, smh)
		local prevFrame = slider.prevFrame
		-- Only send when we go frame by frame
		if math.abs(prevFrame - val) < 1 then
			return
		end
		local _, option = sourceBox:GetSelected()
		if option == "sequence" then
			if not sequence.anims then
				return
			end
			if not IsValid(puppeteer) then
				return
			end
			local numframes = slider:GetMax()
			slider:SetValue(math.Clamp(val, slider:GetMin(), numframes))
			local cycle = val / numframes
			puppeteer:SetCycle(cycle)

			if sendingFrame then
				return
			end

			sendingFrame = true
			net.Start("onFrameChange", true)
			net.WriteBool(true)
			net.WriteFloat(cycle)
			net.WriteBool(nonPhysCheckbox:GetChecked())
			writeSequencePose(
				animPuppeteer,
				puppet,
				physicsCount,
				{ baseGesturer, animGesturer },
				panelState.defaultBonePose
			)
			net.SendToServer()
			sendingFrame = false
		else
			if smh then
				writeSMHPose("onFrameChange", val, angOffset, smhList, nonPhysCheckbox)
			end
		end

		slider.prevFrame = val
	end

	function baseSlider:OnValueChanged(val)
		sliderValueChanged(baseSlider, val, currentSequence, animPuppeteer, true)
	end

	function gestureSlider:OnValueChanged(val)
		sliderValueChanged(gestureSlider, val, currentGesture, animGesturer, false)
	end

	function sourceBox:OnSelect(_, _, option)
		if option == "sequence" then
			gestureSlider:SetEnabled(true)
			smhList:SizeTo(-1, 0, 0.5)
			smhBrowser:SizeTo(-1, 0, 0.5)
			sequenceSheet:SizeTo(-1, 500, 0.5)
		else
			gestureSlider:SetEnabled(false)
			sequenceSheet:SizeTo(-1, 0, 0.5)
			smhList:SizeTo(-1, 250, 0.5)
			smhBrowser:SizeTo(-1, 250, 0.5)
		end
	end

	function smhList:OnRowSelected(_, row)
		baseSlider:SetMax(row:GetValue(2))
		panelState.maxFrames = row:GetValue(2)
		writeSMHPose("onSequenceChange", 0, angOffset, smhList, nonPhysCheckbox)
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
