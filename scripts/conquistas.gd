extends RefCounted
class_name Conquistas

# ─────────────────────────────────────────────
#  CONQUISTAS — definições (texto exato, ids, ordem de exibição)
#
#  Só dado + funções puras, sem estado — EstadoJogo é quem guarda o que já
#  foi desbloqueado.
# ─────────────────────────────────────────────

const ID_PRIMEIRA_COR: String  = "primeira_cor"
const ID_VERMELHO: String      = "vermelho"
const ID_LARANJA: String       = "laranja"
const ID_AMARELO: String       = "amarelo"
const ID_VERDE: String         = "verde"
const ID_VIOLETA: String       = "violeta"
const ID_ROSA: String          = "rosa"
const ID_MODO_RAPIDO: String   = "modo_rapido"
const ID_MODO_NORMAL: String   = "modo_normal"
const ID_MODO_REALISTA: String = "modo_realista"

## Ordem de exibição no menu — bate com a lista original do usuário, 1 a 10.
const ORDEM: Array[String] = [
	ID_PRIMEIRA_COR, ID_VERMELHO, ID_LARANJA, ID_AMARELO, ID_VERDE, ID_VIOLETA, ID_ROSA,
	ID_MODO_RAPIDO, ID_MODO_NORMAL, ID_MODO_REALISTA,
]

const TEXTOS: Dictionary = {
	ID_PRIMEIRA_COR:  "Viu todas as demãos de uma tinta",
	ID_VERMELHO:      "Viu as demãos da cor vermelho",
	ID_LARANJA:       "Viu as demãos da cor laranja",
	ID_AMARELO:       "Viu as demãos da cor amarelo",
	ID_VERDE:         "Viu as demãos da cor verde",
	ID_VIOLETA:       "Viu as demãos da cor violeta",
	ID_ROSA:          "Viu as demãos da cor rosa",
	ID_MODO_RAPIDO:   "Viu todas as cores secarem no modo rápido",
	ID_MODO_NORMAL:   "Viu todas as cores secarem no modo normal",
	ID_MODO_REALISTA: "Viu todas as cores secarem no modo realista",
}

## Nome de CorTinta (ex. "Vermelho", igual ao campo `nome` do .tres) -> id da
## conquista daquela cor. Só as 6 cores rastreadas por conquista.
const COR_PARA_ID: Dictionary = {
	"Vermelho": ID_VERMELHO,
	"Laranja":  ID_LARANJA,
	"Amarelo":  ID_AMARELO,
	"Verde":    ID_VERDE,
	"Violeta":  ID_VIOLETA,
	"Rosa":     ID_ROSA,
}


static func id_para_cor(nome_cor: String) -> String:
	return COR_PARA_ID.get(nome_cor, "")


## `lista` é uma lista de nomes de cor (não ids) — true quando as 6 cores
## rastreadas já apareceram nela.
static func todas_seis_cores(lista: Array) -> bool:
	for nome in COR_PARA_ID.keys():
		if nome not in lista:
			return false
	return true


static func id_do_modo(modo: int) -> String:
	match modo:
		ModoJogo.Modo.RAPIDO:
			return ID_MODO_RAPIDO
		ModoJogo.Modo.NORMAL:
			return ID_MODO_NORMAL
		ModoJogo.Modo.REALISTA:
			return ID_MODO_REALISTA
	return ""
