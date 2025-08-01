local allowPlayback = CreateConVar(
	"sv_ragdollpuppeteer_allow_playback",
	"1",
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
			net.Start("rp_disablePuppeteerPlayback")
			net.Send(player)
		end
	end
end)

concommand.Add("ragdollpuppeteer_recoverpuppeteer", function(ply, _, _)
	if
		not IsValid(ply)
		or not RAGDOLLPUPPETEER_PLAYERS[ply:UserID()]
		or not IsValid(RAGDOLLPUPPETEER_PLAYERS[ply:UserID()].puppet)
		or not IsValid(RAGDOLLPUPPETEER_PLAYERS[ply:UserID()].floor)
	then
		return
	end
	local puppet = RAGDOLLPUPPETEER_PLAYERS[ply:UserID()].puppet
	local floor = RAGDOLLPUPPETEER_PLAYERS[ply:UserID()].floor

	local angle = (ply:GetPos() - floor:GetPos()):Angle()
	floor:SetPos(puppet:GetPos())
	floor:SetAngles(angle)
	local physObject = floor:GetPhysicsObject()
	if IsValid(physObject) then
		physObject:Sleep()
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
		print("[Ragdoll Puppeteer] " .. language.GetPhrase("ui.ragdollpuppeteer.notify.playbackdisabled1"))
		if game.SinglePlayer() then
			print("[Ragdoll Puppeteer] " .. language.GetPhrase("ui.ragdollpuppeteer.notify.playbackdisabled2"))
		end
		return
	end

	local userId = ply:UserID()
	local fps = RAGDOLLPUPPETEER_PLAYERS[userId].fps
	net.Start("rp_enablePuppeteerPlayback")
	net.WriteFloat(fps)
	net.Send(ply)
end)

concommand.Add("-ragdollpuppeteer_playback", function(ply, _, _)
	if not IsValid(ply) then
		return
	end

	net.Start("rp_disablePuppeteerPlayback")
	net.Send(ply)
end)

concommand.Add("ragdollpuppeteer_previousframe", function(ply, _, args)
	local increment = 1
	local newNumber = tonumber(args[1])
	if args and type(newNumber) == "number" then
		increment = newNumber
	end
	net.Start("rp_onFramePrevious")
	net.WriteFloat(increment)
	net.Send(ply)
end)

concommand.Add("ragdollpuppeteer_nextframe", function(ply, _, args)
	local increment = 1
	local newNumber = tonumber(args[1])
	if args and type(newNumber) == "number" then
		increment = newNumber
	end
	net.Start("rp_onFrameNext")
	net.WriteFloat(increment)
	net.Send(ply)
end)
