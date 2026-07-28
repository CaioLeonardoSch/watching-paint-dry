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


func _criar_folha() -> void:
	var box := BoxMesh.new()
	box.size = Vector3(0.06, 2.05, 0.95)
	_folha.mesh = box
	# Centro da folha meio vão adiante da dobradiça (Z local negativo)
	_folha.position = Vector3(0, 1.025, -0.5)

	var ruido  := MateriaisProcedurais.criar_textura_ruido(0.2, 512)
	var normal := MateriaisProcedurais.criar_normal_ruido(1.2, 2.0, 512)
	var mat    := MateriaisProcedurais.criar_material_texturizado(
		Color(0.42, 0.27, 0.16), 0.75, ruido, Vector3(1.0, 6.0, 1.0), normal, 0.9)
	_folha.set_surface_override_material(0, mat)


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
