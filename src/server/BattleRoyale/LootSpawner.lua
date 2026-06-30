local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage:WaitForChild("BattleRoyale"):WaitForChild("Config"))
local WeaponDefs = require(ReplicatedStorage:WaitForChild("BattleRoyale"):WaitForChild("WeaponDefs"))

local LootSpawner = {}
LootSpawner.__index = LootSpawner

local rarityOrder = { "Common", "Uncommon", "Rare", "Epic", "Legendary" }

local function getLootFolder()
	local folder = workspace:FindFirstChild("LootFolder")
	if not folder then
		folder = Instance.new("Folder")
		folder.Name = "LootFolder"
		folder.Parent = workspace
	end
	return folder
end

local function chooseRarity()
	local total = 0
	for _, rarity in ipairs(rarityOrder) do
		total += Config.RARITY_WEIGHTS[rarity] or 0
	end

	local roll = math.random() * total
	local cumulative = 0
	for _, rarity in ipairs(rarityOrder) do
		cumulative += Config.RARITY_WEIGHTS[rarity] or 0
		if roll <= cumulative then
			return rarity
		end
	end

	return "Common"
end

local function chooseWeapon()
	local rarity = chooseRarity()
	local candidates = {}
	for name, def in pairs(WeaponDefs) do
		if def.rarity == rarity then
			table.insert(candidates, name)
		end
	end

	if #candidates == 0 then
		for name in pairs(WeaponDefs) do
			table.insert(candidates, name)
		end
	end

	return candidates[math.random(1, #candidates)]
end

function LootSpawner.new()
	local self = setmetatable({}, LootSpawner)
	self._active = false
	self._connections = {}
	return self
end

function LootSpawner:clear()
	local folder = getLootFolder()
	folder:ClearAllChildren()

	for _, connection in ipairs(self._connections) do
		connection:Disconnect()
	end
	table.clear(self._connections)
end

function LootSpawner:createTool(weaponName)
	local def = WeaponDefs[weaponName]
	if not def then
		return nil
	end

	local tool = Instance.new("Tool")
	tool.Name = weaponName
	tool.ToolTip = def.displayName .. " [" .. def.rarity .. "]"
	tool.RequiresHandle = true
	tool.CanBeDropped = false
	tool:SetAttribute("Damage", def.damage)
	tool:SetAttribute("FireRate", def.fireRate)
	tool:SetAttribute("Range", def.range)
	tool:SetAttribute("MagSize", def.magSize)
	tool:SetAttribute("ReloadTime", def.reloadTime)

	local handle = Instance.new("Part")
	handle.Name = "Handle"
	handle.Size = Vector3.new(1.6, 0.45, 3.2)
	handle.Color = def.color or Color3.fromRGB(220, 220, 220)
	handle.Material = Enum.Material.Metal
	handle.CanCollide = false
	handle.Parent = tool

	local marker = Instance.new("Part")
	marker.Name = "Muzzle"
	marker.Size = Vector3.new(0.35, 0.35, 0.35)
	marker.Color = Color3.fromRGB(255, 240, 170)
	marker.Material = Enum.Material.Neon
	marker.CanCollide = false
	marker.Massless = true
	marker.CFrame = handle.CFrame * CFrame.new(0, 0, -1.75)
	marker.Parent = tool

	local weld = Instance.new("WeldConstraint")
	weld.Part0 = handle
	weld.Part1 = marker
	weld.Parent = handle

	local template = ReplicatedStorage:WaitForChild("BattleRoyale"):FindFirstChild("WeaponTool")
	if template then
		template:Clone().Parent = tool
	end

	return tool
end

function LootSpawner:spawnPickup(spawnPoint)
	local weaponName = chooseWeapon()
	local def = WeaponDefs[weaponName]
	if not def then
		return
	end

	local folder = getLootFolder()
	local pickup = Instance.new("Part")
	pickup.Name = "Pickup_" .. weaponName
	pickup.Anchored = true
	pickup.CanCollide = false
	pickup.Size = Vector3.new(4, 1, 4)
	pickup.CFrame = spawnPoint.CFrame + Vector3.new(0, 2.25, 0)
	pickup.Color = def.color or Color3.fromRGB(255, 255, 255)
	pickup.Material = Enum.Material.Neon
	pickup:SetAttribute("WeaponName", weaponName)
	pickup.Parent = folder

	local prompt = Instance.new("ProximityPrompt")
	prompt.ObjectText = def.displayName
	prompt.ActionText = "Pick up"
	prompt.MaxActivationDistance = 12
	prompt.HoldDuration = 0.15
	prompt.Parent = pickup

	local billboard = Instance.new("BillboardGui")
	billboard.Name = "LootLabel"
	billboard.AlwaysOnTop = true
	billboard.Size = UDim2.fromOffset(160, 44)
	billboard.StudsOffset = Vector3.new(0, 2.2, 0)
	billboard.Parent = pickup

	local label = Instance.new("TextLabel")
	label.BackgroundTransparency = 1
	label.Size = UDim2.fromScale(1, 1)
	label.Font = Enum.Font.GothamBold
	label.Text = def.displayName
	label.TextColor3 = Color3.fromRGB(255, 255, 255)
	label.TextStrokeTransparency = 0.25
	label.TextScaled = true
	label.Parent = billboard

	local connection = prompt.Triggered:Connect(function(player)
		if not player:GetAttribute("BRAlive") then
			return
		end

		local backpack = player:FindFirstChildOfClass("Backpack")
		if not backpack then
			return
		end

		local tool = self:createTool(weaponName)
		if tool then
			tool.Parent = backpack
			pickup:Destroy()
		end
	end)

	table.insert(self._connections, connection)
end

function LootSpawner:spawnAll()
	self:clear()
	local spawnPoints = CollectionService:GetTagged(Config.LOOT_SPAWN_TAG)
	for _, spawnPoint in ipairs(spawnPoints) do
		if spawnPoint:IsA("BasePart") then
			self:spawnPickup(spawnPoint)
		end
	end
end

return LootSpawner
