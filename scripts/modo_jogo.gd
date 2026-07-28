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

## Segundos de secagem por demão, em cada modo.
const TEMPO_SECAGEM: Dictionary = {
	Modo.RAPIDO:   20.0,
	Modo.NORMAL:   300.0,    # 5 minutos
	Modo.REALISTA: 7200.0,   # 2 horas de verdade
}

## Segundos por dia completo (dia/noite), em cada modo.
const DURACAO_DIA: Dictionary = {
	Modo.RAPIDO:   120.0,    # 2 minutos
	Modo.NORMAL:   1200.0,   # 20 minutos
	Modo.REALISTA: 86400.0,  # 24 horas de verdade
}
