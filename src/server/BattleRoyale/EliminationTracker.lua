local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Constants = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Constants"))

local EliminationTracker = {}
local killFeedRemote = nil

function EliminationTracker.init()
	local remotes = ReplicatedStorage:WaitForChild("Remotes")
	killFeedRemote = remotes:WaitForChild(Constants.Remotes.KillFeed)
end

function EliminationTracker.record(killer, victim, placement)
	local killerName = killer and killer.Name or "Storm"
	local victimName = victim and victim.Name or "Unknown"

	if killFeedRemote then
		killFeedRemote:FireAllClients(killerName, victimName, placement)
	end

	print(string.format("[Elimination] %s eliminated %s, placement #%d", killerName, victimName, placement))
end

return EliminationTracker
