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

local getDefaultBonePoseOf, getBoneOffsetsOf, GetPhysBoneParent =
	vendor.getDefaultBonePoseOf, vendor.getBoneOffsetsOf, vendor.GetPhysBoneParent

local getPoseFromSMHFrames = smh.getPoseFromSMHFrames

local getMap, getPhysMap = bones.getMap, bones.getPhysMap

-- Aliases to indices of DefaultBonePoseArray type
local LOCAL_ANGLES = 2
local WORLD_ANGLES = 4

---@param json string
---@return table
local function decompressJSONToTable(json)
	return util.JSONToTable(util.Decompress(json))
end

local function compressTableToJSON(tab)
	return util.Compress(util.TableToJSON(tab))
end

---Calculate the nonphysical bone offsets between two entities
---@param source Entity Entity doing the animation
---@param target Entity Entity that wants the animation
---@param sourceBone integer Source child bone index
---@param targetBone integer Target child bone index
---@return Vector positionOffset Position of child bone with respect to parent bone
---@return Angle angleOffset Angle of child bone with respect to parent bone
local function retargetNonPhysical(source, target, sourceBone, targetBone)
	local sourceReferencePose = getDefaultBonePoseOf(source)
	local targetReferencePose = getDefaultBonePoseOf(target)

	local sourceAng = quaternion.fromAngle(sourceReferencePose[sourceBone + 1][6])
	local targetAng = quaternion.fromAngle(targetReferencePose[targetBone + 1][6])
	local sourceAng2 = quaternion.fromAngle(sourceReferencePose[sourceBone + 1][2])
	local targetAng2 = quaternion.fromAngle(targetReferencePose[targetBone + 1][2])

	-- Source component rotation
	local dPos, dAng =
		getBoneOffsetsOf(source, sourceBone, sourceAng:Invert():Mul(targetAng), sourceAng2:Invert():Mul(targetAng2))

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
	local sourceReferencePose = getDefaultBonePoseOf(source)
	local targetReferencePose = getDefaultBonePoseOf(target)

	local sourceAng = quaternion.fromAngle(sourceReferencePose[sourceBone + 1][6])
	local targetAng = quaternion.fromAngle(targetReferencePose[targetBone + 1][6])

	-- Source component rotation
	local pos, ang = source:GetBonePosition(sourceBone)
	local oldSourceAng = quaternion.fromAngle(ang)
	oldSourceAng = oldSourceAng:Mul(sourceAng:Invert():Mul(targetAng))

	return pos, oldSourceAng:Angle()
end

local writeSMHPose
do
	---@param puppeteer RagdollPuppeteer|Entity
	---@param puppet Entity
	---@param smhModel string?
	---@return Entity
	---@return Entity
	---@return BoneDefinition?
	---@return DefaultBonePoseArray
	---@return DefaultBonePoseArray
	local function setupSMHRetargeting(puppeteer, puppet, smhModel, boneMap)
		local source, target = puppeteer, puppet
		if smhModel then
			source = ents.CreateClientProp()
			source:SetModel(smhModel)
			source:DrawModel()
			source:SetupBones()
			source:InvalidateBoneCache()
			source:Spawn()
		end
		local sourceRoot, targetRoot = source:TranslatePhysBoneToBone(0), target:TranslatePhysBoneToBone(0)
		local from, to = source:GetBoneName(sourceRoot), target:GetBoneName(targetRoot)
		if from ~= to and not boneMap then
			boneMap = getMap(from, to)
		end

		local sourceReferencePose = getDefaultBonePoseOf(source)
		local targetReferencePose = getDefaultBonePoseOf(target)

		return source, target, boneMap, sourceReferencePose, targetReferencePose
	end

	---@param pose SMHFramePose[]
	---@param source Entity
	---@param target Entity
	---@param boneMap BoneDefinition?
	---@param sourceReferencePose DefaultBonePoseArray
	---@param targetReferencePose DefaultBonePoseArray
	---@param index integer
	local function retargetSMHPose(pose, source, target, boneMap, sourceReferencePose, targetReferencePose, index)
		for i = 0, #pose do
			local bone = i
			if index == WORLD_ANGLES then
				bone = source:TranslatePhysBoneToBone(i)
			end
			local sourceBoneName = source:GetBoneName(bone)
			local sourceBone, targetBone =
				bone, target:LookupBone(boneMap and boneMap[sourceBoneName] or sourceBoneName)

			if targetBone then
				if pose[i].LocalAng then
					---@diagnostic disable-next-line: param-type-mismatch
					local sourceAng = quaternion.fromAngle(sourceReferencePose[sourceBone + 1][index])
					---@diagnostic disable-next-line: param-type-mismatch
					local targetAng = quaternion.fromAngle(targetReferencePose[targetBone + 1][index])

					local oldSourceAng = quaternion.fromAngle(pose[i].LocalAng)
					pose[i].LocalAng = oldSourceAng:Mul(sourceAng:Invert()):Mul(targetAng):Angle()
				end

				if pose[i].RootAng and index == WORLD_ANGLES then
					---@diagnostic disable-next-line: param-type-mismatch
					local sourceAng = quaternion.fromAngle(sourceReferencePose[sourceBone + 1][6])
					---@diagnostic disable-next-line: param-type-mismatch
					local targetAng = quaternion.fromAngle(targetReferencePose[targetBone + 1][6])

					local oldSourceAng = quaternion.fromAngle(pose[i].RootAng)
					pose[i].RootAng = oldSourceAng:Mul(sourceAng:Invert()):Mul(targetAng):Angle()
				end
				if pose[i].Ang and index == WORLD_ANGLES then
					---@diagnostic disable-next-line: param-type-mismatch
					local sourceAng = quaternion.fromAngle(sourceReferencePose[sourceBone + 1][6])
					---@diagnostic disable-next-line: param-type-mismatch
					local targetAng = quaternion.fromAngle(targetReferencePose[targetBone + 1][6])

					local oldSourceAng = quaternion.fromAngle(pose[i].Ang)
					pose[i].Ang = oldSourceAng:Mul(sourceAng:Invert()):Mul(targetAng):Angle()
				end
			end
		end
	end

	---@param pose SMHFramePose[]
	---@param puppeteer RagdollPuppeteer
	---@param puppet Entity
	---@param smhModel string?
	---@param boneMap BoneDefinition
	---@return SMHFramePose[]
	local function retargetSMHPhysicalPose(pose, puppeteer, puppet, smhModel, boneMap)
		local source, target, boneMap, sourceReferencePose, targetReferencePose =
			setupSMHRetargeting(puppeteer, puppet, smhModel, boneMap)
		retargetSMHPose(pose, source, target, boneMap, sourceReferencePose, targetReferencePose, WORLD_ANGLES)

		-- FIXME: It's messy to add and remove these props for retargeting. What else works better?
		if source:GetClass() == "class C_PhysPropClientside" then
			source:Remove()
		end

		return pose
	end

	---@param pose SMHFramePose[]
	---@param puppeteer RagdollPuppeteer|Entity
	---@param puppet Entity
	---@param smhModel string?
	---@param boneMap BoneDefinition
	---@return SMHFramePose[]
	local function retargetSMHNonPhysicalPose(pose, puppeteer, puppet, smhModel, boneMap)
		local source, target, boneMap, sourceReferencePose, targetReferencePose =
			setupSMHRetargeting(puppeteer, puppet, smhModel, boneMap)
		retargetSMHPose(pose, source, target, boneMap, sourceReferencePose, targetReferencePose, LOCAL_ANGLES)

		-- FIXME: It's messy to add and remove these props for retargeting. What else works better?
		if source:GetClass() == "class C_PhysPropClientside" then
			source:Remove()
		end

		return pose
	end

	---@param pose SMHFramePose[]
	---@param puppeteer RagdollPuppeteer
	---@param puppet Entity
	---@param smhModel string?
	---@param boneMap BoneDefinition
	local function encodePose(pose, puppeteer, puppet, smhModel, boneMap)
		-- Physics props indices start at 1, not at 0. In case we work with physics props, use that matrix
		local b1, b2 = puppeteer:TranslatePhysBoneToBone(0), puppeteer:TranslatePhysBoneToBone(1)
		local matrix = puppeteer:GetBoneMatrix(b1) or puppeteer:GetBoneMatrix(b2)
		local bPos, bAng = matrix:GetTranslation(), matrix:GetAngles()

		pose[0].RootPos = bPos
		pose[0].RootAng = bAng

		local puppetModel = puppet:GetModel()
		if puppeteer:GetModel() ~= puppetModel or smhModel ~= puppetModel then
			pose = retargetSMHPhysicalPose(pose, puppeteer, puppet, smhModel, boneMap)
		end

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
				net.WriteVector(pose[i].RootPos)
				net.WriteAngle(pose[i].RootAng)
			end
		end
	end

	---Helper for sending both a physical and nonphysical SMH pose
	---@param netString 'rp_onFrameChange'|'rp_onSequenceChange' The name of the network string defined in `net.lua`. Usually `rp_onFrameChange` or `rp_onSequenceChange`
	---@param frame integer The position of a physical or nonphysical pose in the `SMHFrameData`
	---@param physFrames SMHFrameData[] A sequence of physical poses
	---@param nonPhysFrames SMHFrameData[] A sequence of nonphysical poses
	---@param nonPhys boolean Whether nonphysical bone poses (e.g. finger posing) should be sent
	---@param puppeteer RagdollPuppeteer A puppeteer for retargeting if the puppet or puppeteer are different
	---@param puppet Entity A puppet for retargeting if the puppet or puppeteer are different
	---@param smhModel string The model that was used in the `physFrames` (or `nonPhysFrames`), for retargeting if the puppet or puppeteer models differ from this one
	---@param panelState PanelState The current condition of the Ragdoll Puppeteer panel
	function writeSMHPose(netString, frame, physFrames, nonPhysFrames, nonPhys, puppeteer, puppet, smhModel, panelState)
		local physPose = getPoseFromSMHFrames(frame, physFrames, "physbones")
		net.Start(netString, true)
		net.WriteBool(false)
		encodePose(physPose, puppeteer, puppet, smhModel, panelState.boneMap)
		net.WriteBool(nonPhys)
		net.WriteString(smhModel)
		if nonPhys then
			local nonPhysPose = getPoseFromSMHFrames(frame, nonPhysFrames, "bones")
			local puppetModel = puppet:GetModel()
			if puppeteer:GetModel() ~= puppetModel or puppetModel ~= smhModel then
				nonPhysPose = retargetSMHNonPhysicalPose(nonPhysPose, puppeteer, puppet, smhModel, panelState.boneMap)
			end
			local compressedNonPhysPose = compressTableToJSON(nonPhysPose)
			net.WriteUInt(#compressedNonPhysPose, 16)
			net.WriteData(compressedNonPhysPose)
		end

		net.SendToServer()
	end
end

---Try to manipulate the bone angles of the puppet to set the puppeteer
---@param puppeteer Entity The puppeteer to obtain nonphysical bone pose information
---@param puppet Entity The puppet to compare to if the models are different
---@param boneMap BoneDefinition? A mapping from a puppeteer's bones to the puppet's
---@return BoneOffsetArray boneOffsets An array of bone offsets from the default bone pose
local function getNonPhysicalBonePoseOf(puppeteer, puppet, boneMap)
	local newPose = {}
	local defaultBonePose = getDefaultBonePoseOf(puppeteer)
	local from, to = puppeteer:GetBoneName(0), puppet:GetBoneName(0)
	if from ~= to and not boneMap then
		boneMap = getMap(from, to)
	end

	for b = 0, puppeteer:GetBoneCount() - 1 do
		-- Reset bone position and angles
		local boneName = puppeteer:GetBoneName(b)
		if puppeteer:GetBoneParent(b) > -1 then
			newPose[b + 1] = {}
			local dPos, dAng = getBoneOffsetsOf(puppeteer, b)
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

local writeSequencePose
do
	-- Camera classes use the entity's position and angles
	local physicsClasses = {
		["prop_physics"] = true,
	}

	-- Camera classes use the entity's bone position and angles
	local cameraClasses = {
		["hl_camera"] = true,
		["gmod_cameraprop"] = true,
	}

	local clientLastGesturePose = {}
	---Mutate the puppeteer with the gesture and pose offsets
	---@param puppeteers RagdollPuppeteer[]
	---@param gesturers RagdollPuppeteer[]
	---@param sourceBone integer
	---@param poseOffset PoseOffset
	local function applyPhysicalOffsetsToPuppeteer(puppeteers, gesturers, sourceBone, poseOffset)
		local baseGesturer = gesturers[1]
		local animGesturer = gesturers[2]
		local animPuppeteer = puppeteers[1]
		local basePuppeteer = puppeteers[2]
		local viewPuppeteer = puppeteers[3]

		local gesturePos, gestureAng
		if animPuppeteer:GetBoneParent(sourceBone) > -1 then
			local gPos, gAng = getBoneOffsetsOf(animGesturer, sourceBone)
			local oPos, oAng = getBoneOffsetsOf(baseGesturer, sourceBone)

			local oQuat = quaternion.fromAngle(oAng)
			local gQuat = quaternion.fromAngle(gAng)
			local dQuat = gQuat * oQuat:Invert()

			local dPos, dAng = gPos - oPos, dQuat:Angle()
			gesturePos, gestureAng = dPos, dAng
		else
			local gPos, gAng = animGesturer:GetBonePosition(sourceBone)
			local oPos, oAng = baseGesturer:GetBonePosition(sourceBone)
			if gPos and gAng and oPos and oAng then
				local _, dAng = WorldToLocal(gPos, gAng, oPos, oAng)
				local dPos = gPos - oPos
				dPos, _ = LocalToWorld(dPos, angle_zero, vector_origin, animPuppeteer:GetAngles())

				gesturePos, gestureAng = dPos, dAng
			elseif clientLastGesturePose[sourceBone] then
				gesturePos, gestureAng = clientLastGesturePose[sourceBone][1], clientLastGesturePose[sourceBone][2]
			end
		end

		if sourceBone and poseOffset[sourceBone] then
			gesturePos, gestureAng = gesturePos + poseOffset[sourceBone].pos, gestureAng + poseOffset[sourceBone].ang
		end

		-- Only manipulate bone positions if the bone exists on the puppeteer
		if gesturePos and sourceBone then
			animPuppeteer:ManipulateBonePosition(sourceBone, gesturePos)
			basePuppeteer:ManipulateBonePosition(sourceBone, gesturePos)
			viewPuppeteer:ManipulateBonePosition(sourceBone, gesturePos)
		end
		if gestureAng and sourceBone then
			animPuppeteer:ManipulateBoneAngles(sourceBone, gestureAng)
			basePuppeteer:ManipulateBoneAngles(sourceBone, gestureAng)
			viewPuppeteer:ManipulateBoneAngles(sourceBone, gestureAng)
		end
		clientLastGesturePose[sourceBone] = { gesturePos, gestureAng }
	end

	---Mutate the puppeteer with the pose offsets
	---@param puppeteers RagdollPuppeteer[]
	---@param sourceBone integer
	---@param boneOffset PoseOffset
	local function applyNonPhysicalOffsetsToPuppeteer(puppeteers, sourceBone, boneOffset)
		local animPuppeteer = puppeteers[1]
		local basePuppeteer = puppeteers[2]
		local viewPuppeteer = puppeteers[3]

		local offsetPos, offsetAng
		if sourceBone and boneOffset[sourceBone] then
			offsetPos, offsetAng = boneOffset[sourceBone].pos, boneOffset[sourceBone].ang
		end

		-- Only manipulate bone positions if the bone exists on the puppeteer
		if offsetPos and sourceBone then
			animPuppeteer:ManipulateBonePosition(sourceBone, offsetPos)
			basePuppeteer:ManipulateBonePosition(sourceBone, offsetPos)
			viewPuppeteer:ManipulateBonePosition(sourceBone, offsetPos)
		end
		if offsetAng and sourceBone then
			animPuppeteer:ManipulateBoneAngles(sourceBone, offsetAng)
			basePuppeteer:ManipulateBoneAngles(sourceBone, offsetAng)
			viewPuppeteer:ManipulateBoneAngles(sourceBone, offsetAng)
		end
	end

	local clientLastPose = {}
	---@param puppeteers RagdollPuppeteer[]
	---@param puppet Entity | ResizedRagdoll
	---@param sourceBone integer
	---@param targetBone integer
	---@param poseIndex integer
	---@return Vector
	---@return Angle
	local function getPhysObjectTransform(puppeteers, puppet, sourceBone, targetBone, poseIndex)
		local isSameModel = puppeteers[1]:GetModel() == puppet:GetModel()

		local animPuppeteer = puppeteers[1]
		local basePuppeteer = puppeteers[2]
		local viewPuppeteer = puppeteers[3]

		-- Let's get the puppet's phys obj transform
		local pos, ang
		if not isSameModel then
			if sourceBone then
				pos, ang = retargetPhysical(viewPuppeteer, puppet, sourceBone, targetBone)
			else
				-- If we're different models, but sourceBone doesn't exist for specific phys obj i for the
				-- puppeteer, let's just get the puppet's original phys obj transform
				local bMatrix = puppet:GetBoneMatrix(targetBone)
				if bMatrix then
					pos, ang = bMatrix:GetTranslation(), bMatrix:GetAngles()
				else
					-- Somehow the bone hasn't been built yet, so we'll just return this for safety
					pos, ang = vector_origin, angle_zero
				end
			end
		else
			pos, ang = viewPuppeteer:GetBonePosition(targetBone)
		end

		if physicsClasses[puppet:GetClass()] then
			pos, ang = puppeteers[1]:GetPos(), puppeteers[1]:GetAngles()
		elseif cameraClasses[puppet:GetClass()] then
			local bMatrix = puppeteers[3]:GetBoneMatrix(0)
			pos, ang = bMatrix and bMatrix:GetTranslation(), bMatrix and bMatrix:GetAngles()
		end

		if not pos and clientLastPose[poseIndex] then
			pos = clientLastPose[poseIndex][1]
		end

		if not ang and clientLastPose[poseIndex] then
			ang = clientLastPose[poseIndex][2]
		end

		if pos == animPuppeteer:GetPos() then
			local matrix = animPuppeteer:GetBoneMatrix(isSameModel and sourceBone or targetBone)
			if matrix then
				pos = matrix:GetTranslation()
				ang = matrix:GetAngles()
			end
		end

		if poseIndex == 0 then
			local baseMatrix = basePuppeteer:GetBoneMatrix(isSameModel and sourceBone or targetBone)
			local animMatrix = animPuppeteer:GetBoneMatrix(isSameModel and sourceBone or targetBone)
			if baseMatrix and animMatrix and puppet.SavedBoneMatrices and puppet.SavedBoneMatrices[targetBone] then
				local scale = puppet.SavedBoneMatrices[targetBone]:GetScale()
				local offsetPos = (animMatrix:GetTranslation() - baseMatrix:GetTranslation()) * scale
				pos = baseMatrix:GetTranslation() + offsetPos
			end
		end

		return pos, ang
	end

	---Send the client's sequence bone positions, first mutating the puppeteer with the gesturer
	---@source https://github.com/penolakushari/StandingPoseTool/blob/b7dc7b3b57d2d940bb6a4385d01a4b003c97592c/lua/autorun/standpose.lua#L42
	---@param puppeteers RagdollPuppeteer[] An array of the client's puppeteers, posed to a sequence
	---@param puppet Entity | ResizedRagdoll The entity controlled by its puppeteer for sequence posing
	---@param physicsCount integer The number of physics objects on the `puppet`
	---@param gesturers Entity[] An array of the client's gestures, as a workaround to sequence layering on the client
	---@param gesture SequenceInfo The sequence played by the gesturers
	---@param panelState PanelState The current condition of the Ragdoll Puppeteer panel
	function writeSequencePose(puppeteers, puppet, physicsCount, gesturers, gesture, panelState)
		if not IsValid(puppeteers[1]) or not IsValid(puppet) then
			return
		end

		if game.SinglePlayer() then
			local puppetRoot, puppeteerRoot =
				puppet:TranslatePhysBoneToBone(0), puppeteers[3]:TranslatePhysBoneToBone(0)
			local from, to = puppet:GetBoneName(puppetRoot), puppeteers[3]:GetBoneName(puppeteerRoot)
			local boneMap = panelState.boneMap
			if from ~= to and not boneMap then
				boneMap = getMap(from, to)
				panelState.boneMap = boneMap
				if boneMap then
					panelState.inverseBoneMap = table.Flip(boneMap)
				end
			end

			local newPose = {}

			for i = 0, puppeteers[3]:GetBoneCount() - 1 do
				local targetBoneName = puppet:GetBoneName(i)
				local sourceBone = puppeteers[3]:LookupBone(boneMap and boneMap[targetBoneName] or targetBoneName)

				applyNonPhysicalOffsetsToPuppeteer(puppeteers, sourceBone, panelState.offsets)
			end

			for i = 0, physicsCount - 1 do
				local targetBone = puppet:TranslatePhysBoneToBone(i)
				local targetBoneName = puppet:GetBoneName(targetBone)
				local sourceBone = puppeteers[3]:LookupBone(boneMap and boneMap[targetBoneName] or targetBoneName)

				if gesture.anims and sourceBone then
					applyPhysicalOffsetsToPuppeteer(puppeteers, gesturers, sourceBone, panelState.offsets)
				end

				---@type Vector, Angle
				local pos, ang = getPhysObjectTransform(puppeteers, puppet, sourceBone, targetBone, i)

				-- Save the current bone pose, so later iterations can use it if the bone matrix doesn't exist for some reason
				newPose[i] = { pos, ang }

				net.WriteVector(pos)
				net.WriteAngle(ang)
			end

			clientLastPose = newPose
		end
	end
end

---Set the puppet's physical bones to a target pose specified from the puppeteer, while offsetting with an angle
---@source https://github.com/Winded/StopMotionHelper/blob/master/lua/smh/modifiers/physbones.lua
---@param puppet Entity | ResizedRagdoll The puppet to set the physical bone poses
---@param targetPose SMHFramePose[] The target physical pose for the puppet
---@param filteredBones integer[] Bones that will not be set to their target pose
---@param puppeteer RagdollPuppeteer | Entity
---@param boneMap BoneDefinition?
local function setSMHPoseOf(puppet, targetPose, filteredBones, puppeteer, boneMap)
	local scale = puppet.PhysObjScales and puppet.PhysObjScales[0] or Vector(1, 1, 1)

	local isEffectProp = puppet:GetClass() == "prop_dynamic"
		and puppet:GetParent()
		and puppet:GetParent():GetClass() == "prop_effect"

	local physMap = getPhysMap(puppeteer, puppet, boneMap)

	if isEffectProp then
		local parent = puppet:GetParent()
		parent:SetPos(puppeteer:GetPos())
		parent:SetAngles(puppeteer:GetAngles())
	else
		-- For retargeting purposes, we'll iterate through all possible physobjects
		for i = 0, 31 do
			local sourceBone = puppeteer:TranslatePhysBoneToBone(i)
			if not targetPose[i] or filteredBones[sourceBone + 1] then
				continue
			end

			local targetPhysBone = physMap and physMap[i] or i

			local phys = puppet:GetPhysicsObjectNum(targetPhysBone)
			if not IsValid(phys) then
				continue
			end

			local parent = puppet:GetPhysicsObjectNum(GetPhysBoneParent(puppet, targetPhysBone))
			if targetPose[i].LocalPos and parent then
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
---@source https://github.com/penolakushari/StandingPoseTool/blob/b7dc7b3b57d2d940bb6a4385d01a4b003c97592c/lua/autorun/standpose.lua
---@param puppet Entity The puppet to set physical bone poses
---@param puppeteer Entity The puppeteer to use to set poses for the puppet. Only used in multiplayer
---@param filteredBones integer[] Bones that will not be set to their target pose
---@param serverLastPose BonePoseArray The last pose to use if the pose doesn't exist for the current bone
local function setSequencePoseOf(puppet, puppeteer, filteredBones, serverLastPose)
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
				pos = pos and pos or serverLastPose[i][1] or vector_origin
				ang = ang and ang or serverLastPose[i][2] or angle_zero

				if filteredBones[b + 1] then
					continue
				end

				phys:EnableMotion(true)
				phys:Wake()
				phys:SetPos(pos and pos or serverLastPose[i][1])
				phys:SetAngles(ang and ang or serverLastPose[i][2])
				phys:EnableMotion(false)
				phys:Wake()
				serverLastPose[i] = { pos, ang }
			end
		else
			for i = 0, puppet:GetPhysicsObjectCount() - 1 do
				local phys = puppet:GetPhysicsObjectNum(i)
				local b = puppet:TranslatePhysBoneToBone(i)
				if filteredBones[b + 1] then
					continue
				end

				local pos, ang =
					serverLastPose[i] and serverLastPose[i][1] or vector_origin,
					serverLastPose[i] and serverLastPose[i][2] or angle_zero
				if puppeteer:GetModel() == puppet:GetModel() then
					pos, ang = puppeteer:GetBonePosition(b)
				else
					local boneName = puppet:GetBoneName(b)

					local sourceBone = puppeteer:LookupBone(boneName)
					if sourceBone then
						pos, ang = puppeteer:GetBonePosition(sourceBone)
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

				serverLastPose[i] = { pos, ang }
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
		if targetPose[b2] then
			local scale = targetPose[b2].Scale
			if scale then
				puppet:ManipulateBoneScale(b, scale)
			end
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

local readSMHPose
do
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
	function readSMHPose(puppet, playerData)
		-- Assumes that we are in the networking scope
		local targetPose = decodePose()
		local animatingNonPhys = net.ReadBool()
		local puppeteer = playerData.puppeteer

		local smhModel = net.ReadString()
		local oldModel = puppeteer:GetModel()
		if smhModel ~= oldModel then
			puppeteer:SetModel(smhModel)
			local puppetRoot, puppeteerRoot = puppet:TranslatePhysBoneToBone(0), puppeteer:TranslatePhysBoneToBone(0)
			local map = getMap(puppeteer:GetBoneName(puppeteerRoot), puppet:GetBoneName(puppetRoot))
			playerData.boneMap = map
		end

		setSMHPoseOf(puppet, targetPose, playerData.filteredBones, playerData.puppeteer, playerData.boneMap)
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
		elseif
			not playerData.bonesReset and tonumber(playerData.player:GetInfo("ragdollpuppeteer_resetnonphys")) > 0
		then
			resetAllNonphysicalBonesOf(puppet)
			playerData.bonesReset = true
		end

		if smhModel ~= oldModel then
			puppeteer:SetModel(oldModel)
			local puppetRoot, puppeteerRoot = puppet:TranslatePhysBoneToBone(0), puppeteer:TranslatePhysBoneToBone(0)
			local map = getMap(puppeteer:GetBoneName(puppeteerRoot), puppet:GetBoneName(puppetRoot))
			playerData.boneMap = map
		end
	end
end

---Instead of finding the nonphysical bone poses on the server, find them in the client
---We don't require the puppeteer as we always work with one puppet
---@param ply Player Who queried for the nonphysical bone pose
---@param cycle number The current frame of the puppeteer's animation
local function queryNonPhysBonePoseOfPuppet(ply, cycle)
	net.Start("rp_queryNonPhysBonePoseOfPuppet", false)
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

---Gets the bone map `from` a source `to` a target, and its name, if they exist
---@param from string
---@param to string
---@return BoneDefinition? boneMap A bone mapping `from` one skeleton `to` another skeleton
---@return string? boneName The name of the bone mapping
local function getBoneMap(from, to)
	return getMap(from, to)
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
