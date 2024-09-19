local allowPlayback = CreateConVar(
	"sv_ragdollpuppeteer_allow_playback",
	"0",
	FCVAR_ARCHIVE + FCVAR_NOTIFY,
	"Allow +ragdollpuppeteer_playback to be called by players. (INCURS NET COST TO THE SERVER IF USED BY MULTIPLE PLAYERS!)",
	0,
	1
)

cvars.AddChangeCallback("sv_ragdollpuppeteer_allow_playback", function(_, _, newValue)
	newValue = tonumber(newValue)
	-- If we're set to false, we need to stop all playback timers
	if type(newValue) == "number" and newValue == 0 then
		---@type Player[]
		local players = player.GetHumans()
		for _, player in ipairs(players) do
			local userId = player:UserID()
			timer.Remove("ragdollpuppeteer_playback_" .. tostring(userId))
		end
	end
end)

concommand.Add("+ragdollpuppeteer_playback", function(ply, _, _)
	if
		not IsValid(ply)
		or not RAGDOLLPUPPETEER_PLAYERS[ply:UserID()]
		or not IsValid(RAGDOLLPUPPETEER_PLAYERS[ply:UserID()].puppet)
	then
		return
	end
	local playbackAllowed = allowPlayback:GetInt()

	if playbackAllowed <= 0 then
		print("+ragdollpuppeteer_playback is disabled in this server!")
		return
	end

	local userId = ply:UserID()
	local fps = RAGDOLLPUPPETEER_PLAYERS[userId].fps
	timer.Create("ragdollpuppeteer_playback_" .. tostring(userId), 1 / fps, -1, function()
		net.Start("onFrameNext")
		net.Send(ply)
	end)
end)

concommand.Add("-ragdollpuppeteer_playback", function(ply, _, _)
	if not IsValid(ply) then
		return
	end
	if not game.SinglePlayer() then
		return
	end

	local userId = ply:UserID()
	timer.Remove("ragdollpuppeteer_playback_" .. tostring(userId))
end)

concommand.Add("ragdollpuppeteer_previousframe", function(ply)
	net.Start("onFramePrevious")
	net.Send(ply)
end)

concommand.Add("ragdollpuppeteer_nextframe", function(ply)
	net.Start("onFrameNext")
	net.Send(ply)
end)
