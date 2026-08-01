extends Node3D
class_name Porta

# ─────────────────────────────────────────────
#  PORTA — folha com maçaneta, abre e fecha
#
#  Vão da porta na parede leste: X=3.5, Z ∈ [-0.5, +0.5], Y ∈ [0, 2.1].
#  Dobradiça no lado Z=+0.5; a folha gira em torno dela e abre pra dentro
#  do quarto (sentido -X). Quem gira é o PivoFolha, não a raiz — os batentes
#  (moldura) são irmãos dele e ficam parados, como tem que ser.
# ─────────────────────────────────────────────

signal abriu
signal fechou

const ANGULO_ABERTA: float = 80.0
const DURACAO_GIRO: float  = 0.9

@onready var _pivo: Node3D             = $PivoFolha
@onready var _folha: MeshInstance3D    = $PivoFolha/Folha
@onready var _macaneta: Node3D         = $PivoFolha/Folha/Macaneta
@onready var _batente_norte: MeshInstance3D = $BatenteNorte
@onready var _batente_sul: MeshInstance3D   = $BatenteSul
@onready var _batente_topo: MeshInstance3D  = $BatenteTopo

var _aberta: bool = false


func _ready() -> void:
	_criar_folha()
	_criar_macaneta()
	_criar_batentes()


const COR_MADEIRA: Color = Color(0.42, 0.27, 0.16)
const ESPESSURA_FOLHA: float = 0.06


func _criar_folha() -> void:
	var box := BoxMesh.new()
	box.size = Vector3(ESPESSURA_FOLHA, 2.05, 0.95)
	_folha.mesh = box
	# Centro da folha meio vão adiante da dobradiça (Z local negativo)
	_folha.position = Vector3(0, 1.025, -0.5)

	# Cor chapada, sem normal map de veio. Em low-poly o veio fingido não
	# sobrevive à luz de raspão — o que faz a porta ler como porta é a
	# almofada, que é forma de verdade.
	var mat := StandardMaterial3D.new()
	mat.albedo_color = COR_MADEIRA
	mat.roughness    = 0.75
	_folha.set_surface_override_material(0, mat)

	_criar_almofadas(mat)


## Almofadas: duas molduras salientes na folha, uma alta e uma baixa — o
## desenho clássico de porta de madeira. Cada moldura são 4 barras finas que
## atravessam a folha, então aparecem dos dois lados de uma vez.
func _criar_almofadas(mat: Material) -> void:
	var largura: float = 0.95
	var altura: float  = 2.05
	var margem: float  = 0.11    # borda da folha que fica lisa
	var vao: float     = 0.055   # respiro entre a almofada de cima e a de baixo
	var barra: float   = 0.035   # espessura da barra da moldura
	var saliencia: float = ESPESSURA_FOLHA + 0.016  # sobra dos dois lados

	var meia_altura_util: float = (altura - margem * 2.0 - vao) * 0.5
	var largura_util: float = largura - margem * 2.0

	# centro Y de cada almofada, relativo ao centro da folha
	var centros: Array[float] = [
		-(altura * 0.5) + margem + meia_altura_util * 0.5 + meia_altura_util * 0.5,
		(altura * 0.5) - margem - meia_altura_util * 0.5 - meia_altura_util * 0.5,
	]
	# recalcula pra ficar simétrico ao redor do vão central
	centros[0] = -(vao * 0.5 + meia_altura_util * 0.5)
	centros[1] =  (vao * 0.5 + meia_altura_util * 0.5)

	for cy in centros:
		var meia_a: float = meia_altura_util * 0.5
		var meia_l: float = largura_util * 0.5
		# horizontais (topo e base da almofada)
		_barra_almofada(mat, Vector3(saliencia, barra, largura_util), Vector3(0, cy - meia_a, 0))
		_barra_almofada(mat, Vector3(saliencia, barra, largura_util), Vector3(0, cy + meia_a, 0))
		# verticais (laterais)
		_barra_almofada(mat, Vector3(saliencia, meia_altura_util, barra), Vector3(0, cy, -meia_l))
		_barra_almofada(mat, Vector3(saliencia, meia_altura_util, barra), Vector3(0, cy, meia_l))


func _barra_almofada(mat: Material, tamanho: Vector3, pos: Vector3) -> void:
	var peca := MeshInstance3D.new()
	_folha.add_child(peca)
	var box := BoxMesh.new()
	box.size      = tamanho
	peca.mesh     = box
	peca.position = pos
	peca.set_surface_override_material(0, mat)


func _criar_macaneta() -> void:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.72, 0.66, 0.42)  # latão
	mat.metallic     = 0.9
	mat.roughness    = 0.35

	# Maçaneta fica na borda livre da folha (longe da dobradiça), dos dois lados
	_macaneta.position = Vector3(0, -0.05, -0.35)

	var lados: Array[float] = [-1.0, 1.0]
	for lado in lados:
		# Espelho (rosácea) rente à folha
		var rosacea := MeshInstance3D.new()
		_macaneta.add_child(rosacea)
		var disco := CylinderMesh.new()
		disco.top_radius    = 0.045
		disco.bottom_radius = 0.045
		disco.height        = 0.012
		rosacea.mesh        = disco
		rosacea.position    = Vector3(lado * 0.036, 0, 0)
		rosacea.rotation_degrees = Vector3(0, 0, 90)  # eixo do cilindro vira X
		rosacea.set_surface_override_material(0, mat)

		# Haste saindo da folha
		var haste := MeshInstance3D.new()
		_macaneta.add_child(haste)
		var cil := CylinderMesh.new()
		cil.top_radius    = 0.014
		cil.bottom_radius = 0.014
		cil.height        = 0.06
		haste.mesh        = cil
		haste.position    = Vector3(lado * 0.07, 0, 0)
		haste.rotation_degrees = Vector3(0, 0, 90)
		haste.set_surface_override_material(0, mat)

		# Alavanca horizontal na ponta
		var alavanca := MeshInstance3D.new()
		_macaneta.add_child(alavanca)
		var barra := BoxMesh.new()
		barra.size       = Vector3(0.025, 0.025, 0.13)
		alavanca.mesh    = barra
		alavanca.position = Vector3(lado * 0.1, 0, -0.05)
		alavanca.set_surface_override_material(0, mat)


func _criar_batentes() -> void:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.35, 0.22, 0.13)
	mat.roughness    = 0.8

	# Molduras nas laterais e no topo do vão — some com a fresta feia entre
	# folha e parede, e dá acabamento de porta de verdade.
	var caixa_norte := BoxMesh.new()
	caixa_norte.size = Vector3(0.14, 2.15, 0.06)
	_batente_norte.mesh     = caixa_norte
	_batente_norte.position = Vector3(0, 1.075, -1.0)
	_batente_norte.set_surface_override_material(0, mat)

	var caixa_sul := BoxMesh.new()
	caixa_sul.size = Vector3(0.14, 2.15, 0.06)
	_batente_sul.mesh     = caixa_sul
	_batente_sul.position = Vector3(0, 1.075, 0.0)
	_batente_sul.set_surface_override_material(0, mat)

	var caixa_topo := BoxMesh.new()
	caixa_topo.size = Vector3(0.14, 0.06, 1.1)
	_batente_topo.mesh     = caixa_topo
	_batente_topo.position = Vector3(0, 2.12, -0.5)
	_batente_topo.set_surface_override_material(0, mat)


func abrir() -> void:
	if _aberta:
		return
	_aberta = true
	var tw := create_tween().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_property(_pivo, "rotation_degrees:y", ANGULO_ABERTA, DURACAO_GIRO)
	await tw.finished
	abriu.emit()


func fechar() -> void:
	if not _aberta:
		return
	_aberta = false
	# Fecha com ease-in: acelera até bater no batente, como porta de verdade
	var tw := create_tween().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.tween_property(_pivo, "rotation_degrees:y", 0.0, DURACAO_GIRO)
	await tw.finished
	fechou.emit()
