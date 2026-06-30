local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage:WaitForChild("BattleRoyale"):WaitForChild("Config"))
local Constants = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Constants"))

local StormSystem = {}
StormSystem.__index = StormSystem

function StormSystem.new()
	local self = setmetatable({}, StormSystem)
	self._running = false
	self._center = Vector3.new(0, 0, 0)
	self._radius = Config.ZONE_INITIAL_RADIUS
	self._targetCenter = self._center
	self._targetRadius = self._radius
	self._zoneRemote = nil
	self._runId = 0
	return self
end

function StormSystem:_remote()
	if not self._zoneRemote then
		self._zoneRemote = ReplicatedStorage:WaitForChild("Remotes"):WaitForChild(Constants.Remotes.ZoneUpdate)
	end
	return self._zoneRemote
end

function StormSystem:_broadcast(isShrinking)
	self:_remote():FireAllClients(
		self._center.X,
		self._center.Z,
		self._radius,
		self._targetCenter.X,
		self._targetCenter.Z,
		self._targetRadius,
		isShrinking == true
	)
end

function StormSystem:reset()
	self._center = Vector3.new(0, 0, 0)
	self._radius = Config.ZONE_INITIAL_RADIUS
	self._targetCenter = self._center
	self._targetRadius = self._radius
	self:_broadcast(false)
end

function StormSystem:stop()
	self._running = false
	self._runId += 1
end

function StormSystem:_damageOutsideZone(getAlivePlayers, eliminatePlayer)
	local alivePlayers = getAlivePlayers()
	for _, player in ipairs(alivePlayers) do
		local character = player.Character
		local humanoid = character and character:FindFirstChildOfClass("Humanoid")
		local root = character and character:FindFirstChild("HumanoidRootPart")
		if humanoid and root and humanoid.Health > 0 then
			local flatOffset = Vector3.new(root.Position.X - self._center.X, 0, root.Position.Z - self._center.Z)
			if flatOffset.Magnitude > self._radius then
				if humanoid.Health <= Config.ZONE_DAMAGE_PER_TICK then
					eliminatePlayer(player, nil)
					humanoid.Health = 0
				else
					humanoid:TakeDamage(Config.ZONE_DAMAGE_PER_TICK)
				end
			end
		end
	end
end

function StormSystem:start(getAlivePlayers, eliminatePlayer)
	self._running = true
	self._runId += 1
	local runId = self._runId
	self:reset()

	task.spawn(function()
		for _, phase in ipairs(Config.ZONE_PHASES) do
			if not self._running or self._runId ~= runId then
				break
			end

			local waited = 0
			while self._running and self._runId == runId and waited < phase.waitTime do
				self:_broadcast(false)
				self:_damageOutsideZone(getAlivePlayers, eliminatePlayer)
				task.wait(Config.ZONE_TICK_INTERVAL)
				waited += Config.ZONE_TICK_INTERVAL
			end

			if not self._running or self._runId ~= runId then
				break
			end

			local angle = math.random() * math.pi * 2
			local maxOffset = math.max(self._radius - (self._radius * phase.radiusFraction), 0)
			local offset = Vector3.new(math.cos(angle), 0, math.sin(angle)) * (math.random() * maxOffset * 0.45)
			local startCenter = self._center
			local startRadius = self._radius
			self._targetCenter = self._center + offset
			self._targetRadius = math.max(Config.ZONE_INITIAL_RADIUS * phase.radiusFraction, 18)

			local elapsed = 0
			while self._running and self._runId == runId and elapsed < phase.shrinkTime do
				local alpha = math.clamp(elapsed / phase.shrinkTime, 0, 1)
				self._center = startCenter:Lerp(self._targetCenter, alpha)
				self._radius = startRadius + ((self._targetRadius - startRadius) * alpha)
				self:_broadcast(true)
				self:_damageOutsideZone(getAlivePlayers, eliminatePlayer)
				task.wait(Config.ZONE_TICK_INTERVAL)
				elapsed += Config.ZONE_TICK_INTERVAL
			end

			if not self._running or self._runId ~= runId then
				break
			end

			self._center = self._targetCenter
			self._radius = self._targetRadius
			self:_broadcast(false)
		end
	end)
end

return StormSystem
