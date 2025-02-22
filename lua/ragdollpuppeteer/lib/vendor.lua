---@module "ragdollpuppeteer.lib.quaternion"
local quaternion = include("ragdollpuppeteer/lib/quaternion.lua")

--- General vendor functions from Ragdoll Mover and Stop Motion Helper

local Vendor = {}

---@param ent Entity Entity to translate physics bone
---@param physBone integer Physics object id
---@return integer bone Translated bone id
local function PhysBoneToBone(ent, physBone)
	return ent:TranslatePhysBoneToBone(physBone)
end
Vendor.PhysBoneToBone = PhysBoneToBone

---@source https://github.com/Winded/RagdollMover/blob/a761e5618e9cba3440ad88d44ee1e89252d72826/lua/autorun/ragdollmover.lua#L201
---@param ent Entity Entity to translate bone
---@param bone integer Bone id
---@return integer physBone Physics object id
local function BoneToPhysBone(ent, bone)
	for i = 0, ent:GetPhysicsObjectCount() - 1 do
		local b = ent:TranslatePhysBoneToBone(i)
		if bone == b then
			return i
		end
	end
	return -1
end
Vendor.BoneToPhysBone = BoneToPhysBone

do
	---@alias PhysBoneParents table<integer, integer>
	---@type table<string, PhysBoneParents> Mapping of physobjs indices to their parent's, for faster lookup
	local physBoneParents = {}

	---@source https://github.com/Winded/RagdollMover/blob/a761e5618e9cba3440ad88d44ee1e89252d72826/lua/autorun/ragdollmover.lua#L209
	---@param entity Entity Entity to obtain bone information
	---@param physBone integer Physics object id
	---@return integer parent Physics object parent of physBone
	function Vendor.GetPhysBoneParent(entity, physBone)
		local model = entity:GetModel()
		if physBoneParents[model] and physBoneParents[model][physBone] then
			return physBoneParents[model][physBone]
		end
		physBoneParents[model] = {}

		local b = PhysBoneToBone(entity, physBone)
		local i = 1
		while true do
			b = entity:GetBoneParent(b)
			local parent = BoneToPhysBone(entity, b)
			if parent >= 0 and parent ~= physBone then
				physBoneParents[model][physBone] = parent
				return parent
			end
			i = i + 1
			if i > 256 then --We've gone through all possible bones, so we get out.
				break
			end
		end
		physBoneParents[model][physBone] = -1
		return -1
	end
end

---Calculate the bone offsets with respect to the parent
---@source https://github.com/NO-LOAFING/AnimpropOverhaul/blob/a3a6268a5d57655611a8b8ed43dcf43051ecd93a/lua/entities/prop_animated.lua#L1889
---@param puppeteer Entity Entity to obtain bone information
---@param child integer Child bone index
---@param angleDelta Quaternion?
---@param angleDelta2 Quaternion?
---@return Vector positionOffset Position of child bone with respect to parent bone
---@return Angle angleOffset Angle of child bone with respect to parent bone
function Vendor.getBoneOffsetsOf(puppeteer, child, angleDelta, angleDelta2)
	local defaultBonePose = Vendor.getDefaultBonePoseOf(puppeteer)

	local parent = puppeteer:GetBoneParent(child)
	---@type VMatrix
	local cMatrix = puppeteer:GetBoneMatrix(child)
	---@type VMatrix
	local pMatrix = puppeteer:GetBoneMatrix(parent)

	if not cMatrix or not pMatrix or not defaultBonePose or #defaultBonePose == 0 then
		return vector_origin, angle_zero
	end

	local cAngles = cMatrix:GetAngles()
	if angleDelta then
		cAngles = quaternion.fromAngle(cAngles):Mul(angleDelta):Angle()
	end

	local fPos, fAng = WorldToLocal(cMatrix:GetTranslation(), cAngles, pMatrix:GetTranslation(), pMatrix:GetAngles())
	local dPos = fPos - defaultBonePose[child + 1][3]

	local m = Matrix()
	m:Translate(defaultBonePose[parent + 1][1])
	m:Rotate(defaultBonePose[parent + 1][2])
	m:Rotate(fAng)

	local defaultAngle = defaultBonePose[child + 1][2]
	if angleDelta2 then
		defaultAngle = quaternion.fromAngle(defaultAngle):Mul(angleDelta2):Angle()
	end
	local _, dAng = WorldToLocal(m:GetTranslation(), m:GetAngles(), defaultBonePose[child + 1][1], defaultAngle)

	return dPos, dAng
end

---@type table<string, DefaultBonePoseArray> Array of position and angles denoting the reference bone pose
local defaultPoseTrees = {}

---Get the pose of every bone of the entity, for nonphysical bone matching
---@source https://github.com/NO-LOAFING/AnimpropOverhaul/blob/a3a6268a5d57655611a8b8ed43dcf43051ecd93a/lua/entities/prop_animated.lua#L3550
---@param ent Entity Entity in reference pose
---@param identifier string? Custom name for the pose tree to allow for different versions of the same entity
---@return DefaultBonePoseArray defaultPose Array consisting of a bones offsets from the entity, and offsets from its parent bones
function Vendor.getDefaultBonePoseOf(ent, identifier)
	identifier = identifier or ent:GetModel()
	if defaultPoseTrees[identifier] then
		return defaultPoseTrees[identifier]
	end

	local csModel = ents.CreateClientProp()
	csModel:SetModel(ent:GetModel())
	csModel:DrawModel()
	csModel:SetupBones()
	csModel:InvalidateBoneCache()

	local defaultPose = {}
	local entPos = csModel:GetPos()
	local entAngles = csModel:GetAngles()
	for b = 0, csModel:GetBoneCount() - 1 do
		local parent = csModel:GetBoneParent(b)
		local bMatrix = csModel:GetBoneMatrix(b)
		if bMatrix then
			local pos1, ang1 = WorldToLocal(bMatrix:GetTranslation(), bMatrix:GetAngles(), entPos, entAngles)
			local pos2, ang2 = pos1 * 1, ang1 * 1
			if parent > -1 then
				local pMatrix = csModel:GetBoneMatrix(parent)
				pos2, ang2 = WorldToLocal(
					bMatrix:GetTranslation(),
					bMatrix:GetAngles(),
					pMatrix:GetTranslation(),
					pMatrix:GetAngles()
				)
			end

			defaultPose[b + 1] = { pos1, ang1, pos2, ang2, bMatrix:GetTranslation(), bMatrix:GetAngles() }
		else
			defaultPose[b + 1] = { vector_origin, angle_zero, vector_origin, angle_zero, vector_origin, angle_zero }
		end
	end

	defaultPoseTrees[identifier] = defaultPose
	csModel:Remove()

	return defaultPose
end

---@source https://github.com/Winded/StopMotionHelper/blob/2f0f80815a6f46c0ccd0606f27b3b054dae30b2d/lua/smh/server/easing.lua#L5
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

---@source https://github.com/Winded/StopMotionHelper/blob/2f0f80815a6f46c0ccd0606f27b3b054dae30b2d/lua/smh/server/easing.lua#L11
---@param s Vector Start vector
---@param e Vector End vector
---@param p number Percentage between start and end, between 0 and 1
---@return Vector lerpedVector Interpolated vector
function Vendor.LerpLinearVector(s, e, p)
	return LerpVector(p, s, e)
end

---@source https://github.com/Winded/StopMotionHelper/blob/2f0f80815a6f46c0ccd0606f27b3b054dae30b2d/lua/smh/server/easing.lua#L17
---@param s Angle Start angle
---@param e Angle End angle
---@param p number Percentage between start and end, between 0 and 1
---@return Angle lerpedAngle Interpolated angle
function Vendor.LerpLinearAngle(s, e, p)
	return LerpAngle(p, s, e)
end

---Find the closest pair of keyframes (`previousKeyframe` and `nextKeyframe`) to a specified `frame`
---Modified to directly work with json translation
---@source https://github.com/Winded/StopMotionHelper/blob/bc94420283a978f3f56a282c5fe5cdf640d59855/lua/smh/server/keyframe_data.lua#L1
---@param keyframes SMHFrameData[] SMH Keyframe data
---@param frame integer Target keyframe
---@param ignoreCurrentFrame boolean Whether to consider the previous and next keyframes
---@param modname SMHModifiers SMH Modifier name
---@return SMHFrameData? previousKeyframe Previous keyframe near `frame`
---@return SMHFrameData? nextKeyframe Next keyframe near `frame`
---@return integer lerpMultiplier Percentage between `previousKeyframe` and `nextKeyframe`
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

	local tweenDisabled = GetConVar("ragdollpuppeteer_disabletween"):GetBool()
	local lerpMultiplier = 0
	if not tweenDisabled and prevKeyframe.Position ~= nextKeyframe.Position then
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
