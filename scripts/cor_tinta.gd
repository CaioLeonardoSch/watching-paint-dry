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
## O véu começou em 0.20 (fiel) e a secagem ficava INVISÍVEL: a parede andava
## ~4 valores de RGB entre molhada e seca ao longo de 60 s, porque a luz do
## quarto é baixa e comprime a diferença. Subiu pra 0.55, exagero controlado
## pra o efeito caber na tela. Medido: 0.20 dava ~4 valores, 0.40 dava ~17,
## 0.55 dava ~34.
##
## **Voltou pra 0.32 na Fase G2**, e o motivo é que o 0.55 era compensação:
## parede sem estrutura espacial precisa de um véu forte pra não ler como
## retângulo chapado. Só que o véu não clareia a tinta, ele DESSATURA — medido,
## o R andava 13% e o B triplicava, então a parede molhada lia como "ainda não
## pintada" em vez de "laranja molhado". Agora o campo de secagem (G1) dá a
## estrutura, a travessia tem cotovelo (saturação antes de valor) e o brilho
## rasante entrega o resto, então o véu pode voltar pro valor fiel.
const COR_LEITOSA: Color = Color(0.93, 0.93, 0.94)
const VEU_MOLHADO: float = 0.32

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


## Cor do MEIO da travessia (Fase G2): o véu leitoso já foi embora, mas o filme
## ainda não consolidou.
##
## Fisicamente são duas coisas em sequência, não uma: primeiro o ligante branco
## fica transparente e a cor **satura** (o valor quase não mexe), depois o filme
## fecha e o valor **cai** um pouco. Num `mix` só, o percurso é uma reta no RGB
## que atravessa o cinza — lê como fade de vídeo. Com a cor do meio, o caminho
## ganha um cotovelo, que é o que se vê numa parede de verdade.
##
## ⚠️ Feito em HSV, não com `lerp` pro branco como o plano sugeria. Puxar pro
## branco em RGB **dessatura** — na tinta laranja, um lerp de 0,10 já levava a
## razão B/R de 0,19 pra 0,29. Dessaturar aqui seria repetir no meio da
## travessia exatamente o defeito que a G2 existe pra tirar do começo dela.
## O salto de valor é de 22%, não os ~3% que o `lerp` de 0,10 do plano dava.
## Medido: com 10% a perna do valor ficava com ~18 valores de 255 contra ~40 da
## perna da saturação, e como a saturação fecha em `fracao` 0,48 — antes da
## janela da mancha (0,10–0,92) — sobrava pouca inclinação de cor justamente
## onde a mancha da G1 precisa aparecer. A contribuição dela caiu 5×. 22% é
## também o mais fiel: látex escurece bastante ao consolidar.
func meio(indice: int) -> Color:
	var c := seca(indice)
	return Color.from_hsv(c.h, c.s, minf(c.v * 1.22, 1.0), c.a)
