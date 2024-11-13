--- General vendor functions from Ragdoll Mover and Stop Motion Helper

local Vendor = {}

---https://github.com/Winded/RagdollMover/blob/a761e5618e9cba3440ad88d44ee1e89252d72826/lua/autorun/ragdollmover.lua#L209
---@param entity Entity Entity to obtain bone information
---@param physBone integer Physics object id
---@return integer parent Physics object parent of physBone
function Vendor.GetPhysBoneParent(entity, physBone)
	local b = Vendor.PhysBoneToBone(entity, physBone)
	local i = 1
	while true do
		b = entity:GetBoneParent(b)
		local parent = Vendor.BoneToPhysBone(entity, b)
		if parent >= 0 and parent ~= physBone then
			return parent
		end
		i = i + 1
		if i > 256 then --We've gone through all possible bones, so we get out.
			break
		end
	end
	return -1
end

---Calculate the bone offsets with respect to the parent
---Source: https://github.com/NO-LOAFING/AnimpropOverhaul/blob/a3a6268a5d57655611a8b8ed43dcf43051ecd93a/lua/entities/prop_animated.lua#L1889
---@param puppeteer Entity Entity to obtain bone information
---@param child integer Child bone index
---@param defaultBonePose DefaultBonePoseArray Array of position and angles denoting the reference bone pose
---@return Vector positionOffset Position of child bone with respect to parent bone
---@return Angle angleOffset Angle of child bone with respect to parent bone
function Vendor.getBoneOffsetsOf(puppeteer, child, defaultBonePose)
	local parent = puppeteer:GetBoneParent(child)
	---@type VMatrix
	local cMatrix = puppeteer:GetBoneMatrix(child)
	---@type VMatrix
	local pMatrix = puppeteer:GetBoneMatrix(parent)

	if not cMatrix or not pMatrix or not defaultBonePose or #defaultBonePose == 0 then
		return vector_origin, angle_zero
	end

	local fPos, fAng =
		WorldToLocal(cMatrix:GetTranslation(), cMatrix:GetAngles(), pMatrix:GetTranslation(), pMatrix:GetAngles())
	local dPos = fPos - defaultBonePose[child + 1][3]

	local m = Matrix()
	m:Translate(defaultBonePose[parent + 1][1])
	m:Rotate(defaultBonePose[parent + 1][2])
	m:Rotate(fAng)

	local _, dAng =
		WorldToLocal(m:GetTranslation(), m:GetAngles(), defaultBonePose[child + 1][1], defaultBonePose[child + 1][2])

	return dPos, dAng
end

---@param ent Entity Entity to translate physics bone
---@param physBone integer Physics object id
---@return integer bone Translated bone id
function Vendor.PhysBoneToBone(ent, physBone)
	return ent:TranslatePhysBoneToBone(physBone)
end

---Get the pose of every bone of the entity, for nonphysical bone matching
---Source: https://github.com/NO-LOAFING/AnimpropOverhaul/blob/a3a6268a5d57655611a8b8ed43dcf43051ecd93a/lua/entities/prop_animated.lua#L3550
---@param ent Entity Entity in reference pose
---@return DefaultBonePoseArray defaultPose Array consisting of a bones offsets from the entity, and offsets from its parent bones
function Vendor.getDefaultBonePoseOf(ent)
	local defaultPose = {}
	local entPos = ent:GetPos()
	local entAngles = ent:GetAngles()
	for b = 0, ent:GetBoneCount() - 1 do
		local parent = ent:GetBoneParent(b)
		local bMatrix = ent:GetBoneMatrix(b)
		if bMatrix then
			local pos1, ang1 = WorldToLocal(bMatrix:GetTranslation(), bMatrix:GetAngles(), entPos, entAngles)
			local pos2, ang2 = pos1 * 1, ang1 * 1
			if parent > -1 then
				local pMatrix = ent:GetBoneMatrix(parent)
				pos2, ang2 = WorldToLocal(
					bMatrix:GetTranslation(),
					bMatrix:GetAngles(),
					pMatrix:GetTranslation(),
					pMatrix:GetAngles()
				)
			end

			defaultPose[b + 1] = { pos1, ang1, pos2, ang2 }
		else
			defaultPose[b + 1] = { vector_origin, angle_zero, vector_origin, angle_zero }
		end
	end
	return defaultPose
end

---https://github.com/Winded/RagdollMover/blob/a761e5618e9cba3440ad88d44ee1e89252d72826/lua/autorun/ragdollmover.lua#L201
---@param ent Entity Entity to translate bone
---@param bone integer Bone id
---@return integer physBone Physics object id
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
---@param s number | Vector Start number or vector
---@param e number | Vector End number or vector
---@param p number Percentage between start and end, between 0 and 1
---@return number | Vector lerped Interpolated number or vector
function Vendor.LerpLinear(s, e, p)
	-- Internally, lerp uses the __add, __sub, and __mul metamethods, and these operations are defined
	-- for Vectors. We're casting here so we don't get any linting warnings.
	---@cast s number
	---@cast e number
	return Lerp(p, s, e)
end

---https://github.com/Winded/StopMotionHelper/blob/2f0f80815a6f46c0ccd0606f27b3b054dae30b2d/lua/smh/server/easing.lua#L11
---@param s Vector Start vector
---@param e Vector End vector
---@param p number Percentage between start and end, between 0 and 1
---@return Vector lerpedVector Interpolated vector
function Vendor.LerpLinearVector(s, e, p)
	return LerpVector(p, s, e)
end

---https://github.com/Winded/StopMotionHelper/blob/2f0f80815a6f46c0ccd0606f27b3b054dae30b2d/lua/smh/server/easing.lua#L17
---@param s Angle Start angle
---@param e Angle End angle
---@param p number Percentage between start and end, between 0 and 1
---@return Angle lerpedAngle Interpolated angle
function Vendor.LerpLinearAngle(s, e, p)
	return LerpAngle(p, s, e)
end

---Find the closest keyframe corresponding to the frame of keyframes
---Source: https://github.com/Winded/StopMotionHelper/blob/bc94420283a978f3f56a282c5fe5cdf640d59855/lua/smh/server/keyframe_data.lua#L1
---Modified to directly work with json translation
---Supports SMH saves to at most version 4.0 (4.0 introduced save file changes to improve playback performance)
---@param keyframes SMHFrameData[] SMH Keyframe data
---@param frame integer Target keyframe
---@param ignoreCurrentFrame boolean Whether to consider the previous and next keyframes
---@param modname SMHModifiers SMH Modifier name
---@return SMHFrameData? previousKeyframe Previous keyframe near frame
---@return SMHFrameData? nextKeyframe Next keyframe near frame
---@return integer lerpMultiplier Percentage between previous keyframe and next keyframe
function Vendor.getClosestKeyframes(keyframes, frame, ignoreCurrentFrame, modname)
	if ignoreCurrentFrame == nil then
		ignoreCurrentFrame = false
	end
	local prevKeyframe = nil
	local nextKeyframe = nil
	for _, keyframe in pairs(keyframes) do
		if
			keyframe.Position == frame
			and (keyframe.EntityData[modname] or keyframe.Modifier and keyframe.Modifier == modname)
			and not ignoreCurrentFrame
		then
			prevKeyframe = keyframe
			nextKeyframe = keyframe
			break
		end

		if
			keyframe.Position < frame
			and (not prevKeyframe or prevKeyframe.Position < keyframe.Position)
			and (keyframe.EntityData[modname] or keyframe.Modifier and keyframe.Modifier == modname)
		then
			prevKeyframe = keyframe
		elseif
			keyframe.Position > frame
			and (not nextKeyframe or nextKeyframe.Position > keyframe.Position)
			and (keyframe.EntityData[modname] or keyframe.Modifier and keyframe.Modifier == modname)
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
		-- SMH 4.0 save files store easein and easeout values keyed by modifier name,
		-- while SMH 3.0 stores them per frame position (which is costly for iteration)
		local easeOut = istable(prevKeyframe.EaseOut) and prevKeyframe.EaseOut[modname] or prevKeyframe.EaseOut
		local easeIn = istable(prevKeyframe.EaseIn) and prevKeyframe.EaseIn[modname] or prevKeyframe.EaseIn
		---@cast easeOut number
		---@cast easeIn number
		lerpMultiplier = math.EaseInOut(lerpMultiplier, easeIn, easeOut)
	end
	return prevKeyframe, nextKeyframe, lerpMultiplier
end

return Vendor
