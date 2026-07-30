extends PanelContainer
class_name PainelOpcoes

# ─────────────────────────────────────────────
#  PAINEL DE OPÇÕES — reusado no menu principal e no menu de pausa
#
#  Só UI: lê/escreve direto no autoload Opcoes. Quem mostra/esconde e faz a
#  transição é o painel pai (menu_principal.gd / menu_pausa.gd) — este nó só
#  avisa via sinal "fechado" quando o botão Voltar é clicado.
# ─────────────────────────────────────────────

signal fechado

@onready var _slider_volume: HSlider = $VBoxContainer/SliderVolume
@onready var _check_tela_cheia: CheckButton = $VBoxContainer/CheckTelaCheia
@onready var _botao_voltar: Button = $VBoxContainer/BotaoVoltar


func _ready() -> void:
	_slider_volume.value = Opcoes.volume
	_check_tela_cheia.button_pressed = Opcoes.tela_cheia

	_slider_volume.value_changed.connect(Opcoes.definir_volume)
	_check_tela_cheia.toggled.connect(Opcoes.definir_tela_cheia)
	_botao_voltar.pressed.connect(func() -> void: fechado.emit())
