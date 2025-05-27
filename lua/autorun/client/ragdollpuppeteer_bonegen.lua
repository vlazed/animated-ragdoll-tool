---@module "ragdollpuppeteer.lib.fzy"
local fzy = include("ragdollpuppeteer/lib/fzy.lua")

local ROOT = "ragdollpuppeteer/bones"

---@type BoneDefinition
local boneMap = {}

local function kvToCommaSeparatedList(tab)
	local s = ""

	for key, val in pairs(tab) do
		s = s .. key .. "," .. val .. "\n"
	end

	return s
end

---@param panel ControlPanel | DForm
local function buildUI(panel)
	local pl = LocalPlayer()

	---@param pnl DButton
	local function buttonCallback(pnl)
		---@type Entity
		pnl.entity = pl:GetEyeTrace().Entity

		if IsValid(pnl.entity) then
			pnl:SetText(pnl.entity:GetModel())
			pnl.bones = {}
			for i = 0, pnl.entity:GetBoneCount() - 1 do
				table.insert(pnl.bones, pnl.entity:GetBoneName(i))
			end
		end
	end

	panel:Help("#ui.ragdollpuppeteer.bonegen.help")
	local button1 = panel:Button("#ui.ragdollpuppeteer.bonegen.noragdoll", "")
	local button2 = panel:Button("#ui.ragdollpuppeteer.bonegen.noragdoll", "")

	button1.entity = NULL
	button1.bones = {}
	button2.entity = NULL
	button2.bones = {}

	button1.DoClick = buttonCallback
	button2.DoClick = buttonCallback
	local generate = panel:Button("#ui.ragdollpuppeteer.bonegen.generate", "")

	local category = vgui.Create("DForm", panel)
	category:SetLabel("Bone Map")
	panel:AddItem(category)
	panel:Dock(TOP)

	local fileName = panel:TextEntry("#ui.ragdollpuppeteer.bonegen.filename", "")

	local save = panel:Button("#ui.ragdollpuppeteer.bonegen.save", "")

	---@param map BoneDefinition
	local function refreshList(map)
		category:Clear()

		for key, val in pairs(map) do
			---@class ragdollpuppeteer_entry: DPanel
			local entry = vgui.Create("DPanel", category)
			category:AddItem(entry)
			entry:Dock(TOP)

			entry.remove = vgui.Create("DButton", entry)
			entry.remove:SetText("X")
			entry.remove:SetSize(10, 10)

			entry.key = vgui.Create("DTextEntry", entry)
			entry.val = vgui.Create("DTextEntry", entry)
			entry.key.old = key
			entry.val.old = val

			entry.key:SetText(key)
			entry.val:SetText(val)

			function entry.remove:DoClick()
				map[entry.key.old] = nil
				refreshList(map)
			end

			function entry.key:OnLoseFocus()
				local newVal = self:GetText()
				map[entry.key.old] = nil
				map[newVal] = entry.val.old
				entry.key.old = newVal
				hook.Call("OnTextEntryLoseFocus", nil, self)
			end

			function entry.key:GetAutoComplete(inp)
				local suggestions = {}
				local choices = button1.bones

				for _, result in ipairs(fzy.filter(inp, choices, false)) do
					table.insert(suggestions, choices[result[1]])
				end

				return suggestions
			end

			function entry.val:OnLoseFocus()
				local newVal = self:GetText()
				map[entry.key.old] = newVal
				entry.val.old = newVal
				hook.Call("OnTextEntryLoseFocus", nil, self)
			end

			function entry.val:GetAutoComplete(inp)
				local suggestions = {}
				local choices = button2.bones

				for _, result in ipairs(fzy.filter(inp, choices, false)) do
					table.insert(suggestions, choices[result[1]])
				end

				return suggestions
			end

			function entry:PerformLayout(w, h)
				self.remove:SetX(w - self.remove:GetWide())

				local xMargin = 30
				self.key:SetSize(w * 0.3, 20)
				self.key:SetPos(xMargin, h * 0.5 - self.key:GetTall() * 0.5)
				self.val:SetSize(w * 0.3, 20)
				self.val:SetPos(w - self.val:GetWide() - xMargin, h * 0.5 - self.key:GetTall() * 0.5)
			end
		end
	end

	function generate:DoClick()
		---@type Entity
		---@diagnostic disable-next-line: undefined-field
		local e1 = button1.entity
		---@type Entity
		---@diagnostic disable-next-line: undefined-field
		local e2 = button2.entity

		if IsValid(e1) and IsValid(e2) then
			boneMap = {}
			for i = 0, e1:GetBoneCount() - 1 do
				boneMap[e1:GetBoneName(i)] = e2:GetBoneName(i) or ""
			end

			refreshList(boneMap)
		end
	end

	function save:DoClick()
		local name = fileName:GetText()
		if #name == 0 then
			return
		end
		local path = ROOT .. "/" .. string.GetFileFromFilename(name) .. ".txt"
		local success = file.Write(path, kvToCommaSeparatedList(boneMap))
		if success then
			chat.AddText(Format("Ragdoll Puppeteer: Successfully saved a bone map to %s", path))
		end
	end
end

hook.Remove("PopulateToolMenu", "ragdollpuppeteer_bonegen")
hook.Add("PopulateToolMenu", "ragdollpuppeteer_bonegen", function()
	spawnmenu.AddToolMenuOption(
		"Utilities",
		"Ragdoll Puppeteer",
		"ragdollpuppeteer_bonegen",
		"Bone Map Generator",
		"",
		"",
		buildUI
	)
end)
