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

## ⚠️ Iguais às do `Button` em `resources/ui/theme_principal.tres`. O botão da
## paleta troca as 4 stylebox por versões coloridas, e o tamanho mínimo dele
## sai da stylebox `normal` — se a `hover` do tema (16 px de margem) entrar no
## lugar de uma `normal` sem margem, o espaço de texto encolhe 32 px NO HOVER e
## a palavra sai cortada. Era o "Amarelo" virando "Amar" ao passar o mouse.
const MARGEM_BOTAO_H: float = 16.0
const MARGEM_BOTAO_V: float = 8.0

const COR_FOCO: Color = Color(0.85, 0.65, 0.35)
const COR_TEXTO_CLARO: Color = Color(0.98, 0.96, 0.92)
const COR_TEXTO_ESCURO: Color = Color(0.12, 0.09, 0.06)

## Acima disto o fundo é claro demais pra texto claro. Medido no estado mais
## claro do botão (hover), não no normal, pra cor do texto não trocar embaixo
## do mouse: amarelo, laranja e rosa caem do lado escuro.
const LIMIAR_TEXTO_ESCURO: float = 0.52

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
		_container_cores.add_child(_criar_botao_cor(cor))


## Amostra da paleta mostra a cor cheia — é o que a parede vira no fim.
##
## As 4 stylebox são geradas juntas de propósito: sobrescrever só a `normal`
## deixava o tema entrar no hover, e aí o botão perdia a cor (virava marrom) e
## ainda cortava o texto por causa da margem diferente. Todas com a mesma
## margem, então o tamanho do botão não muda de estado pra estado.
func _criar_botao_cor(cor: CorTinta) -> Button:
	var cheia: Color = cor.cor_alvo
	var clara: Color = cheia.lightened(0.18)
	var escura: Color = cheia.darkened(0.18)

	var botao := Button.new()
	botao.text = tr(cor.nome)
	botao.custom_minimum_size = Vector2(96, 44)
	botao.tooltip_text = tr(cor.nome)
	botao.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND

	botao.add_theme_stylebox_override("normal", _estilo_amostra(cheia, cheia.darkened(0.40)))
	botao.add_theme_stylebox_override("hover", _estilo_amostra(clara, COR_TEXTO_CLARO))
	botao.add_theme_stylebox_override("pressed", _estilo_amostra(escura, cheia.darkened(0.50)))
	# foco desenha POR CIMA do estado atual — fundo transparente, só a borda
	botao.add_theme_stylebox_override("focus", _estilo_amostra(Color(0, 0, 0, 0), COR_FOCO))

	var texto: Color = COR_TEXTO_CLARO
	if clara.get_luminance() > LIMIAR_TEXTO_ESCURO:
		texto = COR_TEXTO_ESCURO
	botao.add_theme_color_override("font_color", texto)
	botao.add_theme_color_override("font_hover_color", texto)
	botao.add_theme_color_override("font_pressed_color", texto)
	botao.add_theme_color_override("font_focus_color", texto)

	botao.pressed.connect(func() -> void: _cor_escolhida.emit(cor))
	return botao


func _estilo_amostra(fundo: Color, borda: Color) -> StyleBoxFlat:
	var estilo := StyleBoxFlat.new()
	estilo.bg_color = fundo
	estilo.set_corner_radius_all(6)
	estilo.set_border_width_all(2)
	estilo.border_color = borda
	estilo.content_margin_left   = MARGEM_BOTAO_H
	estilo.content_margin_right  = MARGEM_BOTAO_H
	estilo.content_margin_top    = MARGEM_BOTAO_V
	estilo.content_margin_bottom = MARGEM_BOTAO_V
	return estilo


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
