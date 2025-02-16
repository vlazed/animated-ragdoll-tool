local directory = "ragdollpuppeteer/lib/bone_definitions"
local subdirectory = "bone_definitions/"

---@class BoneMapper
---@field definitions table<string, BoneDefinition>
local bones = {
	definitions = {},
}

if file.IsDir(directory, "LUA") then
	local definitions = file.Find(directory .. "/*.lua", "LUA")
	if definitions then
		for _, definitionFile in pairs(definitions) do
			local definition = include(subdirectory .. definitionFile)
			table.Merge(bones.definitions, definition)
		end
	end
end

---@param from string
---@param to string
---@return BoneDefinition?
---@return string?
function bones.getMap(from, to)
	for definitionName, definition in pairs(bones.definitions) do
		if definition[from] == to then
			return definition, definitionName
		end
	end
end

return bones
