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
	bones.TF2ToVRM = {
		["bip_pelvis"] = "J_Bip_C_Hips",
		["bip_spine_0"] = "J_Bip_C_Spine",
		["bip_spine_1"] = "J_Bip_C_Chest",
		["bip_spine_2"] = "J_Bip_C_UpperChest",
		["bip_neck"] = "J_Bip_C_Neck",
		["bip_head"] = "J_Bip_C_Head",
		["bip_collar_L"] = "J_Bip_L_Shoulder",
		["bip_upperArm_L"] = "J_Bip_L_UpperArm",
		["bip_lowerArm_L"] = "J_Bip_L_LowerArm",
		["bip_hand_L"] = "J_Bip_L_Hand",
		["bip_thumb_0_L"] = "J_Bip_L_Thumb1",
		["bip_thumb_1_L"] = "J_Bip_L_Thumb2",
		["bip_thumb_2_L"] = "J_Bip_L_Thumb3",
		["bip_index_0_L"] = "J_Bip_L_Index1",
		["bip_index_1_L"] = "J_Bip_L_Index2",
		["bip_index_2_L"] = "J_Bip_L_Index3",
		["bip_middle_0_L"] = "J_Bip_L_Middle1",
		["bip_middle_1_L"] = "J_Bip_L_Middle2",
		["bip_middle_2_L"] = "J_Bip_L_Middle3",
		["bip_ring_0_L"] = "J_Bip_L_Ring1",
		["bip_ring_1_L"] = "J_Bip_L_Ring2",
		["bip_ring_2_L"] = "J_Bip_L_Ring3",
		["bip_pinky_0_L"] = "J_Bip_L_Little1",
		["bip_pinky_1_L"] = "J_Bip_L_Little2",
		["bip_pinky_2_L"] = "J_Bip_L_Little3",
		["bip_collar_R"] = "J_Bip_R_Shoulder",
		["bip_upperArm_R"] = "J_Bip_R_UpperArm",
		["bip_lowerArm_R"] = "J_Bip_R_LowerArm",
		["bip_hand_R"] = "J_Bip_R_Hand",
		["bip_index_0_R"] = "J_Bip_R_Index1",
		["bip_index_1_R"] = "J_Bip_R_Index2",
		["bip_index_2_R"] = "J_Bip_R_Index3",
		["bip_pinky_0_R"] = "J_Bip_R_Little1",
		["bip_pinky_1_R"] = "J_Bip_R_Little2",
		["bip_pinky_2_R"] = "J_Bip_R_Little3",
		["bip_middle_0_R"] = "J_Bip_R_Middle1",
		["bip_middle_1_R"] = "J_Bip_R_Middle2",
		["bip_middle_2_R"] = "J_Bip_R_Middle3",
		["bip_ring_0_R"] = "J_Bip_R_Ring1",
		["bip_ring_1_R"] = "J_Bip_R_Ring2",
		["bip_ring_2_R"] = "J_Bip_R_Ring3",
		["bip_thumb_0_R"] = "J_Bip_R_Thumb1",
		["bip_thumb_1_R"] = "J_Bip_R_Thumb2",
		["bip_thumb_2_R"] = "J_Bip_R_Thumb3",
		["bip_hip_L"] = "J_Bip_L_UpperLeg",
		["bip_knee_L"] = "J_Bip_L_LowerLeg",
		["bip_foot_L"] = "J_Bip_L_Foot",
		["bip_toe_L"] = "J_Bip_L_ToeBase",
		["bip_hip_R"] = "J_Bip_R_UpperLeg",
		["bip_knee_R"] = "J_Bip_R_LowerLeg",
		["bip_foot_R"] = "J_Bip_R_Foot",
		["bip_toe_R"] = "J_Bip_R_ToeBase",
	}

	bones.HL2ToVRM = {
		["ValveBiped.Bip01_Pelvis"] = "J_Bip_C_Hips",
		["ValveBiped.Bip01_Spine"] = "J_Bip_C_Spine",
		["ValveBiped.Bip01_Spine1"] = "J_Bip_C_Chest",
		["ValveBiped.Bip01_Spine2"] = "J_Bip_C_UpperChest",
		["ValveBiped.Bip01_Neck1"] = "J_Bip_C_Neck",
		["ValveBiped.Bip01_Head1"] = "J_Bip_C_Head",
		["ValveBiped.Bip01_L_Clavicle"] = "J_Bip_L_Shoulder",
		["ValveBiped.Bip01_L_UpperArm"] = "J_Bip_L_UpperArm",
		["ValveBiped.Bip01_L_Forearm"] = "J_Bip_L_LowerArm",
		["ValveBiped.Bip01_L_Hand"] = "J_Bip_L_Hand",
		["ValveBiped.Bip01_L_Finger0"] = "J_Bip_L_Thumb1",
		["ValveBiped.Bip01_L_Finger01"] = "J_Bip_L_Thumb2",
		["ValveBiped.Bip01_L_Finger02"] = "J_Bip_L_Thumb3",
		["ValveBiped.Bip01_L_Finger1"] = "J_Bip_L_Index1",
		["ValveBiped.Bip01_L_Finger11"] = "J_Bip_L_Index2",
		["ValveBiped.Bip01_L_Finger12"] = "J_Bip_L_Index3",
		["ValveBiped.Bip01_L_Finger2"] = "J_Bip_L_Middle1",
		["ValveBiped.Bip01_L_Finger21"] = "J_Bip_L_Middle2",
		["ValveBiped.Bip01_L_Finger22"] = "J_Bip_L_Middle3",
		["ValveBiped.Bip01_L_Finger3"] = "J_Bip_L_Ring1",
		["ValveBiped.Bip01_L_Finger31"] = "J_Bip_L_Ring2",
		["ValveBiped.Bip01_L_Finger32"] = "J_Bip_L_Ring3",
		["ValveBiped.Bip01_L_Finger4"] = "J_Bip_L_Little1",
		["ValveBiped.Bip01_L_Finger41"] = "J_Bip_L_Little2",
		["ValveBiped.Bip01_L_Finger42"] = "J_Bip_L_Little3",
		["ValveBiped.Bip01_R_Clavicle"] = "J_Bip_R_Shoulder",
		["ValveBiped.Bip01_R_UpperArm"] = "J_Bip_R_UpperArm",
		["ValveBiped.Bip01_R_Forearm"] = "J_Bip_R_LowerArm",
		["ValveBiped.Bip01_R_Hand"] = "J_Bip_R_Hand",
		["ValveBiped.Bip01_R_Finger0"] = "J_Bip_R_Index1",
		["ValveBiped.Bip01_R_Finger01"] = "J_Bip_R_Index2",
		["ValveBiped.Bip01_R_Finger02"] = "J_Bip_R_Index3",
		["ValveBiped.Bip01_R_Finger1"] = "J_Bip_R_Little1",
		["ValveBiped.Bip01_R_Finger11"] = "J_Bip_R_Little2",
		["ValveBiped.Bip01_R_Finger12"] = "J_Bip_R_Little3",
		["ValveBiped.Bip01_R_Finger2"] = "J_Bip_R_Middle1",
		["ValveBiped.Bip01_R_Finger21"] = "J_Bip_R_Middle2",
		["ValveBiped.Bip01_R_Finger22"] = "J_Bip_R_Middle3",
		["ValveBiped.Bip01_R_Finger3"] = "J_Bip_R_Ring1",
		["ValveBiped.Bip01_R_Finger31"] = "J_Bip_R_Ring2",
		["ValveBiped.Bip01_R_Finger32"] = "J_Bip_R_Ring3",
		["ValveBiped.Bip01_R_Finger4"] = "J_Bip_R_Thumb1",
		["ValveBiped.Bip01_R_Finger41"] = "J_Bip_R_Thumb2",
		["ValveBiped.Bip01_R_Finger42"] = "J_Bip_R_Thumb3",
		["ValveBiped.Bip01_L_Thigh"] = "J_Bip_L_UpperLeg",
		["ValveBiped.Bip01_L_Calf"] = "J_Bip_L_LowerLeg",
		["ValveBiped.Bip01_L_Foot"] = "J_Bip_L_Foot",
		["ValveBiped.Bip01_L_Toe0"] = "J_Bip_L_ToeBase",
		["ValveBiped.Bip01_R_Thigh"] = "J_Bip_R_UpperLeg",
		["ValveBiped.Bip01_R_Calf"] = "J_Bip_R_LowerLeg",
		["ValveBiped.Bip01_R_Foot"] = "J_Bip_R_Foot",
		["ValveBiped.Bip01_R_Toe0"] = "J_Bip_R_ToeBase",
	}

	--[[
        To invert the above, you want to use the switchKeysWithValues function. For example,
        
        ```lua
            bones.HL2ToTF2 = switchKeysWithValues(bones.TF2ToHL2)        
        ```
    --]]
	bones.VRMToTF2 = switchKeysWithValues(bones.TF2ToVRM)
	bones.VRMToHL2 = switchKeysWithValues(bones.HL2ToVRM)
end

return bones
