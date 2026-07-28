extends Control

# ─────────────────────────────────────────────
#  MENU PRINCIPAL — tela título
#
#  Com save existente, aparece um "Continuar" extra (pula direto pro jogo,
#  modo já escolhido antes) e "Jogar" vira "Novo Jogo" (abre o seletor de
#  modo, sobrescreve o save ao escolher). Sem save, só "Jogar" mesmo,
#  também abrindo o seletor de modo. "Conquistas" mostra a lista fixa
#  (Conquistas.ORDEM), marcando desbloqueada/bloqueada conforme
#  EstadoJogo.dados.
# ─────────────────────────────────────────────

@onready var _painel_titulo: Control      = $CenterContainer/PainelTitulo
@onready var _painel_modo: Control        = $CenterContainer/PainelModo
@onready var _painel_conquistas: Control  = $CenterContainer/PainelConquistas

@onready var _botao_continuar: Button   = $CenterContainer/PainelTitulo/VBoxContainer/BotaoContinuar
@onready var _botao_jogar: Button       = $CenterContainer/PainelTitulo/VBoxContainer/BotaoJogar
@onready var _botao_conquistas: Button  = $CenterContainer/PainelTitulo/VBoxContainer/BotaoConquistas
@onready var _botao_sair: Button        = $CenterContainer/PainelTitulo/VBoxContainer/BotaoSair

@onready var _botao_rapido: Button   = $CenterContainer/PainelModo/VBoxContainer/BotaoRapido
@onready var _botao_normal: Button   = $CenterContainer/PainelModo/VBoxContainer/BotaoNormal
@onready var _botao_realista: Button = $CenterContainer/PainelModo/VBoxContainer/BotaoRealista
@onready var _botao_voltar: Button   = $CenterContainer/PainelModo/VBoxContainer/BotaoVoltar

@onready var _lista_conquistas: VBoxContainer = $CenterContainer/PainelConquistas/VBoxContainer/ScrollContainer/ListaConquistas
@onready var _botao_voltar_conquistas: Button = $CenterContainer/PainelConquistas/VBoxContainer/BotaoVoltarConquistas


func _ready() -> void:
	_painel_modo.hide()
	_painel_conquistas.hide()

	if EstadoJogo.existe_save():
		_botao_continuar.show()
		_botao_continuar.pressed.connect(_continuar_jogo)
		_botao_jogar.text = "Novo Jogo"

	_botao_jogar.pressed.connect(_mostrar_painel_modo)

	_botao_conquistas.pressed.connect(_mostrar_painel_conquistas)
	_botao_sair.pressed.connect(func() -> void: get_tree().quit())

	_botao_rapido.pressed.connect(_iniciar_jogo.bind(ModoJogo.Modo.RAPIDO))
	_botao_normal.pressed.connect(_iniciar_jogo.bind(ModoJogo.Modo.NORMAL))
	_botao_realista.pressed.connect(_iniciar_jogo.bind(ModoJogo.Modo.REALISTA))
	_botao_voltar.pressed.connect(_mostrar_painel_titulo)
	_botao_voltar_conquistas.pressed.connect(_mostrar_painel_titulo)


func _mostrar_painel_modo() -> void:
	_painel_titulo.hide()
	_painel_modo.show()


func _mostrar_painel_conquistas() -> void:
	_montar_lista_conquistas()
	_painel_titulo.hide()
	_painel_conquistas.show()


func _mostrar_painel_titulo() -> void:
	_painel_modo.hide()
	_painel_conquistas.hide()
	_painel_titulo.show()


func _montar_lista_conquistas() -> void:
	for filho in _lista_conquistas.get_children():
		filho.queue_free()

	for id in Conquistas.ORDEM:
		var desbloqueada: bool = id in EstadoJogo.dados.conquistas_desbloqueadas
		var label := Label.new()
		var texto: String = Conquistas.TEXTOS.get(id, id)
		label.text = ("✓ " + texto) if desbloqueada else ("??? " + texto)
		label.modulate = Color(1, 1, 1, 1) if desbloqueada else Color(1, 1, 1, 0.4)
		_lista_conquistas.add_child(label)


func _iniciar_jogo(modo: int) -> void:
	EstadoJogo.iniciar_novo_jogo(modo)
	get_tree().change_scene_to_file("res://scenes/quarto.tscn")


func _continuar_jogo() -> void:
	EstadoJogo.continuar_jogo()
	get_tree().change_scene_to_file("res://scenes/quarto.tscn")
