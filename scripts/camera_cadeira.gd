extends Camera3D
class_name CameraCadeira

# ─────────────────────────────────────────────
#  CÂMERA — a visão em 1ª pessoa da garotinha, do começo ao fim
#
#  Olha pra todos os lados (mouse). A posição não é livre: é a cabeça da
#  garotinha enquanto ela anda, e o assento da cadeira depois que ela senta.
#
#  ⚠️ Isto mudou em 06/08/2026. Antes o jogo abria numa `CameraCutscene` em 3ª
#  pessoa enquadrando parede+porta+cadeira, e a garotinha era um corpo que o
#  jogador via entrar pela porta. O pedido foi o contrário: o jogador **é** ela
#  desde o primeiro quadro, começa no cômodo vizinho e entra no quarto que está
#  sendo pintado, com o tio ainda terminando a última parede.
#
#  A mistura entre os dois modos é `_seguindo`: 1 = cabeça dela, 0 = pousada na
#  cadeira. `assentar()` interpola — é o que faz sentar não ser corte de câmera.
#
#  ESC/pausa é responsabilidade só do menu_pausa.gd.
# ─────────────────────────────────────────────

@export var sensibilidade: float = 0.002

## Quanto a cabeça sobe e desce a cada passo. Pequeno de propósito: balanço de
## câmera em 1ª pessoa enjoa rápido, e este é um jogo pra ficar olhando parado.
const BALANCO_PASSO: float = 0.012

## Quão rápido a câmera persegue a cabeça dela. Sem filtro, o passo do clipe
## entra inteiro na lente.
const SUAVIZACAO: float = 9.0

var _rot_x: float = 0.0
var _rot_y: float = 0.0

## Onde a câmera repousa quando ela senta: a transform que o nó tem na cena.
## Guardada no `_ready` porque daí em diante o nó é movido a cada quadro.
var _pouso: Transform3D

var _alvo: Node3D
var _altura_olhos: float = 1.15
var _seguindo: float = 0.0
var _posicao_suave: Vector3 = Vector3.ZERO
var _tem_suave: bool = false


func _ready() -> void:
	_pouso = transform


## Cola a câmera na cabeça de quem está andando. Chamar ANTES de `ativar()`.
func seguir(quem: Node3D, altura_olhos: float) -> void:
	_alvo = quem
	_altura_olhos = altura_olhos
	_seguindo = 1.0
	_tem_suave = false


func ativar() -> void:
	current = true
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)


## Desce da cabeça dela pro assento. `duracao` tem que cobrir o gesto de sentar,
## senão a câmera chega antes do corpo.
func assentar(duracao: float = 1.1) -> void:
	var tw := create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tw.tween_property(self, "_seguindo", 0.0, duracao)
	await tw.finished
	_alvo = null


func _process(delta: float) -> void:
	var alvo: Vector3 = _pouso.origin
	# Pra onde a lente aponta quando o mouse está parado. Sentada é o norte (a
	# parede que ela veio ver secar); andando é pra onde o corpo dela vai — sem
	# isto ela sai do cômodo vizinho olhando pra parede em vez de pra porta.
	var base_y: float = 0.0

	if _alvo != null and _seguindo > 0.0:
		var cabeca: Vector3 = _alvo.global_position + Vector3.UP * _altura_olhos
		cabeca.y += sin(float(Time.get_ticks_msec()) * 0.006) * BALANCO_PASSO
		if not _tem_suave:
			_posicao_suave = cabeca
			_tem_suave = true
		_posicao_suave = _posicao_suave.lerp(cabeca, clampf(delta * SUAVIZACAO, 0.0, 1.0))
		alvo = _pouso.origin.lerp(_posicao_suave, _seguindo)
		base_y = lerp_angle(0.0, _alvo.global_rotation.y, _seguindo)

	position = alvo
	rotation = Vector3(_rot_x, base_y + _rot_y, 0.0)


func _input(event: InputEvent) -> void:
	if not current:
		return
	if not event is InputEventMouseMotion:
		return

	var delta_mouse: Vector2 = event.relative

	_rot_y -= delta_mouse.x * sensibilidade
	_rot_x -= delta_mouse.y * sensibilidade
	_rot_x = clamp(_rot_x, -deg_to_rad(89.0), deg_to_rad(89.0))
