extends Resource
class_name CorTinta

# ─────────────────────────────────────────────
#  COR DE TINTA — dado tipado pra paleta de cores escolhível
#
#  `variantes_secas` tem uma cor por demão (índice 0 = 1ª demão seca, a
#  última = cor final "realçada"), ficando mais saturada a cada repintura.
# ─────────────────────────────────────────────

@export var nome: String = ""
@export var cor_molhada_base: Color = Color(0.2, 0.4, 0.8)
@export var variantes_secas: Array[Color] = []
