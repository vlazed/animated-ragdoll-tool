local constants = {}

constants.PUPPETEER_MATERIAL = CreateMaterial("ragdollpuppeteer_puppeteer", "UnlitGeneric", {
	["$basetexture"] = "color/white",
	["$model"] = 1,
	["$translucent"] = 1,
	["$decal"] = 1,
})
constants.INVISIBLE_MATERIAL = CreateMaterial("ragdollpuppeteer_invisible", "UnlitGeneric", {
	["$basetexture"] = "models/effects/vol_light_001",
	["$additive"] = 1,
	["$decal"] = 1,
})

return constants
