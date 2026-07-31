extends Node
class_name ParedePintavel

# ─────────────────────────────────────────────
#  PAREDE PINTÁVEL — uma parede inteira, do ponto de vista da tinta
#
#  Substitui o antigo tinta_secando.gd, que era por MeshInstance3D. A troca
#  aconteceu porque a máscara do rolo é por PAREDE, não por pedaço: as 4
#  paredes são picadas em 9 peças (por causa das aberturas de janela e
#  porta), mas o rolo não sabe disso — ele pinta uma superfície contínua.
#
#  Então aqui mora a máscara, o material e o relógio de secagem, e as peças
#  viram só geometria compartilhando o mesmo material. Como o UV da máscara
#  vem da posição de mundo (e não do UV do mesh), as peças emendam sem
#  costura e a geometria não precisou mudar.
# ─────────────────────────────────────────────

signal secagem_concluida

## Espessura típica no fim de uma demão, pra estimar quando a parede terminou
## de secar. Não dá pra ler a máscara de volta a cada frame (caro), e usar 1.0
## faria esperar quase o dobro do necessário — no modo Realista isso é hora de
## relógio. A coreografia (Fase E) pode ajustar isto se pintar mais grosso.
const ESPESSURA_TIPICA: float = 0.35

## Espelha `atraso_por_espessura` do shader — os dois PRECISAM bater, senão a
## parede é dada como pronta antes de a camada mais grossa terminar.
const ATRASO_POR_ESPESSURA: float = 0.55

var mascara: MascaraTinta
var material: ShaderMaterial

var tempo_secagem_segundos: float = 60.0

var _tempo_decorrido: float = 0.0
var _janela_demao: float = 8.0
var _avisou_conclusao: bool = false
var _ativo: bool = false


## `origem` é o canto de onde a pintura começa, no alto da parede; `eixo_u` e
## `eixo_v` são os dois lados, com o comprimento embutido (ver VARREDURAS em
## ciclo_pintura.gd). v cresce pra baixo, então o topo da máscara é o alto da
## parede — assim o PNG da máscara bate com o que se vê no jogo.
func configurar(
	largura_m: float,
	altura_m: float,
	origem: Vector3,
	eixo_u: Vector3,
	eixo_v: Vector3,
	carimbo: ImageTexture
) -> void:
	tempo_secagem_segundos = EstadoJogo.tempo_secagem_atual()
	mascara = MascaraTinta.new(largura_m, altura_m, carimbo)

	material = ShaderMaterial.new()
	material.shader = load("res://shaders/tinta_secando.gdshader")
	material.set_shader_parameter("mascara_acumulada", mascara.acumulada)
	material.set_shader_parameter("mascara_recente", mascara.recente)
	material.set_shader_parameter("origem_parede", origem)
	material.set_shader_parameter("eixo_u", eixo_u)
	material.set_shader_parameter("eixo_v", eixo_v)
	material.set_shader_parameter("duracao_secagem", tempo_secagem_segundos)
	material.set_shader_parameter("atraso_por_espessura", ATRASO_POR_ESPESSURA)
	material.set_shader_parameter("tempo_decorrido", 0.0)


## Aplica o material compartilhado nas peças desta parede.
##
## Deferido de propósito: quem cria os meshes é inicializar_quarto.gd, que é o
## script do nó RAIZ — e _ready() do pai roda depois dos filhos. Sem esperar um
## frame, as peças ainda não têm surface e o set_surface_override_material
## falha com "surface_override_materials.size() = 0".
func aplicar_em(pecas: Array) -> void:
	call_deferred("_aplicar_deferido", pecas)


func _aplicar_deferido(pecas: Array) -> void:
	for no in pecas:
		var peca: MeshInstance3D = no
		if peca.mesh != null:
			peca.set_surface_override_material(0, material)


func _process(delta: float) -> void:
	if not _ativo:
		return

	_tempo_decorrido += delta
	material.set_shader_parameter("tempo_decorrido", _tempo_decorrido)

	if not _avisou_conclusao and _tempo_decorrido >= duracao_total():
		_avisou_conclusao = true
		_ativo = false
		secagem_concluida.emit()


## Tempo até a parede inteira estar seca: a última pincelada acontece no fim
## da janela, e a camada mais grossa ainda leva a secagem dela depois disso.
func duracao_total() -> float:
	return _janela_demao + tempo_secagem_segundos * (1.0 + ESPESSURA_TIPICA * ATRASO_POR_ESPESSURA)


## Começa uma demão nova.
##
## Só a máscara RECENTE é limpa. A acumulada persiste de propósito: ela guarda
## o relevo real da parede (quantas camadas de tinta já passaram por cada
## ponto), e isso não some quando uma demão nova começa — tinta velha continua
## embaixo. Limpar as duas fazia a parede virar cor chapada no instante em que
## a demão trocava, e a marca da demão anterior desaparecia de uma vez.
##
## `numero_demao` (0, 1, 2…) suaviza a marca do rolo a cada camada: parede
## recém-pintada sobre reboco cru mostra muita variação, a terceira demão já
## está praticamente lisa.
func iniciar_demao(
	anterior: Color,
	molhada: Color,
	seca: Color,
	janela_segundos: float,
	numero_demao: int = 0
) -> void:
	_janela_demao     = maxf(janela_segundos, 0.01)
	_tempo_decorrido  = 0.0
	_avisou_conclusao = false
	_ativo            = true

	mascara.limpar_demao()
	material.set_shader_parameter("cor_anterior",    anterior)
	material.set_shader_parameter("cor_molhada",     molhada)
	material.set_shader_parameter("cor_seca",        seca)
	material.set_shader_parameter("janela_demao",    _janela_demao)
	material.set_shader_parameter("duracao_secagem", tempo_secagem_segundos)
	material.set_shader_parameter("tempo_decorrido", 0.0)
	# cada demão deixa a superfície mais uniforme
	material.set_shader_parameter("suavidade_demao", 1.0 / (1.0 + float(numero_demao) * 0.9))


## Carimba o rastro do rolo. `de`/`para` são UV 0-1 na parede; `instante` é
## 0-1 dentro da janela da demão.
func carimbar_traco(de: Vector2, para: Vector2, carga: float, instante: float) -> void:
	mascara.carimbar_traco(de, para, carga, instante)


## Pula o relógio pra frente — usado na abertura, pra deixar as paredes que o
## tio pintou antes do jogador chegar em estágios diferentes de secagem.
func adiantar(segundos: float) -> void:
	_tempo_decorrido += segundos
	material.set_shader_parameter("tempo_decorrido", _tempo_decorrido)


## Parede pronta na hora: máscara toda coberta e relógio no fim. Usado ao
## retomar de save, onde o estado visual é sempre "tudo seco".
func forcar_seco() -> void:
	mascara.preencher_coberta()
	material.set_shader_parameter("mascara_acumulada", mascara.acumulada)
	material.set_shader_parameter("mascara_recente", mascara.recente)
	_tempo_decorrido  = duracao_total()
	_avisou_conclusao = true
	_ativo            = false
	material.set_shader_parameter("tempo_decorrido", _tempo_decorrido)


func get_fracao_seca() -> float:
	return clampf(_tempo_decorrido / duracao_total(), 0.0, 1.0)
