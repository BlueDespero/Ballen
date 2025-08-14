extends Control


# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	# Set random color for the first ball
	var color : String = Constants.colors.keys().pick_random()
	$Ball/BallSprite.SetBallColor(color)
