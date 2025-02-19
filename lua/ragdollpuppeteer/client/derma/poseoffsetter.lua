include("presetsaver.lua")

---@module "ragdollpuppeteer.lib.fzy"
local fzy = include("ragdollpuppeteer/lib/fzy.lua")

---@class ragdollpuppeteer_poseoffsetter: DFrame
local PANEL = {}

local WIDTH, HEIGHT = ScrW(), ScrH()

function PANEL:Init()
	self:SetTitle("Ragdoll Puppeteer")

	self:SetDraggable(false)
	self:ShowCloseButton(false)
	self:SetDeleteOnClose(false)
	self:SetSizable(false)

	self:SetPos(WIDTH * 0.1, HEIGHT * 0.25)
	self:SetSize(WIDTH * 0.125, HEIGHT * 0.5)

	self.ButtonHeight = 80

	self.BoneOffset = vgui.Create("DPanel", self)

	---@param strLabel string
	---@param numMin number
	---@param numMax number
	---@param parent Panel
	---@return DNumSlider
	local function numSlider(strLabel, numMin, numMax, parent)
		local slider = vgui.Create("DNumSlider", parent)
		slider:SetText(strLabel)
		slider:SetMinMax(numMin, numMax)
		slider:SetDark(true)

		slider:SetDefaultValue(0)
		slider:SetValue(0)

		slider:SizeToContents()

		slider.OnValueChanged = function(_)
			self:TransformChanged()
		end

		return slider
	end

	self.BoneOffset.PresetSaver = vgui.Create("ragdollpuppeteer_presetsaver", self.BoneOffset)
	self.BoneOffset.SaveEntry = vgui.Create("DTextEntry", self.BoneOffset)
	self.BoneOffset.SaveEntry:SetPlaceholderText("#ui.ragdollpuppeteer.offset.save.placeholder")

	function self.BoneOffset.PresetSaver.OnLoadPreset(_, preset, name)
		if preset.model == self.Entity:GetModel() then
			for bone, presetField in pairs(preset.offsets) do
				self:OnTransformChange(bone, presetField.pos, presetField.ang)
				if bone == self:GetSelectedBone() then
					self:SetTransform(presetField, true)
				end
			end
			self.BoneOffset.SaveEntry:SetValue(name)
		else
			self:OnSaveFailure(
				language.GetPhrase("ui.ragdollpuppeteer.offset.save.failure.model") .. " " .. preset.model
			)
		end
	end

	function self.BoneOffset.PresetSaver.OnSavePreset()
		return self:OnSavePreset()
	end

	function self.BoneOffset.PresetSaver.OnSaveFailure(_, msg)
		return self:OnSaveFailure(msg)
	end

	function self.BoneOffset.PresetSaver.OnSaveSuccess(_, msg)
		return self:OnSaveSuccess(msg)
	end

	function self.BoneOffset.SaveEntry.OnValueChange(_, str)
		self.BoneOffset.PresetSaver:SetSaveName(str)
	end

	self.BoneOffset.Pitch = numSlider("#ui.ragdollpuppeteer.offset.pitch", -180, 180, self.BoneOffset)
	self.BoneOffset.Yaw = numSlider("#ui.ragdollpuppeteer.offset.yaw", -180, 180, self.BoneOffset)
	self.BoneOffset.Roll = numSlider("#ui.ragdollpuppeteer.offset.roll", -180, 180, self.BoneOffset)

	self.BoneOffset.PosX = numSlider("X", -100, 100, self.BoneOffset)
	self.BoneOffset.PosY = numSlider("Y", -100, 100, self.BoneOffset)
	self.BoneOffset.PosZ = numSlider("Z", -100, 100, self.BoneOffset)

	self.BoneOffset.Selector = vgui.Create("DComboBox", self.BoneOffset)
	self.BoneOffset.Selector.Label = vgui.Create("DLabel", self.BoneOffset)
	self.BoneOffset.Selector.Label:SetText("#ui.ragdollpuppeteer.offset.selector")
	self.BoneOffset.Selector.Label:SetDark(true)

	---@param pnl DComboBox
	---@param name string
	---@param bone integer
	function self.BoneOffset.Selector.OnSelect(pnl, _, name, bone)
		self.BoneOffset.Search:SetText(name)
		self:OnBoneSelect(bone)
	end

	self.BoneOffset.FilterNonPhys = vgui.Create("DCheckBoxLabel", self.BoneOffset)
	self.BoneOffset.FilterNonPhys:SetText("Phys")
	self.BoneOffset.FilterNonPhys:SetDark(true)
	function self.BoneOffset.FilterNonPhys.OnChange()
		self:RefreshBoneList()
	end

	self.BoneOffset.Search = vgui.Create("DTextEntry", self.BoneOffset)
	self.BoneOffset.Search:SetPlaceholderText("#ui.ragdollpuppeteer.offset.search")
	function self.BoneOffset.Search.GetAutoComplete(_, text)
		local suggestions = {}
		---INFO: Choices is a field for DComboBox
		---@diagnostic disable-next-line: undefined-field
		local choices = self.BoneOffset.Selector.Choices

		for _, result in ipairs(fzy.filter(text, choices, false)) do
			table.insert(suggestions, choices[result[1]])
		end

		return suggestions
	end

	---Overrides the original function by not calling OnTextChanged, allowing the user
	---to still look through the search options without closing it
	function self.BoneOffset.Search:UpdateFromMenu()
		---INFO: Menu is a field of DTextEntry, for autocomplete menu
		---@diagnostic disable-next-line: undefined-field
		local menu = self.Menu

		local pos = self.HistoryPos
		local num = menu:ChildCount()

		menu:ClearHighlights()

		if pos < 0 then
			pos = num
		end
		if pos > num then
			pos = 0
		end

		local item = menu:GetChild(pos)
		if not item then
			self.HistoryPos = pos
			return
		end

		menu:HighlightItem(item)

		local txt = item:GetText()

		self:SetText(txt)
		self:SetCaretPos(utf8.len(txt) or 0)

		self.HistoryPos = pos
	end

	---@param pnl DTextEntry
	---@param newBoneName string
	function self.BoneOffset.Search.OnValueChange(pnl, newBoneName)
		local bone = self.Entity:LookupBone(newBoneName)
		if bone then
			self.BoneOffset.Selector:ChooseOption(newBoneName, self.bonesToOption[bone])
		end
	end

	self.BoneOffset.SelectMirror = vgui.Create("DButton", self.BoneOffset)
	self.BoneOffset.SelectMirror:SetText("#ui.ragdollpuppeteer.offset.mirror")
	self.BoneOffset.SelectMirror:SetTooltip("#ui.ragdollpuppeteer.offset.mirror.tooltip")
	function self.BoneOffset.SelectMirror.DoClick()
		self:SelectMirror()
	end

	self.BoneOffset.ResetOffsets = vgui.Create("DButton", self.BoneOffset)
	self.BoneOffset.ResetAllOffsets = vgui.Create("DButton", self.BoneOffset)
	function self.BoneOffset.ResetOffsets.DoClick()
		self:ResetOffset()
	end
	function self.BoneOffset.ResetAllOffsets.DoClick()
		for i = 0, self.Entity:GetBoneCount() - 1 do
			self:OnTransformChange(i, vector_origin, angle_zero)
		end
		self:ResetOffset()
	end

	self.BoneOffset.ResetOffsets:SetText("#ui.ragdollpuppeteer.offset.reset")
	self.BoneOffset.ResetAllOffsets:SetText("#ui.ragdollpuppeteer.offset.resetall")

	self.Entity = NULL
	self.bonesToOption = {}
end

function PANEL:ResetOffset()
	self:SetTransform({
		pos = vector_origin,
		ang = angle_zero,
	})
end

local switchChar = {
	["L"] = "R",
	["R"] = "L",
	["l"] = "r",
	["r"] = "l",
}

---Iterate through a string and look for a `_` character followed by either `L` or `R`.
---If the next character is `_`, or it is the end of the string, then return the position.
---@param str string
---@return integer?
---@return string?
local function findSidePosition(str)
	local capture = false
	for i = 1, #str do
		if str[i] == "_" then
			capture = true
		end
		if switchChar[str[i]] and capture and (i + 1 < #str and str[i + 1] == "_" or i == #str) then
			return i, str[i]
		end
	end
end

function PANEL:SelectMirror()
	local oldBone = self:GetSelectedBone()
	if not oldBone then
		return
	end
	local oldName = self.Entity:GetBoneName(oldBone)
	local pos, char = findSidePosition(oldName)

	if pos then
		local newNameTable = string.ToTable(oldName)
		newNameTable[pos] = switchChar[char]
		local newName = table.concat(newNameTable)
		local newBone = self.Entity:LookupBone(newName)

		self.BoneOffset.Selector:ChooseOption(
			newBone and newName or oldName,
			newBone and self.bonesToOption[newBone] or self.bonesToOption[oldBone]
		)
	end
end

function PANEL:SetDirectory(newDirectory)
	self.BoneOffset.PresetSaver:SetDirectory(newDirectory)
end

function PANEL:RefreshDirectory()
	self.BoneOffset.PresetSaver:RefreshDirectory()
end

---@return PoseOffsetPreset?
function PANEL:OnSavePreset() end

function PANEL:TransformChanged()
	if self.ignore then
		return
	end

	local pos =
		Vector(self.BoneOffset.PosX:GetValue(), self.BoneOffset.PosY:GetValue(), self.BoneOffset.PosZ:GetValue())
	local ang = Angle(self.BoneOffset.Pitch:GetValue(), self.BoneOffset.Yaw:GetValue(), self.BoneOffset.Roll:GetValue())
	local bone = self:GetSelectedBone()

	if bone then
		self:OnTransformChange(bone, pos, ang)
	end
end

---@param bone integer
---@param pos Vector
---@param ang Angle
function PANEL:OnTransformChange(bone, pos, ang) end

---@param poseOffset BonePoseOffset
function PANEL:SetTransform(poseOffset, ignore)
	ignore = Either(ignore ~= nil, ignore, true)

	local pos, ang = poseOffset and poseOffset.pos or vector_origin, poseOffset and poseOffset.ang or angle_zero

	self.ignore = ignore

	self.BoneOffset.PosX:SetValue(pos[1])
	self.BoneOffset.PosY:SetValue(pos[2])
	self.BoneOffset.PosZ:SetValue(pos[3])

	self.BoneOffset.Pitch:SetValue(ang[1])
	self.BoneOffset.Yaw:SetValue(ang[2])
	self.BoneOffset.Roll:SetValue(ang[3])

	self.ignore = false
end

function PANEL:OnBoneSelect(bone) end

function PANEL:OnSaveFailure(message) end

function PANEL:OnSaveSuccess(message) end

function PANEL:Paint(w, h)
	local old = DisableClipping(true)
	DisableClipping(old)

	derma.SkinHook("Paint", "Frame", self, w, h)

	return true
end

---Initialize a starting position. Every call to this function will add to the `pos` variable by `offset`
---@param pos number Initial position
---@param offset number Delta position
---@return fun(panel: Panel)
local function setPosition(pos, offset, startingX)
	startingX = startingX or 5
	return function(panel)
		panel:SetPos(startingX, pos)
		pos = pos + offset
	end
end

function PANEL:PerformLayout(width, height)
	---@diagnostic disable-next-line
	self.BaseClass.PerformLayout(self, width, height)

	width, height = self.BoneOffset:GetSize()

	self.BoneOffset:Dock(FILL)

	self.BoneOffset.PresetSaver:SetPos(5, 10)
	self.BoneOffset.PresetSaver:SetSize(width - 10, 50)

	local setPos = setPosition(60, 25, 10)
	setPos(self.BoneOffset.SaveEntry)
	self.BoneOffset.SaveEntry:SetWide(width - 20)

	setPos(self.BoneOffset.PosX)
	setPos(self.BoneOffset.PosY)
	setPos(self.BoneOffset.PosZ)

	self.BoneOffset.PosX:SetWide(width - 10)
	self.BoneOffset.PosY:SetWide(width - 10)
	self.BoneOffset.PosZ:SetWide(width - 10)

	setPos(self.BoneOffset.Pitch)
	setPos(self.BoneOffset.Yaw)
	setPos(self.BoneOffset.Roll)

	self.BoneOffset.Pitch:SetWide(width - 10)
	self.BoneOffset.Yaw:SetWide(width - 10)
	self.BoneOffset.Roll:SetWide(width - 10)

	self.BoneOffset.Selector.Label:SetWide(50)
	setPos(self.BoneOffset.Selector.Label)
	self.BoneOffset.Selector.Label:SetY(self.BoneOffset.Selector.Label:GetY() + 10)
	self.BoneOffset.Selector:SetPos(self.BoneOffset.Selector.Label:GetWide(), self.BoneOffset.Selector.Label:GetY())
	self.BoneOffset.Selector:SetWide(width - 120)

	self.BoneOffset.FilterNonPhys:SetPos(
		self.BoneOffset.Selector:GetX() + self.BoneOffset.Selector:GetWide() + 5,
		self.BoneOffset.Selector:GetY() + self.BoneOffset.Selector:GetTall() * 0.225
	)

	setPos(self.BoneOffset.Search)
	self.BoneOffset.Search:SetY(self.BoneOffset.Search:GetY() + 15)
	self.BoneOffset.Search:SetWide(width - 20)

	setPos(self.BoneOffset.SelectMirror)
	self.BoneOffset.SelectMirror:SetY(self.BoneOffset.SelectMirror:GetY() + 20)
	self.BoneOffset.SelectMirror:SetWide(width - 20)

	local setPos = setPosition(height - self.BoneOffset.ResetOffsets:GetTall() - 5, -25, 10)
	setPos(self.BoneOffset.ResetAllOffsets)
	setPos(self.BoneOffset.ResetOffsets)
	self.BoneOffset.ResetOffsets:SetWide(width - 20)
	self.BoneOffset.ResetAllOffsets:SetWide(width - 20)
end

function PANEL:RefreshBoneList()
	local filterNonPhys = self.BoneOffset.FilterNonPhys:GetChecked()

	self.bonesToOption = {}
	self.BoneOffset.Selector:Clear()
	if filterNonPhys then
		for i = 0, self.Entity:GetModelPhysBoneCount() - 1 do
			local b = self.Entity:TranslatePhysBoneToBone(i)
			local name = self.Entity:GetBoneName(b)
			print(b, name)
			if name == "__INVALIDBONE__" then
				continue
			end

			self.bonesToOption[b] = self.BoneOffset.Selector:AddChoice(name, b)
		end
	else
		for i = 0, self.Entity:GetBoneCount() - 1 do
			local name = self.Entity:GetBoneName(i)
			if name == "__INVALIDBONE__" then
				continue
			end
			if self.Entity:BoneHasFlag(i, 4) then
				continue
			end

			self.bonesToOption[i] = self.BoneOffset.Selector:AddChoice(name, i)
		end
	end
end

function PANEL:GetSelectedBone()
	local _, bone = self.BoneOffset.Selector:GetSelected()
	return bone
end

---@param entity Entity
function PANEL:SetEntity(entity)
	self.Entity = entity

	self.BoneOffset.PresetSaver:SetEntity(entity)
	self:RefreshBoneList()
end

function PANEL:SetVisible(visible)
	---@diagnostic disable-next-line
	self.BaseClass.SetVisible(self, visible)
end

function PANEL:Think()
	---@diagnostic disable-next-line
	self.BaseClass.Think(self)
end

vgui.Register("ragdollpuppeteer_poseoffsetter", PANEL, "DFrame")
