extends Node

# ─────────────────────────────────────────────
#  ESTADO DO JOGO — autoload (singleton "EstadoJogo")
#
#  Primeiro autoload do projeto — só passou a fazer sentido agora que existe
#  estado que precisa sobreviver a troca de cena (menu -> quarto -> menu).
#  Cada script consumidor se autoconfigura a partir daqui no próprio
#  _ready() (ex.: tinta_secando.gd lê tempo_secagem_atual()), em vez de
#  ciclo_pintura.gd empurrar valores pra dentro de nós que não são dele.
#
#  Conquistas chegam no Marco 5 — por enquanto só modo + progresso de cor.
# ─────────────────────────────────────────────

const CAMINHO_SAVE: String = "user://save.tres"

signal conquista_desbloqueada(id: String)

var modo_atual: int = ModoJogo.Modo.RAPIDO  # padrão RAPIDO até o menu escolher
var dados: DadosSalvos


func _ready() -> void:
	_carregar()


func existe_save() -> bool:
	return dados.cor_atual_nome != ""


func iniciar_novo_jogo(modo: int) -> void:
	modo_atual = modo
	dados = DadosSalvos.new()
	dados.modo = modo
	salvar()


func continuar_jogo() -> void:
	modo_atual = dados.modo


## Apaga a partida em andamento (cor atual, demão, modo) — o "Continuar" some
## do menu depois disso. Conquistas desbloqueadas e o histórico de cores já
## vistas (cores_completas_*) são preservados de propósito: é reset de
## partida, não perda de progresso permanente/conquistas.
func apagar_save() -> void:
	var conquistas := dados.conquistas_desbloqueadas
	var cores_geral := dados.cores_completas_geral
	var cores_rapido := dados.cores_completas_rapido
	var cores_normal := dados.cores_completas_normal
	var cores_realista := dados.cores_completas_realista

	dados = DadosSalvos.new()
	dados.conquistas_desbloqueadas = conquistas
	dados.cores_completas_geral = cores_geral
	dados.cores_completas_rapido = cores_rapido
	dados.cores_completas_normal = cores_normal
	dados.cores_completas_realista = cores_realista

	salvar()


func tempo_secagem_atual() -> float:
	return ModoJogo.TEMPO_SECAGEM[modo_atual]


func duracao_dia_atual() -> float:
	return ModoJogo.DURACAO_DIA[modo_atual]


## Checkpoint — só chamado depois que uma demão seca de verdade, nunca no
## meio da animação (ver ciclo_pintura.gd).
func salvar_progresso_pintura(nome_cor: String, demao: int) -> void:
	dados.cor_atual_nome = nome_cor
	dados.demao_atual    = demao
	dados.modo           = modo_atual
	salvar()


## Chamado por ciclo_pintura.gd quando uma cor termina as 3 demãos — antes
## da pergunta "gostou?" aparecer, já vale como "viu todas as demãos".
func registrar_ciclo_completo(nome_cor: String) -> void:
	var mudou: bool = _desbloquear(Conquistas.ID_PRIMEIRA_COR)

	if nome_cor not in dados.cores_completas_geral:
		dados.cores_completas_geral.append(nome_cor)
		mudou = true

	var id_cor: String = Conquistas.id_para_cor(nome_cor)
	if id_cor != "" and _desbloquear(id_cor):
		mudou = true

	var lista_modo: Array[String] = _lista_por_modo(modo_atual)
	if nome_cor not in lista_modo:
		lista_modo.append(nome_cor)
		mudou = true

	if Conquistas.todas_seis_cores(lista_modo) and _desbloquear(Conquistas.id_do_modo(modo_atual)):
		mudou = true

	if mudou:
		salvar()


func _lista_por_modo(modo: int) -> Array[String]:
	match modo:
		ModoJogo.Modo.RAPIDO:
			return dados.cores_completas_rapido
		ModoJogo.Modo.NORMAL:
			return dados.cores_completas_normal
		_:
			return dados.cores_completas_realista


## Marca a conquista como desbloqueada se ainda não estava. Devolve true só
## quando muda de estado (pra saber se vale emitir o sinal/salvar).
func _desbloquear(id: String) -> bool:
	if id in dados.conquistas_desbloqueadas:
		return false
	dados.conquistas_desbloqueadas.append(id)
	conquista_desbloqueada.emit(id)
	return true


func salvar() -> void:
	ResourceSaver.save(dados, CAMINHO_SAVE)


func _carregar() -> void:
	if ResourceLoader.exists(CAMINHO_SAVE):
		dados = ResourceLoader.load(CAMINHO_SAVE) as DadosSalvos
	if dados == null:
		dados = DadosSalvos.new()
