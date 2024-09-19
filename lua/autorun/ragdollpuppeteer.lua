if SERVER then
	include("ragdollpuppeteer/net.lua")

	AddCSLuaFile("ragdollpuppeteer/vendor.lua")
	AddCSLuaFile("ragdollpuppeteer/smh.lua")
	AddCSLuaFile("ragdollpuppeteer/ui.lua")

	---@type RagdollPuppeteerPlayerField[]
	RAGDOLLPUPPETEER_PLAYERS = {}

	gameevent.Listen("player_connect")
	hook.Add("player_connect", "ragdollpuppeteer_PlayerConnect", function(data)
		local userId = data.userid
		RAGDOLLPUPPETEER_PLAYERS[userId] = {
			player = Player(userId),
			puppet = NULL,
			puppeteer = NULL,
			physicsCount = 0,
			currentIndex = 0,
			cycle = 0,
			fps = 30,
		}
		print(userId, "connected!")
		PrintTable(RAGDOLLPUPPETEER_PLAYERS[userId])
	end)

	gameevent.Listen("player_disconnect")
	hook.Add("player_disconnect", "ragdollpuppeteer_PlayerDisconnect", function(data)
		local userId = data.userId
		timer.Remove("ragdollpuppeteer_playback_" .. tostring(userId))
		RAGDOLLPUPPETEER_PLAYERS[userId] = nil
		print(userId, "disconnected!")
		PrintTable(RAGDOLLPUPPETEER_PLAYERS[userId])
	end)

	resource.AddSingleFile("resource/localization/en/ragdollpuppeteer_tool.properties")
	resource.AddSingleFile("resource/localization/en/ragdollpuppeteer_ui.properties")
end
