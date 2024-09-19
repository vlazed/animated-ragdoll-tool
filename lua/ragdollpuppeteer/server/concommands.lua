concommand.Add("+ragdollpuppeteer_playback", function(ply, _, _)
	if
		not IsValid(ply)
		or not RAGDOLLPUPPETEER_PLAYERS[ply:UserID()]
		or not IsValid(RAGDOLLPUPPETEER_PLAYERS[ply:UserID()].puppet)
	then
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
