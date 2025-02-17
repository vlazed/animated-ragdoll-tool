include("presetsaver.lua")

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

	self.BoneOffset.PresetSaver.OnLoadPreset = function(_, preset, name)
		if preset.model == self.Entity:GetModel() then
			for bone, preset in pairs(preset.offsets) do
				self:OnTransformChange(bone, preset.pos, preset.ang)
			end
			self.BoneOffset.SaveEntry:SetValue(name)
		else
			self:OnSaveFailure("Expected " .. preset.model)
		end
	end

	self.BoneOffset.PresetSaver.OnSavePreset = function()
		return self:OnSavePreset()
	end

	self.BoneOffset.PresetSaver.OnSaveFailure = function(_, msg)
		return self:OnSaveFailure(msg)
	end

	self.BoneOffset.PresetSaver.OnSaveSuccess = function(_, msg)
		return self:OnSaveSuccess(msg)
	end

	self.BoneOffset.SaveEntry.OnValueChange = function(_, str)
		self.BoneOffset.PresetSaver:SetSaveName(str)
	end

	self.BoneOffset.Pitch = numSlider("Pitch", -180, 180, self.BoneOffset)
	self.BoneOffset.Yaw = numSlider("Yaw", -180, 180, self.BoneOffset)
	self.BoneOffset.Roll = numSlider("Roll", -180, 180, self.BoneOffset)

	self.BoneOffset.PosX = numSlider("X", -100, 100, self.BoneOffset)
	self.BoneOffset.PosY = numSlider("Y", -100, 100, self.BoneOffset)
	self.BoneOffset.PosZ = numSlider("Z", -100, 100, self.BoneOffset)

	self.BoneOffset.Selector = vgui.Create("DComboBox", self.BoneOffset)
	self.BoneOffset.Selector.Label = vgui.Create("DLabel", self.BoneOffset)
	self.BoneOffset.Selector.Label:SetText("Bone:")
	self.BoneOffset.Selector.Label:SetDark(true)

	self.BoneOffset.Selector.OnSelect = function(pnl, _, _, i)
		self:OnBoneSelect(i)
	end

	self.Entity = NULL
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
	local _, bone = self.BoneOffset.Selector:GetSelected()

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

	self.BoneOffset:Dock(FILL)

	self.BoneOffset.PresetSaver:SetPos(5, 10)
	self.BoneOffset.PresetSaver:SetSize(width - 20, 50)

	local setPos = setPosition(60, 25)
	setPos(self.BoneOffset.SaveEntry)
	self.BoneOffset.SaveEntry:SetWide(width - 20)

	setPos(self.BoneOffset.PosX)
	setPos(self.BoneOffset.PosY)
	setPos(self.BoneOffset.PosZ)

	self.BoneOffset.PosX:SetWide(width)
	self.BoneOffset.PosY:SetWide(width)
	self.BoneOffset.PosZ:SetWide(width)

	setPos(self.BoneOffset.Pitch)
	setPos(self.BoneOffset.Yaw)
	setPos(self.BoneOffset.Roll)

	self.BoneOffset.Pitch:SetWide(width)
	self.BoneOffset.Yaw:SetWide(width)
	self.BoneOffset.Roll:SetWide(width)

	self.BoneOffset.Selector.Label:SetWide(50)
	setPos(self.BoneOffset.Selector.Label)
	self.BoneOffset.Selector.Label:SetY(self.BoneOffset.Selector.Label:GetY() + 10)
	self.BoneOffset.Selector:SetPos(self.BoneOffset.Selector.Label:GetWide() + 5, self.BoneOffset.Selector.Label:GetY())
	self.BoneOffset.Selector:SetWide(width - 20)
end

function PANEL:RefreshBoneList()
	self.BoneOffset.Selector:Clear()
	for i = 0, self.Entity:GetBoneCount() - 1 do
		if self.Entity:GetBoneName(i) == "__INVALIDBONE__" then
			continue
		end
		if self.Entity:BoneHasFlag(i, 4) then
			continue
		end

		self.BoneOffset.Selector:AddChoice(self.Entity:GetBoneName(i), i)
	end
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
