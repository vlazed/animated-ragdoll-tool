-- The directory to write to, relative to data
local ROOT = "ragdollpuppeteer/bones"
-- How many folder levels to look through for bone definitions
local MAX_RECURSE_LEVEL = 1

---@class BoneMapper
---@field definitions BoneDefinition[]
local bones = {
	definitions = {},
	physMaps = {},
}

---@param definitionFile string
local function readDefinition(definitionFile)
	file.AsyncRead(definitionFile, "DATA", function(_, _, status, data)
		if status == FSASYNC_OK then
			---@type BoneDefinition
			local kv = {}
			---@type string[]
			local tab = string.Split(data, "\n")
			for _, str in ipairs(tab) do
				local d = string.Split(str, ",")
				if d[1] and d[2] then
					kv[string.Trim(d[1])] = string.Trim(d[2])
				end
			end

			table.insert(bones.definitions, kv)
			table.insert(bones.definitions, table.Flip(kv))
		end
	end)
end

local function restoreDirectory()
	if file.Exists(ROOT, "DATA") then
		return
	end

	local dataStatic = "data_static/" .. ROOT
	---@param files string[]
	---@param directory string?
	local function writePath(files, directory)
		directory = directory or ""
		for _, filePath in ipairs(files) do
			local fileDirectory = ROOT .. "/" .. directory .. "/"
			local path = fileDirectory .. filePath
			local staticPath = dataStatic .. "/" .. directory .. "/" .. filePath
			if not file.Exists(fileDirectory, "DATA") then
				file.CreateDir(fileDirectory)
			end
			file.Write(path, file.Read(staticPath, "GAME") or "")
		end
	end

	file.CreateDir(ROOT)
	---@param files string[]
	---@param folders string[]
	---@param directory string?
	local function recurseFolders(files, folders, directory)
		directory = directory or ""
		if files then
			writePath(files, directory)
		end
		if #folders > 0 then
			for _, folder in ipairs(folders) do
				local path = dataStatic .. "/" .. folder .. "/*"
				local subfiles, subfolders = file.Find(path, "GAME")
				if subfiles or subfolders then
					recurseFolders(subfiles, subfolders, folder)
				end
			end
		end
	end

	local files, folders = file.Find(dataStatic .. "/*", "GAME")
	if files and folders then
		recurseFolders(files, folders)
	end

	print("Ragdoll Puppeteer: Restored bones directory in data folder")
end

---@param dir string
---@param level integer
local function refreshBoneDefinitions(dir, level)
	bones.definitions = {}

	restoreDirectory()

	---@type string[], string[]
	local definitions, folders = file.Find(dir .. "/*", "DATA")
	if definitions then
		for _, definitionFile in ipairs(definitions) do
			if definitionFile == "readme.txt" then
				continue
			end
			readDefinition(dir .. "/" .. definitionFile)
		end
	end

	if folders and level < MAX_RECURSE_LEVEL then
		for _, folder in ipairs(folders) do
			refreshBoneDefinitions(dir .. "/" .. folder, level + 1)
		end
	end
end

if SERVER then
	net.Receive("queryBoneRefresh", function(len, ply)
		local fail = net.ReadString()
		if not game.SinglePlayer() then
			-- Check if player has permissions
			CAMI.PlayerHasAccess(ply, "ragdollpuppeteer_refreshbones", function(hasAccess, reason)
				if hasAccess then
					refreshBoneDefinitions(ROOT, 0)
				else
					print(Format(fail, ply:Nick(), reason))
				end
			end)
		else
			refreshBoneDefinitions(ROOT, 0)
		end
	end)
else
	net.Receive("queryBoneRefresh", function()
		print("Refreshing")
		refreshBoneDefinitions(ROOT, 0)
	end)
end

refreshBoneDefinitions(ROOT, 0)

concommand.Add("ragdollpuppeteer_refreshbones", function(ply)
	if CLIENT then
		local fail = language.GetPhrase("ui.ragdollpuppeteer.refreshbones.failure")
		net.Start("queryBoneRefresh")
		net.WriteString(fail)
		net.SendToServer()
	else
		net.Start("queryBoneRefresh")
		net.Broadcast()
	end
	refreshBoneDefinitions(ROOT, 0)
end)

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
function bones.getMap(from, to)
	for _, definition in ipairs(bones.definitions) do
		if definition[from] == to then
			return definition
		end
	end
end

return bones
