TOOL.Category = "Poser"
TOOL.Name = "#tool.ragdollposer.name"
TOOL.Command = nil
TOOL.ConfigName = ""
TOOL.ClientConVar["playing"] = "false"
TOOL.ClientConVar["frame"] = 0
TOOL.ClientConVar["fps"] = 30
if SERVER then
    util.AddNetworkString("onFrameChange")
    util.AddNetworkString("onAnimationChange")
end

local id = "ragposer_entity"
local id2 = "ragposer_puppet"
local prevServerAnimEntity = nil
local function styleServerEntity(ent)
    ent:SetColor(Color(255, 255, 255, 0))
    ent:SetRenderMode(RENDERMODE_TRANSCOLOR)
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
    self:GetAnimationPuppet():Remove()
    self:SetAnimationEntity(nil)
    self:SetAnimationPuppet(nil)
end

-- https://github.com/Winded/StandingPoseTool/blob/master/lua/weapons/gmod_tool/stools/ragdollstand.lua
local function matchPhysicalBonePoseOf(ent, targetEnt)
    for i = 0, ent:GetPhysicsObjectCount() - 1 do
        local phys = ent:GetPhysicsObjectNum(i)
        local b = ent:TranslatePhysBoneToBone(i)
        local pos, ang = targetEnt:GetBonePosition(b)
        phys:EnableMotion(true)
        phys:Wake()
        phys:SetPos(pos)
        phys:SetAngles(ang)
        if string.sub(ent:GetBoneName(b), 1, 4) == "prp_" then
            phys:EnableMotion(true)
            phys:Wake()
        else
            phys:EnableMotion(false)
            phys:Wake()
        end
    end
end

-- https://github.com/Winded/StandingPoseTool/blob/master/lua/weapons/gmod_tool/stools/ragdollstand.lua
local function matchNonPhysicalBonePoseOf(ent, targetEnt)
    for i = 0, ent:GetPhysicsObjectCount() - 1 do
        local phys = ent:GetPhysicsObjectNum(i)
        local b = ent:TranslatePhysBoneToBone(i)
        local pos, ang = targetEnt:GetBonePosition(b)
        phys:EnableMotion(true)
        phys:Wake()
        phys:SetPos(pos)
        phys:SetAngles(ang)
        if string.sub(ent:GetBoneName(b), 1, 4) == "prp_" then
            phys:EnableMotion(true)
            phys:Wake()
        else
            phys:EnableMotion(false)
            phys:Wake()
        end
    end
end

-- Set stages for showing control panel for selected entity 
function TOOL:LeftClick(tr)
    local ent = tr.Entity
    if not IsValid(ent) then return false end
    if not ent:IsRagdoll() then return false end
    if IsValid(self:GetAnimationEntity()) and self:GetAnimationEntity() == prevServerAnimEntity then return end
    local animEntity = IsValid(self:GetAnimationPuppet()) and self:GetAnimationPuppet() or ents.Create("prop_dynamic")
    animEntity:SetModel(ent:GetModel())
    self:SetAnimationEntity(ent)
    self:SetAnimationPuppet(animEntity)
    animEntity:SetPos(ent:GetPos())
    local angle = (self:GetOwner():GetPos() - ent:GetPos()):Angle()
    animEntity:SetAngles(angle)
    animEntity:Spawn()
    styleServerEntity(animEntity)
    local currentIndex = 0
    -- FIXME: Find a better implementation which doesn't involve setting a timer every time we get a new frame
    net.Receive("onFrameChange", function()
        local cycle = net.ReadFloat()
        animEntity:ResetSequence((currentIndex == 0) and (currentIndex + 1) or (currentIndex - 1))
        animEntity:ResetSequence(currentIndex)
        animEntity:SetCycle(cycle)
        animEntity:SetPlaybackRate(0)
        matchPhysicalBonePoseOf(ent, animEntity)
        timer.Simple(0.25, function() end)
    end)

    net.Receive("onAnimationChange", function()
        if not IsValid(animEntity) then return end
        local seqIndex = net.ReadInt(14)
        print("Setting sequence to", seqIndex)
        animEntity:ResetSequence(seqIndex)
        animEntity:SetCycle(0)
        animEntity:SetPlaybackRate(0)
        currentIndex = seqIndex
    end)
    return true
end

-- Stop selecting an entity
function TOOL:RightClick(tr)
    if IsValid(self:GetAnimationEntity()) then
        print("Removed animation entity to", self:GetAnimationEntity():GetModel())
        self:Cleanup()
        print(self:GetAnimationEntity())
        return true
    end
end

if SERVER then return end
local currentSequence = {
    label = ""
}

TOOL:BuildConVarList()
local function styleClientEntity(ent)
    ent:SetColor(Color(255, 0, 0, 128))
    ent:SetRenderMode(RENDERMODE_TRANSCOLOR)
end

local function constructSequenceList(CPanel)
    local animationList = vgui.Create("DListView", CPanel)
    animationList:AddColumn("Id")
    animationList:AddColumn("Name")
    animationList:AddColumn("FPS")
    animationList:AddColumn("Duration (frames)")
    CPanel:AddItem(animationList)
    return animationList
end

function TOOL.BuildCPanel(CPanel, entity, ply)
    local maxFrame = 60
    local prevFrame = 0
    -- If entity during rebuild is not valid, delete existing anim entity
    if not IsValid(entity) then
        prevClientAnimEntity:Remove()
        print("rebuild")
        return
    end

    local modelEntity = entity:GetModel()
    CPanel:Help("Current Entity: " .. modelEntity)
    local numSlider = CPanel:NumSlider("Frame", "ragdollposer_frame", 0, maxFrame, 0)
    local animEntity = prevClientAnimEntity or ents.CreateClientProp("prop_dynamic")
    animEntity:SetModel(modelEntity)
    animEntity:SetPos(entity:GetPos())
    local angle = (ply:GetPos() - entity:GetPos()):Angle()
    animEntity:SetAngles(angle)
    animEntity:Spawn()
    styleClientEntity(animEntity)
    local sequenceList = constructSequenceList(CPanel)
    for i = 0, animEntity:GetSequenceCount() - 1 do
        local seqInfo = animEntity:GetSequenceInfo(i)
        -- Assume the first animation is the "base", which may have the maximum number of frames compared to other animations in the sequence
        local animInfo = animEntity:GetAnimInfo(seqInfo.anims[1])
        sequenceList:AddLine(i, seqInfo.label, animInfo.fps, animInfo.numframes)
    end

    sequenceList:SizeTo(-1, 500, 0.5)
    sequenceList.OnRowSelected = function(panel, index, row)
        local seqInfo = animEntity:GetSequenceInfo(index - 1)
        print(currentSequence.label)
        print(seqInfo.label)
        if currentSequence.label ~= seqInfo.label then
            currentSequence = seqInfo
            animEntity:ResetSequence(index - 1)
            animEntity:SetPlaybackRate(0)
            numSlider:SetMax(row:GetValue(4))
            net.Start("onAnimationChange")
            net.WriteInt(row:GetValue(1), 14)
            net.SendToServer()
        end
    end

    -- TODO: Set a limit to how many times a new frame can be sent to the server to prevent spamming
    numSlider.OnValueChanged = function()
        if not currentSequence.anims then return end
        if math.abs(prevFrame - numSlider:GetValue()) < 1 then return end
        local numframes = animEntity:GetAnimInfo(currentSequence.anims[1]).numframes
        local cycle = numSlider:GetValue() / numframes
        animEntity:SetCycle(cycle)
        net.Start("onFrameChange", true)
        net.WriteFloat(cycle)
        net.SendToServer()
        prevFrame = numSlider:GetValue()
    end

    prevClientAnimEntity = animEntity
end

if CLIENT then
    language.Add("tool.ragdollposer.name", "Pose Ragdoll to Animation")
    language.Add("tool.ragdollposer.desc", "Pose ragdolls to any animation frame.")
    language.Add("tool.ragdollposer.0", "Left click to select a ragdoll.")
    language.Add("tool.ragdollposer.1", "Play animations through the context menu.")
end