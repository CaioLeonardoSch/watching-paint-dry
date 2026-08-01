extends CanvasLayer

# ─────────────────────────────────────────────
#  MENU DE PAUSA — ESC durante o jogo
#
#  Pausa de verdade (get_tree().paused) — Tweens e _process de
#  tio.gd e parede_pintavel.gd já param sozinhos com a árvore
#  pausada (process_mode herdado, default). Esse nó precisa de
#  PROCESS_MODE_ALWAYS pra continuar respondendo input com o jogo parado.
#
#  Não abre durante a cutscene de abertura (câmera da cadeira ainda não
#  ativa) nem por cima da pergunta de cor (dialogo_pintura.gd já é dono do
#  mouse nesse momento) — dono único do ESC durante o jogo,
#  camera_cadeira.gd abriu mão do seu próprio toggle.
#
#  O CenterContainer é tela cheia e mora numa layer ACIMA do DialogoPintura,
#  então tem mouse_filter = IGNORE na cena: com STOP (default do Control) ele
#  engolia todo clique e travava os botões "Gostei"/"Trocar". Os painéis
#  filhos continuam STOP, então o menu em si segue clicável.
# ─────────────────────────────────────────────

const DURACAO_FADE: float = 0.15

@onready var _painel: Control              = $CenterContainer/PainelPausa
@onready var _painel_opcoes: PainelOpcoes  = $CenterContainer/PainelOpcoes
@onready var _camera_cadeira: CameraCadeira = $"../Camera3D"
@onready var _dialogo: DialogoPintura       = $"../DialogoPintura"
@onready var _botao_retomar: Button        = $CenterContainer/PainelPausa/VBoxContainer/BotaoRetomar
@onready var _botao_opcoes: Button         = $CenterContainer/PainelPausa/VBoxContainer/BotaoOpcoes
@onready var _botao_sair: Button           = $CenterContainer/PainelPausa/VBoxContainer/BotaoSair

var _mostrando_opcoes: bool = false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_painel.hide()
	_painel_opcoes.hide()

	_botao_retomar.pressed.connect(_retomar)
	_botao_opcoes.pressed.connect(_mostrar_opcoes)
	_botao_sair.pressed.connect(_sair_para_menu)
	_painel_opcoes.fechado.connect(_fechar_opcoes)


func _unhandled_input(event: InputEvent) -> void:
	if not event.is_action_pressed("ui_cancel"):
		return
	if _dialogo.visible:
		return
	if not get_tree().paused and not _camera_cadeira.current:
		return  # ainda na cutscene de abertura, ESC não faz nada

	if _mostrando_opcoes:
		_fechar_opcoes()
	elif get_tree().paused:
		_retomar()
	else:
		_pausar()


func _pausar() -> void:
	get_tree().paused = true
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	_painel.modulate.a = 0.0
	_painel.show()
	var tw := create_tween()
	tw.tween_property(_painel, "modulate:a", 1.0, DURACAO_FADE)


func _retomar() -> void:
	var tw := create_tween()
	tw.tween_property(_painel, "modulate:a", 0.0, DURACAO_FADE)
	await tw.finished
	_painel.hide()
	get_tree().paused = false
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)


func _mostrar_opcoes() -> void:
	_mostrando_opcoes = true
	await _trocar_painel(_painel, _painel_opcoes)


func _fechar_opcoes() -> void:
	_mostrando_opcoes = false
	await _trocar_painel(_painel_opcoes, _painel)


func _trocar_painel(atual: Control, novo: Control) -> void:
	var tw_saida := create_tween()
	tw_saida.tween_property(atual, "modulate:a", 0.0, DURACAO_FADE)
	await tw_saida.finished
	atual.hide()
	atual.modulate.a = 1.0

	novo.modulate.a = 0.0
	novo.show()
	var tw_entrada := create_tween()
	tw_entrada.tween_property(novo, "modulate:a", 1.0, DURACAO_FADE)
	await tw_entrada.finished


func _sair_para_menu() -> void:
	EstadoJogo.salvar()
	get_tree().paused = false
	get_tree().change_scene_to_file("res://scenes/menu_principal.tscn")
