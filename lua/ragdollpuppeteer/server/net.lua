--- Network strings

util.AddNetworkString("rp_onFrameChange")
util.AddNetworkString("rp_onSequenceChange")
util.AddNetworkString("rp_onFrameNext")
util.AddNetworkString("rp_onFramePrevious")
util.AddNetworkString("rp_onFPSChange")
util.AddNetworkString("rp_onPuppeteerPlayback")
util.AddNetworkString("rp_onPuppeteerChange")
util.AddNetworkString("rp_onPuppeteerChangeRequest")
util.AddNetworkString("rp_rp_removeClientPuppeteer")
util.AddNetworkString("rp_queryNonPhysBonePoseOfPuppet")
util.AddNetworkString("rp_queryBoneRefresh")
util.AddNetworkString("rp_onPoseParamChange")
util.AddNetworkString("rp_onBoneFilterChange")
util.AddNetworkString("rp_enablePuppeteerPlayback")
util.AddNetworkString("rp_disablePuppeteerPlayback")

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
