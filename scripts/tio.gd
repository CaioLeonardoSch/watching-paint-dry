extends Node3D
class_name Tio

# ─────────────────────────────────────────────
#  TIO — personagem que pinta a parede
#
#  Geometria "boneco de placeholder" (cápsulas/esfera), sem asset externo,
#  montada em código no mesmo padrão de _criar_lampada() em inicializar_quarto.gd.
#  Movimento e pintura são Tweens simples — sem física, sem pathfinding
#  (o quarto é pequeno e retangular, não precisa).
# ─────────────────────────────────────────────

signal chegou
signal pintura_concluida
signal saiu
signal pincelada  ## emitido a cada passada de braço em pintar_parede() — som conecta nisso

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
	var cor_pele  := Color(0.85, 0.68, 0.52)
	var cor_roupa := Color(0.32, 0.42, 0.52)

	_montar_capsula(_corpo, 0.22, 0.7, Vector3(0, 1.15, 0), cor_roupa)
	_montar_esfera(_cabeca, 0.15, Vector3(0, 1.65, 0), cor_pele)
	_montar_capsula(_perna_esquerda, 0.12, 0.9, Vector3(-0.12, 0.45, 0), cor_roupa)
	_montar_capsula(_perna_direita,  0.12, 0.9, Vector3(0.12, 0.45, 0), cor_roupa)

	_pivo_braco_esquerdo.position = Vector3(-0.28, 1.35, 0)
	_pivo_braco_direito.position  = Vector3(0.28, 1.35, 0)
	_montar_capsula(_braco_esquerdo, 0.08, 0.5, Vector3(0, -0.25, 0), cor_pele)
	_montar_capsula(_braco_direito,  0.08, 0.5, Vector3(0, -0.25, 0), cor_pele)


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


## Anda em linha reta até `destino` (posição local), devagar — combina com o tom
## "jogo lento" do projeto. Não emite sinal sozinho; quem chama decide o que emitir.
func ir_ate(destino: Vector3, duracao: float = 3.0) -> void:
	var tw := create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tw.tween_property(self, "position", destino, duracao)
	await tw.finished


## Balança o braço direito devagar, tipo pincelada, por `duracao` segundos,
## parado no lugar. Usado quando ele "termina" um trecho sem se deslocar.
func pintar_parede(duracao: float) -> void:
	var repeticoes: int = maxi(1, int(duracao / 1.2))
	for i in repeticoes:
		pincelada.emit()
		var ida := create_tween().set_trans(Tween.TRANS_SINE)
		ida.tween_property(_pivo_braco_direito, "rotation:x", -0.9, 0.6)
		await ida.finished

		var volta := create_tween().set_trans(Tween.TRANS_SINE)
		volta.tween_property(_pivo_braco_direito, "rotation:x", 0.1, 0.6)
		await volta.finished
	pintura_concluida.emit()


## Pinta ANDANDO: caminha de `de` até `para` encarando a parede (`angulo_y`),
## com o braço em vaivém o tempo todo. A frente de tinta no shader é
## sincronizada por fora, com a mesma duração — ver ciclo_pintura.gd.
func pintar_varrendo(de: Vector3, para: Vector3, duracao: float, angulo_y: float) -> void:
	position = de
	rotation_degrees.y = angulo_y

	# Braço em loop infinito, morto no fim — a caminhada é quem define o tempo
	var tw_braco := create_tween().set_loops()
	tw_braco.tween_callback(func() -> void: pincelada.emit())
	tw_braco.tween_property(_pivo_braco_direito, "rotation:x", -0.9, 0.55).set_trans(Tween.TRANS_SINE)
	tw_braco.tween_property(_pivo_braco_direito, "rotation:x", 0.1, 0.55).set_trans(Tween.TRANS_SINE)

	# Caminhada em velocidade constante: a frente de tinta anda junto, então
	# ease aqui faria o rolo "descolar" do desenho no shader.
	var tw_mov := create_tween().set_trans(Tween.TRANS_LINEAR)
	tw_mov.tween_property(self, "position", para, duracao)
	await tw_mov.finished

	tw_braco.kill()
	var descanso := create_tween().set_trans(Tween.TRANS_SINE)
	descanso.tween_property(_pivo_braco_direito, "rotation:x", 0.0, 0.3)
	await descanso.finished
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
