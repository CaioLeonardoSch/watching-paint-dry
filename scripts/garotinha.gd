extends Personagem
class_name Garotinha

# ─────────────────────────────────────────────
#  GAROTINHA — personagem que assiste a tinta secar
#
#  Modelo rigado no Blender (res://models/garotinha_modelo.tscn, 13 ossos — ela
#  não tem cotovelo nem ombro separados, porque nunca precisa pintar). A
#  locomoção mora em `personagem.gd`.
#
#  Sentar virou pose de osso de verdade (OVERHAUL §5.7). Antes era um Tween de
#  `position.y` de 15 cm seguido de `hide()` — ela afundava no chão e sumia.
#  Agora ela dobra quadril e joelho na cadeira, e o corpo só some quando a
#  câmera da cadeira assume (aí ele viraria clipping na frente da lente).
# ─────────────────────────────────────────────

signal sentou

## Altura do assento da cadeira, de `inicializar_quarto.gd::_criar_cadeira`
## (`alt_assento` 0,45 + metade da espessura 0,05). Se a cadeira mudar, muda aqui.
const ALTURA_ASSENTO: float = 0.475

## Quanto o quadril desce pra pousar no assento, como fração de `queda_maxima`
## do `PosturaModifier` (0,20 m no modelo dela).
##
## Conta: o quadril dela em pé está em 0,55 e a articulação tem que ficar logo
## acima do assento (0,475), ou seja ~0,50 — são 5 cm, que é 0,25 de 0,20 m. A
## raiz do personagem **não sobe**: quem levanta o corpo é a perna dobrando, e
## era justamente o Tween de `position:y` que fazia ela afundar no chão antes.
const AGACHAMENTO_SENTADA: float = 0.25

## Onde os pés vão parar quando ela senta, a partir do repouso: pra frente
## (−Z é a frente do modelo) e **pra cima**, porque a canela dela tem 24 cm e o
## assento está a 47,5 — ela não alcança o chão. O pé balançando no ar é o
## detalhe que entrega a idade dela sem dizer nada.
const PES_SENTADA: Vector3 = Vector3(0.0, 0.21, -0.24)

const DURACAO_SENTAR: float = 1.1

@onready var _anim: AnimationPlayer = $Modelo/AnimationPlayer


func _ready() -> void:
	super()
	parar_locomocao()


func tocar_locomocao() -> void:
	_anim.play("andar")


func parar_locomocao() -> void:
	_anim.play("parado_respirando")


## Entra pela porta, anda até a cadeira, vira pra encarar a parede norte e senta.
##
## Ela encara a parede NORTE (ângulo 0 = olhando pra −Z), não a direção em que
## veio andando: é a parede que ela vai ficar vendo secar.
func entrar_e_sentar(destino_cadeira: Vector3) -> void:
	await entrar_pela_porta(destino_cadeira, 3.4)
	await girar_para(0.0)
	await sentar()


## Dobra quadril e joelhos até assentar. O corpo continua visível — quem esconde
## é quem troca a câmera.
##
## `parado_respirando` continua tocando: nas pistas dela não há Quadril nem
## perna (só coluna, braços e cabeça), então ela respira sentada sem disputar
## osso nenhum com a camada procedural. Conferido nas pistas do modelo.
func sentar() -> void:
	var tw := create_tween().set_parallel(true)
	tw.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tw.tween_method(definir_agachamento, 0.0, AGACHAMENTO_SENTADA, DURACAO_SENTAR)
	tw.tween_method(definir_pose_pes, Vector3.ZERO, PES_SENTADA, DURACAO_SENTAR)
	await tw.finished
	sentou.emit()
