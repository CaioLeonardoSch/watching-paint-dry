extends DirectionalLight3D

# ─────────────────────────────────────────────
#  CICLO DE DIA E NOITE
#
#  Este script vai no nó DirectionalLight3D que representa o sol.
#  Ele gira o sol ao longo do dia e muda a cor/intensidade da luz
#  para simular amanhecer, meio-dia, entardecer e noite.
# ─────────────────────────────────────────────

# Duração de um dia completo em segundos (300 = 5 minutos de jogo = 1 dia)
@export var duracao_dia_segundos: float = 300.0

# Hora inicial do dia (0.0 = meia-noite, 0.5 = meio-dia, 0.25 = 6h da manhã)
@export var hora_inicial: float = 0.25

# Tempo acumulado interno (começa na hora_inicial convertida em segundos)
var _tempo: float = 0.0

# Referência ao WorldEnvironment para trocar o sky ao longo do dia
@onready var _world_env: WorldEnvironment = get_node("../WorldEnvironment")


func _ready() -> void:
	_tempo = hora_inicial * duracao_dia_segundos
	_atualizar_luz()


func _process(delta: float) -> void:
	# Avança o tempo e faz loop quando chega em 1 dia completo
	_tempo += delta
	if _tempo >= duracao_dia_segundos:
		_tempo -= duracao_dia_segundos

	_atualizar_luz()


func _atualizar_luz() -> void:
	# fração_dia vai de 0.0 (meia-noite) a 1.0 (próxima meia-noite)
	var fracao_dia: float = _tempo / duracao_dia_segundos

	# ── Rotação do sol ──────────────────────────────────────────
	# O sol percorre 360° num dia. 0° = meia-noite (abaixo do horizonte),
	# 90° (0.25) = nascer do sol, 180° (0.5) = meio-dia, 270° = pôr do sol.
	var angulo_solar: float = fracao_dia * 360.0 - 90.0
	rotation_degrees.x = angulo_solar

	# Levemente inclinado no eixo Z para parecer que o sol não passa exatamente
	# pelo zênite — mais realista para latitudes temperadas
	rotation_degrees.z = -30.0

	# ── Intensidade da luz ──────────────────────────────────────
	# Durante a noite (sol abaixo do horizonte) a luz solar deve ser zero.
	# sin(ângulo) > 0 quando o sol está acima do horizonte.
	var altura_solar: float = sin(deg_to_rad(angulo_solar + 90.0))
	light_energy = max(0.0, altura_solar) * 2.5

	# ── Cor da luz (temperatura de cor) ────────────────────────
	# Amanhecer/entardecer = laranja/vermelho; meio-dia = branco-azulado
	if altura_solar <= 0.0:
		# Noite — sem cor solar direta
		light_color = Color(0.05, 0.05, 0.15)
	elif altura_solar < 0.2:
		# Nascer/pôr do sol — laranja quente
		var t: float = altura_solar / 0.2
		light_color = Color(1.0, 0.4 + t * 0.3, 0.1 + t * 0.5).lerp(
			Color(1.0, 0.85, 0.7), t
		)
	else:
		# Dia claro — interpolação de laranja suave para branco-azulado
		var t: float = clamp((altura_solar - 0.2) / 0.8, 0.0, 1.0)
		light_color = Color(1.0, 0.85, 0.7).lerp(Color(1.0, 0.98, 0.92), t)

	# ── Luz ambiente (simula céu e reflexo) ────────────────────
	# Mesmo à noite, há um pouco de luz da lua/estrelas
	if _world_env and _world_env.environment:
		var env := _world_env.environment
		var brilho_ambiente: float = clamp(altura_solar * 0.4 + 0.03, 0.03, 0.4)
		env.ambient_light_energy = brilho_ambiente

		# Cor do ambiente acompanha a hora do dia
		if altura_solar <= 0.0:
			env.ambient_light_color = Color(0.05, 0.05, 0.2)   # noite azulada
		else:
			env.ambient_light_color = Color(0.6, 0.65, 0.8)    # dia frio/neutro
