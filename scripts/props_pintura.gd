extends Node3D
class_name PropsPintura

# ─────────────────────────────────────────────
#  PROPS DA PINTURA — bandeja, banquinho e lata
#
#  Fase E. Diferente de `props_quarto.gd`, que é cenário parado: estes três
#  ANDAM com o serviço. O tio pinta uma parede de cada vez, e a bandeja fica
#  onde ele consegue alcançar — quem move é `posicionar_para_parede()`, chamado
#  pelo ciclo quando ele troca de parede.
#
#  Por que importa que a bandeja esteja no lugar certo: a ida à bandeja é a
#  razão diegética da falha de cobertura (a carga do rolo acaba, ver
#  `trajeto_rolo.gd`). Uma bandeja do outro lado do quarto entregaria a
#  mentira na hora.
#
#  Geometria primitiva e cor chapada, igual ao resto do low-poly (Fase C).
# ─────────────────────────────────────────────

const PLASTICO_BANDEJA := Color(0.20, 0.22, 0.25)
const MADEIRA_BANQUINHO := Color(0.55, 0.40, 0.27)
const METAL_LATA := Color(0.68, 0.66, 0.62)

## Altura do assento do banquinho. É o que o tio ganha de alcance ao subir —
## `tio.gd::ALTURA_BANQUINHO` tem que bater com isto, senão ele flutua ou
## enterra o pé na madeira.
const ALTURA_BANQUINHO: float = 0.30

## Distância da parede em que a bandeja e o banquinho ficam. A bandeja fica um
## pouco mais longe: ele pisa no banquinho, então esse tem que estar rente.
const DISTANCIA_BANDEJA: float = 1.05
const DISTANCIA_BANQUINHO: float = 0.58

var bandeja: Node3D
var banquinho: Node3D
var lata: Node3D

var _cor_tinta: Color = Color(0.16, 0.34, 0.68)
var _tinta_bandeja: StandardMaterial3D
var _tinta_lata: StandardMaterial3D


func _ready() -> void:
	_criar_bandeja()
	_criar_banquinho()
	_criar_lata()


## A tinta da bandeja e da lata acompanha a cor que está sendo pintada — sem
## isso o tio molha o rolo em azul e passa vermelho na parede.
func definir_cor(cor: Color) -> void:
	_cor_tinta = cor
	if _tinta_bandeja != null:
		_tinta_bandeja.albedo_color = cor
	if _tinta_lata != null:
		_tinta_lata.albedo_color = cor


## Põe bandeja, banquinho e lata em frente à parede que está sendo pintada,
## no meio dela. O tio caminha até a bandeja quando a carga acaba.
func posicionar_para_parede(parede: ParedePintavel) -> void:
	var normal: Vector3 = parede.normal_interna()
	var meio_chao: Vector3 = parede.ponto_mundo(Vector2(0.5, 1.0))
	meio_chao.y = 0.0

	var lado: Vector3 = parede.eixo_u.normalized()
	bandeja.position = meio_chao + normal * DISTANCIA_BANDEJA
	banquinho.position = meio_chao + normal * DISTANCIA_BANQUINHO + lado * 0.9
	lata.position = meio_chao + normal * DISTANCIA_BANDEJA + lado * -0.55

	# a bandeja é comprida no sentido da parede
	bandeja.rotation.y = atan2(lado.x, lado.z)


## Onde o tio precisa ficar de pé pra molhar o rolo.
func ponto_de_molhar() -> Vector3:
	return bandeja.position


## Leva o banquinho pro trecho em que ele está trabalhando — ele carrega o
## banquinho junto, não pula de um lado da parede pro outro.
func mover_banquinho(ponto_chao: Vector3) -> void:
	banquinho.position = ponto_chao


static func _material(cor: Color, aspereza: float = 0.85) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = cor
	mat.roughness    = aspereza
	mat.metallic     = 0.0
	return mat


func _caixa(pai: Node3D, tamanho: Vector3, pos: Vector3, mat: Material) -> MeshInstance3D:
	var no := MeshInstance3D.new()
	pai.add_child(no)
	var box := BoxMesh.new()
	box.size = tamanho
	no.mesh = box
	no.position = pos
	no.material_override = mat
	return no


## Bandeja de pintor: fundo raso na frente (a rampa onde se escorre o rolo) e
## poço fundo atrás, com a tinta dentro.
func _criar_bandeja() -> void:
	bandeja = Node3D.new()
	bandeja.name = "Bandeja"
	add_child(bandeja)

	var mat := _material(PLASTICO_BANDEJA, 0.6)
	_caixa(bandeja, Vector3(0.42, 0.03, 0.34), Vector3(0, 0.015, 0), mat)
	_caixa(bandeja, Vector3(0.42, 0.09, 0.03), Vector3(0, 0.06, -0.155), mat)
	_caixa(bandeja, Vector3(0.03, 0.06, 0.34), Vector3(-0.195, 0.045, 0), mat)
	_caixa(bandeja, Vector3(0.03, 0.06, 0.34), Vector3(0.195, 0.045, 0), mat)

	_tinta_bandeja = _material(_cor_tinta, 0.35)
	_caixa(bandeja, Vector3(0.38, 0.02, 0.12), Vector3(0, 0.035, -0.09), _tinta_bandeja)


## Banquinho baixo de madeira, 4 pernas.
func _criar_banquinho() -> void:
	banquinho = Node3D.new()
	banquinho.name = "Banquinho"
	add_child(banquinho)

	var mat := _material(MADEIRA_BANQUINHO)
	_caixa(banquinho, Vector3(0.36, 0.04, 0.30), Vector3(0, ALTURA_BANQUINHO - 0.02, 0), mat)
	var altura_perna: float = ALTURA_BANQUINHO - 0.04
	for sx in [-1.0, 1.0]:
		for sz in [-1.0, 1.0]:
			_caixa(banquinho, Vector3(0.04, altura_perna, 0.04),
				Vector3(sx * 0.15, altura_perna * 0.5, sz * 0.12), mat)


## Lata aberta ao lado da bandeja — é de onde a tinta sai.
func _criar_lata() -> void:
	lata = Node3D.new()
	lata.name = "LataDeTinta"
	add_child(lata)

	var corpo := MeshInstance3D.new()
	lata.add_child(corpo)
	var cilindro := CylinderMesh.new()
	cilindro.top_radius = 0.09
	cilindro.bottom_radius = 0.09
	cilindro.height = 0.20
	corpo.mesh = cilindro
	corpo.position = Vector3(0, 0.10, 0)
	corpo.material_override = _material(METAL_LATA, 0.5)

	var dentro := MeshInstance3D.new()
	lata.add_child(dentro)
	var disco := CylinderMesh.new()
	disco.top_radius = 0.082
	disco.bottom_radius = 0.082
	disco.height = 0.01
	dentro.mesh = disco
	dentro.position = Vector3(0, 0.185, 0)
	_tinta_lata = _material(_cor_tinta, 0.35)
	dentro.material_override = _tinta_lata
