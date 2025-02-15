--- Network strings

util.AddNetworkString("onFrameChange")
util.AddNetworkString("onSequenceChange")
util.AddNetworkString("onAngleChange")
util.AddNetworkString("onFrameNext")
util.AddNetworkString("onFramePrevious")
util.AddNetworkString("onFPSChange")
util.AddNetworkString("onPuppeteerPlayback")
util.AddNetworkString("onPuppeteerChange")
util.AddNetworkString("onPuppeteerChangeRequest")
util.AddNetworkString("updateClientPosition")
util.AddNetworkString("removeClientAnimPuppeteer")
util.AddNetworkString("queryDefaultBonePoseOfPuppet")
util.AddNetworkString("queryNonPhysBonePoseOfPuppet")
util.AddNetworkString("onPoseParamChange")
util.AddNetworkString("onBoneFilterChange")
util.AddNetworkString("queryPhysObjects")
util.AddNetworkString("enablePuppeteerPlayback")
util.AddNetworkString("disablePuppeteerPlayback")

hook.Remove("Think", "ragdollpuppeteer_leak_buckets")
hook.Add("Think", "ragdollpuppeteer_leak_buckets", function()
	-- Why do we have this? We're guarding against the possibility of the
	-- client spamming model requests to the server. If these model requests
	-- consist of valid models, the server will begin to precache all these models
	-- until the precached models count to 8192, which causes the server to crash.
	for _, player in ipairs(player.GetHumans()) do
		---@cast player Player
		local playerData = RAGDOLLPUPPETEER_PLAYERS[player:UserID()]
		if playerData and playerData.bucket then
			playerData.bucket()
		end
	end
end)
