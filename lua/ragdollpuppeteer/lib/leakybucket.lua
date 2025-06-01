-- Modified by vlazed to share typing and to make it work more in line with the Quaternion library

-- from incredible-gmod.ru with <3
-- https://github.com/Be1zebub/Leaky-Bucket.lua
-- https://en.wikipedia.org/wiki/Leaky_bucket

--[[
local LeakyBucket = require("leaky-bucket")(1000, 50) -- 1 liter capacity, 50 milliliters per second bandwidth

function webserver:onRequestReceive(request, response)
	LeakyBucket:Add(request.headers.length, function()
		response.headers.code = 200
		response.body = "pong!"
		response()
	end)
end

while true do
	LeakyBucket()
	webserver.listen()
end
]]
--

---@class LeakyBucket
---@field capacity number can fit X liters
---@field bandwidth number leak rate per second
---@field content number inner x liters
---@field contents table fluids queue
local LeakyBucket = {}
LeakyBucket.__index = LeakyBucket

---@return number
function LeakyBucket:GetCapacity()
	return self.capacity
end

---@return number
function LeakyBucket:GetBandwidth()
	return self.bandwidth
end

---@return number
function LeakyBucket:GetValue()
	return self.content
end

---@return number
function LeakyBucket:GetLevel()
	return self.content / self.capacity
end

---@return boolean
function LeakyBucket:IsFull()
	return self.content == self.capacity
end

---@param size number
---@return boolean
function LeakyBucket:CanFit(size)
	return self.content + size <= self.capacity
end

---@param size number
---@param cback fun(...)?
---@return boolean
function LeakyBucket:Add(size, cback)
	if self:CanFit(size) == false then
		return false
	end -- overflow leak
	self.content = self.content + size

	self.contents[#self.contents + 1] = {
		size = size,
		cback = cback,
	}

	return true
end

---Leak the bucket at every call
function LeakyBucket:__call()
	local incoming = self.contents[1]
	if incoming == nil then
		return
	end

	local time = os.time()
	if time == self.lastLeak then
		return
	end

	local change = (time - self.lastLeak) * self.bandwidth

	self.content = math.max(0, self.content - change)
	incoming.size = incoming.size - change

	if incoming.size <= 0 then
		if incoming.cback then
			incoming.cback()
		end
		table.remove(self.contents, 1)
	end

	self.lastLeak = time
end

---Create the leaky bucket object
---@param capacity number
---@param bandwidth number
---@return LeakyBucket
local function leakyBucket(capacity, bandwidth)
	return setmetatable({
		capacity = capacity,
		bandwidth = bandwidth,
		content = 0,
		contents = {},
		lastLeak = os.time(),
	}, LeakyBucket)
end

return leakyBucket
