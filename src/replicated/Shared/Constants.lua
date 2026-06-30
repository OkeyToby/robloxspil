local Constants = {
	SAVE_INTERVAL = 300,
	DATA_STORE_NAME = "BattleRoyale_v1",
	MAX_REMOTE_RATE = 20,
	REMOTE_WINDOW = 10,
	REMOTE_KICK_THRESHOLD = 5,

	Remotes = {
		PlayerDataLoaded = "PlayerDataLoaded",
		UpdateUI = "UpdateUI",
		MatchState = "MatchState",
		KillFeed = "KillFeed",
		ZoneUpdate = "ZoneUpdate",
		ShootRequest = "ShootRequest",
		HitEffect = "HitEffect",
		SpectatorTarget = "SpectatorTarget",
		SpectatorCycle = "SpectatorCycle",
	},
}

return Constants
