extends DirectionalLight3D

# ─────────────────────────────────────────────
#  CICLO DE DIA E NOITE
#
#  Este script vai no nó DirectionalLight3D que representa o sol.
#  Ele gira o sol (e a lua) ao longo do dia, muda cor/intensidade da luz e
#  do céu, usando Gradients montados em código (sem sub_resource no .tscn,
#  mesmo padrão do resto do projeto — tudo procedural em _ready()).
# ─────────────────────────────────────────────

# Duração de um dia completo em segundos (300 = 5 minutos de jogo = 1 dia)
@export var duracao_dia_segundos: float = 300.0

# Hora inicial do dia (0.0 = meia-noite, 0.5 = meio-dia, 0.25 = 6h da manhã)
@export var hora_inicial: float = 0.25

# Tempo acumulado interno (começa na hora_inicial convertida em segundos)
var _tempo: float = 0.0

var _gradiente_luz: Gradient
var _gradiente_ceu_horizonte: Gradient
var _gradiente_ceu_zenite: Gradient
var _sky_material: ProceduralSkyMaterial

# Referência ao WorldEnvironment para trocar o sky ao longo do dia.
# Caminho relativo, não %NomeUnico — nome único já resolveu pra null sem
# motivo claro neste projeto antes (ver convenção em CLAUDE.md).
@onready var _world_env: WorldEnvironment = $"../WorldEnvironment"
@onready var _lua: DirectionalLight3D      = $"../Lua"


func _ready() -> void:
	# Autoconfigura a partir do modo de jogo ativo — o valor no .tscn é só um
	# default de Inspector, não é mais autoridade (ver estado_jogo.gd)
	duracao_dia_segundos = EstadoJogo.duracao_dia_atual()

	_tempo = hora_inicial * duracao_dia_segundos
	_montar_gradientes()

	if _world_env and _world_env.environment and _world_env.environment.sky:
		_sky_material = _world_env.environment.sky.sky_material as ProceduralSkyMaterial
		if _sky_material:
			_sky_material.sky_cover = _criar_textura_nuvens()

	_atualizar_luz()


## Nuvens do céu. Diferente do MateriaisProcedurais.criar_textura_ruido (que dá
## uma textura RGB opaca, boa pra variar tom de parede/chão), aqui a nuvem
## precisa de alfa variando com o ruído — pedaços de céu limpo (transparente)
## e blobs de nuvem (opacos), não um tingimento uniforme.
func _criar_textura_nuvens() -> NoiseTexture2D:
	var ruido := FastNoiseLite.new()
	ruido.noise_type      = FastNoiseLite.TYPE_PERLIN
	ruido.frequency       = 0.015
	ruido.fractal_octaves = 4

	var rampa := Gradient.new()
	rampa.set_offsets(PackedFloat32Array([0.0, 0.55, 0.7, 1.0]))
	rampa.set_colors(PackedColorArray([
		Color(1, 1, 1, 0.0),  # céu limpo
		Color(1, 1, 1, 0.0),
		Color(1, 1, 1, 0.7),  # borda da nuvem
		Color(1, 1, 1, 1.0),  # centro denso
	]))

	var textura := NoiseTexture2D.new()
	textura.width      = 1024
	textura.height     = 512
	textura.seamless   = true
	textura.color_ramp = rampa
	textura.noise      = ruido
	return textura


func _process(delta: float) -> void:
	# Avança o tempo e faz loop quando chega em 1 dia completo
	_tempo += delta
	if _tempo >= duracao_dia_segundos:
		_tempo -= duracao_dia_segundos

	_atualizar_luz()


## Paradas mais densas perto do nascer/pôr do sol, achatadas no meio-dia e
## na meia-noite — dá uma transição rápida e "bonita" sem precisar de mais
## matemática de easing. Tudo espelhado em torno de fracao_dia=0.5 (meio-dia).
func _montar_gradientes() -> void:
	_gradiente_luz = Gradient.new()
	_gradiente_luz.set_offsets(PackedFloat32Array([
		0.0, 0.20, 0.235, 0.27, 0.32, 0.5, 0.68, 0.73, 0.765, 0.80, 1.0,
	]))
	_gradiente_luz.set_colors(PackedColorArray([
		Color(0.05, 0.05, 0.15),  # 0.00 noite
		Color(0.15, 0.12, 0.35),  # 0.20 crepúsculo índigo (antes do amanhecer)
		Color(1.00, 0.35, 0.15),  # 0.235 nascer do sol, laranja-avermelhado
		Color(1.00, 0.75, 0.45),  # 0.27 hora dourada
		Color(1.00, 0.95, 0.85),  # 0.32 manhã morna
		Color(1.00, 0.98, 0.95),  # 0.50 meio-dia, branco-azulado neutro
		Color(1.00, 0.95, 0.85),  # 0.68 tarde morna
		Color(1.00, 0.75, 0.45),  # 0.73 hora dourada (entardecer)
		Color(1.00, 0.35, 0.15),  # 0.765 pôr do sol
		Color(0.15, 0.12, 0.35),  # 0.80 crepúsculo índigo (depois do pôr do sol)
		Color(0.05, 0.05, 0.15),  # 1.00 noite (mesma cor de 0.0, fecha o loop)
	]))

	_gradiente_ceu_horizonte = Gradient.new()
	_gradiente_ceu_horizonte.set_offsets(_gradiente_luz.offsets)
	_gradiente_ceu_horizonte.set_colors(PackedColorArray([
		Color(0.02, 0.02, 0.06),
		Color(0.20, 0.14, 0.32),
		Color(0.85, 0.45, 0.30),
		Color(0.95, 0.65, 0.45),
		Color(0.80, 0.85, 0.92),
		Color(0.75, 0.85, 0.95),
		Color(0.80, 0.85, 0.92),
		Color(0.95, 0.65, 0.45),
		Color(0.85, 0.45, 0.30),
		Color(0.20, 0.14, 0.32),
		Color(0.02, 0.02, 0.06),
	]))

	_gradiente_ceu_zenite = Gradient.new()
	_gradiente_ceu_zenite.set_offsets(_gradiente_luz.offsets)
	_gradiente_ceu_zenite.set_colors(PackedColorArray([
		Color(0.01, 0.01, 0.03),
		Color(0.08, 0.08, 0.20),
		Color(0.25, 0.30, 0.55),
		Color(0.20, 0.35, 0.65),
		Color(0.30, 0.50, 0.80),
		Color(0.25, 0.45, 0.78),
		Color(0.30, 0.50, 0.80),
		Color(0.20, 0.35, 0.65),
		Color(0.25, 0.30, 0.55),
		Color(0.08, 0.08, 0.20),
		Color(0.01, 0.01, 0.03),
	]))


func _atualizar_luz() -> void:
	# fração_dia vai de 0.0 (meia-noite) a 1.0 (próxima meia-noite)
	var fracao_dia: float = _tempo / duracao_dia_segundos

	# ── Rotação do sol e da lua ─────────────────────────────────
	# O sol percorre 360° num dia. 0° = meia-noite (abaixo do horizonte),
	# 90° (0.25) = nascer do sol, 180° (0.5) = meio-dia, 270° = pôr do sol.
	# A lua fica sempre no lado oposto do céu — nasce quando o sol se põe.
	var angulo_solar: float = fracao_dia * 360.0 - 90.0
	rotation_degrees.x = angulo_solar
	rotation_degrees.z = -30.0

	if _lua:
		_lua.rotation_degrees.x = angulo_solar + 180.0
		_lua.rotation_degrees.z = -30.0

	# ── Intensidade da luz ──────────────────────────────────────
	# sin(ângulo) > 0 quando o astro está acima do horizonte.
	var altura_solar: float = sin(deg_to_rad(angulo_solar + 90.0))
	light_energy = max(0.0, altura_solar) * 2.5

	if _lua:
		var altura_lunar: float = -altura_solar
		_lua.light_energy = max(0.0, altura_lunar) * 0.4
		_lua.light_color  = Color(0.6, 0.65, 0.85)

	# ── Cor da luz e do céu (temperatura de cor) ───────────────
	light_color = _gradiente_luz.sample(fracao_dia)
	var cor_horizonte: Color = _gradiente_ceu_horizonte.sample(fracao_dia)
	var cor_zenite: Color    = _gradiente_ceu_zenite.sample(fracao_dia)

	if _sky_material:
		_sky_material.sky_horizon_color    = cor_horizonte
		_sky_material.sky_top_color        = cor_zenite
		_sky_material.ground_horizon_color = cor_horizonte * 0.5
		_sky_material.ground_bottom_color  = cor_zenite * 0.3
		# Nuvens seguem a mesma temperatura de cor do horizonte — ficam
		# alaranjadas no crepúsculo, escuras à noite, neutras de dia
		_sky_material.sky_cover_modulate = cor_horizonte

	# ── Luz ambiente e névoa (simulam céu e reflexo) ───────────
	# Mesmo à noite, há um pouco de luz da lua/estrelas. A névoa acompanha a
	# mesma temperatura do horizonte — sem isso ficaria cinza fixo enquanto
	# o céu muda de cor ao longo do dia.
	if _world_env and _world_env.environment:
		var env := _world_env.environment
		var brilho_ambiente: float = clamp(altura_solar * 0.4 + 0.03, 0.03, 0.4)
		env.ambient_light_energy = brilho_ambiente
		env.ambient_light_color  = cor_horizonte
		env.fog_light_color      = cor_horizonte
