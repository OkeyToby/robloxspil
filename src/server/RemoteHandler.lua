local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Constants = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Constants"))

local RemoteHandler = {}
local remoteFolder = nil
local remoteWindows = {}

local function ensureFolder()
	if remoteFolder and remoteFolder.Parent then
		return remoteFolder
	end

	remoteFolder = ReplicatedStorage:FindFirstChild("Remotes")
	if not remoteFolder then
		remoteFolder = Instance.new("Folder")
		remoteFolder.Name = "Remotes"
		remoteFolder.Parent = ReplicatedStorage
	end

	return remoteFolder
end

function RemoteHandler.createRemote(name, className)
	local folder = ensureFolder()
	local existing = folder:FindFirstChild(name)
	if existing then
		return existing
	end

	local remote = Instance.new(className or "RemoteEvent")
	remote.Name = name
	remote.Parent = folder
	return remote
end

function RemoteHandler.init()
	ensureFolder()

	for _, remoteName in pairs(Constants.Remotes) do
		RemoteHandler.createRemote(remoteName, "RemoteEvent")
	end
end

function RemoteHandler.getRemote(name)
	return ensureFolder():WaitForChild(name)
end

function RemoteHandler.fireClient(name, player, ...)
	local remote = ensureFolder():FindFirstChild(name)
	if remote and remote:IsA("RemoteEvent") then
		remote:FireClient(player, ...)
	end
end

function RemoteHandler.fireAllClients(name, ...)
	local remote = ensureFolder():FindFirstChild(name)
	if remote and remote:IsA("RemoteEvent") then
		remote:FireAllClients(...)
	end
end

function RemoteHandler.checkRate(player, key, maxCount, windowSeconds)
	local now = os.clock()
	local playerKey = player.UserId .. ":" .. key
	local bucket = remoteWindows[playerKey]

	if not bucket or now - bucket.startedAt > windowSeconds then
		remoteWindows[playerKey] = {
			startedAt = now,
			count = 1,
		}
		return true
	end

	bucket.count += 1
	return bucket.count <= maxCount
end

return RemoteHandler
