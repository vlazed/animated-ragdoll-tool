local constants = {}

constants.PUPPETEER_MATERIAL = CreateMaterial("ragdollpuppeteer_puppeteer", "UnlitGeneric", {
	["$basetexture"] = "color/white",
	["$model"] = 1,
	["$translucent"] = 1,
	["$decal"] = 1,
})
constants.INVISIBLE_MATERIAL = CreateMaterial("ragdollpuppeteer_invisible", "UnlitGeneric", {
	["$basetexture"] = "ragdollpuppeteer/invisible",
	["$additive"] = 1,
	["$translucent"] = 1,
	["$decal"] = 1,
})
constants.DEFAULT_MAX_FRAME = 60

return constants
