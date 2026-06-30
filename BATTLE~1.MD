# Battle Royale — Setup Scripts (Del 4)
# Kør disse scripts ÉN GANG i Studio via Plugin-konsollen eller Script Editor

Disse scripts opretter alt det manglende: UI, StarterPack-pistol og map.
Kør dem via: Plugins → Command Bar (eller tryk F9 → Command Bar i bunden)

---

## SCRIPT 1: Opret hele StarterGui HUD
## Kør dette i Roblox Studio Command Bar (én linje ad gangen er ok, eller brug en Script)

Indsæt en ny Script i ServerScriptService, kald den "SetupUI_RUNONCE",
kør spillet i Edit-tilstand (tryk Play → Stop øjeblikkeligt), slet derefter scriptet.

ELLER: Brug Plugin-konsollen (View → Command Bar) og kør scriptet direkte.

```lua
-- =====================================================
-- SetupUI_RUNONCE
-- Kør dette ÉN GANG for at oprette hele BattleRoyaleHUD
-- Slet scriptet bagefter!
-- =====================================================

local StarterGui = game:GetService("StarterGui")

-- Ryd eksisterende HUD hvis det allerede eksisterer
local existing = StarterGui:FindFirstChild("BattleRoyaleHUD")
if existing then existing:Destroy() end

-- ── Hjælpefunktioner ─────────────────────────────────

local function makeFrame(name, parent, size, pos, bgColor, transparency)
	local f = Instance.new("Frame")
	f.Name = name
	f.Size = size or UDim2.new(1,0,1,0)
	f.Position = pos or UDim2.new(0,0,0,0)
	f.BackgroundColor3 = bgColor or Color3.new(0,0,0)
	f.BackgroundTransparency = transparency or 1
	f.BorderSizePixel = 0
	f.Parent = parent
	return f
end

local function makeLabel(name, parent, size, pos, text, fontSize, font, color)
	local l = Instance.new("TextLabel")
	l.Name = name
	l.Size = size or UDim2.new(1,0,0,30)
	l.Position = pos or UDim2.new(0,0,0,0)
	l.BackgroundTransparency = 1
	l.Text = text or ""
	l.TextSize = fontSize or 16
	l.Font = font or Enum.Font.GothamBold
	l.TextColor3 = color or Color3.new(1,1,1)
	l.TextStrokeTransparency = 0.5
	l.TextStrokeColor3 = Color3.new(0,0,0)
	l.TextXAlignment = Enum.TextXAlignment.Center
	l.Parent = parent
	return l
end

local function makeButton(name, parent, size, pos, text)
	local b = Instance.new("TextButton")
	b.Name = name
	b.Size = size
	b.Position = pos
	b.Text = text
	b.Font = Enum.Font.GothamBold
	b.TextSize = 16
	b.TextColor3 = Color3.new(1,1,1)
	b.BackgroundColor3 = Color3.fromRGB(40,40,40)
	b.BackgroundTransparency = 0.3
	b.BorderSizePixel = 0
	b.AutoButtonColor = true
	b.Parent = parent
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0,6)
	corner.Parent = b
	return b
end

local function addCorner(frame, radius)
	local c = Instance.new("UICorner")
	c.CornerRadius = radius or UDim.new(1,0)
	c.Parent = frame
	return c
end

local function addStroke(frame, color, thickness)
	local s = Instance.new("UIStroke")
	s.Color = color or Color3.fromRGB(255,255,255)
	s.Thickness = thickness or 1
	s.Transparency = 0.7
	s.Parent = frame
end

-- ── Opret ScreenGui ──────────────────────────────────

local hud = Instance.new("ScreenGui")
hud.Name = "BattleRoyaleHUD"
hud.ResetOnSpawn = false
hud.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
hud.DisplayOrder = 10
hud.Parent = StarterGui

print("Opretter BattleRoyaleHUD...")

-- ══════════════════════════════════════════════════════
-- 1. MINIMAP (øverst til venstre)
-- ══════════════════════════════════════════════════════

local minimapOuter = makeFrame("MinimapFrame", hud,
	UDim2.fromOffset(210, 210),
	UDim2.fromOffset(10, 10),
	Color3.fromRGB(0,0,0), 1)

local mapBg = makeFrame("MapBackground", minimapOuter,
	UDim2.new(1,0,1,0),
	UDim2.new(0,0,0,0),
	Color3.fromRGB(20,30,20), 0.25)
addCorner(mapBg, UDim.new(0,8))
addStroke(mapBg, Color3.fromRGB(100,200,100), 1.5)

-- Zone-cirkler (starter tomme — HUDController styrer størrelse)
local zoneCircle = makeFrame("ZoneCircle", minimapOuter,
	UDim2.fromOffset(0,0), UDim2.fromOffset(0,0),
	Color3.fromRGB(60,140,255), 0.5)
addCorner(zoneCircle)
addStroke(zoneCircle, Color3.fromRGB(100,180,255), 2)

local targetZoneCircle = makeFrame("TargetZoneCircle", minimapOuter,
	UDim2.fromOffset(0,0), UDim2.fromOffset(0,0),
	Color3.fromRGB(255,60,60), 0.65)
addCorner(targetZoneCircle)
addStroke(targetZoneCircle, Color3.fromRGB(255,100,100), 1.5)
targetZoneCircle.Visible = false

-- Spiller-dot (gul)
local playerDot = makeFrame("PlayerDot", minimapOuter,
	UDim2.fromOffset(10,10), UDim2.fromOffset(100,100),
	Color3.fromRGB(255,220,0), 0)
addCorner(playerDot)

-- Minimap label
local minimapLabel = makeLabel("MinimapLabel", minimapOuter,
	UDim2.new(1,0,0,18),
	UDim2.new(0,0,1,2),
	"MINIMAP", 11, Enum.Font.GothamBold,
	Color3.fromRGB(150,150,150))

print("  ✓ Minimap oprettet")

-- ══════════════════════════════════════════════════════
-- 2. ALIVE COUNT (øverst til højre)
-- ══════════════════════════════════════════════════════

local aliveFrame = makeFrame("AliveFrame", hud,
	UDim2.fromOffset(160, 60),
	UDim2.new(1,-170,0,10),
	Color3.fromRGB(0,0,0), 0.5)
addCorner(aliveFrame, UDim.new(0,8))
addStroke(aliveFrame, Color3.fromRGB(255,255,255), 1)

local aliveIcon = makeLabel("AliveIcon", aliveFrame,
	UDim2.fromOffset(40,40),
	UDim2.fromOffset(10,10),
	"👤", 24, Enum.Font.GothamBold, Color3.new(1,1,1))

local aliveLabel = makeLabel("AliveLabel", aliveFrame,
	UDim2.new(1,-60,1,0),
	UDim2.fromOffset(55,0),
	"-- tilbage", 18, Enum.Font.GothamBold, Color3.new(1,1,1))
aliveLabel.TextXAlignment = Enum.TextXAlignment.Left

print("  ✓ AliveCounter oprettet")

-- ══════════════════════════════════════════════════════
-- 3. COUNTDOWN / MATCH INFO (midt øverst)
-- ══════════════════════════════════════════════════════

local countdownFrame = makeFrame("CountdownFrame", hud,
	UDim2.fromOffset(300,70),
	UDim2.new(0.5,-150,0,10),
	Color3.fromRGB(0,0,0), 0.45)
addCorner(countdownFrame, UDim.new(0,10))
addStroke(countdownFrame, Color3.fromRGB(255,200,50), 1.5)

local countdownLabel = makeLabel("CountdownLabel", countdownFrame,
	UDim2.new(1,0,0.6,0),
	UDim2.new(0,0,0,0),
	"Venter på spillere...", 22, Enum.Font.GothamBold,
	Color3.fromRGB(255,220,80))

local phaseLabel = makeLabel("PhaseLabel", countdownFrame,
	UDim2.new(1,0,0.4,0),
	UDim2.new(0,0,0.6,0),
	"", 13, Enum.Font.Gotham,
	Color3.fromRGB(200,200,200))

print("  ✓ Countdown oprettet")

-- ══════════════════════════════════════════════════════
-- 4. KILL FEED (venstre side, midten)
-- ══════════════════════════════════════════════════════

local killFeedFrame = makeFrame("KillFeedFrame", hud,
	UDim2.fromOffset(280,160),
	UDim2.fromOffset(10,230),
	Color3.new(0,0,0), 1)

-- UIListLayout så nye kills tilføjes i toppen
local listLayout = Instance.new("UIListLayout")
listLayout.SortOrder = Enum.SortOrder.LayoutOrder
listLayout.Padding = UDim.new(0,3)
listLayout.VerticalAlignment = Enum.VerticalAlignment.Bottom
listLayout.Parent = killFeedFrame

print("  ✓ KillFeed oprettet")

-- ══════════════════════════════════════════════════════
-- 5. AMMO TÆLLER (nede til højre)
-- ══════════════════════════════════════════════════════

local ammoFrame = makeFrame("AmmoFrame", hud,
	UDim2.fromOffset(200,60),
	UDim2.new(1,-210,1,-80),
	Color3.fromRGB(0,0,0), 0.45)
addCorner(ammoFrame, UDim.new(0,8))
addStroke(ammoFrame, Color3.fromRGB(200,200,200), 1)

local ammoLabel = makeLabel("AmmoLabel", ammoFrame,
	UDim2.new(1,0,1,0),
	UDim2.new(0,0,0,0),
	"-- / --", 28, Enum.Font.GothamBold,
	Color3.fromRGB(255,255,255))

local weaponNameLabel = makeLabel("WeaponNameLabel", ammoFrame,
	UDim2.new(1,0,0,20),
	UDim2.new(0,0,1,2),
	"", 12, Enum.Font.Gotham,
	Color3.fromRGB(180,180,180))

print("  ✓ AmmoCounter oprettet")

-- ══════════════════════════════════════════════════════
-- 6. HIT MARKER (midt på skærmen)
-- ══════════════════════════════════════════════════════

local hitMarker = makeFrame("HitMarker", hud,
	UDim2.fromOffset(16,16),
	UDim2.new(0.5,-8,0.5,-8),
	Color3.fromRGB(255,50,50), 1)
addCorner(hitMarker)

print("  ✓ HitMarker oprettet")

-- ══════════════════════════════════════════════════════
-- 7. CROSSHAIR (midt på skærmen)
-- ══════════════════════════════════════════════════════

local crosshairFrame = makeFrame("CrosshairFrame", hud,
	UDim2.fromOffset(30,30),
	UDim2.new(0.5,-15,0.5,-15),
	Color3.new(0,0,0), 1)

-- 4 linjer: top, bund, venstre, højre
local lines = {
	{UDim2.fromOffset(2,10), UDim2.new(0.5,-1,0.5,-14)},  -- top
	{UDim2.fromOffset(2,10), UDim2.new(0.5,-1,0.5,4)},    -- bund
	{UDim2.fromOffset(10,2), UDim2.new(0.5,-14,0.5,-1)},  -- venstre
	{UDim2.fromOffset(10,2), UDim2.new(0.5,4,0.5,-1)},    -- højre
}
for i, l in lines do
	local line = makeFrame("Line"..i, crosshairFrame, l[1], l[2],
		Color3.new(1,1,1), 0)
	addStroke(line, Color3.new(0,0,0), 1)
end

print("  ✓ Crosshair oprettet")

-- ══════════════════════════════════════════════════════
-- 8. SPECTATOR HUD (dækker skærmen ved eliminering)
-- ══════════════════════════════════════════════════════

local spectatorHUD = makeFrame("SpectatorHUD", hud,
	UDim2.new(1,0,1,0),
	UDim2.new(0,0,0,0),
	Color3.new(0,0,0), 1)
spectatorHUD.Visible = false

-- Mørk vignette-effekt
local vignette = makeFrame("Vignette", spectatorHUD,
	UDim2.new(1,0,1,0), UDim2.new(0,0,0,0),
	Color3.new(0,0,0), 0.55)

-- "SPECTATING" tekst
local spectatingBanner = makeFrame("SpectatingBanner", spectatorHUD,
	UDim2.fromOffset(400,70),
	UDim2.new(0.5,-200,0,20),
	Color3.fromRGB(0,0,0), 0.5)
addCorner(spectatingBanner, UDim.new(0,10))
addStroke(spectatingBanner, Color3.fromRGB(200,80,80), 2)

local spectatorLabel = makeLabel("SpectatorLabel", spectatingBanner,
	UDim2.new(1,0,0.6,0), UDim2.new(0,0,0,0),
	"Du spectater: ...", 20, Enum.Font.GothamBold,
	Color3.fromRGB(255,200,80))

local cycleHint = makeLabel("CycleHint", spectatingBanner,
	UDim2.new(1,0,0.4,0), UDim2.new(0,0,0.6,0),
	"[ Q ] ◀  Forrige     Næste  ▶ [ E ]", 13, Enum.Font.Gotham,
	Color3.fromRGB(180,180,180))

-- Pladserings-label (nede til venstre)
local placementLabel = makeLabel("PlacementLabel", spectatorHUD,
	UDim2.fromOffset(200,50),
	UDim2.fromOffset(10, -60),
	"Du blev #--", 22, Enum.Font.GothamBold,
	Color3.fromRGB(255,80,80))
placementLabel.AnchorPoint = Vector2.new(0,1)
placementLabel.Position = UDim2.new(0,10,1,-10)
placementLabel.TextXAlignment = Enum.TextXAlignment.Left

print("  ✓ SpectatorHUD oprettet")

-- ══════════════════════════════════════════════════════
-- 9. VICTORY SCREEN
-- ══════════════════════════════════════════════════════

local victoryScreen = makeFrame("VictoryScreen", hud,
	UDim2.new(1,0,1,0), UDim2.new(0,0,0,0),
	Color3.fromRGB(0,0,0), 0.4)
victoryScreen.Visible = false

local victoryLabel = makeLabel("VictoryLabel", victoryScreen,
	UDim2.new(1,0,0,80),
	UDim2.new(0,0,0.35,0),
	"🏆 VICTORY ROYALE!", 52, Enum.Font.GothamBlack,
	Color3.fromRGB(255,220,0))

local victorySubLabel = makeLabel("VictorySubLabel", victoryScreen,
	UDim2.new(1,0,0,40),
	UDim2.new(0,0,0.55,0),
	"", 26, Enum.Font.GothamBold,
	Color3.fromRGB(255,255,200))

-- "ELIMINATED" skærm
local eliminatedScreen = makeFrame("EliminatedScreen", hud,
	UDim2.new(1,0,1,0), UDim2.new(0,0,0,0),
	Color3.fromRGB(200,0,0), 0.7)
eliminatedScreen.Visible = false

local eliminatedLabel = makeLabel("EliminatedLabel", eliminatedScreen,
	UDim2.new(1,0,0,80),
	UDim2.new(0,0,0.35,0),
	"☠ ELIMINATED", 52, Enum.Font.GothamBlack,
	Color3.fromRGB(255,255,255))

local eliminatedSubLabel = makeLabel("EliminatedSubLabel", eliminatedScreen,
	UDim2.new(1,0,0,40),
	UDim2.new(0,0,0.55,0),
	"", 22, Enum.Font.Gotham,
	Color3.fromRGB(230,230,230))

print("  ✓ Victory + Eliminated screens oprettet")

-- ══════════════════════════════════════════════════════
-- 10. ZONE TIMER (nede i midten)
-- ══════════════════════════════════════════════════════

local zoneTimerFrame = makeFrame("ZoneTimerFrame", hud,
	UDim2.fromOffset(260,50),
	UDim2.new(0.5,-130,1,-65),
	Color3.fromRGB(30,60,120), 0.4)
addCorner(zoneTimerFrame, UDim.new(0,8))
addStroke(zoneTimerFrame, Color3.fromRGB(60,140,255), 1.5)

local zoneTimerLabel = makeLabel("ZoneTimerLabel", zoneTimerFrame,
	UDim2.new(1,0,1,0), UDim2.new(0,0,0,0),
	"⚡ Zone stabil", 16, Enum.Font.GothamBold,
	Color3.fromRGB(150,200,255))

print("  ✓ ZoneTimer oprettet")

print("")
print("════════════════════════════════")
print("✅ BattleRoyaleHUD OPRETTET!")
print("Elementer:")
print("  - MinimapFrame (zone + player dot)")
print("  - AliveFrame (antal levende)")
print("  - CountdownFrame (match info)")
print("  - KillFeedFrame")
print("  - AmmoFrame + WeaponNameLabel")
print("  - HitMarker")
print("  - Crosshair")
print("  - SpectatorHUD")
print("  - VictoryScreen + EliminatedScreen")
print("  - ZoneTimerFrame")
print("════════════════════════════════")
print("NÆSTE: Kør Script 2 (Pistol + Map)")
```

---

## SCRIPT 2: Opret Standard Pistol i StarterPack + WeaponTool Script

```lua
-- =====================================================
-- SetupStarterPack_RUNONCE
-- Opretter en standard pistol i StarterPack
-- + WeaponToolScript i ReplicatedStorage
-- Slet scriptet bagefter!
-- =====================================================

local StarterPack       = game:GetService("StarterPack")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- Ryd eksisterende
local existingPistol = StarterPack:FindFirstChild("Pistol_Common")
if existingPistol then existingPistol:Destroy() end

-- ── Opret Tool ───────────────────────────────────────

local tool = Instance.new("Tool")
tool.Name = "Pistol_Common"
tool.RequiresHandle = true
tool.ToolTip = "Pistol [Common]"
tool.CanBeDropped = false
tool.Parent = StarterPack

-- Handle (hvad spilleren holder)
local handle = Instance.new("Part")
handle.Name = "Handle"
handle.Size = Vector3.new(0.3, 0.6, 1.2)
handle.Color = Color3.fromRGB(80, 80, 80)
handle.Material = Enum.Material.Metal
handle.Parent = tool

-- Løb
local barrel = Instance.new("Part")
barrel.Name = "Barrel"
barrel.Size = Vector3.new(0.18, 0.18, 0.8)
barrel.Color = Color3.fromRGB(60, 60, 60)
barrel.Material = Enum.Material.Metal
barrel.CFrame = handle.CFrame * CFrame.new(0, 0.1, -0.9)
barrel.Parent = tool

local weld = Instance.new("WeldConstraint")
weld.Part0 = handle
weld.Part1 = barrel
weld.Parent = handle

-- Muzzle (til muzzle flash)
local muzzle = Instance.new("Part")
muzzle.Name = "Muzzle"
muzzle.Size = Vector3.new(0.1, 0.1, 0.1)
muzzle.Transparency = 1
muzzle.CanCollide = false
muzzle.CFrame = handle.CFrame * CFrame.new(0, 0.1, -1.3)
muzzle.Parent = tool

local muzzleWeld = Instance.new("WeldConstraint")
muzzleWeld.Part0 = handle
muzzleWeld.Part1 = muzzle
muzzleWeld.Parent = handle

-- Muzzle flash PointLight
local muzzleLight = Instance.new("PointLight")
muzzleLight.Name = "MuzzleLight"
muzzleLight.Brightness = 0
muzzleLight.Color = Color3.fromRGB(255,200,100)
muzzleLight.Range = 16
muzzleLight.Parent = muzzle

-- Rarity tag
local rv = Instance.new("StringValue")
rv.Name = "Rarity"; rv.Value = "Common"; rv.Parent = tool

print("✓ Pistol_Common oprettet i StarterPack")

-- ── WeaponTool LocalScript ────────────────────────────

local existingScript = tool:FindFirstChild("WeaponTool")
if existingScript then existingScript:Destroy() end

local weaponScript = Instance.new("LocalScript")
weaponScript.Name = "WeaponTool"
weaponScript.Source = [[
--!strict
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local tool      = script.Parent
local player    = Players.LocalPlayer
local character = player.Character or player.CharacterAdded:Wait()
local camera    = workspace.CurrentCamera

local remotes      = ReplicatedStorage:WaitForChild("Remotes")
local shootRemote  = remotes:WaitForChild("ShootRequest")

local weaponName = tool.Name
local weaponDefs = require(ReplicatedStorage:WaitForChild("BattleRoyale"):WaitForChild("WeaponDefs"))
local def        = weaponDefs[weaponName]

local fireInterval = def and (1 / def.fireRate) or 0.35
local magSize      = def and def.magSize or 12
local reloadTime   = def and def.reloadTime or 1.5

local currentAmmo  = magSize
local totalAmmo    = magSize * 4
local isReloading  = false
local equipped     = false
local lastFireTime = 0

-- UI references
local function getHUD()
	return player.PlayerGui:FindFirstChild("BattleRoyaleHUD")
end

local function updateAmmoUI()
	local hud = getHUD()
	if not hud then return end
	local ammoLabel = hud:FindFirstChild("AmmoFrame") and hud.AmmoFrame:FindFirstChild("AmmoLabel")
	if ammoLabel then
		ammoLabel.Text = currentAmmo .. " / " .. totalAmmo
		ammoLabel.TextColor3 = (currentAmmo <= 3)
			and Color3.fromRGB(255, 70, 70)
			or  Color3.fromRGB(255,255,255)
	end
	local wnLabel = hud:FindFirstChild("AmmoFrame") and hud.AmmoFrame:FindFirstChild("WeaponNameLabel")
	if wnLabel then wnLabel.Text = weaponName end
end

local function clearAmmoUI()
	local hud = getHUD()
	if not hud then return end
	local ammoLabel = hud:FindFirstChild("AmmoFrame") and hud.AmmoFrame:FindFirstChild("AmmoLabel")
	if ammoLabel then ammoLabel.Text = "-- / --" end
	local wnLabel = hud:FindFirstChild("AmmoFrame") and hud.AmmoFrame:FindFirstChild("WeaponNameLabel")
	if wnLabel then wnLabel.Text = "" end
end

-- Muzzle flash
local muzzlePart  = tool:FindFirstChild("Muzzle")
local muzzleLight = muzzlePart and muzzlePart:FindFirstChildOfClass("PointLight")

local function playMuzzleFlash()
	if not muzzleLight then return end
	muzzleLight.Brightness = 5
	task.delay(0.06, function()
		if muzzleLight then muzzleLight.Brightness = 0 end
	end)
end

-- Hit marker
local function showHitMarker()
	local hud = getHUD()
	if not hud then return end
	local hm = hud:FindFirstChild("HitMarker")
	if not hm then return end
	hm.BackgroundTransparency = 0
	task.delay(0.12, function()
		if hm then hm.BackgroundTransparency = 1 end
	end)
end

-- Find spiller fra Part
local function findPlayer(part)
	local model = part
	while model and not model:IsA("Model") do model = model.Parent end
	if not model then return nil end
	for _, p in Players:GetPlayers() do
		if p.Character == model then return p end
	end
	return nil
end

-- Reload
local function reload()
	if isReloading then return end
	if currentAmmo == magSize then return end
	if totalAmmo <= 0 then return end

	isReloading = true
	local hud = getHUD()
	if hud then
		local ammoLabel = hud:FindFirstChild("AmmoFrame") and hud.AmmoFrame:FindFirstChild("AmmoLabel")
		if ammoLabel then ammoLabel.Text = "Genloader..." end
	end

	task.delay(reloadTime, function()
		if not equipped then isReloading = false return end
		local need = magSize - currentAmmo
		local take = math.min(need, totalAmmo)
		currentAmmo += take
		totalAmmo -= take
		isReloading = false
		updateAmmoUI()
	end)
end

-- Skyd
local function shoot()
	if not equipped or isReloading then return end
	if not def then return end

	local now = os.clock()
	if now - lastFireTime < fireInterval then return end
	lastFireTime = now

	if currentAmmo <= 0 then
		reload()
		return
	end

	currentAmmo -= 1
	updateAmmoUI()

	local origin    = camera.CFrame.Position
	local direction = camera.CFrame.LookVector * (def.range or 200)

	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = { character }

	local result = workspace:Raycast(origin, direction, params)

	local targetPlayer = nil
	local hitPos = origin + direction

	if result then
		hitPos = result.Position
		if result.Instance:IsA("BasePart") then
			targetPlayer = findPlayer(result.Instance)
		end
	end

	playMuzzleFlash()

	if targetPlayer then
		shootRemote:FireServer(targetPlayer, hitPos, weaponName)
		showHitMarker()
	end
end

-- Input
local inputConn = nil

tool.Equipped:Connect(function()
	equipped = true
	character = player.Character or character
	updateAmmoUI()

	inputConn = UserInputService.InputBegan:Connect(function(input, processed)
		if processed then return end
		if input.UserInputType == Enum.UserInputType.MouseButton1
		or input.KeyCode == Enum.KeyCode.ButtonR2 then
			shoot()
		end
		if input.KeyCode == Enum.KeyCode.R then
			reload()
		end
	end)
end)

tool.Unequipped:Connect(function()
	equipped = false
	if inputConn then inputConn:Disconnect(); inputConn = nil end
	clearAmmoUI()
end)
]]
weaponScript.Parent = tool

print("✓ WeaponTool LocalScript tilføjet til Pistol_Common")

-- ── WeaponToolScript i ReplicatedStorage (til LootSpawner) ───

local existingRS = ReplicatedStorage:FindFirstChild("WeaponToolScript")
if existingRS then existingRS:Destroy() end

local rsScript = weaponScript:Clone()
rsScript.Name = "WeaponToolScript"
rsScript.Parent = ReplicatedStorage

print("✓ WeaponToolScript klonet til ReplicatedStorage")
print("")
print("NÆSTE: Kør Script 3 (Map Builder)")
```

---

## SCRIPT 3: Map Builder

```lua
-- =====================================================
-- MapBuilder_RUNONCE
-- Genererer et simpelt spillebart map:
-- - En stor flad arena (500x500 studs)
-- - 8 husblokke fordelt rundt på kortet
-- - 32 loot-spawn-punkter tagget med "LootSpawn"
-- - LobbySpawn i midten
-- - Belysning og atmosfære
-- Slet scriptet bagefter!
-- =====================================================

local CollectionService = game:GetService("CollectionService")

-- Ryd eksisterende map-folder
local mapFolder = workspace:FindFirstChild("Map")
if mapFolder then mapFolder:Destroy() end
local lootFolder = workspace:FindFirstChild("LootFolder")
if lootFolder then lootFolder:Destroy() end

mapFolder = Instance.new("Folder")
mapFolder.Name = "Map"
mapFolder.Parent = workspace

lootFolder = Instance.new("Folder")
lootFolder.Name = "LootFolder"
lootFolder.Parent = workspace

local function makePart(name, parent, size, cf, color, material, anchored)
	local p = Instance.new("Part")
	p.Name = name
	p.Size = size
	p.CFrame = cf
	p.Color = color or Color3.fromRGB(100,100,100)
	p.Material = material or Enum.Material.SmoothPlastic
	p.Anchored = anchored ~= false
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Parent = parent
	return p
end

-- ── 1. GROUND ─────────────────────────────────────────

makePart("Ground", mapFolder,
	Vector3.new(600, 4, 600),
	CFrame.new(0, -2, 0),
	Color3.fromRGB(80, 110, 70),
	Enum.Material.Grass)

-- ── 2. BOUNDARY WALLS (usynlige) ─────────────────────

local wallConfigs = {
	{Vector3.new(600,60,4),  CFrame.new(0,30,302)},
	{Vector3.new(600,60,4),  CFrame.new(0,30,-302)},
	{Vector3.new(4,60,600),  CFrame.new(302,30,0)},
	{Vector3.new(4,60,600),  CFrame.new(-302,30,0)},
}
for i, cfg in wallConfigs do
	local w = makePart("Wall"..i, mapFolder, cfg[1], cfg[2],
		Color3.fromRGB(150,100,50), Enum.Material.SmoothPlastic)
	w.Transparency = 0.9
	w.CanCollide = true
end

-- ── 3. BYGNINGER ──────────────────────────────────────

local buildingConfigs = {
	-- { position, width, depth, height, wallColor }
	{Vector3.new(80,  0, 80),  30, 25, 16, Color3.fromRGB(180,140,100)},
	{Vector3.new(-80, 0, 80),  25, 20, 12, Color3.fromRGB(140,100,80)},
	{Vector3.new(80,  0,-80),  35, 28, 20, Color3.fromRGB(160,120,90)},
	{Vector3.new(-80, 0,-80),  28, 22, 14, Color3.fromRGB(130,100,80)},
	{Vector3.new(180, 0, 0),   20, 20, 10, Color3.fromRGB(170,130,90)},
	{Vector3.new(-180,0, 0),   22, 18, 12, Color3.fromRGB(150,110,80)},
	{Vector3.new(0,   0,180),  40, 30, 18, Color3.fromRGB(160,120,100)},
	{Vector3.new(0,   0,-180), 35, 25, 16, Color3.fromRGB(140,110,85)},
}

for i, cfg in buildingConfigs do
	local center = cfg[1]
	local w, d, h = cfg[2], cfg[3], cfg[4]
	local wallColor = cfg[5]
	local wallThick = 2

	-- Gulv
	makePart("Floor"..i, mapFolder,
		Vector3.new(w, 1, d),
		CFrame.new(center.X, 0.5, center.Z),
		Color3.fromRGB(120,100,80), Enum.Material.Wood)

	-- Tag
	makePart("Roof"..i, mapFolder,
		Vector3.new(w+2, 2, d+2),
		CFrame.new(center.X, h+1, center.Z),
		Color3.fromRGB(100,60,40), Enum.Material.Brick)

	-- 4 ydervægge (med en "dør"-åbning i den ene)
	local walls = {
		{Vector3.new(w, h, wallThick),   CFrame.new(center.X, h/2, center.Z + d/2)},  -- front
		{Vector3.new(w, h, wallThick),   CFrame.new(center.X, h/2, center.Z - d/2)},  -- bag
		{Vector3.new(wallThick, h, d-8), CFrame.new(center.X + w/2, h/2, center.Z)},  -- højre (med dør)
		{Vector3.new(wallThick, h, d),   CFrame.new(center.X - w/2, h/2, center.Z)},  -- venstre
	}
	for j, wcfg in walls do
		makePart("Wall"..i.."_"..j, mapFolder, wcfg[1], wcfg[2],
			wallColor, Enum.Material.Brick)
	end

	-- Vinduer (dekorative)
	local windowPart = makePart("Window"..i, mapFolder,
		Vector3.new(3, 3, 0.2),
		CFrame.new(center.X-4, h/2, center.Z + d/2 + 0.1),
		Color3.fromRGB(150,200,220), Enum.Material.Glass)
	windowPart.Transparency = 0.5
end

-- ── 4. NATURLIGE COVER-ELEMENTER ─────────────────────

-- Træer (simple)
local treePositions = {
	{120,0,120}, {-120,0,120}, {120,0,-120}, {-120,0,-120},
	{200,0,150}, {-200,0,150}, {200,0,-150}, {-200,0,-150},
	{50,0,200},  {-50,0,200},  {50,0,-200},  {-50,0,-200},
}
for i, pos in treePositions do
	-- Stamme
	local trunk = makePart("TreeTrunk"..i, mapFolder,
		Vector3.new(2,8,2),
		CFrame.new(pos[1], 4, pos[3]),
		Color3.fromRGB(90,60,40), Enum.Material.Wood)
	-- Krone
	local crown = makePart("TreeCrown"..i, mapFolder,
		Vector3.new(8,10,8),
		CFrame.new(pos[1], 13, pos[3]),
		Color3.fromRGB(40,100,40), Enum.Material.Grass)
end

-- Sten
local rockPositions = {
	{150,0,50}, {-150,0,50}, {150,0,-50}, {-150,0,-50},
	{30,0,150}, {-30,0,150},
}
for i, pos in rockPositions do
	makePart("Rock"..i, mapFolder,
		Vector3.new(math.random(4,8), math.random(2,4), math.random(4,8)),
		CFrame.new(pos[1], math.random(1,2), pos[3]),
		Color3.fromRGB(120,120,120), Enum.Material.Slate)
end

-- ── 5. LOOT SPAWN POINTS ─────────────────────────────

local lootSpawnPositions = {
	-- Inde i bygninger
	{75,1,75},  {85,1,85},  {-75,1,75},  {-85,1,85},
	{75,1,-75}, {85,1,-85}, {-75,1,-75}, {-85,1,-85},
	{180,1,5},  {175,1,-5}, {-180,1,5},  {-175,1,-5},
	{5,1,180},  {-5,1,180}, {5,1,-180},  {-5,1,-180},
	-- Åben mark
	{120,1,0},  {-120,1,0}, {0,1,120},   {0,1,-120},
	{200,1,200},{-200,1,200},{200,1,-200},{-200,1,-200},
	{50,1,50},  {-50,1,50}, {50,1,-50},  {-50,1,-50},
	{140,1,100},{-140,1,100},{140,1,-100},{-140,1,-100},
}

local lootSpawnFolder = Instance.new("Folder")
lootSpawnFolder.Name = "LootSpawns"
lootSpawnFolder.Parent = mapFolder

for i, pos in lootSpawnPositions do
	local spawnPart = makePart("LootSpawn"..i, lootSpawnFolder,
		Vector3.new(2,0.2,2),
		CFrame.new(pos[1], pos[2], pos[3]),
		Color3.fromRGB(255,200,0), Enum.Material.Neon)
	spawnPart.Transparency = 0.6
	spawnPart.CanCollide = false
	CollectionService:AddTag(spawnPart, "LootSpawn")
end

print("✓ " .. #lootSpawnPositions .. " LootSpawn punkter oprettet og tagget")

-- ── 6. LOBBY SPAWN ────────────────────────────────────

local existingSpawn = workspace:FindFirstChild("LobbySpawn")
if existingSpawn then existingSpawn:Destroy() end

local lobbySpawn = Instance.new("SpawnLocation")
lobbySpawn.Name = "LobbySpawn"
lobbySpawn.Size = Vector3.new(10, 1, 10)
lobbySpawn.CFrame = CFrame.new(0, 1, 0)
lobbySpawn.Anchored = true
lobbySpawn.Neutral = true
lobbySpawn.AllowTeamChangeOnTouch = false
lobbySpawn.Duration = 0
lobbySpawn.Material = Enum.Material.Neon
lobbySpawn.Color = Color3.fromRGB(100, 200, 100)
lobbySpawn.Parent = workspace

print("✓ LobbySpawn oprettet i centrum")

-- ── 7. BELYSNING ──────────────────────────────────────

local lighting = game:GetService("Lighting")
lighting.Ambient       = Color3.fromRGB(100,100,120)
lighting.Brightness    = 2
lighting.ClockTime     = 14.5  -- eftermiddag
lighting.FogEnd        = 1200
lighting.FogStart      = 800
lighting.FogColor      = Color3.fromRGB(180,190,200)
lighting.ShadowSoftness = 0.25

-- Atmosfære
local atmo = lighting:FindFirstChildOfClass("Atmosphere") or Instance.new("Atmosphere")
atmo.Density     = 0.3
atmo.Offset      = 0.25
atmo.Color       = Color3.fromRGB(200,210,220)
atmo.Decay       = Color3.fromRGB(80,90,100)
atmo.Glare       = 0.1
atmo.Haze        = 1.5
atmo.Parent      = lighting

print("✓ Lighting og Atmosfære sat")

print("")
print("══════════════════════════════════════")
print("✅ MAP BYGGET!")
print("  - 600x600 studs arena")
print("  - 8 bygninger med vægge + tag + vinduer")
print("  - 12 træer + 6 sten (cover)")
print("  - " .. #lootSpawnPositions .. " LootSpawn punkter (gule plader)")
print("  - LobbySpawn i (0,0,0)")
print("  - Lighting konfigureret")
print("")
print("TIP: De gule neon-plader er LootSpawn-punkter.")
print("     LootSpawner tagget dem med 'LootSpawn'.")
print("     Slet 'SetupUI_RUNONCE', 'SetupStarterPack_RUNONCE'")
print("     og 'MapBuilder_RUNONCE' scripts efter brug.")
print("══════════════════════════════════════")
```

---

## RÆKKEFØLGE — KØR I DENNE ORDEN

```
1. Indsæt Script 1 i ServerScriptService → navn: "SetupUI_RUNONCE"
   Tryk Play → tjek Output for "✅ BattleRoyaleHUD OPRETTET!" → Stop

2. Indsæt Script 2 i ServerScriptService → navn: "SetupStarterPack_RUNONCE"
   Tryk Play → tjek Output → Stop

3. Indsæt Script 3 i ServerScriptService → navn: "MapBuilder_RUNONCE"
   Tryk Play → tjek Output → Stop

4. Slet alle tre "RUNONCE" scripts

5. Tryk Play igen — nu med det rigtige GameManager osv.
   Forventet Output:
   [DataManager] Klar
   [RemoteHandler] Klar
   [WeaponServer] Klar
   [SpectatorSystem] Klar
   [GameManager] Alle systemer kørende!
   [MatchManager] Fase: Lobby
   [MatchManager] Fase: Waiting
   [LootSpawner] Spawnet 32 tools ved 32 punkter  ← når match starter
```

---

## OPDATERET HUDController

Din eksisterende HUDController skal opdateres til at matche de nye UI-navne.
Erstat dit eksisterende HUDController-script med dette:

```lua
--!strict
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local player  = Players.LocalPlayer
local remotes = ReplicatedStorage:WaitForChild("Remotes")

-- Vent på PlayerGui
local hud = player:WaitForChild("PlayerGui"):WaitForChild("BattleRoyaleHUD")

-- UI referencer
local aliveLabel       = hud:FindFirstChild("AliveFrame") and hud.AliveFrame:FindFirstChild("AliveLabel")
local countdownLabel   = hud:FindFirstChild("CountdownFrame") and hud.CountdownFrame:FindFirstChild("CountdownLabel")
local phaseLabel       = hud:FindFirstChild("CountdownFrame") and hud.CountdownFrame:FindFirstChild("PhaseLabel")
local killFeedFrame    = hud:FindFirstChild("KillFeedFrame")
local zoneTimerLabel   = hud:FindFirstChild("ZoneTimerFrame") and hud.ZoneTimerFrame:FindFirstChild("ZoneTimerLabel")
local spectatorHUD     = hud:FindFirstChild("SpectatorHUD")
local spectatorLabel   = spectatorHUD and spectatorHUD:FindFirstChild("SpectatingBanner") and spectatorHUD.SpectatingBanner:FindFirstChild("SpectatorLabel")
local cycleHint        = spectatorHUD and spectatorHUD:FindFirstChild("SpectatingBanner") and spectatorHUD.SpectatingBanner:FindFirstChild("CycleHint")
local placementLabel   = spectatorHUD and spectatorHUD:FindFirstChild("PlacementLabel")
local victoryScreen    = hud:FindFirstChild("VictoryScreen")
local victoryLabel     = victoryScreen and victoryScreen:FindFirstChild("VictoryLabel")
local victorySubLabel  = victoryScreen and victoryScreen:FindFirstChild("VictorySubLabel")
local eliminatedScreen = hud:FindFirstChild("EliminatedScreen")
local eliminatedSubLabel = eliminatedScreen and eliminatedScreen:FindFirstChild("EliminatedSubLabel")
local minimapFrame     = hud:FindFirstChild("MinimapFrame")
local zoneCircle       = minimapFrame and minimapFrame:FindFirstChild("ZoneCircle")
local targetZoneCircle = minimapFrame and minimapFrame:FindFirstChild("TargetZoneCircle")
local playerDot        = minimapFrame and minimapFrame:FindFirstChild("PlayerDot")
local hitMarker        = hud:FindFirstChild("HitMarker")

-- Minimap indstillinger
local MAP_RADIUS   = 300   -- halv-bredde af dit map (studs)
local MINIMAP_PX   = 210   -- pixels (samme som MinimapFrame størrelse)

local function worldToMinimap(wx, wz)
	local scale = (MINIMAP_PX / 2) / MAP_RADIUS
	return wx * scale + MINIMAP_PX / 2, wz * scale + MINIMAP_PX / 2
end

local function updateZoneUI(frame, cx, cz, radius)
	if not frame then return end
	local px, py = worldToMinimap(cx, cz)
	local scale  = (MINIMAP_PX / 2) / MAP_RADIUS
	local pr     = radius * scale
	frame.Size     = UDim2.fromOffset(pr*2, pr*2)
	frame.Position = UDim2.fromOffset(px-pr, py-pr)
end

-- ═══════════════════════════════════════
-- MATCH STATE
-- ═══════════════════════════════════════
local matchStateRemote = remotes:WaitForChild("MatchState")
matchStateRemote.OnClientEvent:Connect(function(phase, extra)
	if phase == "Lobby" then
		if countdownLabel then countdownLabel.Text = "⏳ Næste kamp starter snart..." end
		if phaseLabel then phaseLabel.Text = "" end
		if victoryScreen then victoryScreen.Visible = false end
		if eliminatedScreen then eliminatedScreen.Visible = false end
		if spectatorHUD then spectatorHUD.Visible = false end

	elseif phase == "Waiting" then
		if countdownLabel then countdownLabel.Text = "Venter på spillere..." end
		if phaseLabel then phaseLabel.Text = "Minimum 2 spillere" end

	elseif phase == "Countdown" then
		if countdownLabel then
			countdownLabel.Text = tostring(extra) .. "..."
			countdownLabel.TextColor3 = (tonumber(extra) or 0) <= 3
				and Color3.fromRGB(255,80,80)
				or  Color3.fromRGB(255,220,80)
		end
		if phaseLabel then phaseLabel.Text = "Match starter!" end

	elseif phase == "InProgress" then
		if countdownLabel then
			countdownLabel.Text = "⚔ KAMP I GANG"
			countdownLabel.TextColor3 = Color3.fromRGB(100,255,100)
		end
		if phaseLabel then phaseLabel.Text = "" end

	elseif phase == "Victory" then
		local winnerName = extra
		if winnerName then
			-- Tjek om vi er vinderen
			if winnerName == player.Name then
				if victoryScreen then victoryScreen.Visible = true end
				if victoryLabel then victoryLabel.Text = "🏆 VICTORY ROYALE!" end
				if victorySubLabel then victorySubLabel.Text = "Tillykke, " .. player.Name .. "!" end
			else
				if countdownLabel then
					countdownLabel.Text = "🏆 " .. winnerName .. " vandt!"
					countdownLabel.TextColor3 = Color3.fromRGB(255,220,0)
				end
			end
		else
			if countdownLabel then countdownLabel.Text = "Ingen vinder" end
		end

	elseif phase == "Cleanup" then
		if victoryScreen then victoryScreen.Visible = false end
		if eliminatedScreen then eliminatedScreen.Visible = false end
		if spectatorHUD then spectatorHUD.Visible = false end
		if countdownLabel then
			countdownLabel.Text = "Kamp slut — nulstiller..."
			countdownLabel.TextColor3 = Color3.fromRGB(200,200,200)
		end
	end
end)

-- ═══════════════════════════════════════
-- KILL FEED
-- ═══════════════════════════════════════
local killFeedRemote = remotes:WaitForChild("KillFeed")
local killMessages = {}
local MAX_KILL_MSGS = 6

killFeedRemote.OnClientEvent:Connect(function(killer, victim, placement)
	if not killFeedFrame then return end

	-- Er det os der blev elimineret?
	if victim == player.Name then
		if eliminatedScreen then eliminatedScreen.Visible = true end
		if eliminatedSubLabel then
			eliminatedSubLabel.Text = "Elimineret af: " .. killer .. "\nPlacering: #" .. placement
		end
		if placementLabel then placementLabel.Text = "Du blev #" .. placement end
		task.delay(2.5, function()
			if eliminatedScreen then eliminatedScreen.Visible = false end
		end)
	end

	-- Opdatér alive-tæller
	if aliveLabel then
		aliveLabel.Text = placement - 1 .. " tilbage"
	end

	-- Kill feed entry
	local emoji = (killer == "Zonen") and "⚡" or "💀"
	local msg = emoji .. " " .. killer .. " → " .. victim .. "  #" .. placement
	table.insert(killMessages, 1, msg)
	if #killMessages > MAX_KILL_MSGS then
		table.remove(killMessages)
	end

	-- Ryd og genbygf labels
	for _, child in killFeedFrame:GetChildren() do
		if child:IsA("TextLabel") then child:Destroy() end
	end
	for i, text in killMessages do
		local lbl = Instance.new("TextLabel")
		lbl.LayoutOrder = i
		lbl.Size = UDim2.new(1,0,0,22)
		lbl.BackgroundColor3 = Color3.fromRGB(0,0,0)
		lbl.BackgroundTransparency = 0.5
		lbl.TextColor3 = (text:find("⚡")) and Color3.fromRGB(100,180,255) or Color3.new(1,1,1)
		lbl.TextStrokeTransparency = 0.6
		lbl.TextXAlignment = Enum.TextXAlignment.Left
		lbl.Font = Enum.Font.GothamBold
		lbl.TextSize = 13
		lbl.Text = "  " .. text
		lbl.Parent = killFeedFrame

		local corner = Instance.new("UICorner")
		corner.CornerRadius = UDim.new(0,4)
		corner.Parent = lbl

		-- Fade ud efter 8 sekunder
		task.delay(8, function()
			if lbl and lbl.Parent then lbl:Destroy() end
		end)
	end
end)

-- ═══════════════════════════════════════
-- HIT EFFECT (fra WeaponServer)
-- ═══════════════════════════════════════
local hitEffectRemote = remotes:WaitForChild("HitEffect")
hitEffectRemote.OnClientEvent:Connect(function(hitPos, damage)
	if hitMarker then
		hitMarker.BackgroundTransparency = 0
		task.delay(0.12, function()
			if hitMarker then hitMarker.BackgroundTransparency = 1 end
		end)
	end
end)

-- ═══════════════════════════════════════
-- ZONE UPDATE (minimap)
-- ═══════════════════════════════════════
local zoneRemote = remotes:WaitForChild("ZoneUpdate")
zoneRemote.OnClientEvent:Connect(function(curCX, curCZ, curR, tgtCX, tgtCZ, tgtR, isShrinking)
	updateZoneUI(zoneCircle, curCX, curCZ, curR)
	updateZoneUI(targetZoneCircle, tgtCX, tgtCZ, tgtR)

	if targetZoneCircle then
		targetZoneCircle.Visible = (tgtR < curR - 5)
	end
	if zoneCircle then
		zoneCircle.BackgroundColor3 = isShrinking
			and Color3.fromRGB(255,80,80)
			or  Color3.fromRGB(60,140,255)
	end
	if zoneTimerLabel then
		zoneTimerLabel.Text = isShrinking
			and "⚡ Zone krymper!"
			or  "Zone stabil · Næste fase kommer"
		zoneTimerLabel.TextColor3 = isShrinking
			and Color3.fromRGB(255,120,120)
			or  Color3.fromRGB(150,200,255)
	end
end)

-- ═══════════════════════════════════════
-- PLAYER DOT PÅ MINIMAP (hver frame)
-- ═══════════════════════════════════════
RunService.RenderStepped:Connect(function()
	if not playerDot then return end
	local char = player.Character
	if not char then return end
	local root = char:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not root then return end
	local px, py = worldToMinimap(root.Position.X, root.Position.Z)
	-- Clamp inden for minimap
	px = math.clamp(px - 5, 0, MINIMAP_PX - 10)
	py = math.clamp(py - 5, 0, MINIMAP_PX - 10)
	playerDot.Position = UDim2.fromOffset(px, py)
end)

print("[HUDController] Klar")
```

---

## KOMPLET OVERSIGT — HVAD DU HAR NÅ

```
✅ SERVER
  GameManager          – bootstrapper
  DataManager          – Wins/Kills persistence
  RemoteHandler        – rate limiting
  MatchManager         – Lobby→Waiting→Countdown→InProgress→Victory→Cleanup
  StormSystem          – shrinking zone med damage
  LootSpawner          – Tools med rarity, ProximityPrompt pickup
  EliminationTracker   – kill feed, drop inventory
  SpectatorSystem      – Q/E cycling, target tracking
  WeaponServer         – server-side hit validering

✅ CLIENT
  HUDController        – minimap, kill feed, ammo, zone timer, screens
  SpectatorController  – kamera follow, cycle knapper
  ClientController     – data indlæsning
  WeaponTool           – raycast skydning, ammo tæller, auto-reload

✅ UI (StarterGui)
  BattleRoyaleHUD
    MinimapFrame       – live zone + spiller-dot
    AliveFrame         – antal levende spillere
    CountdownFrame     – match info
    KillFeedFrame      – kill feed med farvekodning
    AmmoFrame          – magasin / total ammo
    HitMarker          – rød prik ved hits
    Crosshair          – sigtekorn
    SpectatorHUD       – spectator view med Q/E hint
    VictoryScreen      – "VICTORY ROYALE!"
    EliminatedScreen   – "ELIMINATED" med placering
    ZoneTimerFrame     – zone status

✅ INDHOLD
  StarterPack          – Pistol_Common (12 skud, 4 magasiner)
  Map                  – 600x600 arena, 8 bygninger, 12 træer, 6 sten
  LootSpawns           – 32 spawn-points tagget med "LootSpawn"
  LobbySpawn           – i centrum
```
