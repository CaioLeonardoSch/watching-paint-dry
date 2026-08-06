extends SkeletonModifier3D
class_name BracoLivreModifier

# ─────────────────────────────────────────────
#  BRAÇO LIVRE — o braço que NÃO segura o rolo
#
#  Existe porque, enquanto ele pinta, o braço esquerdo ficava parado no rest.
#  A causa era estrutural: `tio.gd::OSSOS_DO_BRACO` tira as pistas dos DOIS
#  braços dos clipes de perna (pra a IK do rolo não brigar com o clipe no braço
#  direito), e só o direito tem IK pra pôr no lugar. O esquerdo ficava sem dono
#  — 84 segundos de parede com um braço pendurado sem mexer.
#
#  ⚠️ É OFFSET em cima do que a animação escreveu, igual ao `PosturaModifier`, e
#  pela mesma razão: quem escreve por último num osso comandado por
#  `AnimationPlayer` é a animação, todo quadro. Modifier roda depois.
#
#  ⚠️ Convenção de eixo (OVERHAUL §5.9): os ossos de membro apontam pra baixo e
#  **+X leva o membro pra frente do personagem**. Vale pra `Braco_*` e
#  `Antebraco_*`.
# ─────────────────────────────────────────────

## −1 = braço atrás, +1 = braço à frente. Quem manda é `tio.gd`, a partir da
## direção da passada — subir o rolo joga o braço livre pra trás, descer traz
## de volta. É o contrapeso, não é decoração: braço livre de pintor faz isso.
@export_range(-1.0, 1.0) var balanco: float = 0.0

## 0 = braço caído do lado do corpo, 1 = cotovelo aberto na altura da cintura.
## Sobe quando ele estica pro alto ou agacha pro rodapé — as duas posturas em
## que o braço livre sai do corpo pra equilibrar.
@export_range(0.0, 1.0) var elevacao: float = 0.0

## Amplitudes. Pequenas de propósito: o braço livre é movimento fino, e o
## exagero aqui lê como o personagem gesticulando enquanto pinta.
@export var giro_balanco_graus: float = 7.0
@export var abertura_graus: float = 16.0
@export var cotovelo_graus: float = 22.0

@export var osso_braco: String = "Braco_E"
@export var osso_antebraco: String = "Antebraco_E"


func _process_modification() -> void:
	var esqueleto: Skeleton3D = get_skeleton()
	if esqueleto == null:
		return

	var giro_ombro: float = balanco * giro_balanco_graus + elevacao * abertura_graus
	_girar(esqueleto, osso_braco, giro_ombro)
	# o cotovelo só dobra quando o braço sobe — braço caído fica esticado
	_girar(esqueleto, osso_antebraco, elevacao * cotovelo_graus)


func _girar(esqueleto: Skeleton3D, nome: String, graus: float) -> void:
	if absf(graus) < 0.0001:
		return
	var indice: int = esqueleto.find_bone(nome)
	if indice < 0:
		return
	var giro := Quaternion(Vector3.RIGHT, deg_to_rad(graus))
	esqueleto.set_bone_pose_rotation(indice,
		esqueleto.get_bone_pose_rotation(indice) * giro)
