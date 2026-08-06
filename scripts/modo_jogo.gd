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
## ⚠️ O Rápido subiu de 60 s pra 150 s na Fase E, e não é gosto: com 60 s a
## primeira parede da volta secava **antes de o tio chegar na terceira**, e o
## jogador via a parede já seca em vez de vê-la secar.
##
## Reconferido em 06/08/2026, quando o banquinho virou objeto carregado e a
## parede passou de 84 s pra ~101 s (volta de ~7,1 min contra 5,6 min). A regra
## que importa é sobre a parede que a garotinha ENCARA — a norte, segunda da
## volta, que fica pronta por volta dos 212 s. Ela precisa continuar secando até
## o fim da volta, ou seja mais 213 s. Rápido dá 101 + 150 × 1,054 = 259 s, com
## 46 s de folga; Normal dá 417 s. Os três continuam valendo, e nenhum número
## mudou aqui — o que mudou foi a conta que sustenta eles.
const TEMPO_SECAGEM: Dictionary = {
	Modo.RAPIDO:   150.0,
	Modo.NORMAL:   300.0,    # 5 minutos
	Modo.REALISTA: 7200.0,   # 2 horas de verdade
}
