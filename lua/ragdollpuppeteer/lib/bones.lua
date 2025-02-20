local directory = "ragdollpuppeteer/lib/bone_definitions"
local subdirectory = "bone_definitions/"

---@class BoneMapper
---@field definitions table<string, BoneDefinition>
local bones = {
	definitions = {},
	physMaps = {},
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

local function getRagdollFromEntity(ent)
	local ragdoll = ent
	if ent:GetClass() ~= "prop_ragdoll" then
		ragdoll = ents.Create("prop_ragdoll")
		ragdoll:SetModel(ent:GetModel())
		ragdoll:Spawn()
	end

	return ragdoll, function()
		if ent:GetClass() ~= "prop_ragdoll" then
			ragdoll:Remove()
		end
	end
end

---@param ent Entity
---@return table<integer, string>
local function getPhysicsObjectBoneNameMap(ent)
	local map = {}
	local ragdoll, cleanupRagdoll = getRagdollFromEntity(ent)

	for i = 0, ragdoll:GetPhysicsObjectCount() - 1 do
		local boneName = ragdoll:GetBoneName(ragdoll:TranslatePhysBoneToBone(i))
		map[i] = boneName
	end

	cleanupRagdoll()

	return map
end

---@param ent Entity
---@return table<string, integer>
local function getBoneNamePhysicsObjectMap(ent)
	local map = {}

	local ragdoll, cleanupRagdoll = getRagdollFromEntity(ent)
	for i = 0, ragdoll:GetPhysicsObjectCount() - 1 do
		local boneName = ragdoll:GetBoneName(ragdoll:TranslatePhysBoneToBone(i))
		map[boneName] = i
	end

	cleanupRagdoll()

	return map
end

---Get a mapping of `from` entity's physics object and `to` entity's physics object, which corresponds to a defined `boneMap`
---@param from Entity
---@param to Entity
---@param boneMap BoneDefinition? A bone mapping `from` entity and `to` entity. If this order is not established then the obtained physMap will be incorrect
---@return table<integer, integer>?
function bones.getPhysMap(from, to, boneMap)
	if not boneMap then
		return
	end

	local fromModel = from:GetModel()
	local toModel = to:GetModel()

	if fromModel == toModel then
		return
	end

	if bones.physMaps[fromModel .. toModel] then
		return bones.physMaps[fromModel .. toModel]
	end

	local map = {}

	local fromPhysObjToName, toNameToPhysObj = getPhysicsObjectBoneNameMap(from), getBoneNamePhysicsObjectMap(to)

	for i = 0, 31 do
		local fromName = fromPhysObjToName[i]
		local toName = boneMap[fromName]
		if toName then
			map[i] = toNameToPhysObj[toName]
		end
	end

	bones.physMaps[fromModel .. toModel] = map
	bones.physMaps[toModel .. fromModel] = table.Flip(map)

	return map
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
