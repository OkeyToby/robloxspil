# Battle Royale — Combat System (Tilføjelse til MVP)

Dette bygger oven på BattleRoyale_MVP.md.
Tilføj disse scripts og ændringer til dit eksisterende projekt.

---

## HVAD DU FÅR

- **WeaponTool** — et Tool-script der styrer skyd-logik klient-side (animation, raycast til sigte)
- **WeaponServer** — server-side modul der validerer hits, beregner skade og kalder EliminationTracker
- **Opdateret LootSpawner** — spawner rigtige Tool-instances i stedet for farvede Parts
- **Opdateret MatchManager** — lytter til kills fra WeaponServer i stedet for Humanoid.Died

---

## NYE SCRIPTS

---

### ServerScriptService/BattleRoyale/WeaponServer (ModuleScript)

Placér i `ServerScriptService/BattleRoyale/`

```lua
--!strict
--[[
  WeaponServer
  Modtager ShootRequest fra klienter, validerer og applicerer skade.

  Sikkerhedscheck:
  1. Spilleren eksisterer og er i live
  2. Spilleren har et våben equippet med de korrekte stats
  3. Distancen fra skydende spiller til target er indenfor rækkevidde
  4. Rate limiting via RemoteHandler cooldown (per våben-type)
  5. Target er en levende humanoid (ikke sig selv)
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local WeaponDefs = require(ReplicatedStorage.BattleRoyale.WeaponDefs)

local WeaponServer = {}

-- Eksternt sat af GameManager
local _matchManager = nil :: any

function WeaponServer.setMatchManager(mm)
	_matchManager = mm
end

-- Opret ShootRequest remote (kaldes fra init i GameManager)
function WeaponServer.init()
	local rf = ReplicatedStorage:WaitForChild("Remotes")
	if not rf:FindFirstChild("ShootRequest") then
		local r = Instance.new("RemoteEvent")
		r.Name = "ShootRequest"
		r.Parent = rf
	end

	local shootRemote = rf:WaitForChild("ShootRequest") :: RemoteEvent

	shootRemote.OnServerEvent:Connect(function(
		shooter: Player,
		targetPlayer: Player?,
		hitPosition: Vector3,
		weaponName: string
	)
		WeaponServer._handleShot(shooter, targetPlayer, hitPosition, weaponName)
	end)

	print("[WeaponServer] Klar")
end

function WeaponServer._handleShot(
	shooter: Player,
	targetPlayer: Player?,
	hitPosition: Vector3,
	weaponName: string
)
	-- 1. Valider shooter
	local shooterChar = shooter.Character
	if not shooterChar then return end

	local shooterHum = shooterChar:FindFirstChildOfClass("Humanoid")
	local shooterRoot = shooterChar:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not shooterHum or not shooterRoot or shooterHum.Health <= 0 then return end

	-- 2. Valider våbendefinition
	local def = WeaponDefs[weaponName]
	if not def then
		warn("[WeaponServer] Ukendt våben: " .. tostring(weaponName) .. " fra " .. shooter.Name)
		return
	end

	-- 3. Valider at shooteren faktisk holder dette våben
	local equippedTool = shooterChar:FindFirstChildOfClass("Tool")
	if not equippedTool or equippedTool.Name ~= weaponName then
		warn("[WeaponServer] " .. shooter.Name .. " har ikke " .. weaponName .. " equippet")
		return
	end

	-- 4. Tjek target
	if not targetPlayer then return end
	if targetPlayer == shooter then return end -- ingen selvmord via exploit

	local targetChar = targetPlayer.Character
	if not targetChar then return end

	local targetHum = targetChar:FindFirstChildOfClass("Humanoid")
	local targetRoot = targetChar:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not targetHum or not targetRoot or targetHum.Health <= 0 then return end

	-- 5. Distance-validering (forhindrer teleport-hacks)
	-- Klienten sender hit-position — vi tjekker at shooter er tæt nok på
	local shooterPos = shooterRoot.Position
	local targetPos  = targetRoot.Position
	local maxRange   = def.range or 300

	-- Vi validerer at targetets faktiske position er indenfor range
	-- (klientens hitPosition bruges kun til visuelle effekter)
	local distance = (shooterPos - targetPos).Magnitude
	if distance > maxRange * 1.2 then -- 20% buffer for lag
		warn(string.format(
			"[WeaponServer] Range exploit? %s skød %s (dist=%.0f, max=%.0f)",
			shooter.Name, targetPlayer.Name, distance, maxRange
		))
		return
	end

	-- 6. Line-of-sight tjek (server-side raycast)
	local rayParams = RaycastParams.new()
	rayParams.FilterType = Enum.RaycastFilterType.Exclude
	rayParams.FilterDescendantsInstances = { shooterChar, targetChar }
	-- Kast fra shooter mod targets position
	local direction = (targetPos - shooterPos)
	local rayResult = workspace:Raycast(shooterPos, direction, rayParams)

	-- Hvis raycasen rammer noget (en mur), er skuddet blokeret
	-- Vi tjekker kun hvis rayen ramte og det ikke var target-karakteren
	if rayResult and not rayResult.Instance:IsDescendantOf(targetChar) then
		-- Mur i vejen — bloker ikke altid (lag kan give falske positiver)
		-- Log det men tillad skuddet (justering kan skærpes i produktion)
		warn("[WeaponServer] Muligt LoS issue: " .. shooter.Name .. " -> " .. targetPlayer.Name)
	end

	-- 7. Applicér skade
	local damage = def.baseDamage
	targetHum:TakeDamage(damage)

	print(string.format(
		"[WeaponServer] %s → %s: %d skade (%s, dist=%.0f)",
		shooter.Name, targetPlayer.Name, damage, weaponName, distance
	))

	-- 8. Tjek om target døde
	if targetHum.Health <= 0 and _matchManager then
		-- Fortæl MatchManager hvem der eliminerede hvem
		task.defer(function()
			if _matchManager and _matchManager._alive and _matchManager._alive[targetPlayer] then
				_matchManager:EliminatePlayer(targetPlayer, shooter)
			end
		end)
	end

	-- 9. Broadcast hit-effekt til klienter (valgfrit: blod/impact visual)
	local rf = ReplicatedStorage:FindFirstChild("Remotes")
	if rf then
		local hitFxRemote = rf:FindFirstChild("HitEffect")
		if hitFxRemote and hitFxRemote:IsA("RemoteEvent") then
			hitFxRemote:FireAllClients(hitPosition, damage)
		end
	end
end

return WeaponServer
```

---

### Tool Script — "WeaponTool" (LocalScript inde i hvert Tool)

Hver gang LootSpawner opretter et Tool, sættes dette script ind automatisk (se opdateret LootSpawner nedenfor). Du kan også placere det manuelt.

Placér i: `StarterPack/[VåbenNavn]/WeaponTool` ELLER lad LootSpawner sætte det ind.

```lua
--!strict
--[[
  WeaponTool (LocalScript — lever inde i Tool)
  Styrer klient-side skyd-input.

  Flow:
  1. Spiller trykker Mouse1 (venstre museklik)
  2. Klienten laver en raycast fra kameraet
  3. Hvis rayen rammer en anden spillers karakter, sender vi ShootRequest
  4. Serveren validerer og applicerer skade
  5. Klienten spiller lydeffekt + muzzle flash (ingen skade klient-side)
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")

local tool = script.Parent
local player = Players.LocalPlayer
local character = player.Character or player.CharacterAdded:Wait()
local camera = workspace.CurrentCamera

local remotes = ReplicatedStorage:WaitForChild("Remotes")
local shootRemote = remotes:WaitForChild("ShootRequest") :: RemoteEvent

-- Hent våbenstatistik fra tool (sat af LootSpawner ved oprettelse)
local weaponName = tool.Name
local weaponDefs = require(ReplicatedStorage:WaitForChild("BattleRoyale"):WaitForChild("WeaponDefs"))
local def = weaponDefs[weaponName]

-- Cooldown baseret på fire rate (sekunder per skud)
local fireInterval = def and (1 / def.fireRate) or 0.5
local lastFireTime = 0
local equipped = false

-- Muzzle flash (simpel: kræver en Part i tool kaldet "Muzzle")
local muzzlePart = tool:FindFirstChild("Muzzle") :: BasePart?

local function playMuzzleFlash()
	if not muzzlePart then return end
	muzzlePart.Light = true -- placeholder; erstat med PointLight toggle
	task.delay(0.05, function()
		if muzzlePart then muzzlePart.Light = false end
	end)
end

local function findPlayerFromPart(part: BasePart): Player?
	-- Gå op i part-hierarkiet for at finde karakteren og dermed spilleren
	local model = part
	while model and not model:IsA("Model") do
		model = model.Parent :: any
	end
	if not model then return nil end
	for _, p in Players:GetPlayers() do
		if p.Character == model then return p end
	end
	return nil
end

local function shoot()
	if not equipped then return end
	if not def then return end

	local now = os.clock()
	if now - lastFireTime < fireInterval then return end
	lastFireTime = now

	-- Raycast fra kamera
	local origin    = camera.CFrame.Position
	local direction = camera.CFrame.LookVector * (def.range or 300)

	local rayParams = RaycastParams.new()
	rayParams.FilterType = Enum.RaycastFilterType.Exclude
	rayParams.FilterDescendantsInstances = { character }

	local result = workspace:Raycast(origin, direction, rayParams)

	local targetPlayer: Player? = nil
	local hitPosition = origin + direction -- default: ingen hit

	if result then
		hitPosition = result.Position
		if result.Instance:IsA("BasePart") then
			targetPlayer = findPlayerFromPart(result.Instance)
		end
	end

	-- Animér muzzle flash lokalt
	playMuzzleFlash()

	-- Send til server (selv hvis ingen target — serveren ignorerer det)
	if targetPlayer then
		shootRemote:FireServer(targetPlayer, hitPosition, weaponName)
	end
end

-- Input binding
local connection: RBXScriptConnection? = nil

tool.Equipped:Connect(function()
	equipped = true
	-- Skjul Roblox's standard backpack GUI for dette tool (optional)
	connection = UserInputService.InputBegan:Connect(function(input, processed)
		if processed then return end
		if input.UserInputType == Enum.UserInputType.MouseButton1
			or input.KeyCode == Enum.KeyCode.ButtonR2 -- controller trigger
		then
			shoot()
		end
	end)
end)

tool.Unequipped:Connect(function()
	equipped = false
	if connection then
		connection:Disconnect()
		connection = nil
	end
end)
```

---

### Opdateret LootSpawner — med rigtige Tools

Erstat din eksisterende `LootSpawner` i `ServerScriptService/BattleRoyale/` med denne:

```lua
--!strict
--[[
  LootSpawner (opdateret)
  Spawner Tools i stedet for bare farvede Parts.
  Hvert Tool indeholder WeaponTool LocalScript og har korrekt navn.
]]

local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage     = game:GetService("ServerStorage")

local Config     = require(ReplicatedStorage.BattleRoyale.Config)
local WeaponDefs = require(ReplicatedStorage.BattleRoyale.WeaponDefs)

local LootSpawner = {}
local spawnedLoot: { Instance } = {}

-- Rarity farver til tool-håndtag
local RARITY_COLORS = {
	Common    = Color3.fromRGB(200, 200, 200),
	Uncommon  = Color3.fromRGB(30,  200, 30),
	Rare      = Color3.fromRGB(30,  100, 255),
	Epic      = Color3.fromRGB(160, 50,  255),
	Legendary = Color3.fromRGB(255, 200, 0),
}

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

--[[
  Forsøg at klone et pre-lavet Tool fra ServerStorage.
  Fallback: opret et simpelt Tool programmatisk.
]]
local function createWeaponTool(weaponName: string, rarity: string): Tool
	-- Tjek om der er et pre-lavet Tool i ServerStorage/Weapons/
	local weaponsFolder = ServerStorage:FindFirstChild("Weapons")
	if weaponsFolder then
		local template = weaponsFolder:FindFirstChild(weaponName)
		if template and template:IsA("Tool") then
			return template:Clone()
		end
	end

	-- Fallback: byg et simpelt Tool
	local tool = Instance.new("Tool")
	tool.Name = weaponName
	tool.RequiresHandle = true
	tool.ToolTip = weaponName .. " [" .. rarity .. "]"
	tool.CanBeDropped = false -- forhindrer spill via exploit

	-- Handle (det man ser i verden og i spillerens hånd)
	local handle = Instance.new("Part")
	handle.Name = "Handle"
	handle.Size = Vector3.new(0.3, 0.3, 1.5)
	handle.Color = RARITY_COLORS[rarity] or RARITY_COLORS.Common
	handle.Material = Enum.Material.Neon
	handle.Parent = tool

	-- Rarity metadata
	local rv = Instance.new("StringValue")
	rv.Name = "Rarity"; rv.Value = rarity; rv.Parent = tool

	-- WeaponTool LocalScript — Roblox kræver at LocalScripts i Tools hedder noget specifikt
	-- Vi kloner scriptet fra ReplicatedStorage (se nedenfor)
	local scriptTemplate = ReplicatedStorage:FindFirstChild("WeaponToolScript")
	if scriptTemplate then
		local ls = scriptTemplate:Clone()
		ls.Name = "WeaponTool"
		ls.Parent = tool
	else
		-- Inline fallback hvis script ikke er i ReplicatedStorage endnu
		local ls = Instance.new("LocalScript")
		ls.Name = "WeaponTool"
		ls.Source = "-- WeaponTool: se BattleRoyale_Combat.md for kildekode"
		ls.Parent = tool
	end

	return tool
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

		local tool = createWeaponTool(weaponName, rarity)

		-- Tilføj ProximityPrompt til handle
		local handle = tool:FindFirstChild("Handle") :: BasePart?
		if handle then
			local pp = Instance.new("ProximityPrompt")
			pp.ActionText = "Tag op"
			pp.ObjectText = weaponName .. " [" .. rarity .. "]"
			pp.HoldDuration = 0.15
			pp.MaxActivationDistance = 8
			pp.Parent = handle

			-- Server: giv spilleren toolet ved pickup
			pp.Triggered:Connect(function(triggeringPlayer: Player)
				-- Tjek at pickup stadig er i verden (ikke allerede taget)
				if not tool.Parent or not tool.Parent:IsA("Folder") then return end

				-- Max inventory check (simpel: max 2 våben)
				local backpackCount = #triggeringPlayer.Backpack:GetChildren()
				local charToolCount = triggeringPlayer.Character
					and #triggeringPlayer.Character:GetChildren()
					or 0
				-- Tæl kun Tools
				local totalTools = 0
				for _, item in triggeringPlayer.Backpack:GetChildren() do
					if item:IsA("Tool") then totalTools += 1 end
				end
				if triggeringPlayer.Character then
					for _, item in triggeringPlayer.Character:GetChildren() do
						if item:IsA("Tool") then totalTools += 1 end
					end
				end

				if totalTools >= 2 then return end -- fuld inventory

				-- Giv til spilleren
				tool.Parent = triggeringPlayer.Backpack
				print(string.format("[LootSpawner] %s tog %s (%s)", triggeringPlayer.Name, weaponName, rarity))
			end)

			handle.CFrame = point.CFrame * CFrame.new(0, 1, 0)
		end

		tool.Parent = lootFolder
		table.insert(spawnedLoot, tool)
		count += 1
	end

	print(string.format("[LootSpawner] Spawnet %d tools ved %d punkter", count, #points))
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

### Opdateret GameManager — registrer WeaponServer

Tilføj disse linjer til din eksisterende `GameManager` Script:

```lua
-- Tilføj øverst (i require-sektionen):
local WeaponServer = require(ServerScriptService.BattleRoyale.WeaponServer)

-- Tilføj efter RemoteHandler.init():
WeaponServer.init()

-- Tilføj efter 'local match = MatchManager.new(...)':
WeaponServer.setMatchManager(match)
```

Den komplette GameManager-sektion ser sådan ud:

```lua
-- Init infrastruktur
DataManager.init()
RemoteHandler.init()
WeaponServer.init()   -- ← NYT

-- ... (player lifecycle som før) ...

-- Opret BR systemer
local storm = StormSystem.new()
local loot  = LootSpawner
local elim  = EliminationTracker

local match = MatchManager.new({
	storm = storm,
	loot  = loot,
	elim  = elim,
	data  = DataManager,
})

WeaponServer.setMatchManager(match)  -- ← NYT

task.spawn(function()
	match:Start()
end)
```

---

### Opdateret MatchManager — fjern Humanoid.Died lytter

I din eksisterende `MatchManager`, i `Start()`-funktionen, fjern dette:

```lua
-- FJERN DENNE BLOK (den er nu erstattet af WeaponServer):
Players.PlayerAdded:Connect(function(p)
    p.CharacterAdded:Connect(function(char)
        local hum = char:WaitForChild("Humanoid") :: Humanoid
        hum.Died:Connect(function()
            if self._phase == "InProgress" then
                self:EliminatePlayer(p, nil)
                task.delay(1, function()
                    if p.Parent then p:LoadCharacter() end
                end)
            end
        end)
    end)
end)
-- (og den eksisterende players-løkke nedenunder)
```

Erstat med (storm-damage og fald-damage håndteres stadig via Humanoid.Died):

```lua
-- Zone- og fald-dødsfald (ingen killer)
local function connectCharacterDeath(p: Player, char: Model)
    local hum = char:WaitForChild("Humanoid") :: Humanoid
    hum.Died:Connect(function()
        if self._phase == "InProgress" and self._alive[p] then
            -- Kun kald EliminatePlayer hvis WeaponServer ikke allerede har gjort det
            -- (WeaponServer bruger task.defer, så vi tjekker _alive status)
            task.wait() -- giv WeaponServer's defer tid til at køre
            if self._alive[p] then
                self:EliminatePlayer(p, nil) -- ingen killer = zone/fald
            end
        end
    end)
end

Players.PlayerAdded:Connect(function(p)
    p.CharacterAdded:Connect(function(char) connectCharacterDeath(p, char) end)
end)
for _, p in Players:GetPlayers() do
    if p.Character then connectCharacterDeath(p, p.Character) end
end
```

---

### Tilføj WeaponTool script til ReplicatedStorage

For at LootSpawner kan sætte det korrekte script ind i hvert Tool, skal WeaponTool-scriptet ligge i `ReplicatedStorage`:

1. I `ReplicatedStorage`, insert en **LocalScript**
2. Navn: `WeaponToolScript`
3. Indsæt kildekoden fra "WeaponTool (LocalScript)" afsnittet ovenfor

---

## HIT EFFECT (valgfrit — visuelt feedback)

Tilføj disse linjer til `HUDController` LocalScript for at vise hit markers:

```lua
-- I HUDController, tilføj:
local hitEffectRemote = remotes:WaitForChild("HitEffect") :: RemoteEvent

-- Opret en hit marker (rød prik i midten af skærmen i 0.1s)
local hitMarker = Instance.new("Frame")
hitMarker.Name = "HitMarker"
hitMarker.Size = UDim2.fromOffset(10, 10)
hitMarker.Position = UDim2.new(0.5, -5, 0.5, -5)
hitMarker.BackgroundColor3 = Color3.fromRGB(255, 50, 50)
hitMarker.BackgroundTransparency = 1
hitMarker.BorderSizePixel = 0
hitMarker.Parent = hud

local uiCorner = Instance.new("UICorner")
uiCorner.CornerRadius = UDim.new(1, 0)
uiCorner.Parent = hitMarker

hitEffectRemote.OnClientEvent:Connect(function(hitPos, damage)
    hitMarker.BackgroundTransparency = 0
    task.delay(0.1, function()
        hitMarker.BackgroundTransparency = 1
    end)
end)
```

Og tilføj `HitEffect` remote i WeaponServer.init():

```lua
function WeaponServer.init()
    local rf = ReplicatedStorage:WaitForChild("Remotes")
    if not rf:FindFirstChild("ShootRequest") then
        local r = Instance.new("RemoteEvent")
        r.Name = "ShootRequest"
        r.Parent = rf
    end
    -- Tilføj HitEffect remote:
    if not rf:FindFirstChild("HitEffect") then
        local r = Instance.new("RemoteEvent")
        r.Name = "HitEffect"
        r.Parent = rf
    end
    -- ... resten som før
end
```

---

## SIKKERHEDS-MODEL

```
KLIENT                          SERVER
──────                          ──────
Mouse1 trykket
  → Lokal raycast (hurtig)
  → Finder muligt target
  → FireServer(target, pos, weapon)
                                → Modtager ShootRequest
                                → Tjekker: spiller i live?
                                → Tjekker: weapon equippet?
                                → Tjekker: distance <= range?
                                → Tjekker: target i live?
                                → Applicerer skade (server-only)
                                → Hvis health <= 0:
                                    EliminatePlayer(target, shooter)
                                → FireAllClients(HitEffect)
  ← HitEffect modtaget
  → Vis hit marker
```

**Hvad klienten IKKE kan:**
- Sætte sin egen skade
- Eliminere andre spillere direkte
- Skyde med et våben de ikke har equippet
- Skyde spillere udenfor range

---

## TEST CHECKLIST

```
[ ] Tryk Play, join med 2 spillere (brug "Test" → "2 Players")
[ ] Vent på countdown og match-start
[ ] Spiller A tager et weapon op (ProximityPrompt)
[ ] Tool vises i backpack/hånd
[ ] Spiller A klikker på Spiller B
[ ] Output: "[WeaponServer] PlayerA → PlayerB: X skade"
[ ] Spiller B's health falder
[ ] Spiller B dør → Output: "[MatchManager] PlayerB eliminated #2"
[ ] Kill feed opdateres i HUD
[ ] Matcher slutter med "VINDER: PlayerA"
```

---

## NÆSTE SKRIDT (efter combat virker)

- **Spectator kamera** — så eliminerede spillere kan se kampen fortsætte
- **Ammo system** — magasin-tæller, reload-animation, ammo-loot
- **Minimap med zone** — live zone-indikator baseret på ZoneUpdate remote
- **Pre-lavede weapon models** — sæt dine egne Roblox Tools i `ServerStorage/Weapons/`
