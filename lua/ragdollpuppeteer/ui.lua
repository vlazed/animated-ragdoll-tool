local UI = {}

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
---@param defaultMaxFrame integer
---@return DNumSlider
function UI.FrameSlider(cPanel, defaultMaxFrame)
	local panel = cPanel:NumSlider("Frame", "ragdollpuppeteer_frame", 0, defaultMaxFrame - 1, 0)
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
---@return table
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
---@return table
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
	return angleSliders
end

return UI
