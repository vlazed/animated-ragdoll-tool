-- Bone names are all case-sensitive!
-- Each bone definition must consist of a mapping pair (e.g. ["bip_pelvis"] = "ValveBiped.Biped01_Pelvis").

local bones = {}
do
	local function switchKeysWithValues(tab)
		local newTab = {}
		for key, val in pairs(tab) do
			newTab[val] = key
		end
		return newTab
	end

	bones.HL2ToR6 = {
		["ValveBiped.Bip01_R_UpperArm"] = "Right Arm",
		["ValveBiped.Bip01_L_UpperArm"] = "Left Arm",
		["ValveBiped.Bip01_R_Thigh"] = "Right Leg",
		["ValveBiped.Bip01_L_Thigh"] = "Left Leg",
		["ValveBiped.Bip01_Pelvis"] = "Torso",
		["ValveBiped.Bip01_Head"] = "Head",
	}
	bones.TF2ToR6 = {
		["bip_upperArm_R"] = "Right Arm",
		["bip_upperArm_L"] = "Left Arm",
		["bip_hip_R"] = "Right Leg",
		["bip_hip_L"] = "Left Leg",
		["bip_pelvis"] = "Torso",
		["bip_head"] = "Head",
	}
	bones.R6ToTF2 = switchKeysWithValues(bones.TF2ToR6)
	bones.R6ToHL2 = switchKeysWithValues(bones.HL2ToR6)

	bones.HL2ToR15 = {
		["ValveBiped.Bip01_R_UpperArm"] = "RightUpperArm",
		["ValveBiped.Bip01_L_UpperArm"] = "LeftUpperArm",
		["ValveBiped.Bip01_R_Thigh"] = "RightUpperLeg",
		["ValveBiped.Bip01_L_Thigh"] = "LeftUpperLeg",
		["ValveBiped.Bip01_R_Forearm"] = "RightLowerArm",
		["ValveBiped.Bip01_L_Forearm"] = "LeftLowerArm",
		["ValveBiped.Bip01_R_Hand"] = "RightHand",
		["ValveBiped.Bip01_L_Hand"] = "LeftHand",
		["ValveBiped.Bip01_R_Calf"] = "RightLowerLeg",
		["ValveBiped.Bip01_L_Calf"] = "LeftLowerLeg",
		["ValveBiped.Bip01_R_Foot"] = "RightFoot",
		["ValveBiped.Bip01_L_Foot"] = "LeftFoot",
		["ValveBiped.Bip01_Spine2"] = "UpperTorso",
		["ValveBiped.Bip01_Pelvis"] = "LowerTorso",
		["ValveBiped.Bip01_Head"] = "Head",
	}
	bones.TF2ToR15 = {
		["bip_upperArm_R"] = "RightUpperArm",
		["bip_upperArm_L"] = "LeftUpperArm",
		["bip_hip_R"] = "RightUpperLeg",
		["bip_hip_L"] = "LeftUpperLeg",
		["bip_lowerArm_R"] = "RightLowerArm",
		["bip_lowerArm_L"] = "LeftLowerArm",
		["bip_hand_R"] = "RightHand",
		["bip_hand_L"] = "LeftHand",
		["bip_knee_R"] = "RightLowerLeg",
		["bip_knee_L"] = "LeftLowerLeg",
		["bip_foot_R"] = "RightFoot",
		["bip_foot_L"] = "LeftFoot",
		["bip_spine_2"] = "UpperTorso",
		["bip_pelvis"] = "LowerTorso",
		["bip_head"] = "Head",
	}
	bones.R15ToTF2 = switchKeysWithValues(bones.TF2ToR15)
	bones.R15ToHL2 = switchKeysWithValues(bones.HL2ToR15)
end

return bones
