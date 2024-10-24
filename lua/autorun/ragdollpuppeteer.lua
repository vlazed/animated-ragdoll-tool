if SERVER then
	resource.AddSingleFile("materials/ragdollpuppeteer/invisible.vtf")
	resource.AddSingleFile("materials/ragdollpuppeteer/puppeteer_invisible.vmt")
	resource.AddSingleFile("materials/ragdollpuppeteer/puppeteer_ignorez.vmt")
	resource.AddSingleFile("materials/ragdollpuppeteer/puppeteer.vmt")

	resource.AddSingleFile("resource/localization/en/ragdollpuppeteer_tool.properties")
	resource.AddSingleFile("resource/localization/en/ragdollpuppeteer_ui.properties")

	include("ragdollpuppeteer/server/net.lua")
	include("ragdollpuppeteer/server/concommands.lua")

	AddCSLuaFile("ragdollpuppeteer/constants.lua")
	AddCSLuaFile("ragdollpuppeteer/lib/vendor.lua")
	AddCSLuaFile("ragdollpuppeteer/lib/smh.lua")
	AddCSLuaFile("ragdollpuppeteer/lib/quaternion.lua")
	AddCSLuaFile("ragdollpuppeteer/lib/helpers.lua")
	AddCSLuaFile("ragdollpuppeteer/client/components.lua")
	AddCSLuaFile("ragdollpuppeteer/client/ui.lua")

	---@type RagdollPuppeteerPlayerField[]
	RAGDOLLPUPPETEER_PLAYERS = RAGDOLLPUPPETEER_PLAYERS or {}

	---@param userId integer
	local function addPlayerField(userId)
		local player = Player(userId)
		RAGDOLLPUPPETEER_PLAYERS[userId] = {
			player = player,
			puppet = NULL,
			puppeteer = NULL,
			physicsCount = 0,
			currentIndex = 0,
			cycle = 0,
			fps = 30,
			filteredBones = {},
			bonesReset = false,
			floor = NULL,
			lastPose = {},
			poseParams = {},
			playbackEnabled = false,
			physBones = {},
		}
	end

	---On player disconnect, remove any floors or puppeteers
	---@param userId integer
	local function cleanupPlayerField(userId)
		local playerData = RAGDOLLPUPPETEER_PLAYERS[userId]
		if not playerData then
			return
		end

		if IsValid(playerData.puppeteer) then
			playerData.puppeteer:Remove()
		end
		if IsValid(playerData.floor) then
			playerData.floor:Remove()
		end

		RAGDOLLPUPPETEER_PLAYERS[userId] = nil
	end

	gameevent.Listen("player_connect")
	hook.Add("player_connect", "ragdollpuppeteer_PlayerConnect", function(data)
		local userId = data.userid
		addPlayerField(userId)
	end)

	gameevent.Listen("player_disconnect")
	hook.Add("player_disconnect", "ragdollpuppeteer_PlayerDisconnect", function(data)
		local userId = data.userid
		cleanupPlayerField(userId)
	end)

	---@type Player[]
	local players = player.GetHumans()
	for _, player in ipairs(players) do
		addPlayerField(player:UserID())
	end
end
