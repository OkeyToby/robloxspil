local Players = game:GetService("Players")
local ServerScriptService = game:GetService("ServerScriptService")

Players.CharacterAutoLoads = false

local DataManager = require(ServerScriptService:WaitForChild("DataManager"))
local RemoteHandler = require(ServerScriptService:WaitForChild("RemoteHandler"))
local BattleRoyale = ServerScriptService:WaitForChild("BattleRoyale")

local TestMapBuilder = require(BattleRoyale:WaitForChild("TestMapBuilder"))
local EliminationTracker = require(BattleRoyale:WaitForChild("EliminationTracker"))
local SpectatorSystem = require(BattleRoyale:WaitForChild("SpectatorSystem"))
local WeaponServer = require(BattleRoyale:WaitForChild("WeaponServer"))
local MatchManager = require(BattleRoyale:WaitForChild("MatchManager"))

RemoteHandler.init()
TestMapBuilder.ensure()
EliminationTracker.init()
SpectatorSystem.init()
WeaponServer.init()
DataManager.startAutoSave(Players)

local matchManager = MatchManager.new({
	data = DataManager,
	eliminations = EliminationTracker,
	spectator = SpectatorSystem,
})

WeaponServer.setMatchManager(matchManager)
SpectatorSystem.setAliveGetter(function()
	return matchManager:GetAlivePlayers()
end)

local function onPlayerAdded(player)
	player:SetAttribute("BRAlive", false)
	DataManager.loadPlayer(player)
	task.defer(function()
		matchManager:SendToLobby(player)
	end)
end

Players.PlayerAdded:Connect(onPlayerAdded)
Players.PlayerRemoving:Connect(function(player)
	matchManager:EliminatePlayer(player, nil)
	DataManager.savePlayer(player)
	DataManager.forget(player)
end)

for _, player in ipairs(Players:GetPlayers()) do
	task.defer(onPlayerAdded, player)
end

game:BindToClose(function()
	for _, player in ipairs(Players:GetPlayers()) do
		DataManager.savePlayer(player)
	end
end)

matchManager:Start()

print("[GameManager] Battle Royale demo started")
