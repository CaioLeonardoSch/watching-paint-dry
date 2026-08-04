extends RefCounted
class_name MascaraTinta

# ─────────────────────────────────────────────
#  MÁSCARA DE TINTA — o histórico do que o rolo tocou, por parede
#
#  Duas texturas em vez de uma RGBA, porque os canais querem modos de blend
#  diferentes e render_mode é por shader (ver PLANO-OVERHAUL-TINTA.md 3.7):
#
#    acumulada (blend_add)  R = cobertura (satura em 1)  G = espessura
#    recente   (blend_mix)  R = instante da pincelada    G = carga do rolo
#
#  É isto que substitui o cálculo de varredura do shader antigo: em vez de
#  cada pixel deduzir "quando fui pintado" a partir da própria posição, ele
#  lê o que de fato aconteceu ali. Daí saem falha de cobertura, sobreposição,
#  mancha de secagem e lap mark — coisas que uma varredura não representa.
# ─────────────────────────────────────────────

## Resolução da máscara. 146 px/m dá pra ver a marca do rolo (que tem ~23 cm)
## sem gastar VRAM à toa — uma parede de 7 m fica em ~1024 px.
const PIXELS_POR_METRO: float = 146.0

## O rolo de verdade tem ~23 cm de largura e deposita uma faixa de ~5 cm.
const LARGURA_ROLO_M: float = 0.23
const FAIXA_ROLO_M: float = 0.05

## Distância entre dois carimbos do rastro, em texels da máscara — meia faixa
## do rolo (ver `carimbar_traco` e `trajeto_rolo.gd::PASSO_CARIMBO`, 0,025 m).
##
## O shader precisa deste número: é o período do ripple que sobra nas duas
## máscaras, e um box filtro com exatamente esta largura tem um zero nessa
## frequência. Derivado das constantes em vez de chumbado, senão mexer na
## faixa do rolo faria os carimbos reaparecerem na parede sem aviso.
static func passo_carimbo_texels() -> float:
	return FAIXA_ROLO_M * PIXELS_POR_METRO * 0.5

## Resolução da mancha de secagem. 24 px/m: a oitava fina tem 0,35 m, então
## cada mancha pequena cobre ~8 texels. Mais que isso é VRAM à toa num sinal
## que é de propósito borrado — ele nunca é visto como textura, só como nuvem.
const PIXELS_POR_METRO_MANCHA: float = 24.0

## A textura de mancha cobre 1,5× a parede em cada eixo.
##
## A demão desloca o UV pra não secar com o mesmo desenho de manchas da demão
## anterior (o que denunciaria o truque na hora), e a margem é o que permite
## esse deslocamento. Não dá pra resolver com `repeat_enable`: o ruído do
## FastNoiseLite não é tileável, e o wrap deixaria uma emenda reta atravessando
## a parede — bem o oposto do que a mancha existe pra fazer.
const MARGEM_MANCHA: float = 1.5

var acumulada: DrawableTexture2D
var recente: DrawableTexture2D

## Campo de variação da secagem desta parede (Fase G1). Canal R, 0-1, centrado
## em 0,5. O shader lê duas vezes: uma fixa (o substrato, que é o mesmo reboco
## em todas as demãos) e uma deslocada (a irregularidade desta demão).
var mancha: ImageTexture
## UV da parede × isto = UV dentro da mancha. É o recíproco de MARGEM_MANCHA.
var mancha_escala: float = 1.0 / MARGEM_MANCHA

var largura_px: int
var altura_px: int
var largura_m: float
var altura_m: float

var _mat_acumulado: ShaderMaterial
var _mat_recente: ShaderMaterial
var _carimbo: ImageTexture


## `semente` vem do índice da parede: quatro paredes com a mesma nuvem leem
## como repetição de textura, que é justamente o que a mancha deveria evitar.
func _init(largura_metros: float, altura_metros: float, carimbo: ImageTexture,
		semente: int = 0) -> void:
	largura_m = largura_metros
	altura_m  = altura_metros
	largura_px = maxi(int(round(largura_metros * PIXELS_POR_METRO)), 4)
	altura_px  = maxi(int(round(altura_metros * PIXELS_POR_METRO)), 4)
	_carimbo = carimbo
	mancha = criar_mancha(semente, largura_metros, altura_metros)

	acumulada = DrawableTexture2D.new()
	recente   = DrawableTexture2D.new()
	limpar()

	_mat_acumulado = ShaderMaterial.new()
	_mat_acumulado.shader = load("res://shaders/carimbo_acumulado.gdshader")
	_mat_recente = ShaderMaterial.new()
	_mat_recente.shader = load("res://shaders/carimbo_recente.gdshader")


## Zera as duas — parede como se nunca tivesse recebido tinta. Só no início.
func limpar() -> void:
	acumulada.setup(largura_px, altura_px, DrawableTexture2D.DRAWABLE_FORMAT_RGBA8, Color(0, 0, 0, 1), false)
	recente.setup(largura_px, altura_px, DrawableTexture2D.DRAWABLE_FORMAT_RGBA8, Color(0, 0, 0, 1), false)


## Prepara pra uma demão nova preservando o relevo já existente.
##
## Só a máscara recente é zerada. A acumulada guarda quantas camadas passaram
## por cada ponto — informação física que não desaparece porque começou uma
## demão nova. O canal G (carga) da recente serve de marcador de "passei aqui
## nesta demão": zerado agora, e o carimbo o levanta por onde o rolo for.
func limpar_demao() -> void:
	recente.setup(largura_px, altura_px, DrawableTexture2D.DRAWABLE_FORMAT_RGBA8, Color(0, 0, 0, 1), false)


## Parede inteira coberta e pintada no instante 0 — usado ao retomar de um
## save, onde o estado visual é sempre "tudo seco" e não há o que animar.
## R/G da acumulada = cobertura e relevo já assentados; G da recente = carga,
## que é o marcador de "passou aqui" lido como cobertura da demão atual.
func preencher_coberta() -> void:
	acumulada.setup(largura_px, altura_px, DrawableTexture2D.DRAWABLE_FORMAT_RGBA8, Color(1.0, 0.5, 0, 1), false)
	recente.setup(largura_px, altura_px, DrawableTexture2D.DRAWABLE_FORMAT_RGBA8, Color(0, 0.95, 0, 1), false)


## Carimba o rolo numa posição da parede.
##   uv        — posição do centro do rolo, 0-1 na parede
##   angulo    — inclinação do rolo em radianos (0 = rolo na horizontal)
##   carga     — quanta tinta o rolo tem (0-1); rolo seco falha e estria
##   instante  — 0-1, quando na demão isto aconteceu
func carimbar(uv: Vector2, angulo: float, carga: float, instante: float) -> void:
	# tamanho do rolo em pixels da máscara
	var w: float = LARGURA_ROLO_M * PIXELS_POR_METRO
	var h: float = FAIXA_ROLO_M * PIXELS_POR_METRO

	# o retângulo de destino precisa caber o carimbo girado
	var cos_a: float = absf(cos(angulo))
	var sin_a: float = absf(sin(angulo))
	var bbox_w: float = w * cos_a + h * sin_a
	var bbox_h: float = w * sin_a + h * cos_a

	var centro_x: float = uv.x * float(largura_px)
	var centro_y: float = uv.y * float(altura_px)

	# O retângulo é obrigatoriamente inteiro (blit_rect só aceita Rect2i), mas
	# o rolo anda em passos fracionários de pixel. Arredondar a posição fazia
	# cada carimbo cair um pouco fora do lugar e o rastro ganhava um moiré
	# regular — lia como defeito de renderização, não como tinta. A saída é
	# arredondar o retângulo e mandar o resto fracionário pro shader, que
	# desloca o carimbo dentro dele.
	var x0: int = int(floor(centro_x - bbox_w * 0.5))
	var y0: int = int(floor(centro_y - bbox_h * 0.5))
	var x1: int = int(ceil(centro_x + bbox_w * 0.5))
	var y1: int = int(ceil(centro_y + bbox_h * 0.5))
	var rw: int = maxi(x1 - x0, 1)
	var rh: int = maxi(y1 - y0, 1)
	var rect := Rect2i(x0, y0, rw, rh)

	# nada a fazer se caiu inteiro fora da parede
	if x0 >= largura_px or y0 >= altura_px or x1 <= 0 or y1 <= 0:
		return

	var centro_rect := Vector2(float(x0) + float(rw) * 0.5, float(y0) + float(rh) * 0.5)
	var desloc := Vector2(
		(centro_x - centro_rect.x) / float(rw),
		(centro_y - centro_rect.y) / float(rh))

	# o retângulo cresceu pro pixel inteiro, então a escala usa o tamanho real
	var escala := Vector2(float(rw) / w, float(rh) / h)

	_mat_acumulado.set_shader_parameter("angulo", angulo)
	_mat_acumulado.set_shader_parameter("escala_bbox", escala)
	_mat_acumulado.set_shader_parameter("desloc_sub", desloc)
	_mat_acumulado.set_shader_parameter("carga", carga)
	acumulada.blit_rect(rect, _carimbo, Color.WHITE, 0, _mat_acumulado)

	_mat_recente.set_shader_parameter("angulo", angulo)
	_mat_recente.set_shader_parameter("escala_bbox", escala)
	_mat_recente.set_shader_parameter("desloc_sub", desloc)
	_mat_recente.set_shader_parameter("carga", carga)
	_mat_recente.set_shader_parameter("instante", instante)
	recente.blit_rect(rect, _carimbo, Color.WHITE, 0, _mat_recente)


## Carimba ao longo de um segmento, com passo pequeno o bastante pra não sair
## pontilhado. Em velocidade alta um carimbo por frame deixa buraco entre um
## e outro — o rastro tem que ser contínuo.
func carimbar_traco(de: Vector2, para: Vector2, carga: float, instante: float) -> void:
	var delta := para - de
	var delta_px := Vector2(delta.x * float(largura_px), delta.y * float(altura_px))
	# um carimbo a cada meia faixa do rolo garante sobreposição
	var passo_px: float = FAIXA_ROLO_M * PIXELS_POR_METRO * 0.5
	var n: int = maxi(int(ceil(delta_px.length() / maxf(passo_px, 1.0))), 1)

	var angulo: float = 0.0
	if delta_px.length_squared() > 0.0:
		# o rolo fica perpendicular ao movimento: rolada vertical deixa o rolo
		# deitado, rolada horizontal deixa em pé
		angulo = atan2(delta_px.y, delta_px.x) + PI * 0.5

	for i in range(n + 1):
		var t: float = float(i) / float(n)
		carimbar(de.lerp(para, t), angulo, carga, instante)


## Campo de variação da secagem — a razão nº 1 de parede de verdade secar em
## nuvens (Fase G1, plano §3.1).
##
## Duas oitavas com significado físico, não "detalhe": a grossa (~1,1 m) é a
## variação de absorção do reboco de uma região pra outra; a fina (~0,35 m) é o
## granulado dentro de cada região. Sem a grossa a parede seca com chuvisco
## uniforme, que lê como ruído de vídeo em vez de mancha.
##
## O ruído é amostrado em METROS, não em UV. Assim as manchas ficam redondas em
## qualquer parede — amostrar em UV numa parede 6 × 3 esticaria cada mancha na
## proporção 2:1 e o olho pega isso na hora.
static func criar_mancha(semente: int, largura_metros: float, altura_metros: float) -> ImageTexture:
	var w: int = maxi(int(round(largura_metros * MARGEM_MANCHA * PIXELS_POR_METRO_MANCHA)), 8)
	var h: int = maxi(int(round(altura_metros * MARGEM_MANCHA * PIXELS_POR_METRO_MANCHA)), 8)

	var grossa := FastNoiseLite.new()
	grossa.seed = semente
	grossa.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	grossa.fractal_octaves = 1
	grossa.frequency = 1.0 / 1.1

	var fina := FastNoiseLite.new()
	# offset na semente pra as duas oitavas não coincidirem de picos
	fina.seed = semente + 977
	fina.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	fina.fractal_octaves = 1
	fina.frequency = 1.0 / 0.35

	var img := Image.create(w, h, false, Image.FORMAT_R8)
	for y in h:
		for x in w:
			var mx: float = float(x) / PIXELS_POR_METRO_MANCHA
			var my: float = float(y) / PIXELS_POR_METRO_MANCHA
			var n: float = grossa.get_noise_2d(mx, my) * 0.68 + fina.get_noise_2d(mx, my) * 0.32
			# guardado em 0-1; o shader devolve pra -1..+1. A distribuição bruta
			# do ruído é preservada de propósito — normalizar pra usar a faixa
			# toda transformaria a mancha suave num contraste de pôster.
			img.set_pixel(x, y, Color(n * 0.5 + 0.5, 0.0, 0.0))

	return ImageTexture.create_from_image(img)


## Carimbo procedural do rolo: borda macia nos dois eixos, fibras
## longitudinais leves (a marca característica) e queda nas pontas, porque a
## borda do rolo deposita menos que o meio.
static func criar_carimbo(largura: int = 64, altura: int = 32) -> ImageTexture:
	var img := Image.create(largura, altura, false, Image.FORMAT_RGBA8)
	var rng := RandomNumberGenerator.new()
	rng.seed = 8891  # fixo: o carimbo é sempre o mesmo rolo

	# Fibras: variam ao longo do EIXO do rolo (x), não da faixa de contato (y).
	# Como o rolo gira, o que está em y é varrido na direção do movimento e
	# viraria listra atravessada; o que está em x acompanha a rolada e vira a
	# estria longitudinal característica. Indexar errado aqui deixa a parede
	# com cara de código de barras.
	var fibras: PackedFloat32Array = []
	fibras.resize(largura)
	for x in largura:
		fibras[x] = 1.0 - rng.randf() * 0.10

	for y in altura:
		for x in largura:
			var u: float = (float(x) + 0.5) / float(largura)
			var v: float = (float(y) + 0.5) / float(altura)

			# Borda lateral (u) macia: é onde as passadas vizinhas se sobrepõem,
			# e borda estreita ali vira degrau visível a cada passada.
			var borda_x: float = smoothstep(0.0, 0.28, u) * smoothstep(1.0, 0.72, u)

			# Ao longo da faixa de contato (v) o perfil é TRIANGULAR, não
			# smoothstep. Motivo: o rastro é feito de carimbos discretos
			# espaçados de meia-faixa, e só o triângulo de base 2× o passo soma
			# exatamente constante (partição da unidade). Com smoothstep a soma
			# ondula e a parede ganha um ripple regular atravessado, que lê como
			# defeito de renderização e não como tinta.
			var borda_y: float = 1.0 - absf(v * 2.0 - 1.0)

			# pontas do rolo depositam menos
			var ponta: float = 1.0 - pow(absf(u - 0.5) * 2.0, 3.0) * 0.25

			var valor: float = borda_x * borda_y * ponta * fibras[x]
			img.set_pixel(x, y, Color(valor, valor, valor, valor))

	return ImageTexture.create_from_image(img)
