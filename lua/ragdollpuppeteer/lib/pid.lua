---@class PID
---@field Reset fun(self: PID),
---@field Calculate fun(self: PID, setpoint: Vector|number, input: Vector|number, deltaTime: number): number
---@field Destroys fun(self: PID)
---@field _kp number
---@field _ki number
---@field _kd number
---@field _lastError Vector|number
---@field _min number
---@field _max number

local PID = {}
PID.__index = PID

---@param min number
---@param max number
---@param kp number
---@param ki number
---@param kd number
---@return PID
function PID.new(min, max, kp, ki, kd)
	local self = setmetatable({}, PID)
	self._min = min
	self._max = max
	self._kp = kp
	self._ki = ki
	self._kd = kd
	self._lastError = vector_origin -- Store the last error for derivative calculation
	self._integralSum = vector_origin -- Store the sum of errors for integral calculation
	return self
end

---Resets the PID to a zero start state.
function PID:Reset()
	self._lastError = vector_origin
	self._integralSum = vector_origin
end

function PID:Clamp(val)
	return math.Clamp(val, self._min, self._max)
end

---@param setpoint Vector|number
---@param processVariable Vector|number
---@param deltaTime number
---@return Vector|number
function PID:Calculate(setpoint, processVariable, deltaTime)
	-- Calculate the error e(t) = SP - PV(t)
	local err = setpoint - processVariable

	-- Proportional term
	local pOut = self._kp * err

	-- Integral term
	self._integralSum = self._integralSum + err * deltaTime
	local iOut = self._ki * self._integralSum

	-- Derivative term
	local derivative = (err - self._lastError) / deltaTime
	local dOut = self._kd * derivative

	-- Combine terms
	local output = pOut + iOut + dOut

	-- Clamp output to min/max
	if type(output) == "Vector" then
		output = Vector(self:Clamp(output.x), self:Clamp(output.y), self:Clamp(output.z))
	else
		output = self:Clamp(output)
	end

	-- Save the current error for the next derivative calculation
	self._lastError = err

	return output
end

return {
	new = PID.new,
}
