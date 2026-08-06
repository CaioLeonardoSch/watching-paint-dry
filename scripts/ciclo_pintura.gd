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

## ⚠️ NÃO é mais o que manda no ritmo — quem decide quanto uma parede leva é a
## coreografia (`TrajetoRolo.duracao_estimada()`, ver SECAGEM §3.9). Este número
## é só a estimativa usada onde não há trajeto rodando: o escalonamento de
## secagem das paredes já pintadas da abertura e a retomada de save.
##
## **Remedido** em 06/08/2026, depois de o banquinho virar objeto carregado:
## ~222 m de caminho, 62 s rolando + 9 idas à bandeja + ~7 idas ao banquinho =
## 99 a 105 s por parede (leste 104,5 / norte 102,4 / oeste 98,8 / sul 99,7).
## Era 84 s. Mudou o caminho do rolo ou o número de paradas? Remedir aqui.
@export var duracao_pintura_segundos: float = 101.0

const PONTO_PERTO_CADEIRA_TIO: Vector3  = Vector3(0.9, 0, -1.6)
const PONTO_CADEIRA_GAROTINHA: Vector3  = Vector3(0, 0, -1)

## Cor do reboco cru, antes de qualquer tinta (bate com mat_parede em
## inicializar_quarto.gd) — é o que fica "à frente do rolo" na 1ª demão.
const COR_PAREDE_CRUA: Color = Color(0.93, 0.92, 0.90)

## Quanto da parede o tio já pintou quando a cutscene começa.
##
## Subiu de 0,65 pra 0,92 na Fase E: com a coreografia honesta uma parede leva
## 84 s, e 35% dela seriam 29 s de cutscene antes de a garotinha sequer entrar.
## Ele agora está fechando o último trecho — 7 s, que é o tempo de o jogador
## entender a cena sem ela cansar antes de começar.
const FRACAO_JA_PINTADA_ABERTURA: float = 0.92

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
#   aberturas            — os buracos (janela, porta) em METROS no plano (u, v),
#                          convertidos das medidas de inicializar_quarto.gd.
#                          v cresce pra baixo, então v_m = 3 − Y. O rolo pinta
#                          ao redor deles; sem isto ele atravessava o vão.
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
		# porta: Z∈[-0.5,+0.5] → u_m = 2 − Z ∈ [1.5, 2.5]; Y∈[0,2.1] → v_m ∈ [0.9, 3.0]
		"aberturas": [Rect2(1.5, 0.9, 1.0, 2.1)],
	},
	{  # Norte (frente dela). Pinta de leste pra oeste.
		"origem": Vector3(3.0, 3, -4), "eixo_u": Vector3(-6, 0, 0), "eixo_v": Vector3(0, -3, 0),
		"largura": 6.0, "altura": 3.0,
		"de": Vector3(2.3, 0, -3.4), "para": Vector3(-2.3, 0, -3.4), "angulo": 0.0,
		"aberturas": [],
	},
	{  # Oeste (janela) — esquerda dela. Pinta do norte pro sul.
		"origem": Vector3(-3.0, 3, -4), "eixo_u": Vector3(0, 0, 6), "eixo_v": Vector3(0, -3, 0),
		"largura": 6.0, "altura": 3.0,
		"de": Vector3(-2.3, 0, -3.4), "para": Vector3(-2.3, 0, 1.4), "angulo": 90.0,
		# janela: Z∈[-1.85,-0.15] → u_m = Z + 4 ∈ [2.15, 3.85]; Y∈[0.8,2.0] → v_m ∈ [1.0, 2.2]
		"aberturas": [Rect2(2.15, 1.0, 1.7, 1.2)],
	},
	{  # Sul (atrás dela) — fecha a volta. Pinta de oeste pra leste.
		"origem": Vector3(-3.0, 3, 2), "eixo_u": Vector3(6, 0, 0), "eixo_v": Vector3(0, -3, 0),
		"largura": 6.0, "altura": 3.0,
		"de": Vector3(-2.3, 0, 1.4), "para": Vector3(2.3, 0, 1.4), "angulo": 180.0,
		"aberturas": [],
	},
]

var estado: Estado = Estado.INTRO
var demao_atual: int = 0
var cor_atual: CorTinta

# Uma entrada por parede, na mesma ordem de VARREDURAS (Leste/Norte/Oeste/Sul).
var _paredes: Array[ParedePintavel] = []
var _trajeto: TrajetoRolo
var _props: PropsPintura
var _cor_anterior_seca: Color = COR_PAREDE_CRUA

@onready var _tio: Tio                      = $"../Tio"
@onready var _garotinha: Garotinha          = $"../Garotinha"
@onready var _camera_cadeira: CameraCadeira = $"../Camera3D"
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
		# ⚠️ o Array dentro de um Dictionary const vem SEM tipo — copiar pra um
		# Array[Rect2] antes de passar, senão é o mesmo tropeço de passar
		# `dicionario["chave"]` direto pra parâmetro tipado (CLAUDE.md)
		var buracos: Array[Rect2] = []
		for r in v["aberturas"]:
			buracos.append(r as Rect2)
		parede.configurar(largura, altura, origem, eixo_u, eixo_v, carimbo, i, PONTO_JANELA, buracos)
		parede.aplicar_em(grupos[i])
		_paredes.append(parede)

	_trajeto = TrajetoRolo.new()
	_trajeto.name = "TrajetoRolo"
	add_child(_trajeto)

	# Bandeja, banquinho e lata andam com o serviço (ver props_pintura.gd), por
	# isso não moram no cenário estático de props_quarto.gd.
	#
	# ⚠️ Filho DESTE nó, não do pai: `add_child` no pai durante o `_ready` dele
	# falha com "Parent node is busy setting up children". Como o `Quarto` é um
	# Node3D na identidade e este nó é um Node comum, pendurar aqui dá as mesmas
	# coordenadas de mundo.
	_props = PropsPintura.new()
	_props.name = "PropsPintura"
	add_child(_props)
	_tio.definir_props(_props)

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
	# o material do tio ficou pela última parede que ele pintou — sem isto a
	# bandeja e o banquinho aparecem no meio do quarto, em cima da cadeira
	_props.posicionar_para_parede(_paredes[_paredes.size() - 1])

	if demao_atual >= demaos_por_ciclo:
		await _perguntar_cor()
	else:
		await _continuar_ciclo()


func _sequencia_abertura() -> void:
	estado = Estado.INTRO

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
		_trajeto.preparar(_paredes[indice])
		_iniciar_demao_parede(indice, 0, _trajeto.duracao_estimada())
		_trajeto.pintar_instantaneo(_paredes[indice])
		var voltas_atras: float = float(quantas_antes - ordem)
		_paredes[indice].adiantar(duracao_pintura_segundos * voltas_atras * 0.35)

	# O tio está no fim da parede norte, terminando o serviço em cena.
	var v: Dictionary  = VARREDURAS[PAREDE_ABERTURA]
	var angulo: float  = v["angulo"]
	var parede_abertura: ParedePintavel = _paredes[PAREDE_ABERTURA]
	_trajeto.preparar(parede_abertura)
	var janela: float = _trajeto.duracao_estimada()
	_iniciar_demao_parede(PAREDE_ABERTURA, 0, janela)
	_trajeto.pintar_instantaneo(parede_abertura, false, FRACAO_JA_PINTADA_ABERTURA)
	parede_abertura.adiantar(janela * FRACAO_JA_PINTADA_ABERTURA)

	# Posiciona ANTES de mostrar: ele já entra em cena no lugar certo e virado
	# pra parede, então não há giro nem salto na frente do jogador. É a única
	# aparição que não passa pela porta — aqui ele já está no meio do serviço.
	_tio.position = _tio.posto_de_trabalho(_trajeto, parede_abertura, FRACAO_JA_PINTADA_ABERTURA)
	_tio.rotation_degrees.y = angulo
	_tio.show()
	_props.posicionar_para_parede(parede_abertura)
	# o rolo continua de onde parou, em paralelo com o corpo do tio
	_trajeto.pintar(parede_abertura, false, FRACAO_JA_PINTADA_ABERTURA)
	# ⚠️ SEM await: a garotinha entra ENQUANTO ele pinta. O pedido é ela chegar e
	# encontrar o tio no fim da última parede, não achar o serviço pronto.
	_tio.acompanhar_trajeto(_trajeto, parede_abertura, angulo)

	await _garotinha_entra_e_senta()

	# Ele termina a parede com ela já sentada, e só então guarda e sai.
	await _tio.pintura_concluida
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
##
## `posicionar_fora()` vem ANTES de abrir de propósito: com a folha ainda
## fechada o personagem fica ocluído, então ele já está lá quando a porta abre,
## em vez de aparecer do nada no meio do vão. Onde é "fora" é o cômodo vizinho,
## que é modelado — quem sabe disso é `personagem.gd`, não este arquivo.
func _tio_entra(destino: Vector3) -> void:
	_tio.posicionar_fora()
	await _porta.abrir()
	await _tio.entrar_pela_porta(destino)
	await _porta.fechar()


func _tio_sai() -> void:
	await _porta.abrir()
	await _tio.sair_pela_porta()
	await _porta.fechar()


## A entrada dela, em 1ª pessoa do começo ao fim.
##
## ⚠️ Ela fica INVISÍVEL a viagem toda, e não só depois de sentar como antes: a
## câmera é a cabeça dela, então o corpo seria clipping na frente da lente. O
## `sentar()` continua sendo pose de osso de verdade (OVERHAUL §5.7) porque é
## dele que sai a altura da câmera descendo — não é animação desperdiçada.
func _garotinha_entra_e_senta() -> void:
	_garotinha.esconder_sempre = true
	_garotinha.posicionar_fora()
	_garotinha.hide()
	_camera_cadeira.seguir(_garotinha, _garotinha.altura_dos_olhos())
	_camera_cadeira.ativar()

	await _porta.abrir()
	await _garotinha.entrar_pela_porta(PONTO_CADEIRA_GAROTINHA, 3.4)
	await _garotinha.girar_para(0.0)
	# a câmera desce JUNTO com o corpo, não depois: sem `await` aqui as duas
	# descidas acontecem na mesma janela de tempo
	_camera_cadeira.assentar(Garotinha.DURACAO_SENTAR)
	await _garotinha.sentar()
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
	# Entra andando DIRETO pros props, não pro canto da primeira parede: é de lá
	# que ele vai pegar bandeja, lata e banquinho. Ir pro canto primeiro fazia
	# ele atravessar o quarto duas vezes sem motivo visível.
	var pega_props: Vector3 = _props.ponto_de_molhar()
	pega_props.y = 0.0
	await _tio_entra(pega_props)

	for i in range(_paredes.size()):
		var v: Dictionary  = VARREDURAS[i]
		var de: Vector3    = v["de"]
		var angulo: float  = v["angulo"]
		# Ele busca bandeja, lata e banquinho onde deixou e carrega até a parede
		# nova — inclusive na PRIMEIRA parede da volta, porque os props ficaram
		# na última parede da volta anterior. Era `posicionar_para_parede`
		# sozinho, e os três objetos pulavam de canto do quarto na frente da
		# garotinha sentada.
		await _tio.levar_props(_props, _paredes[i])
		await _tio.ir_ate(de, 1.2)   # canto a canto, o trajeto é curto
		# Virar pra parede ANTES de soltar o rolo: `pintar()` não é aguardado, e
		# um giro depois dele deixaria o rolo meio segundo andando sozinho.
		await _tio.encarar_parede(angulo)
		# preparar antes de abrir a demão: a janela da demão É a duração da
		# coreografia desta parede, e ela só se sabe com o caminho gerado
		_trajeto.preparar(_paredes[i])
		_iniciar_demao_parede(i, indice_demao, _trajeto.duracao_estimada())
		# rolo e tio são a mesma curva: o trajeto carimba e o corpo o persegue
		_trajeto.pintar(_paredes[i])
		await _tio.acompanhar_trajeto(_trajeto, _paredes[i], angulo)

	await _tio_sai()

	estado = Estado.SECANDO
	await _esperar_secar(_paredes.size() - 1)


## Prepara uma parede pra receber uma demão nova: limpa a máscara e troca as
## cores. Quem desenha de fato é o trajeto do rolo.
##
## `janela` é quanto a pintura desta parede vai levar — vem do trajeto já
## preparado, não de constante. É ela que o shader usa pra converter o instante
## gravado (0 a 1) em segundos de relógio de secagem.
func _iniciar_demao_parede(indice_parede: int, indice_demao: int, janela: float = -1.0) -> void:
	var segundos: float = janela if janela > 0.0 else duracao_pintura_segundos
	var cor_molhada: Color = cor_atual.molhada(indice_demao)
	_tio.definir_cor_tinta(cor_molhada)
	_props.definir_cor(cor_molhada)
	_paredes[indice_parede].iniciar_demao(
		_cor_antes_da_demao(indice_demao),
		cor_atual.molhada(indice_demao),
		cor_atual.meio(indice_demao),
		cor_atual.seca(indice_demao),
		segundos,
		indice_demao,
		demaos_por_ciclo)


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
