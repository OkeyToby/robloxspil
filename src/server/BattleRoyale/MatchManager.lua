local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage:WaitForChild("BattleRoyale"):WaitForChild("Config"))
local Constants = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Constants"))
local LootSpawner = require(script.Parent:WaitForChild("LootSpawner"))
local StormSystem = require(script.Parent:WaitForChild("StormSystem"))

local MatchManager = {}
MatchManager.__index = MatchManager

local function clearTools(player)
	local backpack = player:FindFirstChildOfClass("Backpack")
	if backpack then
		for _, child in ipairs(backpack:GetChildren()) do
			if child:IsA("Tool") then
				child:Destroy()
			end
		end
	end

	local character = player.Character
	if character then
		for _, child in ipairs(character:GetChildren()) do
			if child:IsA("Tool") then
				child:Destroy()
			end
		end
	end
end

local function loadCharacter(player)
	player:LoadCharacter()
	return player.Character or player.CharacterAdded:Wait()
end

function MatchManager.new(deps)
	local self = setmetatable({}, MatchManager)
	self._data = deps.data
	self._eliminations = deps.eliminations
	self._spectator = deps.spectator
	self._state = "Boot"
	self._running = false
	self._alive = {}
	self._deathConnections = {}
	self._loot = LootSpawner.new()
	self._storm = StormSystem.new()
	self._matchStateRemote = ReplicatedStorage:WaitForChild("Remotes"):WaitForChild(Constants.Remotes.MatchState)
	return self
end

function MatchManager:GetAlivePlayers()
	local alive = {}
	for player in pairs(self._alive) do
		if player.Parent == Players then
			table.insert(alive, player)
		end
	end
	table.sort(alive, function(a, b)
		return a.UserId < b.UserId
	end)
	return alive
end

function MatchManager:_playerCount()
	return #Players:GetPlayers()
end

function MatchManager:_broadcastState(phase, extra)
	self._state = phase
	self._matchStateRemote:FireAllClients(phase, extra)
end

function MatchManager:_disconnectDeath(player)
	local connection = self._deathConnections[player]
	if connection then
		connection:Disconnect()
		self._deathConnections[player] = nil
	end
end

function MatchManager:_connectDeath(player, character)
	self:_disconnectDeath(player)
	local humanoid = character:FindFirstChildOfClass("Humanoid") or character:WaitForChild("Humanoid", 5)
	if not humanoid then
		return
	end

	self._deathConnections[player] = humanoid.Died:Connect(function()
		self:EliminatePlayer(player, nil)
	end)
end

function MatchManager:SendToLobby(player)
	player:SetAttribute("BRAlive", false)
	clearTools(player)
	local character = loadCharacter(player)
	local root = character:WaitForChild("HumanoidRootPart", 5)
	local lobbySpawn = workspace:FindFirstChild("LobbySpawn")
	if root and lobbySpawn and lobbySpawn:IsA("BasePart") then
		root.CFrame = lobbySpawn.CFrame + Vector3.new(0, 5, 0)
	end
end

function MatchManager:_deployPlayers()
	table.clear(self._alive)

	local players = Players:GetPlayers()
	table.sort(players, function(a, b)
		return a.UserId < b.UserId
	end)

	local maxPlayers = math.min(#players, Config.MAX_PLAYERS)
	for index = 1, maxPlayers do
		local player = players[index]
		self._data.addMatch(player)
		player:SetAttribute("BRAlive", true)
		clearTools(player)

		local character = loadCharacter(player)
		local humanoid = character:WaitForChild("Humanoid", 5)
		local root = character:WaitForChild("HumanoidRootPart", 5)

		if humanoid then
			humanoid.Health = humanoid.MaxHealth
		end

		if root then
			local angle = (math.pi * 2) * (index / math.max(maxPlayers, 1))
			local radius = math.min(Config.ARENA_RADIUS * 0.55, 170)
			root.CFrame = CFrame.new(
				math.cos(angle) * radius,
				Config.ARENA_CENTER.Y + Config.DEPLOY_HEIGHT,
				math.sin(angle) * radius
			)
		end

		self._alive[player] = true
		self:_connectDeath(player, character)
	end
end

function MatchManager:_cleanupPlayers()
	for player in pairs(self._alive) do
		player:SetAttribute("BRAlive", false)
	end
	table.clear(self._alive)

	for player, connection in pairs(self._deathConnections) do
		connection:Disconnect()
		self._deathConnections[player] = nil
	end

	for _, player in ipairs(Players:GetPlayers()) do
		if self._spectator then
			self._spectator.stopSpectating(player)
		end
		self:SendToLobby(player)
	end
end

function MatchManager:EliminatePlayer(player, killer)
	if not self._alive[player] then
		return
	end

	self._alive[player] = nil
	player:SetAttribute("BRAlive", false)
	self:_disconnectDeath(player)

	local alivePlayers = self:GetAlivePlayers()
	local placement = #alivePlayers + 1

	if killer and killer ~= player then
		self._data.addKill(killer)
	end

	self._eliminations.record(killer, player, placement)

	if self._spectator then
		self._spectator.beginSpectating(player, alivePlayers)
		self._spectator.onTargetEliminated(player, alivePlayers)
	end
end

function MatchManager:_waitForPlayers()
	while self._running and self:_playerCount() < Config.MIN_PLAYERS do
		self:_broadcastState("Waiting", Config.MIN_PLAYERS - self:_playerCount())
		task.wait(2)
	end
end

function MatchManager:_countdown()
	self:_broadcastState("Intermission", Config.LOBBY_INTERMISSION)
	task.wait(Config.LOBBY_INTERMISSION)

	for remaining = Config.COUNTDOWN_DURATION, 1, -1 do
		if self:_playerCount() < Config.MIN_PLAYERS then
			return false
		end
		self:_broadcastState("Countdown", remaining)
		task.wait(1)
	end

	return true
end

function MatchManager:_runMatch()
	if not self:_countdown() then
		return
	end

	if self._spectator then
		self._spectator.reset()
	end

	self:_broadcastState("Deploying", Config.DEPLOY_DURATION)
	self:_deployPlayers()
	self._loot:spawnAll()
	task.wait(Config.DEPLOY_DURATION)

	self:_broadcastState("Playing", #self:GetAlivePlayers())
	self._storm:start(function()
		return self:GetAlivePlayers()
	end, function(player, killer)
		self:EliminatePlayer(player, killer)
	end)

	while self._running and #self:GetAlivePlayers() > 1 do
		self:_broadcastState("Playing", #self:GetAlivePlayers())
		task.wait(1)
	end

	self._storm:stop()

	local alivePlayers = self:GetAlivePlayers()
	local winner = alivePlayers[1]
	if winner then
		self._data.addWin(winner)
		self:_broadcastState("Victory", winner.Name)
	else
		self:_broadcastState("Victory", "No winner")
	end

	task.wait(Config.VICTORY_SCREEN_DURATION)
	self:_broadcastState("Cleanup", Config.CLEANUP_DURATION)
	self._loot:clear()
	task.wait(Config.CLEANUP_DURATION)
	self:_cleanupPlayers()
end

function MatchManager:Start()
	if self._running then
		return
	end

	self._running = true
	task.spawn(function()
		while self._running do
			self:_waitForPlayers()
			if self._running then
				self:_runMatch()
			end
			task.wait(1)
		end
	end)
end

function MatchManager:Stop()
	self._running = false
	self._storm:stop()
	self._loot:clear()
	self:_cleanupPlayers()
end

return MatchManager
