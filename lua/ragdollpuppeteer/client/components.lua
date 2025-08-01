local constants = include("ragdollpuppeteer/constants.lua")

local components = {}

local DEFAULT_MAX_FRAME = constants.DEFAULT_MAX_FRAME

---@param cPanel DForm
---@param model string
---@return DLabel puppetLabel
function components.PuppetLabel(cPanel, model)
	local panel = cPanel:Help(language.GetPhrase("ui.ragdollpuppeteer.label.current") .. " " .. model)
	---@cast panel DLabel
	return panel
end

---@param cPanel DForm
---@param label string?
---@param placeholder string?
---@return DTextEntry
function components.SearchBar(cPanel, label, placeholder)
	label = label or "#ui.ragdollpuppeteer.label.search"
	placeholder = placeholder or "#ui.ragdollpuppeteer.tooltip.search"
	---@diagnostic disable-next-line
	local panel = cPanel:TextEntry(label)
	---@cast panel DTextEntry
	panel:SetPlaceholderText(placeholder)

	-- Override to not remove text if beyond position bounds
	function panel:UpdateFromHistory()

		---@diagnostic disable-next-line: undefined-field
		local history = self.History

		---@diagnostic disable-next-line: undefined-field
		if ( IsValid( self.Menu ) ) then
			return self:UpdateFromMenu()
		end
	
		local pos = self.HistoryPos
		-- Is the Pos within bounds?
		if ( pos < 0 ) then pos = #history end
		if ( pos > #history ) then pos = 0 end
	
		local text = history[ pos ]
		if ( !text ) then text = self:GetValue() end
	
		self:SetText( text )
		self:SetCaretPos( utf8.len( text ) or 0 )
	
		self:OnTextChanged(false)
	
		self.HistoryPos = pos
	
	end

	return panel
end

---@param cPanel DForm | DScrollPanel
---@param label string
---@param convar string
---@param tooltip string
---@return DCheckBoxLabel checkBox
function components.CheckBox(cPanel, label, convar, tooltip)
	local panel = vgui.Create("DCheckBoxLabel", cPanel)
	panel:SetText(label)
	panel:SetDark(true)
	panel:SetConVar(convar)
	panel:SetTooltip(tooltip)

	cPanel:AddItem(panel)
	panel:Dock(TOP)
	panel:DockMargin(0, 10, 0, 0)

	return panel
end

---@param cPanel DForm
---@return DComboBox sourceBox Choose between SMH or model sequence animations
function components.AnimationSourceBox(cPanel)
	---@diagnostic disable-next-line
	local panel = cPanel:ComboBox("#ui.ragdollpuppeteer.label.source")
	---@cast panel DComboBox

	panel:AddChoice("#ui.ragdollpuppeteer.label.sequence", "sequence")
	panel:AddChoice("#ui.ragdollpuppeteer.label.smh", "smh")
	panel:ChooseOption("#ui.ragdollpuppeteer.label.sequence", 1)
	panel:SetTooltip("#ui.ragdollpuppeteer.tooltip.source")
	panel:Dock(TOP)

	return panel
end

---@param cPanel DForm
---@return DButton removeGesture Set the gesture sequence to the reference sequence
function components.RemoveGesture(cPanel)
	local panel = cPanel:Button("#ui.ragdollpuppeteer.label.removegesture", "")
	---@cast panel DButton

	panel:SetTooltip("#ui.ragdollpuppeteer.tooltip.removegesture")
	return panel
end

---@param cPanel DForm
---@return DButton randomPose Sample a nongesture sequence pose from the puppeteer's sequences
function components.RandomPose(cPanel)
	local panel = cPanel:Button("#ui.ragdollpuppeteer.label.randompose", "")
	---@cast panel DButton

	panel:SetTooltip("#ui.ragdollpuppeteer.tooltip.randompose")
	return panel
end

---@param cPanel DForm | DScrollPanel
---@return DButton recoverPuppeteer Teleport the puppeteer floor to the puppet
function components.RecoverPuppeteer(cPanel)
	local panel = vgui.Create("DButton", cPanel)
	panel:SetText("#ui.ragdollpuppeteer.label.recoverpuppeteer")
	panel:SetDark(true)
	panel:SetConsoleCommand("ragdollpuppeteer_recoverpuppeteer")
	panel:SetTooltip("#ui.ragdollpuppeteer.tooltip.recoverpuppeteer")

	cPanel:AddItem(panel)
	panel:Dock(TOP)
	panel:DockMargin(0, 10, 0, 0)

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
---@return DNumSlider heightSlider Offset the puppeteer from the platform it is standing on
function components.HeightSlider(cPanel)
	local panel = cPanel:NumSlider("#ui.ragdollpuppeteer.label.height", "", -100, 100)
	---@cast panel DNumSlider

	panel:SetValue(0)
	panel:SetTooltip("#ui.ragdollpuppeteer.tooltip.height")

	return panel
end

---@param cPanel DForm
---@return DNumSlider scaleSlider Scale the puppeteer movement
function components.ScaleSlider(cPanel)
	local panel = cPanel:NumSlider("#ui.ragdollpuppeteer.label.scale", "", 0, 1000)
	---@cast panel DNumSlider

	panel:SetValue(1)
	panel:SetTooltip("#ui.ragdollpuppeteer.tooltip.scale")

	return panel
end

---@return DNumberWang fpsWang Change the FPS ConVar
function components.FPSWang()
	local panel = vgui.Create("DNumberWang")
	panel:SetConVar("ragdollpuppeteer_fps")
	panel:SetMin(-math.huge)
	panel:SetMax(math.huge)
	panel:SetValue(30)
	panel:SetDecimals(0)

	function panel:Paint(w, h)
		derma.SkinHook("Paint", "TextEntry", self, w, h)
		DisableClipping(true)
		return false
	end

	local label = vgui.Create("DLabel", panel)
	label:SetText("#ui.ragdollpuppeteer.label.fps")
	label:SetPos(-30, -2)
	label:SetDark(true)

	panel:SetTooltip("#ui.ragdollpuppeteer.tooltip.fps")

	return panel
end

---@return DButton playButton Play the puppeteer's animation
function components.PlayButton()
	---@diagnostic disable-next-line
	local panel = vgui.Create("DButton")
	panel:SetText("#ui.ragdollpuppeteer.label.play")

	panel:SetIsToggle(true)
	panel:SetTooltip("#ui.ragdollpuppeteer.tooltip.playback")

	return panel
end

---@param cPanel DForm
---@return DPropertySheet
function components.Sheet(cPanel)
	local sheet = vgui.Create("DPropertySheet", cPanel)

	cPanel:AddItem(sheet)
	return sheet
end

---@param sheet DPropertySheet
---@return DScrollPanel, table
function components.Container(sheet, label)
	local container = vgui.Create("DScrollPanel", sheet)

	local sheetTable = sheet:AddSheet(label, container)

	return container, sheetTable
end

---@return DColorCombo puppeteerColor Change the puppeteer's color
function components.PuppeteerColors(cPanel)
	local colorCombo = vgui.Create("DColorCombo", cPanel)
	cPanel:AddItem(colorCombo)
	colorCombo:Dock(TOP)
	colorCombo:DockMargin(0, 10, 0, 0)

	return colorCombo
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
---@return DTree boneTree Filter bones
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

---@param dForm DForm
---@param puppeteer Entity
---@return PoseParameterSlider[] poseParamSliders Change the pose parameters of the puppeteer
function components.PoseParameters(dForm, puppeteer)
	---@type PoseParameterSlider[]
	local poseParams = {}

	local numParameters = puppeteer:GetNumPoseParameters()

	for i = 1, numParameters do
		poseParams[i] = poseParameterSlider(i, puppeteer, dForm)
	end

	dForm:DoExpansion(false)

	return poseParams
end

---@param dForm DForm
---@param poseParams PoseParameterSlider[]
---@param puppeteer Entity
---@return DButton
function components.ResetPoseParameters(dForm, poseParams, puppeteer)
	local resetParams = dForm:Button("#ui.ragdollpuppeteer.label.resetparams", "")
	---@cast resetParams DButton

	local numParameters = #poseParams
	function resetParams:DoClick()
		for i = 1, numParameters do
			poseParams[i].slider:ResetToDefaultValue()
		end
		puppeteer:ClearPoseParameters()
	end

	return resetParams
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

---Container for Offset Sliders
---@param cPanel DForm
---@return DForm
function components.Offsets(cPanel)
	local offsets = vgui.Create("DForm", cPanel)
	offsets:SetLabel("#ui.ragdollpuppeteer.label.offsets")

	cPanel:AddItem(offsets)
	offsets:DoExpansion(false)

	return offsets
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
