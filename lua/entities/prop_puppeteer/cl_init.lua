include("shared.lua")

---@type Entity
local ENT = ENT

function ENT:DrawTranslucent()
	self:DrawModel()
end

---@source https://github.com/NO-LOAFING/AnimpropOverhaul/blob/cb75a0bbceefcd194f093d0ad211040c69b018e8/lua/entities/prop_animated.lua#L2935
function ENT:FireAnimationEvent(pos, ang, event, name)
	if
		event == 15
		or event == 5004
		or event == 6004
		or event == 6005
		or event == 6006
		or event == 6007
		or event == 6008
		or event == 6009
		or event == 32
	then
		return true
	end
end
