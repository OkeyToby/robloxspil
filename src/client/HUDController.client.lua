local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")
local Config = require(ReplicatedStorage:WaitForChild("BattleRoyale"):WaitForChild("Config"))
local Constants = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Constants"))

local function addCorner(instance, radius)
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, radius or 6)
	corner.Parent = instance
end

local function ensureLabel(parent, name, position, size, textSize)
	local label = parent:FindFirstChild(name)
	if label and label:IsA("TextLabel") then
		return label
	end

	label = Instance.new("TextLabel")
	label.Name = name
	label.BackgroundColor3 = Color3.fromRGB(20, 24, 30)
	label.BackgroundTransparency = 0.15
	label.BorderSizePixel = 0
	label.Position = position
	label.Size = size
	label.Font = Enum.Font.GothamBold
	label.Text = ""
	label.TextColor3 = Color3.fromRGB(255, 255, 255)
	label.TextSize = textSize or 18
	label.TextWrapped = true
	label.Parent = parent
	addCorner(label, 6)
	return label
end

local function ensureGui()
	local gui = playerGui:FindFirstChild("BattleRoyaleHUD")
	if gui and gui:IsA("ScreenGui") then
		return gui
	end

	gui = Instance.new("ScreenGui")
	gui.Name = "BattleRoyaleHUD"
	gui.ResetOnSpawn = false
	gui.IgnoreGuiInset = false
	gui.Parent = playerGui
	return gui
end

local hud = ensureGui()
local stateLabel = ensureLabel(hud, "StateLabel", UDim2.fromScale(0.34, 0.03), UDim2.fromScale(0.32, 0.055), 20)
local aliveLabel = ensureLabel(hud, "AliveLabel", UDim2.fromScale(0.78, 0.04), UDim2.fromScale(0.18, 0.05), 18)
local statsLabel = ensureLabel(hud, "StatsLabel", UDim2.fromScale(0.04, 0.04), UDim2.fromScale(0.2, 0.05), 16)
local ammoLabel = ensureLabel(hud, "AmmoLabel", UDim2.fromScale(0.78, 0.89), UDim2.fromScale(0.16, 0.055), 22)
ammoLabel.Text = "-- / --"

local killFeed = hud:FindFirstChild("KillFeedFrame")
if not killFeed then
	killFeed = Instance.new("Frame")
	killFeed.Name = "KillFeedFrame"
	killFeed.BackgroundTransparency = 1
	killFeed.Position = UDim2.fromScale(0.035, 0.14)
	killFeed.Size = UDim2.fromScale(0.3, 0.28)
	killFeed.Parent = hud

	local layout = Instance.new("UIListLayout")
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Padding = UDim.new(0, 6)
	layout.Parent = killFeed
end

local minimap = hud:FindFirstChild("MinimapFrame")
if not minimap then
	minimap = Instance.new("Frame")
	minimap.Name = "MinimapFrame"
	minimap.BackgroundColor3 = Color3.fromRGB(14, 18, 22)
	minimap.BackgroundTransparency = 0.08
	minimap.BorderSizePixel = 0
	minimap.Position = UDim2.fromScale(0.04, 0.7)
	minimap.Size = UDim2.fromOffset(200, 200)
	minimap.ClipsDescendants = true
	minimap.Parent = hud
	addCorner(minimap, 8)

	local mapBackground = Instance.new("Frame")
	mapBackground.Name = "MapBackground"
	mapBackground.BackgroundColor3 = Color3.fromRGB(48, 60, 54)
	mapBackground.BorderSizePixel = 0
	mapBackground.Size = UDim2.fromScale(1, 1)
	mapBackground.Parent = minimap

	local targetCircle = Instance.new("Frame")
	targetCircle.Name = "TargetZoneCircle"
	targetCircle.BackgroundTransparency = 0.82
	targetCircle.BackgroundColor3 = Color3.fromRGB(255, 80, 80)
	targetCircle.BorderSizePixel = 2
	targetCircle.BorderColor3 = Color3.fromRGB(255, 80, 80)
	targetCircle.Parent = minimap
	addCorner(targetCircle, 999)

	local zoneCircle = Instance.new("Frame")
	zoneCircle.Name = "ZoneCircle"
	zoneCircle.BackgroundTransparency = 0.88
	zoneCircle.BackgroundColor3 = Color3.fromRGB(80, 170, 255)
	zoneCircle.BorderSizePixel = 2
	zoneCircle.BorderColor3 = Color3.fromRGB(80, 170, 255)
	zoneCircle.Parent = minimap
	addCorner(zoneCircle, 999)

	local playerDot = Instance.new("Frame")
	playerDot.Name = "PlayerDot"
	playerDot.BackgroundColor3 = Color3.fromRGB(255, 235, 80)
	playerDot.BorderSizePixel = 0
	playerDot.Size = UDim2.fromOffset(9, 9)
	playerDot.Parent = minimap
	addCorner(playerDot, 999)
end

local zoneCircle = minimap:WaitForChild("ZoneCircle")
local targetZoneCircle = minimap:WaitForChild("TargetZoneCircle")
local playerDot = minimap:WaitForChild("PlayerDot")
local mapRadius = Config.ARENA_RADIUS

local function worldToMinimap(x, z)
	local size = minimap.AbsoluteSize
	local px = (x / mapRadius) * (size.X / 2) + size.X / 2
	local py = (z / mapRadius) * (size.Y / 2) + size.Y / 2
	return px, py
end

local function updateCircle(circle, cx, cz, radius)
	local size = minimap.AbsoluteSize
	local px, py = worldToMinimap(cx, cz)
	local diameter = math.max((radius / mapRadius) * (size.X / 2) * 2, 4)
	circle.Size = UDim2.fromOffset(diameter, diameter)
	circle.Position = UDim2.fromOffset(px - diameter / 2, py - diameter / 2)
end

local remotes = ReplicatedStorage:WaitForChild("Remotes")

remotes:WaitForChild(Constants.Remotes.PlayerDataLoaded).OnClientEvent:Connect(function(data)
	statsLabel.Text = string.format("Wins: %d  Kills: %d", data.Wins or 0, data.Kills or 0)
end)

remotes:WaitForChild(Constants.Remotes.MatchState).OnClientEvent:Connect(function(phase, extra)
	if phase == "Waiting" then
		stateLabel.Text = "Waiting for players"
		aliveLabel.Text = "Need " .. tostring(extra)
	elseif phase == "Intermission" then
		stateLabel.Text = "Intermission"
		aliveLabel.Text = tostring(extra) .. "s"
	elseif phase == "Countdown" then
		stateLabel.Text = "Match starts in " .. tostring(extra)
	elseif phase == "Deploying" then
		stateLabel.Text = "Deploying"
	elseif phase == "Playing" then
		stateLabel.Text = "Fight"
		aliveLabel.Text = tostring(extra) .. " alive"
	elseif phase == "Victory" then
		stateLabel.Text = "Winner: " .. tostring(extra)
	elseif phase == "Cleanup" then
		stateLabel.Text = "Returning to lobby"
	else
		stateLabel.Text = tostring(phase)
	end
end)

remotes:WaitForChild(Constants.Remotes.KillFeed).OnClientEvent:Connect(function(killerName, victimName, placement)
	local row = Instance.new("TextLabel")
	row.BackgroundColor3 = Color3.fromRGB(20, 24, 30)
	row.BackgroundTransparency = 0.12
	row.BorderSizePixel = 0
	row.Size = UDim2.new(1, 0, 0, 28)
	row.Font = Enum.Font.GothamMedium
	row.TextColor3 = Color3.fromRGB(255, 255, 255)
	row.TextSize = 14
	row.TextXAlignment = Enum.TextXAlignment.Left
	row.Text = string.format("  %s -> %s  (#%d)", tostring(killerName), tostring(victimName), tonumber(placement) or 0)
	row.Parent = killFeed
	addCorner(row, 5)

	task.delay(6, function()
		if row.Parent then
			row:Destroy()
		end
	end)
end)

remotes:WaitForChild(Constants.Remotes.ZoneUpdate).OnClientEvent:Connect(function(cx, cz, radius, tcx, tcz, targetRadius)
	updateCircle(zoneCircle, cx, cz, radius)
	updateCircle(targetZoneCircle, tcx, tcz, targetRadius)
end)

RunService.RenderStepped:Connect(function()
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if root then
		local px, py = worldToMinimap(root.Position.X, root.Position.Z)
		playerDot.Position = UDim2.fromOffset(px - 4.5, py - 4.5)
	end
end)
