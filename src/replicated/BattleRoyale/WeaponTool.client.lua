local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Debris = game:GetService("Debris")

local player = Players.LocalPlayer
local mouse = player:GetMouse()
local tool = script.Parent
local remotes = ReplicatedStorage:WaitForChild("Remotes")
local shootRemote = remotes:WaitForChild("ShootRequest")
local weaponDefs = require(ReplicatedStorage:WaitForChild("BattleRoyale"):WaitForChild("WeaponDefs"))

local weaponName = tool.Name
local def = weaponDefs[weaponName] or {}
local magSize = tool:GetAttribute("MagSize") or def.magSize or 10
local totalAmmo = magSize * 3
local currentAmmo = magSize
local lastShot = 0
local reloading = false

local function getAmmoLabel()
	local playerGui = player:FindFirstChildOfClass("PlayerGui")
	if not playerGui then
		return nil
	end

	local hud = playerGui:FindFirstChild("BattleRoyaleHUD")
	if not hud then
		return nil
	end

	return hud:FindFirstChild("AmmoLabel")
end

local function updateAmmoLabel()
	local label = getAmmoLabel()
	if label and label:IsA("TextLabel") then
		label.Text = string.format("%d / %d", currentAmmo, totalAmmo)
		label.TextColor3 = currentAmmo <= 5 and Color3.fromRGB(255, 90, 90) or Color3.fromRGB(255, 255, 255)
	end
end

local function drawTracer(fromPos, toPos)
	local distance = (toPos - fromPos).Magnitude
	if distance <= 0 then
		return
	end

	local tracer = Instance.new("Part")
	tracer.Name = "LocalBulletTracer"
	tracer.Anchored = true
	tracer.CanCollide = false
	tracer.Material = Enum.Material.Neon
	tracer.Color = Color3.fromRGB(255, 235, 140)
	tracer.Size = Vector3.new(0.08, 0.08, distance)
	tracer.CFrame = CFrame.lookAt(fromPos, toPos) * CFrame.new(0, 0, -distance / 2)
	tracer.Parent = workspace
	Debris:AddItem(tracer, 0.08)
end

local function findTargetPlayer(hit)
	if not hit then
		return nil
	end

	local model = hit:FindFirstAncestorOfClass("Model")
	if not model then
		return nil
	end

	local humanoid = model:FindFirstChildOfClass("Humanoid")
	if not humanoid then
		return nil
	end

	return Players:GetPlayerFromCharacter(model)
end

local function reload()
	if reloading or currentAmmo >= magSize or totalAmmo <= 0 then
		return
	end

	reloading = true
	local label = getAmmoLabel()
	if label and label:IsA("TextLabel") then
		label.Text = "Reloading"
		label.TextColor3 = Color3.fromRGB(255, 220, 140)
	end

	task.wait(tool:GetAttribute("ReloadTime") or def.reloadTime or 1.5)

	local needed = magSize - currentAmmo
	local refill = math.min(needed, totalAmmo)
	currentAmmo += refill
	totalAmmo -= refill
	reloading = false
	updateAmmoLabel()
end

local function shoot()
	if reloading then
		return
	end

	if currentAmmo <= 0 then
		reload()
		return
	end

	local now = os.clock()
	local fireRate = tool:GetAttribute("FireRate") or def.fireRate or 0.3
	if now - lastShot < fireRate then
		return
	end
	lastShot = now
	currentAmmo -= 1
	updateAmmoLabel()

	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	local hitPosition = mouse.Hit and mouse.Hit.Position
	if not root or not hitPosition then
		return
	end

	drawTracer(root.Position + Vector3.new(0, 1.5, 0), hitPosition)

	local targetPlayer = findTargetPlayer(mouse.Target)
	if targetPlayer then
		shootRemote:FireServer(targetPlayer, hitPosition, weaponName)
	end

	if currentAmmo <= 0 and totalAmmo > 0 then
		task.defer(reload)
	end
end

tool.Equipped:Connect(updateAmmoLabel)
tool.Activated:Connect(shoot)

updateAmmoLabel()
