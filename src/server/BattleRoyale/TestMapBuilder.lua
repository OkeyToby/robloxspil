local CollectionService = game:GetService("CollectionService")

local Config = require(game:GetService("ReplicatedStorage"):WaitForChild("BattleRoyale"):WaitForChild("Config"))

local TestMapBuilder = {}

local function createPart(parent, name, size, cframe, color, material)
	local existing = parent:FindFirstChild(name)
	if existing and existing:IsA("BasePart") then
		return existing
	end

	local part = Instance.new("Part")
	part.Name = name
	part.Anchored = true
	part.Size = size
	part.CFrame = cframe
	part.Color = color
	part.Material = material or Enum.Material.SmoothPlastic
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	part.Parent = parent
	return part
end

local function ensureFolder(parent, name)
	local folder = parent:FindFirstChild(name)
	if not folder then
		folder = Instance.new("Folder")
		folder.Name = name
		folder.Parent = parent
	end
	return folder
end

local function ensureLobbySpawn()
	local existing = workspace:FindFirstChild("LobbySpawn")
	if existing and existing:IsA("SpawnLocation") then
		return existing
	end

	local spawnLocation = Instance.new("SpawnLocation")
	spawnLocation.Name = "LobbySpawn"
	spawnLocation.Anchored = true
	spawnLocation.Neutral = true
	spawnLocation.AllowTeamChangeOnTouch = false
	spawnLocation.Duration = 0
	spawnLocation.Size = Vector3.new(12, 1, 12)
	spawnLocation.CFrame = CFrame.new(0, 18, -455)
	spawnLocation.Color = Color3.fromRGB(95, 190, 255)
	spawnLocation.Material = Enum.Material.Neon
	spawnLocation.Parent = workspace
	return spawnLocation
end

local function ensureLootSpawns(parent)
	local tagged = CollectionService:GetTagged(Config.LOOT_SPAWN_TAG)
	if #tagged > 0 then
		return
	end

	local spawnFolder = ensureFolder(parent, "LootSpawnPoints")
	for i = 1, 18 do
		local angle = (math.pi * 2) * (i / 18)
		local radius = 55 + ((i % 4) * 55)
		local x = math.cos(angle) * radius
		local z = math.sin(angle) * radius
		local part = createPart(
			spawnFolder,
			string.format("LootSpawn%02d", i),
			Vector3.new(4, 0.3, 4),
			CFrame.new(x, 7.2, z),
			Color3.fromRGB(255, 235, 120),
			Enum.Material.Neon
		)
		part.Transparency = 0.35
		CollectionService:AddTag(part, Config.LOOT_SPAWN_TAG)
	end
end

function TestMapBuilder.ensure()
	local mapFolder = ensureFolder(workspace, "Map")
	ensureFolder(workspace, "LootFolder")
	ensureLobbySpawn()

	local generated = ensureFolder(mapFolder, "BR_GeneratedTestAssets")
	createPart(
		generated,
		"ArenaBase",
		Vector3.new(Config.ARENA_RADIUS * 2, 2, Config.ARENA_RADIUS * 2),
		CFrame.new(0, 5, 0),
		Color3.fromRGB(72, 118, 76),
		Enum.Material.Grass
	)

	createPart(generated, "NorthWall", Vector3.new(Config.ARENA_RADIUS * 2, 36, 4), CFrame.new(0, 23, -Config.ARENA_RADIUS), Color3.fromRGB(80, 85, 95), Enum.Material.Concrete)
	createPart(generated, "SouthWall", Vector3.new(Config.ARENA_RADIUS * 2, 36, 4), CFrame.new(0, 23, Config.ARENA_RADIUS), Color3.fromRGB(80, 85, 95), Enum.Material.Concrete)
	createPart(generated, "EastWall", Vector3.new(4, 36, Config.ARENA_RADIUS * 2), CFrame.new(Config.ARENA_RADIUS, 23, 0), Color3.fromRGB(80, 85, 95), Enum.Material.Concrete)
	createPart(generated, "WestWall", Vector3.new(4, 36, Config.ARENA_RADIUS * 2), CFrame.new(-Config.ARENA_RADIUS, 23, 0), Color3.fromRGB(80, 85, 95), Enum.Material.Concrete)

	for i = 1, 10 do
		local angle = (math.pi * 2) * (i / 10)
		local radius = 80 + ((i % 3) * 45)
		createPart(
			generated,
			string.format("Cover%02d", i),
			Vector3.new(24, 18, 16),
			CFrame.new(math.cos(angle) * radius, 14, math.sin(angle) * radius) * CFrame.Angles(0, angle, 0),
			Color3.fromRGB(95, 100, 110),
			Enum.Material.Slate
		)
	end

	ensureLootSpawns(generated)
end

return TestMapBuilder
