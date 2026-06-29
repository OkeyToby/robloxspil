# Battle Royale — Spectator System + Minimap (Del 3)

Bygger videre på MVP + Combat filerne.

---

## HVAD DU FÅR

- **SpectatorSystem** (server) — tildeler eliminerede spillere en target at følge, håndterer Q/E cycling
- **SpectatorController** (client LocalScript) — kamera følger target, viser spectator UI
- **Minimap** med live zone-cirkel der krymper i realtid
- **Ammo-tæller** i HUD (magasin + total ammo)
- **Opdateret MatchManager** — kalder SpectatorSystem ved eliminering

---

## FOLDER STRUKTUR (nye filer)

```
ServerScriptService/BattleRoyale/
  SpectatorSystem      (ModuleScript)  ← NY

StarterGui/BattleRoyaleHUD/
  SpectatorHUD         (Frame)         ← NY  (vises kun når du er eliminated)
    SpectatorLabel     (TextLabel)     "Du spectater: [navn]"
    CycleHint          (TextLabel)     "Q / E for at skifte"
  MinimapFrame         (Frame)         ← NY
    MapBackground      (Frame)         grå baggrund
    ZoneCircle         (Frame)         blå cirkel = safe zone
    TargetZoneCircle   (Frame)         rød cirkel = næste zone
    PlayerDot          (Frame)         gul prik = dig selv
  AmmoLabel            (TextLabel)     ← NY  "30 / 120"

StarterPlayerScripts/
  SpectatorController  (LocalScript)   ← NY
```

---

## SCRIPTS

---

### ServerScriptService/BattleRoyale/SpectatorSystem (ModuleScript)

```lua
--!strict
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local SpectatorSystem = {}

-- spectatorTargets[player] = den spiller de ser på
local spectatorTargets: { [Player]: Player } = {}
-- spectatorIndex[player] = index i alive-listen
local spectatorIndex: { [Player]: number } = {}

local CYCLE_COOLDOWN = 0.5
local lastCycleTime: { [Player]: number } = {}

-- Lav remotes
local function ensureRemote(name: string)
	local rf = ReplicatedStorage:WaitForChild("Remotes")
	if not rf:FindFirstChild(name) then
		local r = Instance.new("RemoteEvent")
		r.Name = name
		r.Parent = rf
	end
	return rf:FindFirstChild(name) :: RemoteEvent
end

local spectatorRemote: RemoteEvent
local cycleRemote: RemoteEvent

function SpectatorSystem.init()
	spectatorRemote = ensureRemote("SpectatorTarget")
	cycleRemote     = ensureRemote("SpectatorCycle")

	-- Klient sender cycle-request
	cycleRemote.OnServerEvent:Connect(function(player: Player, direction: number)
		SpectatorSystem.cycleTarget(player, direction)
	end)

	print("[SpectatorSystem] Klar")
end

function SpectatorSystem.reset()
	table.clear(spectatorTargets)
	table.clear(spectatorIndex)
	table.clear(lastCycleTime)
end

function SpectatorSystem.beginSpectating(eliminated: Player, alivePlayers: { Player })
	if #alivePlayers == 0 then
		-- Ingen at spectate — send til lobby-kamera
		spectatorRemote:FireClient(eliminated, "NoTargets", nil)
		return
	end

	local idx = 1
	spectatorIndex[eliminated] = idx
	spectatorTargets[eliminated] = alivePlayers[idx]

	spectatorRemote:FireClient(eliminated, "StartSpectating", alivePlayers[idx])
	print(string.format("[SpectatorSystem] %s spectater %s", eliminated.Name, alivePlayers[idx].Name))
end

function SpectatorSystem.cycleTarget(spectator: Player, direction: number)
	-- Rate limit
	local now = os.clock()
	if lastCycleTime[spectator] and now - lastCycleTime[spectator] < CYCLE_COOLDOWN then return end
	lastCycleTime[spectator] = now

	if not spectatorIndex[spectator] then return end

	-- Hent opdateret liste over levende spillere
	-- (Dette kræver adgang til MatchManager — sendt via setAliveGetter)
	local alivePlayers = SpectatorSystem._getAlivePlayers()
	if #alivePlayers == 0 then return end

	local currentIdx = spectatorIndex[spectator]
	local newIdx = ((currentIdx - 1 + direction) % #alivePlayers) + 1
	spectatorIndex[spectator] = newIdx
	spectatorTargets[spectator] = alivePlayers[newIdx]

	spectatorRemote:FireClient(spectator, "SwitchTarget", alivePlayers[newIdx])
end

function SpectatorSystem.stopSpectating(player: Player)
	spectatorTargets[player] = nil
	spectatorIndex[player] = nil
	spectatorRemote:FireClient(player, "StopSpectating", nil)
end

-- Kaldes når en spiller (der spectates af nogen) dør
-- Opdater alle der specterede den spilleren til næste target
function SpectatorSystem.onTargetEliminated(eliminatedTarget: Player, newAlivePlayers: { Player })
	for spectator, target in spectatorTargets do
		if target == eliminatedTarget then
			SpectatorSystem.beginSpectating(spectator, newAlivePlayers)
		end
	end
end

-- Injicér alive-getter fra MatchManager
SpectatorSystem._getAlivePlayers = function(): { Player } return {} end

function SpectatorSystem.setAliveGetter(fn: () -> { Player })
	SpectatorSystem._getAlivePlayers = fn
end

return SpectatorSystem
```

---

### StarterPlayerScripts/SpectatorController (LocalScript)

```lua
--!strict
--[[
  SpectatorController
  Kører klient-side. Lytter til SpectatorTarget remote og styrer kameraet.
  Viser/skjuler spectator HUD.
  Q/E eller pil-taster skifter target.
]]

local Players          = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")
local RunService       = game:GetService("RunService")

local player    = Players.LocalPlayer
local camera    = workspace.CurrentCamera
local remotes   = ReplicatedStorage:WaitForChild("Remotes")

local spectatorRemote = remotes:WaitForChild("SpectatorTarget") :: RemoteEvent
local cycleRemote     = remotes:WaitForChild("SpectatorCycle")  :: RemoteEvent

-- UI referencer
local hud           = player:WaitForChild("PlayerGui"):WaitForChild("BattleRoyaleHUD")
local spectatorHUD  = hud:WaitForChild("SpectatorHUD")
local spectatorLabel = spectatorHUD:FindFirstChild("SpectatorLabel") :: TextLabel?
local cycleHint      = spectatorHUD:FindFirstChild("CycleHint") :: TextLabel?

spectatorHUD.Visible = false

-- State
local isSpectating   = false
local currentTarget: Player? = nil
local renderConn: RBXScriptConnection? = nil

-- Kamera offset (bag og over target)
local CAM_OFFSET = Vector3.new(0, 6, 14)

local function startRenderLoop()
	if renderConn then renderConn:Disconnect() end

	renderConn = RunService.RenderStepped:Connect(function()
		local target = currentTarget
		if not target then return end
		local char = target.Character
		if not char then return end
		local root = char:FindFirstChild("HumanoidRootPart") :: BasePart?
		if not root then return end

		-- Beregn ønsket kamera CFrame (bag og over target)
		local targetCF = CFrame.new(root.Position) * CFrame.Angles(0, math.atan2(
			-(root.CFrame.LookVector.X),
			-(root.CFrame.LookVector.Z)
		), 0)

		local desiredCF = targetCF * CFrame.new(0, CAM_OFFSET.Y, CAM_OFFSET.Z)
		local lookAt    = root.Position + Vector3.new(0, 1, 0)

		camera.CameraType = Enum.CameraType.Scriptable
		-- Blød interpolation (lerp)
		camera.CFrame = camera.CFrame:Lerp(
			CFrame.new(desiredCF.Position, lookAt),
			0.12
		)
	end)
end

local function stopRenderLoop()
	if renderConn then
		renderConn:Disconnect()
		renderConn = nil
	end
	camera.CameraType = Enum.CameraType.Custom
end

local function startSpectating(target: Player)
	isSpectating = true
	currentTarget = target
	spectatorHUD.Visible = true

	if spectatorLabel then
		spectatorLabel.Text = "Du spectater: " .. target.Name
	end
	if cycleHint then
		cycleHint.Text = "[ Q ] ← Forrige   Næste → [ E ]"
	end

	startRenderLoop()
end

local function switchTarget(target: Player)
	currentTarget = target
	if spectatorLabel then
		spectatorLabel.Text = "Du spectater: " .. target.Name
	end
	-- Render loop kører allerede, opdater bare target
end

local function stopSpectating()
	isSpectating = false
	currentTarget = nil
	spectatorHUD.Visible = false
	stopRenderLoop()
end

-- Lyt til server
spectatorRemote.OnClientEvent:Connect(function(action: string, target: Player?)
	if action == "StartSpectating" and target then
		startSpectating(target)
	elseif action == "SwitchTarget" and target then
		switchTarget(target)
	elseif action == "StopSpectating" or action == "NoTargets" then
		stopSpectating()
	end
end)

-- Input: Q/E eller piletaster for at cycle
local lastCycleInput = 0
UserInputService.InputBegan:Connect(function(input: InputObject, processed: boolean)
	if processed or not isSpectating then return end
	if os.clock() - lastCycleInput < 0.3 then return end

	local dir = 0
	if input.KeyCode == Enum.KeyCode.E or input.KeyCode == Enum.KeyCode.Right then
		dir = 1
	elseif input.KeyCode == Enum.KeyCode.Q or input.KeyCode == Enum.KeyCode.Left then
		dir = -1
	end

	if dir ~= 0 then
		lastCycleInput = os.clock()
		cycleRemote:FireServer(dir)
	end
end)

-- Mobile: tilføj touch-knapper (simpel version)
local function addMobileButtons()
	if not UserInputService.TouchEnabled then return end

	local prevBtn = Instance.new("TextButton")
	prevBtn.Size = UDim2.fromOffset(80, 40)
	prevBtn.Position = UDim2.new(0.3, 0, 0.85, 0)
	prevBtn.Text = "◀ Q"
	prevBtn.BackgroundColor3 = Color3.fromRGB(40, 40, 40)
	prevBtn.BackgroundTransparency = 0.3
	prevBtn.TextColor3 = Color3.new(1,1,1)
	prevBtn.Font = Enum.Font.GothamBold
	prevBtn.TextSize = 16
	prevBtn.Parent = spectatorHUD
	prevBtn.MouseButton1Click:Connect(function()
		cycleRemote:FireServer(-1)
	end)

	local nextBtn = Instance.new("TextButton")
	nextBtn.Size = UDim2.fromOffset(80, 40)
	nextBtn.Position = UDim2.new(0.6, 0, 0.85, 0)
	nextBtn.Text = "E ▶"
	nextBtn.BackgroundColor3 = Color3.fromRGB(40, 40, 40)
	nextBtn.BackgroundTransparency = 0.3
	nextBtn.TextColor3 = Color3.new(1,1,1)
	nextBtn.Font = Enum.Font.GothamBold
	nextBtn.TextSize = 16
	nextBtn.Parent = spectatorHUD
	nextBtn.MouseButton1Click:Connect(function()
		cycleRemote:FireServer(1)
	end)
end

addMobileButtons()
print("[SpectatorController] Klar")
```

---

### Minimap + Ammo — tilføj til HUDController

Tilføj disse sektioner i din eksisterende `HUDController` LocalScript:

```lua
--!strict
-- ========== MINIMAP SEKTION ==========
-- Placér i bunden af HUDController (efter kill feed koden)

local minimapFrame      = hud:FindFirstChild("MinimapFrame")
local mapBackground     = minimapFrame and minimapFrame:FindFirstChild("MapBackground")
local zoneCircle        = minimapFrame and minimapFrame:FindFirstChild("ZoneCircle")
local targetZoneCircle  = minimapFrame and minimapFrame:FindFirstChild("TargetZoneCircle")
local playerDot         = minimapFrame and minimapFrame:FindFirstChild("PlayerDot")

-- Kortets radius i studs (tilpas til dit map)
local MAP_RADIUS = 500   -- halv-bredde af dit map i studs
-- Minimap frame størrelse i pixels (antager kvadratisk)
local MINIMAP_PX = 200   -- sæt til faktisk størrelse af MinimapFrame

local function worldToMinimap(worldX: number, worldZ: number): (number, number)
	-- Konvertér world XZ til pixel offset ift. minimap-centrum
	local scale = (MINIMAP_PX / 2) / MAP_RADIUS
	local px = worldX * scale + MINIMAP_PX / 2
	local py = worldZ * scale + MINIMAP_PX / 2
	return px, py
end

local function updateZoneCircle(frame: Frame?, cx: number, cz: number, radius: number)
	if not frame then return end
	local px, py = worldToMinimap(cx, cz)
	local scale = (MINIMAP_PX / 2) / MAP_RADIUS
	local pixelR = radius * scale
	frame.Size = UDim2.fromOffset(pixelR * 2, pixelR * 2)
	frame.Position = UDim2.fromOffset(px - pixelR, py - pixelR)
end

-- Lyt til zone updates fra server
local zoneRemote = remotes:WaitForChild("ZoneUpdate") :: RemoteEvent
zoneRemote.OnClientEvent:Connect(function(
	curCX: number, curCZ: number, curR: number,
	tgtCX: number, tgtCZ: number, tgtR: number,
	isShrinking: boolean
)
	updateZoneCircle(zoneCircle   :: Frame?, curCX, curCZ, curR)
	updateZoneCircle(targetZoneCircle :: Frame?, tgtCX, tgtCZ, tgtR)

	-- Vis kun target-zone når den er forskellig fra nuværende
	if targetZoneCircle then
		targetZoneCircle.Visible = (tgtR < curR)
	end

	-- Farv zone-cirklen: blå = statisk, rød = krymper
	if zoneCircle and zoneCircle:IsA("Frame") then
		zoneCircle.BackgroundColor3 = isShrinking
			and Color3.fromRGB(255, 60, 60)
			or  Color3.fromRGB(60, 140, 255)
	end
end)

-- Opdatér spiller-dot på minimap hver frame
local playerDotConn = game:GetService("RunService").RenderStepped:Connect(function()
	if not playerDot then return end
	local char = player.Character
	if not char then return end
	local root = char:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not root then return end

	local px, py = worldToMinimap(root.Position.X, root.Position.Z)
	playerDot.Position = UDim2.fromOffset(px - 5, py - 5) -- center prikken
end)

-- ========== AMMO-TÆLLER SEKTION ==========

local ammoLabel = hud:FindFirstChild("AmmoLabel") :: TextLabel?
local ammoRemote = remotes:WaitForChild("AmmoUpdate") :: RemoteEvent

if ammoLabel then ammoLabel.Text = "-- / --" end

ammoRemote.OnClientEvent:Connect(function(current: number, total: number)
	if ammoLabel then
		ammoLabel.Text = string.format("%d / %d", current, total)
		-- Farv rød hvis lav ammo
		ammoLabel.TextColor3 = (current <= 5)
			and Color3.fromRGB(255, 80, 80)
			or  Color3.fromRGB(255, 255, 255)
	end
end)
```

---

### UI Setup — opret elementer i Studio

**MinimapFrame** (inde i BattleRoyaleHUD):
- Type: Frame
- Size: `{0,200},{0,200}`
- Position: `{0,10},{0,10}` (øverste venstre hjørne)
- BackgroundTransparency: 1
- ClipsDescendants: true

Inde i MinimapFrame:
```
MapBackground     Frame   Size={1,0},{1,0}  BackgroundColor=RGB(30,30,30)  Transparency=0.3
ZoneCircle        Frame   Size={0,0},{0,0}  BackgroundColor=RGB(60,140,255) Transparency=0.5  (UICorner CornerRadius=0,1 for cirkel)
TargetZoneCircle  Frame   Size={0,0},{0,0}  BackgroundColor=RGB(255,60,60)  Transparency=0.6  (UICorner CornerRadius=0,1)
PlayerDot         Frame   Size={0,10},{0,10} BackgroundColor=RGB(255,220,0) (UICorner CornerRadius=0,1)
```

Tip: For at gøre firkanter runde, insert UICorner og sæt CornerRadius til `{1, 0}`.

**SpectatorHUD** (inde i BattleRoyaleHUD):
- Type: Frame
- Size: `{1,0},{1,0}` (dækker hele skærmen)
- BackgroundTransparency: 1
- Visible: false (sættes til true af SpectatorController)

Inde i SpectatorHUD:
```
SpectatorLabel  TextLabel  Size={0.4,0},{0,30}  Position={0.3,0},{0.05,0}
                Text="Du spectater: ..."  Font=GothamBold  TextSize=18

CycleHint       TextLabel  Size={0.4,0},{0,24}  Position={0.3,0},{0.1,0}
                Text="[ Q ] ← Forrige   Næste → [ E ]"  Font=Gotham  TextSize=14
```

**AmmoLabel** (inde i BattleRoyaleHUD):
- Type: TextLabel
- Size: `{0,120},{0,30}`
- Position: `{0.8,0},{0.9,0}` (nede til højre)
- Font: GothamBold, TextSize: 22
- Text: "30 / 120"

---

### Ammo-system i WeaponTool (tilføjelse)

Tilføj dette til din WeaponTool LocalScript for at tracke ammo klient-side og sende opdateringer:

```lua
-- Tilføj i toppen af WeaponTool (efter 'local def = weaponDefs[weaponName]'):
local ammoRemote = remotes:WaitForChild("AmmoUpdate") :: RemoteEvent

local magSize   = def and def.magSize or 30
local currentAmmo = magSize
local totalAmmo   = magSize * 3   -- 3 magasiner total

local isReloading = false

local function updateAmmoUI()
	ammoRemote:FireServer(currentAmmo, totalAmmo)
	-- Faktisk: klienten skal bruge FireServer kun hvis server holder ammo-state.
	-- For MVP: brug en BindableEvent eller lokal RemoteEvent til UI-kun opdatering.
	-- Hurtigste løsning: send direkte til lokal UI via en BindableEvent.
end

-- Erstat shoot()-funktionen med denne version der tracker ammo:
local function shoot()
	if not equipped then return end
	if not def then return end
	if isReloading then return end
	if currentAmmo <= 0 then
		-- Auto-reload
		isReloading = true
		task.delay(def.reloadTime or 2, function()
			if totalAmmo <= 0 then
				isReloading = false
				return
			end
			local refill = math.min(magSize - currentAmmo, totalAmmo)
			currentAmmo += refill
			totalAmmo -= refill
			isReloading = false
			-- Opdatér UI
			local ammoLbl = player:WaitForChild("PlayerGui")
				:WaitForChild("BattleRoyaleHUD")
				:FindFirstChild("AmmoLabel") :: TextLabel?
			if ammoLbl then
				ammoLbl.Text = currentAmmo .. " / " .. totalAmmo
				ammoLbl.TextColor3 = Color3.new(1,1,1)
			end
		end)
		return
	end

	local now = os.clock()
	if now - lastFireTime < fireInterval then return end
	lastFireTime = now

	currentAmmo -= 1

	-- Opdatér ammo UI direkte (ingen server-tur nødvendig for display)
	local ammoLbl = player:WaitForChild("PlayerGui")
		:WaitForChild("BattleRoyaleHUD")
		:FindFirstChild("AmmoLabel") :: TextLabel?
	if ammoLbl then
		ammoLbl.Text = currentAmmo .. " / " .. totalAmmo
		ammoLbl.TextColor3 = (currentAmmo <= 5)
			and Color3.fromRGB(255, 80, 80)
			or  Color3.fromRGB(255, 255, 255)
	end

	-- Raycast og skyd (samme som før)
	local origin    = camera.CFrame.Position
	local direction = camera.CFrame.LookVector * (def.range or 300)

	local rayParams = RaycastParams.new()
	rayParams.FilterType = Enum.RaycastFilterType.Exclude
	rayParams.FilterDescendantsInstances = { character }

	local result = workspace:Raycast(origin, direction, rayParams)

	local targetPlayer: Player? = nil
	local hitPosition = origin + direction

	if result then
		hitPosition = result.Position
		if result.Instance:IsA("BasePart") then
			targetPlayer = findPlayerFromPart(result.Instance)
		end
	end

	playMuzzleFlash()

	if targetPlayer then
		shootRemote:FireServer(targetPlayer, hitPosition, weaponName)
	end
end

-- Opdatér ammo-label ved equip
tool.Equipped:Connect(function()
	equipped = true
	local ammoLbl = player:WaitForChild("PlayerGui")
		:WaitForChild("BattleRoyaleHUD")
		:FindFirstChild("AmmoLabel") :: TextLabel?
	if ammoLbl then ammoLbl.Text = currentAmmo .. " / " .. totalAmmo end
	-- ... resten af Equipped handler ...
end)
```

---

### Opdateret MatchManager — integrer SpectatorSystem

Tilføj i `MatchManager.new(deps)`:

```lua
-- I deps-tabellen:
local match = MatchManager.new({
	storm     = storm,
	loot      = loot,
	elim      = elim,
	data      = DataManager,
	spectator = SpectatorSystem,   -- ← NYT
})
```

I `MatchManager:EliminatePlayer()`, tilføj efter `self._alive[player] = false`:

```lua
function MatchManager:EliminatePlayer(player: Player, killer: Player?)
	if not self._alive[player] then return end
	self._alive[player] = false
	local placement = #self:GetAlive() + 1
	self._elim:RecordElimination(player, killer, placement)

	-- Start spectator for den eliminerede spiller
	if self._spectator then
		local alive = self:GetAlive()
		self._spectator.beginSpectating(player, alive)
		-- Opdatér alle der specterede en der nu er ude
		self._spectator.onTargetEliminated(player, alive)
	end

	-- Bloker respawn under match
	task.delay(0.5, function()
		if player.Parent then
			player:LoadCharacter() -- respawn som ghost (ingen collision/weapon)
			-- TODO: sæt karakter usynlig / ingen collision
		end
	end)

	print(string.format("[MatchManager] %s eliminated #%d. %d tilbage.", player.Name, placement, #self:GetAlive()))
end
```

I `MatchManager.new()`, gem spectator-referencen:

```lua
function MatchManager.new(deps)
	local self = setmetatable({}, MatchManager)
	self._storm     = deps.storm
	self._loot      = deps.loot
	self._elim      = deps.elim
	self._data      = deps.data
	self._spectator = deps.spectator   -- ← NYT
	-- ...
end
```

I `Start()`, ved CLEANUP-fasen, stop spectator:

```lua
-- Cleanup fase:
self:_setPhase("Cleanup")
self._storm:Stop()
self._loot:DespawnAllLoot()
if self._spectator then
	self._spectator.reset()
	-- Fortæl alle klienter at stoppe spectating
	for _, p in Players:GetPlayers() do
		self._spectator.stopSpectating(p)
	end
end
self:_teleportToLobby()
task.wait(Config.CLEANUP_DURATION)
```

---

### Opdateret GameManager — init SpectatorSystem

```lua
-- Tilføj i require-sektionen:
local SpectatorSystem = require(ServerScriptService.BattleRoyale.SpectatorSystem)

-- Tilføj efter WeaponServer.init():
SpectatorSystem.init()
SpectatorSystem.setAliveGetter(function()
	return match and match:GetAlive() or {}
end)

-- Opdatér MatchManager.new:
local match = MatchManager.new({
	storm     = storm,
	loot      = loot,
	elim      = elim,
	data      = DataManager,
	spectator = SpectatorSystem,
})
```

---

## TEST CHECKLIST

```
[ ] Spiller A og B starter match
[ ] Spiller A skyder Spiller B ihjel
[ ] SpectatorHUD dukker op hos Spiller B: "Du spectater: PlayerA"
[ ] Kameraet følger Spiller A jævnt (lerp-animation)
[ ] Q/E skifter til næste levende spiller
[ ] Minimap viser zone-cirkel (blå = safe zone)
[ ] Zone begynder at krympe → cirkel bliver rød og shrinks
[ ] Target zone (rød gestipplet) viser hvad next zone bliver
[ ] Spiller-dot (gul) bevæger sig på minimap
[ ] Ammo-tæller viser "30 / 90" og tæller ned ved skydning
[ ] Auto-reload starter når mag er tom
[ ] Ammo-label rød ved ≤5 skud tilbage
[ ] Victory → SpectatorHUD forsvinder, kamera tilbage til normal
```

---

## NÆSTE SKRIDT

Projektet er nu et fungerende battle royale med:
- ✅ Match loop (lobby → kamp → victory → cleanup)
- ✅ Shrinking zone med damage
- ✅ Loot spawn med rarity tiers
- ✅ Server-autoritativt combat
- ✅ Spectator system med Q/E cycling
- ✅ Minimap med live zone
- ✅ Ammo-tæller med auto-reload
- ✅ Kill feed + data persistence

**Hvad der mangler for at shippe:**
- Rigtige 3D weapon models (ServerStorage/Weapons/)
- Et rigtigt map (erstat Map-folderen)
- Sound effects (skud, hit, zone buzz)
- Leaderboard (OrderedDataStore på Wins)
- Monetization (VIP gamepass, kosmetik)
- Security audit (køre `workflows/security-audit.md`)
- Publish checklist
