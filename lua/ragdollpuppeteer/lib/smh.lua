--- Stop Motion Helper vendor functions to generate SMH pose for puppet

---@module "ragdollpuppeteer.lib.vendor"
local vendor = include("ragdollpuppeteer/lib/vendor.lua")

local SMH = {}

---Parse the smh text file and return a table of it
---Source: https://github.com/Winded/StopMotionHelper/blob/9680e756ef01ee994c3bbac0eacffdfd174d34bb/lua/smh/shared/saves.lua#L98
---@param filePath string Path to the SMH .txt file
---@param model string The model in the SMH file to consider
---@return SMHFile? smhFile A table consisting of the contents of the SMH .txt file
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
---@param prevFrame SMHFramePose[]? Previous frame pose
---@param nextFrame SMHFramePose[]? Next frame pose
---@param lerpMultiplier number Percentage between previous frame and next frame
---@param puppeteer Entity Entity for assigning bone names
---@return SMHFramePose[] interpolatedFrame Interpolated frame pose between previous frame and next frame
local function generateLerpPose(prevFrame, nextFrame, lerpMultiplier, puppeteer)
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
		lerpPose[i].Pos = vendor.LerpLinearVector(prevFrame[i].Pos, nextFrame[i].Pos, lerpMultiplier)
		lerpPose[i].Ang = vendor.LerpLinearAngle(prevFrame[i].Ang, nextFrame[i].Ang, lerpMultiplier)
		if i > 0 then
			if prevFrame[i].LocalPos then
				lerpPose[i].LocalPos =
					vendor.LerpLinearVector(prevFrame[i].LocalPos, nextFrame[i].LocalPos, lerpMultiplier)
				lerpPose[i].LocalAng =
					vendor.LerpLinearAngle(prevFrame[i].LocalAng, nextFrame[i].LocalAng, lerpMultiplier)
			end

			if prevFrame[i].Scale then
				lerpPose[i].Scale = vendor.LerpLinear(prevFrame[i].Scale, nextFrame[i].Scale, lerpMultiplier)
			end
		end
	end
	return lerpPose
end

---Generate a displacement vector from the origin position to the current position
---@param poseData SMHFramePose Current pose at some frame of the animation
---@param originPose SMHFramePose Origin pose at the start of the animation
---@param puppeteer Entity Entity for assigning bone names
---@return SMHFramePose deltaPose The delta between the current pose and origin pose
local function deltaPose(poseData, originPose, puppeteer)
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
---@param smhFrames SMHFrameData[] Frame data
---@param modifier SMHModifiers Modifier to consider
---@return SMHFramePose originPose Origin pose at the start of the animation
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

---@param poseFrame integer Target frame to obtain pose
---@param smhFrames SMHFrameData[] Collection of pose data to search for target
---@param modifier SMHModifiers Modifier to consider when finding target pose
---@param puppeteer Entity Entity for assigning bone names
---@return SMHFramePose[] targetPose The closest, interpolated keyframe pose to our target frame
function SMH.getPoseFromSMHFrames(poseFrame, smhFrames, modifier, puppeteer)
	local originPose = getOriginPose(smhFrames, modifier)
	for _, frameData in ipairs(smhFrames) do
		-- If no pose data exists, continue to the next frame
		if not frameData.EntityData[modifier] then
			continue
		end
		local prevFrame, nextFrame, lerpMultiplier = vendor.getClosestKeyframes(smhFrames, poseFrame, false, modifier)
		---@cast prevFrame SMHFrameData
		---@cast nextFrame SMHFrameData

		return deltaPose(
			generateLerpPose(prevFrame.EntityData[modifier], nextFrame.EntityData[modifier], lerpMultiplier, puppeteer),
			originPose,
			puppeteer
		)
	end
end

return SMH
