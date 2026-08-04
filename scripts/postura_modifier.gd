extends SkeletonModifier3D
class_name PosturaModifier

# ─────────────────────────────────────────────
#  POSTURA — a camada procedural por cima dos clipes (OVERHAUL §5.4)
#
#  Duas coisas, e as duas são OFFSET em cima da animação, não pose absoluta:
#  a altura do quadril (é isso que faz agachar e esticar parecerem esforço, em
#  vez de pose trocada) e a inclinação do torso na direção da pincelada.
#
#  ⚠️ Tem que ser um `SkeletonModifier3D`, e não `set_bone_pose_*` chamado de
#  fora. O `AnimationPlayer` reescreve a pose de todo osso que ele comanda em
#  todo frame, e **`andar` e `parado_respirando` comandam o Quadril os dois** —
#  então qualquer coisa escrita de fora dura até o próximo frame de animação.
#  Modifier roda depois da animação, na ordem da árvore.
#
#  ⚠️ E por isso este nó fica ACIMA das duas `TwoBoneIK3D` das pernas: elas
#  precisam resolver o joelho já com o quadril na altura nova. Invertida a
#  ordem, o quadril desce depois da IK e o pé afunda no assoalho — que é
#  exatamente o que a IK está ali pra impedir.
# ─────────────────────────────────────────────

## 0 = em pé, 1 = agachado no fundo. Quem manda nisto é `personagem.gd`.
@export_range(0.0, 1.0) var agachamento: float = 0.0

## Graus, positivo = torso pra frente (o peso do corpo acompanhando o braço).
@export var inclinacao_torso: float = 0.0

## Quanto o quadril desce com `agachamento = 1`, em metros.
##
## O tio tem coxa 0,38 + canela 0,36 = 0,74 de alcance do quadril ao tornozelo,
## e em pé ele já usa 0,74 desses (quadril 0,82, tornozelo 0,08). Descer 0,30
## deixa o joelho num ângulo forte mas ainda humano; mais que isso e a IK começa
## a estourar o alcance e o pé descola.
@export var queda_maxima: float = 0.30

@export var osso_quadril: String = "Quadril"
@export var osso_torso: String = "Coluna_01"


func _process_modification() -> void:
	var esqueleto: Skeleton3D = get_skeleton()
	if esqueleto == null:
		return

	if agachamento > 0.0001:
		var indice_quadril: int = esqueleto.find_bone(osso_quadril)
		if indice_quadril >= 0:
			# offset: lê o que a animação acabou de escrever e desce a partir dali
			var pose: Vector3 = esqueleto.get_bone_pose_position(indice_quadril)
			esqueleto.set_bone_pose_position(indice_quadril,
				pose - Vector3(0.0, agachamento * queda_maxima, 0.0))

	if absf(inclinacao_torso) > 0.0001:
		var indice_torso: int = esqueleto.find_bone(osso_torso)
		if indice_torso >= 0:
			# `Coluna_01` nasce com rotação de repouso identidade (conferido no
			# .tscn), então o X local é o X do esqueleto. Girar em torno de +X
			# leva o topo do osso pra +Z; a frente do modelo é -Z, então
			# inclinar pra FRENTE é ângulo negativo.
			var giro := Quaternion(Vector3.RIGHT, -deg_to_rad(inclinacao_torso))
			esqueleto.set_bone_pose_rotation(indice_torso,
				esqueleto.get_bone_pose_rotation(indice_torso) * giro)


