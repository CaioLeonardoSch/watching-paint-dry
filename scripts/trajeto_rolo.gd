extends Node
class_name TrajetoRolo

# ─────────────────────────────────────────────
#  TRAJETO DO ROLO — a curva que governa tudo
#
#  A ideia central do overhaul: uma coisa só decide o que acontece na parede,
#  que é por onde o rolo passou. Este nó gera essa curva, vai carimbando a
#  máscara ao longo dela, e é dela que o corpo do tio tira posição, altura da
#  mão e postura (ver `tio.gd::acompanhar_trajeto`).
#
#  Trabalha em METROS, não em UV. Duas razões: o passo entre passadas é uma
#  medida física (tem que ser menor que a largura do rolo), e UV não é
#  isotrópico numa parede 6×3 — andar 0.1 em u é bem mais longe que 0.1 em v.
#  A conversão pra UV acontece só na hora de carimbar.
#
#  ── A coreografia (Fase E, OVERHAUL §5.5) ──
#
#  A parede é dividida em TRECHOS de ~1 m. Cada trecho é pintado em 4 blocos,
#  na ordem em que um pintor de verdade faz:
#
#    1. W        — sobe diagonal, desce reto, sobe diagonal, desce reto.
#                  É o bloco que DEPOSITA a tinta.
#    2. verticais— passadas retas adjacentes, que espalham e uniformizam
#    3. topo     — a faixa que só se alcança em cima do banquinho
#    4. rodapé   — a faixa de baixo, agachado, com traços curtos
#
#  Entre blocos ele vai molhar o rolo na bandeja quando a carga acaba. Isso
#  **não é decoração**: a carga cai por metro rodado (ver CONSUMO_POR_METRO), e
#  é ela que faz a cobertura falhar no fim de cada carga. A ida à bandeja é a
#  motivação diegética da falha, não um número mágico.
#
#  ⚠️ A duração de uma parede é CONSEQUÊNCIA da coreografia, não parâmetro:
#  `duracao_estimada()` = caminho ÷ velocidade + as paradas na bandeja. Antes
#  era `duracao_pintura_segundos = 8.0` fixo, o que punha o rolo a 15,6 m/s
#  (56 km/h). Ver SECAGEM §3.9.
# ─────────────────────────────────────────────

signal terminou
signal foi_molhar    ## rolo saiu da parede rumo à bandeja
signal voltou_da_bandeja

## O tio vai buscar o banquinho e plantar no trecho novo. Vem antes de todo
## bloco do topo — é a faixa que ele não alcança do chão.
signal mudou_banquinho

## Uma passada terminou e outra começou (o rolo dobrou a esquina do traço).
## É o gancho de som: `som_pincelada.gd` toca por passada de verdade, em vez de
## por timer fixo de 1,16 s desligado do movimento.
signal passada

## Distância ALVO entre passadas verticais. Precisa ser menor que a largura do
## rolo (23 cm), senão sobra parede crua entre uma passada e a seguinte. 17 cm
## deixa ~25% de sobreposição, que é como se pinta de verdade.
##
## O passo de fato usado é `largura / ceil(largura / isto)`, um pouco menor, e é
## calculado por COLUNA — ver `_gerar_pontos`. É o que faz a última passada
## fechar no canto em vez de deixar o resto da divisão como parede crua.
const PASSO_METROS: float = 0.17

## Espaçamento entre carimbos ao longo do traço. Metade da faixa de contato
## do rolo (5 cm) garante rastro contínuo sem depositar demais.
const PASSO_CARIMBO: float = 0.025

## Quanto o traço passa DO LADO DE FORA da parede, em cima e embaixo. Negativo
## de propósito: a borda macia do carimbo precisa cair fora da superfície,
## senão a última meia-faixa do rolo aparece como dente claro no encontro com
## teto e rodapé.
const TRANSBORDO: float = 0.03

## Largura de um trecho — o quanto ele pinta sem sair do lugar. ~1 m é o vão
## de braço de quem está de pé com um rolo na mão.
##
## É um ALVO, não uma medida fixa: as bordas de janela e porta viram corte de
## coluna (ver `_cortes_em_u`), e cada pedaço entre dois cortes é dividido no
## número inteiro de trechos que chega mais perto disto.
const LARGURA_TRECHO: float = 1.0

## Faixa de parede curta demais pra valer uma passada de rolo.
##
## Serve pros dois lados do buraco: a tira de 3 cm que sobra embaixo do vão da
## porta (que vai até o chão) não vira bloco, e a coluna que ficaria com meia
## passada de altura some em vez de virar um toque de rolo solto na parede.
const FAIXA_MINIMA: float = 0.12

## Quanto a abertura encolhe no teste de "o rolo está por cima do buraco".
##
## Sem isso o último carimbo de cada passada some: uma passada que termina
## exatamente na borda de cima da janela tem o centro do rolo EM CIMA da borda,
## e `Rect2.has_point` conta a borda de `position` como dentro. O resultado
## seria uma linha crua de 2 cm contornando os dois vãos.
const FOLGA_ABERTURA: float = 0.02

## As três faixas de altura, medidas a partir do TOPO da parede (v cresce pra
## baixo, ver `parede_pintavel.gd::configurar`).
##
## Elas existem porque o corpo do tio tem alcance: `ALCANCE_TOPO` é o quanto
## fica acima da mão dele em pé (precisa do banquinho) e `ALCANCE_RODAPE` é
## onde ele já precisa agachar. Os dois números viram postura em `tio.gd` —
## mudar aqui muda quando ele sobe no banquinho.
const ALCANCE_TOPO: float = 0.62
const ALCANCE_RODAPE: float = 2.52

## Faixas vizinhas se sobrepõem — sem isso o encontro entre duas viraria uma
## linha horizontal crua atravessando a parede inteira, que é o mesmo defeito
## do canto que a G3 fechou, só que deitado.
const SOBREPOSICAO_FAIXA: float = 0.10

## Quanto a altura de cada faixa varia de um trecho pro outro.
##
## A sobreposição resolve o buraco, mas cria o problema oposto: as duas emendas
## viram linhas horizontais RETAS de 6 m, com o dobro de tinta, e linha reta
## perfeita não lê como pintura, lê como bug. Cada trecho é uma esticada de
## braço diferente, então a emenda tem que serrilhar. ±8 cm bastam.
const JITTER_FAIXA: float = 0.08

## Velocidade do rolo na parede.
##
## ⚠️ **Comprimida de propósito, ~2× uma passada real** (um traço de 2 m leva
## ~1 s na mão de um pintor). A conta honesta não fecha com o ritmo decidido: a
## coreografia dá 224 m de caminho por parede, e a 2 m/s isso é uma volta de
## 9,4 min — contra os 3 a 5 min que OVERHAUL §5.6 fixou. Nenhuma parte do
## caminho é gorda (18 m² com rolo de 23 cm e 25% de sobreposição já custam
## 106 m; o W dobra, e dobrar é a técnica). Então a compressão é aqui, no mesmo
## espírito do véu de 0,32 da G2: exagero controlado pra o efeito caber.
const VELOCIDADE_ROLO: float = 3.6

## Quanto ele leva pra ir na bandeja, molhar e voltar. Durante isso o rolo não
## carimba nada e o trajeto fica parado onde estava. A bandeja fica a ~1 m, e
## são dois passos, mergulhar, dois passos.
const DURACAO_BANDEJA: float = 2.4

## Quanto ele leva pra buscar o banquinho, plantar no trecho novo e subir.
##
## ⚠️ Isto é tempo de parede parada, e não é pouco: uma parede tem ~7 trechos,
## então são ~20 s por parede. É o preço de o banquinho deixar de teletransportar
## pro pé dele — antes ele ficava plantado onde estava e o tio atravessava a
## madeira com a canela quando descia pra pintar o meio.
const DURACAO_BANQUINHO: float = 2.8

## Quanto a PRIMEIRA molhada de cada parede dura a mais: é nela que ele despeja
## a lata na bandeja antes de escorrer o rolo. Uma vez por parede — bandeja de
## pintor dá pra várias cargas, e repor a cada ida viraria tique.
const FATOR_REPOR_TINTA: float = 1.7

## Motivo de uma parada. O rolo para do mesmo jeito nos três; o que muda é o que
## o corpo do tio faz durante, e o sinal que sai.
##
## REPOR é uma BANDEJA mais longa: recarrega o rolo igual, e ainda passa pela
## lata. Quem separa os dois é o gesto, não a física.
enum Parada { BANDEJA, BANQUINHO, REPOR }

## A carga cai enquanto pinta e é reposta ao "molhar". Quando está baixa a
## cobertura falha sozinha.
##
## Um rolo de 23 cm segura ~1,5 m² de tinta. Numa parede de 18 m² isso dá **12
## cargas por demão**, e é esse número que é físico — não os metros.
##
## ⚠️ Os 9,0 da G3 estavam certos pro trajeto ANTIGO, que passava na parede uma
## vez só (106 m ÷ 12 = 8,8). A coreografia passa 2,1× no mesmo lugar (o W
## deposita, as verticais espalham), então a MESMA tinta se espalha por 224 m —
## e a carga tem que durar o dobro. Manter 9,0 aqui faria o tio ir à bandeja 24
## vezes por parede pra descarregar tinta que ele não tem.
##
## Com 0,036 por metro a carga cai de 1,00 pra 0,33 ao longo de uma carga, e
## **só o último terço estria** — que era o comportamento calibrado na G3.
const CARGA_CHEIA: float = 1.0
const CARGA_MINIMA: float = 0.30
const METROS_POR_CARGA: float = 18.5

## ⚠️ A carga NÃO cai linear, e isso importa muito na tela.
##
## Com queda linear (o modelo da G3), a carga passa metade do percurso abaixo de
## 0,65 — e como a cobertura satura junto, **um terço da parede inteira** sai
## falhado. Visto na tela: manchões brancos verticais em toda a parede, pior que
## a barra de ponta quadrada que a falha tinha antes.
##
## Rolo de verdade entrega filme parelho quase até o fim e aí despenca: a
## espuma segura a tinta por capilaridade, e o que sai por metro só cai quando o
## reservatório interno acaba. Expoente 3 põe a carga em 0,91 na metade do
## percurso e só derruba nos últimos ~20% — que é a faixa que estria.
const EXPOENTE_CARGA: float = 3.0

## Variação no tamanho de cada carga, pra a falha não sair periódica.
##
## ⚠️ Continua existindo mesmo com a coreografia: as molhadas caem em QUEBRA de
## bloco (fim do W, fim das verticais…), e como os blocos têm tamanhos
## parecidos, sem jitter elas cairiam sempre no mesmo ponto de cada trecho.
const JITTER_CARGA: float = 0.15

## Posição atual do rolo, em UV da parede — é o alvo que a mão do tio persegue.
var posicao_atual: Vector2 = Vector2.ZERO

## Direção do traço agora, no plano da parede. O rolo fica perpendicular a ela.
var direcao_atual: Vector2 = Vector2.DOWN

## true enquanto ele está fora da parede, molhando o rolo.
var na_bandeja: bool = false

## true enquanto ele está buscando e plantando o banquinho.
var mexendo_no_banquinho: bool = false

## Carga do rolo neste instante, 0-1. Sai daqui pro visual do rolo (espuma
## escorrida) além de já mandar na cobertura da máscara.
var carga_atual: float = CARGA_CHEIA

## true enquanto o rolo viaja de um bloco pro outro sem encostar na parede.
## O corpo do tio usa isto pra afastar o rolo da superfície.
var no_ar: bool = false

var _parede: ParedePintavel
var _pontos: PackedVector2Array = []      # em metros, origem no canto de cima
var _acumulado: PackedFloat32Array = []   # distância acumulada até cada ponto
var _quebras_indice: PackedInt32Array = []   # onde um bloco termina (índice)
var _quebras: PackedFloat32Array = []        # …a mesma coisa, em distância
## Por segmento: 1 = o rolo está NO AR indo de um bloco pro outro, e não pinta.
var _transicao: PackedByteArray = []
## Onde o rolo para, em distância percorrida, em ordem. Molhar na bandeja e
## buscar o banquinho entram na MESMA lista: as duas são segundos em que a
## parede não recebe tinta, e `_instante_em` precisa contar as duas ou o relógio
## de secagem discorda do que se viu na tela.
var _paradas: PackedFloat32Array = []
var _tipos_parada: PackedByteArray = []
var _duracoes_parada: PackedFloat32Array = []

## Índice do primeiro ponto de cada bloco do topo — vira parada de banquinho em
## `_medir`, quando as distâncias existem.
var _inicios_topo: PackedInt32Array = []
var _comprimento: float = 0.0
var _largura_m: float = 1.0
var _altura_m: float = 1.0

## Bordas de todos os trechos, em metros e em ordem, no espaço NÃO espelhado.
## Sempre começa em 0 e termina na largura da parede. É o que `centro_trecho`
## consulta — os trechos deixaram de ter largura uniforme quando as aberturas
## passaram a cortar colunas.
var _bordas_trecho: PackedFloat32Array = []
var _invertido: bool = false

## Aberturas da parede já encolhidas por FOLGA_ABERTURA, prontas pro teste.
var _buracos: Array[Rect2] = []

var _percorrido: float = 0.0
var _proximo_carimbo: float = 0.0  # distância absoluta do próximo carimbo
var _pausa_restante: float = 0.0
var _pausa_total: float = 0.0
var _proxima_parada: int = 0
var _segmento_anterior: int = -1
var _ativo: bool = false
var _preparado: bool = false


## Monta o trajeto sem começar a pintar. Quem chama precisa disto pra perguntar
## `duracao_estimada()` ANTES de `parede.iniciar_demao()` — a janela da demão é
## a duração da pintura, e ela agora sai daqui.
##
## ⚠️ Idempotente de propósito: `pintar()` também chama, e se regerasse o
## caminho as molhadas seriam re-sorteadas — a duração que quem chamou já usou
## pra abrir a demão deixaria de bater com a que vai acontecer. O flag cai
## quando a parede termina, então a demão seguinte sorteia de novo (a falha não
## pode cair no mesmo lugar toda demão, senão vira listra permanente).
func preparar(parede: ParedePintavel, invertido: bool = false) -> void:
	if _preparado and _parede == parede:
		return
	_parede    = parede
	_largura_m = maxf(parede.mascara.largura_m, 0.1)
	_altura_m  = maxf(parede.mascara.altura_m, 0.1)
	_invertido = invertido
	_buracos = []
	for abertura in parede.aberturas:
		_buracos.append(abertura.grow(-FOLGA_ABERTURA))
	_gerar_pontos(invertido)
	_preparado = true


## Quanto esta parede vai levar: caminho ÷ velocidade, mais TODAS as paradas.
## Chamar depois de `preparar()`.
func duracao_estimada() -> float:
	var parado: float = 0.0
	for d in _duracoes_parada:
		parado += d
	return _comprimento / VELOCIDADE_ROLO + parado


func comprimento() -> float:
	return _comprimento


func quantas_molhadas() -> int:
	return _quantas_do_tipo(Parada.BANDEJA) + _quantas_do_tipo(Parada.REPOR)


## true se a parada de agora é a que também repõe tinta da lata. O corpo do tio
## usa pra acrescentar o gesto de despejar sem mudar o resto.
func repondo_tinta() -> bool:
	var i: int = _proxima_parada - 1
	if i < 0 or i >= _tipos_parada.size():
		return false
	return _tipos_parada[i] == Parada.REPOR


func quantas_mudancas_de_banquinho() -> int:
	return _quantas_do_tipo(Parada.BANQUINHO)


func _quantas_do_tipo(tipo: int) -> int:
	var n: int = 0
	for t in _tipos_parada:
		if t == tipo:
			n += 1
	return n


## Quanto da parada atual já passou, de 0 a 1. É por onde o corpo do tio sabe em
## que ponto do gesto ele está (mergulhar o rolo, largar o banquinho…) sem
## precisar de um Tween próprio disputando as mesmas propriedades.
func fracao_da_parada() -> float:
	if _pausa_total <= 0.0:
		return 1.0
	return clampf(1.0 - _pausa_restante / _pausa_total, 0.0, 1.0)


## Onde o rolo está agora, em metros a partir do canto de cima da parede.
func posicao_metros() -> Vector2:
	return Vector2(posicao_atual.x * _largura_m, posicao_atual.y * _altura_m)


## Centro do trecho que contém `u_m`. É AQUI que o tio fica de pé — não em cima
## do rolo: um trecho tem ~1 m e o braço alcança isso, então ele planta o pé uma
## vez por trecho e trabalha o vão. Seguir o rolo passo a passo faria ele
## bambolear de lado o tempo todo.
##
## ⚠️ Deixou de ser `floor(u / largura_trecho)` na rodada das aberturas: com as
## bordas de janela e porta cortando colunas, os trechos não têm mais a mesma
## largura. A busca é na lista de bordas, e o espelhamento entra e sai aqui —
## `_bordas_trecho` mora no espaço não espelhado.
func centro_trecho(u_m: float) -> float:
	if _bordas_trecho.size() < 2:
		return u_m
	var u: float = (_largura_m - u_m) if _invertido else u_m
	var centro: float = (_bordas_trecho[0] + _bordas_trecho[1]) * 0.5
	for i in range(_bordas_trecho.size() - 1):
		centro = (_bordas_trecho[i] + _bordas_trecho[i + 1]) * 0.5
		if u <= _bordas_trecho[i + 1]:
			break
	return (_largura_m - centro) if _invertido else centro


## Pinta a parede inteira, no ritmo da coreografia. Devolve quando termina —
## quem chama pode rodar isto em paralelo com a animação do tio.
## `de_fracao` permite continuar de um trecho já pintado (a abertura começa
## com o tio quase terminando o serviço).
func pintar(parede: ParedePintavel, invertido: bool = false, de_fracao: float = 0.0) -> void:
	preparar(parede, invertido)
	if _pontos.size() < 2:
		terminou.emit()
		return

	var inicio: float = clampf(de_fracao, 0.0, 1.0)
	# retoma do ponto onde o instantâneo parou, sem recarimbar o que já existe
	_percorrido = inicio * _comprimento
	_proximo_carimbo = _percorrido
	_pausa_restante = 0.0
	na_bandeja = false
	mexendo_no_banquinho = false
	_proxima_parada = 0
	while _proxima_parada < _paradas.size() and _paradas[_proxima_parada] <= _percorrido:
		_proxima_parada += 1
	posicao_atual = _uv(_ponto_em(_percorrido))

	_ativo = true
	await terminou


## Carimba o trajeto de uma vez só, sem animar. Usado na abertura, onde 3
## paredes já foram pintadas antes de o jogador chegar — elas precisam ter a
## marca de rolo de verdade, não cor chapada.
##
## O instante sai da MESMA função que o modo animado (`_instante_em`). Gravar
## um valor fixo criava um degrau no relógio de secagem exatamente onde o trecho
## instantâneo encontrava o animado: metade da parede começava a secar junta e a
## outra metade escalonada, e a emenda aparecia como divisão vertical nítida.
func pintar_instantaneo(
	parede: ParedePintavel,
	invertido: bool = false,
	ate_fracao: float = 1.0
) -> void:
	preparar(parede, invertido)
	if _pontos.size() < 2:
		return
	_proximo_carimbo = 0.0
	_carimbar_ate(clampf(ate_fracao, 0.0, 1.0) * _comprimento)
	if ate_fracao >= 1.0:
		_preparado = false


# ─── Geração da coreografia ──────────────────────────────────────────────

## Coluna a coluna, trecho a trecho, faixa a faixa. `invertido` espelha o
## sentido horizontal, que é o lado de onde o tio entra na parede.
##
## As COLUNAS são o que a rodada das aberturas acrescentou: a parede é cortada
## em u nas bordas de cada buraco, de modo que dentro de uma coluna a altura de
## parede sólida é sempre a mesma. Sem esse corte, um trecho de 1 m poderia ter
## a metade esquerda inteira e a direita só acima da porta — e aí cada passada
## precisaria de um limite próprio.
func _gerar_pontos(invertido: bool) -> void:
	_pontos = PackedVector2Array()
	_quebras_indice = PackedInt32Array()
	_inicios_topo = PackedInt32Array()
	_bordas_trecho = PackedFloat32Array([0.0])

	var cortes: PackedFloat32Array = _cortes_em_u()
	for c in range(cortes.size() - 1):
		var col0: float = cortes[c]
		var col1: float = cortes[c + 1]
		var faixas: Array[Vector2] = _faixas_solidas(col0, col1)
		var largura_col: float = col1 - col0

		# ⚠️ O número de passadas é decidido pela COLUNA, não pelo trecho, e os
		# trechos só repartem essas passadas. Fazendo por trecho, o
		# arredondamento pra cima acontece uma vez por trecho: a parede leste
		# saiu com 232 m de caminho contra 223 m da norte, sendo que ela tem 2 m²
		# a MENOS de parede. Repartir a conta da coluna zera essa sobra.
		var n_passadas: int = maxi(int(ceil(largura_col / PASSO_METROS)), 1)
		var passo: float = largura_col / float(n_passadas)
		var n_trechos: int = clampi(int(round(largura_col / LARGURA_TRECHO)), 1, n_passadas)

		var feitas: int = 0
		for t in range(n_trechos):
			var ate: int = n_passadas * (t + 1) / n_trechos
			var quantas: int = ate - feitas
			var u0: float = col0 + float(feitas) * passo
			var largura_trecho: float = float(quantas) * passo
			feitas = ate
			_bordas_trecho.append(u0 + largura_trecho)
			for faixa in faixas:
				_pintar_faixa(u0, largura_trecho, quantas, faixa.x, faixa.y, invertido)

	_medir()


## Onde a parede é cortada em colunas: as duas pontas e a borda de cada buraco.
##
## Devolve sempre em ordem e sem repetição. Uma abertura encostada no canto não
## gera coluna de largura zero — o filtro de `FAIXA_MINIMA` come o corte.
func _cortes_em_u() -> PackedFloat32Array:
	var brutos: Array[float] = [0.0, _largura_m]
	for abertura in _buracos:
		brutos.append(clampf(abertura.position.x, 0.0, _largura_m))
		brutos.append(clampf(abertura.end.x, 0.0, _largura_m))
	brutos.sort()

	var cortes := PackedFloat32Array([brutos[0]])
	for u in brutos:
		if u - cortes[cortes.size() - 1] > FAIXA_MINIMA:
			cortes.append(u)
	# a última coluna sempre fecha na borda da parede, mesmo que a sobra seja
	# menor que FAIXA_MINIMA — parede crua no canto aparece
	cortes[cortes.size() - 1] = _largura_m
	return cortes


## As faixas de parede SÓLIDA na coluna [u0, u1], de cima pra baixo, em metros.
##
## Sem buraco nenhum devolve uma faixa só, do transbordo de cima ao de baixo —
## que é exatamente o que existia antes desta rodada. Com buraco, a faixa é
## partida em duas (acima e abaixo dele) e o transbordo NÃO acompanha: a passada
## termina rente ao vão, e é a borda macia do carimbo que fecha o encontro.
func _faixas_solidas(u0: float, u1: float) -> Array[Vector2]:
	var faixas: Array[Vector2] = [Vector2(-TRANSBORDO, _altura_m + TRANSBORDO)]
	var meio_u: float = (u0 + u1) * 0.5

	for abertura in _buracos:
		if meio_u <= abertura.position.x or meio_u >= abertura.end.x:
			continue
		var novas: Array[Vector2] = []
		for f in faixas:
			var acima: float = minf(f.y, abertura.position.y)
			if acima - f.x > FAIXA_MINIMA:
				novas.append(Vector2(f.x, acima))
			var abaixo: float = maxf(f.x, abertura.end.y)
			if f.y - abaixo > FAIXA_MINIMA:
				novas.append(Vector2(abaixo, f.y))
		faixas = novas

	return faixas


## A coreografia de um trecho dentro de uma faixa de parede sólida [a, b]:
## W, verticais do meio, faixa do topo, rodapé.
##
## Os limites das três alturas são os mesmos de sempre, só que APARADOS pela
## faixa. É isso que faz a coluna acima da porta não ter rodapé e a coluna
## abaixo da janela não ter faixa de topo — sem `if` sobre "que pedaço é este",
## e o tio herda de graça: ele não agacha onde não há rodapé pra pintar, porque
## o rolo nunca desce até lá.
func _pintar_faixa(
	u0: float, largura: float, passadas: int, a: float, b: float, invertido: bool
) -> void:
	# a esticada de braço muda a cada trecho: a emenda serrilha
	var fim_topo: float = ALCANCE_TOPO + randf_range(-JITTER_FAIXA, JITTER_FAIXA)
	var inicio_rodape: float = ALCANCE_RODAPE + randf_range(-JITTER_FAIXA, JITTER_FAIXA)

	var meio_topo: float = clampf(fim_topo - SOBREPOSICAO_FAIXA, a, b)
	var meio_base: float = clampf(inicio_rodape + SOBREPOSICAO_FAIXA, a, b)
	if meio_base - meio_topo > FAIXA_MINIMA:
		_bloco_w(u0, largura, meio_topo, meio_base, invertido)
		_bloco_passadas(u0, largura, passadas, meio_topo, meio_base, invertido)

	var topo_fim: float = clampf(fim_topo, a, b)
	if topo_fim - a > FAIXA_MINIMA:
		# guarda o índice ANTES de gerar: vira parada de banquinho em `_medir`
		_inicios_topo.append(_pontos.size())
		_bloco_passadas(u0, largura, passadas, a, topo_fim, invertido)

	var rodape_inicio: float = clampf(inicio_rodape, a, b)
	if b - rodape_inicio > FAIXA_MINIMA:
		_bloco_passadas(u0, largura, passadas, rodape_inicio, b, invertido)


## O W: sobe na diagonal, desce reto, sobe na diagonal, desce reto. É o bloco
## que deposita — por isso ele vem antes das verticais, que só espalham.
func _bloco_w(u0: float, largura: float, v_topo: float, v_base: float, invertido: bool) -> void:
	var pernas: Array[Vector2] = [
		Vector2(0.00, 1.0), Vector2(0.35, 0.0), Vector2(0.35, 1.0),
		Vector2(0.70, 0.0), Vector2(0.70, 1.0), Vector2(1.00, 0.0),
	]
	for p in pernas:
		var u: float = u0 + p.x * largura
		_pontos.append(Vector2(_espelhar(u, invertido), lerpf(v_topo, v_base, p.y)))
	_fechar_bloco()


## Passadas verticais adjacentes cobrindo [v_topo, v_base] dentro do trecho.
## Serve pros três blocos retos: verticais do meio, topo e rodapé — o que muda
## entre eles é só a faixa de altura (e, do lado do tio, a postura).
##
## `n` vem de fora (da coluna) e não é recalculado aqui: ver o aviso em
## `_gerar_pontos` sobre arredondar passada uma vez por trecho.
func _bloco_passadas(
	u0: float, largura: float, n: int, v_topo: float, v_base: float, invertido: bool
) -> void:
	var passo: float = largura / float(maxi(n, 1))
	var descendo := true
	for i in range(n):
		var u: float = _espelhar(u0 + passo * (float(i) + 0.5), invertido)
		if descendo:
			_pontos.append(Vector2(u, v_topo))
			_pontos.append(Vector2(u, v_base))
		else:
			_pontos.append(Vector2(u, v_base))
			_pontos.append(Vector2(u, v_topo))
		descendo = not descendo
	_fechar_bloco()


func _espelhar(u: float, invertido: bool) -> float:
	return _largura_m - u if invertido else u


## Marca fim de bloco. É onde a ida à bandeja pode acontecer: interromper no
## meio de um W deixaria meia letra na parede.
func _fechar_bloco() -> void:
	if not _pontos.is_empty():
		_quebras_indice.append(_pontos.size() - 1)


## Pré-calcula a distância acumulada pra conseguir andar em velocidade
## constante depois (sem isso, passadas de tamanhos diferentes andariam em
## ritmos diferentes e o rolo "descolaria" do tempo).
func _medir() -> void:
	_acumulado = PackedFloat32Array()
	_acumulado.resize(_pontos.size())
	if _pontos.is_empty():
		_comprimento = 0.0
		return
	_acumulado[0] = 0.0
	var total: float = 0.0
	for i in range(1, _pontos.size()):
		total += _pontos[i].distance_to(_pontos[i - 1])
		_acumulado[i] = total
	_comprimento = total

	_quebras = PackedFloat32Array()
	for i in _quebras_indice:
		_quebras.append(_acumulado[i])

	# ⚠️ O segmento que LIGA dois blocos é viagem, não pintura. Sem isto o rolo
	# ia riscando a parede no caminho do fim das verticais até o começo do topo
	# — diagonais compridas atravessando a faixa de cima, bem visíveis na
	# máscara. Achado olhando o PNG; nenhum número do teste acusava, porque
	# cobertura e depósito médio até MELHORAM com uma risca a mais.
	_transicao = PackedByteArray()
	_transicao.resize(_pontos.size())
	for i in _quebras_indice:
		var seguinte: int = i + 1
		if seguinte < _transicao.size():
			_transicao[seguinte] = 1

	_sortear_paradas()


# ─── Andar e carimbar ────────────────────────────────────────────────────

func _process(delta: float) -> void:
	if not _ativo:
		return

	if _pausa_restante > 0.0:
		_pausa_restante -= delta
		if _pausa_restante <= 0.0:
			if na_bandeja:
				voltou_da_bandeja.emit()
			na_bandeja = false
			mexendo_no_banquinho = false
			_pausa_total = 0.0
		return

	var limite: float = _comprimento
	if _proxima_parada < _paradas.size():
		limite = _paradas[_proxima_parada]

	_percorrido += VELOCIDADE_ROLO * delta
	if _percorrido < limite:
		_carimbar_ate(_percorrido)
		return

	# chegou no fim da parede, ou na hora de parar por algum motivo
	_percorrido = limite
	_carimbar_ate(_percorrido)
	if _proxima_parada >= _paradas.size():
		_ativo = false
		_preparado = false  # a demão seguinte sorteia molhadas novas
		terminou.emit()
		return

	var tipo: int = _tipos_parada[_proxima_parada]
	_pausa_total = _duracoes_parada[_proxima_parada]
	_pausa_restante = _pausa_total
	_proxima_parada += 1
	if tipo == Parada.BANQUINHO:
		mexendo_no_banquinho = true
		mudou_banquinho.emit()
	else:
		na_bandeja = true
		foi_molhar.emit()


## Carimba em posições ABSOLUTAS ao longo do trajeto, em passos fixos.
##
## O detalhe que importa: o espaçamento não pode depender de como o caminho foi
## fatiado. Antes cada chamada carimbava nas duas pontas do pedaço que recebia,
## então o trecho animado (fatiado a cada frame) depositava bem mais tinta que o
## instantâneo (fatiado por segmento) — dava pra ver a emenda na parede.
func _carimbar_ate(alvo: float) -> void:
	while _proximo_carimbo <= alvo:
		var p := _ponto_em(_proximo_carimbo)
		var dir := _direcao_em(_proximo_carimbo)
		var seg: int = _segmento_em(_proximo_carimbo)
		if seg != _segmento_anterior:
			_segmento_anterior = seg
			passada.emit()
		# o rolo fica perpendicular ao movimento: descida deixa ele deitado
		var angulo: float = atan2(dir.y, dir.x) + PI * 0.5
		var uv := _uv(p)
		# A viagem entre blocos já não pinta; a abertura entra na MESMA porta.
		# O caminho gerado não passa por dentro de um buraco, mas a diagonal que
		# liga dois blocos passa — e é justamente ela que atravessa o vão da
		# porta. Cinto e suspensório de propósito: `no_ar` também é o que faz o
		# tio afastar o rolo da parede, então ele levanta o rolo pra cruzar.
		no_ar = (seg < _transicao.size() and _transicao[seg] == 1) or _sobre_abertura(p)
		carga_atual = _carga_em(_proximo_carimbo)
		if not no_ar:
			_parede.mascara.carimbar(
				uv, angulo, carga_atual, _instante_em(_proximo_carimbo))
		posicao_atual = uv
		direcao_atual = dir
		_proximo_carimbo += PASSO_CARIMBO


## Instante em que um ponto do trajeto foi pintado, de 0 a 1 da janela da demão.
##
## ⚠️ Conta o TEMPO, não a distância: as paradas na bandeja são segundos em que
## o rolo não anda, e ignorá-las faria o relógio de secagem discordar do que se
## viu na tela — justamente o que a emenda instantâneo/animado já ensinou a não
## fazer. Por isso as duas rotas de carimbo chamam esta mesma função.
func _instante_em(dist: float) -> float:
	var parado: float = 0.0
	for i in range(_paradas.size()):
		if _paradas[i] > dist:
			break
		parado += _duracoes_parada[i]
	var segundos: float = dist / VELOCIDADE_ROLO + parado
	return clampf(segundos / maxf(duracao_estimada(), 0.001), 0.0, 1.0)


func _uv(ponto_m: Vector2) -> Vector2:
	return Vector2(ponto_m.x / _largura_m, ponto_m.y / _altura_m)


## O rolo está por cima de um vão? `ponto_m` já vem espelhado, então o teste
## desespelha antes — as aberturas são medidas da parede, não do caminho.
func _sobre_abertura(ponto_m: Vector2) -> bool:
	if _buracos.is_empty():
		return false
	var u: float = (_largura_m - ponto_m.x) if _invertido else ponto_m.x
	var ponto := Vector2(u, ponto_m.y)
	for abertura in _buracos:
		if abertura.has_point(ponto):
			return true
	return false


## Índice do segmento que contém uma distância percorrida.
func _segmento_em(dist: float) -> int:
	var i: int = 1
	while i < _acumulado.size() - 1 and _acumulado[i] < dist:
		i += 1
	return i


func _ponto_em(dist: float) -> Vector2:
	if _pontos.size() < 2:
		return Vector2.ZERO
	if dist <= 0.0:
		return _pontos[0]
	if dist >= _comprimento:
		return _pontos[_pontos.size() - 1]

	var i: int = _segmento_em(dist)
	var d0: float = _acumulado[i - 1]
	var d1: float = _acumulado[i]
	var t: float = 0.0 if is_equal_approx(d1, d0) else (dist - d0) / (d1 - d0)
	return _pontos[i - 1].lerp(_pontos[i], t)


func _direcao_em(dist: float) -> Vector2:
	if _pontos.size() < 2:
		return Vector2.DOWN
	var i: int = _segmento_em(clampf(dist, 0.0, _comprimento))
	var d := _pontos[i] - _pontos[i - 1]
	return d.normalized() if d.length_squared() > 0.0 else Vector2.DOWN


## Carga do rolo em função de quanto já rodou desde a última molhada. Cai
## enquanto pinta e volta ao cheio ao molhar — o dente de serra é o que faz a
## cobertura falhar de forma irregular em vez de uniforme.
func _carga_em(dist: float) -> float:
	var inicio: float = 0.0
	for i in range(_paradas.size()):
		if _paradas[i] > dist:
			break
		# só molhar recarrega o rolo; buscar o banquinho não repõe tinta
		if _tipos_parada[i] != Parada.BANQUINHO:
			inicio = _paradas[i]
	var gasto: float = clampf((dist - inicio) / METROS_POR_CARGA, 0.0, 1.0)
	var queda: float = pow(gasto, EXPOENTE_CARGA) * (CARGA_CHEIA - CARGA_MINIMA)
	return maxf(CARGA_CHEIA - queda, CARGA_MINIMA)


## Onde o tio vai molhar o rolo. Sempre numa QUEBRA de bloco: ele termina o W,
## aí vai à bandeja — não larga meia letra na parede. Escolhe a primeira quebra
## depois da carga ter acabado, com jitter pra não cair sempre no mesmo ponto
## de cada trecho.
func _sortear_paradas() -> void:
	# 1) onde ele vai molhar o rolo
	var molhadas := PackedFloat32Array()
	var ultima: float = 0.0
	var alvo: float = METROS_POR_CARGA * (1.0 + randf_range(-JITTER_CARGA, JITTER_CARGA))
	for q in _quebras:
		if q <= 0.0 or q >= _comprimento:
			continue
		if q - ultima >= alvo:
			molhadas.append(q)
			ultima = q
			alvo = METROS_POR_CARGA * (1.0 + randf_range(-JITTER_CARGA, JITTER_CARGA))

	# 2) onde ele vai buscar o banquinho: no fim do bloco ANTERIOR ao do topo,
	#    porque ele precisa do banquinho plantado antes de começar a faixa alta
	var banquinhos := PackedFloat32Array()
	for i in _inicios_topo:
		var antes: int = i - 1
		if antes <= 0 or antes >= _acumulado.size():
			continue
		banquinhos.append(_acumulado[antes])

	# 3) mistura as duas em ordem de distância
	_paradas = PackedFloat32Array()
	_tipos_parada = PackedByteArray()
	_duracoes_parada = PackedFloat32Array()
	var a: int = 0
	var b: int = 0
	while a < molhadas.size() or b < banquinhos.size():
		var pega_molhada: bool = b >= banquinhos.size()
		if a < molhadas.size() and b < banquinhos.size():
			pega_molhada = molhadas[a] <= banquinhos[b]
		if pega_molhada:
			var primeira: bool = a == 0
			_paradas.append(molhadas[a])
			_tipos_parada.append(Parada.REPOR if primeira else Parada.BANDEJA)
			_duracoes_parada.append(DURACAO_BANDEJA * (FATOR_REPOR_TINTA if primeira else 1.0))
			a += 1
		else:
			_paradas.append(banquinhos[b])
			_tipos_parada.append(Parada.BANQUINHO)
			_duracoes_parada.append(DURACAO_BANQUINHO)
			b += 1
