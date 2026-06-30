local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Debris = game:GetService("Debris")

local Constants = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Constants"))
local remotes = ReplicatedStorage:WaitForChild("Remotes")

remotes:WaitForChild(Constants.Remotes.HitEffect).OnClientEvent:Connect(function(hitPosition, damage)
	if typeof(hitPosition) ~= "Vector3" then
		return
	end

	local marker = Instance.new("Part")
	marker.Name = "HitEffect"
	marker.Anchored = true
	marker.CanCollide = false
	marker.Shape = Enum.PartType.Ball
	marker.Size = Vector3.new(0.7, 0.7, 0.7)
	marker.CFrame = CFrame.new(hitPosition)
	marker.Material = Enum.Material.Neon
	marker.Color = Color3.fromRGB(255, 80, 80)
	marker.Parent = workspace
	Debris:AddItem(marker, 0.35)

	local billboard = Instance.new("BillboardGui")
	billboard.AlwaysOnTop = true
	billboard.Size = UDim2.fromOffset(70, 34)
	billboard.StudsOffset = Vector3.new(0, 1.5, 0)
	billboard.Parent = marker

	local label = Instance.new("TextLabel")
	label.BackgroundTransparency = 1
	label.Size = UDim2.fromScale(1, 1)
	label.Font = Enum.Font.GothamBold
	label.Text = tostring(damage or "")
	label.TextColor3 = Color3.fromRGB(255, 245, 245)
	label.TextStrokeTransparency = 0.2
	label.TextScaled = true
	label.Parent = billboard
end)
