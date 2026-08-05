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
#  DOIS arquivos em disco, não um:
#
#    user://save.tres        partida em andamento (cor, demão, modo)
#    user://conquistas.tres  conquista e progresso permanente
#
#  A separação é o ponto, não organização: nada que mexa no save pode encostar
#  em conquista. Antes era um arquivo só e `iniciar_novo_jogo()` zerava o
#  DadosSalvos inteiro — quem começava partida nova perdia tudo que tinha
#  desbloqueado.
# ─────────────────────────────────────────────

const CAMINHO_SAVE: String = "user://save.tres"
const CAMINHO_CONQUISTAS: String = "user://conquistas.tres"

signal conquista_desbloqueada(id: String)

var modo_atual: int = ModoJogo.Modo.RAPIDO  # padrão RAPIDO até o menu escolher
var dados: DadosSalvos
var conquistas: DadosConquistas


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
## do menu depois disso. Conquista não mora mais neste arquivo, então zerar o
## save não tem mais como levar progresso permanente junto.
func apagar_save() -> void:
	dados = DadosSalvos.new()
	salvar()


func tempo_secagem_atual() -> float:
	return ModoJogo.TEMPO_SECAGEM[modo_atual]


## Checkpoint — só chamado depois que uma demão seca de verdade, nunca no
## meio da animação (ver ciclo_pintura.gd).
func salvar_progresso_pintura(nome_cor: String, demao: int) -> void:
	dados.cor_atual_nome = nome_cor
	dados.demao_atual    = demao
	dados.modo           = modo_atual
	salvar()


# ─── Conquistas ──────────────────────────────────────────────────────────

func tem_conquista(id: String) -> bool:
	return id in conquistas.desbloqueadas


## Conta pela ORDEM, não pelo tamanho da lista salva: id que saiu do jogo
## continua no arquivo de quem jogou a versão antiga, e não pode inflar o
## "x de y" do menu.
func total_desbloqueadas() -> int:
	var quantas: int = 0
	for id in Conquistas.ORDEM:
		if id in conquistas.desbloqueadas:
			quantas += 1
	return quantas


## Chamado por ciclo_pintura.gd quando uma cor termina as 3 demãos — antes
## da pergunta "gostou?" aparecer, já vale como "viu todas as demãos".
func registrar_ciclo_completo(nome_cor: String) -> void:
	var mudou: bool = _desbloquear(Conquistas.ID_PRIMEIRA_COR)

	if nome_cor not in conquistas.cores_completas_geral:
		conquistas.cores_completas_geral.append(nome_cor)
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
		salvar_conquistas()


## ⚠️ Ferramenta de desenvolvimento — sai na integração com a Steam (Etapa 3),
## junto com `Conquistas.PERMITE_LIMPAR`, que é quem esconde o botão. Lá quem
## manda no desbloqueio é a Steam, e apagar arquivo local não desfaz o unlock
## no perfil do jogador — o botão passaria a mentir.
func limpar_conquistas() -> void:
	conquistas = DadosConquistas.new()
	salvar_conquistas()


func _lista_por_modo(modo: int) -> Array[String]:
	match modo:
		ModoJogo.Modo.RAPIDO:
			return conquistas.cores_completas_rapido
		ModoJogo.Modo.NORMAL:
			return conquistas.cores_completas_normal
		_:
			return conquistas.cores_completas_realista


## Marca a conquista como desbloqueada se ainda não estava. Devolve true só
## quando muda de estado (pra saber se vale emitir o sinal/salvar).
func _desbloquear(id: String) -> bool:
	if id in conquistas.desbloqueadas:
		return false
	conquistas.desbloqueadas.append(id)
	conquista_desbloqueada.emit(id)
	return true


# ─── Disco ───────────────────────────────────────────────────────────────

func salvar() -> void:
	ResourceSaver.save(dados, CAMINHO_SAVE)


func salvar_conquistas() -> void:
	ResourceSaver.save(conquistas, CAMINHO_CONQUISTAS)


## CACHE_MODE_IGNORE nos dois: save é dado do jogador, não recurso compartilhado
## — sem isso, reler o arquivo depois de gravar devolve o objeto que já estava
## no cache em vez do que está no disco.
func _carregar() -> void:
	if ResourceLoader.exists(CAMINHO_SAVE):
		dados = ResourceLoader.load(CAMINHO_SAVE, "", ResourceLoader.CACHE_MODE_IGNORE) as DadosSalvos
	if dados == null:
		dados = DadosSalvos.new()

	if ResourceLoader.exists(CAMINHO_CONQUISTAS):
		conquistas = ResourceLoader.load(
			CAMINHO_CONQUISTAS, "", ResourceLoader.CACHE_MODE_IGNORE) as DadosConquistas
	if conquistas == null:
		conquistas = DadosConquistas.new()

	_migrar_conquistas_do_save()


## Save de schema 1 guardava conquista dentro de si mesmo. Traz pra cá uma vez
## só e zera o campo lá — JUNTANDO com o que já houver no arquivo novo em vez
## de sobrescrever, que é o certo caso os dois coexistam por algum motivo.
##
## ⚠️ A checagem é por CONTEÚDO (tem campo legado preenchido?), não por
## `versao_schema`. Um `.tres` não grava propriedade que esteja igual ao
## default do script: o save antigo tinha `versao_schema` 1 = default da época,
## então a linha nem foi escrita no arquivo. Com o default agora em 2, esse
## mesmo arquivo carrega dizendo "2" — e uma migração que confiasse na versão
## pularia calada, jogando fora as conquistas de quem já jogou.
func _migrar_conquistas_do_save() -> void:
	if not _save_tem_campo_legado():
		return

	_juntar(conquistas.desbloqueadas, dados.conquistas_desbloqueadas)
	_juntar(conquistas.cores_completas_geral, dados.cores_completas_geral)
	_juntar(conquistas.cores_completas_rapido, dados.cores_completas_rapido)
	_juntar(conquistas.cores_completas_normal, dados.cores_completas_normal)
	_juntar(conquistas.cores_completas_realista, dados.cores_completas_realista)

	dados.conquistas_desbloqueadas = []
	dados.cores_completas_geral = []
	dados.cores_completas_rapido = []
	dados.cores_completas_normal = []
	dados.cores_completas_realista = []
	dados.versao_schema = DadosSalvos.VERSAO_ATUAL

	salvar_conquistas()
	salvar()


func _save_tem_campo_legado() -> bool:
	return not (dados.conquistas_desbloqueadas.is_empty()
		and dados.cores_completas_geral.is_empty()
		and dados.cores_completas_rapido.is_empty()
		and dados.cores_completas_normal.is_empty()
		and dados.cores_completas_realista.is_empty())


func _juntar(destino: Array[String], origem: Array[String]) -> void:
	for item in origem:
		if item not in destino:
			destino.append(item)
