local constants = {}

if CLIENT then
	constants.PUPPETEER_MATERIAL = Material("ragdollpuppeteer/puppeteer")
	constants.PUPPETEER_MATERIAL_IGNOREZ = Material("ragdollpuppeteer/puppeteer_ignorez")
	constants.INVISIBLE_MATERIAL = Material("ragdollpuppeteer/puppeteer_invisible")
end

constants.DEFAULT_MAX_FRAME = 60

-- An empirical estimate of the threshold for the half root height difference of big ragdolls
constants.RAGDOLL_HEIGHT_DIFFERENCE = 100

constants.COLOR_BLUE = Color(0, 0, 64, 100)

-- The number of models that the user should not go over
constants.MAX_MODELS = 100
-- The number of models to leak from the bucket
constants.MODEL_DEQUE_RATE = 10
-- A list of commonly used prefixes for gestures
constants.PREFIXES = {
	"g_",
	"p_",
}
-- A list of commonly used suffixes for gestures
constants.SUFFIXES = {}
-- Keywords in a sequence name which likely result in a variation of a reference pose
constants.POSEFILTER = {
	"ref",
	"ragdoll",
	"user_ref",
	"r_handposes",
	"r_armposes",
	"r_armposes",
	"_flinch",
	"_swing",
	"gesture",
	"posture",
	"_end",
	"_loop",
	"aimmatrix",
	"_matrix",
	"spine",
	"arms",
	"delta",
	"_g_",
	"_bg_",
	"turnright",
	"turnleft",
	"arml",
	"armr",
	"attackstand",
	"attackcrouch",
	"blend",
	"placesapper",
	"jumpland",
}
-- Keywords in a sequence name which likely require pose parameters to visualize locomotion
constants.LOCOMOTION = {
	"run",
	"walk",
}
-- Pose parameter names that typically control locomotion
constants.LOCOMOTION_POSEPARAMS = {
	["move_x"] = true,
}

return constants
