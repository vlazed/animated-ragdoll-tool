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

function generateLerpFrame(currentFrame, prevFrame, nextFrame, lerpMultiplier)
    prevFrame = prevFrame or nextFrame
    nextFrame = nextFrame or prevFrame
    if not nextFrame or not prevFrame then return {} end
    local lerpFrame = {}
    local count = #prevFrame
    for i = 0, count do
        lerpFrame[i] = {}
        lerpFrame[i].Pos = LerpLinearVector(prevFrame[i].Pos, nextFrame[i].Pos, lerpMultiplier)
        lerpFrame[i].Ang = LerpLinearAngle(prevFrame[i].Ang, nextFrame[i].Ang, lerpMultiplier)
        if i > 0 then
            if prevFrame[i].LocalPos then
                lerpFrame[i].LocalPos = LerpLinearVector(prevFrame[i].LocalPos, nextFrame[i].LocalPos, lerpMultiplier)
                lerpFrame[i].LocalAng = LerpLinearAngle(prevFrame[i].LocalAng, nextFrame[i].LocalAng, lerpMultiplier)
            end

            if prevFrame[i].Scale then lerpFrame[i].Scale = LerpLinear(prevFrame[i].Scale, nextFrame[i].Scale, lerpMultiplier) end
        end
    end
    return lerpFrame
end

function getPoseFromSMHFrames(poseFrame, smhFrames, modifier)
    for _, frameData in ipairs(smhFrames) do
        -- If no pose data exists, continue to the next frame
        if not frameData.EntityData[modifier] then continue end
        if frameData.Position == poseFrame then
            return frameData.EntityData[modifier]
        else
            local prevFrame, nextFrame, lerpMultiplier = getClosestKeyframes(smhFrames, poseFrame, false, modifier)
            return generateLerpFrame(poseFrame, prevFrame.EntityData[modifier], nextFrame.EntityData[modifier], lerpMultiplier)
        end
    end
end