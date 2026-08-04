extends Camera3D

# ─────────────────────────────────────────────
#  CÂMERA ORBITAL DO FUNDO DO MENU
#
#  Gira devagar em torno do centro do quarto, olhando sempre pro mesmo
#  ponto. Só decoração — nada aqui reage a input nem a estado de jogo.
# ─────────────────────────────────────────────

@export var centro: Vector3 = Vector3(0.0, 1.4, -1.0)
@export var raio: float = 2.3  ## quarto tem ~3.4/~3 de meia-largura/profundidade — margem das paredes
@export var altura: float = 2.0
@export var graus_por_segundo: float = 2.5  ## bem devagar — 144s pra dar a volta

var _angulo: float = 0.0


func _ready() -> void:
	_angulo = 0.0


func _process(delta: float) -> void:
	_angulo = wrapf(_angulo + deg_to_rad(graus_por_segundo) * delta, 0.0, TAU)
	position = Vector3(centro.x + sin(_angulo) * raio, altura, centro.z + cos(_angulo) * raio)
	look_at(centro, Vector3.UP)
