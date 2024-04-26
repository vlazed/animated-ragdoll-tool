function GetPhysBoneParent(entity, bone)
    local b = PhysBoneToBone(entity, bone)
    local i = 1
    while true do
        b = entity:GetBoneParent(b)
        local parent = BoneToPhysBone(entity, b)
        if parent >= 0 and parent ~= bone then return parent end
        i = i + 1
        if i > 128 then --We've gone through all possible bones, so we get out.
            break
        end
    end
    return -1
end

function PhysBoneToBone(ent, bone)
    return ent:TranslatePhysBoneToBone(bone)
end

function BoneToPhysBone(ent, bone)
    for i = 0, ent:GetPhysicsObjectCount() - 1 do
        local b = ent:TranslatePhysBoneToBone(i)
        if bone == b then return i end
    end
    return -1
end

-- https://github.com/Winded/StopMotionHelper/blob/master/lua/smh/server/easing.lua
function LerpLinear(s, e, p)
    return Lerp(p, s, e)
end

function LerpLinearVector(s, e, p)
    return LerpVector(p, s, e)
end

function LerpLinearAngle(s, e, p)
    return LerpAngle(p, s, e)
end

-- https://github.com/Winded/StopMotionHelper/blob/master/lua/smh/server/keyframe_data.lua
-- Modified to directly work with json translation 
function getClosestKeyframes(keyframes, frame, ignoreCurrentFrame, modname)
    if ignoreCurrentFrame == nil then ignoreCurrentFrame = false end
    local prevKeyframe = nil
    local nextKeyframe = nil
    for _, keyframe in pairs(keyframes) do
        if keyframe.Position == frame and keyframe.Modifier == modname and not ignoreCurrentFrame then
            prevKeyframe = keyframe
            nextKeyframe = keyframe
            break
        end

        if keyframe.Position < frame and (not prevKeyframe or prevKeyframe.Position < keyframe.Position) and keyframe.Modifier == modname then
            prevKeyframe = keyframe
        elseif keyframe.Position > frame and (not nextKeyframe or nextKeyframe.Position > keyframe.Position) and keyframe.Modifier == modname then
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

TOOL.Category = "Poser"
TOOL.Name = "#tool.ragdollposer.name"
TOOL.Command = nil
TOOL.ConfigName = ""
TOOL.ClientConVar["frame"] = 0
TOOL.ClientConVar["animatenonphys"] = "false"
if SERVER then
    util.AddNetworkString("onFrameChange")
    util.AddNetworkString("onSequenceChange")
    util.AddNetworkString("onFrameNext")
    util.AddNetworkString("onFramePrevious")
    -- TODO: direct way to update client animation puppet
    util.AddNetworkString("updateClientPosition")
end

local id = "ragposer_entity"
local id2 = "ragposer_puppet"
local prevServerAnimEntity = nil
local bonesReset = false
local function styleServerEntity(ent)
    ent:SetColor(Color(255, 255, 255, 0))
    ent:SetRenderMode(RENDERMODE_TRANSCOLOR)
    ent:AddEffects(EF_NODRAW)
end

function TOOL:Think()
    if CLIENT then
        if self:GetAnimationEntity() == prevServerAnimEntity then return end
        prevServerAnimEntity = self:GetAnimationEntity()
        self:RebuildControlPanel(self:GetAnimationEntity(), self:GetOwner())
        return true
    end
end

function TOOL:SetAnimationEntity(ent)
    return self:GetWeapon():SetNWEntity(id, ent)
end

function TOOL:GetAnimationEntity()
    return self:GetWeapon():GetNWEntity(id)
end

function TOOL:SetAnimationPuppet(puppet)
    return self:GetWeapon():SetNWEntity(id2, puppet)
end

function TOOL:GetAnimationPuppet()
    return self:GetWeapon():GetNWEntity(id2)
end

function TOOL:Cleanup()
    if IsValid(self:GetAnimationPuppet()) then self:GetAnimationPuppet():Remove() end
    self:SetAnimationEntity(nil)
    self:SetAnimationPuppet(nil)
end

-- https://github.com/Winded/StopMotionHelper/blob/master/lua/smh/modifiers/physbones.lua
-- Directly influence the ragdoll physical bones from SMH data
local function setPhysicalBonePoseOf(ent, targetPose, animEnt, originPose, offset)
    offset = offset and Angle(offsets[1], offsets[2], offsets[3]) or Angle(0, 0, 0)
    for i = 0, ent:GetPhysicsObjectCount() - 1 do
        local b = ent:TranslatePhysBoneToBone(i)
        local phys = ent:GetPhysicsObjectNum(i)
        local parent = ent:GetPhysicsObjectNum(GetPhysBoneParent(ent, i))
        if not targetPose[i] then continue end
        if targetPose[i].LocalPos and targetPose[i].LocalAng then
            local pos, ang = LocalToWorld(targetPose[i].LocalPos, targetPose[i].LocalAng, parent:GetPos(), parent:GetAngles())
            phys:EnableMotion(false)
            phys:SetPos(pos)
            phys:SetAngles(ang)
            phys:Wake()
        else
            local matrix = animEnt:GetBoneMatrix(b)
            local bPos, bAng = matrix:GetTranslation(), matrix:GetAngles()
            local dAng = targetPose[i].Ang - originPose.Ang
            local dPos = originPose.Pos - targetPose[i].Pos
            local fPos = animEnt:LocalToWorld(WorldToLocal(bPos, angle_zero, animEnt:GetPos(), angle_zero) - dPos)
            phys:EnableMotion(false)
            phys:SetPos(fPos)
            phys:SetAngles(bAng + dAng + offset)
            phys:Wake()
        end
    end
end

-- Directly influence the ragdoll nonphysical bones from SMH data
local function setNonPhysicalBonePoseOf(ent, targetPose)
    for b = 0, ent:GetBoneCount() - 1 do
        ent:ManipulateBonePosition(b, targetPose[b].Pos)
        ent:ManipulateBoneAngles(b, targetPose[b].Ang)
        if targetPose[b].Scale then ent:ManipulateBoneScale(b, targetPose[b].Scale) end
    end
end

-- https://github.com/Winded/StandingPoseTool/blob/master/lua/weapons/gmod_tool/stools/ragdollstand.lua
local function matchPhysicalBonePoseOf(ent, targetEnt)
    for i = 0, ent:GetPhysicsObjectCount() - 1 do
        local phys = ent:GetPhysicsObjectNum(i)
        local b = ent:TranslatePhysBoneToBone(i)
        local pos, ang = targetEnt:GetBonePosition(b)
        phys:EnableMotion(false)
        phys:SetPos(pos)
        phys:SetAngles(ang)
        if string.sub(ent:GetBoneName(b), 1, 4) == "prp_" then
            phys:EnableMotion(true)
            phys:Wake()
        else
            phys:Wake()
        end
    end
end

local function matchNonPhysicalBonePoseOf(ent, targetEnt)
    if bonesReset then bonesReset = false end
    local physBoneIndices = {}
    for i = 0, ent:GetPhysicsObjectCount() - 1 do
        physBoneIndices[ent:TranslatePhysBoneToBone(i)] = true
    end

    for i = 0, ent:GetBoneCount() - 1 do
        if not physBoneIndices[i] then
            -- Reset bone position and angles
            ent:ManipulateBonePosition(i, vector_origin, false)
            ent:ManipulateBoneAngles(i, angle_zero, false)
            -- Get world position
            local ipos, iang = ent:GetBonePosition(i)
            local fpos, fang = targetEnt:GetBonePosition(i)
            -- TODO: Manipulate nonphysical bones from target ent which has no bone manipulations
            if targetEnt:GetBoneParent(i) > -1 then
                local diffpos = fpos - ipos
                local diffang = fang - iang
                --print(diffpos)
                --print(diffang)
                -- Go from world position to local bone position
                --ent:ManipulateBonePosition(i, diffpos)
                ent:ManipulateBoneAngles(i, diffang)
            end
        end
    end
end

local function setPositionOf(targetEnt, ent)
    local tr = util.TraceLine({
        start = ent:GetPos(),
        endpos = ent:GetPos() - Vector(0, 0, 3000),
        filter = function(e) return e:GetClass() == game.GetWorld() end,
    })

    targetEnt:SetPos(tr.HitPos)
end

local function setAngleOf(targetEnt, ent, ply)
    local angle = (ply:GetPos() - ent:GetPos()):Angle()
    targetEnt:SetAngles(Angle(0, angle.y, 0))
end

local function setPlacementOf(targetEnt, ent, ply)
    setPositionOf(targetEnt, ent)
    setAngleOf(targetEnt, ent, ply)
end

local function resetAllNonphysicalBonesOf(ent)
    for i = 0, ent:GetBoneCount() - 1 do
        ent:ManipulateBonePosition(i, vector_origin)
        ent:ManipulateBoneAngles(i, angle_zero)
    end

    bonesReset = true
end

-- Set stages for showing control panel for selected entity 
function TOOL:LeftClick(tr)
    local ent = tr.Entity
    do
        local validEnt = IsValid(ent)
        local isRagdoll = ent:IsRagdoll()
        local sameEntity = IsValid(self:GetAnimationEntity()) and self:GetAnimationEntity() == prevServerAnimEntity
        if not validEnt or not isRagdoll or sameEntity then return false end
    end

    local animEntity = ents.Create("prop_dynamic")
    if self:GetAnimationEntity() ~= animEntity then self:Cleanup() end
    animEntity:SetModel(ent:GetModel())
    self:SetAnimationEntity(ent)
    self:SetAnimationPuppet(animEntity)
    setPlacementOf(animEntity, ent, self:GetOwner())
    animEntity:Spawn()
    styleServerEntity(animEntity)
    local currentIndex = 0
    net.Receive("onFrameChange", function()
        local isSequence = net.ReadBool()
        if isSequence then
            local cycle = net.ReadFloat()
            local animatingNonPhys = net.ReadBool()
            -- This statement mimics a sequence change event, so it offsets its sequence to force an animation change. Might test without statement. 
            animEntity:ResetSequence((currentIndex == 0) and (currentIndex + 1) or (currentIndex - 1))
            animEntity:ResetSequence(currentIndex)
            animEntity:SetCycle(cycle)
            animEntity:SetPlaybackRate(0)
            matchPhysicalBonePoseOf(ent, animEntity)
            if animatingNonPhys then
                matchNonPhysicalBonePoseOf(ent, animEntity)
            elseif not bonesReset then
                resetAllNonphysicalBonesOf(ent)
            end
        else
            local targetPose = net.ReadTable(false)
            local originPose = net.ReadTable(false)
            local angOffset = net.ReadTable(true)
            local animatingNonPhys = net.ReadBool()
            setPhysicalBonePoseOf(ent, targetPose, animEntity, originPose, angOffset)
            if animatingNonPhys then
                local targetPoseNonPhys = net.ReadTable(false)
                setNonPhysicalBonePoseOf(ent, targetPoseNonPhys, animEntity)
            elseif not bonesReset then
                resetAllNonphysicalBonesOf(ent)
            end
        end
    end)

    net.Receive("onSequenceChange", function()
        if not IsValid(animEntity) then return end
        local isSequence = net.ReadBool()
        if isSequence then
            local seqIndex = net.ReadInt(14)
            local animatingNonPhys = net.ReadBool()
            currentIndex = seqIndex
            animEntity:ResetSequence(seqIndex)
            animEntity:SetCycle(0)
            animEntity:SetPlaybackRate(0)
            matchPhysicalBonePoseOf(ent, animEntity)
            if animatingNonPhys then
                matchNonPhysicalBonePoseOf(ent, animEntity)
            elseif not bonesReset then
                resetAllNonphysicalBonesOf(ent)
            end
        else
            local targetPose = net.ReadTable(false)
            local originPose = net.ReadTable(false)
            local angOffset = net.ReadTable(true)
            local animatingNonPhys = net.ReadBool()
            setPhysicalBonePoseOf(ent, targetPose, animEntity, originPose, angOffset)
            if animatingNonPhys then
                local targetPoseNonPhys = net.ReadTable(false)
                setNonPhysicalBonePoseOf(ent, targetPoseNonPhys, animEntity)
            elseif not bonesReset then
                resetAllNonphysicalBonesOf(ent)
            end
        end
    end)

    ent:CallOnRemove("RemoveAnimEntity", function() self:Cleanup() end)
    self:SetStage(1)
    return true
end

-- Stop selecting an entity
function TOOL:RightClick(tr)
    if IsValid(self:GetAnimationEntity()) then
        self:Cleanup()
        self:SetStage(0)
        return true
    end
end

concommand.Add("ragdollposer_updateposition", function(ply, _, _)
    if not IsValid(ply) then return end
    local tool = ply:GetTool("ragdollposer")
    local puppet = tool:GetAnimationPuppet()
    local entity = tool:GetAnimationEntity()
    if not IsValid(entity) or not IsValid(puppet) then return end
    setPlacementOf(puppet, entity, ply)
    net.Start("updateClientPosition")
    net.Send(ply)
end)

concommand.Add("ragdollposer_previousframe", function(ply)
    net.Start("onFramePrevious")
    net.Send(ply)
end)

concommand.Add("ragdollposer_nextframe", function(ply)
    net.Start("onFrameNext")
    net.Send(ply)
end)

if SERVER then return end
local prevClientAnimEntity = nil
local currentSequence = {
    label = ""
}

TOOL:BuildConVarList()
local function styleClientEntity(ent)
    ent:SetColor(Color(0, 0, 255, 128))
    ent:SetRenderMode(RENDERMODE_TRANSCOLOR)
end

local function constructSequenceList(cPanel)
    local animationList = vgui.Create("DListView", cPanel)
    animationList:SetMultiSelect(false)
    animationList:AddColumn("Id")
    animationList:AddColumn("Name")
    animationList:AddColumn("FPS")
    animationList:AddColumn("Duration (frames)")
    cPanel:AddItem(animationList)
    return animationList
end

local function constructSMHEntityList(cPanel)
    local animationList = vgui.Create("DListView", cPanel)
    animationList:SetMultiSelect(false)
    animationList:AddColumn("Name")
    animationList:AddColumn("Duration (frames)")
    cPanel:AddItem(animationList)
    return animationList
end

local function constructSMHFileBrowser(cPanel)
    local fileBrowser = vgui.Create("DFileBrowser", CPanel)
    fileBrowser:SetPath("DATA")
    fileBrowser:SetBaseFolder("smh")
    fileBrowser:SetCurrentFolder("smh")
    cPanel:AddItem(fileBrowser)
    return fileBrowser
end

local function constructAngleNumWangs(parent, names)
    local wangs = {}
    for i = 1, 3 do
        local wang = vgui.Create("DNumberWang", parent)
        local name = vgui.Create("DLabel", wang)
        wang:SetMin(-180)
        wang:SetMax(180)
        name:NoClipping(false)
        name:SetText(names[i])
        name:SetPos(name:GetSize() / 2, 0)
        name:SetColor(Color(0, 0, 0))
        wang:Dock(LEFT)
        wangs[i] = wang
    end
    return wangs
end

local function constructAngleNumWangTrio(cPanel, names, label)
    label = label or ""
    local scrollingFrame = vgui.Create("DScrollPanel")
    local name = vgui.Create("DLabel", scrollingFrame)
    scrollingFrame:NoClipping(false)
    local angleWangs = constructAngleNumWangs(scrollingFrame, names)
    scrollingFrame:Dock(FILL)
    name:Dock(LEFT)
    name:SetText(label)
    name:SetColor(Color(0, 0, 0))
    cPanel:AddItem(scrollingFrame)
    return angleWangs, scrollingFrame
end

-- https://github.com/Winded/StopMotionHelper/blob/master/lua/smh/shared/saves.lua MGR.Load()
local function parseSMHFile(filePath, model)
    -- Check if the file has the model somewhere in there
    if not file.Exists(filePath, "DATA") then return end
    local json = file.Read(filePath)
    -- If the entity doesn't exist, don't bother loading other entities
    if not string.find(json, model) then return end
    local smhData = util.JSONToTable(json)
    if not smhData then return end
    return smhData
end

local function findLongestAnimationIn(sequenceInfo, animEntity)
    local longestAnim = {
        numframes = -1
    }

    for _, anim in pairs(sequenceInfo.anims) do
        local animInfo = animEntity:GetAnimInfo(anim)
        if not (animInfo and animInfo.numframes) then continue end
        if animInfo.numframes > longestAnim.numframes then longestAnim = animInfo end
    end
    return longestAnim
end

-- Populate the DList with compatible SMH entities (compatible meaning the entity has the same model as animEntity)
local function populateSMHEntitiesList(seqList, model, data, predicate)
    if not data then return end
    local maxFrames = 0
    for _, entity in pairs(data.Entities) do
        if entity.Properties.Model ~= model then continue end
        if not predicate(entity.Properties) then continue end
        local physFrames = {}
        local nonPhysFrames = {}
        local pFrames = 0
        local nFrames = 0
        local lmax = 0
        for _, fdata in pairs(entity.Frames) do
            if fdata.EntityData and fdata.EntityData.physbones then
                table.insert(physFrames, fdata)
                pFrames = fdata.Position
            end

            if fdata.EntityData and fdata.EntityData.bones then
                table.insert(nonPhysFrames, fdata)
                nFrames = fdata.Position
            end

            lmax = (pFrames > nFrames) and pFrames or nFrames
            if lmax > maxFrames then maxFrames = lmax end
        end

        local line = seqList:AddLine(entity.Properties.Name, maxFrames)
        line:SetSortValue(3, physFrames)
        line:SetSortValue(4, nonPhysFrames)
    end
end

-- Populate the DList with the animEntity sequence
local function populateSequenceList(seqList, animEntity, predicate)
    local defaultMaxFrame = 60
    local defaultFPS = 30
    for i = 0, animEntity:GetSequenceCount() - 1 do
        local seqInfo = animEntity:GetSequenceInfo(i)
        if not predicate(seqInfo) then continue end
        local longestAnim = findLongestAnimationIn(seqInfo, animEntity)
        local fps = defaultFPS
        local maxFrame = defaultMaxFrame
        -- Assume the first animation is the "base", which may have the maximum number of frames compared to other animations in the sequence
        if longestAnim.numframes > -1 then
            maxFrame = longestAnim.numframes
            fps = longestAnim.fps
        end

        seqList:AddLine(i, seqInfo.label, fps, maxFrame)
    end
end

local function clearList(dList)
    for i = 1, #dList:GetLines() do
        dList:RemoveLine(i)
    end
end

local function generateLerpFrame(currentFrame, prevFrame, nextFrame, lerpMultiplier)
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

local function getPoseFromSMHFrames(poseFrame, smhFrames, modifier)
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

local function setAngleTrioDefaults(trio, a, b, c)
    trio[1]:SetValue(a)
    trio[2]:SetValue(b)
    trio[3]:SetValue(c)
end

local function getAngleTrio(trio)
    return {trio[1]:GetValue(), trio[2]:GetValue(), trio[3]:GetValue()}
end

function TOOL.BuildCPanel(cPanel, entity, ply)
    if not IsValid(entity) then return end
    local defaultMaxFrame = 60
    local prevFrame = 0
    local model = entity:GetModel()
    local animEntity = ClientsideModel(model, RENDERGROUP_TRANSLUCENT)
    if IsValid(prevClientAnimEntity) and prevClientAnimEntity ~= animEntity then prevClientAnimEntity:Remove() end
    animEntity:SetModel(model)
    setPlacementOf(animEntity, entity, ply)
    animEntity:Spawn()
    styleClientEntity(animEntity)
    -- UI Elements
    cPanel:Help("Current Entity: " .. model)
    local numSlider = cPanel:NumSlider("Frame", "ragdollposer_frame", 0, defaultMaxFrame - 1, 0)
    local angOffset, _ = constructAngleNumWangTrio(cPanel, {"Pitch", "Yaw", "Roll"}, "Angle Offset")
    setAngleTrioDefaults(angOffset, 0, 0, 0)
    local nonPhysCheckbox = cPanel:CheckBox("Animate Nonphysical Bones", "ragdollposer_animatenonphys")
    cPanel:Button("Update Puppet Position", "ragdollposer_updateposition", animEntity)
    local sourceBox = cPanel:ComboBox("Source")
    sourceBox:AddChoice("Sequence")
    sourceBox:AddChoice("Stop Motion Helper")
    sourceBox:ChooseOption("Sequence", 1)
    --print(sourceBox:GetSelected())
    local searchBar = cPanel:TextEntry("Search Bar:")
    searchBar:SetPlaceholderText("Search for a sequence...")
    local sequenceList = constructSequenceList(cPanel)
    local smhBrowser = constructSMHFileBrowser(cPanel)
    local smhList = constructSMHEntityList(cPanel)
    smhList:Hide()
    smhBrowser:Hide()
    populateSequenceList(sequenceList, animEntity, function(_) return true end)
    sequenceList:SizeTo(-1, 500, 0.5)
    -- UI Hooks
    function searchBar:OnEnter(text)
        if sourceBox:GetSelected() == "Sequence" then
            clearList(sequenceList)
            populateSequenceList(sequenceList, animEntity, function(seqInfo)
                if text:len() > 0 then
                    return string.find(seqInfo.label, text)
                else
                    return true
                end
            end)
        else
            populateSMHEntitiesList(smhList, animEntity, function(entProp)
                if text:len() > 0 then
                    return entProp == text
                else
                    return true
                end
            end)
        end
    end

    function sequenceList:OnRowSelected(index, row)
        local seqInfo = animEntity:GetSequenceInfo(row:GetValue(1))
        if currentSequence.label ~= seqInfo.label then
            currentSequence = seqInfo
            --print(index)
            animEntity:ResetSequence(row:GetValue(1))
            animEntity:SetCycle(0)
            animEntity:SetPlaybackRate(0)
            numSlider:SetMax(row:GetValue(4) - 1)
            net.Start("onSequenceChange")
            net.WriteBool(true)
            net.WriteInt(row:GetValue(1), 14)
            net.WriteBool(nonPhysCheckbox:GetChecked())
            net.SendToServer()
        end
    end

    -- TODO: Set a limit to how many times a new frame can be sent to the server to prevent spamming
    function numSlider:OnValueChanged(val)
        -- Only send when we go frame by frame
        if math.abs(prevFrame - val) < 1 then return end
        local option, _ = sourceBox:GetSelected()
        if option == "Sequence" then
            if not currentSequence.anims then return end
            if not IsValid(animEntity) then return end
            local numframes = findLongestAnimationIn(currentSequence, animEntity).numframes - 1
            numSlider:SetValue(math.Clamp(val, 0, numframes))
            local cycle = val / numframes
            animEntity:SetCycle(cycle)
            net.Start("onFrameChange", true)
            net.WriteBool(true)
            net.WriteFloat(cycle)
            net.WriteBool(nonPhysCheckbox:GetChecked())
            net.SendToServer()
        else
            if not smhList:GetSelected()[1] then return end
            local physBoneData = getPoseFromSMHFrames(val, smhList:GetSelected()[1]:GetSortValue(3), "physbones")
            local originPhysBonePose = getPoseFromSMHFrames(0, smhList:GetSelected()[1]:GetSortValue(3), "physbones")[0]
            net.Start("onFrameChange", true)
            net.WriteBool(false)
            net.WriteTable(physBoneData, false)
            net.WriteTable(originPhysBonePose, false)
            net.WriteTable(getAngleTrio(angOffset), true)
            net.WriteBool(nonPhysCheckbox:GetChecked())
            if nonPhysCheckbox:GetChecked() then
                local nonPhysBoneData = getPoseFromSMHFrames(val, smhList:GetSelected()[1]:GetSortValue(4), "bones")
                net.WriteTable(nonPhysBoneData, false)
            end

            net.SendToServer()
        end

        prevFrame = val
    end

    function sourceBox:OnSelect(ind, val, data)
        if val == "Sequence" then
            smhList:SizeTo(-1, 0, 0.5)
            smhBrowser:SizeTo(-1, 0, 0.5)
            smhList:Hide()
            smhBrowser:Hide()
            sequenceList:Show()
            sequenceList:SizeTo(-1, 500, 0.5)
        else
            sequenceList:SizeTo(-1, 0, 0.5)
            sequenceList:Hide()
            smhBrowser:Show()
            smhList:Show()
            smhList:SizeTo(-1, 250, 0.5)
            smhBrowser:SizeTo(-1, 250, 0.5)
        end
    end

    function smhList:OnRowSelected(index, row)
        numSlider:SetMax(row:GetValue(2))
        local physBoneData = getPoseFromSMHFrames(0, row:GetSortValue(3), "physbones")
        local originPhysBonePose = getPoseFromSMHFrames(0, smhList:GetSelected()[1]:GetSortValue(3), "physbones")[0]
        net.Start("onSequenceChange", true)
        net.WriteBool(false)
        net.WriteTable(physBoneData, false)
        net.WriteTable(originPhysBonePose, false)
        net.WriteTable(getAngleTrio(angOffset), true)
        net.WriteBool(nonPhysCheckbox:GetChecked())
        if nonPhysCheckbox:GetChecked() then
            local nonPhysBoneData = getPoseFromSMHFrames(0, row:GetSortValue(4), "bones")
            net.WriteTable(nonPhysBoneData, false)
        end

        net.SendToServer()
    end

    function smhBrowser:OnSelect(filePath)
        clearList(smhList)
        local data = parseSMHFile(filePath, model)
        populateSMHEntitiesList(smhList, model, data, function(_) return true end)
    end

    -- Network Hooks
    net.Receive("onFramePrevious", function() numSlider:SetValue((numSlider:GetValue() - 1) % numSlider:GetMax()) end)
    net.Receive("onFrameNext", function() numSlider:SetValue((numSlider:GetValue() + 1) % numSlider:GetMax()) end)
    net.Receive("updateClientPosition", function() setPlacementOf(animEntity, entity, ply) end)
    -- End of lifecycle events
    entity:CallOnRemove("RemoveAnimEntity", function() animEntity:Remove() end)
    prevClientAnimEntity = animEntity
end

if CLIENT then
    language.Add("tool.ragdollposer.name", "Pose Ragdoll to Animation")
    language.Add("tool.ragdollposer.desc", "Pose ragdolls to any animation frame.")
    language.Add("tool.ragdollposer.0", "Left click to select a ragdoll.")
    language.Add("tool.ragdollposer.1", "Play animations through the context menu.")
end