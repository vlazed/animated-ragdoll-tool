---@module "ragdollpuppeteer.smh"
local SMH = include("ragdollpuppeteer/smh.lua")

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

---@class PanelProps
---@field puppet Entity
---@field physicsCount integer
---@field puppeteer Entity
---@field model string

---@class PanelState
---@field maxFrames integer
---@field previousPuppeteer Entity?
---@field defaultBonePose DefaultBonePose
---@field sequenceOrFrameChange boolean

local DEFAULT_MAX_FRAME = 60
local SEQUENCE_CHANGE_DELAY = 0.2

local UI = {}

local currentSequence = {
	label = "",
}

local function compressTableToJSON(tab)
	return util.Compress(util.TableToJSON(tab))
end

---@param cPanel DForm
---@param model string
---@return DLabel
function UI.PuppetLabel(cPanel, model)
	local panel = cPanel:Help("Current Puppet: " .. model)
	---@cast panel DLabel
	return panel
end

---@param cPanel DForm
---@return DTextEntry
function UI.SearchBar(cPanel)
	---@diagnostic disable-next-line
	local panel = cPanel:TextEntry("Search Bar:")
	---@cast panel DTextEntry
	panel:SetPlaceholderText("Search for a sequence...")

	return panel
end

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

---@param cPanel DForm
---@param puppeteer Entity
---@return DButton
function UI.UpdatePuppeteerButton(cPanel, puppeteer)
	local panel = cPanel:Button("Update Puppeteer Position", "ragdollpuppeteer_updateposition", puppeteer)
	---@cast panel DButton
	return panel
end

---@param cPanel DForm
---@return DNumSlider
function UI.FrameSlider(cPanel)
	local panel = cPanel:NumSlider("Frame", "ragdollpuppeteer_frame", 0, DEFAULT_MAX_FRAME - 1, 0)
	---@cast panel DNumSlider
	return panel
end

---@param cPanel DForm
---@return DCheckBoxLabel
function UI.NonPhysCheckBox(cPanel)
	local panel = cPanel:CheckBox("Animate Nonphysical Bones", "ragdollpuppeteer_animatenonphys")
	---@cast panel DCheckBoxLabel
	return panel
end

---@param cPanel DForm
---@return DCheckBoxLabel
function UI.FindFloor(cPanel)
	local panel = cPanel:CheckBox("Teleport to Floor", "ragdollpuppeteer_updateposition_floors")
	---@cast panel DCheckBoxLabel
	return panel
end

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

-- Populate the DList with the puppeteer sequence
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

---@param numSlider DNumSlider
function UI.NetHookPanel(numSlider)
	-- Network hooks from server
	net.Receive("onFramePrevious", function()
		numSlider:SetValue((numSlider:GetValue() - 1) % numSlider:GetMax())
	end)
	net.Receive("onFrameNext", function()
		numSlider:SetValue((numSlider:GetValue() + 1) % numSlider:GetMax())
	end)
end

---@param cPanel DForm
---@return DForm
function UI.Settings(cPanel)
	local settings = vgui.Create("DForm", cPanel)
	settings:SetLabel("Settings")

	cPanel:AddItem(settings)

	return settings
end

---Construct the ragdoll puppeteer control panel and return its components
---@param panelProps PanelProps
---@return PanelChildren
function UI.ConstructPanel(cPanel, panelProps)
	local model = panelProps.model
	local puppeteer = panelProps.puppeteer

	local puppetLabel = UI.PuppetLabel(cPanel, model)
	local numSlider = UI.FrameSlider(cPanel)
	local angOffset = UI.AngleNumSliderTrio(cPanel, { "Pitch", "Yaw", "Roll" }, "Angle Offset")
	local poseParams = UI.PoseParameters(cPanel, puppeteer)
	local settings = UI.Settings(cPanel)
	local nonPhysCheckbox = UI.NonPhysCheckBox(settings)
	local findFloor = UI.FindFloor(settings)
	local updatePuppeteerButton = UI.UpdatePuppeteerButton(cPanel, puppeteer)
	local sourceBox = UI.AnimationSourceBox(cPanel)
	local searchBar = UI.SearchBar(cPanel)
	local sequenceList = UI.SequenceList(cPanel)
	local smhBrowser = UI.SMHFileBrowser(cPanel)
	local smhList = UI.SMHEntityList(cPanel)

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
	}
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

	local animPuppeteer = panelProps.puppeteer
	local puppet = panelProps.puppet
	local model = panelProps.model
	local physicsCount = panelProps.physicsCount

	local smhData

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
	local function writeSequencePose(ent, rag, physicsObjects)
		if game.SinglePlayer() then
			for i = 0, physicsObjects do
				local b = rag:TranslatePhysBoneToBone(i)
				local pos, ang = ent:GetBonePosition(b)
				if pos == ent:GetPos() then
					local matrix = ent:GetBoneMatrix(b)
					if matrix then
						pos = matrix:GetTranslation()
						ang = matrix:GetAngles()
					end
				end
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
		timer.Simple(0.2, function()
			if sourceBox:GetSelected() == "Sequence" and not slider:IsEditing() then
				panelState.sequenceOrFrameChange = true
				net.Start("onPoseParamChange", true)
				net.WriteBool(nonPhysCheckbox:GetChecked())
				net.WriteFloat(newValue)
				net.WriteString(paramName)
				writeSequencePose(animPuppeteer, puppet, physicsCount)
				net.SendToServer()
				panelState.sequenceOrFrameChange = false
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
					return string.find(seqInfo.label:lower(), text:lower())
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
		if panelState.sequenceOrFrameChange then
			return
		end

		local currentIndex = row:GetValue(1)
		local seqInfo = animPuppeteer:GetSequenceInfo(currentIndex)
		if currentSequence.label ~= seqInfo.label then
			currentSequence = seqInfo
			animPuppeteer:ResetSequence(currentIndex)
			animPuppeteer:SetCycle(0)
			animPuppeteer:SetPlaybackRate(0)
			numSlider:SetMax(row:GetValue(4) - 1)
			panelState.maxFrames = row:GetValue(4) - 1
			timer.Simple(SEQUENCE_CHANGE_DELAY, function()
				panelState.sequenceOrFrameChange = true
				net.Start("onSequenceChange")
				net.WriteBool(true)
				net.WriteInt(currentIndex, 14)
				net.WriteBool(nonPhysCheckbox:GetChecked())
				writeSequencePose(animPuppeteer, puppet, physicsCount)
				net.SendToServer()
				panelState.sequenceOrFrameChange = false
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
			if not currentSequence.anims or panelState.sequenceOrFrameChange then
				return
			end
			if not IsValid(animPuppeteer) then
				return
			end
			local numframes = findLongestAnimationIn(currentSequence, animPuppeteer).numframes - 1
			numSlider:SetValue(math.Clamp(val, 0, numframes))
			local cycle = val / numframes
			animPuppeteer:SetCycle(cycle)

			panelState.sequenceOrFrameChange = true
			net.Start("onFrameChange", true)
			net.WriteBool(true)
			net.WriteFloat(cycle)
			net.WriteBool(nonPhysCheckbox:GetChecked())
			writeSequencePose(animPuppeteer, puppet, physicsCount)
			net.SendToServer()
			panelState.sequenceOrFrameChange = false
		else
			panelState.sequenceOrFrameChange = true
			writeSMHPose("onFrameChange", val)
			panelState.sequenceOrFrameChange = false
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
		panelState.sequenceOrFrameChange = true
		writeSMHPose("onSequenceChange", 0)
		panelState.sequenceOrFrameChange = false
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
