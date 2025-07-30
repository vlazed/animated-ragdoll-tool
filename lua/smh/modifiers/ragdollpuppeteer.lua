---@diagnostic disable
-- Custom SMH Modifier for the puppeteer floor

MOD.Name = "Ragdoll Puppeteer Floor"

function MOD:IsPuppeteerFloor(entity)
	if entity:GetClass() ~= "prop_puppeteerfloor" then
		return false
	end
	return true
end

function MOD:Save(entity)
	if not self:IsPuppeteerFloor(entity) then
		return nil
	end

	local data = {}

	local angle = entity:GetAngleOffset()
	data.Height = entity:GetHeight()
	data.Pitch = angle.p
	data.Yaw = angle.y
	data.Roll = angle.r

	data["poseparams"] = {}

	for poseName, poseValue in pairs(entity:GetPoseParameters()) do
		data["poseparams"][poseName] = poseValue
	end

	return data
end

local isfunction = isfunction

function MOD:Load(entity, data)
	if not self:IsPuppeteerFloor(entity) then
		return
	end -- can never be too sure?

	entity:SetHeight(data.Height)
	entity:SetAngleOffset(Angle(data.Pitch, data.Yaw, data.Roll))

	if data["poseparams"] then
		for poseName, poseValue in pairs(data["poseparams"]) do
			if isfunction(entity["Set" .. poseName]) then
				entity["Set" .. poseName](entity, poseValue)
			end
		end
	end
end

function MOD:LoadBetween(entity, data1, data2, percentage)
	if not self:IsPuppeteerFloor(entity) then
		return
	end -- can never be too sure?

	entity:SetHeight(SMH.LerpLinear(data1.Height, data2.Height, percentage))
	entity:SetAngleOffset(
		SMH.LerpLinearAngle(
			Angle(data1.Pitch, data1.Yaw, data1.Roll),
			Angle(data2.Pitch, data2.Yaw, data2.Roll),
			percentage
		)
	)

	if data1["poseparams"] and data2["poseparams"] then
		for poseName, poseValue1 in pairs(data1["poseparams"]) do
			if isfunction(entity["Set" .. poseName]) then
				local poseValue2 = data2["poseparams"][poseName] or poseValue1
				local newValue = SMH.LerpLinear(poseValue1, poseValue2, percentage)
				entity["Set" .. poseName](entity, newValue)
			end
		end
	end
end
