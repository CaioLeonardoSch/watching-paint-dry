extends DirectionalLight3D

# ─────────────────────────────────────────────
#  AMBIENTE DE DIA — luz fixa, sem ciclo
#
#  Substitui o antigo ciclo_dia_noite.gd. O ciclo girava sol e lua e
#  interpolava cor de luz, céu, ambiente e névoa ao longo do dia; na prática
#  atrapalhava mais do que ajudava, porque o jogo é de observar uma parede
#  secar devagar e a luz mudando por baixo competia com a única coisa que
#  deveria estar mudando. Amanhecer e entardecer eram os piores: tingiam o
#  quarto inteiro de laranja bem no meio da observação.
#
#  Agora é sempre meio da tarde: sol alto o bastante pra ser dia claro, com
#  inclinação suficiente pra entrar pela janela e desenhar sombra legível.
#  Configura tudo uma vez em _ready() e não roda _process — nada aqui muda
#  depois, de propósito.
# ─────────────────────────────────────────────

## Direção do sol. Vem de oeste (onde está a janela), 52° acima do horizonte:
## alto o suficiente pra não ter cara de fim de tarde, inclinado o suficiente
## pra luz entrar pelo vão em vez de bater no telhado.
const ELEVACAO_GRAUS: float = -52.0
const AZIMUTE_GRAUS: float = -90.0

const COR_SOL: Color = Color(1.0, 0.97, 0.90)
const ENERGIA_SOL: float = 1.4

## Céu de dia limpo. O horizonte é mais claro e leitoso que o zênite — é o que
## dá leitura de "céu" em vez de gradiente azul chapado.
const COR_ZENITE: Color = Color(0.38, 0.55, 0.82)
const COR_HORIZONTE: Color = Color(0.74, 0.82, 0.90)

## Ambiente DESSATURADO de propósito: incide em tudo por igual, inclusive nas
## faces internas do quarto. Usar a cor cheia do céu pinta o cômodo todo de
## azul, do mesmo jeito que a cor do pôr do sol o pintava de laranja.
const COR_AMBIENTE: Color = Color(0.80, 0.83, 0.88)
const ENERGIA_AMBIENTE: float = 0.24

# Caminho relativo, não %NomeUnico — nome único já resolveu pra null sem
# motivo claro neste projeto antes (ver convenção no PROJETO.md).
@onready var _world_env: WorldEnvironment = $"../WorldEnvironment"


func _ready() -> void:
	set_process(false)  # nada aqui é animado

	rotation_degrees = Vector3(ELEVACAO_GRAUS, AZIMUTE_GRAUS, 0.0)
	light_color  = COR_SOL
	light_energy = ENERGIA_SOL

	_configurar_ceu()
	_configurar_ambiente()


func _configurar_ceu() -> void:
	if _world_env == null or _world_env.environment == null:
		return
	var ceu := _world_env.environment.sky
	if ceu == null:
		return
	var material := ceu.sky_material as ProceduralSkyMaterial
	if material == null:
		return

	material.sky_top_color        = COR_ZENITE
	material.sky_horizon_color    = COR_HORIZONTE
	material.ground_horizon_color = COR_HORIZONTE * 0.6
	material.ground_bottom_color  = COR_ZENITE * 0.4
	material.sky_cover            = _criar_textura_nuvens()
	material.sky_cover_modulate   = Color(1.0, 1.0, 1.0)


func _configurar_ambiente() -> void:
	if _world_env == null or _world_env.environment == null:
		return
	var env := _world_env.environment
	env.ambient_light_color  = COR_AMBIENTE
	env.ambient_light_energy = ENERGIA_AMBIENTE
	# A névoa é o céu visto lá fora, então mantém a cor cheia do horizonte.
	env.fog_light_color = COR_HORIZONTE


## Nuvens do céu. Diferente do MateriaisProcedurais.criar_textura_ruido (que dá
## uma textura RGB opaca, boa pra variar tom de parede/chão), aqui a nuvem
## precisa de alfa variando com o ruído — pedaços de céu limpo (transparente) e
## blobs de nuvem (opacos), não um tingimento uniforme. Já foi tentado sem o
## alfa variando e o resultado é um véu chapado, não nuvem.
func _criar_textura_nuvens() -> NoiseTexture2D:
	var ruido := FastNoiseLite.new()
	ruido.noise_type = FastNoiseLite.TYPE_SIMPLEX
	ruido.frequency  = 0.004
	ruido.fractal_octaves = 4

	var textura := NoiseTexture2D.new()
	textura.noise  = ruido
	textura.width  = 512
	textura.height = 256
	textura.seamless = true

	var rampa := Gradient.new()
	rampa.set_offset(0, 0.42)
	rampa.set_color(0, Color(1, 1, 1, 0.0))
	rampa.set_offset(1, 0.72)
	rampa.set_color(1, Color(1, 1, 1, 0.85))
	textura.color_ramp = rampa

	return textura
