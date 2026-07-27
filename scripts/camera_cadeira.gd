extends Camera3D

# ─────────────────────────────────────────────
#  CÂMERA LIVRE — SEM LIMITES (modo debug)
#  Olha pra todos os lados para inspecionar a cena.
#  Por padrão a câmera olha pro Norte (Z-) sem rotação base.
# ─────────────────────────────────────────────

@export var sensibilidade: float = 0.002

var _rot_x: float = 0.0
var _rot_y: float = 0.0


func _ready() -> void:
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)


func _input(event: InputEvent) -> void:
	if not event is InputEventMouseMotion:
		return

	var delta_mouse: Vector2 = event.relative

	_rot_y -= delta_mouse.x * sensibilidade
	_rot_x -= delta_mouse.y * sensibilidade
	_rot_x = clamp(_rot_x, -deg_to_rad(89.0), deg_to_rad(89.0))

	rotation = Vector3(_rot_x, _rot_y, 0.0)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		if Input.get_mouse_mode() == Input.MOUSE_MODE_CAPTURED:
			Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
		else:
			Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
