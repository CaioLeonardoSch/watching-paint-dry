extends Node3D
class_name Garotinha

# ─────────────────────────────────────────────
#  GAROTINHA — personagem que assiste a tinta secar
#
#  Modelo rigado no Blender (res://models/garotinha_modelo.tscn — ver
#  PROJETO.md Fase 1.2). Depois de sentar, o corpo é escondido — a câmera da
#  cadeira vira a visão em primeira pessoa dela, então o corpo visível só
#  causaria clipping. "Sentar" continua sendo só um Tween de posição Y (não
#  virou clipe de osso — janela de visibilidade é curta demais pra valer a
#  pena, câmera corta pra 1ª pessoa logo em seguida).
# ─────────────────────────────────────────────

signal sentou

@onready var _anim: AnimationPlayer = $Modelo/AnimationPlayer


func ir_ate(destino: Vector3, duracao: float = 3.0) -> void:
	_anim.play("andar")
	var tw := create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tw.tween_property(self, "position", destino, duracao)
	await tw.finished
	_anim.stop(true)


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
