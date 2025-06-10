if SERVER then
	-- Some addons (which ones?) override the Player function to a string type.
	-- This just overrides the function with a slower version if this happens.
	local Player = isfunction(Player) and Player
		or function(userId)
			for _, player in player.Iterator() do
				if player:UserID() == userId then
					return player
				end
			end
		end

	resource.AddWorkshop("3333911060")

	include("sh_cami.lua")
	include("ragdollpuppeteer/server/net.lua")
	include("ragdollpuppeteer/server/concommands.lua")

	-- TODO: Automate in a for loop
	AddCSLuaFile("ragdollpuppeteer/constants.lua")

	AddCSLuaFile("ragdollpuppeteer/lib/leakybucket.lua")
	AddCSLuaFile("ragdollpuppeteer/lib/fzy.lua")
	AddCSLuaFile("ragdollpuppeteer/lib/vendor.lua")
	AddCSLuaFile("ragdollpuppeteer/lib/bones.lua")
	AddCSLuaFile("ragdollpuppeteer/lib/smh.lua")
	AddCSLuaFile("ragdollpuppeteer/lib/quaternion.lua")
	AddCSLuaFile("ragdollpuppeteer/lib/helpers.lua")
	AddCSLuaFile("ragdollpuppeteer/lib/pose.lua")

	AddCSLuaFile("ragdollpuppeteer/client/components.lua")
	AddCSLuaFile("ragdollpuppeteer/client/ui.lua")
	AddCSLuaFile("ragdollpuppeteer/client/derma/poseoffsetter.lua")
	AddCSLuaFile("ragdollpuppeteer/client/derma/presetsaver.lua")

	---@type CAMI_PRIVILEGE
	local refreshBonesPrivilage = {
		Name = "ragdollpuppeteer_canrefresh",
		MinAccess = "superadmin",
		Description = "Whether the user can refresh bones in a multiplayer server. Defaults to `superadmin`",
		HasAccess = nil,
	}
	CAMI.RegisterPrivilege(refreshBonesPrivilage)

	---@module "ragdollpuppeteer.lib.leakybucket"
	local leakyBucket = include("ragdollpuppeteer/lib/leakybucket.lua")
	---@module "ragdollpuppeteer.constants"
	local constants = include("ragdollpuppeteer/constants.lua")

	local MAX_MODELS = constants.MAX_MODELS
	local MODEL_DEQUE_RATE = constants.MODEL_DEQUE_RATE

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
			bucket = leakyBucket(MAX_MODELS, MODEL_DEQUE_RATE),
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

	gameevent.Listen("player_activate")
	hook.Add("player_activate", "ragdollpuppeteer_PlayerConnect", function(data)
		addPlayerField(data.userid)
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
