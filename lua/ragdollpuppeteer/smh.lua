-- https://github.com/Winded/StopMotionHelper/blob/master/lua/smh/shared/saves.lua MGR.Load()
function parseSMHFile(filePath, model)
    -- Check if the file has the model somewhere in there
    if not file.Exists(filePath, "DATA") then return end
    local json = file.Read(filePath)
    -- If the entity doesn't exist, don't bother loading other entities
    if not string.find(json, model) then return end
    local smhData = util.JSONToTable(json)
    if not smhData then return end
    return smhData
end

local function generateLerpPose(prevFrame, nextFrame, lerpMultiplier)
    prevFrame = prevFrame or nextFrame
    nextFrame = nextFrame or prevFrame
    if not nextFrame or not prevFrame then return {} end
    local lerpPose = {}
    local count = #prevFrame
    for i = 0, count do
        lerpPose[i] = {}
        lerpPose[i].Pos = LerpLinearVector(prevFrame[i].Pos, nextFrame[i].Pos, lerpMultiplier)
        lerpPose[i].Ang = LerpLinearAngle(prevFrame[i].Ang, nextFrame[i].Ang, lerpMultiplier)
        if i > 0 then
            if prevFrame[i].LocalPos then
                lerpPose[i].LocalPos = LerpLinearVector(prevFrame[i].LocalPos, nextFrame[i].LocalPos, lerpMultiplier)
                lerpPose[i].LocalAng = LerpLinearAngle(prevFrame[i].LocalAng, nextFrame[i].LocalAng, lerpMultiplier)
            end

            if prevFrame[i].Scale then lerpPose[i].Scale = LerpLinear(prevFrame[i].Scale, nextFrame[i].Scale, lerpMultiplier) end
        end
    end
    return lerpPose
end

local function deltaPose(poseData, originPose)
    local targetPose = poseData[0]
    local newPose = poseData
    --PrintTable(targetPose)
    local wpos, wang = WorldToLocal(targetPose.Pos, targetPose.Ang, originPose.Pos, originPose.Ang)
    local pos, ang = LocalToWorld(wpos, wang, vector_origin, angle_zero)
    newPose[0].Pos = pos --targetPose.Pos - originPose.Pos
    newPose[0].Ang = ang --targetPose.Ang - originPose.Ang
    --PrintTable(originPose)
    --print()
    return newPose
end

-- We assume the lowest frame is the origin of the entity
local function getOriginPose(smhFrames, modifier)
    local lowestFrame = math.huge
    for frameIndex, frameData in ipairs(smhFrames) do
        -- We shouldn't set the lowest frame if it doesn't exist for the modifier we're looking for
        if not frameData.EntityData[modifier] then continue end
        if lowestFrame > frameData.Position then lowestFrame = frameIndex end
    end
    return smhFrames[lowestFrame].EntityData[modifier][0]
end

function getPoseFromSMHFrames(poseFrame, smhFrames, modifier)
    local originPose = getOriginPose(smhFrames, modifier) --smhFrames[1].EntityData[modifier][0]
    --PrintTable(originPose)
    --print()
    for _, frameData in ipairs(smhFrames) do
        -- If no pose data exists, continue to the next frame
        if not frameData.EntityData[modifier] then continue end
        local prevFrame, nextFrame, lerpMultiplier = getClosestKeyframes(smhFrames, poseFrame, false, modifier)
        return deltaPose(generateLerpPose(prevFrame.EntityData[modifier], nextFrame.EntityData[modifier], lerpMultiplier), originPose)
    end
end