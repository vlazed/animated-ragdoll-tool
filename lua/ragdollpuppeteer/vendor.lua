local Vendor = {}

-- https://github.com/Winded/RagdollMover/blob/master/lua/autorun/ragdollmover.lua
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

function Vendor.PhysBoneToBone(ent, bone)
	return ent:TranslatePhysBoneToBone(bone)
end

function Vendor.BoneToPhysBone(ent, bone)
	for i = 0, ent:GetPhysicsObjectCount() - 1 do
		local b = ent:TranslatePhysBoneToBone(i)
		if bone == b then
			return i
		end
	end
	return -1
end

-- https://github.com/Winded/StopMotionHelper/blob/master/lua/smh/server/easing.lua
function Vendor.LerpLinear(s, e, p)
	return Lerp(p, s, e)
end

function Vendor.LerpLinearVector(s, e, p)
	return LerpVector(p, s, e)
end

function Vendor.LerpLinearAngle(s, e, p)
	return LerpAngle(p, s, e)
end

-- https://github.com/Winded/StopMotionHelper/blob/master/lua/smh/server/keyframe_data.lua
-- Modified to directly work with json translation
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

	local lerpMultiplier = 0
	if prevKeyframe.Position ~= nextKeyframe.Position then
		lerpMultiplier = (frame - prevKeyframe.Position) / (nextKeyframe.Position - prevKeyframe.Position)
		lerpMultiplier = math.EaseInOut(lerpMultiplier, prevKeyframe.EaseOut, nextKeyframe.EaseIn)
	end
	return prevKeyframe, nextKeyframe, lerpMultiplier
end

return Vendor
