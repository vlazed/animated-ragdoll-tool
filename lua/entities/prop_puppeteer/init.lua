AddCSLuaFile("cl_init.lua")
AddCSLuaFile("shared.lua")

include("shared.lua")

---@type Entity
local ENT = ENT

function ENT:Initialize()
	self:DrawShadow(false)
end

---@source https://github.com/NO-LOAFING/AnimpropOverhaul/blob/cb75a0bbceefcd194f093d0ad211040c69b018e8/lua/entities/prop_animated.lua#L2918
function ENT:HandleAnimEvent(event, eventTime, cycle, type, options)
	if event == 25 or event == 35 or event == 1004 then
		return true
	end
end
