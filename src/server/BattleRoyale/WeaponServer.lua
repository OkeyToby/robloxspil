local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Constants = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Constants"))
local WeaponDefs = require(ReplicatedStorage:WaitForChild("BattleRoyale"):WaitForChild("WeaponDefs"))

local WeaponServer = {}
local matchManager = nil
local lastShotByPlayer = {}

function WeaponServer.setMatchManager(manager)
	matchManager = manager
end

local function getCharacterParts(player)
	local character = player.Character
	if not character then
		return nil, nil, nil
	end

	return character, character:FindFirstChildOfClass("Humanoid"), character:FindFirstChild("HumanoidRootPart")
end

local function hasEquippedWeapon(player, weaponName)
	local character = player.Character
	if not character then
		return false
	end

	local tool = character:FindFirstChildOfClass("Tool")
	return tool and tool.Name == weaponName
end

function WeaponServer.handleShot(shooter, targetPlayer, hitPosition, weaponName)
	if typeof(targetPlayer) ~= "Instance" or not targetPlayer:IsA("Player") then
		return
	end

	if typeof(hitPosition) ~= "Vector3" or type(weaponName) ~= "string" then
		return
	end

	local def = WeaponDefs[weaponName]
	if not def then
		return
	end

	if not shooter:GetAttribute("BRAlive") or not targetPlayer:GetAttribute("BRAlive") then
		return
	end

	if shooter == targetPlayer then
		return
	end

	if not hasEquippedWeapon(shooter, weaponName) then
		return
	end

	local _, shooterHumanoid, shooterRoot = getCharacterParts(shooter)
	local _, targetHumanoid, targetRoot = getCharacterParts(targetPlayer)
	if not shooterHumanoid or not shooterRoot or shooterHumanoid.Health <= 0 then
		return
	end
	if not targetHumanoid or not targetRoot or targetHumanoid.Health <= 0 then
		return
	end

	local key = shooter.UserId .. ":" .. weaponName
	local now = os.clock()
	if lastShotByPlayer[key] and now - lastShotByPlayer[key] < math.max((def.fireRate or 0.3) * 0.75, 0.05) then
		return
	end
	lastShotByPlayer[key] = now

	local maxRange = def.range or 300
	if (targetRoot.Position - shooterRoot.Position).Magnitude > maxRange + 12 then
		return
	end

	if (hitPosition - targetRoot.Position).Magnitude > 18 then
		return
	end

	local damage = def.damage or 10
	local hitEffect = ReplicatedStorage:WaitForChild("Remotes"):WaitForChild(Constants.Remotes.HitEffect)
	hitEffect:FireAllClients(hitPosition, damage)

	if targetHumanoid.Health <= damage then
		if matchManager then
			matchManager:EliminatePlayer(targetPlayer, shooter)
		end
		targetHumanoid.Health = 0
	else
		targetHumanoid:TakeDamage(damage)
	end
end

function WeaponServer.init()
	local remotes = ReplicatedStorage:WaitForChild("Remotes")
	local shootRemote = remotes:WaitForChild(Constants.Remotes.ShootRequest)
	shootRemote.OnServerEvent:Connect(WeaponServer.handleShot)

	Players.PlayerRemoving:Connect(function(player)
		for key in pairs(lastShotByPlayer) do
			if string.find(key, tostring(player.UserId) .. ":", 1, true) == 1 then
				lastShotByPlayer[key] = nil
			end
		end
	end)
end

return WeaponServer
