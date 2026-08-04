extends Node3D
class_name Tio

# ─────────────────────────────────────────────
#  TIO — personagem que pinta a parede
#
#  Modelo rigado no Blender (res://models/tio_modelo.tscn, gerado via
#  Blender MCP + GLTFDocument — ver PROJETO.md Fase 1.2). Duas AnimationPlayer
#  no modelo, "andar" e "pintar_braco" não compartilham osso nenhum, então
#  pintar_varrendo() toca as duas ao mesmo tempo sem precisar de AnimationTree.
# ─────────────────────────────────────────────

signal chegou
signal pintura_concluida
signal saiu
signal pincelada  ## emitido a cada passada de braço — som conecta nisso

const DURACAO_PINCELADA: float = 1.1666667  ## duração real do clipe pintar_braco

@onready var _anim_pernas: AnimationPlayer = $Modelo/AnimationPlayerPernas
@onready var _anim_braco: AnimationPlayer  = $Modelo/AnimationPlayerBraco


## Anda em linha reta até `destino` (posição local), devagar — combina com o tom
## "jogo lento" do projeto. Não emite sinal sozinho; quem chama decide o que emitir.
func ir_ate(destino: Vector3, duracao: float = 3.0) -> void:
	_anim_pernas.play("andar")
	var tw := create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tw.tween_property(self, "position", destino, duracao)
	await tw.finished
	_anim_pernas.stop(true)


## Balança o braço direito devagar, tipo pincelada, por `duracao` segundos,
## parado no lugar. Usado quando ele "termina" um trecho sem se deslocar.
func pintar_parede(duracao: float) -> void:
	_anim_braco.play("pintar_braco")
	var repeticoes: int = maxi(1, int(duracao / DURACAO_PINCELADA))
	for i in repeticoes:
		pincelada.emit()
		await get_tree().create_timer(DURACAO_PINCELADA).timeout
	_anim_braco.stop(true)
	pintura_concluida.emit()


## Pinta ANDANDO: caminha de `de` até `para` encarando a parede (`angulo_y`),
## com o braço em vaivém o tempo todo. A frente de tinta no shader é
## sincronizada por fora, com a mesma duração — ver ciclo_pintura.gd.
func pintar_varrendo(de: Vector3, para: Vector3, duracao: float, angulo_y: float) -> void:
	position = de
	rotation_degrees.y = angulo_y

	_anim_pernas.play("andar")
	_anim_braco.play("pintar_braco")

	# Caminhada em velocidade constante: a frente de tinta anda junto, então
	# ease aqui faria o rolo "descolar" do desenho no shader.
	var tw_mov := create_tween().set_trans(Tween.TRANS_LINEAR)
	tw_mov.tween_property(self, "position", para, duracao)

	var repeticoes: int = maxi(1, int(duracao / DURACAO_PINCELADA))
	for i in repeticoes:
		pincelada.emit()
		await get_tree().create_timer(DURACAO_PINCELADA).timeout
	await tw_mov.finished

	_anim_pernas.stop(true)
	_anim_braco.stop(true)
	pintura_concluida.emit()


## Reaparece na porta (ponto_entrada) e anda até `destino`. Reusa a mesma
## instância em vez de recriar o boneco a cada entrada.
func entrar_pela_porta(ponto_entrada: Vector3, destino: Vector3, duracao: float = 2.5) -> void:
	position = ponto_entrada
	show()
	await ir_ate(destino, duracao)
	chegou.emit()


## Anda até a porta e some (fica escondido até a próxima entrada).
func sair_pela_porta(ponto_porta: Vector3, duracao: float = 2.5) -> void:
	await ir_ate(ponto_porta, duracao)
	hide()
	saiu.emit()
