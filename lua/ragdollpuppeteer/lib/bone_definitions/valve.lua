--[[
    Bone names are all case-sensitive!
    There should always be an even number of bone definitions. If there's an odd number, something went wrong!
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
		["bip_neck"] = "ValveBiped.Bip01_Neck",
		["bip_head"] = "ValveBiped.Bip01_Head",
	}

	--[[
        To invert the above, you want to use the switchKeysWithValues function. For example,
        
        ```lua
            bones.HL2ToTF2 = switchKeysWithValues(bones.TF2ToHL2)        
        ```
    --]]
	bones.HL2ToTF2 = switchKeysWithValues(bones.TF2ToHL2)
end

return bones
