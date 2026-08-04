extends Node
class_name TrajetoRolo

# ─────────────────────────────────────────────
#  TRAJETO DO ROLO — a curva que governa tudo
#
#  A ideia central do overhaul: uma coisa só decide o que acontece na parede,
#  que é por onde o rolo passou. Este nó gera essa curva e vai carimbando a
#  máscara ao longo dela, em velocidade constante.
#
#  Trabalha em METROS, não em UV. Duas razões: o passo entre passadas é uma
#  medida física (tem que ser menor que a largura do rolo), e UV não é
#  isotrópico numa parede 7×3 — andar 0.1 em u é bem mais longe que 0.1 em v.
#  A conversão pra UV acontece só na hora de carimbar.
#
#  Hoje o trajeto é um zigue-zague vertical simples — já muito mais honesto
#  que a varredura em linha reta do sistema antigo, e suficiente pra validar
#  a máscara. A coreografia rica (W de deposição, verticais de espalhamento,
#  banquinho pro alto, agachar no rodapé, ida à bandeja) é a Fase E do plano,
#  e entra reescrevendo só `_gerar_pontos()`.
#
#  Quando o rig com IK existir (Fase D), `posicao_atual` vira o alvo que a
#  mão do tio persegue — daí o braço e a tinta passam a ser a mesma coisa,
#  em vez de duas animações sincronizadas na sorte.
# ─────────────────────────────────────────────

signal terminou

## Distância ALVO entre passadas verticais. Precisa ser menor que a largura do
## rolo (23 cm), senão sobra parede crua entre uma passada e a seguinte. 17 cm
## deixa ~25% de sobreposição, que é como se pinta de verdade.
##
## O passo de fato usado é `largura / ceil(largura / isto)`, um pouco menor —
## ver `_gerar_pontos`. É o que faz a última passada fechar no canto.
const PASSO_METROS: float = 0.17

## Espaçamento entre carimbos ao longo do traço. Metade da faixa de contato
## do rolo (5 cm) garante rastro contínuo sem depositar demais.
const PASSO_CARIMBO: float = 0.025

## Quanto o traço passa DO LADO DE FORA da parede, em cima e embaixo. Negativo
## de propósito: a borda macia do carimbo precisa cair fora da superfície,
## senão a última meia-faixa do rolo aparece como dente claro no encontro com
## teto e rodapé. O acabamento de verdade (banquinho no alto, agachado no
## rodapé) é Fase E.
const TRANSBORDO: float = 0.03

## A carga cai enquanto pinta e é reposta ao "molhar". Quando está baixa a
## cobertura falha sozinha — a falha vira motivação diegética pra ir à
## bandeja, em vez de um número mágico.
##
## Números da Fase G3, agora físicos. Um rolo de 23 cm segura ~1,5 m² de tinta,
## que a 17 cm de passo são ~9 m de trajeto. Com 0,070 por metro a carga cai de
## 1,00 pra 0,37 ao longo de uma carga, e **só o último terço estria**.
##
## Antes eram 14 m e 0,013: a carga caía de 1,00 pra 0,82, nunca chegava perto
## do limiar do shader, e a falha de cobertura ficava inerte — era um dos três
## "inertes" anotados no PROJETO.md 3.4. `CARGA_MINIMA` também era inalcançável
## em 0,80; agora ela é um piso de verdade, que o jitter às vezes encosta.
const CARGA_CHEIA: float = 1.0
const CARGA_MINIMA: float = 0.30
const CONSUMO_POR_METRO: float = 0.070
const METROS_POR_CARGA: float = 9.0

## Variação no tamanho de cada carga. Sem ela, molhar a cada 9 m exatos desenha
## uma listra periódica na parede — o olho pega repetição regular na hora. Sai
## quando a Fase E puser as idas à bandeja na coreografia de verdade; até lá é
## isto que faz a falha parecer acidente em vez de padrão.
const JITTER_CARGA: float = 0.15

## Posição atual do rolo, em UV da parede. Vira o alvo de IK na Fase D.
var posicao_atual: Vector2 = Vector2.ZERO

var _parede: ParedePintavel
var _pontos: PackedVector2Array = []      # em metros, origem no canto de cima
var _acumulado: PackedFloat32Array = []   # distância acumulada até cada ponto
var _molhadas: PackedFloat32Array = []    # onde o rolo volta pra bandeja
var _comprimento: float = 0.0
var _largura_m: float = 1.0
var _altura_m: float = 1.0

var _duracao: float = 1.0
var _tempo: float = 0.0
var _proximo_carimbo: float = 0.0  # distância absoluta do próximo carimbo
var _ativo: bool = false


## Pinta uma parede inteira em `duracao` segundos. Devolve quando termina —
## quem chama pode rodar isto em paralelo com a animação do tio.
## `de_fracao` permite continuar de um trecho já pintado (a abertura começa
## com o tio no meio do serviço).
func pintar(parede: ParedePintavel, duracao: float, invertido: bool = false, de_fracao: float = 0.0) -> void:
	_preparar(parede, invertido)
	if _pontos.size() < 2:
		terminou.emit()
		return

	var inicio: float = clampf(de_fracao, 0.0, 1.0)
	_duracao = maxf(duracao, 0.01)
	_tempo   = inicio * _duracao
	# retoma do ponto onde o instantâneo parou, sem recarimbar o que já existe
	_proximo_carimbo = inicio * _comprimento
	posicao_atual = _uv(_ponto_em(_proximo_carimbo))

	_ativo = true
	await terminou


## Carimba o trajeto de uma vez só, sem animar. Usado na abertura, onde 3
## paredes já foram pintadas antes de o jogador chegar — elas precisam ter a
## marca de rolo de verdade, não cor chapada.
##
## O instante é gravado PROPORCIONAL ao progresso do trajeto, igual ao modo
## animado. Gravar um valor fixo criava um degrau no relógio de secagem
## exatamente onde o trecho instantâneo encontrava o animado: metade da parede
## começava a secar junta e a outra metade escalonada, e a emenda aparecia como
## uma divisão vertical nítida no meio da parede.
func pintar_instantaneo(
	parede: ParedePintavel,
	invertido: bool = false,
	ate_fracao: float = 1.0
) -> void:
	_preparar(parede, invertido)
	if _pontos.size() < 2:
		return
	_proximo_carimbo = 0.0
	_carimbar_ate(clampf(ate_fracao, 0.0, 1.0) * _comprimento, -1.0)


func _preparar(parede: ParedePintavel, invertido: bool) -> void:
	_parede    = parede
	_largura_m = maxf(parede.mascara.largura_m, 0.1)
	_altura_m  = maxf(parede.mascara.altura_m, 0.1)
	_gerar_pontos(invertido)


## Zigue-zague vertical: desce numa coluna, sobe na seguinte. O sentido
## horizontal acompanha o lado de onde o tio entra na parede.
func _gerar_pontos(invertido: bool) -> void:
	_pontos = PackedVector2Array()

	var topo: float = -TRANSBORDO
	var base: float = _altura_m + TRANSBORDO

	# Passadas distribuídas por igual entre os dois cantos, a primeira e a última
	# a meio passo da borda. Antes o laço só somava PASSO_METROS até estourar a
	# largura, e o resto da divisão virava parede crua no canto final — 2 cm numa
	# parede de 6 m, que aparecia como faixa clara vertical no encontro das
	# paredes. O passo efetivo fica um pouco menor que PASSO_METROS, o que só
	# aumenta a sobreposição.
	var n_passadas: int = maxi(int(ceil(_largura_m / PASSO_METROS)), 1)
	var passo: float = _largura_m / float(n_passadas)

	var descendo := true
	for i in range(n_passadas):
		var x: float = passo * (float(i) + 0.5)
		var u: float = _largura_m - x if invertido else x
		if descendo:
			_pontos.append(Vector2(u, topo))
			_pontos.append(Vector2(u, base))
		else:
			_pontos.append(Vector2(u, base))
			_pontos.append(Vector2(u, topo))
		descendo = not descendo

	_medir()


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
	_sortear_molhadas()


func _process(delta: float) -> void:
	if not _ativo:
		return

	_tempo += delta
	var fracao: float = clampf(_tempo / _duracao, 0.0, 1.0)
	# -1 = deriva o instante da posição, mesma fórmula do modo instantâneo.
	# Os dois PRECISAM concordar, senão a emenda entre eles vira degrau.
	_carimbar_ate(fracao * _comprimento, -1.0)

	if fracao >= 1.0:
		_ativo = false
		terminou.emit()


## Carimba em posições ABSOLUTAS ao longo do trajeto, em passos fixos.
##
## O detalhe que importa: o espaçamento não pode depender de como o caminho
## foi fatiado. Antes cada chamada carimbava nas duas pontas do pedaço que
## recebia, então o trecho animado (fatiado a cada frame) depositava bem mais
## tinta que o trecho instantâneo (fatiado por segmento) — dava pra ver a
## emenda na parede, mais grossa de um lado.
## `instante` negativo = derivar da posição no trajeto. É o que mantém o
## relógio de secagem contínuo quando um trecho é carimbado de uma vez e o
## seguinte é animado.
func _carimbar_ate(alvo: float, instante: float) -> void:
	while _proximo_carimbo <= alvo:
		var p := _ponto_em(_proximo_carimbo)
		var dir := _direcao_em(_proximo_carimbo)
		# o rolo fica perpendicular ao movimento: descida deixa ele deitado
		var angulo: float = atan2(dir.y, dir.x) + PI * 0.5
		var uv := _uv(p)
		var t: float = instante
		if t < 0.0:
			t = _proximo_carimbo / maxf(_comprimento, 0.001)
		_parede.mascara.carimbar(uv, angulo, _carga_em(_proximo_carimbo), t)
		posicao_atual = uv
		_proximo_carimbo += PASSO_CARIMBO


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
##
## Cada carga tem um tamanho próprio (ver `_sortear_molhadas`), então isto não
## é um `fmod`: procura em qual carga a distância caiu.
func _carga_em(dist: float) -> float:
	var inicio: float = 0.0
	for m in _molhadas:
		if m > dist:
			break
		inicio = m
	return maxf(CARGA_CHEIA - (dist - inicio) * CONSUMO_POR_METRO, CARGA_MINIMA)


## Onde o tio molha o rolo, ao longo do trajeto. Tamanhos sorteados dentro de
## ±JITTER_CARGA pra a falha não sair periódica.
func _sortear_molhadas() -> void:
	_molhadas.clear()
	var d: float = 0.0
	while d < _comprimento:
		_molhadas.append(d)
		d += METROS_POR_CARGA * (1.0 + randf_range(-JITTER_CARGA, JITTER_CARGA))
