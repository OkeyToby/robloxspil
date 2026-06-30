local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")
local Constants = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Constants"))

local function addCorner(instance, radius)
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, radius or 6)
	corner.Parent = instance
end

local function ensureGui()
	local gui = playerGui:FindFirstChild("BattleRoyaleHUD")
	if not gui then
		gui = Instance.new("ScreenGui")
		gui.Name = "BattleRoyaleHUD"
		gui.ResetOnSpawn = false
		gui.Parent = playerGui
	end
	return gui
end

local function makeButton(parent, name, text, position)
	local button = parent:FindFirstChild(name)
	if button and button:IsA("TextButton") then
		return button
	end

	button = Instance.new("TextButton")
	button.Name = name
	button.BackgroundColor3 = Color3.fromRGB(32, 38, 48)
	button.BackgroundTransparency = 0.08
	button.BorderSizePixel = 0
	button.Position = position
	button.Size = UDim2.fromOffset(48, 36)
	button.Font = Enum.Font.GothamBold
	button.Text = text
	button.TextColor3 = Color3.fromRGB(255, 255, 255)
	button.TextSize = 20
	button.Parent = parent
	addCorner(button, 6)
	return button
end

local hud = ensureGui()
local spectatorHud = hud:FindFirstChild("SpectatorHUD")
if not spectatorHud then
	spectatorHud = Instance.new("Frame")
	spectatorHud.Name = "SpectatorHUD"
	spectatorHud.BackgroundTransparency = 1
	spectatorHud.Position = UDim2.fromScale(0.28, 0.09)
	spectatorHud.Size = UDim2.fromScale(0.44, 0.13)
	spectatorHud.Visible = false
	spectatorHud.Parent = hud

	local label = Instance.new("TextLabel")
	label.Name = "SpectatorLabel"
	label.BackgroundColor3 = Color3.fromRGB(20, 24, 30)
	label.BackgroundTransparency = 0.1
	label.BorderSizePixel = 0
	label.Position = UDim2.fromScale(0.14, 0)
	label.Size = UDim2.fromScale(0.72, 0.52)
	label.Font = Enum.Font.GothamBold
	label.TextColor3 = Color3.fromRGB(255, 255, 255)
	label.TextSize = 18
	label.Text = "Spectating"
	label.Parent = spectatorHud
	addCorner(label, 6)

	local hint = Instance.new("TextLabel")
	hint.Name = "CycleHint"
	hint.BackgroundTransparency = 1
	hint.Position = UDim2.fromScale(0.2, 0.56)
	hint.Size = UDim2.fromScale(0.6, 0.36)
	hint.Font = Enum.Font.GothamMedium
	hint.TextColor3 = Color3.fromRGB(230, 235, 245)
	hint.TextSize = 14
	hint.Text = "Q / E to switch target"
	hint.Parent = spectatorHud
end

local spectatorLabel = spectatorHud:WaitForChild("SpectatorLabel")
local prevButton = makeButton(spectatorHud, "PrevTarget", "<", UDim2.fromScale(0, 0.05))
local nextButton = makeButton(spectatorHud, "NextTarget", ">", UDim2.fromScale(0.89, 0.05))

local remotes = ReplicatedStorage:WaitForChild("Remotes")
local spectatorRemote = remotes:WaitForChild(Constants.Remotes.SpectatorTarget)
local cycleRemote = remotes:WaitForChild(Constants.Remotes.SpectatorCycle)

local function setCameraToPlayer(targetPlayer)
	local camera = Workspace.CurrentCamera
	local character = targetPlayer and targetPlayer.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if camera and humanoid then
		camera.CameraType = Enum.CameraType.Custom
		camera.CameraSubject = humanoid
	end
end

local function setCameraToSelf()
	local camera = Workspace.CurrentCamera
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if camera and humanoid then
		camera.CameraType = Enum.CameraType.Custom
		camera.CameraSubject = humanoid
	end
end

local function showTarget(targetPlayer)
	spectatorHud.Visible = true
	if targetPlayer then
		spectatorLabel.Text = "Spectating: " .. targetPlayer.Name
		setCameraToPlayer(targetPlayer)
	else
		spectatorLabel.Text = "No targets"
	end
end

spectatorRemote.OnClientEvent:Connect(function(action, targetPlayer)
	if action == "StartSpectating" or action == "SwitchTarget" then
		showTarget(targetPlayer)
	elseif action == "NoTargets" then
		showTarget(nil)
	elseif action == "StopSpectating" then
		spectatorHud.Visible = false
		setCameraToSelf()
	end
end)

local function cycle(direction)
	if spectatorHud.Visible then
		cycleRemote:FireServer(direction)
	end
end

prevButton.MouseButton1Click:Connect(function()
	cycle(-1)
end)

nextButton.MouseButton1Click:Connect(function()
	cycle(1)
end)

UserInputService.InputBegan:Connect(function(input, gameProcessed)
	if gameProcessed then
		return
	end

	if input.KeyCode == Enum.KeyCode.Q then
		cycle(-1)
	elseif input.KeyCode == Enum.KeyCode.E then
		cycle(1)
	end
end)
