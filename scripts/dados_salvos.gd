extends Resource
class_name DadosSalvos

# ─────────────────────────────────────────────
#  DADOS SALVOS — schema do save (user://save.tres)
#
#  versao_schema existe pra detectar save de versão antiga no futuro (não
#  migra sozinho ainda — projeto pequeno demais pra precisar disso agora,
#  mas o campo já existe pra não precisar quebrar saves existentes depois).
# ─────────────────────────────────────────────

@export var versao_schema: int = 1
@export var modo: int = 0  # ModoJogo.Modo

@export var cor_atual_nome: String = ""  # vazio = nenhum save de meio de ciclo ainda
@export var demao_atual: int = 0

@export var cores_completas_geral: Array[String] = []
@export var cores_completas_rapido: Array[String] = []
@export var cores_completas_normal: Array[String] = []
@export var cores_completas_realista: Array[String] = []

@export var conquistas_desbloqueadas: Array[String] = []
