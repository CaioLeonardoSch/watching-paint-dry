extends Node

# ─────────────────────────────────────────────
#  CICLO DE PINTURA — orquestra a intro e o loop de demãos
#
#  O tio dá uma VOLTA COMPLETA no quarto, sempre no mesmo sentido: da direita
#  para a esquerda do ponto de vista da garotinha sentada (ela olha pro norte),
#  ou seja Leste, Norte, Oeste, Sul. Ele pinta ANDANDO — o rolo (trajeto_rolo.gd)
#  vai carimbando a máscara da parede enquanto ele caminha, então cada trecho já
#  começa a secar assim que o rolo passa.
#
#  - ABERTURA: o tio já pintou 3 paredes antes do jogador chegar (num escalonamento
#    curto de secagem entre elas) e está terminando a última (Norte) em cena.
#  - Demãos seguintes: circuito completo, uma parede de cada vez.
#  - Depois da 3ª demão: pergunta se gostou. Trocar de cor recomeça o ciclo,
#    também com o tio dando a volta (o jogador está vendo, não pode teleportar
#    a cor como na abertura).
#
#  Enum existe pra introspecção/debug (e save, ver estado_jogo.gd) — a lógica
#  de verdade é a sequência linear abaixo com await, não uma FSM completa.
# ─────────────────────────────────────────────

enum Estado { INTRO, PINTANDO, SECANDO, PERGUNTANDO, CONTEMPLANDO }

@export var demaos_por_ciclo: int = 3
@export var duracao_pintura_segundos: float = 8.0

const PONTO_PORTA_TIO: Vector3          = Vector3(2.5, 0, 0)
const PONTO_PERTO_CADEIRA_TIO: Vector3  = Vector3(0.9, 0, -1.6)
const PONTO_PORTA_GAROTINHA: Vector3    = Vector3(2.3, 0, 0.5)
const PONTO_CADEIRA_GAROTINHA: Vector3  = Vector3(0, 0, -1)
const PONTO_OLHAR_CUTSCENE: Vector3     = Vector3(0.8, 1.3, -2.0)  # entre parede, porta e cadeira

## Cor do reboco cru, antes de qualquer tinta (bate com mat_parede em
## inicializar_quarto.gd) — é o que fica "à frente do rolo" na 1ª demão.
const COR_PAREDE_CRUA: Color = Color(0.93, 0.92, 0.90)

## Quanto da parede o tio já pintou quando a cutscene começa.
const FRACAO_JA_PINTADA_ABERTURA: float = 0.65

## Na abertura ele termina na parede NORTE — é a que a garotinha vai encarar
## sentada, então é a única que enquadra bem. Como o circuito é cíclico, isso
## só quer dizer que a volta anterior já passou por Oeste, Sul e Leste (nessa
## ordem de "mais seca" pra "mais fresca"), e o Norte fecha a volta em cena.
const ORDEM_ABERTURA: Array[int] = [2, 3, 0]  # Oeste, Sul, Leste
const PAREDE_ABERTURA: int = 1                # Norte

# Circuito de pintura, na ordem de visita. Para cada parede:
#   origem/eixo_u/eixo_v — o PLANO da parede em espaço de mundo. `origem` é o
#                          canto de cima de onde a pintura começa; os eixos já
#                          carregam o comprimento do lado. É isto que converte
#                          posição de mundo em UV da máscara (ver o shader).
#                          v aponta pra baixo, então o topo da máscara é o alto
#                          da parede.
#   largura/altura       — em metros, pra dimensionar a máscara
#   de/para              — trajeto do tio, rente à parede
#   angulo               — rotação em Y pra ele encarar a parede
#
# Antes isto descrevia por onde a "frente de varredura" andava; agora descreve
# só a superfície. Quem decide o caminho do rolo é trajeto_rolo.gd.
# Quarto: X ∈ [-3.0, +3.0], Z ∈ [-4.0, +2.0], Y ∈ [0, 3] — 6 × 6, ver G6.
## Centro do vão da janela, na face interna da parede oeste. É a única entrada
## direcional do campo de secagem (Fase G1): perto dela há corrente de ar e mais
## calor, então a tinta seca antes ali e a região seca avança dali pro canto de
## baixo mais distante. Se a janela mudar de lugar, este ponto muda junto.
const PONTO_JANELA: Vector3 = Vector3(-3.0, 1.4, -1.0)

const VARREDURAS: Array[Dictionary] = [
	{  # Leste (porta) — direita da garotinha. Pinta do sul pro norte.
		"origem": Vector3(3.0, 3, 2), "eixo_u": Vector3(0, 0, -6), "eixo_v": Vector3(0, -3, 0),
		"largura": 6.0, "altura": 3.0,
		"de": Vector3(2.3, 0, 1.6), "para": Vector3(2.3, 0, -3.4), "angulo": -90.0,
	},
	{  # Norte (frente dela). Pinta de leste pra oeste.
		"origem": Vector3(3.0, 3, -4), "eixo_u": Vector3(-6, 0, 0), "eixo_v": Vector3(0, -3, 0),
		"largura": 6.0, "altura": 3.0,
		"de": Vector3(2.3, 0, -3.4), "para": Vector3(-2.3, 0, -3.4), "angulo": 0.0,
	},
	{  # Oeste (janela) — esquerda dela. Pinta do norte pro sul.
		"origem": Vector3(-3.0, 3, -4), "eixo_u": Vector3(0, 0, 6), "eixo_v": Vector3(0, -3, 0),
		"largura": 6.0, "altura": 3.0,
		"de": Vector3(-2.3, 0, -3.4), "para": Vector3(-2.3, 0, 1.4), "angulo": 90.0,
	},
	{  # Sul (atrás dela) — fecha a volta. Pinta de oeste pra leste.
		"origem": Vector3(-3.0, 3, 2), "eixo_u": Vector3(6, 0, 0), "eixo_v": Vector3(0, -3, 0),
		"largura": 6.0, "altura": 3.0,
		"de": Vector3(-2.3, 0, 1.4), "para": Vector3(2.3, 0, 1.4), "angulo": 180.0,
	},
]

var estado: Estado = Estado.INTRO
var demao_atual: int = 0
var cor_atual: CorTinta

# Uma entrada por parede, na mesma ordem de VARREDURAS (Leste/Norte/Oeste/Sul).
var _paredes: Array[ParedePintavel] = []
var _trajeto: TrajetoRolo
var _cor_anterior_seca: Color = COR_PAREDE_CRUA

@onready var _tio: Tio                      = $"../Tio"
@onready var _garotinha: Garotinha          = $"../Garotinha"
@onready var _camera_cadeira: CameraCadeira = $"../Camera3D"
@onready var _camera_cutscene: Camera3D     = $"../CameraCutscene"
@onready var _dialogo: DialogoPintura       = $"../DialogoPintura"
@onready var _porta: Porta                  = $"../Porta"


func _ready() -> void:
	# As peças de cada parede — picadas por causa das aberturas de janela e
	# porta, mas do ponto de vista da tinta são uma superfície contínua só.
	var grupos: Array = [
		[$"../ParedeLesteNorte", $"../ParedeLesteSul", $"../ParedeLesteAcima"],
		[$"../ParedeNorteSolida"],
		[$"../ParedeOesteNorte", $"../ParedeOesteSul", $"../ParedeOesteAcima", $"../ParedeOesteAbaixo"],
		[$"../ParedeSul"],
	]

	var carimbo := MascaraTinta.criar_carimbo()  # o mesmo rolo nas 4 paredes
	for i in range(VARREDURAS.size()):
		var v: Dictionary = VARREDURAS[i]
		var parede := ParedePintavel.new()
		parede.name = "Parede%d" % i
		add_child(parede)
		var largura: float  = v["largura"]
		var altura: float   = v["altura"]
		var origem: Vector3 = v["origem"]
		var eixo_u: Vector3 = v["eixo_u"]
		var eixo_v: Vector3 = v["eixo_v"]
		parede.configurar(largura, altura, origem, eixo_u, eixo_v, carimbo, i, PONTO_JANELA)
		parede.aplicar_em(grupos[i])
		_paredes.append(parede)

	_trajeto = TrajetoRolo.new()
	_trajeto.name = "TrajetoRolo"
	add_child(_trajeto)

	if EstadoJogo.existe_save():
		await _retomar_de_save()
	else:
		cor_atual = _carregar_cor("Azul")
		await _sequencia_abertura()


## Carrega um CorTinta pelo nome, aproveitando a convenção de nomes de
## arquivo (resources/cores/<nome em minúsculo>.tres) — evita depender da
## paleta carregada por dialogo_pintura.gd, que pode não ter rodado
## _ready() ainda nesse ponto (ordem entre nós irmãos não é garantida).
func _carregar_cor(nome: String) -> CorTinta:
	return load("res://resources/cores/%s.tres" % nome.to_lower()) as CorTinta


## Pula a cutscene inteira — tio/garotinha já "não estão lá", câmera da
## cadeira já ativa, paredes aparecem no estado salvo (secas, sem animar).
func _retomar_de_save() -> void:
	_tio.hide()
	_garotinha.hide()
	_camera_cadeira.ativar()

	cor_atual   = _carregar_cor(EstadoJogo.dados.cor_atual_nome)
	demao_atual = EstadoJogo.dados.demao_atual

	var indice_cor: int = clampi(demao_atual - 1, 0, cor_atual.demaos() - 1)
	for i in range(_paredes.size()):
		_iniciar_demao_parede(i, indice_cor)
		_paredes[i].forcar_seco()

	if demao_atual >= demaos_por_ciclo:
		await _perguntar_cor()
	else:
		await _continuar_ciclo()


func _sequencia_abertura() -> void:
	estado = Estado.INTRO
	_camera_cutscene.look_at(PONTO_OLHAR_CUTSCENE, Vector3.UP)

	# As outras 3 paredes já foram pintadas antes do jogador chegar. Carimba de
	# uma vez (sem animar) pra elas terem a marca de rolo de verdade, não cor
	# chapada.
	#
	# O escalonamento de secagem entre elas é DE PROPÓSITO bem curto. A versão
	# anterior espaçava cada parede por uma volta inteira mais 18% da secagem, e
	# o resultado era o quarto abrindo com quatro paredes visivelmente em
	# estágios diferentes — mais parecia tinta de cores diferentes que a mesma
	# demão. A leitura que interessa no começo do jogo é uma só: primeira mão de
	# tinta sobre reboco, igual nas quatro paredes.
	var quantas_antes: int = ORDEM_ABERTURA.size()
	for ordem in range(quantas_antes):
		var indice: int = ORDEM_ABERTURA[ordem]
		_iniciar_demao_parede(indice, 0)
		_trajeto.pintar_instantaneo(_paredes[indice])
		var voltas_atras: float = float(quantas_antes - ordem)
		_paredes[indice].adiantar(duracao_pintura_segundos * voltas_atras * 0.35)

	# O tio está no meio da parede norte, terminando o serviço em cena.
	var v: Dictionary  = VARREDURAS[PAREDE_ABERTURA]
	var de: Vector3    = v["de"]
	var para: Vector3  = v["para"]
	var angulo: float  = v["angulo"]
	_iniciar_demao_parede(PAREDE_ABERTURA, 0)
	_trajeto.pintar_instantaneo(_paredes[PAREDE_ABERTURA], false, FRACAO_JA_PINTADA_ABERTURA)
	_paredes[PAREDE_ABERTURA].adiantar(duracao_pintura_segundos * FRACAO_JA_PINTADA_ABERTURA)

	var ponto_atual: Vector3 = de.lerp(para, FRACAO_JA_PINTADA_ABERTURA)
	var restante: float = duracao_pintura_segundos * (1.0 - FRACAO_JA_PINTADA_ABERTURA)
	_tio.show()
	# o rolo continua de onde parou, em paralelo com a caminhada do tio
	_trajeto.pintar(_paredes[PAREDE_ABERTURA], duracao_pintura_segundos, false, FRACAO_JA_PINTADA_ABERTURA)
	await _tio.pintar_varrendo(ponto_atual, para, restante, angulo)

	await _tio.ir_ate(PONTO_PERTO_CADEIRA_TIO, 2.5)
	await _garotinha_entra_e_senta()
	_camera_cadeira.ativar()
	await _tio_sai()

	estado = Estado.SECANDO
	demao_atual = 0
	await _esperar_secar(PAREDE_ABERTURA)

	demao_atual = 1
	EstadoJogo.salvar_progresso_pintura(cor_atual.nome, demao_atual)
	await _continuar_ciclo()


## Wrappers de entrada/saída — a porta abre antes de alguém passar e fecha
## depois. Centralizado aqui pra tio.gd/garotinha.gd continuarem sem saber
## que existe porta (mesma razão de eles não saberem de som nem de save).
func _tio_entra(destino: Vector3) -> void:
	await _porta.abrir()
	await _tio.entrar_pela_porta(PONTO_PORTA_TIO, destino)
	await _porta.fechar()


func _tio_sai() -> void:
	await _porta.abrir()
	await _tio.sair_pela_porta(PONTO_PORTA_TIO)
	await _porta.fechar()


func _garotinha_entra_e_senta() -> void:
	await _porta.abrir()
	await _garotinha.entrar_e_sentar(PONTO_PORTA_GAROTINHA, PONTO_CADEIRA_GAROTINHA)
	await _porta.fechar()


func _continuar_ciclo() -> void:
	if demao_atual < demaos_por_ciclo:
		await _rodada_de_pintura(demao_atual)
		demao_atual += 1
		EstadoJogo.salvar_progresso_pintura(cor_atual.nome, demao_atual)
		await _continuar_ciclo()
	else:
		await _perguntar_cor()


## Volta completa: o tio entra, percorre as 4 paredes na ordem do circuito
## pintando enquanto anda, e sai. Só depois espera secar — a última parede da
## volta é sempre a que termina por último, então esperar por ela basta.
func _rodada_de_pintura(indice_demao: int) -> void:
	estado = Estado.PINTANDO
	var primeira: Dictionary  = VARREDURAS[0]
	var ponto_inicial: Vector3 = primeira["de"]
	await _tio_entra(ponto_inicial)

	for i in range(_paredes.size()):
		var v: Dictionary  = VARREDURAS[i]
		var de: Vector3    = v["de"]
		var para: Vector3  = v["para"]
		var angulo: float  = v["angulo"]
		if i > 0:
			await _tio.ir_ate(de, 1.2)   # canto a canto, o trajeto é curto
		_iniciar_demao_parede(i, indice_demao)
		# rolo e tio andam juntos: o trajeto carimba enquanto ele caminha
		_trajeto.pintar(_paredes[i], duracao_pintura_segundos)
		await _tio.pintar_varrendo(de, para, duracao_pintura_segundos, angulo)

	await _tio_sai()

	estado = Estado.SECANDO
	await _esperar_secar(_paredes.size() - 1)


## Prepara uma parede pra receber uma demão nova: limpa a máscara e troca as
## cores. Quem desenha de fato é o trajeto do rolo.
func _iniciar_demao_parede(indice_parede: int, indice_demao: int) -> void:
	_paredes[indice_parede].iniciar_demao(
		_cor_antes_da_demao(indice_demao),
		cor_atual.molhada(indice_demao),
		cor_atual.meio(indice_demao),
		cor_atual.seca(indice_demao),
		duracao_pintura_segundos,
		indice_demao)


## O que está na parede ANTES desta demão — a demão anterior da mesma cor,
## ou (na 1ª) a cor que estava lá antes de trocar de tinta.
func _cor_antes_da_demao(indice_demao: int) -> Color:
	if indice_demao > 0:
		return cor_atual.seca(indice_demao - 1)
	return _cor_anterior_seca


## Espera a parede pintada POR ÚLTIMO terminar — como todas têm a mesma
## duração, quem começou depois acaba depois, então basta essa. Na abertura a
## última é o Norte, não a última do array, por isso o índice vem por fora.
func _esperar_secar(indice_ultima_pintada: int) -> void:
	await _paredes[indice_ultima_pintada].secagem_concluida


func _duracao_secagem_padrao() -> float:
	return _paredes[0].tempo_secagem_segundos


func _perguntar_cor() -> void:
	estado = Estado.PERGUNTANDO
	EstadoJogo.registrar_ciclo_completo(cor_atual.nome)  # "viu todas as demãos" já vale aqui
	await _tio_entra(PONTO_PERTO_CADEIRA_TIO)

	var gostou: bool = await _dialogo.perguntar_gostou()
	if gostou:
		await _tio_sai()
		estado = Estado.CONTEMPLANDO
		return

	var nova_cor: CorTinta = await _dialogo.escolher_cor(cor_atual)
	# A cor que sai fica "por baixo" da primeira demão da cor nova
	_cor_anterior_seca = cor_atual.seca(cor_atual.demaos() - 1)
	cor_atual   = nova_cor
	demao_atual = 0
	EstadoJogo.salvar_progresso_pintura(cor_atual.nome, demao_atual)

	await _tio_sai()
	await _rodada_de_pintura(0)
	demao_atual = 1
	EstadoJogo.salvar_progresso_pintura(cor_atual.nome, demao_atual)
	await _continuar_ciclo()
