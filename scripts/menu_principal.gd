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

const DURACAO_FADE: float = 0.15

@onready var _painel_titulo: Control      = $CenterContainer/PainelTitulo
@onready var _painel_modo: Control        = $CenterContainer/PainelModo
@onready var _painel_conquistas: Control  = $CenterContainer/PainelConquistas
@onready var _painel_opcoes: PainelOpcoes = $CenterContainer/PainelOpcoes
@onready var _painel_confirmar_exclusao: Control = $CenterContainer/PainelConfirmarExclusao

@onready var _linha_continuar: Control  = $CenterContainer/PainelTitulo/VBoxContainer/LinhaContinuar
@onready var _botao_continuar: Button   = $CenterContainer/PainelTitulo/VBoxContainer/LinhaContinuar/BotaoContinuar
@onready var _botao_excluir_save: Button = $CenterContainer/PainelTitulo/VBoxContainer/LinhaContinuar/BotaoExcluirSave
@onready var _botao_jogar: Button       = $CenterContainer/PainelTitulo/VBoxContainer/BotaoJogar
@onready var _botao_conquistas: Button  = $CenterContainer/PainelTitulo/VBoxContainer/BotaoConquistas
@onready var _botao_opcoes: Button      = $CenterContainer/PainelTitulo/VBoxContainer/BotaoOpcoes
@onready var _botao_sair: Button        = $CenterContainer/PainelTitulo/VBoxContainer/BotaoSair

@onready var _botao_confirmar_exclusao: Button = $CenterContainer/PainelConfirmarExclusao/VBoxContainer/HBoxContainer/BotaoConfirmarExclusao
@onready var _botao_cancelar_exclusao: Button  = $CenterContainer/PainelConfirmarExclusao/VBoxContainer/HBoxContainer/BotaoCancelarExclusao

var _painel_atual: Control

@onready var _botao_rapido: Button   = $CenterContainer/PainelModo/VBoxContainer/BotaoRapido
@onready var _botao_normal: Button   = $CenterContainer/PainelModo/VBoxContainer/BotaoNormal
@onready var _botao_realista: Button = $CenterContainer/PainelModo/VBoxContainer/BotaoRealista
@onready var _botao_voltar: Button   = $CenterContainer/PainelModo/VBoxContainer/BotaoVoltar

@onready var _lista_conquistas: VBoxContainer = $CenterContainer/PainelConquistas/VBoxContainer/ScrollContainer/ListaConquistas
@onready var _botao_voltar_conquistas: Button = $CenterContainer/PainelConquistas/VBoxContainer/BotaoVoltarConquistas

@onready var _seletor_idioma: OptionButton = $SeletorIdioma


func _ready() -> void:
	_painel_atual = _painel_titulo
	_painel_modo.hide()
	_painel_conquistas.hide()
	_painel_opcoes.hide()
	_painel_confirmar_exclusao.hide()
	_linha_continuar.hide()

	if EstadoJogo.existe_save():
		_mostrar_linha_continuar()

	_botao_jogar.pressed.connect(_mostrar_painel_modo)

	_botao_conquistas.pressed.connect(_mostrar_painel_conquistas)
	_botao_opcoes.pressed.connect(_mostrar_painel_opcoes)
	_botao_excluir_save.pressed.connect(_mostrar_painel_confirmar_exclusao)
	_botao_sair.pressed.connect(func() -> void: get_tree().quit())

	_botao_rapido.pressed.connect(_iniciar_jogo.bind(ModoJogo.Modo.RAPIDO))
	_botao_normal.pressed.connect(_iniciar_jogo.bind(ModoJogo.Modo.NORMAL))
	_botao_realista.pressed.connect(_iniciar_jogo.bind(ModoJogo.Modo.REALISTA))
	_botao_voltar.pressed.connect(_mostrar_painel_titulo)
	_botao_voltar_conquistas.pressed.connect(_mostrar_painel_titulo)
	_painel_opcoes.fechado.connect(_mostrar_painel_titulo)
	_botao_confirmar_exclusao.pressed.connect(_confirmar_exclusao_save)
	_botao_cancelar_exclusao.pressed.connect(_mostrar_painel_titulo)

	_montar_seletor_idioma()


func _mostrar_linha_continuar() -> void:
	_linha_continuar.show()
	if not _botao_continuar.pressed.is_connected(_continuar_jogo):
		_botao_continuar.pressed.connect(_continuar_jogo)
	_botao_jogar.text = tr("Novo Jogo")


## Lista fixa (dicionário Opcoes.IDIOMAS preserva ordem de inserção) — nome de
## cada idioma exibido no idioma atual (chave IDIOMA_NOME_* traduzida).
func _montar_seletor_idioma() -> void:
	var indice: int = 0
	var indice_atual: int = 0
	for codigo in Opcoes.IDIOMAS:
		var chave_nome: String = Opcoes.IDIOMAS[codigo]
		_seletor_idioma.add_item(tr(chave_nome))
		_seletor_idioma.set_item_metadata(indice, codigo)
		if codigo == Opcoes.idioma:
			indice_atual = indice
		indice += 1
	_seletor_idioma.select(indice_atual)
	_seletor_idioma.item_selected.connect(_ao_trocar_idioma)


func _ao_trocar_idioma(indice: int) -> void:
	var codigo: String = _seletor_idioma.get_item_metadata(indice)
	Opcoes.definir_idioma(codigo)


func _mostrar_painel_modo() -> void:
	await _trocar_painel(_painel_modo)


func _mostrar_painel_conquistas() -> void:
	_montar_lista_conquistas()
	await _trocar_painel(_painel_conquistas)


func _mostrar_painel_opcoes() -> void:
	await _trocar_painel(_painel_opcoes)


func _mostrar_painel_titulo() -> void:
	await _trocar_painel(_painel_titulo)


func _mostrar_painel_confirmar_exclusao() -> void:
	await _trocar_painel(_painel_confirmar_exclusao)


## Apaga o save (conquistas continuam salvas — ver estado_jogo.gd::apagar_save)
## e some com "Continuar"/lixeira, voltando "Jogar" ao texto normal.
func _confirmar_exclusao_save() -> void:
	EstadoJogo.apagar_save()
	_linha_continuar.hide()
	_botao_jogar.text = tr("Jogar")
	await _mostrar_painel_titulo()


## Crossfade curto entre painéis do CenterContainer — evita o corte seco de
## show()/hide() sem deixar dois painéis sobrepostos ao mesmo tempo.
func _trocar_painel(novo: Control) -> void:
	var atual := _painel_atual

	var tw_saida := create_tween()
	tw_saida.tween_property(atual, "modulate:a", 0.0, DURACAO_FADE)
	await tw_saida.finished
	atual.hide()
	atual.modulate.a = 1.0

	novo.modulate.a = 0.0
	novo.show()
	_painel_atual = novo
	var tw_entrada := create_tween()
	tw_entrada.tween_property(novo, "modulate:a", 1.0, DURACAO_FADE)
	await tw_entrada.finished


func _montar_lista_conquistas() -> void:
	for filho in _lista_conquistas.get_children():
		filho.queue_free()

	for id in Conquistas.ORDEM:
		var desbloqueada: bool = id in EstadoJogo.dados.conquistas_desbloqueadas
		var label := Label.new()
		var texto: String = tr(Conquistas.TEXTOS.get(id, id))
		label.text = ("✓ " + texto) if desbloqueada else ("??? " + texto)
		label.modulate = Color(1, 1, 1, 1) if desbloqueada else Color(1, 1, 1, 0.4)
		_lista_conquistas.add_child(label)


func _iniciar_jogo(modo: int) -> void:
	EstadoJogo.iniciar_novo_jogo(modo)
	get_tree().change_scene_to_file("res://scenes/quarto.tscn")


func _continuar_jogo() -> void:
	EstadoJogo.continuar_jogo()
	get_tree().change_scene_to_file("res://scenes/quarto.tscn")
