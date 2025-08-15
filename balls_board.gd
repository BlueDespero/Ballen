extends TileMapLayer

func GetOpponentBallSpawnLocation() -> Vector2i:
	return to_global(map_to_local(Vector2i(0,0)))

func GetPlayerBallSpawnLocation() -> Vector2i:
	return to_global(map_to_local(Vector2i(0,10)))
