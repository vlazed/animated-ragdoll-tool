if SERVER then
	include("ragdollpuppeteer/net.lua")

	AddCSLuaFile("ragdollpuppeteer/vendor.lua")
	AddCSLuaFile("ragdollpuppeteer/smh.lua")
	AddCSLuaFile("ragdollpuppeteer/ui.lua")

	resource.AddSingleFile("resource/localization/en/ragdollpuppeteer_tool.properties")
	resource.AddSingleFile("resource/localization/en/ragdollpuppeteer_ui.properties")
end
