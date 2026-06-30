local WeaponDefs = {
	Pistol = {
		displayName = "Pistol",
		rarity = "Common",
		damage = 18,
		fireRate = 0.35,
		range = 260,
		magSize = 12,
		reloadTime = 1.2,
		color = Color3.fromRGB(180, 190, 205),
	},

	SMG = {
		displayName = "SMG",
		rarity = "Uncommon",
		damage = 12,
		fireRate = 0.12,
		range = 210,
		magSize = 28,
		reloadTime = 1.5,
		color = Color3.fromRGB(60, 190, 110),
	},

	Rifle = {
		displayName = "Rifle",
		rarity = "Rare",
		damage = 24,
		fireRate = 0.24,
		range = 360,
		magSize = 24,
		reloadTime = 1.8,
		color = Color3.fromRGB(55, 140, 255),
	},

	Shotgun = {
		displayName = "Shotgun",
		rarity = "Epic",
		damage = 42,
		fireRate = 0.85,
		range = 120,
		magSize = 6,
		reloadTime = 2,
		color = Color3.fromRGB(170, 95, 255),
	},

	Sniper = {
		displayName = "Sniper",
		rarity = "Legendary",
		damage = 80,
		fireRate = 1.2,
		range = 650,
		magSize = 5,
		reloadTime = 2.4,
		color = Color3.fromRGB(255, 190, 65),
	},
}

return WeaponDefs
