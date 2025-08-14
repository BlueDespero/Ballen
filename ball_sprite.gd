extends Sprite2D

func SetBallColor(color: String)-> void:
	self.modulate = Constants.colors[color]["rgb"]
