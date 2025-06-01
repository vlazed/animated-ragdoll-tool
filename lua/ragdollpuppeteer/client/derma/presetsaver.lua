---Saves bone presets for a specific model and tries to load them if they are suspected to match the model's skeleton
---@source https://github.com/Winded/RagdollMover/blob/2c9c5a9417effc618e4530ce98f9b69f3ad817fe/lua/weapons/gmod_tool/stools/ragmover_ikchains.lua#L402
---@class ragdollpuppeteer_presetsaver: DPanel
local PANEL = {}

function PANEL:Init()
	self.selector = vgui.Create("DComboBox", self)
	self.entity = NULL

	self.save = vgui.Create("DButton", self)
	self.save:SetText("Save")
	self.save.DoClick = function()
		self:SavePreset()
	end

	self.load = vgui.Create("DButton", self)
	self.load:SetText("Load")
	self.load.DoClick = function()
		self:LoadPreset()
	end

	self.refresh = vgui.Create("DImageButton", self)
	self.refresh:SetImage("icon16/arrow_refresh.png")
	self.refresh.DoClick = function()
		self:RefreshDirectory()
	end

	self.name = ""

	self.loadJSON = true
	self:SetTall(45)
end

---@param state boolean
function PANEL:SetLoadJSON(state)
	self.loadJSON = state
end

function PANEL:SetData(newData)
	self.data = newData
end

function PANEL:OnSavePreset()
	return {}
end

function PANEL:SaveCondition()
	local condition = IsValid(self.entity)
	return condition, not condition and "No entity selected"
end

function PANEL:OnSaveSuccess() end

---@param msg string
function PANEL:OnSaveFailure(msg) end

function PANEL:SaveFunction(data)
	local json = util.TableToJSON(data, true)
	if not file.Exists(self.directory, "DATA") then
		file.CreateDir(self.directory)
	end

	local name = self.name
	if file.Exists(self.directory .. "/" .. name .. ".txt", "DATA") then
		local exists = true
		local count = 1

		while exists do
			local newname = name .. count

			if not file.Exists(self.directory .. "/" .. newname .. ".txt", "DATA") then
				name = newname
				exists = false
			end

			count = count + 1
		end
	end

	local success = file.Write(self.directory .. "/" .. name .. ".txt", json)
	if not success then
		self:OnSaveFailure("Failed to write preset")
		return
	end
end

function PANEL:EmptyCheck(data)
	return next(data)
end

function PANEL:SavePreset()
	local condition, reason = self:SaveCondition()
	if not condition then
		---@cast reason string
		self:OnSaveFailure(reason)
		return
	end
	local data = self:OnSavePreset()
	if not self:EmptyCheck(data) then
		self:OnSaveFailure("Empty data")
		return
	end
	if not self.name then
		self:OnSaveFailure("Empty save name")
		return
	end

	self:SaveFunction(data)

	self:AddChoice(self.name)

	self:RefreshDirectory()
end

---@param preset PoseOffsetPreset|string
---@param name string
function PANEL:OnLoadPreset(preset, name) end

---@param reason string
function PANEL:OnLoadFail(reason) end

function PANEL:LoadPreset()
	local name, filePath = self.selector:GetSelected()
	if not name then
		return self:OnLoadFail("Empty filename")
	end
	if not file.Exists(self.directory, "DATA") or not file.Exists(filePath, "DATA") then
		return self:OnLoadFail("File path does not exist: " .. filePath)
	end

	local json = file.Read(filePath, "DATA")
	if self.loadJSON then
		local preset = util.JSONToTable(json)
		if preset then
			self:OnLoadPreset(preset, name)
		else
			self:OnLoadFail("Failed to read JSON file")
		end
	else
		self:OnLoadPreset(json, name)
	end
end

function PANEL:SetSaveName(name)
	self.name = name
end

function PANEL:PerformLayout()
	self.selector:SetPos(0, 0)
	self.selector:SetSize(self:GetWide() - 20, 20)
	self.refresh:SetPos(self:GetWide() - 20, 0)
	self.refresh:SetSize(20, 20)

	self.save:SetPos(0, 25)
	self.save:SetSize(self:GetWide() / 2 - 20, 20)

	self.load:SetPos(self:GetWide() / 2 + 20, 25)
	self.load:SetSize(self:GetWide() / 2 - 20, 20)
end

function PANEL:AddChoice(option)
	self.selector:AddChoice(option)
end

---@param newEntity Entity
function PANEL:SetEntity(newEntity)
	self.entity = newEntity
end

function PANEL:SetDirectory(newDirectory)
	self.directory = newDirectory
end

---@param fileName string
---@return boolean
function PANEL:RefreshFilter(fileName)
	return true
end

---@package
---@param dir string
---@param list string[]
---@return {[1]: string, [2]: string}[]
function PANEL:recurseDirectory(dir, list)
	local files, folders = file.Find(dir .. "/*", "DATA")
	---@cast files string[]
	---@cast folders string[]
	for _, f in ipairs(files or {}) do
		if string.GetExtensionFromFilename(f) == "txt" and self:RefreshFilter(f) then
			table.insert(list, { f, dir .. "/" .. f })
		end
	end
	if folders and #folders > 0 then
		for _, folder in ipairs(folders) do
			self:recurseDirectory(dir .. "/" .. folder, list)
		end
	end
	return list
end

function PANEL:RefreshDirectory()
	if not file.Exists(self.directory, "DATA") then
		file.CreateDir(self.directory)
	end
	self.selector:Clear()

	local files = self:recurseDirectory(self.directory, {})
	for _, fileInfo in ipairs(files) do
		self.selector:AddChoice(string.sub(fileInfo[1], 1, -5), fileInfo[2])
	end
end

vgui.Register("ragdollpuppeteer_presetsaver", PANEL, "DPanel")
