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

return constants
