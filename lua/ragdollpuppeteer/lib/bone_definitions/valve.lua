--[[
    Bone names are all case-sensitive!
	Each bone definition must consist of a mapping pair (e.g. ["bip_pelvis"] = "ValveBiped.Biped01_Pelvis").
    If you have any questions regarding the format of a bone definition, post it in the discussion board:
    
    Discussion Board: https://steamcommunity.com/sharedfiles/filedetails/discussions/3333911060
--]]

local bones = {}
do
	---@param tab BoneDefinition
	---@return BoneDefinition switchedTab
	local function switchKeysWithValues(tab)
		local switchedTab = {}
		for key, val in pairs(tab) do
			switchedTab[val] = key
		end
		return switchedTab
	end

	--[[
        Make a new entry here. For example,

        ```lua
        bones.TF2ToHL2 = {
            ["bip_collar_R"] = "ValveBiped.Bip01_R_Clavicle",
            ["bip_collar_L"] = "ValveBiped.Bip01_L_Clavicle",
            ["bip_upperarm_R"] = "ValveBiped.Bip01_R_UpperArm",
            ["bip_upperarm_L"] = "ValveBiped.Bip01_L_UpperArm",
            ...
        }
        ```
        and so on.
    --]]
	---@type BoneDefinition
	bones.TF2ToHL2 = {
		["bip_collar_R"] = "ValveBiped.Bip01_R_Clavicle",
		["bip_collar_L"] = "ValveBiped.Bip01_L_Clavicle",
		["bip_upperArm_R"] = "ValveBiped.Bip01_R_UpperArm",
		["bip_upperArm_L"] = "ValveBiped.Bip01_L_UpperArm",
		["bip_lowerArm_R"] = "ValveBiped.Bip01_R_Forearm",
		["bip_lowerArm_L"] = "ValveBiped.Bip01_L_Forearm",
		["bip_hand_R"] = "ValveBiped.Bip01_R_Hand",
		["bip_hand_L"] = "ValveBiped.Bip01_L_Hand",

		["bip_thumb_0_L"] = "ValveBiped.Bip01_L_Finger0",
		["bip_thumb_1_L"] = "ValveBiped.Bip01_L_Finger01",
		["bip_thumb_2_L"] = "ValveBiped.Bip01_L_Finger02",
		["bip_index_0_L"] = "ValveBiped.Bip01_L_Finger1",
		["bip_index_1_L"] = "ValveBiped.Bip01_L_Finger11",
		["bip_index_2_L"] = "ValveBiped.Bip01_L_Finger12",
		["bip_middle_0_L"] = "ValveBiped.Bip01_L_Finger2",
		["bip_middle_1_L"] = "ValveBiped.Bip01_L_Finger21",
		["bip_middle_2_L"] = "ValveBiped.Bip01_L_Finger22",
		["bip_ring_0_L"] = "ValveBiped.Bip01_L_Finger3",
		["bip_ring_1_L"] = "ValveBiped.Bip01_L_Finger31",
		["bip_ring_2_L"] = "ValveBiped.Bip01_L_Finger32",
		["bip_pinky_0_L"] = "ValveBiped.Bip01_L_Finger4",
		["bip_pinky_1_L"] = "ValveBiped.Bip01_L_Finger41",
		["bip_pinky_2_L"] = "ValveBiped.Bip01_L_Finger42",

		["bip_thumb_0_R"] = "ValveBiped.Bip01_R_Finger0",
		["bip_thumb_1_R"] = "ValveBiped.Bip01_R_Finger01",
		["bip_thumb_2_R"] = "ValveBiped.Bip01_R_Finger02",
		["bip_index_0_R"] = "ValveBiped.Bip01_R_Finger1",
		["bip_index_1_R"] = "ValveBiped.Bip01_R_Finger11",
		["bip_index_2_R"] = "ValveBiped.Bip01_R_Finger12",
		["bip_middle_0_R"] = "ValveBiped.Bip01_R_Finger2",
		["bip_middle_1_R"] = "ValveBiped.Bip01_R_Finger21",
		["bip_middle_2_R"] = "ValveBiped.Bip01_R_Finger22",
		["bip_ring_0_R"] = "ValveBiped.Bip01_R_Finger3",
		["bip_ring_1_R"] = "ValveBiped.Bip01_R_Finger31",
		["bip_ring_2_R"] = "ValveBiped.Bip01_R_Finger32",
		["bip_pinky_0_R"] = "ValveBiped.Bip01_R_Finger4",
		["bip_pinky_1_R"] = "ValveBiped.Bip01_R_Finger41",
		["bip_pinky_2_R"] = "ValveBiped.Bip01_R_Finger42",

		["bip_hip_R"] = "ValveBiped.Bip01_R_Thigh",
		["bip_hip_L"] = "ValveBiped.Bip01_L_Thigh",
		["bip_knee_R"] = "ValveBiped.Bip01_R_Calf",
		["bip_knee_L"] = "ValveBiped.Bip01_L_Calf",
		["bip_foot_R"] = "ValveBiped.Bip01_R_Foot",
		["bip_foot_L"] = "ValveBiped.Bip01_L_Foot",
		["bip_toe_R"] = "ValveBiped.Bip01_R_Toe0",
		["bip_toe_L"] = "ValveBiped.Bip01_L_Toe0",

		["bip_pelvis"] = "ValveBiped.Bip01_Pelvis",
		["bip_spine_0"] = "ValveBiped.Bip01_Spine",
		["bip_spine_1"] = "ValveBiped.Bip01_Spine1",
		["bip_spine_2"] = "ValveBiped.Bip01_Spine2",
		["bip_spine_3"] = "ValveBiped.Bip01_Spine4",
		["bip_neck"] = "ValveBiped.Bip01_Neck1",
		["bip_head"] = "ValveBiped.Bip01_Head1",
	}

	bones.TF2ToBip = {
		["bip_collar_R"] = "ValveBiped.Bip01_R_Clavicle",
		["bip_collar_L"] = "ValveBiped.Bip01_L_Clavicle",
		["bip_upperArm_R"] = "ValveBiped.Bip01_R_UpperArm",
		["bip_upperArm_L"] = "ValveBiped.Bip01_L_UpperArm",
		["bip_lowerArm_R"] = "ValveBiped.Bip01_R_Forearm",
		["bip_lowerArm_L"] = "ValveBiped.Bip01_L_Forearm",
		["bip_hand_R"] = "ValveBiped.Bip01_R_Hand",
		["bip_hand_L"] = "ValveBiped.Bip01_L_Hand",

		["bip_thumb_0_L"] = "ValveBiped.Bip01_L_Finger0",
		["bip_thumb_1_L"] = "ValveBiped.Bip01_L_Finger01",
		["bip_thumb_2_L"] = "ValveBiped.Bip01_L_Finger02",
		["bip_index_0_L"] = "ValveBiped.Bip01_L_Finger1",
		["bip_index_1_L"] = "ValveBiped.Bip01_L_Finger11",
		["bip_index_2_L"] = "ValveBiped.Bip01_L_Finger12",
		["bip_middle_0_L"] = "ValveBiped.Bip01_L_Finger2",
		["bip_middle_1_L"] = "ValveBiped.Bip01_L_Finger21",
		["bip_middle_2_L"] = "ValveBiped.Bip01_L_Finger22",
		["bip_ring_0_L"] = "ValveBiped.Bip01_L_Finger3",
		["bip_ring_1_L"] = "ValveBiped.Bip01_L_Finger31",
		["bip_ring_2_L"] = "ValveBiped.Bip01_L_Finger32",
		["bip_pinky_0_L"] = "ValveBiped.Bip01_L_Finger4",
		["bip_pinky_1_L"] = "ValveBiped.Bip01_L_Finger41",
		["bip_pinky_2_L"] = "ValveBiped.Bip01_L_Finger42",

		["bip_thumb_0_R"] = "ValveBiped.Bip01_R_Finger0",
		["bip_thumb_1_R"] = "ValveBiped.Bip01_R_Finger01",
		["bip_thumb_2_R"] = "ValveBiped.Bip01_R_Finger02",
		["bip_index_0_R"] = "ValveBiped.Bip01_R_Finger1",
		["bip_index_1_R"] = "ValveBiped.Bip01_R_Finger11",
		["bip_index_2_R"] = "ValveBiped.Bip01_R_Finger12",
		["bip_middle_0_R"] = "ValveBiped.Bip01_R_Finger2",
		["bip_middle_1_R"] = "ValveBiped.Bip01_R_Finger21",
		["bip_middle_2_R"] = "ValveBiped.Bip01_R_Finger22",
		["bip_ring_0_R"] = "ValveBiped.Bip01_R_Finger3",
		["bip_ring_1_R"] = "ValveBiped.Bip01_R_Finger31",
		["bip_ring_2_R"] = "ValveBiped.Bip01_R_Finger32",
		["bip_pinky_0_R"] = "ValveBiped.Bip01_R_Finger4",
		["bip_pinky_1_R"] = "ValveBiped.Bip01_R_Finger41",
		["bip_pinky_2_R"] = "ValveBiped.Bip01_R_Finger42",

		["bip_hip_R"] = "ValveBiped.Bip01_R_Thigh",
		["bip_hip_L"] = "ValveBiped.Bip01_L_Thigh",
		["bip_knee_R"] = "ValveBiped.Bip01_R_Calf",
		["bip_knee_L"] = "ValveBiped.Bip01_L_Calf",
		["bip_foot_R"] = "ValveBiped.Bip01_R_Foot",
		["bip_foot_L"] = "ValveBiped.Bip01_L_Foot",
		["bip_toe_R"] = "ValveBiped.Bip01_R_Toe0",
		["bip_toe_L"] = "ValveBiped.Bip01_L_Toe0",

		["bip_pelvis"] = "ValveBiped.Bip01",
		["bip_spine_0"] = "ValveBiped.Bip01_Spine",
		["bip_spine_1"] = "ValveBiped.Bip01_Spine1",
		["bip_spine_2"] = "ValveBiped.Bip01_Spine2",
		["bip_spine_3"] = "ValveBiped.Bip01_Spine4",
		["bip_neck"] = "ValveBiped.Bip01_Neck1",
		["bip_head"] = "ValveBiped.Bip01_Head1",
	}

	bones.HL2ToBip = {
		["ValveBiped.Bip01_Pelvis"] = "ValveBiped.Bip01",
	}

	bones.HL2ToVortigaunt = {
		["ValveBiped.Bip01_Pelvis"] = "ValveBiped.hips",
		["ValveBiped.Bip01_Spine"] = "ValveBiped.spine1",
		["ValveBiped.Bip01_Spine1"] = "ValveBiped.spine2",
		["ValveBiped.Bip01_Spine2"] = "ValveBiped.spine3",
		["ValveBiped.Bip01_Spine4"] = "ValveBiped.spine4",
		["ValveBiped.Bip01_Neck1"] = "ValveBiped.neck1",
		["ValveBiped.Bip01_Head1"] = "ValveBiped.head",
		["ValveBiped.Bip01_L_Clavicle"] = "ValveBiped.clavical_L",
		["ValveBiped.Bip01_L_UpperArm"] = "ValveBiped.arm1_L",
		["ValveBiped.Bip01_L_Forearm"] = "ValveBiped.arm2_L",
		["ValveBiped.Bip01_L_Hand"] = "ValveBiped.hand1_L",
		["ValveBiped.Bip01_L_Finger1"] = "ValveBiped.index1_L",
		["ValveBiped.Bip01_L_Finger11"] = "ValveBiped.index2_L",
		["ValveBiped.Bip01_L_Finger12"] = "ValveBiped.index3_L",
		["ValveBiped.Bip01_L_Finger4"] = "ValveBiped.pinky1_L",
		["ValveBiped.Bip01_L_Finger41"] = "ValveBiped.pinky2_L",
		["ValveBiped.Bip01_L_Finger42"] = "ValveBiped.pinky3_L",
		["ValveBiped.Bip01_R_Clavicle"] = "ValveBiped.clavical_R",
		["ValveBiped.Bip01_R_UpperArm"] = "ValveBiped.arm1_R",
		["ValveBiped.Bip01_R_Forearm"] = "ValveBiped.arm2_R",
		["ValveBiped.Bip01_R_Hand"] = "ValveBiped.hand1_R",
		["ValveBiped.Bip01_R_Finger1"] = "ValveBiped.index1_R",
		["ValveBiped.Bip01_R_Finger11"] = "ValveBiped.index2_R",
		["ValveBiped.Bip01_R_Finger12"] = "ValveBiped.index3_R",
		["ValveBiped.Bip01_R_Finger4"] = "ValveBiped.pinky1_R",
		["ValveBiped.Bip01_R_Finger41"] = "ValveBiped.pinky2_R",
		["ValveBiped.Bip01_R_Finger42"] = "ValveBiped.pinky3_R",
		["ValveBiped.Bip01_L_Thigh"] = "ValveBiped.leg_bone1_L",
		["ValveBiped.Bip01_L_Calf"] = "ValveBiped.leg_bone2_L",
		["ValveBiped.Bip01_L_Foot"] = "ValveBiped.Bip01_L_Foot",
		["ValveBiped.Bip01_L_Toe0"] = "ValveBiped.Bip01_L_Toe0",
		["ValveBiped.Bip01_R_Thigh"] = "ValveBiped.leg_bone1_R",
		["ValveBiped.Bip01_R_Calf"] = "ValveBiped.leg_bone2_R",
		["ValveBiped.Bip01_R_Foot"] = "ValveBiped.Bip01_R_Foot",
		["ValveBiped.Bip01_R_Toe0"] = "ValveBiped.Bip01_R_Toe0",
	}
	bones.VortigauntToTF2 = {
		["ValveBiped.hips"] = "bip_pelvis",
		["ValveBiped.spine1"] = "bip_spine_0",
		["ValveBiped.spine2"] = "bip_spine_1",
		["ValveBiped.spine3"] = "bip_spine_2",
		["ValveBiped.spine4"] = "bip_spine_3",
		["ValveBiped.neck1"] = "bip_neck",
		["ValveBiped.head"] = "bip_head",
		["ValveBiped.clavical_L"] = "bip_collar_L",
		["ValveBiped.arm1_L"] = "bip_upperArm_L",
		["ValveBiped.arm2_L"] = "bip_lowerArm_L",
		["ValveBiped.hand1_L"] = "bip_hand_L",
		["ValveBiped.index1_L"] = "bip_index_0_L",
		["ValveBiped.index2_L"] = "bip_index_1_L",
		["ValveBiped.index3_L"] = "bip_index_2_L",
		["ValveBiped.pinky1_L"] = "bip_pinky_0_L",
		["ValveBiped.pinky2_L"] = "bip_pinky_1_L",
		["ValveBiped.pinky3_L"] = "bip_pinky_2_L",
		["ValveBiped.clavical_R"] = "bip_collar_R",
		["ValveBiped.arm1_R"] = "bip_upperArm_R",
		["ValveBiped.arm2_R"] = "bip_RowerArm_R",
		["ValveBiped.hand1_R"] = "bip_hand_R",
		["ValveBiped.index1_R"] = "bip_index_0_R",
		["ValveBiped.index2_R"] = "bip_index_1_R",
		["ValveBiped.index3_R"] = "bip_index_2_R",
		["ValveBiped.pinky1_R"] = "bip_pinky_0_R",
		["ValveBiped.pinky2_R"] = "bip_pinky_1_R",
		["ValveBiped.pinky3_R"] = "bip_pinky_2_R",
		["ValveBiped.leg_bone1_L"] = "bip_hip_L",
		["ValveBiped.leg_bone2_L"] = "bip_knee_L",
		["ValveBiped.Bip01_L_Foot"] = "bip_foot_L",
		["ValveBiped.Bip01_L_Toe0"] = "bip_toe_L",
		["ValveBiped.leg_bone1_R"] = "bip_hip_R",
		["ValveBiped.leg_bone2_R"] = "bip_knee_R",
		["ValveBiped.Bip01_R_Foot"] = "bip_foot_R",
		["ValveBiped.Bip01_R_Toe0"] = "bip_toe_R",
	}

	--[[
        To invert the above, you want to use the switchKeysWithValues function. For example,
        
        ```lua
            bones.HL2ToTF2 = switchKeysWithValues(bones.TF2ToHL2)        
        ```
    --]]
	bones.HL2ToTF2 = switchKeysWithValues(bones.TF2ToHL2)
	bones.BipToTF2 = switchKeysWithValues(bones.TF2ToBip)
	bones.BipToHL2 = switchKeysWithValues(bones.HL2ToBip)
	bones.VortigauntToHL2 = switchKeysWithValues(bones.HL2ToVortigaunt)
	bones.TF2ToVortigaunt = switchKeysWithValues(bones.VortigauntToTF2)
end

return bones
