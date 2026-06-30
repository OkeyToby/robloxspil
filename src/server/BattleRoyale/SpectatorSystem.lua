local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Constants = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Constants"))

local SpectatorSystem = {}
local spectatorTargets = {}
local spectatorIndex = {}
local lastCycleTime = {}
local spectatorRemote = nil
local cycleRemote = nil
local getAlivePlayers = function()
	return {}
end

local CYCLE_COOLDOWN = 0.5

function SpectatorSystem.init()
	local remotes = ReplicatedStorage:WaitForChild("Remotes")
	spectatorRemote = remotes:WaitForChild(Constants.Remotes.SpectatorTarget)
	cycleRemote = remotes:WaitForChild(Constants.Remotes.SpectatorCycle)

	cycleRemote.OnServerEvent:Connect(function(player, direction)
		SpectatorSystem.cycleTarget(player, direction)
	end)
end

function SpectatorSystem.setAliveGetter(callback)
	getAlivePlayers = callback
end

function SpectatorSystem.reset()
	table.clear(spectatorTargets)
	table.clear(spectatorIndex)
	table.clear(lastCycleTime)
end

function SpectatorSystem.beginSpectating(eliminated, alivePlayers)
	if not spectatorRemote then
		return
	end

	if #alivePlayers == 0 then
		spectatorRemote:FireClient(eliminated, "NoTargets", nil)
		return
	end

	spectatorIndex[eliminated] = 1
	spectatorTargets[eliminated] = alivePlayers[1]
	spectatorRemote:FireClient(eliminated, "StartSpectating", alivePlayers[1])
end

function SpectatorSystem.stopSpectating(player)
	spectatorTargets[player] = nil
	spectatorIndex[player] = nil

	if spectatorRemote then
		spectatorRemote:FireClient(player, "StopSpectating", nil)
	end
end

function SpectatorSystem.cycleTarget(player, direction)
	if not spectatorRemote then
		return
	end

	local now = os.clock()
	if lastCycleTime[player] and now - lastCycleTime[player] < CYCLE_COOLDOWN then
		return
	end
	lastCycleTime[player] = now

	if not spectatorIndex[player] then
		return
	end

	local alivePlayers = getAlivePlayers()
	if #alivePlayers == 0 then
		spectatorRemote:FireClient(player, "NoTargets", nil)
		return
	end

	local nextIndex = spectatorIndex[player] + (tonumber(direction) or 1)
	if nextIndex < 1 then
		nextIndex = #alivePlayers
	elseif nextIndex > #alivePlayers then
		nextIndex = 1
	end

	spectatorIndex[player] = nextIndex
	spectatorTargets[player] = alivePlayers[nextIndex]
	spectatorRemote:FireClient(player, "SwitchTarget", alivePlayers[nextIndex])
end

function SpectatorSystem.onTargetEliminated(eliminatedTarget, alivePlayers)
	for spectator, target in pairs(spectatorTargets) do
		if target == eliminatedTarget then
			SpectatorSystem.beginSpectating(spectator, alivePlayers)
		end
	end
end

return SpectatorSystem
