local directory = "ragdollpuppeteer/lib/bone_definitions"
local subdirectory = "bone_definitions/"

---@type table<string, BoneDefinition>
local bones = {}

if file.IsDir(directory, "LUA") then
	local definitions = file.Find(directory .. "/*.lua", "LUA")
	if definitions then
		for _, definitionFile in pairs(definitions) do
			local definition = include(subdirectory .. definitionFile)
			table.Merge(bones, definition)
		end
	end
end

return bones
