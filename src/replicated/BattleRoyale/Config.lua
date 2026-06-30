local Config = {
	MIN_PLAYERS = 2,
	MAX_PLAYERS = 50,

	LOBBY_INTERMISSION = 8,
	COUNTDOWN_DURATION = 10,
	DEPLOY_DURATION = 3,
	VICTORY_SCREEN_DURATION = 6,
	CLEANUP_DURATION = 4,

	ZONE_INITIAL_RADIUS = 400,
	ZONE_DAMAGE_PER_TICK = 5,
	ZONE_TICK_INTERVAL = 1,
	ZONE_PHASES = {
		{ waitTime = 35, shrinkTime = 25, radiusFraction = 0.65 },
		{ waitTime = 25, shrinkTime = 20, radiusFraction = 0.4 },
		{ waitTime = 20, shrinkTime = 15, radiusFraction = 0.18 },
		{ waitTime = 15, shrinkTime = 12, radiusFraction = 0.06 },
	},

	LOOT_SPAWN_TAG = "LootSpawn",
	LOOT_RESPAWN_INTERVAL = 45,
	RARITY_WEIGHTS = {
		Common = 40,
		Uncommon = 30,
		Rare = 18,
		Epic = 9,
		Legendary = 3,
	},

	ARENA_CENTER = Vector3.new(0, 6, 0),
	ARENA_RADIUS = 360,
	DEPLOY_HEIGHT = 8,
}

return Config
