extends Personagem
class_name Tio

# ─────────────────────────────────────────────
#  TIO — personagem que pinta a parede
#
#  Modelo rigado no Blender (res://models/tio_modelo.tscn, 19 ossos + IK — ver
#  PLANO-OVERHAUL-TINTA.md §5). Locomoção (virar antes de andar, atravessar a
#  porta) mora em `personagem.gd`; aqui fica só o que é do tio.
#
#  Dois `AnimationPlayer` no modelo, um pras pernas e um pro braço, porque
#  `pintar_varrendo()` toca os dois ao mesmo tempo.
# ─────────────────────────────────────────────

signal pintura_concluida
signal pincelada  ## emitido a cada passada de braço — som conecta nisso

const DURACAO_PINCELADA: float = 1.1666667  ## duração real do clipe pintar_braco

## ⚠️ `andar` e `pintar_braco` **compartilham osso**, e por isso existe
## `andar_pintando`.
##
## O `PROJETO.md` diz que os dois clipes não têm osso em comum — era verdade no
## rig de 7 ossos, onde o braço era um osso só e a caminhada não o tocava. No rig
## de 19 a caminhada balança os braços (`Ombro_D`, `Braco_D`, `Ombro_E`,
## `Braco_E`) e `pintar_braco` comanda `Ombro_D`, `Braco_D`, `Antebraco_D` e
## `Ombro_E`. Dois `AnimationPlayer` escrevendo no mesmo osso não misturam: quem
## processa por último ganha, e o resultado depende da ordem dos nós.
##
## A saída é uma variante de `andar` **sem nenhuma pista de braço**, montada em
## runtime. Assim os papéis ficam separados por construção: as pernas andam, o
## braço pinta, e ninguém disputa osso.
const OSSOS_DO_BRACO: PackedStringArray = [
	"Ombro_D", "Braco_D", "Antebraco_D", "Mao_D",
	"Ombro_E", "Braco_E", "Antebraco_E", "Mao_E",
]

const CLIPE_ANDAR_PINTANDO: String = "andar_pintando"

@onready var _anim_pernas: AnimationPlayer = $Modelo/AnimationPlayerPernas
@onready var _anim_braco: AnimationPlayer  = $Modelo/AnimationPlayerBraco


func _ready() -> void:
	super()  # sem isto a camada procedural e as IK das pernas não são achadas
	_montar_andar_pintando()
	parar_locomocao()


## Clona `andar` sem as pistas de braço. Ver OSSOS_DO_BRACO pro porquê.
##
## Os dois `AnimationPlayer` compartilham a MESMA `AnimationLibrary`, então
## acrescentar aqui vale pros dois — e por isso o clipe original é duplicado em
## vez de editado no lugar.
func _montar_andar_pintando() -> void:
	var lib: AnimationLibrary = _anim_pernas.get_animation_library("")
	if lib == null or not lib.has_animation("andar"):
		push_warning("Tio: clipe 'andar' não encontrado — o rig mudou?")
		return
	if lib.has_animation(CLIPE_ANDAR_PINTANDO):
		return

	var clipe: Animation = lib.get_animation("andar").duplicate(true)
	# de trás pra frente: remover pista renumera as seguintes
	for i in range(clipe.get_track_count() - 1, -1, -1):
		var caminho: NodePath = clipe.track_get_path(i)
		if caminho.get_subname_count() == 0:
			continue
		if OSSOS_DO_BRACO.has(String(caminho.get_subname(0))):
			clipe.remove_track(i)
	lib.add_animation(CLIPE_ANDAR_PINTANDO, clipe)


func tocar_locomocao() -> void:
	_anim_pernas.play("andar")


## Parado ele respira. O clipe existia desde a Fase D e **nunca era tocado** —
## a alternativa era `stop()`, que deixa o corpo congelado. Respiração é o que
## separa personagem de estátua com script (OVERHAUL §5.3).
func parar_locomocao() -> void:
	_anim_pernas.play("parado_respirando")


## Balança o braço direito devagar, tipo pincelada, por `duracao` segundos,
## parado no lugar. Usado quando ele "termina" um trecho sem se deslocar.
##
## As pernas ficam na pose de repouso em vez de respirar: `parado_respirando`
## também comanda `Ombro_D`/`Ombro_E`, e aí ele disputaria osso com o braço.
func pintar_parede(duracao: float) -> void:
	_anim_pernas.stop(true)
	_anim_braco.play("pintar_braco")
	var repeticoes: int = maxi(1, int(duracao / DURACAO_PINCELADA))
	for i in repeticoes:
		pincelada.emit()
		await get_tree().create_timer(DURACAO_PINCELADA).timeout
	_anim_braco.stop(true)
	parar_locomocao()
	pintura_concluida.emit()


## Vira pra encarar a parede e espera terminar.
##
## Separado de `pintar_varrendo` de propósito: quem chama dispara o trajeto do
## rolo ANTES de esperar a caminhada, então um giro dentro de `pintar_varrendo`
## deixaria o rolo andando meio segundo com o tio parado. Ver ciclo_pintura.gd.
func encarar_parede(angulo_y_graus: float) -> void:
	await girar_para(deg_to_rad(angulo_y_graus))


## Pinta ANDANDO: caminha até `para` encarando a parede (`angulo_y`), com o
## braço em vaivém o tempo todo. A frente de tinta no shader é sincronizada por
## fora, com a mesma duração — ver ciclo_pintura.gd.
##
## Pintando, a regra de orientação é o oposto da caminhada normal: ele encara a
## **parede**, não a direção em que anda. É como se pinta de verdade — andando
## de lado, rente à parede.
func pintar_varrendo(para: Vector3, duracao: float, angulo_y: float) -> void:
	# no-op quando quem chama já virou (o caso normal); protege quem não virou
	await encarar_parede(angulo_y)

	_anim_pernas.play(CLIPE_ANDAR_PINTANDO)
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

	_anim_braco.stop(true)
	parar_locomocao()
	pintura_concluida.emit()
