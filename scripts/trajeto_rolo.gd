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

## Uma passada terminou e outra começou (o rolo dobrou a esquina do traço).
## É o gancho de som: `som_pincelada.gd` toca por passada de verdade, em vez de
## por timer fixo de 1,16 s desligado do movimento.
signal passada

## Distância ALVO entre passadas verticais. Precisa ser menor que a largura do
## rolo (23 cm), senão sobra parede crua entre uma passada e a seguinte. 17 cm
## deixa ~25% de sobreposição, que é como se pinta de verdade.
##
## O passo de fato usado é `largura / ceil(largura / isto)`, um pouco menor —
## ver `_passadas_em`. É o que faz a última passada fechar no canto.
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
const LARGURA_TRECHO: float = 1.0

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
var _molhadas: PackedFloat32Array = []    # onde o rolo volta pra bandeja
var _comprimento: float = 0.0
var _largura_m: float = 1.0
var _altura_m: float = 1.0

var _largura_trecho: float = LARGURA_TRECHO
var _n_trechos: int = 1

var _percorrido: float = 0.0
var _proximo_carimbo: float = 0.0  # distância absoluta do próximo carimbo
var _pausa_restante: float = 0.0
var _proxima_molhada: int = 0
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
	_gerar_pontos(invertido)
	_preparado = true


## Quanto esta parede vai levar: caminho ÷ velocidade, mais as paradas na
## bandeja. Chamar depois de `preparar()`.
func duracao_estimada() -> float:
	return _comprimento / VELOCIDADE_ROLO + float(_molhadas.size()) * DURACAO_BANDEJA


func comprimento() -> float:
	return _comprimento


func quantas_molhadas() -> int:
	return _molhadas.size()


## Onde o rolo está agora, em metros a partir do canto de cima da parede.
func posicao_metros() -> Vector2:
	return Vector2(posicao_atual.x * _largura_m, posicao_atual.y * _altura_m)


## Centro do trecho que contém `u_m`. É AQUI que o tio fica de pé — não em cima
## do rolo: um trecho tem 1 m e o braço alcança isso, então ele planta o pé uma
## vez por trecho e trabalha o vão. Seguir o rolo passo a passo faria ele
## bambolear de lado o tempo todo.
func centro_trecho(u_m: float) -> float:
	var i: int = clampi(int(floor(u_m / _largura_trecho)), 0, _n_trechos - 1)
	return (float(i) + 0.5) * _largura_trecho


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
	_proxima_molhada = 0
	while _proxima_molhada < _molhadas.size() and _molhadas[_proxima_molhada] <= _percorrido:
		_proxima_molhada += 1
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

## Trecho a trecho, quatro blocos cada. `invertido` espelha o sentido
## horizontal, que é o lado de onde o tio entra na parede.
func _gerar_pontos(invertido: bool) -> void:
	_pontos = PackedVector2Array()
	_quebras_indice = PackedInt32Array()

	var topo: float = -TRANSBORDO
	var base: float = _altura_m + TRANSBORDO

	_n_trechos = maxi(int(round(_largura_m / LARGURA_TRECHO)), 1)
	_largura_trecho = _largura_m / float(_n_trechos)

	for t in range(_n_trechos):
		var u0: float = _largura_trecho * float(t)
		# a esticada de braço muda a cada trecho: a emenda serrilha
		var fim_topo: float = ALCANCE_TOPO + randf_range(-JITTER_FAIXA, JITTER_FAIXA)
		var inicio_rodape: float = ALCANCE_RODAPE + randf_range(-JITTER_FAIXA, JITTER_FAIXA)
		var meio_topo: float = fim_topo - SOBREPOSICAO_FAIXA
		var meio_base: float = inicio_rodape + SOBREPOSICAO_FAIXA

		_bloco_w(u0, _largura_trecho, meio_topo, meio_base, invertido)
		_bloco_passadas(u0, _largura_trecho, meio_topo, meio_base, invertido)
		_bloco_passadas(u0, _largura_trecho, topo, fim_topo, invertido)
		_bloco_passadas(u0, _largura_trecho, inicio_rodape, base, invertido)

	_medir()


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
func _bloco_passadas(u0: float, largura: float, v_topo: float, v_base: float, invertido: bool) -> void:
	var n: int = _passadas_em(largura)
	var passo: float = largura / float(n)
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


## Passadas distribuídas por igual, a primeira e a última a meio passo da borda.
## Antes o laço só somava PASSO_METROS até estourar a largura, e o resto da
## divisão virava parede crua no canto — 2 cm numa parede de 6 m, que aparecia
## como faixa clara vertical no encontro das paredes.
func _passadas_em(largura: float) -> int:
	return maxi(int(ceil(largura / PASSO_METROS)), 1)


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

	_sortear_molhadas()


# ─── Andar e carimbar ────────────────────────────────────────────────────

func _process(delta: float) -> void:
	if not _ativo:
		return

	if _pausa_restante > 0.0:
		_pausa_restante -= delta
		if _pausa_restante <= 0.0:
			na_bandeja = false
			voltou_da_bandeja.emit()
		return

	var limite: float = _comprimento
	if _proxima_molhada < _molhadas.size():
		limite = _molhadas[_proxima_molhada]

	_percorrido += VELOCIDADE_ROLO * delta
	if _percorrido < limite:
		_carimbar_ate(_percorrido)
		return

	# chegou no fim do trecho ou na hora de molhar
	_percorrido = limite
	_carimbar_ate(_percorrido)
	if _proxima_molhada >= _molhadas.size():
		_ativo = false
		_preparado = false  # a demão seguinte sorteia molhadas novas
		terminou.emit()
	else:
		_proxima_molhada += 1
		_pausa_restante = DURACAO_BANDEJA
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
		no_ar = seg < _transicao.size() and _transicao[seg] == 1
		if not no_ar:
			_parede.mascara.carimbar(
				uv, angulo, _carga_em(_proximo_carimbo), _instante_em(_proximo_carimbo))
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
	var paradas: int = 0
	for m in _molhadas:
		if m <= dist:
			paradas += 1
	var segundos: float = dist / VELOCIDADE_ROLO + float(paradas) * DURACAO_BANDEJA
	return clampf(segundos / maxf(duracao_estimada(), 0.001), 0.0, 1.0)


func _uv(ponto_m: Vector2) -> Vector2:
	return Vector2(ponto_m.x / _largura_m, ponto_m.y / _altura_m)


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
	for m in _molhadas:
		if m > dist:
			break
		inicio = m
	var gasto: float = clampf((dist - inicio) / METROS_POR_CARGA, 0.0, 1.0)
	var queda: float = pow(gasto, EXPOENTE_CARGA) * (CARGA_CHEIA - CARGA_MINIMA)
	return maxf(CARGA_CHEIA - queda, CARGA_MINIMA)


## Onde o tio vai molhar o rolo. Sempre numa QUEBRA de bloco: ele termina o W,
## aí vai à bandeja — não larga meia letra na parede. Escolhe a primeira quebra
## depois da carga ter acabado, com jitter pra não cair sempre no mesmo ponto
## de cada trecho.
func _sortear_molhadas() -> void:
	_molhadas = PackedFloat32Array()
	var ultima: float = 0.0
	var alvo: float = METROS_POR_CARGA * (1.0 + randf_range(-JITTER_CARGA, JITTER_CARGA))
	for q in _quebras:
		if q <= 0.0 or q >= _comprimento:
			continue
		if q - ultima >= alvo:
			_molhadas.append(q)
			ultima = q
			alvo = METROS_POR_CARGA * (1.0 + randf_range(-JITTER_CARGA, JITTER_CARGA))
