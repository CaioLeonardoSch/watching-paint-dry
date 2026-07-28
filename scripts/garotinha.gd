extends Node3D
class_name Garotinha

# ─────────────────────────────────────────────
#  GAROTINHA — personagem que assiste a tinta secar
#
#  Mesmo padrão de boneco-placeholder do tio.gd, em escala menor (criança).
#  Depois de sentar, o corpo é escondido — a câmera da cadeira vira a visão
#  em primeira pessoa dela, então o corpo visível só causaria clipping.
# ─────────────────────────────────────────────

signal sentou

const ESCALA_CRIANCA: float = 0.78

@onready var _corpo: MeshInstance3D          = $Corpo
@onready var _cabeca: MeshInstance3D         = $Cabeca
@onready var _perna_esquerda: MeshInstance3D = $PernaEsquerda
@onready var _perna_direita: MeshInstance3D  = $PernaDireita
@onready var _pivo_braco_esquerdo: Node3D    = $PivoBracoEsquerdo
@onready var _pivo_braco_direito: Node3D     = $PivoBracoDireito
@onready var _braco_esquerdo: MeshInstance3D = $PivoBracoEsquerdo/BracoEsquerdo
@onready var _braco_direito: MeshInstance3D  = $PivoBracoDireito/BracoDireito


func _ready() -> void:
	call_deferred("_criar_corpo")


func _criar_corpo() -> void:
	var e := ESCALA_CRIANCA
	var cor_pele    := Color(0.87, 0.71, 0.56)
	var cor_vestido := Color(0.85, 0.55, 0.62)

	_montar_capsula(_corpo, 0.18 * e, 0.6 * e, Vector3(0, 0.95 * e, 0), cor_vestido)
	_montar_esfera(_cabeca, 0.14 * e, Vector3(0, 1.4 * e, 0), cor_pele)
	_montar_capsula(_perna_esquerda, 0.09 * e, 0.75 * e, Vector3(-0.1 * e, 0.38 * e, 0), cor_pele)
	_montar_capsula(_perna_direita,  0.09 * e, 0.75 * e, Vector3(0.1 * e, 0.38 * e, 0), cor_pele)

	_pivo_braco_esquerdo.position = Vector3(-0.24 * e, 1.15 * e, 0)
	_pivo_braco_direito.position  = Vector3(0.24 * e, 1.15 * e, 0)
	_montar_capsula(_braco_esquerdo, 0.06 * e, 0.42 * e, Vector3(0, -0.2 * e, 0), cor_pele)
	_montar_capsula(_braco_direito,  0.06 * e, 0.42 * e, Vector3(0, -0.2 * e, 0), cor_pele)


func _montar_capsula(no: MeshInstance3D, raio: float, altura: float, pos: Vector3, cor: Color) -> void:
	var cap := CapsuleMesh.new()
	cap.radius = raio
	cap.height = altura
	no.mesh     = cap
	no.position = pos
	no.set_surface_override_material(0, _material_liso(cor))


func _montar_esfera(no: MeshInstance3D, raio: float, pos: Vector3, cor: Color) -> void:
	var esfera := SphereMesh.new()
	esfera.radius = raio
	esfera.height = raio * 2.0
	no.mesh     = esfera
	no.position = pos
	no.set_surface_override_material(0, _material_liso(cor))


func _material_liso(cor: Color) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = cor
	mat.roughness    = 0.8
	return mat


func ir_ate(destino: Vector3, duracao: float = 3.0) -> void:
	var tw := create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tw.tween_property(self, "position", destino, duracao)
	await tw.finished


## Anda até a cadeira e senta — depois esconde o corpo (vira a câmera em 1ª pessoa).
func entrar_e_sentar(ponto_entrada: Vector3, destino_cadeira: Vector3) -> void:
	position = ponto_entrada
	show()
	await ir_ate(destino_cadeira, 3.0)

	var tw := create_tween().set_trans(Tween.TRANS_SINE)
	tw.tween_property(self, "position:y", position.y - 0.15, 0.4)
	await tw.finished

	hide()
	sentou.emit()
