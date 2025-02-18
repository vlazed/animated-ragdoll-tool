---@alias BoneOffset table<Vector, Angle>
---@alias BoneOffsetArray BoneOffset[]

---@module "ragdollpuppeteer.lib.smh"
local smh = include("ragdollpuppeteer/lib/smh.lua")
---@module "ragdollpuppeteer.lib.vendor"
local vendor = include("ragdollpuppeteer/lib/vendor.lua")
---@module "ragdollpuppeteer.lib.quaternion"
local quaternion = include("ragdollpuppeteer/lib/quaternion.lua")
---@module "ragdollpuppeteer.lib.bones"
local bones = include("ragdollpuppeteer/lib/bones.lua")

local lastPose = {}
local lastGesturePose = {}

-- Camera classes use the entity's position and angles
local physicsClasses = {
	["prop_physics"] = true,
}

-- Camera classes use the entity's bone position and angles
local cameraClasses = {
	["hl_camera"] = true,
	["gmod_cameraprop"] = true,
}

---@param json string
---@return table
local function decompressJSONToTable(json)
	return util.JSONToTable(util.Decompress(json))
end

local function compressTableToJSON(tab)
	return util.Compress(util.TableToJSON(tab))
end

---@param pose SMHFramePose[]
---@param puppeteer RagdollPuppeteer
local function encodePose(pose, puppeteer)
	-- Physics props indices start at 1, not at 0. In case we work with physics props, use that matrix
	local b1, b2 = puppeteer:TranslatePhysBoneToBone(0), puppeteer:TranslatePhysBoneToBone(1)
	local matrix = puppeteer:GetBoneMatrix(b1) or puppeteer:GetBoneMatrix(b2)
	local bPos, bAng = matrix:GetTranslation(), matrix:GetAngles()

	net.WriteUInt(#pose, 5)
	for i = 0, #pose do
		local hasLocal = (pose[i].LocalPos and true) or false
		net.WriteVector(pose[i].Pos or vector_origin)
		net.WriteAngle(pose[i].Ang or angle_zero)
		net.WriteVector(pose[i].Scale or Vector(-1, -1, -1))
		net.WriteBool(hasLocal)
		if hasLocal then
			net.WriteVector(pose[i].LocalPos)
			net.WriteAngle(pose[i].LocalAng)
		end
		if i == 0 then
			net.WriteVector(bPos)
			net.WriteAngle(bAng)
		end
	end
end

---Calculate the nonphysical bone offsets between two entities
---@param source Entity Entity doing the animation
---@param target Entity Entity that wants the animation
---@param sourceBone integer Source child bone index
---@param targetBone integer Target child bone index
---@return Vector positionOffset Position of child bone with respect to parent bone
---@return Angle angleOffset Angle of child bone with respect to parent bone
local function retargetNonPhysical(source, target, sourceBone, targetBone)
	local sourceReferencePose = vendor.getDefaultBonePoseOf(source)
	local targetReferencePose = vendor.getDefaultBonePoseOf(target)

	local sourceAng = quaternion.fromAngle(sourceReferencePose[sourceBone + 1][6])
	local targetAng = quaternion.fromAngle(targetReferencePose[targetBone + 1][6])
	local sourceAng2 = quaternion.fromAngle(sourceReferencePose[sourceBone + 1][2])
	local targetAng2 = quaternion.fromAngle(targetReferencePose[targetBone + 1][2])

	-- Source component rotation
	local dPos, dAng = vendor.getBoneOffsetsOf(
		source,
		sourceBone,
		sourceAng:Invert():Mul(targetAng),
		sourceAng2:Invert():Mul(targetAng2)
	)

	return dPos, dAng
end

---Calculate the physical bone offsets between two entities
---@param source Entity Entity doing the animation
---@param target Entity Entity that wants the animation
---@param sourceBone integer Source child bone index
---@param targetBone integer Target child bone index
---@return Vector positionOffset Position of child bone with respect to parent bone
---@return Angle angleOffset Angle of child bone with respect to parent bone
local function retargetPhysical(source, target, sourceBone, targetBone)
	local sourceReferencePose = vendor.getDefaultBonePoseOf(source)
	local targetReferencePose = vendor.getDefaultBonePoseOf(target)

	local sourceAng = quaternion.fromAngle(sourceReferencePose[sourceBone + 1][6])
	local targetAng = quaternion.fromAngle(targetReferencePose[targetBone + 1][6])

	-- Source component rotation
	local pos, ang = source:GetBonePosition(sourceBone)
	local qAng = quaternion.fromAngle(ang)
	qAng = qAng:Mul(sourceAng:Invert():Mul(targetAng))

	return pos, qAng:Angle()
end

---Try to manipulate the bone angles of the puppet to set the puppeteer
---@param puppeteer Entity The puppeteer to obtain nonphysical bone pose information
---@param puppet Entity The puppet to compare to if the models are different
---@return BoneOffsetArray boneOffsets An array of bone offsets from the default bone pose
local function getNonPhysicalBonePoseOf(puppeteer, puppet)
	local newPose = {}
	local defaultBonePose = vendor.getDefaultBonePoseOf(puppeteer)
	local boneMap = bones.getMap(puppeteer:GetBoneName(0), puppet:GetBoneName(0))

	for b = 0, puppeteer:GetBoneCount() - 1 do
		-- Reset bone position and angles
		local boneName = puppeteer:GetBoneName(b)
		if puppeteer:GetBoneParent(b) > -1 then
			newPose[b + 1] = {}
			local dPos, dAng = vendor.getBoneOffsetsOf(puppeteer, b)
			if puppeteer:GetModel() ~= puppet:GetModel() then
				local sourceBone = b
				local targetBone = puppet:LookupBone(boneMap and boneMap[boneName] or boneName)
				if targetBone then
					dPos, dAng = retargetNonPhysical(puppeteer, puppet, sourceBone, targetBone)
				end
			end
			newPose[b + 1][1] = dPos
			newPose[b + 1][2] = dAng
		else
			local bMatrix = puppeteer:GetBoneMatrix(b)
			local dPos, dAng = vector_origin, angle_zero
			if bMatrix then
				-- Get the position and angles of the bone with respect to the puppeteer systems
				local lPos, lAng = WorldToLocal(
					bMatrix:GetTranslation(),
					bMatrix:GetAngles(),
					puppeteer:GetPos(),
					puppeteer:GetAngles()
				)

				-- ManipulateBonePosition delta
				dPos = lPos - defaultBonePose[b + 1][1]
				-- ManipulateBoneAngles delta
				_, dAng = WorldToLocal(lPos, lAng, defaultBonePose[b + 1][1], defaultBonePose[b + 1][2])
			end

			newPose[b + 1] = {}
			newPose[b + 1][1] = dPos
			newPose[b + 1][2] = dAng
		end
	end

	return newPose
end

---@param netString string
---@param frame integer
---@param physFrames SMHFrameData[]
---@param nonPhysFrames SMHFrameData[]
---@param nonPhys boolean
local function writeSMHPose(netString, frame, physFrames, nonPhysFrames, nonPhys, puppeteer)
	local physBonePose = smh.getPoseFromSMHFrames(frame, physFrames, "physbones")
	net.Start(netString, true)
	net.WriteBool(false)
	encodePose(physBonePose, puppeteer)
	net.WriteBool(nonPhys)
	if nonPhys then
		local nonPhysBoneData = smh.getPoseFromSMHFrames(frame, nonPhysFrames, "bones")
		local compressedNonPhysPose = compressTableToJSON(nonPhysBoneData)
		net.WriteUInt(#compressedNonPhysPose, 16)
		net.WriteData(compressedNonPhysPose)
	end

	net.SendToServer()
end

---Send the client's sequence bone positions, first mutating the puppeteer with the gesturer
---https://github.com/penolakushari/StandingPoseTool/blob/b7dc7b3b57d2d940bb6a4385d01a4b003c97592c/lua/autorun/standpose.lua#L42
---@param puppeteers Entity[]
---@param puppet Entity | ResizedRagdoll
---@param physicsCount integer
---@param gesturers Entity[]
---@param gesture SequenceInfo
---@param poseOffset PoseOffset
local function writeSequencePose(puppeteers, puppet, physicsCount, gesturers, gesture, poseOffset)
	if not IsValid(puppeteers[1]) or not IsValid(puppet) then
		return
	end

	if game.SinglePlayer() then
		local isSameModel = puppeteers[1]:GetModel() == puppet:GetModel()

		local baseGesturer = gesturers[1]
		local animGesturer = gesturers[2]
		local animPuppeteer = puppeteers[1]
		local basePuppeteer = puppeteers[2]
		local viewPuppeteer = puppeteers[3]

		local puppetRoot, puppeteerRoot = puppet:TranslatePhysBoneToBone(0), viewPuppeteer:TranslatePhysBoneToBone(0)
		local boneMap = bones.getMap(puppet:GetBoneName(puppetRoot), viewPuppeteer:GetBoneName(puppeteerRoot))

		local newPose = {}

		-- FIXME: Clean up and reorganize functionality
		for i = 0, physicsCount - 1 do
			local b = puppet:TranslatePhysBoneToBone(i)
			local boneName = puppet:GetBoneName(b)
			local b2 = viewPuppeteer:LookupBone(boneMap and boneMap[boneName] or boneName)

			if gesture.anims and b2 then
				local gesturePos, gestureAng
				if animPuppeteer:GetBoneParent(b2) > -1 then
					local gPos, gAng = vendor.getBoneOffsetsOf(animGesturer, b2)
					local oPos, oAng = vendor.getBoneOffsetsOf(baseGesturer, b2)

					local oQuat = quaternion.fromAngle(oAng)
					local gQuat = quaternion.fromAngle(gAng)
					local dQuat = gQuat * oQuat:Invert()

					local dPos, dAng = gPos - oPos, dQuat:Angle()
					gesturePos, gestureAng = dPos, dAng
				else
					local gPos, gAng = animGesturer:GetBonePosition(b2)
					local oPos, oAng = baseGesturer:GetBonePosition(b2)
					if gPos and gAng and oPos and oAng then
						local _, dAng = WorldToLocal(gPos, gAng, oPos, oAng)
						local dPos = gPos - oPos
						dPos, _ = LocalToWorld(dPos, angle_zero, vector_origin, puppeteers[1]:GetAngles())

						gesturePos, gestureAng = dPos, dAng
					elseif lastGesturePose[b2] then
						gesturePos, gestureAng = lastGesturePose[b2][1], lastGesturePose[b2][2]
					end
				end

				if b2 and poseOffset[b2] then
					gesturePos, gestureAng = gesturePos + poseOffset[b2].pos, gestureAng + poseOffset[b2].ang
				end

				-- Only manipulate bone positions if the bone exists on the puppeteer
				if gesturePos and b2 then
					animPuppeteer:ManipulateBonePosition(b2, gesturePos)
					basePuppeteer:ManipulateBonePosition(b2, gesturePos)
					viewPuppeteer:ManipulateBonePosition(b2, gesturePos)
				end
				if gestureAng and b2 then
					animPuppeteer:ManipulateBoneAngles(b2, gestureAng)
					basePuppeteer:ManipulateBoneAngles(b2, gestureAng)
					viewPuppeteer:ManipulateBoneAngles(b2, gestureAng)
				end
				lastGesturePose[b2] = { gesturePos, gestureAng }
			end

			-- Let's get the phys obj transform
			---@type Vector, Angle
			local pos, ang
			if not isSameModel then
				local targetBone = b
				local sourceBone = b2
				if sourceBone then
					pos, ang = retargetPhysical(viewPuppeteer, puppet, sourceBone, targetBone)
				else
					-- If we're different models, but b2 doesn't exist for specific phys obj i for the
					-- puppeteer, let's just get the puppet's original phys obj transform
					local bMatrix = puppet:GetBoneMatrix(b)
					if bMatrix then
						pos, ang = bMatrix:GetTranslation(), bMatrix:GetAngles()
					else
						-- Somehow the bone hasn't been built yet, so we'll just return this for safety
						pos, ang = vector_origin, angle_zero
					end
				end
			else
				pos, ang = viewPuppeteer:GetBonePosition(b)
			end

			if physicsClasses[puppet:GetClass()] then
				pos, ang = puppeteers[1]:GetPos(), puppeteers[1]:GetAngles()
			elseif cameraClasses[puppet:GetClass()] then
				local bMatrix = puppeteers[3]:GetBoneMatrix(0)
				pos, ang = bMatrix and bMatrix:GetTranslation(), bMatrix and bMatrix:GetAngles()
			end

			if not pos and lastPose[i] then
				pos = lastPose[i][1]
			end

			if not ang and lastPose[i] then
				ang = lastPose[i][2]
			end

			if pos == animPuppeteer:GetPos() then
				local matrix = animPuppeteer:GetBoneMatrix(isSameModel and b2 or b)
				if matrix then
					pos = matrix:GetTranslation()
					ang = matrix:GetAngles()
				end
			end

			if i == 0 then
				local baseMatrix = basePuppeteer:GetBoneMatrix(isSameModel and b2 or b)
				local animMatrix = animPuppeteer:GetBoneMatrix(isSameModel and b2 or b)
				if baseMatrix and animMatrix and puppet.SavedBoneMatrices and puppet.SavedBoneMatrices[b] then
					local scale = puppet.SavedBoneMatrices[b]:GetScale()
					local offsetPos = (animMatrix:GetTranslation() - baseMatrix:GetTranslation()) * scale
					pos = baseMatrix:GetTranslation() + offsetPos
				end
			end

			-- Save the current bone pose, so later iterations can use it if the bone matrix doesn't exist for some reason
			newPose[i] = { pos, ang }

			net.WriteVector(pos)
			net.WriteAngle(ang)
		end

		lastPose = newPose
	end
end

---Set the puppet's physical bones to a target pose specified from the puppeteer, while offsetting with an angle
---Source: https://github.com/Winded/StopMotionHelper/blob/master/lua/smh/modifiers/physbones.lua
---@param puppet Entity | ResizedRagdoll The puppet to set the physical bone poses
---@param targetPose SMHFramePose[] The target physical pose for the puppet
---@param filteredBones integer[] Bones that will not be set to their target pose
local function setSMHPoseOf(puppet, targetPose, filteredBones, puppeteer)
	local scale = puppet.PhysObjScales and puppet.PhysObjScales[0] or Vector(1, 1, 1)

	local isEffectProp = puppet:GetClass() == "prop_dynamic"
		and puppet:GetParent()
		and puppet:GetParent():GetClass() == "prop_effect"

	if isEffectProp then
		local parent = puppet:GetParent()
		parent:SetPos(puppeteer:GetPos())
		parent:SetAngles(puppeteer:GetAngles())
	else
		for i = 0, puppet:GetPhysicsObjectCount() - 1 do
			local b = puppet:TranslatePhysBoneToBone(i)
			local phys = puppet:GetPhysicsObjectNum(i)
			local parent = puppet:GetPhysicsObjectNum(vendor.GetPhysBoneParent(puppet, i))
			if not targetPose[i] or filteredBones[b + 1] then
				continue
			end
			if targetPose[i].LocalPos then
				local pos, ang =
					LocalToWorld(targetPose[i].LocalPos, targetPose[i].LocalAng, parent:GetPos(), parent:GetAngles())
				phys:EnableMotion(false)
				phys:SetPos(pos)
				phys:SetAngles(ang)
			else
				-- Then, set target position of puppet with offset
				if i == 0 then
					local fPos, fAng = LocalToWorld(
						targetPose[i].Pos * scale,
						targetPose[i].Ang,
						targetPose[i].RootPos,
						targetPose[i].RootAng
					)

					phys:EnableMotion(false)
					phys:SetPos(fPos)
					-- Finally, set angle of puppet itself
					phys:SetAngles(fAng)
				end
			end
			phys:Wake()
		end
	end
end

---Move and orient each physical bone of the puppet using the poses sent to us from the client
---Source: https://github.com/penolakushari/StandingPoseTool/blob/b7dc7b3b57d2d940bb6a4385d01a4b003c97592c/lua/autorun/standpose.lua
---@param puppet Entity The puppet to set physical bone poses
---@param puppeteer Entity The puppeteer to use to set poses for the puppet. Only used in multiplayer
---@param filteredBones integer[] Bones that will not be set to their target pose
---@param lastPose BonePoseArray The last pose to use if the pose doesn't exist for the current bone
local function setSequencePoseOf(puppet, puppeteer, filteredBones, lastPose)
	if
		puppet:GetClass() == "prop_dynamic"
		and puppet:GetParent()
		and puppet:GetParent():GetClass() == "prop_effect"
	then
		local parent = puppet:GetParent()
		parent:SetPos(puppeteer:GetPos())
		parent:SetAngles(puppeteer:GetAngles())
	else
		if game.SinglePlayer() then
			for i = 0, puppet:GetPhysicsObjectCount() - 1 do
				local phys = puppet:GetPhysicsObjectNum(i)
				local b = puppet:TranslatePhysBoneToBone(i)

				local pos, ang = net.ReadVector(), net.ReadAngle()
				pos = pos and pos or lastPose[i][1] or vector_origin
				ang = ang and ang or lastPose[i][2] or angle_zero

				if filteredBones[b + 1] then
					continue
				end

				phys:EnableMotion(true)
				phys:Wake()
				phys:SetPos(pos and pos or lastPose[i][1])
				phys:SetAngles(ang and ang or lastPose[i][2])
				phys:EnableMotion(false)
				phys:Wake()
				lastPose[i] = { pos, ang }
			end
		else
			for i = 0, puppet:GetPhysicsObjectCount() - 1 do
				local phys = puppet:GetPhysicsObjectNum(i)
				local b = puppet:TranslatePhysBoneToBone(i)
				if filteredBones[b + 1] then
					continue
				end

				local pos, ang = lastPose[i][1] or vector_origin, lastPose[i][2] or angle_zero
				if puppeteer:GetModel() == puppet:GetModel() then
					pos, ang = puppeteer:GetBonePosition(b)
				else
					local boneName = puppet:GetBoneName(b)

					local b2 = puppeteer:LookupBone(boneName)
					if b2 then
						pos, ang = puppeteer:GetBonePosition(b2)
					end
				end

				phys:EnableMotion(true)
				phys:Wake()
				phys:SetPos(pos)
				phys:SetAngles(ang)
				if string.sub(puppet:GetBoneName(b), 1, 4) == "prp_" then
					phys:EnableMotion(true)
					phys:Wake()
				else
					phys:EnableMotion(false)
					phys:Wake()
				end

				lastPose[i] = { pos, ang }
			end
		end
	end
end

---Directly influence the ragdoll nonphysical bones from SMH data
---@param puppet Entity The puppet to set nonphysical bone poses
---@param puppeteer Entity The puppeteer to compare with the puppet if the model isn't the same
---@param targetPose SMHFramePose[] The target nonphysical bone pose for the puppet
---@param filteredBones integer[] Bones that will not be set to their target pose
---@param physBones integer[] Bone indices that map to physobj indices
---@param boneMap BoneDefinition? Mapping from the puppeteer's skeleton to the puppet's skeleton
local function setNonPhysicalBonePoseOf(puppet, puppeteer, targetPose, filteredBones, physBones, boneMap)
	for b2 = 0, puppeteer:GetBoneCount() - 1 do
		local boneName = puppeteer:GetBoneName(b2)
		local b = puppet:LookupBone(boneMap and boneMap[boneName] or boneName)

		if not b then
			continue
		end

		if filteredBones[b + 1] then
			continue
		end

		if not physBones[b] and targetPose[b2] then
			local pos, ang = targetPose[b2].Pos, targetPose[b2].Ang

			puppet:ManipulateBonePosition(b, pos)
			puppet:ManipulateBoneAngles(b, ang)
		end
		local scale = targetPose[b2].Scale
		if scale then
			puppet:ManipulateBoneScale(b, scale)
		end
	end
end

---@param ent Entity The entity to remove all bone manipulations
local function resetAllNonphysicalBonesOf(ent)
	for i = 0, ent:GetBoneCount() - 1 do
		ent:ManipulateBonePosition(i, vector_origin)
		ent:ManipulateBoneAngles(i, angle_zero)
	end
end

---Decode the SMH pose from the client
---@return SMHFramePose[]
local function decodePose()
	local pose = {}
	local poseSize = net.ReadUInt(5)
	for i = 0, poseSize do
		pose[i] = {
			Pos = 0,
			Ang = 0,
			Scale = 0,
		}

		pose[i].Pos = net.ReadVector()
		pose[i].Ang = net.ReadAngle()
		pose[i].Scale = net.ReadVector()
		local hasLocal = net.ReadBool()
		if hasLocal then
			pose[i].LocalPos = net.ReadVector()
			pose[i].LocalAng = net.ReadAngle()
		end
		if i == 0 then
			pose[i].RootPos = net.ReadVector()
			pose[i].RootAng = net.ReadAngle()
		end
	end
	return pose
end

---Helper for setting poses for SMH animations
---@param puppet Entity The puppet to set poses
---@param playerData RagdollPuppeteerPlayerField Data to control the puppet's pose
local function readSMHPose(puppet, playerData)
	-- Assumes that we are in the networking scope
	local targetPose = decodePose()
	local animatingNonPhys = net.ReadBool()
	setSMHPoseOf(puppet, targetPose, playerData.filteredBones, playerData.puppeteer)
	if animatingNonPhys then
		-- Instead of decoding the pose as we did with physical bones, we decompress some nonphysical data
		-- This apparently reduces the outgoing rate compared to encoding/decoding together or
		-- compressing/decompressing together
		local tPNPLength = net.ReadUInt(16)
		local targetPoseNonPhys = decompressJSONToTable(net.ReadData(tPNPLength))
		setNonPhysicalBonePoseOf(
			puppet,
			playerData.puppeteer,
			targetPoseNonPhys,
			playerData.filteredBones,
			playerData.physBones,
			playerData.boneMap
		)
		playerData.bonesReset = false
	elseif not playerData.bonesReset and tonumber(playerData.player:GetInfo("ragdollpuppeteer_resetnonphys")) > 0 then
		resetAllNonphysicalBonesOf(puppet)
		playerData.bonesReset = true
	end
end

---Instead of finding the nonphysical bone poses on the server, find them in the client
---We don't require the puppeteer as we always work with one puppet
---@param ply Player Who queried for the nonphysical bone pose
---@param cycle number The current frame of the puppeteer's animation
local function queryNonPhysBonePoseOfPuppet(ply, cycle)
	net.Start("queryNonPhysBonePoseOfPuppet", false)
	net.WriteFloat(cycle)
	net.Send(ply)
end

---Helper for setting poses for sequences
---@param cycle number Current frame of animation
---@param animatingNonPhys boolean Whether to set nonphysical bones or not
---@param playerData RagdollPuppeteerPlayerField Data to control the puppet's pose
local function setPuppeteerPose(cycle, animatingNonPhys, playerData)
	local player = playerData.player
	local puppet = playerData.puppet
	local puppeteer = playerData.puppeteer
	local currentIndex = playerData.currentIndex

	if not IsValid(puppet) or not IsValid(puppeteer) then
		return
	end

	-- This statement mimics a sequence change event, so it offsets its sequence to force an animation change. Might test without statement.
	puppeteer:ResetSequence((currentIndex == 0) and (currentIndex + 1) or (currentIndex - 1))
	puppeteer:ResetSequence(currentIndex)
	puppeteer:SetCycle(cycle)
	puppeteer:SetPlaybackRate(0)
	setSequencePoseOf(puppet, puppeteer, playerData.filteredBones, playerData.lastPose)
	if animatingNonPhys then
		queryNonPhysBonePoseOfPuppet(player, cycle)
		playerData.bonesReset = false
	elseif not playerData.bonesReset and tonumber(playerData.player:GetInfo("ragdollpuppeteer_resetnonphys")) > 0 then
		resetAllNonphysicalBonesOf(puppet)
		playerData.bonesReset = true
	end
end

---@param from string
---@param to string
---@return BoneDefinition?
---@return string?
local function getBoneMap(from, to)
	return bones.getMap(from, to)
end

return {
	writeSequence = writeSequencePose,
	writeSMH = writeSMHPose,
	readSMH = readSMHPose,
	readSequence = setPuppeteerPose,
	getNonPhysicalPose = getNonPhysicalBonePoseOf,
	getBoneMap = getBoneMap,
	resetNonPhysicalPose = resetAllNonphysicalBonesOf,
	setSMH = setSMHPoseOf,
	setSequence = setSequencePoseOf,
	setNonPhysicalPose = setNonPhysicalBonePoseOf,
}
