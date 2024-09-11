---@module "ragdollpuppeteer.smhTypes"
include("ragdollpuppeteer/smhTypes.lua")

local Vendor = {}

---https://github.com/Winded/RagdollMover/blob/a761e5618e9cba3440ad88d44ee1e89252d72826/lua/autorun/ragdollmover.lua#L209
---@param entity Entity
---@param bone integer
---@return integer
function Vendor.GetPhysBoneParent(entity, bone)
	local b = Vendor.PhysBoneToBone(entity, bone)
	local i = 1
	while true do
		b = entity:GetBoneParent(b)
		local parent = Vendor.BoneToPhysBone(entity, b)
		if parent >= 0 and parent ~= bone then
			return parent
		end
		i = i + 1
		if i > 256 then --We've gone through all possible bones, so we get out.
			break
		end
	end
	return -1
end

---@param ent Entity
---@param bone integer
---@return integer
function Vendor.PhysBoneToBone(ent, bone)
	return ent:TranslatePhysBoneToBone(bone)
end

---https://github.com/Winded/RagdollMover/blob/a761e5618e9cba3440ad88d44ee1e89252d72826/lua/autorun/ragdollmover.lua#L201
---@param ent Entity
---@param bone integer
---@return integer
function Vendor.BoneToPhysBone(ent, bone)
	for i = 0, ent:GetPhysicsObjectCount() - 1 do
		local b = ent:TranslatePhysBoneToBone(i)
		if bone == b then
			return i
		end
	end
	return -1
end

---https://github.com/Winded/StopMotionHelper/blob/2f0f80815a6f46c0ccd0606f27b3b054dae30b2d/lua/smh/server/easing.lua#L5
---@param s number | Vector
---@param e number | Vector
---@param p number
---@return number | Vector
function Vendor.LerpLinear(s, e, p)
	-- Internally, lerp uses the __add, __sub, and __mul metamethods, and these operations are defined
	-- for Vectors. We're casting here so we don't get any linting warnings.
	---@cast s number
	---@cast e number
	return Lerp(p, s, e)
end

---https://github.com/Winded/StopMotionHelper/blob/2f0f80815a6f46c0ccd0606f27b3b054dae30b2d/lua/smh/server/easing.lua#L11
---@param s Vector
---@param e Vector
---@param p number
---@return Vector
function Vendor.LerpLinearVector(s, e, p)
	return LerpVector(p, s, e)
end

---https://github.com/Winded/StopMotionHelper/blob/2f0f80815a6f46c0ccd0606f27b3b054dae30b2d/lua/smh/server/easing.lua#L17
---@param s Angle
---@param e Angle
---@param p number
---@return Angle
function Vendor.LerpLinearAngle(s, e, p)
	return LerpAngle(p, s, e)
end

---Find the closest keyframe corresponding to the frame of keyframes
---Source: https://github.com/Winded/StopMotionHelper/blob/bc94420283a978f3f56a282c5fe5cdf640d59855/lua/smh/server/keyframe_data.lua#L1
---Modified to directly work with json translation
---@param keyframes SMHFrameData[]
---@param frame integer
---@param ignoreCurrentFrame boolean
---@param modname SMHModifiers
---@return SMHFrameData?
---@return SMHFrameData?
---@return integer
function Vendor.getClosestKeyframes(keyframes, frame, ignoreCurrentFrame, modname)
	if ignoreCurrentFrame == nil then
		ignoreCurrentFrame = false
	end
	local prevKeyframe = nil
	local nextKeyframe = nil
	for _, keyframe in pairs(keyframes) do
		if keyframe.Position == frame and keyframe.Modifier == modname and not ignoreCurrentFrame then
			prevKeyframe = keyframe
			nextKeyframe = keyframe
			break
		end

		if
			keyframe.Position < frame
			and (not prevKeyframe or prevKeyframe.Position < keyframe.Position)
			and keyframe.Modifier == modname
		then
			prevKeyframe = keyframe
		elseif
			keyframe.Position > frame
			and (not nextKeyframe or nextKeyframe.Position > keyframe.Position)
			and keyframe.Modifier == modname
		then
			nextKeyframe = keyframe
		end
	end

	if not prevKeyframe and not nextKeyframe then
		return nil, nil, 0
	elseif not prevKeyframe then
		prevKeyframe = nextKeyframe
	elseif not nextKeyframe then
		nextKeyframe = prevKeyframe
	end

	---@cast prevKeyframe SMHFrameData
	---@cast nextKeyframe SMHFrameData

	local lerpMultiplier = 0
	if prevKeyframe.Position ~= nextKeyframe.Position then
		lerpMultiplier = (frame - prevKeyframe.Position) / (nextKeyframe.Position - prevKeyframe.Position)
		lerpMultiplier = math.EaseInOut(lerpMultiplier, prevKeyframe.EaseOut, nextKeyframe.EaseIn)
	end
	return prevKeyframe, nextKeyframe, lerpMultiplier
end

return Vendor
