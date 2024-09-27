local constants = include("ragdollpuppeteer/constants.lua")

local components = {}

local DEFAULT_MAX_FRAME = constants.DEFAULT_MAX_FRAME

---@param cPanel DForm
---@param model string
---@return DLabel
function components.PuppetLabel(cPanel, model)
	local panel = cPanel:Help(language.GetPhrase("ui.ragdollpuppeteer.label.current") .. " " .. model)
	---@cast panel DLabel
	return panel
end

---@param cPanel DForm
---@return DTextEntry
function components.SearchBar(cPanel)
	---@diagnostic disable-next-line
	local panel = cPanel:TextEntry("#ui.ragdollpuppeteer.label.search")
	---@cast panel DTextEntry
	panel:SetPlaceholderText("#ui.ragdollpuppeteer.tooltip.search")

	return panel
end

function components.ShouldIncrement(cPanel)
	local panel =
		cPanel:CheckBox("#ui.ragdollpuppeteer.label.shouldincrement", "ragdollpuppeteer_playback_shouldincrement")
	---@cast panel DCheckBoxLabel

	panel:SetTooltip("#ui.ragdollpuppeteer.tooltip.shouldincrement")

	return panel
end

function components.FloorWorldCollisions(cPanel)
	local panel = cPanel:CheckBox("#ui.ragdollpuppeteer.label.floorworld", "ragdollpuppeteer_floor_worldcollisions")
	---@cast panel DCheckBoxLabel

	panel:SetTooltip("#ui.ragdollpuppeteer.tooltip.floorworld")

	return panel
end

---@param cPanel DForm
---@return DComboBox
function components.AnimationSourceBox(cPanel)
	---@diagnostic disable-next-line
	local panel = cPanel:ComboBox("#ui.ragdollpuppeteer.label.source")
	---@cast panel DComboBox

	panel:AddChoice("#ui.ragdollpuppeteer.label.sequence", "sequence")
	panel:AddChoice("#ui.ragdollpuppeteer.label.smh", "smh")
	panel:ChooseOption("#ui.ragdollpuppeteer.label.sequence", 1)
	panel:SetTooltip("#ui.ragdollpuppeteer.tooltip.source")

	return panel
end

---@param cPanel DForm
---@return DButton
function components.RemoveGesture(cPanel)
	local panel = cPanel:Button("#ui.ragdollpuppeteer.label.removegesture", "")
	---@cast panel DButton

	panel:SetTooltip("#ui.ragdollpuppeteer.tooltip.removegesture")
	return panel
end

---@param cPanel DForm
---@return DButton
function components.RecoverPuppeteer(cPanel)
	local panel = cPanel:Button("#ui.ragdollpuppeteer.label.recoverpuppeteer", "ragdollpuppeteer_recoverpuppeteer")
	---@cast panel DButton

	panel:SetTooltip("#ui.ragdollpuppeteer.tooltip.recoverpuppeteer")
	return panel
end

---@param cPanel DForm
---@param label string
---@return FrameSlider
function components.FrameSlider(cPanel, cvar, label, tooltip)
	label = label or "Frame"
	tooltip = tooltip or "#ui.ragdollpuppeteer.tooltip.timeline"
	local panel = cPanel:NumSlider(label, cvar, 0, DEFAULT_MAX_FRAME - 1, 0)
	---@cast panel FrameSlider

	panel.prevFrame = 0
	panel:SetTooltip(tooltip)

	return panel
end

---@param cPanel DForm
---@return DCheckBoxLabel
function components.NonPhysCheckBox(cPanel)
	local panel = cPanel:CheckBox("#ui.ragdollpuppeteer.label.nonphys", "ragdollpuppeteer_animatenonphys")
	---@cast panel DCheckBoxLabel

	panel:SetTooltip("#ui.ragdollpuppeteer.tooltip.nonphys")

	return panel
end

---@param cPanel DForm
---@return DCheckBoxLabel
function components.PuppeteerVisible(cPanel)
	local panel = cPanel:CheckBox("#ui.ragdollpuppeteer.label.showpuppeteer", "ragdollpuppeteer_showpuppeteer")
	---@cast panel DCheckBoxLabel

	panel:SetTooltip("#ui.ragdollpuppeteer.tooltip.showpuppeteer")

	return panel
end

function components.SequenceSheet(cPanel)
	local sequenceSheet = vgui.Create("DPropertySheet", cPanel)

	cPanel:AddItem(sequenceSheet)
	return sequenceSheet
end

---@param dForm DForm
---@param names string[]
---@return DNumSlider[]
function components.AngleNumSliders(dForm, names)
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

---Set the angle of the sequence or SMH animation
---@param cPanel DForm
---@param names string[]
---@param label string
---@return DNumSlider[]
function components.AngleNumSliderTrio(cPanel, names, label)
	local dForm = vgui.Create("DForm")
	dForm:SetLabel(label)
	local angleSliders = components.AngleNumSliders(dForm, names)
	cPanel:AddItem(dForm)
	---@diagnostic disable-next-line
	local resetAngles = dForm:Button("#ui.ragdollpuppeteer.label.resetangles")
	function resetAngles:DoClick()
		for i = 1, 3 do
			angleSliders[i]:SetValue(0)
		end
	end

	dForm:DoExpansion(false)

	return angleSliders
end

---@param sheet DPropertySheet
---@return DListView
function components.SequenceList(sheet, label)
	local animationList = vgui.Create("DListView", sheet)
	animationList:SetMultiSelect(false)
	animationList:AddColumn("#ui.ragdollpuppeteer.sequences.id")
	animationList:AddColumn("#ui.ragdollpuppeteer.shared.name")
	animationList:AddColumn("#ui.ragdollpuppeteer.sequences.fps")
	animationList:AddColumn("#ui.ragdollpuppeteer.shared.duration")
	sheet:AddSheet(label, animationList)
	return animationList
end

---@param cPanel DForm
---@return DListView
function components.SMHEntityList(cPanel)
	local animationList = vgui.Create("DListView", cPanel)
	animationList:SetMultiSelect(false)
	animationList:AddColumn("#ui.ragdollpuppeteer.shared.name")
	animationList:AddColumn("#ui.ragdollpuppeteer.shared.duration")
	cPanel:AddItem(animationList)
	return animationList
end

---@param cPanel DForm
---@return DFileBrowser
function components.SMHFileBrowser(cPanel)
	local fileBrowser = vgui.Create("DFileBrowser", cPanel)
	fileBrowser:SetPath("DATA")
	fileBrowser:SetBaseFolder("smh")
	fileBrowser:SetCurrentFolder("smh")
	cPanel:AddItem(fileBrowser)
	return fileBrowser
end

---@param cPanel DForm
---@return DTree
function components.BoneTree(cPanel)
	local boneTreeContainer = vgui.Create("DForm", cPanel)
	cPanel:AddItem(boneTreeContainer)
	boneTreeContainer:SetLabel("#ui.ragdollpuppeteer.label.bonetree")
	boneTreeContainer:Help("#ui.ragdollpuppeteer.tooltip.bonetree")
	boneTreeContainer:Dock(TOP)

	local boneTree = vgui.Create("DTree", boneTreeContainer)
	boneTreeContainer:AddItem(boneTree)
	boneTree:Dock(TOP)

	boneTree:SizeTo(-1, 250, 0)

	boneTreeContainer:SetExpanded(false)

	return boneTree
end

---Container for timelines
---@param cPanel DForm
---@return DForm
function components.Timelines(cPanel)
	local timelines = vgui.Create("DForm", cPanel)
	timelines:SetLabel("#ui.ragdollpuppeteer.label.timelines")
	cPanel:AddItem(timelines)

	return timelines
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
function components.PoseParameters(cPanel, puppeteer)
	---@type PoseParameterSlider[]
	local poseParams = {}

	---@type DForm
	local dForm = vgui.Create("DForm")
	dForm:SetLabel("#ui.ragdollpuppeteer.label.poseparams")
	local numParameters = puppeteer:GetNumPoseParameters()

	for i = 1, numParameters do
		poseParams[i] = poseParameterSlider(i, puppeteer, dForm)
	end

	---@diagnostic disable-next-line
	local resetParams = dForm:Button("#ui.ragdollpuppeteer.label.resetparams")
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

---Container for ConVar settings
---@param cPanel DForm
---@return DForm
function components.Settings(cPanel)
	local settings = vgui.Create("DForm", cPanel)
	settings:SetLabel("#ui.ragdollpuppeteer.label.settings")

	cPanel:AddItem(settings)

	return settings
end

---Container for lists
---@param cPanel DForm
---@return DForm
function components.Lists(cPanel)
	local lists = vgui.Create("DForm", cPanel)
	lists:SetLabel("#ui.ragdollpuppeteer.label.hidelist")
	cPanel:AddItem(lists)

	function lists:OnToggle(expanded)
		if expanded then
			lists:SetLabel("#ui.ragdollpuppeteer.label.hidelist")
		else
			lists:SetLabel("#ui.ragdollpuppeteer.label.showlist")
		end
	end

	return lists
end

return components
