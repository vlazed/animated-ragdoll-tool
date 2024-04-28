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

local function generateLerpPose(currentFrame, prevFrame, nextFrame, lerpMultiplier)
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

            if prevFrame[i].Scale then
                lerpPose[i].Scale = LerpLinear(prevFrame[i].Scale, nextFrame[i].Scale, lerpMultiplier)
            end
        end
    end

    return lerpPose
end

local function deltaPose(poseData, originPose)
    local targetPose = poseData[0]
    local newPose = poseData
    newPose[0].Pos = targetPose.Pos - originPose.Pos
    newPose[0].Ang = targetPose.Ang - originPose.Ang
    PrintTable(newPose)

    return newPose
end

function getPoseFromSMHFrames(poseFrame, smhFrames, modifier)
    local originPose = smhFrames[1].EntityData[modifier][0]
    for _, frameData in ipairs(smhFrames) do
        -- If no pose data exists, continue to the next frame
        if not frameData.EntityData[modifier] then continue end
        local prevFrame, nextFrame, lerpMultiplier = getClosestKeyframes(smhFrames, poseFrame, false, modifier)

        return deltaPose(generateLerpPose(poseFrame, prevFrame.EntityData[modifier], nextFrame.EntityData[modifier], lerpMultiplier), originPose)
    end
end