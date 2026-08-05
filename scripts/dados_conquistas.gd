extends Resource
class_name DadosConquistas

# ─────────────────────────────────────────────
#  DADOS DE CONQUISTA — schema de user://conquistas.tres
#
#  Arquivo SEPARADO do save, de propósito. Conquista é permanente: "Novo Jogo"
#  e a lixeira do menu recomeçam a partida, e nenhum dos dois pode encostar
#  aqui. Enquanto isso morava dentro de DadosSalvos, `iniciar_novo_jogo()`
#  fazia `DadosSalvos.new()` e levava as conquistas junto — quem começasse
#  partida nova perdia tudo.
# ─────────────────────────────────────────────

@export var versao_schema: int = 1

## Ids de Conquistas.ORDEM já desbloqueados.
@export var desbloqueadas: Array[String] = []

## Progresso que ALIMENTA conquista, e por isso mora aqui e não no save: quais
## cores já foram vistas até o fim, no geral e por modo (as de modo só fecham
## quando as 6 cores rastreadas aparecem na lista daquele modo).
@export var cores_completas_geral: Array[String] = []
@export var cores_completas_rapido: Array[String] = []
@export var cores_completas_normal: Array[String] = []
@export var cores_completas_realista: Array[String] = []
