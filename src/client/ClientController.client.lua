local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local player = Players.LocalPlayer
local Constants = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Constants"))
local remotes = ReplicatedStorage:WaitForChild("Remotes")

remotes:WaitForChild(Constants.Remotes.PlayerDataLoaded).OnClientEvent:Connect(function(data)
	print(string.format("[ClientController] Data loaded for %s: %d wins, %d kills", player.Name, data.Wins or 0, data.Kills or 0))
end)
