---@module "ragdollpuppeteer.vendor"
local Vendor = include("ragdollpuppeteer/vendor.lua")

local SMH = {}

-- https://github.com/Winded/StopMotionHelper/blob/master/lua/smh/shared/saves.lua MGR.Load()
---Parse the smh text file and return a table of it
---@param filePath string
---@param model string
---@return SMHFile?
function SMH.parseSMHFile(filePath, model)
	-- Check if the file has the model somewhere in there
	if not file.Exists(filePath, "DATA") then
		return
	end
	local json = file.Read(filePath)
	-- If the entity doesn't exist, don't bother loading other entities
	if not string.find(json, model) then
		return
	end
	local smhData = util.JSONToTable(json)
	if not smhData then
		return
	end
	return smhData
end

---Linearly interpolate between each frame, imitating the poses as seen in the SMH timeline
---Takes inspiration from the following sources:
---https://github.com/Winded/StopMotionHelper/blob/bc94420283a978f3f56a282c5fe5cdf640d59855/lua/smh/modifiers/bones.lua#L56
---https://github.com/Winded/StopMotionHelper/blob/bc94420283a978f3f56a282c5fe5cdf640d59855/lua/smh/modifiers/physbones.lua#L116
---@param prevFrame SMHFramePose[]?
---@param nextFrame SMHFramePose[]?
---@param lerpMultiplier number
---@return SMHFramePose[]
local function generateLerpPose(prevFrame, nextFrame, lerpMultiplier)
	prevFrame = prevFrame or nextFrame
	nextFrame = nextFrame or prevFrame
	if not nextFrame or not prevFrame then
		return {}
	end
	---@cast prevFrame SMHFramePose[]
	---@cast nextFrame SMHFramePose[]

	local lerpPose = {}
	local count = #prevFrame
	for i = 0, count do
		lerpPose[i] = {}
		lerpPose[i].Pos = Vendor.LerpLinearVector(prevFrame[i].Pos, nextFrame[i].Pos, lerpMultiplier)
		lerpPose[i].Ang = Vendor.LerpLinearAngle(prevFrame[i].Ang, nextFrame[i].Ang, lerpMultiplier)
		if i > 0 then
			if prevFrame[i].LocalPos then
				lerpPose[i].LocalPos =
					Vendor.LerpLinearVector(prevFrame[i].LocalPos, nextFrame[i].LocalPos, lerpMultiplier)
				lerpPose[i].LocalAng =
					Vendor.LerpLinearAngle(prevFrame[i].LocalAng, nextFrame[i].LocalAng, lerpMultiplier)
			end

			if prevFrame[i].Scale then
				lerpPose[i].Scale = Vendor.LerpLinear(prevFrame[i].Scale, nextFrame[i].Scale, lerpMultiplier)
			end
		end
	end
	return lerpPose
end

---Generate a displacement vector from the origin position to the current position
---@param poseData SMHFramePose
---@param originPose SMHFramePose
---@return SMHFramePose
local function deltaPose(poseData, originPose)
	local targetPose = poseData[0]
	local newPose = poseData
	local wpos, wang = WorldToLocal(targetPose.Pos, targetPose.Ang, originPose.Pos, originPose.Ang)
	local pos, ang = LocalToWorld(wpos, wang, vector_origin, angle_zero)
	newPose[0].Pos = pos
	newPose[0].Ang = ang
	return newPose
end

---Find the entity's origin in the timeline.
---We assume the lowest frame is the origin of the entity
---@param smhFrames SMHFrameData[]
---@param modifier SMHModifiers
---@return SMHFramePose
local function getOriginPose(smhFrames, modifier)
	local lowestFrame = math.huge
	for frameIndex, frameData in ipairs(smhFrames) do
		-- We shouldn't set the lowest frame if it doesn't exist for the modifier we're looking for
		if not frameData.EntityData[modifier] then
			continue
		end
		if lowestFrame > frameData.Position then
			lowestFrame = frameIndex
		end
	end
	return smhFrames[lowestFrame].EntityData[modifier][0]
end

---@param poseFrame integer
---@param smhFrames SMHFrameData[]
---@param modifier SMHModifiers
---@return SMHFramePose
function SMH.getPoseFromSMHFrames(poseFrame, smhFrames, modifier)
	local originPose = getOriginPose(smhFrames, modifier)
	for _, frameData in ipairs(smhFrames) do
		-- If no pose data exists, continue to the next frame
		if not frameData.EntityData[modifier] then
			continue
		end
		local prevFrame, nextFrame, lerpMultiplier = Vendor.getClosestKeyframes(smhFrames, poseFrame, false, modifier)
		---@cast prevFrame SMHFrameData
		---@cast nextFrame SMHFrameData

		return deltaPose(
			generateLerpPose(prevFrame.EntityData[modifier], nextFrame.EntityData[modifier], lerpMultiplier),
			originPose
		)
	end
end

return SMH
