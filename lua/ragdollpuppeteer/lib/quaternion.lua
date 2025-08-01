---
-- This module defines a quaternion data structure and associated operations for 3D rotations.
---@author WLKRE
---@class Quaternion
local QUATERNION = {
	__epsl = 0.0001,
	__lerp = 0.9995,
	__axis = Vector(),
}

QUATERNION.__index = QUATERNION
debug.getregistry().Quaternion = QUATERNION

---
-- Checks if an object is a quaternion.
---@param  obj any object to check.
---@return boolean 'true' if the object is a quaternion, 'false' otherwise.
local function IsQuaternion(obj)
	return getmetatable(obj) == QUATERNION
end

---
-- Create a new quaternion.
-- If a single argument 'w' is provided, it assumes a quaternion object was passed in to copy the
-- values from. If 'w' and 'x', 'y', and 'z' are provided, it creates a quaternion with the provided values.
---@param  w Quaternion|number The 'w' component of the quaternion or a Quaternion object to copy.
---@param  x number? The 'x' component of the quaternion.
---@param  y number? The 'y' component of the quaternion.
---@param  z number? The 'z' component of the quaternion.
---@return Quaternion A new quaternion.
--
local function Quaternion(
	w --[[ 1.0 ]],
	x --[[ 0.0 ]],
	y --[[ 0.0 ]],
	z --[[ 0.0 ]]
)
	return IsQuaternion(w) and setmetatable({ w = w.w, x = w.x, y = w.y, z = w.z }, QUATERNION)
		or setmetatable({ w = w or 1.0, x = x or 0.0, y = y or 0.0, z = z or 0.0 }, QUATERNION)
end

---
-- Compare this quaternion with another quaternion for equality.
---@param q Quaternion Another quaternion to compare with.
---@return boolean True if the quaternions are equal, false otherwise.
--
function QUATERNION:__eq(q)
	return self.w == q.w and self.x == q.x and self.y == q.y and self.z == q.z
end

---
-- Set the values of the quaternion.
---@param w number|Quaternion The 'w' component of the quaternion or a Quaternion object to copy.
---@param x number? The 'x' component of the quaternion.
---@param y number? The 'y' component of the quaternion.
---@param z number? The 'z' component of the quaternion.
---@return Quaternion q The modified quaternion.
--
function QUATERNION:Set(w, x, y, z)
	if IsQuaternion(w) then
		self.w, self.x, self.y, self.z = w.w, w.x, w.y, w.z
	else
		self.w, self.x, self.y, self.z = w, x, y, z
	end
	return self
end

---
-- Set the quaternion using Euler angles.
---@param  ang Angle An angle with 'p', 'y', and 'r' keys representing pitch, yaw, and roll angles.
---@return Quaternion The modified quaternion.
--
function QUATERNION:SetAngle(ang)
	local p = math.rad(ang.p) * 0.5
	local y = math.rad(ang.y) * 0.5
	local r = math.rad(ang.r) * 0.5
	local sinp = math.sin(p)
	local cosp = math.cos(p)
	local siny = math.sin(y)
	local cosy = math.cos(y)
	local sinr = math.sin(r)
	local cosr = math.cos(r)

	return self:Set(
		cosr * cosp * cosy + sinr * sinp * siny,
		sinr * cosp * cosy - cosr * sinp * siny,
		cosr * sinp * cosy + sinr * cosp * siny,
		cosr * cosp * siny - sinr * sinp * cosy
	)
end

---@param angle Angle
---@return Quaternion
local function FromAngle(angle)
	local q = Quaternion(1, 0, 0, 0)
	return q:SetAngle(angle)
end

---
-- Set the quaternion using an axis and an angle.
---@param  theta number The angle in degrees.
---@param  axis Vector A vector with 'x', 'y', and 'z' keys representing the axis of rotation.
---@return Quaternion The modified quaternion.
--
function QUATERNION:SetAngleAxis(theta, axis)
	local ang = math.rad(theta) * 0.5
	local sin = math.sin(ang)
	local vec = axis:GetNormalized()

	self.__axis = vec
	return self:Set(math.cos(ang), vec.x * sin, vec.y * sin, vec.z * sin)
end

---
-- Sets the quaternion based on a 4x4 rotation matrix.
---@param  m VMatrix The 4x4 matrix representing the rotation.
---@return Quaternion q The calculated quaternion.
--
function QUATERNION:SetMatrix(m)
	local m11, m12, m13, _, m21, m22, m23, _, m31, m32, m33, _ = m:Unpack()

	local scale = 1.0
	local trace = m11 + m22 + m33 + scale

	if trace > self.__epsl then
		scale = math.sqrt(trace) * 2.0
		self:Set(0.25 * scale, (m32 - m23) / scale, (m13 - m31) / scale, (m21 - m12) / scale)
	else
		if m11 > m22 and m11 > m33 then
			scale = math.sqrt(1.0 + m11 - m22 - m33) * 2.0
			self:Set((m32 - m23) / scale, 0.25 * scale, (m21 + m12) / scale, (m13 + m31) / scale)
		elseif m22 > m33 then
			scale = math.sqrt(1.0 + m22 - m11 - m33) * 2.0
			self:Set((m13 - m31) / scale, (m21 + m12) / scale, 0.25 * scale, (m32 + m23) / scale)
		else
			scale = math.sqrt(1.0 + m33 - m11 - m22) * 2.0
			self:Set((m21 - m12) / scale, (m13 + m31) / scale, (m23 + m32) / scale, 0.25 * scale)
		end
	end

	return self:Normalize()
end

---
-- Set the quaternion to orient an object in the specified direction with a given up vector.
---@param forward Vector The desired direction vector.
---@param up Vector? The up vector that defines the object's up direction.
---@return Quaternion The modified quaternion representing the new orientation.
--
function QUATERNION:SetDirection(
	forward,
	up --[[ Vector(0, 0, 1) ]]
)
	up = up and up:GetNormalized() or Vector(0, 0, 1)
	forward = forward:GetNormalized()

	local m = Matrix()
	local right = up:Cross(forward)
	m:SetUnpacked(
		forward.x,
		right.x,
		up.x,
		0.0,
		forward.y,
		right.y,
		up.y,
		0.0,
		forward.z,
		right.z,
		up.z,
		0.0,
		0.0,
		0.0,
		0.0,
		1.0
	)

	return self:SetAngle(m:GetAngles())
end

---
-- Get the squared length of the quaternion.
---@return number The squared length of the quaternion.
--
function QUATERNION:LengthSqr()
	return self.w * self.w + self.x * self.x + self.y * self.y + self.z * self.z
end

---
-- Get the length of the quaternion.
---@return number The length of the quaternion.
--
function QUATERNION:Length()
	return math.sqrt(self:LengthSqr())
end

---
-- Normalize the quaternion.
---@return Quaternion The normalized quaternion.
--
function QUATERNION:Normalize()
	local len = self:Length()
	return len > 0 and self:DivScalar(len) or self
end

---
-- Get the normalized quaternion as a new quaternion.
---@return Quaternion A new quaternion representing the normalized quaternion.
--
function QUATERNION:Normalized()
	return Quaternion(self):Normalize()
end

---
-- Get the conjugate of the quaternion.
---@return Quaternion The conjugated quaternion.
--
function QUATERNION:Conjugate()
	return self:Set(self.w, -self.x, -self.y, -self.z)
end

---
-- Get the conjugated quaternion as a new quaternion.
---@return Quaternion conj A new quaternion representing the conjugated quaternion.
--
function QUATERNION:Conjugated()
	return Quaternion(self):Conjugate()
end

---
-- Invert the quaternion.
---@return Quaternion inverted The inverted quaternion.
--
function QUATERNION:Invert()
	return self:Conjugate():Normalize()
end

---
-- Get the inverted quaternion as a new quaternion.
---@return Quaternion inverted A new quaternion representing the inverted quaternion.
--
function QUATERNION:Inverted()
	return Quaternion(self):Invert()
end

---
-- Negate the quaternion.
---@return Quaternion negated The negated quaternion.
--
function QUATERNION:Negate()
	return self:MulScalar(-1.0)
end

---
-- Get the negated quaternion as a new quaternion.
---@return Quaternion negated A new quaternion representing the negated quaternion.
--
function QUATERNION:Negated()
	return Quaternion(self):Negate()
end

function QUATERNION:__unm()
	return self:Negated()
end

---
-- Calculate the dot product of two quaternions.
---@param q Quaternion The other quaternion for dot product calculation.
---@return number dot The dot product result.
--
function QUATERNION:Dot(q)
	return self.w * q.w + self.x * q.x + self.y * q.y + self.z * q.z
end

---
-- Calculates the angular difference between two quaternions in degrees.
---@param q Quaternion The other quaternion to calculate the angular difference with.
---@return number difference The angular difference in degrees.
--
function QUATERNION:AngleDifference(q)
	return math.deg(math.acos(math.min(math.abs(self:Dot(q)), 1.0)) * 2.0)
end

---
-- Add a scalar value to the quaternion's real part.
---@param scalar number The scalar value to add.
---@return self q The modified quaternion.
--
function QUATERNION:AddScalar(scalar)
	self.w = self.w + scalar
	return self
end

---
-- Add another quaternion to this quaternion.
---@param q Quaternion The quaternion to add.
---@return Quaternion q The modified quaternion after addition.
--
function QUATERNION:Add(q)
	return self:Set(self.w + q.w, self.x + q.x, self.y + q.y, self.z + q.z)
end

function QUATERNION:__add(q)
	return IsQuaternion(q) and Quaternion(self):Add(q) or Quaternion(self):AddScalar(q)
end

---
-- Subtract a scalar value from the quaternion's real part.
---@param scalar number The scalar value to subtract.
---@return self Quaternion The modified quaternion.
--
function QUATERNION:SubScalar(scalar)
	return self:AddScalar(-scalar)
end

---
-- Subtract another quaternion from this quaternion.
---@param q Quaternion The quaternion to subtract.
---@return Quaternion q The modified quaternion after subtraction.
--
function QUATERNION:Sub(q)
	---@diagnostic disable-next-line: param-type-mismatch
	return self:Add(-q)
end

function QUATERNION:__sub(q)
	return IsQuaternion(q) and Quaternion(self):Sub(q) or Quaternion(self):SubScalar(q)
end

---
-- Multiply the quaternion by a scalar value.
---@param scalar number The scalar value to multiply by.
---@return Quaternion q The modified quaternion after multiplication.
--
function QUATERNION:MulScalar(scalar)
	return self:Set(self.w * scalar, self.x * scalar, self.y * scalar, self.z * scalar)
end

---
-- Multiply this quaternion by another quaternion.
---@param q Quaternion The quaternion to multiply by.
---@return Quaternion q The modified quaternion after multiplication.
--
function QUATERNION:Mul(q)
	local qw, qx, qy, qz = self:Unpack()
	local q2w, q2x, q2y, q2z = q:Unpack()

	return self:Set(
		qw * q2w - qx * q2x - qy * q2y - qz * q2z,
		qx * q2w + qw * q2x + qy * q2z - qz * q2y,
		qy * q2w + qw * q2y + qz * q2x - qx * q2z,
		qz * q2w + qw * q2z + qx * q2y - qy * q2x
	)
end

---@param q number|Quaternion
---@return number|Quaternion
function QUATERNION:__mul(q)
	---@diagnostic disable-next-line: param-type-mismatch
	return IsQuaternion(q) and Quaternion(self):Mul(q) or Quaternion(self):MulScalar(q)
end

function QUATERNION:__concat(q)
	return Quaternion(q):Mul(self)
end

---
-- Divide the quaternion by a scalar value.
---@param  scalar number The scalar value to divide by.
---@return Quaternion The modified quaternion after division.
--
function QUATERNION:DivScalar(scalar)
	return self:MulScalar(1.0 / scalar)
end

---
-- Divide this quaternion by another quaternion.
---@param  q Quaternion The quaternion to divide by.
---@return Quaternion The modified quaternion after division.
--
function QUATERNION:Div(q)
	return self:Mul(q:Inverted())
end

function QUATERNION:__div(q)
	return IsQuaternion(q) and Quaternion(self):Div(q) or Quaternion(self):DivScalar(q)
end

---
-- Perform linear interpolation within a specified alpha range.
---@param  q Quaternion The target quaternion to interpolate to.
---@param  alphaStart number The starting alpha value (0.0 to 1.0).
---@param  alphaEnd number The ending alpha value (0.0 to 1.0).
---@return Quaternion Quaternion The interpolated quaternion.
--
function QUATERNION:LerpDomain(q, alphaStart, alphaEnd)
	return self:MulScalar(alphaStart):Add(Quaternion(q):MulScalar(alphaEnd)):Normalize()
end

---
-- Perform linear interpolation between two quaternions.
---@param  q Quaternion The target quaternion to interpolate to.
---@param  alpha number The alpha value (0.0 to 1.0) for interpolation.
---@return Quaternion interpQ The interpolated quaternion.
--
function QUATERNION:Lerp(q, alpha)
	return self:LerpDomain(q, 1.0 - alpha, alpha)
end

---
-- Perform spherical linear interpolation between two quaternions.
---@param  q Quaternion The target quaternion to interpolate to.
---@param  alpha number The alpha value (0.0 to 1.0) for interpolation.
---@return Quaternion slerpQ The interpolated quaternion.
--
function QUATERNION:SLerp(q, alpha)
	local ref = q
	local dot = self:Dot(ref)

	local alphaStart = 1.0 - alpha
	local alphaEnd = alpha

	if dot < 0.0 then
		---@diagnostic disable-next-line: cast-local-type
		ref = -q
		dot = -dot
	end

	if dot < self.__lerp then
		local theta = math.acos(dot)
		local thetaInv = math.abs(theta) < self.__epsl and 1.0 or (1.0 / math.sin(theta))

		alphaStart = math.sin((1.0 - alpha) * theta) * thetaInv
		alphaEnd = math.sin(alpha * theta) * thetaInv
	end

	---@diagnostic disable-next-line: param-type-mismatch
	return self:LerpDomain(ref, alphaStart, alphaEnd)
end

---
-- Rotate a 3D vector using this quaternion.
---@param vec Vector A 3D vector to be rotated.
---@return Vector rotated The rotated 3D vector.
--
function QUATERNION:RotateVector(vec)
	local qw, qx, qy, qz = self:Unpack()
	local vx, vy, vz = vec:Unpack()

	vec:SetUnpacked(
		qw * qw * vx
			+ 2.0 * qy * qw * vz
			- 2.0 * qz * qw * vy
			+ qx * qx * vx
			+ 2.0 * qy * qx * vy
			+ 2.0 * qz * qx * vz
			- qz * qz * vx
			- qy * qy * vx,
		2.0 * qx * qy * vx
			+ qy * qy * vy
			+ 2.0 * qz * qy * vz
			+ 2.0 * qw * qz * vx
			- qz * qz * vy
			+ qw * qw * vy
			- 2.0 * qx * qw * vz
			- qx * qx * vy,
		2.0 * qx * qz * vx
			+ 2.0 * qy * qz * vy
			+ qz * qz * vz
			- 2.0 * qw * qy * vx
			- qy * qy * vz
			+ 2.0 * qw * qx * vy
			- qx * qx * vz
			+ qw * qw * vz
	)

	return vec
end

---
-- Get a rotated 3D vector using this quaternion as a new vector.
---@param vec Vector A 3D vector to be rotated.
---@return Vector rotated A new 3D vector representing the rotated vector.
--
function QUATERNION:RotatedVector(vec)
	return self:RotateVector(Vector(vec))
end

---
-- Convert the quaternion to Euler angles.
---@return Angle angle An angle with 'p', 'y', and 'r' keys representing pitch, yaw, and roll angles.
--
function QUATERNION:Angle()
	local qw, qx, qy, qz = self:Unpack()

	return Angle(
		math.deg(math.asin(2.0 * (qw * qy - qz * qx))),
		math.deg(math.atan2(2.0 * (qw * qz + qx * qy), 1.0 - 2.0 * (qy * qy + qz * qz))),
		math.deg(math.atan2(2.0 * (qw * qx + qy * qz), 1.0 - 2.0 * (qx * qx + qy * qy)))
	)
end

---
-- Converts the quaternion to an angle-axis representation.
---@return number ang The angle in degrees.
---@return Vector axis A 3D vector representing the axis.
--
function QUATERNION:AngleAxis()
	local qw = self.w
	---@cast qw number
	local den = math.sqrt(1.0 - qw * qw)

	return math.deg(2.0 * math.acos(qw)), den > self.__epsl and (Vector(self.x, self.y, self.z) / den) or self.__axis
end

---
-- Convert the quaternion to a 4x4 rotation matrix.
---@param m VMatrix? Matrix to output result to.
---@return VMatrix matrix A 4x4 rotation matrix.
--
function QUATERNION:Matrix(
	m --[[ Matrix() ]]
)
	local qw, qx, qy, qz = self:Unpack()

	m = m or Matrix()
	m:SetUnpacked(
		1.0 - 2.0 * (qy * qy + qz * qz),
		2.0 * (qx * qy - qw * qz),
		2.0 * (qx * qz + qw * qy),
		0.0,
		2.0 * (qx * qy + qw * qz),
		1.0 - 2.0 * (qx * qx + qz * qz),
		2.0 * (qy * qz - qw * qx),
		0.0,
		2.0 * (qx * qz - qw * qy),
		2.0 * (qy * qz + qw * qx),
		1.0 - 2.0 * (qx * qx + qy * qy),
		0.0,
		0.0,
		0.0,
		0.0,
		1.0
	)

	return m
end

---
-- Unpacks a quaternion into its components.
---@return number w The w component.
---@return number x The x component.
---@return number y The y component.
---@return number z The z component.
--
function QUATERNION:Unpack()
	---@diagnostic disable-next-line: return-type-mismatch
	return self.w, self.x, self.y, self.z
end

---
-- Convert the quaternion to a string representation.
---@return string A string representing the quaternion.
--
function QUATERNION:__tostring()
	return string.format("%f %f %f %f", self:Unpack())
end

return {
	new = Quaternion,
	fromAngle = FromAngle,
}
