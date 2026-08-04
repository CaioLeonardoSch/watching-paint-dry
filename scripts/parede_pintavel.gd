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

## Teto da variação do campo de secagem (Fase G1). Espelha `variacao_max` do
## shader e os dois PRECISAM bater — é o que faz `duracao_total()` deixar de
## ser chute. Antes daqui havia `ESPESSURA_TIPICA = 0.35`, um palpite sobre um
## acumulador que na medição vale 0,033: sobravam ~18% de espera morta no fim
## de cada demão, que no modo Realista é hora de relógio.
const VARIACAO_MAX: float = 0.40

## Variação usada pra ANUNCIAR que a parede secou — é um percentil, não o teto.
##
## `VARIACAO_MAX` limita o pior texel possível, mas medindo a distribuição real
## só 0,2% da parede chega perto dele, e anunciar pelo pior caso custa 11,6% de
## espera morta com a parede já parada na tela. 0,24 saiu de medir na tela
## quando o último pixel entra em 1/255 da cor final (70,2 s), com margem pra
## não anunciar cedo: dá 71,2 s, 1,4% de folga.
##
## ⚠️ Medir isto exige **congelar a cena** — tirar Tio e Garotinha da árvore e
## parar `ciclo_pintura`. A cutscene continua rodando durante o teste, e um
## personagem entrando em quadro depois do quadro de referência vira uma
## diferença permanente que não decai. Isso já produziu um resultado falso de
## "4,22% da parede nunca converge", idêntico em quatro configurações
## diferentes do shader — que era justamente a pista de que não era o shader.
const VARIACAO_CONCLUSAO: float = 0.24

## Onde `k_valor` fecha no shader (`smoothstep(0.34, 0.85, fracao)`) — é a
## última das curvas da secagem. Depois disto a cor não muda mais, então esperar
## `fracao` chegar a 1,0 é esperar à toa. **Espelha o 0,85 do shader e os dois
## PRECISAM bater**, senão a parede é anunciada como pronta antes da hora.
const FIM_DA_COR: float = 0.85

## Carga típica na máscara RECENTE depois de uma passada. MEDIDA lendo a
## máscara de volta com o trajeto real nas 4 paredes: média 0,511, mediana
## 0,505, p05 0,288, p90 0,719. É o divisor do termo de espessura do campo de
## secagem — o filme molhado desta demão, que é o que atrasa a secagem.
##
## Era 0,627 até `carimbo_recente` parar de multiplicar a carga DUAS vezes (uma
## no peso da mistura e outra no valor gravado). O canal andava com o quadrado
## da carga; agora anda com ela.
const CARGA_TIPICA: float = 0.511

## Depósito médio de UMA demão no ACUMULADOR. Medido do mesmo jeito: média
## 0,033, pico 0,043, desvio 0,005. Divisor da marca do rolo, que é relevo
## seco de todas as demãos — outra grandeza, outro número, de propósito.
##
## Se a Fase E mudar carga ou trajeto do rolo, remedir os dois.
const ESPESSURA_DEMAO: float = 0.033

## Faixa da carga que conta como "coberto" (Fase G3).
##
## Mora AQUI, não nos shaders, porque dois shaders precisam do mesmo par:
## `tinta_secando` pra desenhar e `copia_cobertura` pra gravar o histórico com o
## mesmo critério. Se divergirem, a costura entre demãos reabre.
##
## ⚠️ Não dá pra ler isto de volta do material com `get_shader_parameter`: ele
## devolve **null** pra uniform que nunca foi setado explicitamente (o default
## do shader não conta), e o null vazava como argumento tipado. Foi assim que
## `iniciar_demao` quebrou com "Cannot convert argument 1 from Nil to float".
##
## O máximo é o **ganho visual da falha de cobertura**, e está DESLIGADO de
## propósito: 0,10 fica abaixo do pior texel do miolo (medido, 0,140), então
## dentro da parede a cobertura fecha em 1 e só canto de verdade falha.
##
## Não é covardia, é a conclusão da própria Fase G3 aplicada: com passadas de
## altura inteira e recarga instantânea, a falha sai como **barra vertical de
## ponta quadrada**, uma passada de largura — lê como risco na parede, não como
## rolo secando. O Caio pegou isso na tela antes de eu pegar na medição.
## Reabrir junto com a coreografia da Fase E, que é o que quebra a passada de
## altura inteira. Ver SECAGEM §5.3 e §5.4.
const COBERTURA_MIN: float = 0.0
const COBERTURA_MAX: float = 0.10

## Quanto cada demão nova atrasa a secagem, uniformemente. É real: o substrato
## vai selando e absorve menos água a cada camada. Entra como fator explícito
## de propósito — antes isso saía como efeito colateral do acumulador crescendo,
## o que misturava "esta camada é grossa aqui" com "esta é a 3ª demão".
const ATRASO_POR_DEMAO: float = 0.12

var mascara: MascaraTinta
var material: ShaderMaterial

var tempo_secagem_segundos: float = 60.0

var _tempo_decorrido: float = 0.0
var _janela_demao: float = 8.0
## Duração de secagem DESTA demão, já com ATRASO_POR_DEMAO aplicado.
var _duracao_demao: float = 60.0
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
	carimbo: ImageTexture,
	indice_parede: int = 0,
	pos_janela: Vector3 = Vector3.ZERO
) -> void:
	tempo_secagem_segundos = EstadoJogo.tempo_secagem_atual()
	_duracao_demao = tempo_secagem_segundos
	# semente derivada do índice: as 4 paredes precisam de nuvens diferentes,
	# senão o campo de secagem lê como repetição de textura
	mascara = MascaraTinta.new(largura_m, altura_m, carimbo, 1300 + indice_parede * 71)

	material = ShaderMaterial.new()
	material.shader = load("res://shaders/tinta_secando.gdshader")
	material.set_shader_parameter("mascara_acumulada", mascara.acumulada)
	material.set_shader_parameter("mascara_recente", mascara.recente)
	material.set_shader_parameter("mascara_historico", mascara.historico)
	material.set_shader_parameter("cor_crua", CorTinta.COR_FUNDO_CRU)
	material.set_shader_parameter("origem_parede", origem)
	material.set_shader_parameter("eixo_u", eixo_u)
	material.set_shader_parameter("eixo_v", eixo_v)
	material.set_shader_parameter("duracao_secagem", tempo_secagem_segundos)
	material.set_shader_parameter("tempo_decorrido", 0.0)

	# ── Campo de secagem (Fase G1) ────────────────────────────────
	material.set_shader_parameter("mancha_secagem", mascara.mancha)
	material.set_shader_parameter("mancha_escala", mascara.mancha_escala)
	material.set_shader_parameter("passo_carimbo_texels", MascaraTinta.passo_carimbo_texels())
	material.set_shader_parameter("cobertura_min", COBERTURA_MIN)
	material.set_shader_parameter("cobertura_max", COBERTURA_MAX)
	material.set_shader_parameter("carga_tipica", CARGA_TIPICA)
	material.set_shader_parameter("espessura_demao", ESPESSURA_DEMAO)
	material.set_shader_parameter("variacao_max", VARIACAO_MAX)
	material.set_shader_parameter("pos_janela", pos_janela)
	material.set_shader_parameter("altura_parede", altura_m)
	material.set_shader_parameter("largura_parede", largura_m)


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


## Tempo até a parede inteira estar seca: a última pincelada acontece no fim da
## janela, e o ponto mais lento ainda leva a secagem dele depois disso.
##
## Isto é ancorado no shader, não estimado, e é o que o `clamp` do campo compra:
## o tempo local é `duracao_secagem * (1 + variacao)` com `variacao` limitada, e
## `k_valor` fecha em FIM_DA_COR.
##
## Usa VARIACAO_CONCLUSAO (percentil), não VARIACAO_MAX (teto) — ver lá em cima.
func duracao_total() -> float:
	return _janela_demao + _duracao_demao * (1.0 + VARIACAO_CONCLUSAO) * FIM_DA_COR


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
	meio: Color,
	seca: Color,
	janela_segundos: float,
	numero_demao: int = 0,
	total_demaos: int = 3
) -> void:
	_janela_demao     = maxf(janela_segundos, 0.01)
	_tempo_decorrido  = 0.0
	_avisou_conclusao = false
	_ativo            = true
	_duracao_demao    = tempo_secagem_segundos * (1.0 + ATRASO_POR_DEMAO * float(numero_demao))

	# A cobertura desta demão entra pro histórico (Fase G3). Tem que ser AQUI:
	# depois de a demão anterior ter terminado e antes de a recente ser limpa.
	mascara.guardar_historico(COBERTURA_MIN, COBERTURA_MAX)
	mascara.limpar_demao()
	material.set_shader_parameter("cor_anterior",    anterior)
	material.set_shader_parameter("cor_molhada",     molhada)
	material.set_shader_parameter("cor_meio",        meio)
	material.set_shader_parameter("cor_seca",        seca)
	material.set_shader_parameter("janela_demao",    _janela_demao)
	material.set_shader_parameter("duracao_secagem", _duracao_demao)
	material.set_shader_parameter("tempo_decorrido", 0.0)
	# Cada demão deixa a superfície mais uniforme — mas só ATRÁS DO ROLO. Os dois
	# valores são o que a parede mostra antes e depois desta camada cobrir; o
	# shader escolhe entre eles pela `cobertura`. Ver `suavidade_anterior` lá.
	material.set_shader_parameter("suavidade_anterior",
		suavidade_marca(numero_demao - 1, total_demaos))
	material.set_shader_parameter("suavidade_demao",
		suavidade_marca(numero_demao, total_demaos))

	# Desloca a amostra da mancha desta demão. Sem isto a 2ª demão secaria com
	# exatamente o mesmo desenho de nuvens da 1ª, e o truque se denunciaria na
	# hora. A margem da textura (MARGEM_MANCHA) é o que deixa deslocar sem wrap.
	var folga: float = 1.0 - mascara.mancha_escala
	material.set_shader_parameter("mancha_offset",
		Vector2(randf() * folga, randf() * folga))


## Quanto da marca do rolo ainda aparece depois da demão `numero` (0 = primeira).
##
## Fecha em ZERO na última: a recompensa de três demãos é a parede ficar lisa.
## A curva antiga era `1 / (1 + n * 0.9)`, que parava em 0,36 na terceira — a
## marca da PRIMEIRA demão continuava aparecendo na parede acabada.
##
## `numero` negativo devolve 1,0 de propósito: é o "antes da 1ª demão", quando o
## que está na parede é reboco cru e nada foi alisado ainda.
static func suavidade_marca(numero: int, total: int) -> float:
	var ultima: float = float(maxi(total - 1, 1))
	return clampf(1.0 - float(numero) / ultima, 0.0, 1.0)


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
