extends Camera3D
class_name CameraCadeira

# ─────────────────────────────────────────────
#  CÂMERA DA CADEIRA — visão em 1ª pessoa da garotinha
#  Olha pra todos os lados (mouse), sem movimento de posição.
#  Por padrão a câmera olha pro Norte (Z-) sem rotação base.
#
#  Só fica ativa depois que a garotinha senta (ver ciclo_pintura.gd) — antes
#  disso quem está com o foco é a CameraCutscene. Por isso não captura o
#  mouse nem processa rotação sozinha em _ready(); espera ativar() ser chamado.
#
#  ESC/pausa é responsabilidade só do menu_pausa.gd agora (era daqui antes).
# ─────────────────────────────────────────────

@export var sensibilidade: float = 0.002

var _rot_x: float = 0.0
var _rot_y: float = 0.0


func ativar() -> void:
	current = true
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)


func _input(event: InputEvent) -> void:
	if not current:
		return
	if not event is InputEventMouseMotion:
		return

	var delta_mouse: Vector2 = event.relative

	_rot_y -= delta_mouse.x * sensibilidade
	_rot_x -= delta_mouse.y * sensibilidade
	_rot_x = clamp(_rot_x, -deg_to_rad(89.0), deg_to_rad(89.0))

	rotation = Vector3(_rot_x, _rot_y, 0.0)
