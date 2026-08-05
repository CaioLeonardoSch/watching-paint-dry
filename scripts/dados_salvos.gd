extends Resource
class_name DadosSalvos

# ─────────────────────────────────────────────
#  DADOS SALVOS — schema do save (user://save.tres)
#
#  Só a PARTIDA em andamento. Conquista e progresso permanente moram em
#  user://conquistas.tres (DadosConquistas) — apagar este arquivo aqui não
#  pode custar conquista nenhuma.
#
#  versao_schema detecta save de versão antiga. Hoje serve pra uma coisa só:
#  save de schema 1 guardava conquista aqui dentro, e EstadoJogo migra isso
#  pro arquivo novo uma vez (ver `_migrar_conquistas_do_save`).
# ─────────────────────────────────────────────

const VERSAO_ATUAL: int = 2

@export var versao_schema: int = VERSAO_ATUAL
@export var modo: int = 0  # ModoJogo.Modo

@export var cor_atual_nome: String = ""  # vazio = nenhum save de meio de ciclo ainda
@export var demao_atual: int = 0

# ─── Campos legados (schema 1) ───────────────────────────────────────────
# Continuam declarados só pra um save antigo carregar sem perder nada: a
# migração lê daqui, copia pro DadosConquistas e zera. Código novo NÃO usa
# nenhum deles — quem quer conquista pergunta pro EstadoJogo.
@export var cores_completas_geral: Array[String] = []
@export var cores_completas_rapido: Array[String] = []
@export var cores_completas_normal: Array[String] = []
@export var cores_completas_realista: Array[String] = []
@export var conquistas_desbloqueadas: Array[String] = []
