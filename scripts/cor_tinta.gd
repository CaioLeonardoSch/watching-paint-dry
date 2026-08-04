extends Resource
class_name CorTinta

# ─────────────────────────────────────────────
#  COR DE TINTA — dado tipado pra paleta de cores escolhível
#
#  Uma cor autoral só: `cor_alvo`, a cor cheia — o que a parede vira quando a
#  tinta cobre de verdade. Demão a demão sai de curva de cobertura, e o tom
#  molhado sai da seca daquela demão. Antes eram 4 cores escritas à mão por
#  tinta (3 secas + 1 molhada), que precisavam ficar em sintonia entre si.
#
#  Por que mudou (pesquisa de 02/08/2026, ver PROJETO.md):
#
#  1. Tinta látex/acrílica seca MAIS ESCURA, não mais clara. O ligante é
#     branco leitoso quando molhado e fica transparente ao secar — sai o véu
#     branco e sobra o pigmento cru, então a cor aprofunda. O brilho da
#     superfície molhada reforça a ilusão de "mais claro". O modelo antigo
#     fazia o contrário: molhado escuro secando pra um tom pálido, o que dava
#     a leitura de "escureceu e depois lavou".
#
#  2. Cobertura converge, não é linear. Cada demão cobre a maior parte do que
#     ainda faltava, então o salto entre demãos diminui — e a cor "de verdade"
#     chega já na 2ª (é assim que fabricante formula tinta). A 3ª é
#     acabamento, muda pouco de propósito.
# ─────────────────────────────────────────────

## Reboco cru — o que está embaixo da 1ª demão de uma parede nunca pintada.
## Mesmo tom de `ciclo_pintura.gd::COR_PAREDE_CRUA`.
const COR_FUNDO_CRU: Color = Color(0.93, 0.92, 0.90)

## Quanto da cor cheia cada demão entrega, acumulado. Uma demão sozinha cobre
## ~70%; a segunda cobre 70% do que sobrou (0.30 × 0.30 = 9% de fundo ainda
## aparecendo); a terceira quase fecha.
const COBERTURA: Array[float] = [0.70, 0.91, 0.973]

## Tinta molhada = a mesma cor com o véu leitoso do ligante por cima.
##
## O véu começou em 0.20 (fiel ao que a tinta faz de verdade) e a secagem
## ficou INVISÍVEL: medido no jogo, a parede andava ~4 valores de RGB entre
## molhada e seca ao longo de 60 s, porque a luz do quarto já é baixa e
## comprime a diferença toda. 0.55 é exagero controlado — o jogo é assistir
## isso acontecer, então o efeito precisa caber na tela.
##
## Medido no render, na mesma parede e mesma luz: 0.20 dava ~4 valores de
## diferença entre molhada e seca, 0.40 dava ~17, 0.55 dá ~34. O estado FINAL
## não muda com isso — quem muda é só o caminho até ele.
const COR_LEITOSA: Color = Color(0.93, 0.93, 0.94)
const VEU_MOLHADO: float = 0.55

@export var nome: String = ""
@export var cor_alvo: Color = Color(0.16, 0.34, 0.68)


func demaos() -> int:
	return COBERTURA.size()


## Cor da demão `indice` (0 = primeira) depois de seca.
func seca(indice: int) -> Color:
	var k: float = COBERTURA[clampi(indice, 0, COBERTURA.size() - 1)]
	return COR_FUNDO_CRU.lerp(cor_alvo, k)


## Cor da demão `indice` enquanto ainda está molhada — mais clara e leitosa
## que a seca, não mais escura (ver cabeçalho). O resto da leitura de "molhado"
## quem faz é o brilho, no shader.
func molhada(indice: int) -> Color:
	return seca(indice).lerp(COR_LEITOSA, VEU_MOLHADO)
