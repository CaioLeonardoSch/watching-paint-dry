extends RefCounted
class_name PropsQuarto

# ─────────────────────────────────────────────
#  PROPS DO QUARTO — o que faz um quarto ler como quarto
#
#  Fase C do overhaul. A tese do plano: num visual low-poly, superfície
#  chapada é a proposta, não o problema — o que separa "quarto" de "caixa"
#  não é micro-detalhe de textura, é ter as coisas que todo quarto tem.
#  Rodapé, moldura de porta e de janela, interruptor, tomada. Cada um com
#  poucos polígonos e cor chapada da paleta.
#
#  Tudo aqui é geometria primitiva posicionada, sem textura nenhuma.
#
#  Quarto: X ∈ [-3.0, +3.0], Z ∈ [-4.0, +2.0], Y ∈ [0, 3] — 6 × 6 (Fase G6)
#  Porta a leste (x=+3.0, z de -0.5 a +0.5); janela a oeste (x=-3.0,
#  z de -1.85 a -0.15, centrada na parede; y de 0.8 a 2.0).
# ─────────────────────────────────────────────

# ── Paleta fechada (Fase C do plano) ─────────────────────────
const MADEIRA_CLARA := Color(0.60, 0.45, 0.31)
const MADEIRA_ESCURA := Color(0.38, 0.24, 0.14)
const BRANCO_SUJO := Color(0.88, 0.86, 0.82)
const METAL_FOSCO := Color(0.62, 0.60, 0.56)
const PLASTICO_CREME := Color(0.90, 0.88, 0.83)

# FACE INTERNA de cada parede, não o centro dela. As paredes são BoxMesh de
# 0.2 de espessura centrados em ±3.0 / -4.0 / +2.0, então a superfície que dá
# pro quarto está 0.1 pra dentro. Usar o centro enterra os props na parede.
const LIMITE_X: float = 2.9
const LIMITE_Z_NORTE: float = -3.9
const LIMITE_Z_SUL: float = 1.9

const ALTURA_RODAPE: float = 0.11
const SALIENCIA: float = 0.025  # o quanto o prop se destaca da parede


static func criar(pai: Node3D) -> void:
	var raiz := Node3D.new()
	raiz.name = "Props"
	pai.add_child(raiz)

	_rodapes(raiz)
	_moldura_janela(raiz)
	_interruptor(raiz)
	_tomada(raiz)


static func _material(cor: Color, aspereza: float = 0.85) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = cor
	mat.roughness    = aspereza
	mat.metallic     = 0.0
	return mat


static func _caixa(pai: Node3D, tamanho: Vector3, pos: Vector3, mat: Material) -> MeshInstance3D:
	var no := MeshInstance3D.new()
	pai.add_child(no)
	var box := BoxMesh.new()
	box.size  = tamanho
	no.mesh   = box
	no.position = pos
	no.set_surface_override_material(0, mat)
	return no


## Rodapé nas 4 paredes. Além de dar leitura de quarto, esconde o encontro
## entre parede e assoalho — que é justamente onde a tinta do rolo termina.
static func _rodapes(raiz: Node3D) -> void:
	var mat := _material(BRANCO_SUJO, 0.7)
	var y: float = ALTURA_RODAPE * 0.5
	var largura: float = LIMITE_X * 2.0
	var profundidade: float = LIMITE_Z_SUL - LIMITE_Z_NORTE

	# norte e sul (atravessam a parede inteira)
	_caixa(raiz, Vector3(largura, ALTURA_RODAPE, SALIENCIA),
		Vector3(0, y, LIMITE_Z_NORTE + SALIENCIA * 0.5), mat)
	_caixa(raiz, Vector3(largura, ALTURA_RODAPE, SALIENCIA),
		Vector3(0, y, LIMITE_Z_SUL - SALIENCIA * 0.5), mat)

	# oeste (janela começa em y=0.8, então o rodapé passa reto)
	_caixa(raiz, Vector3(SALIENCIA, ALTURA_RODAPE, profundidade),
		Vector3(-LIMITE_X + SALIENCIA * 0.5, y, (LIMITE_Z_NORTE + LIMITE_Z_SUL) * 0.5), mat)

	# leste: interrompido pelo vão da porta (z de -0.5 a +0.5)
	var comp_norte: float = -0.5 - LIMITE_Z_NORTE
	_caixa(raiz, Vector3(SALIENCIA, ALTURA_RODAPE, comp_norte),
		Vector3(LIMITE_X - SALIENCIA * 0.5, y, LIMITE_Z_NORTE + comp_norte * 0.5), mat)
	var comp_sul: float = LIMITE_Z_SUL - 0.5
	_caixa(raiz, Vector3(SALIENCIA, ALTURA_RODAPE, comp_sul),
		Vector3(LIMITE_X - SALIENCIA * 0.5, y, 0.5 + comp_sul * 0.5), mat)


## Moldura da janela (parede oeste, x=-3.0, z de -1.85 a -0.15, y de 0.8 a 2.0).
##
## Vão encurtado 15% em Z (era z ∈ [-1, +1]) e travessa vertical somada à
## horizontal: a cruz no meio divide em 4 vidros iguais, que é o desenho
## clássico de janela de casa. Só a divisória horizontal deixava a janela
## comprida e estranha, mais cara de vitrine que de quarto.
static func _moldura_janela(raiz: Node3D) -> void:
	var mat := _material(BRANCO_SUJO, 0.65)
	var x: float = -LIMITE_X + SALIENCIA
	var esp: float = 0.05
	var z0: float = -1.85
	var z1: float = -0.15
	var y0: float = 0.8
	var y1: float = 2.0
	var ym: float = (y0 + y1) * 0.5
	var zm: float = (z0 + z1) * 0.5

	# verticais
	_caixa(raiz, Vector3(esp, y1 - y0 + esp * 2.0, esp), Vector3(x, ym, z0), mat)
	_caixa(raiz, Vector3(esp, y1 - y0 + esp * 2.0, esp), Vector3(x, ym, z1), mat)
	# horizontais
	_caixa(raiz, Vector3(esp, esp, z1 - z0), Vector3(x, y0, zm), mat)
	_caixa(raiz, Vector3(esp, esp, z1 - z0), Vector3(x, y1, zm), mat)
	# cruz central — os dois braços, mais finos que a moldura de fora
	_caixa(raiz, Vector3(esp * 0.7, esp * 0.7, z1 - z0), Vector3(x, ym, zm), mat)
	_caixa(raiz, Vector3(esp * 0.7, y1 - y0, esp * 0.7), Vector3(x, ym, zm), mat)

	# peitoril, um pouco mais fundo que a moldura
	_caixa(raiz, Vector3(0.12, 0.04, z1 - z0 + 0.16),
		Vector3(x + 0.04, y0 - 0.03, (z0 + z1) * 0.5), _material(MADEIRA_CLARA, 0.7))


## A moldura da porta MORAVA AQUI e foi removida na Fase G6.
##
## Havia duas molduras de porta no jogo, quase idênticas em cor e sobrepostas
## em X — esta e a de `porta.gd::_criar_batentes`. Liam como uma moldura só
## meio grossa e eram geometria duplicada esperando pra brigar por z-fighting.
## Ficou a de `porta.gd`, que é quem tem as medidas da folha e por isso
## consegue fechar a fresta do topo. Cena de porta autocontida.


## Interruptor perto da porta, na altura da mão.
static func _interruptor(raiz: Node3D) -> void:
	var x: float = LIMITE_X - SALIENCIA
	var pos := Vector3(x, 1.15, 0.85)
	_caixa(raiz, Vector3(0.02, 0.10, 0.08), pos, _material(PLASTICO_CREME, 0.5))
	# a teclinha
	_caixa(raiz, Vector3(0.012, 0.05, 0.035),
		pos + Vector3(0.015, 0.005, 0.0), _material(BRANCO_SUJO, 0.4))


## Tomada na parede norte, baixa, logo acima do rodapé.
static func _tomada(raiz: Node3D) -> void:
	var z: float = LIMITE_Z_NORTE + SALIENCIA
	var pos := Vector3(-1.9, 0.28, z)
	_caixa(raiz, Vector3(0.09, 0.09, 0.02), pos, _material(PLASTICO_CREME, 0.5))
	# os dois furinhos
	var mat_furo := _material(Color(0.18, 0.17, 0.16), 0.9)
	_caixa(raiz, Vector3(0.012, 0.022, 0.012), pos + Vector3(-0.018, 0.008, 0.008), mat_furo)
	_caixa(raiz, Vector3(0.012, 0.022, 0.012), pos + Vector3(0.018, 0.008, 0.008), mat_furo)
