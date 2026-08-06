extends RefCounted
class_name ModoJogo

# ─────────────────────────────────────────────
#  MODO DE JOGO — rápido / normal / realista
#
#  Só dado (enum + tabelas), sem estado próprio. EstadoJogo (autoload) é quem
#  guarda qual modo está ativo e consulta essas tabelas.
# ─────────────────────────────────────────────

enum Modo { RAPIDO, NORMAL, REALISTA }

const NOMES: Dictionary = {
	Modo.RAPIDO:    "Rápido",
	Modo.NORMAL:    "Normal",
	Modo.REALISTA:  "Realista",
}

## Segundos de secagem por demão, em cada modo. É a única coisa que o modo
## controla — o ciclo de dia e noite foi removido (ver ambiente_dia.gd), então
## não há mais duração de dia pra escalar. **A pintura não escala com o modo**:
## ela leva o que a coreografia leva, igual nos três (SECAGEM §3.9).
##
## ⚠️ O Rápido subiu de 60 s pra 150 s na Fase E, e não é gosto: uma parede
## agora leva 84 s pra ser pintada e a volta inteira 336 s. Com 60 s, a primeira
## parede da volta secava em 144 s — **antes de o tio chegar na terceira**, e o
## jogador ia ver a parede já seca em vez de vê-la secar. Com 150 s ela fecha em
## 234 s, ainda durante a volta, mas já com a garotinha sentada olhando.
## Normal e Realista não precisaram mexer: 84 + 300 = 384 s já cai depois dos
## 336 s da volta.
const TEMPO_SECAGEM: Dictionary = {
	Modo.RAPIDO:   150.0,
	Modo.NORMAL:   300.0,    # 5 minutos
	Modo.REALISTA: 7200.0,   # 2 horas de verdade
}
