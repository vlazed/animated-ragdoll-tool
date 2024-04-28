-- TODO: move clientside code to another file
include("ragdollposer/vendor.lua")
TOOL.Category = "Poser"
TOOL.Name = "#tool.ragdollposer.name"
TOOL.Command = nil
TOOL.ConfigName = ""
TOOL.ClientConVar["frame"] = 0
TOOL.ClientConVar["animatenonphys"] = "false"
if SERVER then
    util.AddNetworkString("onFrameChange")
    util.AddNetworkString("onSequenceChange")
    util.AddNetworkString("onAngleChange")
    util.AddNetworkString("onFrameNext")
    util.AddNetworkString("onFramePrevious")
    -- TODO: direct way to update client animation puppet
    util.AddNetworkString("updateClientPosition")
    util.AddNetworkString("removeClientAnimPuppeteer")
end

local id = "ragposer_puppet"
local id2 = "ragposer_puppeteer"
local prevServerAnimPuppet = nil
local bonesReset = false
local function styleServerEntity(ent)
    ent:SetColor(Color(255, 255, 255, 0))
    ent:SetRenderMode(RENDERMODE_TRANSCOLOR)
    ent:AddEffects(EF_NODRAW)
end

function TOOL:Think()
    if self:GetAnimationPuppet() == prevServerAnimPuppet then return end
    prevServerAnimPuppet = self:GetAnimationPuppet()
    print(prevServerAnimPuppet)
    print(self:GetAnimationPuppet())
    print("")
    if CLIENT then
        self:RebuildControlPanel(self:GetAnimationPuppet(), self:GetOwner())
    end
end

function TOOL:SetAnimationPuppet(puppet)
    return self:GetWeapon():SetNWEntity(id, puppet)
end

function TOOL:GetAnimationPuppet()
    return self:GetWeapon():GetNWEntity(id)
end

function TOOL:SetAnimationPuppeteer(puppeteer)
    return self:GetWeapon():SetNWEntity(id2, puppeteer)
end

function TOOL:GetAnimationPuppeteer()
    return self:GetWeapon():GetNWEntity(id2)
end

function TOOL:Cleanup()
    if IsValid(self:GetAnimationPuppeteer()) then
        self:GetAnimationPuppeteer():Remove()
    end

    self:SetAnimationPuppet(nil)
    self:SetAnimationPuppeteer(nil)
    self:SetStage(0)
end

-- https://github.com/Winded/StopMotionHelper/blob/master/lua/smh/modifiers/physbones.lua
-- Directly influence the ragdoll physical bones from SMH data
local function setPhysicalBonePoseOf(puppet, targetPose, puppeteer, originPose, offset)
    offset = offset and Angle(offset[1], offset[2], offset[3]) or Angle(0, 0, 0)
    for i = 0, puppet:GetPhysicsObjectCount() - 1 do
        local b = puppet:TranslatePhysBoneToBone(i)
        local phys = puppet:GetPhysicsObjectNum(i)
        local parent = puppet:GetPhysicsObjectNum(GetPhysBoneParent(puppet, i))
        if not targetPose[i] then continue end
        if targetPose[i].LocalPos and targetPose[i].LocalAng then
            local pos, ang = LocalToWorld(targetPose[i].LocalPos, targetPose[i].LocalAng, parent:GetPos(), parent:GetAngles())
            phys:EnableMotion(false)
            phys:SetPos(pos)
            phys:SetAngles(ang)
            phys:Wake()
        else
            local matrix = puppeteer:GetBoneMatrix(b)
            local bPos, bAng = matrix:GetTranslation(), matrix:GetAngles()
            local dAng = targetPose[i].Ang - originPose.Ang
            local dPos = originPose.Pos - targetPose[i].Pos
            local fPos = puppeteer:LocalToWorld(WorldToLocal(bPos, angle_zero, puppeteer:GetPos(), angle_zero) - dPos)
            phys:EnableMotion(false)
            phys:SetPos(fPos)
            phys:SetAngles(bAng + dAng + offset)
            phys:Wake()
        end
    end
end

-- Directly influence the ragdoll nonphysical bones from SMH data
local function setNonPhysicalBonePoseOf(puppet, targetPose)
    for b = 0, puppet:GetBoneCount() - 1 do
        puppet:ManipulateBonePosition(b, targetPose[b].Pos)
        puppet:ManipulateBoneAngles(b, targetPose[b].Ang)
        if targetPose[b].Scale then
            puppet:ManipulateBoneScale(b, targetPose[b].Scale)
        end
    end
end

-- https://github.com/Winded/StandingPoseTool/blob/master/lua/weapons/gmod_tool/stools/ragdollstand.lua
local function matchPhysicalBonePoseOf(puppet, puppeteer)
    for i = 0, puppet:GetPhysicsObjectCount() - 1 do
        local phys = puppet:GetPhysicsObjectNum(i)
        local b = puppet:TranslatePhysBoneToBone(i)
        local pos, ang = puppeteer:GetBonePosition(b)
        phys:EnableMotion(false)
        phys:SetPos(pos)
        phys:SetAngles(ang)
        if string.sub(puppet:GetBoneName(b), 1, 4) == "prp_" then
            phys:EnableMotion(true)
            phys:Wake()
        else
            phys:Wake()
        end
    end
end

local function matchNonPhysicalBonePoseOf(puppet, puppeteer)
    if bonesReset then
        bonesReset = false
    end

    local physBoneIndices = {}
    for i = 0, puppet:GetPhysicsObjectCount() - 1 do
        physBoneIndices[puppet:TranslatePhysBoneToBone(i)] = true
    end

    for i = 0, puppet:GetBoneCount() - 1 do
        if not physBoneIndices[i] then
            -- Reset bone position and angles
            puppet:ManipulateBonePosition(i, vector_origin, false)
            puppet:ManipulateBoneAngles(i, angle_zero, false)
            -- Get world position
            local _, iang = puppet:GetBonePosition(i)
            local _, fang = puppeteer:GetBonePosition(i)
            -- TODO: Manipulate nonphysical bones from target ent which has no bone manipulations
            if puppeteer:GetBoneParent(i) > -1 then
                --local diffpos = fpos - ipos
                local diffang = fang - iang
                -- Go from world position to local bone position
                --ent:ManipulateBonePosition(i, diffpos)
                puppet:ManipulateBoneAngles(i, diffang)
            end
        end
    end
end

local function setPositionOf(puppeteer, puppet)
    local tr = util.TraceLine(
        {
            start = puppet:GetPos(),
            endpos = puppet:GetPos() - Vector(0, 0, 3000),
            filter = function(e) return e:GetClass() == game.GetWorld() end,
        }
    )

    puppeteer:SetPos(tr.HitPos)
end

local function setAngleOf(puppeteer, puppet, ply)
    local angle = (ply:GetPos() - puppet:GetPos()):Angle()
    puppeteer:SetAngles(Angle(0, angle.y, 0))
end

local function setPlacementOf(puppeteer, puppet, ply)
    setPositionOf(puppeteer, puppet)
    setAngleOf(puppeteer, puppet, ply)
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
    local ragdollPuppet = tr.Entity
    do
        local validPuppet = IsValid(ragdollPuppet)
        local isRagdoll = ragdollPuppet:IsRagdoll()
        local samePuppet = IsValid(self:GetAnimationPuppet()) and self:GetAnimationPuppet() == prevServerAnimPuppet
        if not validPuppet or not isRagdoll or samePuppet then return false end
    end

    local animPuppeteer = ents.Create("prop_dynamic")
    if self:GetAnimationPuppet() ~= ragdollPuppet then
        self:Cleanup()
    end

    animPuppeteer:SetModel(ragdollPuppet:GetModel())
    self:SetAnimationPuppet(ragdollPuppet)
    self:SetAnimationPuppeteer(animPuppeteer)
    setPlacementOf(animPuppeteer, ragdollPuppet, self:GetOwner())
    animPuppeteer:Spawn()
    styleServerEntity(animPuppeteer)
    local currentIndex = 0
    net.Receive(
        "onFrameChange",
        function()
            local isSequence = net.ReadBool()
            if isSequence then
                local cycle = net.ReadFloat()
                local animatingNonPhys = net.ReadBool()
                -- This statement mimics a sequence change event, so it offsets its sequence to force an animation change. Might test without statement. 
                animPuppeteer:ResetSequence((currentIndex == 0) and (currentIndex + 1) or (currentIndex - 1))
                animPuppeteer:ResetSequence(currentIndex)
                animPuppeteer:SetCycle(cycle)
                animPuppeteer:SetPlaybackRate(0)
                matchPhysicalBonePoseOf(ragdollPuppet, animPuppeteer)
                if animatingNonPhys then
                    matchNonPhysicalBonePoseOf(ragdollPuppet, animPuppeteer)
                elseif not bonesReset then
                    resetAllNonphysicalBonesOf(ragdollPuppet)
                end
            else
                local targetPose = net.ReadTable(false)
                local originPose = net.ReadTable(false)
                local angOffset = net.ReadTable(true)
                local animatingNonPhys = net.ReadBool()
                setPhysicalBonePoseOf(ragdollPuppet, targetPose, animPuppeteer, originPose, angOffset)
                if animatingNonPhys then
                    local targetPoseNonPhys = net.ReadTable(false)
                    setNonPhysicalBonePoseOf(ragdollPuppet, targetPoseNonPhys, animPuppeteer)
                elseif not bonesReset then
                    resetAllNonphysicalBonesOf(ragdollPuppet)
                end
            end
        end
    )

    net.Receive(
        "onSequenceChange",
        function()
            if not IsValid(animPuppeteer) then return end
            local isSequence = net.ReadBool()
            if isSequence then
                local seqIndex = net.ReadInt(14)
                local animatingNonPhys = net.ReadBool()
                currentIndex = seqIndex
                animPuppeteer:ResetSequence(seqIndex)
                animPuppeteer:SetCycle(0)
                animPuppeteer:SetPlaybackRate(0)
                matchPhysicalBonePoseOf(ragdollPuppet, animPuppeteer)
                if animatingNonPhys then
                    matchNonPhysicalBonePoseOf(ragdollPuppet, animPuppeteer)
                elseif not bonesReset then
                    resetAllNonphysicalBonesOf(ragdollPuppet)
                end
            else
                local targetPose = net.ReadTable(false)
                local originPose = net.ReadTable(false)
                local angOffset = net.ReadTable(true)
                local animatingNonPhys = net.ReadBool()
                setPhysicalBonePoseOf(ragdollPuppet, targetPose, animPuppeteer, originPose, angOffset)
                if animatingNonPhys then
                    local targetPoseNonPhys = net.ReadTable(false)
                    setNonPhysicalBonePoseOf(ragdollPuppet, targetPoseNonPhys, animPuppeteer)
                elseif not bonesReset then
                    resetAllNonphysicalBonesOf(ragdollPuppet)
                end
            end
        end
    )

    ragdollPuppet:CallOnRemove(
        "RemoveAnimPuppeteer",
        function()
            self:Cleanup()
        end
    )

    self:SetStage(1)

    return true
end

-- Stop selecting an entity
function TOOL:RightClick(tr)
    -- FIXME: Properly clear any animation entities, clientside and serverside
    if IsValid(self:GetAnimationPuppet()) then
        self:Cleanup()
        prevServerAnimPuppet = nil
        net.Start("removeClientAnimPuppeteer")
        net.Send(self:GetOwner())

        return true
    end
end

concommand.Add(
    "ragdollposer_updateposition",
    function(ply, _, _)
        if not IsValid(ply) then return end
        local tool = ply:GetTool("ragdollposer")
        local puppeteer = tool:GetAnimationPuppeteer()
        local puppet = tool:GetAnimationPuppet()
        if not IsValid(puppet) or not IsValid(puppeteer) then return end
        setPlacementOf(puppeteer, puppet, ply)
        net.Start("updateClientPosition")
        net.Send(ply)
    end
)

concommand.Add(
    "ragdollposer_previousframe",
    function(ply)
        net.Start("onFramePrevious")
        net.Send(ply)
    end
)

concommand.Add(
    "ragdollposer_nextframe",
    function(ply)
        net.Start("onFrameNext")
        net.Send(ply)
    end
)

if SERVER then return end
include("ragdollposer/smh.lua")
local prevClientAnimPuppeteer = nil
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

local function constructAngleNumSliders(dForm, names)
    local sliders = {}
    for i = 1, 3 do
        local slider = dForm:NumSlider(names[i], "", -180, 180)
        slider:Dock(TOP)
        slider:SetValue(0)
        sliders[i] = slider
    end

    return sliders
end

local function constructAngleNumSliderTrio(cPanel, names, label)
    local dForm = vgui.Create("DForm")
    dForm:SetLabel(label)
    local angleSliders = constructAngleNumSliders(dForm, names)
    cPanel:AddItem(dForm)
    local resetAngles = dForm:Button("Reset Angles")
    function resetAngles:DoClick()
        for i = 1, 3 do
            angleSliders[i]:SetValue(0)
        end
    end

    return angleSliders
end

local function findLongestAnimationIn(sequenceInfo, animEntity)
    local longestAnim = {
        numframes = -1
    }

    for _, anim in pairs(sequenceInfo.anims) do
        local animInfo = animEntity:GetAnimInfo(anim)
        if not (animInfo and animInfo.numframes) then continue end
        if animInfo.numframes > longestAnim.numframes then
            longestAnim = animInfo
        end
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
            if lmax > maxFrames then
                maxFrames = lmax
            end
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

local function getAngleTrio(trio)
    return {trio[1]:GetValue(), trio[2]:GetValue(), trio[3]:GetValue()}
end

function TOOL.BuildCPanel(cPanel, entity, ply)
    if not IsValid(entity) then
        cPanel:Help("No entity selected")

        return
    end

    local defaultMaxFrame = 60
    local prevFrame = 0
    local model = entity:GetModel()
    local animPuppeteer = ClientsideModel(model, RENDERGROUP_TRANSLUCENT)
    if IsValid(prevClientAnimPuppeteer) then
        prevClientAnimPuppeteer:Remove()
    end

    animPuppeteer:SetModel(model)
    setPlacementOf(animPuppeteer, entity, ply)
    animPuppeteer:Spawn()
    styleClientEntity(animPuppeteer)
    -- UI Elements
    local entityLabel = cPanel:Help("Current Entity: " .. model)
    local numSlider = cPanel:NumSlider("Frame", "ragdollposer_frame", 0, defaultMaxFrame - 1, 0)
    local angOffset = constructAngleNumSliderTrio(cPanel, {"Pitch", "Yaw", "Roll"}, "Angle Offset")
    local nonPhysCheckbox = cPanel:CheckBox("Animate Nonphysical Bones", "ragdollposer_animatenonphys")
    cPanel:Button("Update Puppeteer Position", "ragdollposer_updateposition", animPuppeteer)
    local sourceBox = cPanel:ComboBox("Source")
    sourceBox:AddChoice("Sequence")
    sourceBox:AddChoice("Stop Motion Helper")
    sourceBox:ChooseOption("Sequence", 1)
    local searchBar = cPanel:TextEntry("Search Bar:")
    searchBar:SetPlaceholderText("Search for a sequence...")
    local sequenceList = constructSequenceList(cPanel)
    local smhBrowser = constructSMHFileBrowser(cPanel)
    local smhList = constructSMHEntityList(cPanel)
    sequenceList:Dock(TOP)
    smhList:Dock(TOP)
    smhBrowser:Dock(TOP)
    populateSequenceList(sequenceList, animPuppeteer, function(_) return true end)
    smhList:SizeTo(-1, 0, 0.5)
    smhBrowser:SizeTo(-1, 0, 0.5)
    sequenceList:SizeTo(-1, 500, 0.5)
    local function sendSMHPose(netString, frame)
        if not smhList:GetSelected()[1] then return end
        local physBoneData = getPoseFromSMHFrames(frame, smhList:GetSelected()[1]:GetSortValue(3), "physbones")
        local originPhysBonePose = getPoseFromSMHFrames(0, smhList:GetSelected()[1]:GetSortValue(3), "physbones")[0]
        net.Start(netString, true)
        net.WriteBool(false)
        net.WriteTable(physBoneData, false)
        net.WriteTable(originPhysBonePose, false)
        net.WriteTable(getAngleTrio(angOffset), true)
        net.WriteBool(nonPhysCheckbox:GetChecked())
        if nonPhysCheckbox:GetChecked() then
            local nonPhysBoneData = getPoseFromSMHFrames(frame, smhList:GetSelected()[1]:GetSortValue(3), "bones")
            net.WriteTable(nonPhysBoneData, false)
        end

        net.SendToServer()
    end

    local function onAngleTrioValueChange()
        sendSMHPose("onFrameChange", numSlider:GetValue())
    end

    -- UI Hooks
    function searchBar:OnEnter(text)
        if sourceBox:GetSelected() == "Sequence" then
            clearList(sequenceList)
            populateSequenceList(
                sequenceList,
                animPuppeteer,
                function(seqInfo)
                    if text:len() > 0 then
                        return string.find(seqInfo.label, text)
                    else
                        return true
                    end
                end
            )
        else
            populateSMHEntitiesList(
                smhList,
                animPuppeteer,
                function(entProp)
                    if text:len() > 0 then
                        return entProp == text
                    else
                        return true
                    end
                end
            )
        end
    end

    function sequenceList:OnRowSelected(index, row)
        local seqInfo = animPuppeteer:GetSequenceInfo(row:GetValue(1))
        if currentSequence.label ~= seqInfo.label then
            currentSequence = seqInfo
            animPuppeteer:ResetSequence(row:GetValue(1))
            animPuppeteer:SetCycle(0)
            animPuppeteer:SetPlaybackRate(0)
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
            if not IsValid(animPuppeteer) then return end
            local numframes = findLongestAnimationIn(currentSequence, animPuppeteer).numframes - 1
            numSlider:SetValue(math.Clamp(val, 0, numframes))
            local cycle = val / numframes
            animPuppeteer:SetCycle(cycle)
            net.Start("onFrameChange", true)
            net.WriteBool(true)
            net.WriteFloat(cycle)
            net.WriteBool(nonPhysCheckbox:GetChecked())
            net.SendToServer()
        else
            sendSMHPose("onFrameChange", val)
        end

        prevFrame = val
    end

    angOffset[1].OnValueChanged = onAngleTrioValueChange
    angOffset[2].OnValueChanged = onAngleTrioValueChange
    angOffset[3].OnValueChanged = onAngleTrioValueChange
    function sourceBox:OnSelect(ind, val, data)
        if val == "Sequence" then
            smhList:SizeTo(-1, 0, 0.5)
            smhBrowser:SizeTo(-1, 0, 0.5)
            sequenceList:SizeTo(-1, 500, 0.5)
        else
            sequenceList:SizeTo(-1, 0, 0.5)
            smhList:SizeTo(-1, 250, 0.5)
            smhBrowser:SizeTo(-1, 250, 0.5)
        end
    end

    function smhList:OnRowSelected(index, row)
        numSlider:SetMax(row:GetValue(2))
        sendSMHPose("onSequenceChange", 0)
    end

    function smhBrowser:OnSelect(filePath)
        clearList(smhList)
        local data = parseSMHFile(filePath, model)
        populateSMHEntitiesList(smhList, model, data, function(_) return true end)
    end

    -- Network Hooks
    net.Receive(
        "onFramePrevious",
        function()
            numSlider:SetValue((numSlider:GetValue() - 1) % numSlider:GetMax())
        end
    )

    net.Receive(
        "onFrameNext",
        function()
            numSlider:SetValue((numSlider:GetValue() + 1) % numSlider:GetMax())
        end
    )

    net.Receive(
        "updateClientPosition",
        function()
            setPlacementOf(animPuppeteer, entity, ply)
        end
    )

    net.Receive(
        "removeClientAnimPuppeteer",
        function()
            if IsValid(animPuppeteer) then
                animPuppeteer:Remove()
                prevClientAnimPuppeteer = nil
                clearList(sequenceList)
                clearList(smhList)
                entityLabel:SetText("No entity selected.")
            end
        end
    )

    -- End of lifecycle events
    entity:CallOnRemove(
        "RemoveAnimPuppeteer",
        function()
            if IsValid(animPuppeteer) then
                animPuppeteer:Remove()
                prevClientAnimPuppeteer = nil
                clearList(sequenceList)
                clearList(smhList)
                entityLabel:SetText("No entity selected.")
            end
        end
    )

    prevClientAnimPuppeteer = animPuppeteer
end

function TOOL:DrawToolScreen(width, height)
    --surface.SetDrawColor(Color(20, 20, 20))
    local white = Color(200, 200, 200)
    local frame = GetConVar("ragdollposer_frame")
    draw.SimpleText("Ragdoll Poser", "DermaLarge", width / 2, height - height / 1.75, white, TEXT_ALIGN_CENTER, TEXT_ALIGN_BOTTOM)
    draw.SimpleText("Current Frame: " .. frame:GetString(), "GModToolSubtitle", width / 2, height / 2, white, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
end

TOOL.Information = {
    {
        name = "info",
        stage = 1
    },
    {
        name = "left",
        stage = 0
    },
    {
        name = "right",
        stage = 1
    }
}

language.Add("tool.ragdollposer.name", "Pose Ragdoll to Animation")
language.Add("tool.ragdollposer.desc", "Pose ragdolls to any animation frame")
language.Add("tool.ragdollposer.0", "Select a ragdoll")
language.Add("tool.ragdollposer.1", "Play animations through the context menu")
language.Add("tool.ragdollposer.left", "Select ragdoll to pose")
language.Add("tool.ragdollposer.right", "Deselect ragdoll to pose")