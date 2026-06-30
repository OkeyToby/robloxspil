local DataStoreService = game:GetService("DataStoreService")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Constants = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Constants"))

local DataManager = {}
local store = DataStoreService:GetDataStore(Constants.DATA_STORE_NAME)
local cache = {}
local saveQueued = {}

local DEFAULT_DATA = {
	Wins = 0,
	Kills = 0,
	Matches = 0,
}

local function cloneDefault()
	return {
		Wins = DEFAULT_DATA.Wins,
		Kills = DEFAULT_DATA.Kills,
		Matches = DEFAULT_DATA.Matches,
	}
end

local function keyFor(player)
	return "player_" .. player.UserId
end

local function fireLoaded(player)
	local remotes = ReplicatedStorage:FindFirstChild("Remotes")
	local remote = remotes and remotes:FindFirstChild(Constants.Remotes.PlayerDataLoaded)
	if remote and remote:IsA("RemoteEvent") then
		remote:FireClient(player, cache[player.UserId])
	end
end

function DataManager.loadPlayer(player)
	local data = nil

	if not RunService:IsStudio() then
		local ok, result = pcall(function()
			return store:GetAsync(keyFor(player))
		end)
		if ok and type(result) == "table" then
			data = result
		elseif not ok then
			warn("[DataManager] Load failed for " .. player.Name .. ": " .. tostring(result))
		end
	else
		local ok, result = pcall(function()
			return store:GetAsync(keyFor(player))
		end)
		if ok and type(result) == "table" then
			data = result
		end
	end

	data = data or cloneDefault()
	data.Wins = tonumber(data.Wins) or 0
	data.Kills = tonumber(data.Kills) or 0
	data.Matches = tonumber(data.Matches) or 0

	cache[player.UserId] = data
	fireLoaded(player)
	task.delay(1, function()
		if player.Parent then
			fireLoaded(player)
		end
	end)
	return data
end

function DataManager.get(player)
	if not cache[player.UserId] then
		cache[player.UserId] = cloneDefault()
	end
	return cache[player.UserId]
end

function DataManager.addKill(player)
	local data = DataManager.get(player)
	data.Kills += 1
	saveQueued[player.UserId] = true
	fireLoaded(player)
end

function DataManager.addWin(player)
	local data = DataManager.get(player)
	data.Wins += 1
	saveQueued[player.UserId] = true
	fireLoaded(player)
end

function DataManager.addMatch(player)
	local data = DataManager.get(player)
	data.Matches += 1
	saveQueued[player.UserId] = true
	fireLoaded(player)
end

function DataManager.savePlayer(player)
	local data = cache[player.UserId]
	if not data then
		return
	end

	local ok, err = pcall(function()
		store:SetAsync(keyFor(player), data)
	end)

	if not ok then
		warn("[DataManager] Save failed for " .. player.Name .. ": " .. tostring(err))
	else
		saveQueued[player.UserId] = nil
	end
end

function DataManager.forget(player)
	cache[player.UserId] = nil
	saveQueued[player.UserId] = nil
end

function DataManager.startAutoSave(playersService)
	task.spawn(function()
		while true do
			task.wait(Constants.SAVE_INTERVAL)
			for _, player in ipairs(playersService:GetPlayers()) do
				if saveQueued[player.UserId] then
					DataManager.savePlayer(player)
				end
			end
		end
	end)
end

return DataManager
