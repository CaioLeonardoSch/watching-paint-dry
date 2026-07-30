extends CanvasLayer
class_name DialogoPintura

# ─────────────────────────────────────────────
#  DIÁLOGO DE PINTURA — pergunta "gostou da cor?" + paleta de troca
#
#  UI mínima: dois painéis (pergunta / paleta), escondidos por padrão.
#  As funções públicas são co-rotinas que mostram o painel certo, esperam
#  o jogador clicar (via sinal interno) e devolvem a escolha.
# ─────────────────────────────────────────────

const DURACAO_FADE: float = 0.15

signal _resposta_pergunta(gostou: bool)
signal _cor_escolhida(cor: CorTinta)

## Azul é a cor inicial (fora da rotação de conquista) + as 6 que batem com
## as conquistas 2-7 (ver conquistas.gd). A cor atual nunca aparece como
## opção — sempre "as outras 6", pra dar pra passar por todas com o tempo.
const CAMINHOS_PALETA: Array[String] = [
	"res://resources/cores/azul.tres",
	"res://resources/cores/vermelho.tres",
	"res://resources/cores/laranja.tres",
	"res://resources/cores/amarelo.tres",
	"res://resources/cores/verde.tres",
	"res://resources/cores/violeta.tres",
	"res://resources/cores/rosa.tres",
]

var paleta: Array[CorTinta] = []

@onready var _painel_pergunta: Control  = $CenterContainer/PainelPergunta
@onready var _painel_paleta: Control    = $CenterContainer/PainelPaleta
@onready var _botao_gostei: Button      = $CenterContainer/PainelPergunta/VBoxContainer/HBoxContainer/BotaoGostei
@onready var _botao_trocar: Button      = $CenterContainer/PainelPergunta/VBoxContainer/HBoxContainer/BotaoTrocar
@onready var _container_cores: HBoxContainer = $CenterContainer/PainelPaleta/VBoxContainer/ContainerCores


func _ready() -> void:
	visible = false
	_painel_pergunta.hide()
	_painel_paleta.hide()

	_botao_gostei.pressed.connect(func() -> void: _resposta_pergunta.emit(true))
	_botao_trocar.pressed.connect(func() -> void: _resposta_pergunta.emit(false))

	for caminho in CAMINHOS_PALETA:
		var cor := load(caminho) as CorTinta
		if cor:
			paleta.append(cor)


## Reconstrói os botões toda vez — a cor atual muda a cada chamada, então
## a lista de "outras cores" também muda (nunca mostra a que já tá na parede).
func _montar_botoes_paleta(cor_atual: CorTinta) -> void:
	for filho in _container_cores.get_children():
		filho.queue_free()

	for cor in paleta:
		if cor_atual and cor.nome == cor_atual.nome:
			continue
		var botao := Button.new()
		botao.text = cor.nome
		botao.custom_minimum_size = Vector2(90, 40)

		var estilo := StyleBoxFlat.new()
		estilo.bg_color = cor.variantes_secas[-1] if cor.variantes_secas.size() > 0 else cor.cor_molhada_base
		estilo.corner_radius_top_left     = 4
		estilo.corner_radius_top_right    = 4
		estilo.corner_radius_bottom_left  = 4
		estilo.corner_radius_bottom_right = 4
		botao.add_theme_stylebox_override("normal", estilo)

		botao.pressed.connect(func() -> void: _cor_escolhida.emit(cor))
		_container_cores.add_child(botao)


## Mostra "gostou da cor?" e devolve true (gostou) / false (quer trocar).
func perguntar_gostou() -> bool:
	visible = true
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	await _fade_in(_painel_pergunta)

	var gostou: bool = await _resposta_pergunta

	await _fade_out(_painel_pergunta)
	visible = false
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	return gostou


## Mostra a paleta (sem a cor_atual, pra sempre oferecer as outras 6) e
## devolve a CorTinta escolhida.
func escolher_cor(cor_atual: CorTinta) -> CorTinta:
	_montar_botoes_paleta(cor_atual)
	visible = true
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	await _fade_in(_painel_paleta)

	var cor: CorTinta = await _cor_escolhida

	await _fade_out(_painel_paleta)
	visible = false
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	return cor


func _fade_in(painel: Control) -> void:
	painel.modulate.a = 0.0
	painel.show()
	var tw := create_tween()
	tw.tween_property(painel, "modulate:a", 1.0, DURACAO_FADE)
	await tw.finished


func _fade_out(painel: Control) -> void:
	var tw := create_tween()
	tw.tween_property(painel, "modulate:a", 0.0, DURACAO_FADE)
	await tw.finished
	painel.hide()
	painel.modulate.a = 1.0
