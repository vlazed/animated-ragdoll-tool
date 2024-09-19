if SERVER then
	resource.AddSingleFile("resource/localization/en/ragdollpuppeteer_tool.properties")
	resource.AddSingleFile("resource/localization/en/ragdollpuppeteer_ui.properties")

	include("ragdollpuppeteer/server/net.lua")
	include("ragdollpuppeteer/server/concommands.lua")

	AddCSLuaFile("ragdollpuppeteer/vendor.lua")
	AddCSLuaFile("ragdollpuppeteer/smh.lua")
	AddCSLuaFile("ragdollpuppeteer/client/ui.lua")

	---@type RagdollPuppeteerPlayerField[]
	RAGDOLLPUPPETEER_PLAYERS = {}

	---comment
	---@param userId integer
	local function addPlayerField(userId)
		RAGDOLLPUPPETEER_PLAYERS[userId] = {
			player = Player(userId),
			puppet = NULL,
			puppeteer = NULL,
			physicsCount = 0,
			currentIndex = 0,
			cycle = 0,
			fps = 30,
		}
	end

	gameevent.Listen("player_connect")
	hook.Add("player_connect", "ragdollpuppeteer_PlayerConnect", function(data)
		local userId = data.userid
		addPlayerField(userId)
	end)

	gameevent.Listen("player_disconnect")
	hook.Add("player_disconnect", "ragdollpuppeteer_PlayerDisconnect", function(data)
		local userId = data.userid
		timer.Remove("ragdollpuppeteer_playback_" .. tostring(userId))
		RAGDOLLPUPPETEER_PLAYERS[userId] = nil
		print(userId, "disconnected!")
	end)

	---@type Player[]
	local players = player.GetHumans()
	for _, player in ipairs(players) do
		addPlayerField(player:UserID())
	end
end
