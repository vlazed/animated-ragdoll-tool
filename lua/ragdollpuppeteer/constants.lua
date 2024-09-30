local constants = {}

if CLIENT then
	constants.PUPPETEER_MATERIAL = CreateMaterial("ragdollpuppeteer_puppeteer", "VertexLitGeneric", {
		["$basetexture"] = "color/white",
		["$model"] = 1,
		["$translucent"] = 1,
		["$decal"] = 1,
	})
	constants.INVISIBLE_MATERIAL = CreateMaterial("ragdollpuppeteer_invisible", "VertexLitGeneric", {
		["$basetexture"] = "ragdollpuppeteer/invisible",
		["$additive"] = 1,
		["$translucent"] = 1,
		["$decal"] = 1,
	})
end
constants.DEFAULT_MAX_FRAME = 60
constants.RAGDOLL_HEIGHT_DIFFERENCE = 100
constants.COLOR_BLUE = Color(0, 0, 64, 100)

return constants
