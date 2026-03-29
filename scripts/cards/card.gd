extends Node2D

signal card_event(card: Node2D, event: CardTypes.CardEvent)

## Preload the card hover shader so every card instance shares the same compiled shader
var _shader: Shader = preload("res://assets/shaders/card_hover.gdshader")

## Reference to the Sprite2D child that displays the card art
@onready var card_image: Sprite2D = $CardImage


func _ready() -> void:
	# Create a unique ShaderMaterial for this card so each card's hovering param is independent
	var mat := ShaderMaterial.new()
	mat.shader = _shader
	# Give each card a unique random seed so idle wobble animations don't sync up
	mat.set_shader_parameter("rand_seed", randf() * 1000.0)
	card_image.material = mat
	# Register this card's signals with the CardManager
	get_parent().connect_card_signals(self)


## Enable or disable the shader's hover-reactive tilt effect
func set_hover_shader(enabled: bool) -> void:
	var mat: ShaderMaterial = card_image.material
	if mat:
		mat.set_shader_parameter("hovering", 1.0 if enabled else 0.0)


func _on_area_2d_mouse_entered() -> void:
	card_event.emit(self, CardTypes.CardEvent.HOVER_ON)


func _on_area_2d_mouse_exited() -> void:
	card_event.emit(self, CardTypes.CardEvent.HOVER_OFF)
