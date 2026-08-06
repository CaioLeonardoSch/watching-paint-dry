extends Node3D
class_name RoloPintura

# ─────────────────────────────────────────────
#  ROLO DE PINTURA — a ferramenta na mão do tio
#
#  Fase E. O rolo não é decoração nem animação à parte: ele fica exatamente
#  onde `trajeto_rolo.gd` diz que o rolo está, e é a MÃO que vai atrás dele
#  (via `TwoBoneIK3D`, ver `tio.gd`). Essa é a inversão que o overhaul pede —
#  antes eram duas animações sincronizadas na sorte; agora a tinta na parede e
#  o braço do tio saem da mesma curva.
#
#  ── Convenção de eixos locais, que é o que faz o resto ser simples ──
#
#    +Y  vai da espuma até a mão (é o cabo)
#    +X  é o eixo da espuma — perpendicular ao traço, no plano da parede
#    +Z  fecha a base
#
#  Com isso o cabo é um cilindro em Y sem rotação nenhuma, a mão mora em
#  (0, COMPRIMENTO_CABO, 0), e orientar o rolo é montar uma Basis com esses
#  três vetores. `look_at` aqui só confundia: ele resolve UMA direção e deixa o
#  giro em torno dela pro vetor `up`, que é justamente o eixo que importa.
# ─────────────────────────────────────────────

const LARGURA_ESPUMA: float = 0.23
const RAIO_ESPUMA: float = 0.038

## Da espuma até a mão, em repouso. É o que deixa o tio alcançar o alto da
## parede sem escada, e o que mantém o punho dele numa altura de gente.
##
## ⚠️ O cabo ESTICA (ver `encostar`), e isso não é preguiça de animação: rolo de
## parede de verdade tem extensor rosqueado, e o pintor abre e fecha conforme a
## altura. Cabo rígido obrigava a mão a ir exatamente a 0,42 m da espuma — e
## quando esse ponto caía fora do alcance do braço, a IK parava onde dava e o
## rolo ficava **flutuando a 40 cm da mão**. Agora a mão manda e o cabo obedece.
const COMPRIMENTO_CABO: float = 0.42
const CABO_MINIMO: float = 0.22
const CABO_MAXIMO: float = 0.70

const COR_CABO := Color(0.72, 0.70, 0.66)
const COR_HASTE := Color(0.55, 0.54, 0.52)

## Quanto a espuma escurece e brilha quando está encharcada, contra o rolo já
## gasto. Rolo cheio de tinta é mais escuro e mais liso que rolo escorrido — é o
## que deixa a ida à bandeja ter consequência visível, não só coreográfica.
const ESCURECE_MOLHADO: float = 0.22
const ASPEREZA_SECA: float = 0.62
const ASPEREZA_MOLHADA: float = 0.28

var _mat_espuma: StandardMaterial3D
var _haste: MeshInstance3D
var _cabo: MeshInstance3D
var _cor_tinta: Color = Color(0.16, 0.34, 0.68)
var _molhado: float = 1.0


func _ready() -> void:
	_montar()


## A espuma fica da cor da tinta que está passando.
func definir_cor(cor: Color) -> void:
	_cor_tinta = cor
	_aplicar_espuma()


## 0 = rolo escorrido, 1 = acabou de sair da bandeja. Quem manda durante a
## pintura é a carga do trajeto; durante a parada, o mergulho.
func definir_molhado(fracao: float) -> void:
	_molhado = clampf(fracao, 0.0, 1.0)
	_aplicar_espuma()


func _aplicar_espuma() -> void:
	if _mat_espuma == null:
		return
	_mat_espuma.albedo_color = _cor_tinta.darkened(ESCURECE_MOLHADO * _molhado)
	_mat_espuma.roughness = lerpf(ASPEREZA_SECA, ASPEREZA_MOLHADA, _molhado)


## Encosta o rolo na parede e aponta o cabo pra onde a mão consegue ficar.
##
## - `ponto`: onde o rolo toca a parede (vem do trajeto)
## - `normal`: normal da parede, pra dentro do quarto
## - `direcao_traco`: pra onde o traço está indo, no plano da parede
## - `mao_desejada`: onde o punho do tio ficaria confortável
##
## `mao` é onde o punho do tio consegue estar (já limitado pelo alcance do
## braço — quem limita é `tio.gd`). O cabo estica ou encolhe pra chegar lá.
##
## Devolve o ponto onde a mão de fato agarra, que é o alvo da IK do braço.
func encostar(ponto: Vector3, normal: Vector3, direcao_traco: Vector3, mao: Vector3) -> Vector3:
	global_position = ponto + normal * RAIO_ESPUMA

	var ate_mao: Vector3 = mao - global_position
	var comprimento: float = clampf(ate_mao.length(), CABO_MINIMO, CABO_MAXIMO)
	var eixo_y: Vector3 = ate_mao if ate_mao.length_squared() > 0.0001 else normal
	eixo_y = eixo_y.normalized()

	var eixo_x: Vector3 = direcao_traco.cross(normal)
	if eixo_x.length_squared() < 0.0001:
		eixo_x = normal.cross(Vector3.UP)
	var eixo_z: Vector3 = eixo_x.cross(eixo_y).normalized()
	eixo_x = eixo_y.cross(eixo_z).normalized()

	global_basis = Basis(eixo_x, eixo_y, eixo_z)
	_esticar(comprimento)
	return global_position + eixo_y * comprimento


func _montar() -> void:
	_mat_espuma = StandardMaterial3D.new()
	_mat_espuma.metallic = 0.0
	_aplicar_espuma()

	# espuma: cilindro deitado no eixo X (CylinderMesh nasce em pé, no Y)
	var espuma := MeshInstance3D.new()
	add_child(espuma)
	var cilindro := CylinderMesh.new()
	cilindro.top_radius = RAIO_ESPUMA
	cilindro.bottom_radius = RAIO_ESPUMA
	cilindro.height = LARGURA_ESPUMA
	espuma.mesh = cilindro
	espuma.rotation_degrees = Vector3(0, 0, 90)
	espuma.material_override = _mat_espuma

	var mat_haste := StandardMaterial3D.new()
	mat_haste.albedo_color = COR_HASTE
	mat_haste.roughness = 0.4
	mat_haste.metallic = 0.6

	_haste = MeshInstance3D.new()
	add_child(_haste)
	var tubo := CylinderMesh.new()
	tubo.top_radius = 0.011
	tubo.bottom_radius = 0.011
	tubo.height = 1.0   # escalado em Y por `_esticar`
	_haste.mesh = tubo
	_haste.material_override = mat_haste

	_cabo = MeshInstance3D.new()
	add_child(_cabo)
	var punho := CylinderMesh.new()
	punho.top_radius = 0.019
	punho.bottom_radius = 0.021
	punho.height = 0.17   # o punho não estica: é a mão fechada nele
	_cabo.mesh = punho
	var mat_cabo := StandardMaterial3D.new()
	mat_cabo.albedo_color = COR_CABO
	mat_cabo.roughness = 0.75
	_cabo.material_override = mat_cabo

	_esticar(COMPRIMENTO_CABO)


## Estica a haste até `comprimento` e põe o punho na ponta, onde a mão agarra.
func _esticar(comprimento: float) -> void:
	var trecho_haste: float = maxf(comprimento - 0.17, 0.02)
	_haste.scale.y = trecho_haste
	_haste.position.y = trecho_haste * 0.5
	_cabo.position.y = comprimento - 0.085
