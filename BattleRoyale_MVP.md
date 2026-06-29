# Battle Royale MVP — Roblox Script Guide

Opret disse scripts i Roblox Studio i den rækkefølge de er listet.
Tryk F5 for at teste. Forventet Output: ingen røde fejl.

---

## ARKITEKTUR OVERSIGT

```
ServerScriptService/
  GameManager          (Script)        ← entry point
  DataManager          (ModuleScript)  ← data persistence
  RemoteHandler        (ModuleScript)  ← remote security
  BattleRoyale/
    MatchManager       (ModuleScript)  ← state machine & game loop
    StormSystem        (ModuleScript)  ← shrinking zone
    LootSpawner        (ModuleScript)  ← item distribution
    EliminationTracker (ModuleScript)  ← kill feed & placement

ReplicatedStorage/
  Shared/
    Constants          (ModuleScript)
  BattleRoyale/
    Config             (ModuleScript)  ← match settings, zone timings
    WeaponDefs         (ModuleScript)  ← weapons med rarity
  Remotes/             (Folder — laves automatisk af GameManager)

StarterGui/
  BattleRoyaleHUD      (ScreenGui)
    HUDController      (LocalScript)
    AliveLabel         (TextLabel)
    KillFeedFrame      (Frame)

StarterPlayer/StarterPlayerScripts/
  ClientController     (LocalScript)

Workspace/
  LobbySpawn           (SpawnLocation)
  LootFolder           (Folder)
  Map/                 (Folder til dit map)
```

---

## SETUP — STEP BY STEP

### 1. Opret folder-strukturen i Explorer

- ServerScriptService → Insert Folder → navn: `BattleRoyale`
- ReplicatedStorage → Insert Folder → navn: `Shared`
- ReplicatedStorage → Insert Folder → navn: `BattleRoyale`
- Workspace → Insert Folder → navn: `LootFolder`
- Workspace → Insert Folder → navn: `Map`
- StarterGui → Insert ScreenGui → navn: `BattleRoyaleHUD`, ResetOnSpawn = false

### 2. Opret UI elementer inde i BattleRoyaleHUD

- Insert TextLabel → navn: `AliveLabel` (Position: {0.8,0},{0.05,0}, Size: {0.15,0},{0.05,0})
- Insert Frame → navn: `KillFeedFrame` (Position: {0,0},{0.3,0}, Size: {0.25,0},{0.35,0})

### 3. Opret en SpawnLocation i Workspace, navn: `LobbySpawn`

### 4. Tag alle loot-spawn-points og giv dem CollectionService tag: `LootSpawn`
   (Right-click part → Add Tag → skriv "LootSpawn")

### 5. Enable DataStore i Studio: Game Settings → Security → Enable Studio Access to API Services

---

## SCRIPTS

---

### ReplicatedStorage/Shared/Constants (ModuleScript)

```lua
--!strict
local Constants = {
	SAVE_INTERVAL = 300,
	DATA_STORE_NAME = "BattleRoyale_v1",
	MAX_REMOTE_RATE = 20,
	REMOTE_WINDOW = 10,
	REMOTE_KICK_THRESHOLD = 5,
	Remotes = {
		PlayerDataLoaded = "PlayerDataLoaded",
		UpdateUI = "UpdateUI",
	},
}
return Constants
```

---

### ReplicatedStorage/BattleRoyale/Config (ModuleScript)

```lua
--!strict
local Config = {
	-- Antal spillere
	MIN_PLAYERS = 2,    -- sæt til 2 for nemt at teste i Studio
	MAX_PLAYERS = 50,

	-- Fase-varighed (sekunder)
	LOBBY_INTERMISSION = 8,
	COUNTDOWN_DURATION = 10,
	DEPLOY_DURATION = 3,       -- kort for MVP (ingen rigtig drop-animation)
	VICTORY_SCREEN_DURATION = 6,
	CLEANUP_DURATION = 4,

	-- Zone / Storm
	ZONE_INITIAL_RADIUS = 400,
	ZONE_DAMAGE_PER_TICK = 5,
	ZONE_TICK_INTERVAL = 1.0,
	ZONE_PHASES = {
		{ waitTime = 60, shrinkTime = 30, radiusFraction = 0.6 },
		{ waitTime = 45, shrinkTime = 25, radiusFraction = 0.35 },
		{ waitTime = 30, shrinkTime = 20, radiusFraction = 0.15 },
		{ waitTime = 20, shrinkTime = 15, radiusFraction = 0.05 },
	},

	-- Loot
	LOOT_SPAWN_TAG = "LootSpawn",
	RARITY_WEIGHTS = {
		Common    = 40,
		Uncommon  = 30,
		Rare      = 18,
		Epic      = 9,
		Legendary = 3,
	},

	-- Spawn position ved match-start (sky-drop forenklet til teleport)
	DROP_HEIGHT = 200,
}
return Config
```

---

### ReplicatedStorage/BattleRoyale/WeaponDefs (ModuleScript)

```lua
--!strict
local WeaponDefs = {
	-- Assault Rifles
	AR_Common     = { rarity = "Common",    baseDamage = 18, fireRate = 5.5, magSize = 30, reloadTime = 2.2, weaponType = "AR" },
	AR_Rare       = { rarity = "Rare",      baseDamage = 23, fireRate = 5.5, magSize = 30, reloadTime = 1.8, weaponType = "AR" },
	AR_Legendary  = { rarity = "Legendary", baseDamage = 32, fireRate = 6.0, magSize = 35, reloadTime = 1.4, weaponType = "AR" },

	-- Shotguns
	SG_Common     = { rarity = "Common",    baseDamage = 70,  fireRate = 1.0, magSize = 5, reloadTime = 4.5, weaponType = "Shotgun" },
	SG_Legendary  = { rarity = "Legendary", baseDamage = 110, fireRate = 1.1, magSize = 6, reloadTime = 3.5, weaponType = "Shotgun" },

	-- SMGs
	SMG_Common    = { rarity = "Common",    baseDamage = 12, fireRate = 10.0, magSize = 25, reloadTime = 1.8, weaponType = "SMG" },
	SMG_Epic      = { rarity = "Epic",      baseDamage = 18, fireRate = 11.0, magSize = 35, reloadTime = 1.4, weaponType = "SMG" },

	-- Snipers
	Sniper_Rare   = { rarity = "Rare",      baseDamage = 90,  fireRate = 0.5, magSize = 5, reloadTime = 3.0, weaponType = "Sniper" },
	Sniper_Leg    = { rarity = "Legendary", baseDamage = 130, fireRate = 0.5, magSize = 5, reloadTime = 2.5, weaponType = "Sniper" },

	-- Pistols
	Pistol_Common = { rarity = "Common",    baseDamage = 22, fireRate = 3.5, magSize = 12, reloadTime = 1.5, weaponType = "Pistol" },
}
return WeaponDefs
```

---

### ServerScriptService/DataManager (ModuleScript)

```lua
--!strict
local Players = game:GetService("Players")
local DataStoreService = game:GetService("DataStoreService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Constants = require(ReplicatedStorage.Shared.Constants)

local DataManager = {}

local PROFILE_TEMPLATE = {
	DataVersion = 1,
	Wins = 0,
	Kills = 0,
	GamesPlayed = 0,
}

local dataStore = DataStoreService:GetDataStore(Constants.DATA_STORE_NAME)
local cache = {}
local MAX_RETRIES = 3

local function deepClone(t)
	local c = {}
	for k, v in t do
		c[k] = (typeof(v) == "table") and deepClone(v) or v
	end
	return c
end

local function reconcile(data, template)
	for k, v in template do
		if data[k] == nil then
			data[k] = (typeof(v) == "table") and deepClone(v) or v
		end
	end
end

local function loadData(player)
	local key = "Player_" .. player.UserId
	for i = 1, MAX_RETRIES do
		local ok, result = pcall(function()
			return dataStore:GetAsync(key)
		end)
		if ok then
			local data = result or deepClone(PROFILE_TEMPLATE)
			reconcile(data, PROFILE_TEMPLATE)
			return data
		end
		warn("[DataManager] Load fejl attempt " .. i .. ": " .. tostring(result))
		task.wait(2 * i)
	end
	return nil
end

local function saveData(player)
	local data = cache[player]
	if not data then return end
	local key = "Player_" .. player.UserId
	for i = 1, MAX_RETRIES do
		local ok, err = pcall(function()
			dataStore:UpdateAsync(key, function() return data end)
		end)
		if ok then return end
		warn("[DataManager] Save fejl attempt " .. i .. ": " .. tostring(err))
		task.wait(2 * i)
	end
end

function DataManager.init() print("[DataManager] Klar") end

function DataManager.loadPlayer(player)
	local data = loadData(player)
	if not data then
		player:Kick("Kunne ikke indlæse data. Prøv igen.")
		return
	end
	if not player:IsDescendantOf(Players) then return end
	cache[player] = data

	-- Leaderstats
	local ls = Instance.new("Folder")
	ls.Name = "leaderstats"
	local wins = Instance.new("IntValue")
	wins.Name = "Wins"; wins.Value = data.Wins; wins.Parent = ls
	local kills = Instance.new("IntValue")
	kills.Name = "Kills"; kills.Value = data.Kills; kills.Parent = ls
	ls.Parent = player

	data.GamesPlayed += 1

	-- Fortæl klienten at data er klar
	local remotes = ReplicatedStorage:FindFirstChild("Remotes")
	if remotes then
		local r = remotes:FindFirstChild(Constants.Remotes.PlayerDataLoaded)
		if r and r:IsA("RemoteEvent") then
			r:FireClient(player, { Wins = data.Wins, Kills = data.Kills })
		end
	end
	print("[DataManager] Indlæst: " .. player.Name)
end

function DataManager.unloadPlayer(player)
	if cache[player] then
		saveData(player)
		cache[player] = nil
	end
end

function DataManager.getData(player) return cache[player] end

function DataManager.addKill(player)
	local data = cache[player]
	if not data then return end
	data.Kills += 1
	local ls = player:FindFirstChild("leaderstats")
	if ls then
		local k = ls:FindFirstChild("Kills")
		if k then k.Value = data.Kills end
	end
end

function DataManager.addWin(player)
	local data = cache[player]
	if not data then return end
	data.Wins += 1
	local ls = player:FindFirstChild("leaderstats")
	if ls then
		local w = ls:FindFirstChild("Wins")
		if w then w.Value = data.Wins end
	end
end

function DataManager.saveAllPlayers()
	for player in cache do task.spawn(saveData, player) end
end

function DataManager.saveAllPlayersSync()
	local players = Players:GetPlayers()
	if #players == 0 then return end
	local remaining = #players
	local done = Instance.new("BindableEvent")
	for _, p in players do
		task.spawn(function()
			saveData(p)
			remaining -= 1
			if remaining <= 0 then done:Fire() end
		end)
	end
	task.delay(25, function() done:Fire() end)
	done.Event:Wait()
	done:Destroy()
end

return DataManager
```

---

### ServerScriptService/RemoteHandler (ModuleScript)

```lua
--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Constants = require(ReplicatedStorage.Shared.Constants)

local RemoteHandler = {}
local rateLimitData = {}
local cooldownData = {}
local violationCounts = {}

local function checkRate(player, name, max)
	local now = os.clock()
	if not rateLimitData[player] then rateLimitData[player] = {} end
	if not rateLimitData[player][name] then rateLimitData[player][name] = {} end
	local ts = rateLimitData[player][name]
	local pruned = {}
	for _, t in ts do
		if now - t < Constants.REMOTE_WINDOW then table.insert(pruned, t) end
	end
	rateLimitData[player][name] = pruned
	if #pruned >= max then
		violationCounts[player] = (violationCounts[player] or 0) + 1
		if violationCounts[player] >= Constants.REMOTE_KICK_THRESHOLD then
			task.defer(function() player:Kick("For mange requests.") end)
		end
		return false
	end
	table.insert(pruned, now)
	return true
end

local function checkCooldown(player, name, cd)
	local now = os.clock()
	if not cooldownData[player] then cooldownData[player] = {} end
	local last = cooldownData[player][name]
	if last and now - last < cd then return false end
	cooldownData[player][name] = now
	return true
end

function RemoteHandler.init()
	local rf = ReplicatedStorage:FindFirstChild("Remotes")
	if not rf then
		rf = Instance.new("Folder")
		rf.Name = "Remotes"
		rf.Parent = ReplicatedStorage
	end
	RemoteHandler.createRemote(Constants.Remotes.PlayerDataLoaded, "Event")
	RemoteHandler.createRemote(Constants.Remotes.UpdateUI, "Event")
	print("[RemoteHandler] Klar")
end

function RemoteHandler.createRemote(name, kind)
	local rf = ReplicatedStorage:WaitForChild("Remotes")
	local ex = rf:FindFirstChild(name)
	if ex then return ex end
	local r = Instance.new(kind == "Function" and "RemoteFunction" or "RemoteEvent")
	r.Name = name
	r.Parent = rf
	return r
end

function RemoteHandler.register(cfg)
	local remote = RemoteHandler.createRemote(cfg.Name, cfg.Type)
	local cd = cfg.Cooldown or 0
	local maxRate = cfg.RateLimit or Constants.MAX_REMOTE_RATE
	if cfg.Type == "Event" then
		remote.OnServerEvent:Connect(function(player, ...)
			if not checkRate(player, cfg.Name, maxRate) then return end
			if cd > 0 and not checkCooldown(player, cfg.Name, cd) then return end
			if cfg.Validator then
				local ok, reason = cfg.Validator(player, ...)
				if not ok then
					warn("[RemoteHandler] Validation fejl: " .. (reason or "?"))
					return
				end
			end
			cfg.Handler(player, ...)
		end)
	end
end

function RemoteHandler.cleanupPlayer(player)
	rateLimitData[player] = nil
	cooldownData[player] = nil
	violationCounts[player] = nil
end

function RemoteHandler.fireClient(name, player, ...)
	local rf = ReplicatedStorage:FindFirstChild("Remotes")
	if not rf then return end
	local r = rf:FindFirstChild(name)
	if r and r:IsA("RemoteEvent") then r:FireClient(player, ...) end
end

function RemoteHandler.fireAll(name, ...)
	local rf = ReplicatedStorage:FindFirstChild("Remotes")
	if not rf then return end
	local r = rf:FindFirstChild(name)
	if r and r:IsA("RemoteEvent") then r:FireAllClients(...) end
end

return RemoteHandler
```

---

### ServerScriptService/BattleRoyale/EliminationTracker (ModuleScript)

```lua
--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local EliminationTracker = {}

local killCounts: { [Player]: number } = {}
local placements: { [Player]: number } = {}

-- Lav KillFeed remote
local function getKillFeedRemote()
	local rf = ReplicatedStorage:FindFirstChild("Remotes")
	if not rf then return nil end
	local existing = rf:FindFirstChild("KillFeed")
	if existing then return existing end
	local r = Instance.new("RemoteEvent")
	r.Name = "KillFeed"
	r.Parent = rf
	return r
end

function EliminationTracker:Reset()
	table.clear(killCounts)
	table.clear(placements)
end

function EliminationTracker:RecordElimination(victim: Player, killer: Player?, placement: number)
	placements[victim] = placement
	if killer and killer ~= victim then
		killCounts[killer] = (killCounts[killer] or 0) + 1
	end

	local killerName = (killer and killer ~= victim) and killer.Name or "Zonen"
	print(string.format("[EliminationTracker] %s eliminerede %s (#%d)", killerName, victim.Name, placement))

	local r = getKillFeedRemote()
	if r then r:FireAllClients(killerName, victim.Name, placement) end

	-- Drop inventory
	self:_dropInventory(victim)
end

function EliminationTracker:RecordDisconnect(player: Player, placement: number)
	placements[player] = placement
	local r = getKillFeedRemote()
	if r then r:FireAllClients("Disconnect", player.Name, placement) end
end

function EliminationTracker:GetKillCount(player: Player): number
	return killCounts[player] or 0
end

function EliminationTracker:_dropInventory(player: Player)
	local char = player.Character
	if not char then return end
	local root = char:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not root then return end
	local lootFolder = workspace:FindFirstChild("LootFolder")
	if not lootFolder then return end
	for _, tool in player.Backpack:GetChildren() do
		if tool:IsA("Tool") then
			tool.Parent = lootFolder
			local handle = tool:FindFirstChild("Handle") :: BasePart?
			if handle then
				handle.CFrame = root.CFrame * CFrame.new(math.random(-3,3), 1, math.random(-3,3))
			end
		end
	end
end

function EliminationTracker:FinalizeResults(winner: Player?)
	if winner then
		placements[winner] = 1
		killCounts[winner] = killCounts[winner] or 0
		print(string.format("[EliminationTracker] VINDER: %s (%d kills)", winner.Name, killCounts[winner]))
	end
end

return EliminationTracker
```

---

### ServerScriptService/BattleRoyale/LootSpawner (ModuleScript)

```lua
--!strict
local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.BattleRoyale.Config)
local WeaponDefs = require(ReplicatedStorage.BattleRoyale.WeaponDefs)

local LootSpawner = {}

local spawnedLoot: { Instance } = {}

local function rollRarity(): string
	local total = 0
	for _, w in Config.RARITY_WEIGHTS do total += w end
	local roll = math.random() * total
	local cum = 0
	for rarity, weight in Config.RARITY_WEIGHTS do
		cum += weight
		if roll <= cum then return rarity end
	end
	return "Common"
end

local function pickWeapon(rarity: string): string?
	local candidates = {}
	for name, def in WeaponDefs do
		if def.rarity == rarity then table.insert(candidates, name) end
	end
	if #candidates == 0 then return nil end
	return candidates[math.random(#candidates)]
end

-- Lav en simpel Part der repræsenterer et loot-item (erstat med rigtige models)
local function createLootPart(weaponName: string, rarity: string, cf: CFrame): Part
	local part = Instance.new("Part")
	part.Name = weaponName
	part.Size = Vector3.new(1, 0.5, 2)
	part.Anchored = false
	part.CanCollide = true

	-- Farve baseret på rarity
	local colors = {
		Common    = Color3.fromRGB(200,200,200),
		Uncommon  = Color3.fromRGB(30,200,30),
		Rare      = Color3.fromRGB(30,100,255),
		Epic      = Color3.fromRGB(160,50,255),
		Legendary = Color3.fromRGB(255,200,0),
	}
	part.Color = colors[rarity] or colors.Common
	part.Material = Enum.Material.Neon
	part.CFrame = cf

	-- Metadata
	local rv = Instance.new("StringValue")
	rv.Name = "Rarity"; rv.Value = rarity; rv.Parent = part
	local wv = Instance.new("StringValue")
	wv.Name = "WeaponName"; wv.Value = weaponName; wv.Parent = part

	-- ProximityPrompt til pickup
	local pp = Instance.new("ProximityPrompt")
	pp.ActionText = "Tag op"
	pp.ObjectText = weaponName .. " [" .. rarity .. "]"
	pp.HoldDuration = 0.2
	pp.MaxActivationDistance = 8
	pp.Parent = part

	return part
end

function LootSpawner:SpawnAllLoot()
	self:DespawnAllLoot()

	local points = CollectionService:GetTagged(Config.LOOT_SPAWN_TAG)
	local lootFolder = workspace:FindFirstChild("LootFolder")
	if not lootFolder then
		lootFolder = Instance.new("Folder")
		lootFolder.Name = "LootFolder"
		lootFolder.Parent = workspace
	end

	local count = 0
	for _, point in points do
		if not point:IsA("BasePart") then continue end
		local rarity = rollRarity()
		local weaponName = pickWeapon(rarity)
		if not weaponName then continue end

		local spawnCF = point.CFrame * CFrame.new(0, 1, 0)
		local lootPart = createLootPart(weaponName, rarity, spawnCF)
		lootPart.Parent = lootFolder
		table.insert(spawnedLoot, lootPart)
		count += 1
	end

	print(string.format("[LootSpawner] Spawnet %d items ved %d punkter", count, #points))
end

function LootSpawner:DespawnAllLoot()
	for _, item in spawnedLoot do
		if item.Parent then item:Destroy() end
	end
	table.clear(spawnedLoot)
end

return LootSpawner
```

---

### ServerScriptService/BattleRoyale/StormSystem (ModuleScript)

```lua
--!strict
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.BattleRoyale.Config)

local StormSystem = {}
StormSystem.__index = StormSystem

function StormSystem.new()
	local self = setmetatable({}, StormSystem)
	self._running = false
	self._phaseIndex = 0
	self._damageAccum = 0
	self._currentZone = { cx = 0, cz = 0, radius = Config.ZONE_INITIAL_RADIUS }
	self._targetZone  = { cx = 0, cz = 0, radius = Config.ZONE_INITIAL_RADIUS }
	self._isShrinking = false

	-- Lav ZoneUpdate remote
	local rf = ReplicatedStorage:WaitForChild("Remotes")
	if not rf:FindFirstChild("ZoneUpdate") then
		local r = Instance.new("RemoteEvent")
		r.Name = "ZoneUpdate"
		r.Parent = rf
	end
	return self
end

function StormSystem:_broadcast()
	local r = ReplicatedStorage.Remotes:FindFirstChild("ZoneUpdate")
	if r then
		r:FireAllClients(
			self._currentZone.cx, self._currentZone.cz, self._currentZone.radius,
			self._targetZone.cx,  self._targetZone.cz,  self._targetZone.radius,
			self._isShrinking
		)
	end
end

function StormSystem:IsInsideZone(pos: Vector3): boolean
	local dx = pos.X - self._currentZone.cx
	local dz = pos.Z - self._currentZone.cz
	return dx*dx + dz*dz <= self._currentZone.radius * self._currentZone.radius
end

function StormSystem:_applyDamage()
	for _, player in Players:GetPlayers() do
		local char = player.Character
		if not char then continue end
		local hum = char:FindFirstChildOfClass("Humanoid")
		local root = char:FindFirstChild("HumanoidRootPart") :: BasePart?
		if not hum or not root or hum.Health <= 0 then continue end
		if not self:IsInsideZone(root.Position) then
			local dmg = Config.ZONE_DAMAGE_PER_TICK * math.max(1, self._phaseIndex)
			hum:TakeDamage(dmg)
		end
	end
end

function StormSystem:_runPhase(phase)
	local nextR = Config.ZONE_INITIAL_RADIUS * phase.radiusFraction
	local maxOff = math.max(0, self._currentZone.radius - nextR)
	local angle = math.random() * 2 * math.pi
	local dist = math.random() * maxOff
	self._targetZone = {
		cx = self._currentZone.cx + math.cos(angle) * dist,
		cz = self._currentZone.cz + math.sin(angle) * dist,
		radius = nextR,
	}

	-- Vent-periode
	self._isShrinking = false
	self:_broadcast()
	print(string.format("[StormSystem] Fase %d: venter %ds", self._phaseIndex, phase.waitTime))
	local elapsed = 0
	while elapsed < phase.waitTime and self._running do
		task.wait(1)
		elapsed += 1
	end
	if not self._running then return end

	-- Krympe-periode
	self._isShrinking = true
	self:_broadcast()
	print(string.format("[StormSystem] Fase %d: krymper over %ds", self._phaseIndex, phase.shrinkTime))
	local startZone = { cx = self._currentZone.cx, cz = self._currentZone.cz, radius = self._currentZone.radius }
	local shrinkElapsed = 0
	while shrinkElapsed < phase.shrinkTime and self._running do
		local dt = task.wait()
		shrinkElapsed += dt
		local alpha = math.clamp(shrinkElapsed / phase.shrinkTime, 0, 1)
		local smooth = alpha * alpha * (3 - 2 * alpha)
		self._currentZone.cx = startZone.cx + (self._targetZone.cx - startZone.cx) * smooth
		self._currentZone.cz = startZone.cz + (self._targetZone.cz - startZone.cz) * smooth
		self._currentZone.radius = startZone.radius + (self._targetZone.radius - startZone.radius) * smooth
		self:_broadcast()
	end

	self._currentZone = { cx = self._targetZone.cx, cz = self._targetZone.cz, radius = self._targetZone.radius }
	self._isShrinking = false
	self:_broadcast()
end

function StormSystem:Tick()
	if not self._running then return end
	self._damageAccum += 0.5
	if self._damageAccum >= Config.ZONE_TICK_INTERVAL then
		self._damageAccum -= Config.ZONE_TICK_INTERVAL
		self:_applyDamage()
	end
end

function StormSystem:Start()
	self._running = true
	self._phaseIndex = 0
	self._damageAccum = 0
	self._currentZone = { cx = 0, cz = 0, radius = Config.ZONE_INITIAL_RADIUS }
	self._targetZone  = { cx = 0, cz = 0, radius = Config.ZONE_INITIAL_RADIUS }
	self:_broadcast()

	task.spawn(function()
		for i, phase in Config.ZONE_PHASES do
			if not self._running then break end
			self._phaseIndex = i
			self:_runPhase(phase)
		end
		print("[StormSystem] Alle faser færdige — zonen er lukket.")
	end)
end

function StormSystem:Stop()
	self._running = false
end

return StormSystem
```

---

### ServerScriptService/BattleRoyale/MatchManager (ModuleScript)

```lua
--!strict
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local Config = require(ReplicatedStorage.BattleRoyale.Config)

local MatchManager = {}
MatchManager.__index = MatchManager

export type Phase = "Lobby"|"Waiting"|"Countdown"|"InProgress"|"Victory"|"Cleanup"

function MatchManager.new(deps)
	local self = setmetatable({}, MatchManager)
	self._storm    = deps.storm
	self._loot     = deps.loot
	self._elim     = deps.elim
	self._data     = deps.data
	self._phase    = "Lobby" :: Phase
	self._alive    = {} :: { [Player]: boolean }
	self._winner   = nil :: Player?

	-- MatchState remote
	local rf = ReplicatedStorage:WaitForChild("Remotes")
	if not rf:FindFirstChild("MatchState") then
		local r = Instance.new("RemoteEvent")
		r.Name = "MatchState"
		r.Parent = rf
	end
	self._matchStateRemote = rf:WaitForChild("MatchState") :: RemoteEvent

	return self
end

function MatchManager:_setPhase(p: Phase)
	self._phase = p
	self._matchStateRemote:FireAllClients(p)
	print("[MatchManager] Fase: " .. p)
end

function MatchManager:GetAlive(): { Player }
	local list = {}
	for p, alive in self._alive do
		if alive and p.Parent then table.insert(list, p) end
	end
	return list
end

function MatchManager:EliminatePlayer(player: Player, killer: Player?)
	if not self._alive[player] then return end
	self._alive[player] = false
	local placement = #self:GetAlive() + 1
	self._elim:RecordElimination(player, killer, placement)
	print(string.format("[MatchManager] %s eliminated #%d. %d tilbage.", player.Name, placement, #self:GetAlive()))
end

function MatchManager:OnPlayerRemoving(player: Player)
	if self._alive[player] then
		self._alive[player] = nil
		self._elim:RecordDisconnect(player, #self:GetAlive() + 1)
	end
end

function MatchManager:_teleportToLobby()
	local lobby = workspace:FindFirstChild("LobbySpawn")
	for _, p in Players:GetPlayers() do
		if p.Character then
			local cf = lobby and lobby.CFrame or CFrame.new(0, 10, 0)
			p.Character:PivotTo(cf + Vector3.new(math.random(-5,5), 2, math.random(-5,5)))
		end
	end
end

function MatchManager:Start()
	Players.PlayerRemoving:Connect(function(p) self:OnPlayerRemoving(p) end)

	-- Lyt til spilleres død
	Players.PlayerAdded:Connect(function(p)
		p.CharacterAdded:Connect(function(char)
			local hum = char:WaitForChild("Humanoid") :: Humanoid
			hum.Died:Connect(function()
				if self._phase == "InProgress" then
					-- Find killer via ForceField / Creator tag (simpelt: ingen killer info)
					self:EliminatePlayer(p, nil)
					-- Respawn bloker: fjern Character, men lad dem spectate via klient
					task.delay(1, function()
						if p.Parent then p:LoadCharacter() end
					end)
				end
			end)
		end)
	end)

	-- Sæt listeners for eksisterende spillere
	for _, p in Players:GetPlayers() do
		if p.Character then
			local hum = p.Character:FindFirstChildOfClass("Humanoid")
			if hum then
				hum.Died:Connect(function()
					if self._phase == "InProgress" then
						self:EliminatePlayer(p, nil)
					end
				end)
			end
		end
	end

	while true do
		-- LOBBY
		self:_setPhase("Lobby")
		self._alive = {}
		self._winner = nil
		self._elim:Reset()
		task.wait(Config.LOBBY_INTERMISSION)

		-- WAITING — vent på min spillere
		self:_setPhase("Waiting")
		while #Players:GetPlayers() < Config.MIN_PLAYERS do
			task.wait(2)
		end

		-- COUNTDOWN
		self:_setPhase("Countdown")
		for i = Config.COUNTDOWN_DURATION, 1, -1 do
			self._matchStateRemote:FireAllClients("Countdown", i)
			if #Players:GetPlayers() < Config.MIN_PLAYERS then
				break
			end
			task.wait(1)
		end
		if #Players:GetPlayers() < Config.MIN_PLAYERS then continue end

		-- DEPLOY (teleport til spawn-punkter)
		local allPlayers = Players:GetPlayers()
		for _, p in allPlayers do
			self._alive[p] = true
		end
		self._loot:SpawnAllLoot()

		-- Teleport spillere til sky-position (simpel version uden parachute)
		local lobby = workspace:FindFirstChild("LobbySpawn")
		local baseCF = lobby and lobby.CFrame or CFrame.new(0, Config.DROP_HEIGHT, 0)
		for i, p in allPlayers do
			if p.Character then
				p.Character:PivotTo(baseCF * CFrame.new((i-1)*5 - (#allPlayers*2.5), 0, 0))
			end
		end
		task.wait(Config.DEPLOY_DURATION)

		-- IN PROGRESS
		self:_setPhase("InProgress")
		self._storm:Start()

		while self._phase == "InProgress" do
			local alive = self:GetAlive()
			if #alive <= 1 then
				self._winner = (#alive == 1) and alive[1] or nil
				break
			end
			self._storm:Tick()
			task.wait(0.5)
		end

		-- VICTORY
		self:_setPhase("Victory")
		if self._winner then
			self._matchStateRemote:FireAllClients("Victory", self._winner.Name)
			self._elim:FinalizeResults(self._winner)
			self._data.addWin(self._winner)
			print("[MatchManager] VINDER: " .. self._winner.Name)
		else
			self._matchStateRemote:FireAllClients("Victory", nil)
			print("[MatchManager] Ingen vinder (draw)")
		end
		task.wait(Config.VICTORY_SCREEN_DURATION)

		-- CLEANUP
		self:_setPhase("Cleanup")
		self._storm:Stop()
		self._loot:DespawnAllLoot()
		self:_teleportToLobby()
		task.wait(Config.CLEANUP_DURATION)
	end
end

return MatchManager
```

---

### ServerScriptService/GameManager (Script — ENTRY POINT)

```lua
--!strict
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ServerScriptService = game:GetService("ServerScriptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- Shared modules
local Constants = require(ReplicatedStorage.Shared.Constants)

-- Server modules
local DataManager    = require(ServerScriptService.DataManager)
local RemoteHandler  = require(ServerScriptService.RemoteHandler)
local MatchManager   = require(ServerScriptService.BattleRoyale.MatchManager)
local StormSystem    = require(ServerScriptService.BattleRoyale.StormSystem)
local LootSpawner    = require(ServerScriptService.BattleRoyale.LootSpawner)
local EliminationTracker = require(ServerScriptService.BattleRoyale.EliminationTracker)

print("[GameManager] Starter...")

-- Init infrastruktur
DataManager.init()
RemoteHandler.init()

-- Player lifecycle
Players.PlayerAdded:Connect(function(p) DataManager.loadPlayer(p) end)
Players.PlayerRemoving:Connect(function(p)
	DataManager.unloadPlayer(p)
	RemoteHandler.cleanupPlayer(p)
end)
for _, p in Players:GetPlayers() do task.spawn(DataManager.loadPlayer, p) end

-- Auto-save loop
local saveTimer = 0
RunService.Heartbeat:Connect(function(dt)
	saveTimer += dt
	if saveTimer >= Constants.SAVE_INTERVAL then
		saveTimer = 0
		DataManager.saveAllPlayers()
	end
end)

-- Shutdown save
game:BindToClose(function()
	print("[GameManager] Server lukker — gemmer data...")
	DataManager.saveAllPlayersSync()
end)

-- Opret BR systemer
local storm = StormSystem.new()
local loot  = LootSpawner
local elim  = EliminationTracker

-- Start match loop i baggrunden
local match = MatchManager.new({
	storm = storm,
	loot  = loot,
	elim  = elim,
	data  = DataManager,
})

task.spawn(function()
	match:Start()
end)

print("[GameManager] Alle systemer kørende!")
```

---

### StarterGui/BattleRoyaleHUD/HUDController (LocalScript)

Sæt denne LocalScript inde i BattleRoyaleHUD ScreenGui.

```lua
--!strict
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local player = Players.LocalPlayer
local remotes = ReplicatedStorage:WaitForChild("Remotes")

-- UI referencer (tilpas navnene hvis du brugte andre)
local hud = script.Parent
local aliveLabel = hud:FindFirstChild("AliveLabel") :: TextLabel?
local killFeedFrame = hud:FindFirstChild("KillFeedFrame") :: Frame?

-- Lyt til match state
local matchStateRemote = remotes:WaitForChild("MatchState") :: RemoteEvent
matchStateRemote.OnClientEvent:Connect(function(phase, extra)
	if phase == "Countdown" then
		if aliveLabel then aliveLabel.Text = "Start om: " .. tostring(extra) end
	elseif phase == "InProgress" then
		if aliveLabel then aliveLabel.Text = "Kamp i gang!" end
	elseif phase == "Victory" then
		if aliveLabel then
			aliveLabel.Text = extra and ("🏆 " .. extra .. " vandt!") or "Ingen vinder"
		end
	elseif phase == "Lobby" then
		if aliveLabel then aliveLabel.Text = "Venter på spillere..." end
	elseif phase == "Waiting" then
		if aliveLabel then aliveLabel.Text = "Venter på spillere..." end
	end
end)

-- Kill feed
local killFeedRemote = remotes:WaitForChild("KillFeed") :: RemoteEvent
local killMessages = {}

killFeedRemote.OnClientEvent:Connect(function(killer: string, victim: string, placement: number)
	if not killFeedFrame then return end

	local msg = string.format("[#%d] %s → %s", placement, killer, victim)
	table.insert(killMessages, 1, msg)
	if #killMessages > 6 then table.remove(killMessages) end

	-- Ryd og genskab labels
	for _, child in killFeedFrame:GetChildren() do
		if child:IsA("TextLabel") then child:Destroy() end
	end

	for i, text in killMessages do
		local label = Instance.new("TextLabel")
		label.Size = UDim2.new(1, 0, 0, 20)
		label.Position = UDim2.new(0, 0, 0, (i-1)*22)
		label.BackgroundTransparency = 1
		label.TextColor3 = Color3.fromRGB(255, 255, 255)
		label.TextStrokeTransparency = 0
		label.TextXAlignment = Enum.TextXAlignment.Left
		label.Font = Enum.Font.GothamBold
		label.TextSize = 13
		label.Text = text
		label.Parent = killFeedFrame
	end
end)

-- Zone remote (til fremtidig minimap)
local zoneRemote = remotes:WaitForChild("ZoneUpdate") :: RemoteEvent
zoneRemote.OnClientEvent:Connect(function(cx, cz, radius, tcx, tcz, tr, isShrinking)
	-- TODO: tegn zone på minimap
	-- cx/cz = zone center, radius = nuværende radius
	-- tcx/tcz/tr = target zone (hvad zonen krymper mod)
end)

print("[HUDController] Klar")
```

---

### StarterPlayer/StarterPlayerScripts/ClientController (LocalScript)

```lua
--!strict
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local player = Players.LocalPlayer
local remotes = ReplicatedStorage:WaitForChild("Remotes")
local dataLoadedRemote = remotes:WaitForChild("PlayerDataLoaded") :: RemoteEvent

dataLoadedRemote.OnClientEvent:Connect(function(data)
	print(string.format("[Client] Data: Wins=%d, Kills=%d", data.Wins, data.Kills))
end)

-- Karakter setup
local function onCharacterAdded(char)
	print("[Client] Karakter spawnet: " .. player.Name)
	-- Tilføj client-side effekter her (kamera, lyde osv.)
end

if player.Character then task.spawn(onCharacterAdded, player.Character) end
player.CharacterAdded:Connect(onCharacterAdded)

print("[ClientController] Klar")
```

---

## FORVENTET OUTPUT VED PLAYTEST (F5)

```
[DataManager] Klar
[RemoteHandler] Klar
[GameManager] Alle systemer kørende!
[DataManager] Indlæst: [DitNavn]
[Client] Data: Wins=0, Kills=0
[MatchManager] Fase: Lobby
[MatchManager] Fase: Waiting
```

Når nok spillere er med:
```
[MatchManager] Fase: Countdown
[LootSpawner] Spawnet X items ved Y punkter
[MatchManager] Fase: InProgress
[StormSystem] Fase 1: venter 60s
```

---

## NÆSTE SKRIDT

Når MVP virker, kan du tilføje:

- **Rigtige våbenmodels** — erstat de farvede Parts i LootSpawner med models fra ServerStorage
- **Minimap med zone** — brug ZoneUpdate remote til at tegne en circle i HUDController
- **Spectator kamera** — fra genre-template (SpectatorController.lua)
- **Drop-animation** — DropSystem.lua fra genre-template (parachute + fri fald)
- **Shop / Battle Pass** — load monetization-referencerne
- **Sikkerhed** — server-side hitvalidering (AntiCheat.lua fra genre-template)
- **Leaderboard** — OrderedDataStore på Wins/Kills

Spørg mig om hvad som helst:
- "Tilføj spectator system" → jeg loader SpectatorController
- "Lav en shop" → jeg bygger monetization-systemet
- "Optimer performance" → jeg kører en performance audit
- "Review sikkerheden" → jeg kører security audit
```
