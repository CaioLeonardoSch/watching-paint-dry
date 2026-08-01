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
## não há mais duração de dia pra escalar.
const TEMPO_SECAGEM: Dictionary = {
	Modo.RAPIDO:   60.0,
	Modo.NORMAL:   300.0,    # 5 minutos
	Modo.REALISTA: 7200.0,   # 2 horas de verdade
}
