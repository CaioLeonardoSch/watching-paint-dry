extends CanvasLayer

# ─────────────────────────────────────────────
#  MENU DE PAUSA — ESC durante o jogo
#
#  Pausa de verdade (get_tree().paused) — Tweens e _process de
#  tio.gd/tinta_secando.gd/ciclo_dia_noite.gd já param sozinhos com a árvore
#  pausada (process_mode herdado, default). Esse nó precisa de
#  PROCESS_MODE_ALWAYS pra continuar respondendo input com o jogo parado.
#
#  Não abre durante a cutscene de abertura (câmera da cadeira ainda não
#  ativa) nem por cima da pergunta de cor (dialogo_pintura.gd já é dono do
#  mouse nesse momento) — dono único do ESC durante o jogo,
#  camera_cadeira.gd abriu mão do seu próprio toggle.
# ─────────────────────────────────────────────

@onready var _painel: Control              = $CenterContainer/PainelPausa
@onready var _camera_cadeira: CameraCadeira = $"../Camera3D"
@onready var _dialogo: DialogoPintura       = $"../DialogoPintura"
@onready var _botao_retomar: Button        = $CenterContainer/PainelPausa/VBoxContainer/BotaoRetomar
@onready var _botao_sair: Button           = $CenterContainer/PainelPausa/VBoxContainer/BotaoSair


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_painel.hide()

	_botao_retomar.pressed.connect(_retomar)
	_botao_sair.pressed.connect(_sair_para_menu)


func _unhandled_input(event: InputEvent) -> void:
	if not event.is_action_pressed("ui_cancel"):
		return
	if _dialogo.visible:
		return
	if not _painel.visible and not _camera_cadeira.current:
		return  # ainda na cutscene de abertura, ESC não faz nada

	if _painel.visible:
		_retomar()
	else:
		_pausar()


func _pausar() -> void:
	get_tree().paused = true
	_painel.show()
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)


func _retomar() -> void:
	get_tree().paused = false
	_painel.hide()
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)


func _sair_para_menu() -> void:
	EstadoJogo.salvar()
	get_tree().paused = false
	get_tree().change_scene_to_file("res://scenes/menu_principal.tscn")
