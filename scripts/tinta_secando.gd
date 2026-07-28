extends MeshInstance3D
class_name TintaSecando

# ─────────────────────────────────────────────
#  TINTA SECANDO NA PAREDE
#
#  A demão não cai de uma vez: uma frente de pintura varre a parede no
#  sentido em que o tio anda (ver ciclo_pintura.gd), e cada ponto começa a
#  secar quando a frente passa por ele. Quem faz esse desenho é o shader —
#  aqui só corre o relógio (`_tempo_decorrido`) e se avisa quando o último
#  ponto da parede terminou de secar.
#
#  Usa call_deferred pra garantir que o mesh já foi criado
#  pelo inicializar_quarto.gd antes de aplicar o material.
# ─────────────────────────────────────────────

@export var tempo_secagem_segundos: float = 600.0

## Quanto a onda de secagem arrasta no sentido da pintura. Espelha o uniform
## `atraso_direcional_secagem` do shader — os dois PRECISAM bater, senão a
## parede é dada como pronta antes da ponta esquerda terminar de secar.
const ATRASO_DIRECIONAL: float = 0.6

signal secagem_concluida

var _tempo_decorrido: float = 0.0
var _duracao_varredura: float = 1.0
var _material: ShaderMaterial
var _avisou_conclusao: bool = false
var _ativo: bool = false


func _ready() -> void:
	# Autoconfigura a partir do modo de jogo ativo — o valor no .tscn é só um
	# default de Inspector, não é mais autoridade (ver estado_jogo.gd)
	tempo_secagem_segundos = EstadoJogo.tempo_secagem_atual()

	call_deferred("_setup")


func _setup() -> void:
	_material = ShaderMaterial.new()
	_material.shader = load("res://shaders/tinta_secando.gdshader")
	set_surface_override_material(0, _material)
	_material.set_shader_parameter("duracao_secagem", tempo_secagem_segundos)
	_material.set_shader_parameter("tempo_decorrido", 0.0)


func _process(delta: float) -> void:
	if not _ativo:
		return

	_tempo_decorrido += delta
	if _material:
		_material.set_shader_parameter("tempo_decorrido", _tempo_decorrido)

	if not _avisou_conclusao and _tempo_decorrido >= _duracao_total():
		_avisou_conclusao = true
		_ativo = false
		secagem_concluida.emit()


## Tempo até a parede inteira estar seca. O ponto mais tardio é a ponta final
## da varredura: espera a frente chegar lá, mais o atraso direcional, mais a
## secagem dele.
func _duracao_total() -> float:
	return _duracao_varredura + tempo_secagem_segundos * (1.0 + ATRASO_DIRECIONAL)


## Começa uma demão nova. `eixo`/`inicio`/`fim` descrevem por onde a frente de
## pintura anda, em espaço de mundo (projeção da posição no eixo).
func iniciar_demao(
	anterior: Color,
	molhada: Color,
	seca: Color,
	eixo: Vector3,
	inicio: float,
	fim: float,
	duracao_varredura: float
) -> void:
	_duracao_varredura = maxf(duracao_varredura, 0.01)
	_tempo_decorrido   = 0.0
	_avisou_conclusao  = false
	_ativo             = true
	call_deferred("_aplicar_demao", anterior, molhada, seca, eixo, inicio, fim)


func _aplicar_demao(anterior: Color, molhada: Color, seca: Color, eixo: Vector3, inicio: float, fim: float) -> void:
	if not _material:
		return
	_material.set_shader_parameter("cor_anterior",      anterior)
	_material.set_shader_parameter("cor_molhada",       molhada)
	_material.set_shader_parameter("cor_seca",          seca)
	_material.set_shader_parameter("eixo_varredura",    eixo)
	_material.set_shader_parameter("inicio_varredura",  inicio)
	_material.set_shader_parameter("fim_varredura",     fim)
	_material.set_shader_parameter("duracao_varredura", _duracao_varredura)
	_material.set_shader_parameter("duracao_secagem",   tempo_secagem_segundos)
	_material.set_shader_parameter("tempo_decorrido",   _tempo_decorrido)
	_material.set_shader_parameter("atraso_direcional_secagem", ATRASO_DIRECIONAL)


## Pula o relógio pra frente. Usado na abertura pra deixar as paredes que o
## tio já pintou antes do jogador chegar em estágios diferentes de secagem.
func adiantar(segundos: float) -> void:
	_tempo_decorrido += segundos
	if _material:
		_material.set_shader_parameter("tempo_decorrido", _tempo_decorrido)


## Mostra a parede totalmente seca na hora — usado ao retomar de um save
## (ciclo_pintura.gd::_retomar_de_save), não durante o jogo normal.
func forcar_seco() -> void:
	call_deferred("_aplicar_seco_deferido")


func _aplicar_seco_deferido() -> void:
	_tempo_decorrido  = _duracao_total()
	_avisou_conclusao = true
	_ativo            = false
	if _material:
		_material.set_shader_parameter("tempo_decorrido", _tempo_decorrido)


func get_fracao_seca() -> float:
	return clampf(_tempo_decorrido / _duracao_total(), 0.0, 1.0)
