# Plano — Secagem Natural, Proporção do Quarto e Apresentação

Documento de planejamento de uma rodada só, com três assuntos que se encostam mais do que parece:

1. **A natureza da secagem** (partes 2 a 5) — fazer a tinta secar de um jeito que valha a pena
   assistir, sendo fiel ao que látex faz de verdade. Tédio como textura, não como ausência de
   acontecimento.
2. **A proporção do quarto** (parte 6) — o quarto é 7 × 6 m e as paredes não recebem a mesma luz; a
   queixa de "sombra mais funda nas paredes mais distantes" tem causa medível.
3. **Apresentação** (parte 7) — serrilhamento, a fresta no topo da porta e o jogo abrir preso em
   1152×648.

1 e 2 se encostam porque a secagem proposta na parte 1 **lê a posição da janela e a altura da
parede** pra decidir onde seca primeiro. Se as paredes forem desiguais, o campo de secagem fica
desigual junto — e a parede de trás fica úmida mais tempo que a da frente sem que ninguém tenha
pedido isso. E 3 se encosta em 2 porque a porta anda meio metro quando o quarto encolhe: a fresta e
a mudança de layout mexem nos mesmos números, e não vale fazer duas vezes.

**Se a ideia for ver melhora rápida:** os itens da parte 7 são os mais baratos do documento
(o tamanho de tela leva minutos) e não dependem de nada. A parte 6 vem antes de qualquer `LightmapGI`,
porque ele trava a geometria. A parte 3 (G1) é a de maior retorno, mas é a mais trabalhosa.

Complementa `PROJETO.md` (documento-mãe) e `PLANO-OVERHAUL-TINTA.md` (o overhaul do miolo, que
continua valendo — este documento é a **Fase G**, entra depois de D/E/F ou em paralelo com elas,
ver seção 5). Quando fechar, o que sobreviver vira parágrafo na seção 3 do `PROJETO.md`.

**Nada aqui foi implementado.** É proposta, escrita a partir da leitura do código de 02/08/2026.

---

## 1. A tese — o que "satisfatório mesmo sendo tedioso" quer dizer

Um jogo cuja mecânica é olhar não pode competir por intensidade. Ele compete por **legibilidade**:
a qualquer momento em que o jogador resolver prestar atenção, tem que haver alguma coisa que ele
consiga perceber mudando. Não algo *empolgante* — algo *perceptível*.

Isso quebra em três escalas de tempo, e o jogo hoje só tem a terceira:

| Escala | O que o jogador percebe | Existe hoje? |
|---|---|---|
| **Segundos** | Ele mexe a cabeça e o brilho da parede muda — descobre onde ainda está molhado | ❌ quase nulo (`SPECULAR` varia 0.30→0.38) |
| **Minutos** | Uma fronteira irregular atravessa a parede: a região fosca crescendo sobre a região brilhante | ❌ inexistente |
| **Demão inteira** | A cor aprofunda | ✅ é a única coisa que acontece |

A terceira sozinha não funciona, e a razão é aritmética. Está medido no próprio `cor_tinta.gd`:
o véu de 0.55 move ~34 valores de RGB ao longo de 60 s. Isso é **0,57 valor de RGB por segundo**,
distribuído uniformemente pela parede inteira. Não existe véu grande o bastante pra tornar isso
perceptível em tempo real — o olho detecta mudança lenta por **contraste com o vizinho**, não por
deriva absoluta. Uma parede que muda toda junta não muda, do ponto de vista da percepção; ela só
está diferente quando você volta.

> **A regra que organiza este documento inteiro: estrutura, não amplitude.**
> Enquanto a parede secar toda junta, aumentar o efeito só deixa a cor errada. Assim que
> pedaços dela secarem em momentos diferentes, aparece uma **borda em movimento** — e borda em
> movimento é a coisa que o sistema visual humano detecta melhor. Aí dá pra devolver a cor pro
> lugar fiel e o resultado fica *mais* visível, não menos.

E é exatamente isso que tinta de verdade faz. A pesquisa que já está no `PLANO-OVERHAUL-TINTA.md`
seção 3.4 diz com todas as letras: *"while the paint is drying it will look splotchy and uneven"*.
A fase manchada é o assunto do jogo. Hoje ela não existe.

---

## 2. Diagnóstico — a arquitetura está certa, os números estão mortos

Este é o achado principal e ele é uma boa notícia: **não há nada errado com o desenho do sistema.**
A máscara, os dois carimbos, o UV por posição de mundo, a separação brilho/cor — tudo isso está
certo e é o que torna o resto possível. O problema é que **três das quatro coisas que a Fase B foi
construída pra permitir estão numericamente inertes**: os números que alimentam a máquina caíram
todos numa faixa onde nada acontece.

Cada item abaixo tem a conta. Todas partem de `PIXELS_POR_METRO = 146`, rolo de 23 cm (33,6 px),
faixa de contato de 5 cm (7,3 px), passo entre carimbos de 2,5 cm (3,65 px) e passo entre passadas
verticais de 17 cm (24,8 px).

### 2.1 Falha de cobertura nunca acontece

`trajeto_rolo.gd`:

```gdscript
const CARGA_CHEIA: float = 1.0
const CARGA_MINIMA: float = 0.80
const CONSUMO_POR_METRO: float = 0.013
const METROS_POR_CARGA: float = 14.0
```

A carga cai `14 × 0,013 = 0,182` no pior caso. Ou seja **a carga do rolo vive entre 0,82 e 1,0** —
o piso de `CARGA_MINIMA = 0.80` nunca é alcançado, é código morto.

Do outro lado, `tinta_secando.gdshader`:

```glsl
uniform float cobertura_min = 0.03;
uniform float cobertura_max = 0.45;
...
float cobertura = smoothstep(cobertura_min, cobertura_max, rec.g);   // rec.g = carga gravada
```

Qualquer coisa acima de 0,45 lê como **cobertura total**. A carga nunca desce de 0,82. Logo
`cobertura == 1.0` em toda a área que o rolo tocou, sempre, em todas as demãos.

**Consequência:** a linha mais importante do shader —

```glsl
ALBEDO = mix(base_anterior, cor_nova, cobertura);
```

— é sempre `ALBEDO = cor_nova`. `base_anterior` só aparece na franja de meio centímetro na borda
externa do traçado. O canal que existe pra dar função à 2ª demão está desligado.

Um rolo de 23 cm carregado cobre de verdade uns **1,0 a 1,5 m²** antes de precisar molhar. A 17 cm
de passo, isso é **6 a 9 metros de trajeto**, não 14 — e a carga tem que cair pra perto de **0,35**
no fim, não 0,82, senão o último trecho de cada carga não estria.

### 2.2 Lap mark nunca dispara

O critério do shader é absoluto, em segundos:

```glsl
float salto = length(vec2(r_dx, r_dy)) * janela_demao;
float lap = smoothstep(limiar_lap, limiar_lap * 2.0, salto) * cobertura;  // limiar_lap = 0.35 s
```

Conta pra parede norte (7 × 3 m) com `duracao_pintura_segundos = 8.0`:

- 7,0 m ÷ 0,17 m = **41 colunas**, cada uma de 3,06 m → trajeto ≈ **125 m**
- 125 m em 8 s = **15,6 m/s** (o rolo anda a 56 km/h — outro assunto, ver 2.8 e Fase E)
- uma coluna leva 3,06 ÷ 15,6 = **0,196 s**
- a transição entre colunas vizinhas se espalha pela faixa de sobreposição, ~8,8 texels
- gradiente ≈ 0,025 (normalizado) ÷ 8,8 texels → `salto ≈ 0,023 s`

**0,023 s contra um limiar de 0,35 s.** O `smoothstep` devolve zero. Lap mark é código morto —
o único lugar onde ele já apareceu foi na emenda entre o trecho instantâneo e o animado da
abertura, que é justamente onde ninguém queria ver linha nenhuma.

E aqui o código está **fisicamente certo e o cenário é que está errado**: pintor rápido não faz lap
mark. Lap mark aparece quando a passada anterior já flashou antes da nova encostar. Com secagem de
60 s, isso pede um intervalo da ordem de 15-20 s entre passadas vizinhas. Com a parede sendo pintada
em 8 s inteiros, é impossível por construção. Ver 3.8 e 3.9.

### 2.3 A mancha de espessura vale 0,7% do tempo de secagem

`carimbo_acumulado.gdshader` deposita `deposito * ganho_espessura` com `ganho_espessura = 0.035`.

O perfil do carimbo ao longo do movimento é triangular de base 7,3 px com passo de 3,65 px — que é
exatamente uma partição da unidade (o comentário no código explica, e está certo). Então uma passada
soma **1,0 × carga × 1,18** de depósito, e de espessura:

- uma passada: `1,0 × 0,9 × 1,18 × 0,035 ≈ 0,037`
- na faixa de sobreposição entre passadas (25% de 23 cm): até `≈ 0,048`

Logo, dentro de uma demão, `relevo` varia entre **0,037 e 0,048**. E o shader faz:

```glsl
float duracao_local = duracao_secagem * (1.0 + relevo * atraso_por_espessura);  // atraso = 0.55
```

- ponto fino: `60 × (1 + 0,037 × 0,55)` = **61,2 s**
- ponto grosso: `60 × (1 + 0,048 × 0,55)` = **61,6 s**

**A parede inteira seca dentro de uma janela de 0,4 segundo.** A "fase manchada" que o plano do
overhaul chamou de "o ouro" tem 0,7% de amplitude. Não é sutil — é indistinguível de zero.

Pior: a variação que sobra é **periódica** (as faixas de sobreposição estão espaçadas exatamente
17 cm), então se ela fosse amplificada como está, viraria listra regular, não mancha. Manchado é
uma palavra sobre irregularidade; espessura de rolo em zigue-zague regular não produz isso sozinha.

### 2.4 A demão nova apaga instantaneamente as falhas da anterior

`cor_anterior` é um `Color` uniforme, não uma textura:

```gdscript
material.set_shader_parameter("cor_anterior", anterior)   # parede_pintavel.gd
```

E `mascara.limpar_demao()` zera a máscara recente. Então no **frame exato** em que `iniciar_demao`
roda, `cobertura` cai pra 0 na parede inteira e o `ALBEDO` vira `cor_anterior`, chapada.

Ou seja: se a 1ª demão tivesse deixado uma falha (o que hoje não acontece, ver 2.1), essa falha
**sumiria no instante em que a 2ª demão começasse** — antes de o rolo chegar perto dela. O critério
de aceite nº 2 do `PLANO-OVERHAUL-TINTA.md` ("a 2ª demão visivelmente cobre falhas da 1ª") não é
alcançável com essa estrutura, mesmo com os números de 2.1 corrigidos.

Falta guardar a **cobertura histórica**. Os canais **B e A da máscara acumulada estão livres** —
é onde isso cabe, sem textura nova. Ver 3.7.

### 2.5 `ESPESSURA_TIPICA` está ~7× alta — e isso vira espera morta

`parede_pintavel.gd`:

```gdscript
const ESPESSURA_TIPICA: float = 0.35
func duracao_total() -> float:
	return _janela_demao + tempo_secagem_segundos * (1.0 + ESPESSURA_TIPICA * ATRASO_POR_ESPESSURA)
```

Mas a espessura real de uma demão é ~0,04 (conta de 2.3), não 0,35. E a cor termina de mudar em
`fracao = 0.95` (`seco_cor = smoothstep(0.22, 0.95, fracao)`), não em 1,0. Juntando:

| | Rápido (60 s) | Normal (300 s) | Realista (7200 s) |
|---|---|---|---|
| Quando a cor de fato para de mudar | ~66 s | ~300 s | ~1 h 57 |
| Quando `secagem_concluida` dispara | 79,5 s | 366 s | 2 h 23 |
| **Espera com a parede já pronta** | 13 s (17%) | 66 s (18%) | **26 min (18%)** |

Dezoito por cento de cada demão é o jogo esperando um relógio que não corresponde a nada na tela.
Num jogo sobre esperar, esperar de propósito é a proposta; esperar por engano é bug. E como o
número é um chute (`ESPESSURA_TIPICA` é literalmente comentado como estimativa), ele fica errado de
novo cada vez que alguém mexer no depósito. A saída é **fazer a variação ser limitada por
construção** e derivar a duração dela, não estimá-la (3.1).

### 2.6 O véu de 0,55 é amplitude tentando resolver falta de estrutura

O comentário de `cor_tinta.gd` conta a história certa: começou fiel (0,20), ficou invisível,
subiu pra 0,55. Isso não foi erro — foi a única alavanca disponível dado que a parede seca toda
junta. Mas o custo está na tela: com véu 0,55 e cobertura 0,70, a 1ª demão de azul **molhada** fica
em ≈ (0.69, 0.74, 0.85), um cinza-lilás. O tio passa o rolo e a parede quase não muda; a cor só
aparece depois. A leitura de "ele está pintando **de azul**" chega atrasada.

Com o campo de secagem de 3.1 no lugar, o véu pode voltar pra perto de **0,30** e ainda assim a
secagem ficar mais visível do que é hoje — porque o que passa a chamar atenção é a fronteira se
movendo, não a diferença entre os dois extremos.

### 2.7 Nos modos Normal e Realista a parede seca em bloco

A única fonte de variação temporal hoje é `instante` — quando o rolo passou. A janela de pintura é
de 8 s. Comparando com a secagem:

| Modo | Secagem | Espalhamento entre o 1º e o último ponto | Proporção |
|---|---|---|---|
| Rápido | 60 s | 8 s | 13% |
| Normal | 300 s | 8 s | 2,7% |
| Realista | 7200 s | 8 s | **0,1%** |

No modo Realista o jogador tem **duas horas** de um retângulo perfeitamente uniforme mudando de cor
a 0,005 valor de RGB por segundo. O modo "Realista" é hoje o menos realista dos três, porque parede
de verdade não seca assim — e é o modo que mais precisaria de estrutura, já que é o que exige mais
paciência.

**A variação de tempo local tem que ser uma fração da duração da secagem, não um número de
segundos.** É o pivô do desenho todo (3.1).

### 2.8 O rolo anda a velocidades diferentes em paredes de tamanhos diferentes

`duracao_pintura_segundos` é 8,0 fixo, mas o comprimento do trajeto depende da largura da parede:

| Parede | Largura | Colunas | Trajeto | Velocidade do rolo |
|---|---|---|---|---|
| Norte / Sul | 7,0 m | 41 | ~125 m | **15,6 m/s** |
| Leste / Oeste | 6,0 m | 35 | ~107 m | **13,4 m/s** |

17% de diferença. Isso muda o depósito por metro, o dente-de-serra da carga e (quando os números de
2.1 e 2.8 forem corrigidos) a distribuição de falha. As paredes ficam **medivelmente diferentes umas
das outras** sem que ninguém tenha decidido isso — e cai direto na queixa do "quero algo igual em
todos os lados". A parte 6 resolve isso na raiz.

### 2.9 O dente-de-serra da carga é periódico

`_carga_em()` usa `fmod(dist, METROS_POR_CARGA)`, o que produz uma banda de carga a cada 14 m de
trajeto — ou seja, a cada ~4,6 colunas, uma faixa de ~78 cm de largura. Com os números de 2.1
corrigidos essa banda passa a ser **visível**, e sendo perfeitamente periódica vai ler como listra
de shader, não como pintor. Precisa de jitter, e idealmente de virar evento (o tio vai à bandeja) —
o que é justamente a Fase E do overhaul.

### Resumo

| Recurso que a Fase B construiu | Estado real |
|---|---|
| Máscara do trajeto do rolo | ✅ funciona, é a base de tudo |
| Falha de cobertura | ❌ inerte (carga nunca desce de 0,82; limiar satura em 0,45) |
| Sobreposição / mancha de secagem | ❌ inerte (0,7% de variação, e periódica) |
| Lap mark | ❌ inerte (0,023 s contra limiar de 0,35 s) |
| A 2ª demão cobrir a falha da 1ª | ❌ impossível (a falha some antes de ser coberta) |
| Flash off (brilho antes da cor) | ✅ existe, mas o contraste é pequeno demais pra ler |

**Nenhum desses seis itens pede reescrever nada.** Cinco são calibração e um (2.4) é um canal de
textura que já está reservado e vazio.

---

## 3. A proposta — secagem como campo, não como relógio

A mudança conceitual cabe numa frase:

> Hoje cada ponto da parede pergunta **"quando eu fui pintado?"**.
> Passa a perguntar também **"que tipo de lugar da parede eu sou?"**.

Cada ponto passa a ter um **tempo local de secagem próprio**, que sai de um campo com quatro
contribuições. Nenhuma delas é ruído decorativo — as quatro são coisas que fazem parede de verdade
secar desigual.

### 3.1 O campo de secagem

```glsl
// variação percentual do tempo local de secagem, centrada em zero
float variacao =
	  esp_rel        * PESO_ESPESSURA    // camada mais grossa, seca depois
	+ mancha_subst   * PESO_SUBSTRATO    // absorção do reboco/da demão de baixo
	+ mancha_demao   * PESO_DEMAO        // irregularidade desta camada
	+ ambiente(uv)   * PESO_AMBIENTE;    // janela, altura, canto

variacao = clamp(variacao, -VARIACAO_MAX, VARIACAO_MAX);   // VARIACAO_MAX = 0.40

float duracao_local = duracao_secagem_demao * (1.0 + variacao);
float fracao = clamp((tempo_decorrido - instante) / duracao_local, 0.0, 1.0);
```

O `clamp` não é higiene, é **contrato**: com ele, `duracao_total()` deixa de ser um chute e passa a
ser exato —

```gdscript
func duracao_total() -> float:
	return _janela_demao + tempo_secagem_segundos * (1.0 + VARIACAO_MAX) * FIM_DA_COR
```

com `FIM_DA_COR = 0.95` (o ponto onde `seco_cor` fecha). Isso mata o item 2.5 de uma vez: nada de
`ESPESSURA_TIPICA`, nada de 18% de espera morta, e o número continua certo se alguém mexer no
depósito depois.

**As quatro contribuições:**

**(a) Espessura — relativa, não absoluta.** O erro de 2.3 é comparar `relevo` com 1,0, quando ele
vive perto de 0,04. Passa a ser normalizado pela espessura esperada da demão:

```glsl
uniform float espessura_esperada = 0.04;   // setada por parede_pintavel.gd a cada demão
float esp_rel = relevo / max(espessura_esperada, 1e-4) - 1.0;   // ≈ -0.2 .. +0.25
```

Assim o termo mede **desvio local**, que é o que importa, e não cresce com o número de demãos.
O fato de a 3ª demão secar mais devagar que a 1ª (substrato selado, sem absorção) é real, mas deve
ser um fator **explícito e uniforme**, não um efeito colateral do acumulador:

```gdscript
# parede_pintavel.gd::iniciar_demao
var duracao_demao := tempo_secagem_segundos * (1.0 + 0.12 * float(numero_demao))
```

**(b) Mancha de substrato.** Uma textura de ruído de baixa frequência por parede — manchas de
~0,35 m e ~1,1 m, duas oitavas. Fisicamente: a absorção do reboco (massa corrida × papel × demão
anterior) varia nessa escala, e é a razão nº 1 de parede real secar em nuvens. **Persiste entre
demãos** (mesma semente por parede) porque o substrato é o mesmo.

Semente **por parede**, não global — quatro paredes com a mesma nuvem lê como repetição de textura.

**(c) Mancha da demão.** A mesma textura, amostrada com um **offset de UV por demão** (um `vec2`
uniform, sorteado em `iniciar_demao`). Custo zero, e é o que impede a 2ª demão de secar com
exatamente o mesmo desenho de manchas da 1ª — o que denunciaria o truque na hora.

**(d) Ambiente — a única contribuição direcional.** Analítica, sem textura:

```glsl
// perto da janela: corrente de ar e mais calor → seca antes (sinal negativo)
float f_janela = -exp(-distance(pos_mundo, pos_janela) / 3.0);
// ar quente sobe, e o filme escorre pra baixo e engrossa → a base seca depois
float f_altura =  1.0 - clamp(pos_mundo.y / altura_parede, 0.0, 1.0);
// canto = ar parado
float f_canto  =  1.0 - smoothstep(0.0, 0.6, min(u, 1.0 - u) * largura_m);
```

Este é o termo que produz uma **fronteira que atravessa a parede** em vez de manchas soltas — a
região seca começa perto da janela e no alto, e avança pro canto de baixo mais longe. É a escala de
minutos da tabela da seção 1, e é o que faz o modo Realista virar assistível: em duas horas, uma
borda irregular cruzando a parede de um lado ao outro.

**Efeito colateral que vale a pena manter de propósito:** o campo é determinístico, então **a última
mancha a secar é sempre o mesmo lugar** — o canto de baixo mais distante da janela. O jogador
aprende isso sozinho depois de duas demãos, e passa a ter um ponto pra onde olhar quando quiser
saber se acabou. É o mais perto de "objetivo" que um jogo assim deveria chegar: um ritual, não um
HUD. Isso é coerente com a decisão já tomada de deixar o timer da demão **desligado por padrão**.

**Pesos sugeridos** (soma estatística ≈ ±0,30, pico limitado a ±0,40):

| Termo | Peso | Amplitude típica |
|---|---|---|
| `PESO_ESPESSURA` | 0.45 | ±10% |
| `PESO_SUBSTRATO` | 0.28 | ±14% |
| `PESO_DEMAO` | 0.16 | ±8% |
| `PESO_AMBIENTE` | 0.18 | ±18% (direcional) |

Traduzindo pro que aparece na tela: no modo Rápido, os pontos extremos da parede terminam com
**~48 s de diferença** (contra 0,4 s hoje). No Realista, **~1 h 20 de diferença**. Aí há o que
assistir nos dois.

### 3.2 As quatro fases, com curvas próprias

A tabela de fases do `PLANO-OVERHAUL-TINTA.md` 3.4 continua sendo a referência certa. O que falta é
cada fase ter uma **grandeza própria** em vez de duas curvas dividindo o trabalho:

```glsl
float k_brilho = smoothstep(0.02, 0.28, fracao);   // flash off: o brilho morre primeiro
float k_sat    = smoothstep(0.05, 0.55, fracao);   // o véu leitoso clareia, a cor satura
float k_valor  = smoothstep(0.38, 0.95, fracao);   // só depois o tom aprofunda
float k_mancha = smoothstep(0.10, 0.40, fracao)
               * (1.0 - smoothstep(0.62, 0.92, fracao));   // mancha: nasce e morre no meio
```

`k_mancha` é a peça nova e é o coração da proposta: **a mancha é um evento com começo e fim**, não
um ruído permanente. Molhada, a parede é lisa (o filme ainda nivela). Seca, é uniforme. No meio,
fica de nuvem. Quem só olhar antes e depois não vê mancha nenhuma — que é exatamente o
comportamento de tinta de verdade, e é o que dá vontade de ficar olhando o meio.

E o detalhe que separa isso de "ruído em cima da cor": **manchado de tinta secando é mais uma
diferença de brilho do que de cor.** O peso tem que ir pro `ROUGHNESS`:

```glsl
float m = (mancha - 0.5) * 2.0;               // -1 .. +1
cor_nova  *= 1.0 + m * 0.07 * k_mancha;       // cor: sutil
rugosidade += m * 0.14 * k_mancha;            // brilho: o dobro
```

### 3.3 Cor — saturação antes de valor

Hoje é um `mix` só entre molhada e seca. Mas o que acontece fisicamente são **duas coisas em
sequência**: primeiro o ligante branco leitoso fica transparente (a cor **satura**, o valor quase
não mexe), depois o filme consolida (o valor **cai** um pouco). Fazer isso num `lerp` só produz um
caminho reto no espaço RGB, que lê como fade de vídeo.

A solução mais barata é dar uma cor intermediária pra `cor_tinta.gd` e o shader fazer dois mixes:

```gdscript
# cor_tinta.gd — cor cheia, ainda sem o aprofundamento final
func meio(indice: int) -> Color:
	var c := seca(indice)
	return c.lerp(Color(1, 1, 1), 0.10)   # mesma saturação, valor um tico acima
```

```glsl
vec3 cor_nova = mix(cor_molhada.rgb, cor_meio.rgb,  k_sat);
cor_nova      = mix(cor_nova,        cor_seca.rgb,  k_valor);
```

Com isso, `VEU_MOLHADO` volta de **0.55 pra ~0.32** — mais perto do fiel — e o percurso fica mais
legível do que hoje, porque tem um cotovelo no meio em vez de ser uma reta.

### 3.4 Superfície — o brilho é a informação, e responde ao jogador

Esta é a escala de segundos da seção 1, e é a única forma de agência que um jogo assim pode ter:
**o jogador move a cabeça e descobre coisa**. Pintor de verdade confere a borda molhada exatamente
assim, olhando a parede de raspão.

Hoje o intervalo é `SPECULAR` 0.30 → 0.38 e `ROUGHNESS` 0.45 → 0.90. O specular é quase nada.
Proposta:

```glsl
float rasante = pow(1.0 - clamp(dot(normalize(NORMAL), normalize(VIEW)), 0.0, 1.0), 4.0);
float molhado = 1.0 - k_brilho;

ROUGHNESS = mix(0.92, mix(0.36, 0.90, k_brilho) + m * 0.14 * k_mancha, cobertura);
SPECULAR  = mix(0.30, 0.30 + 0.32 * molhado * (0.35 + 0.65 * rasante), cobertura);
```

⚠️ **O risco conhecido e já revertido antes:** `roughness` muito baixo faz a parede refletir o céu
procedural e quebrar em blocos visíveis (está registrado no `PROJETO.md`). Por isso o piso é 0.36 e
não menos, e o ganho vai no `SPECULAR` **modulado pelo ângulo rasante** — de frente a parede
continua fosca, e o brilho só aparece quando a câmera olha ao longo dela. É o mesmo efeito com
menos risco.

Verificar no Godot 4.7 se `NORMAL`/`VIEW` no `fragment()` estão no espaço esperado antes de confiar
na fórmula.

### 3.5 A borda viva (bead)

A tabela de fases já prevê "borda viva com bead na parte de baixo do traço" e isso nunca foi feito.
Sai quase de graça, porque o gradiente do instante **já é calculado** pro lap mark:

```glsl
float grad_v = (texture(mascara_recente, uv + vec2(0.0, texel.y)).r - rec.r);
float bead = clamp(-grad_v * ESCALA_BEAD, 0.0, 1.0)
           * (1.0 - smoothstep(0.0, 0.06, fracao));   // só enquanto está molhada
cor_nova   *= 1.0 - bead * 0.06;   // acúmulo é mais escuro
rugosidade -= bead * 0.10;         // e mais brilhoso
```

É um detalhe de dois centímetros que dura três segundos, e é o tipo de coisa que faz a pintura
parecer líquida em vez de decalque. Conferir o sinal do gradiente contra a orientação real de `v`
(que cresce pra baixo, ver `parede_pintavel.gd::configurar`).

### 3.6 Cobertura com história — o canal B da máscara acumulada

Resolve 2.4 e destrava o critério de aceite nº 2 do overhaul. Os canais B e A da acumulada estão
livres.

- **B = cobertura ao fim da demão anterior.** No começo de cada demão, uma blit de textura inteira
  copia `R → B` (um `blit_rect` cobrindo tudo, com um shader de cópia — uma vez por demão, custo
  irrelevante; a Fase A mediu 0,022 ms por blit).
- O shader passa a montar o fundo com história em vez de cor chapada:

```glsl
vec3 fundo = mix(cor_crua.rgb, cor_anterior.rgb, acum.b);   // o que a demão passada deixou
ALBEDO = mix(fundo, cor_nova, cobertura);
```

Agora uma falha da 1ª demão **continua na parede** enquanto a 2ª está sendo pintada, e some
**quando o rolo passa por cima dela**, não antes. É isso que faz três demãos serem três
acontecimentos em vez de três trocas de valor de saturação.

Efeito colateral bom: com o fundo passando a ser a demão anterior (e não reboco cru), dá pra abrir
a faixa de cobertura sem a parede "sair lavada" — que foi exatamente o motivo de `cobertura_max`
ter sido apertado pra 0,45. Os dois consertos se sustentam um ao outro.

### 3.7 Falha de cobertura de verdade

Com 3.6 no lugar, os números de 2.1 podem ir pro lugar físico:

```gdscript
# trajeto_rolo.gd
const METROS_POR_CARGA: float = 9.0     # ~1,5 m² por carga, que é o que um rolo de 23 cm segura
const CONSUMO_POR_METRO: float = 0.070  # 9 × 0,07 = 0,63 → a carga cai de 1,00 pra 0,37
const CARGA_MINIMA: float = 0.30
```

```glsl
uniform float cobertura_min = 0.06;
uniform float cobertura_max = 0.72;
```

Conferindo o que isso produz:

| Momento da carga | `carga` | `cobertura` resultante | Leitura na parede |
|---|---|---|---|
| Acabou de molhar | 1,00 | 1,00 | cobre inteiro |
| Meio da carga | 0,68 | 0,99 | cobre inteiro |
| Fim da carga | 0,37 | **0,42** | a camada de baixo transparece |

Só o **último terço de cada carga** estria. É o comportamento certo, e é o que dá motivo diegético
pro tio ir à bandeja (que é a Fase E). Somar um jitter de ±15% em `METROS_POR_CARGA` mata a listra
periódica de 2.9 enquanto a Fase E não existir.

### 3.8 Lap mark relativo à secagem, não a segundos

O limiar tem que ser a mesma grandeza que o fenômeno: lap mark acontece quando a passada anterior
**já flashou** antes da nova encostar.

```glsl
// limiar_lap deixa de ser 0.35 s e vira fração da secagem local
float dt_vizinho = salto;                                    // em segundos
float limiar = duracao_local * FRACAO_FLASH;                 // FRACAO_FLASH ≈ 0.28
float lap = smoothstep(limiar, limiar * 1.8, dt_vizinho) * cobertura;
```

Com isso, o efeito **aparece sozinho quando a coreografia da Fase E fizer o tio voltar num trecho
que ele pintou minutos antes** (subir no banquinho, terminar o alto, descer e voltar pro rodapé), e
continua não aparecendo quando ele pinta seguido — que é o comportamento correto. Não precisa de
número mágico nenhum: o critério vira físico.

### 3.9 Tempo de pintura — vem da coreografia, NÃO do modo

> **Correção 03/08/2026.** A primeira versão desta seção propunha uma tabela `TEMPO_PINTURA` por modo
> (12 / 45 / 180 s). **Estava errado e conflitava com a Fase E do overhaul**, que já decidiu que a
> coreografia honesta leva 40-70 s por parede. Esticar isso pra 180 s no Realista faria o tio pintar
> em câmera lenta — pior que o problema que resolveria. A tabela por modo está descartada.

Hoje `duracao_pintura_segundos = 8.0` fixo, e a parede é pintada em 8 s. O rolo anda a **15,6 m/s**
(56 km/h). Isso não é escolha de ritmo, é um valor de placeholder do tempo em que o trajeto era uma
linha reta.

**A regra certa:** `duracao_pintura_segundos` é uma **consequência da coreografia**, medida uma vez
quando a Fase E existir (§5.5 e §5.6 do `PLANO-OVERHAUL-TINTA.md` estimam 40-70 s por parede, volta
completa de 3 a 5 min), e **igual nos três modos**. O modo continua controlando só a secagem, que é
o que ele sempre controlou.

O que isso implica pro lap mark, e é contraintuitivo mas está certo:

| Modo | Secagem | Flash-off termina em | Intervalo entre trechos vizinhos | Lap mark? |
|---|---|---|---|---|
| Rápido | 60 s | ~17 s | ~10 s | **quase** — aparece nos trechos mais demorados |
| Normal | 300 s | ~84 s | ~10 s | não |
| Realista | 7200 s | ~34 min | ~10 s | não |

**Lap mark é fenômeno de tinta que seca rápido**, não de pintor lento. No modo Realista a tinta leva
duas horas: nada do que ele pintou vai ter flashado antes de ele voltar. Está fisicamente correto que
o efeito só apareça no Rápido — e é uma diferença de comportamento **de graça** entre os modos, que
recompensa quem experimenta os três.

**Consequência que reforça a G1:** se a pintura leva 70 s e a secagem do Realista leva 7200 s, o
espalhamento temporal vindo do `instante` é de **~1%**. Ou seja, nos modos lentos o campo de secagem
de §3.1 não é *uma* fonte de variação espacial — é a **única**. Sem G1, Normal e Realista continuam
sendo um retângulo uniforme por horas, por mais bonita que a coreografia fique.

**O que fica pendente aqui, então:**

- `[x]` ✅ **Medido em 05/08/2026:** 224 m de caminho ÷ 3,6 m/s + 9 idas à bandeja = **84 s por
  parede**, volta completa 5,6 min. `duracao_pintura_segundos = 84.0`. E o número deixou de ser o
  que manda: quem decide agora é `TrajetoRolo.duracao_estimada()`, chamado antes de abrir a demão —
  este `@export` só serve onde não há trajeto rodando (abertura e retomada de save)
- `[x]` ✅ **Rápido subiu pra 150 s**, não 120: com 84 s de pintura por parede e 336 s de volta, os
  60 s antigos faziam a 1ª parede secar em 144 s, **antes de o tio chegar na terceira**. Normal e
  Realista não precisaram mexer (84 + 300 = 384 > 336)
- `[x]` ✅ `FRACAO_JA_PINTADA_ABERTURA` foi pra **0,92**, não 0,9: 8% de 84 s são 7 s de cutscene,
  que é o tempo de entender a cena sem ela cansar antes de a garotinha entrar

#### Remedido em 06/08/2026 — a parede foi pra ~101 s

A rodada de animação da Fase E2 (`PROJETO.md` §3.8) acrescentou **duas paradas novas** ao trajeto: o
tio buscar e plantar o banquinho (~7 por parede, 2,8 s cada) e a primeira ida à bandeja ficar 1,7×
mais longa porque ele despeja a lata. Antes o banquinho era teletransportado pro pé dele.

| | Fase E (05/08) | Fase E2 (06/08) |
|---|---|---|
| Caminho por parede | 224 m | 211 a 224 m (janela e porta saíram da conta) |
| Duração por parede | 84 s | **98,8 a 104,5 s** |
| Volta completa | 5,6 min | **~7,1 min** |
| Fração parada | 26% | **~40%** |

`duracao_pintura_segundos` foi pra **101,0**. Os três modos foram reconferidos e **nenhum mudou** —
o que mudou foi a conta que sustenta eles, agora escrita em `modo_jogo.gd::TEMPO_SECAGEM`: a regra é
sobre a parede que a garotinha ENCARA (a norte, segunda da volta, pronta por volta dos 212 s), que
precisa continuar secando pelos 213 s restantes. Rápido dá 259 s, com 46 s de folga.

⚠️ **A tabela de lap mark acima usa "intervalo entre trechos vizinhos ~10 s" e isso subiu junto.**
Não foi remedido — quando a G4 for feita, medir de novo antes de escolher limiar.

⚠️ **As quatro paredes deixaram de ter a mesma duração.** Leste e oeste têm ~2 m² a menos (porta e
janela), então saem 4 a 6% mais rápidas. É pequeno e está certo, mas quem for calibrar ritmo com uma
parede só precisa saber que as outras não são idênticas.

---

## 4. Tabela de constantes — hoje → proposto

Tudo num lugar só, pra facilitar a implementação e o rollback.

| Arquivo | Constante | Hoje | Proposto | Por quê |
|---|---|---|---|---|
| `trajeto_rolo.gd` | `METROS_POR_CARGA` | 14.0 | **9.0** | 1,5 m² por carga é o que um rolo segura (2.1) |
| `trajeto_rolo.gd` | `CONSUMO_POR_METRO` | 0.013 | **0.070** | a carga precisa chegar a ~0,37 pra estriar |
| `trajeto_rolo.gd` | `CARGA_MINIMA` | 0.80 | **0.30** | hoje é código morto, nunca é alcançado |
| `trajeto_rolo.gd` | *(novo)* `JITTER_CARGA` | — | **0.15** | mata a listra periódica de 2.9 |
| `tinta_secando.gdshader` | `cobertura_min` | 0.03 | **0.06** | — |
| `tinta_secando.gdshader` | `cobertura_max` | 0.45 | **0.72** | com fundo histórico (3.6), não lava mais |
| `tinta_secando.gdshader` | `atraso_por_espessura` | 0.55 | **removido** | substituído pelo campo (3.1) |
| `tinta_secando.gdshader` | `limiar_lap` | 0.35 s | **fração 0.28** | absoluto nunca dispara (2.2, 3.8) |
| `tinta_secando.gdshader` | `seco_brilho` | `(0.02, 0.30)` | **`(0.02, 0.28)`** | — |
| `tinta_secando.gdshader` | `seco_cor` | `(0.22, 0.95)` | **duas curvas** | saturação antes de valor (3.3) |
| `tinta_secando.gdshader` | *(novo)* `k_mancha` | — | **`(0.10,0.40)×(0.62,0.92)`** | a mancha é evento, não ruído (3.2) |
| `tinta_secando.gdshader` | `ROUGHNESS` molhada | 0.45 | **0.36** | com o piso ainda seguro contra reflexo de céu |
| `tinta_secando.gdshader` | `SPECULAR` | 0.30→0.38 | **0.30→0.62 rasante** | dá o que descobrir movendo a cabeça (3.4) |
| `cor_tinta.gd` | `VEU_MOLHADO` | 0.55 | **0.32** | estrutura substitui amplitude (2.6, 3.3) |
| `cor_tinta.gd` | *(novo)* `meio()` | — | **+10% de valor** | cotovelo na curva de cor (3.3) |
| `parede_pintavel.gd` | `ESPESSURA_TIPICA` | 0.35 | **removido** | vira `VARIACAO_MAX`, exato (2.5, 3.1) |
| `parede_pintavel.gd` | *(novo)* `VARIACAO_MAX` | — | **0.40** | contrato do campo de secagem |
| `parede_pintavel.gd` | *(novo)* `FIM_DA_COR` | — | **0.95** | tira os 18% de espera morta |
| `ciclo_pintura.gd` | `duracao_pintura_segundos` | 8.0 | **medir na Fase E** (~40-70 s) | igual nos 3 modos — ver 3.9 |
| `ciclo_pintura.gd` | `FRACAO_JA_PINTADA_ABERTURA` | 0.65 | **~0.90** | abertura acelerada, decidido 01/08 |
| `modo_jogo.gd` | `TEMPO_SECAGEM[RAPIDO]` | 60.0 | **~120.0** | senão a parede seca antes de terminar de ser pintada |

---

## 5. Ordem de execução — Fase G

Quebrada em quatro passos que **entregam valor isoladamente** e podem parar em qualquer um deles.
Nenhum depende do rig (Fase D) nem da coreografia (Fase E) — exceto 3.9, que está marcada.

### G1 — O campo de secagem (o item que sozinho resolve a queixa) ✅ **feito em 03/08/2026**

- `[x]` `mascara_tinta.gd`: textura de mancha por parede (`FastNoiseLite`, 2 oitavas, semente
  derivada do índice da parede)
- `[x]` `tinta_secando.gdshader`: samplers e uniforms novos; `atraso_por_espessura` substituído pelo
  bloco `variacao` de 3.1
- `[x]` `parede_pintavel.gd`: `VARIACAO_MAX`, `VARIACAO_CONCLUSAO`, `FIM_DA_COR`, `CARGA_TIPICA`,
  `ESPESSURA_DEMAO`, `_duracao_demao`, offset de UV por demão; `ESPESSURA_TIPICA` apagada
- `[x]` `k_mancha` e o peso da mancha indo pro `ROUGHNESS` (3.2)

**Entrega:** a fase manchada passa a existir; o modo Realista vira assistível; a espera morta cai de
21% pra 3,9%. **É o item de maior retorno do documento.** Ver 5.1 pro que mudou em relação ao plano.

### 5.1 O que a G1 entregou de fato — 03/08/2026

Três coisas do plano estavam erradas e só apareceram medindo. Nenhuma é de forma; todas são de
qual número entra na conta.

#### ⚠️ (1) A espessura vem da máscara RECENTE, não da acumulada

3.1 escreve `esp_rel = relevo / espessura_esperada - 1.0`, com `relevo = acum.g`. Implementado assim,
**a dispersão da secagem CRESCE a cada demão** — medido, razão p05–p95 de 1,53 na 1ª demão e 2,07 na
3ª. É o contrário do certo, e contraria o próprio plano, que diz que o termo "não cresce com o número
de demãos": a 3ª demão cai sobre substrato selado e é a mais lisa.

A causa é que a acumulada é acumulada: o relevo das demãos velhas empilha neste termo. O que atrasa a
secagem é o filme **molhado desta demão**, e quem guarda isso é a máscara recente, que é limpa a cada
demão. Trocado pra `rec.g`, a dispersão fica estável: 1,51 · 1,52 · 1,51 nas três demãos.

A acumulada continua sendo a fonte certa pra **marca do rolo**, que é relevo seco de todas as camadas.
São duas grandezas diferentes e agora têm dois divisores diferentes, os dois medidos:

| Constante | Valor | O que é | Medido em |
|---|---|---|---|
| `CARGA_TIPICA` | 0,627 | carga média na recente depois de uma passada (σ 0,113) | secagem |
| `ESPESSURA_DEMAO` | 0,033 | depósito médio de uma demão no acumulador (pico 0,043, σ 0,005) | marca do rolo |

O `espessura_esperada = 0.04` que 3.1 sugeria estava certo em ordem de grandeza pro acumulador — e o
`ESPESSURA_TIPICA = 0.35` que estava no código estava errado por um fator de 10.

#### ⚠️ (2) `relevo_base` precisa ser medido, não constante

O acumulador é absoluto e **já vale 0,498 quando o jogo retoma de um save**, porque
`preencher_coberta` grava G = 0,5. Com um centro chumbado, o termo saturava o clamp na parede inteira.
`iniciar_demao` agora lê a máscara de volta (1 texel a cada 8, ~6 mil amostras) e mede a base.

Isso destapou um bug antigo: `marca` usava `relevo - 0.5`, um centro chumbado que **só batia por
acidente** justamente porque `preencher_coberta` grava 0,5. Numa parede pintada do zero o relevo vale
~0,033 e o termo virava um escurecimento chapado de −0,47. Era esta a origem do *"números inertes"*
anotado na Fase B: o desvio real (±0,005) sumia ao lado do erro de centro.

#### ⚠️ (3) O anúncio de conclusão usa um percentil, não o teto

`duracao_total()` com `VARIACAO_MAX` limita o **pior texel possível** — mas só 0,3% da parede chega
perto dele, e esperar por esses custava 12% de espera morta com a parede já parada na tela. Virou
duas constantes: `VARIACAO_MAX = 0.40` (o clamp do shader, contrato de verdade) e
`VARIACAO_CONCLUSAO = 0.20` (o percentil que o anúncio usa).

#### O pente do carimbo, que a G1 destapou

A máscara recente é escrita com `blend_mix` a cada meia faixa do rolo, e **mix não é partição da
unidade** — só o `blend_add` da acumulada é, que era o motivo do perfil triangular do carimbo. Sobra
um ripple no período do carimbo (~3,6 texels) nos **dois** canais.

Antes da G1 isso sumia dentro do `smoothstep` saturado da cobertura. Depois, com `instante` e
espessura alimentando o tempo local de secagem direto, ele virou um **pente horizontal fino
atravessando a parede** — lê como defeito de renderização, não como tinta. Resolvido com um box
filtro sobre `rec.rg` de largura **exatamente igual ao período do carimbo** (3 taps espaçados de
passo/3), que tem um zero nessa frequência. Suavizar só o G deixava metade do pente na tela, porque
`instante` (canal R) carrega o mesmo ripple. O período vem de
`MascaraTinta.passo_carimbo_texels()`, derivado das constantes — chumbar o número faria mexer na
faixa do rolo trazer os carimbos de volta sem aviso.

#### ⚠️ E o lap mark disparava em todo carimbo

Achado depois, numa foto do jogo: a parede inteira ficava com **cara de tecido**, tramada de
tracinhos horizontais curtos. Desligando um termo do shader de cada vez, o culpado apareceu na hora
— com o lap desligado a energia de alta frequência caía de 0,633 pra 0,253, e nenhum outro termo
mexia o ponteiro.

A causa: o lap media `instante` **texel a texel sobre a máscara crua**. Mas `instante` anda um degrau
a cada carimbo, então cada carimbo era um "salto" e o lap desenhava um traço em cima dele. Um lap de
verdade é um degrau de segundos entre duas **passadas** vizinhas.

Consertado derivando do campo liso, num passo de **um período de carimbo**: o degrau entre duas
passadas sobrevive a esse passo, o degrau de quantização entre dois carimbos da mesma passada não —
que é exatamente o critério que separa as duas coisas. Energia caiu pra 0,270, encostada no piso de
0,248 de "lap desligado".

Isso estava latente desde a Fase B e ficou escondido enquanto nada mais no shader dependia de
`instante`. Vale como aviso pras fases que ainda vão mexer nele: **`instante` é quantizado no passo
do carimbo, e qualquer derivada dele tem que ser tomada numa escala maior que esse passo.**

#### Detalhes da textura de mancha

- **24 px/m**, não 256 × 256 fixo. A oitava fina tem 0,35 m, então cada mancha pequena já cobre
  ~8 texels; resolução acima disso é VRAM num sinal que nunca é visto como textura
- **Amostrada em metros, não em UV.** Em UV, uma parede 6 × 3 esticaria cada mancha na proporção 2:1
- **Textura 1,5× maior que a parede**, em vez de `repeat_enable`. O ruído do `FastNoiseLite` não é
  tileável, e o wrap deixaria uma emenda reta atravessando a parede — o oposto do que a mancha faz.
  A margem é o que permite o offset por demão

#### Medições

Critério do plano — razão entre `duracao_local` máximo e mínimo ≥ 1,5:

| Demão | Leste | Norte | Oeste | Sul |
|---|---|---|---|---|
| 1ª | 2,33 | 2,33 | 2,27 | 2,33 |
| 2ª | 2,32 | 2,33 | 2,30 | 2,30 |
| 3ª | 2,33 | 2,33 | 2,27 | 2,33 |

Entre p05 e p95 fica 1,45–1,58, e o clamp é tocado por só 0,1–0,3% da parede — o campo não está
saturado, está distribuído. A parede oeste seca consistentemente antes (média 56 s contra 59 s das
outras): é o termo da janela funcionando.

A mancha como **evento** (aceites 2 e 3), medindo o contraste espacial da parede norte. A coluna
"só a mancha" é a diferença entre renderizar com e sem a textura de mancha — o contraste total
inclui a estrutura de brilho que a G2 põe na parede molhada, e misturar as duas escondia o que
importa aqui:

| `fracao` | 0,02 | 0,15 | 0,30 | 0,50 | 0,70 | 1,00 |
|---|---|---|---|---|---|---|
| total | 1,42 | 1,19 | 0,93 | **2,67** | 1,86 | 0,57 |
| só a mancha | 0,00 | 0,03 | 0,07 | 0,13 | **0,86** | 0,00 |

Nasce, chega ao pico no meio, e morre — zero nas duas pontas. Quem só olhar antes e depois não vê
mancha nenhuma, que era exatamente a proposta.

Espera morta (aceite 7): **21% → 3,9%**, e depois → **2,3%** com o ajuste de curvas da G2 (ver 5.2).

⚠️ **Estes números foram remedidos.** O harness original não congelava a cena, e os personagens
entrando em quadro depois do quadro de referência viravam uma diferença permanente — a medição
travava num "4,22% da parede nunca converge" que não era do shader. `VARIACAO_CONCLUSAO` foi
recalibrado com o harness limpo e ficou em **0,24** (era 0,20).

⚠️ **Como medir isso de novo, se precisar:** comparar quadro com quadro **não funciona** — o limiar
é por passo, então passo menor deixa o detector menos sensível e a resposta muda com a resolução do
teste (60 passos deram 77 s; 160 deram 74 s pro mesmo jogo). A formulação que independe do passo é
comparar cada quadro com o **estado final**: "a cor parou" = "a imagem chegou a menos de 1 nível de
255 do que ela vai virar".

### G2 — Cor e superfície ✅ **feito em 04/08/2026**

- `[x]` `cor_tinta.gd`: `meio()`, `VEU_MOLHADO` 0.55 → 0.32
- `[x]` Shader: `k_brilho`/`k_sat`/`k_valor` e os dois mixes (3.3)
- `[x]` Shader: `SPECULAR` com termo rasante, `ROUGHNESS` 0.36 (3.4)
- `[x]` Bead na borda molhada (3.5) — implementado, **inerte até a Fase E**, ver 5.2

**Entrega:** a escala de segundos — o jogador descobre o molhado movendo a cabeça.

### 5.2 O que a G2 entregou de fato — 04/08/2026

#### O véu caiu pra 0,32 e a secagem ficou MAIS visível, não menos

Era o risco óbvio: `VEU_MOLHADO` tinha subido de 0,20 pra 0,55 justamente porque a secagem sumia.
Medido no render depois da mudança, o percurso da cor de molhada a seca é de **47,4 valores de 255**
— contra os ~34 que o véu de 0,55 entregava. Baixar o véu aumentou o percurso.

O motivo é que o percurso agora tem duas pernas em vez de uma. Antes, molhada e seca diferiam quase
só em **saturação**, e o `mix` atravessava o cinza. Agora a saturação sobe primeiro e o valor cai
depois, e as duas somam.

| `fracao` | 0,00 | 0,20 | 0,40 | 0,60 | 0,80 | 1,00 |
|---|---|---|---|---|---|---|
| saturação | 0,11 | 0,26 | 0,49 | 0,54 | 0,55 | 0,55 |
| valor | 0,51 | 0,49 | 0,49 | 0,45 | 0,42 | 0,42 |

O cotovelo é mensurável: o caminho se afasta **14%** da reta que liga as duas pontas no RGB.

#### ⚠️ `meio()` em HSV e com salto de 22%, não `lerp` pro branco de 10%

3.3 sugere `seca(i).lerp(Color(1,1,1), 0.10)`. Duas coisas erradas nisso.

**Puxar pro branco em RGB dessatura.** Na tinta laranja, um lerp de 0,10 já levava a razão B/R de
0,19 pra 0,29 — repetiria no meio da travessia exatamente o defeito que a G2 existe pra tirar do
começo dela. Feito com `Color.from_hsv`, mantendo matiz e saturação.

**E 10% de salto de valor é pouco demais**, por um motivo que só aparece medindo junto com a G1: com
10%, a perna do valor ficava com ~18 valores de 255 contra ~40 da perna da saturação. Como a
saturação fecha em `fracao` 0,48 — **antes** da janela da mancha (0,10–0,92) — sobrava pouca
inclinação de cor justamente onde a mancha precisa aparecer, e a contribuição dela caiu 5×
(de 1,9 na G1 pra 0,35). Com 22% ela volta pra 0,86, e o cotovelo dobra de 14% pra 28% do percurso.
22% também é mais fiel: látex escurece bastante ao consolidar.

#### ⚠️ As curvas são mais estreitas que as de 3.2

3.2 propõe `k_sat = smoothstep(0.05, 0.55)` e `k_valor = smoothstep(0.38, 0.95)`. Com essas faixas,
**no meio da secagem as duas curvas estão em região plana ao mesmo tempo** — a saturação já
terminando, o valor mal começando. Pouca inclinação no meio significa pouca mancha, porque é a
inclinação que converte variação de `fracao` em variação de cor.

Ficou `k_sat = smoothstep(0.05, 0.48)` e `k_valor = smoothstep(0.34, 0.85)`.

O `0,85` tem uma segunda função: **`FIM_DA_COR` em `parede_pintavel.gd` espelha esse número**. Com
`k_valor` fechando em 0,95, a cauda da curva é plana e não muda nada na tela, mas adiava a conclusão
— foi o que obrigou a G1 a usar um percentil em vez do teto do clamp. Com o fim da curva no lugar
certo, a conta de `duracao_total()` volta a bater com o que se vê.

#### O brilho rasante funciona — mas só na linha de reflexão de uma luz

Aqui quase concluí que o mecanismo era inerte, e o erro estava na medição. **Comparar a parede vista
de frente com a parede vista de raspão amostrando regiões diferentes não mede specular** — de raspão
a parede inteira fica mais escura porque a luz chega diferente, e essa mudança geométrica afoga o
efeito. Tem que ser o **mesmo ponto da superfície**, visto de dois lugares: aí o termo difuso é
idêntico e só o termo de vista muda.

Com o ponto fixo, um passeio de ângulo no plano horizontal ainda dá quase nada (+49 de 255 de frente,
+51 a 85°). O que faltava era a geometria certa: o brilho especular só aparece onde o **reflexo da
parede aponta pra uma luz**. Pondo a câmera em cima da linha de reflexão:

| linha de reflexão | molhada | seca | diferença |
|---|---|---|---|
| nenhuma (85° horizontal) | 0,518 | 0,316 | +51 de 255 |
| lâmpada do teto | 0,619 | 0,289 | **+84** |
| luz do cômodo vizinho | 0,718 | 0,299 | **+107** |

Resumindo o aceite: a aparência da parede **molhada** varia de 0,432 a 0,718 conforme a geometria de
vista (oscilação 0,286); a **seca** varia de 0,288 a 0,300 (0,013). **A molhada é 22× mais sensível
ao ângulo que a seca** — que é exatamente "o jogador move a cabeça e descobre coisa".

Como a câmera da cadeira é fixa em posição e só gira, cada ponto da parede tem a sua própria direção
de vista: o que o jogador vê é uma **região** da parede brilhando, e ela se move conforme ele olha
em volta. Melhor do que um efeito uniforme.

#### O bead está certo e está inerte até a Fase E

Implementado, e **sem efeito nenhum hoje**: com `escala_bead` em 0, 3 e 8, a imagem é byte a byte a
mesma (maior degrau vertical 0,2 de 255 nos três).

O motivo é geometria de trajeto, não de código. O bead é **gravidade**: ele mora na borda de baixo do
traço, e portanto precisa de um gradiente de cobertura em `v`. O trajeto atual são passadas verticais
de altura inteira, então a frente de pintura é uma linha **vertical** — não tem borda horizontal no
meio da parede pra ele agir. As únicas bordas em `v` são o topo e o rodapé.

É a mesma dependência que 3.8 já anota pro lap mark: **só faz sentido depois da Fase E**, quando o W,
as verticais curtas e o banquinho criarem traços com borda de baixo. O código fica, custa dois taps
que já eram calculados pro lap, e está anotado aqui pra não virar mais um "número inerte" esquecido.

✅ **Deixou de ser inerte na Fase E (05/08/2026).** Medindo na máscara quanta parede tem queda de
cobertura indo pra baixo — que é literalmente o que o bead morde — o valor foi de ~0 pra **3,18% da
parede**. As bordas novas são as do W (cada perna termina numa ponta) e as emendas entre as três
faixas de altura. `escala_bead` continua em 3,0; não precisou mexer, precisou de trajeto.

⚠️ **Uma coisa mudou em relação a 3.5:** o bead sai do gradiente da **cobertura**, não do `instante`
como o plano sugeria. O gradiente do instante traria de volta o pente do carimbo que o conserto do
lap acabou de tirar — e a cobertura é mais fiel de todo jeito, porque o bead é uma borda de tinta,
não uma borda de "quando foi pintado".

#### ⚠️ Como medir estas coisas sem se enganar

Três armadilhas de medição apareceram nesta fase, e todas produziram números convincentes e errados.

**1. Comparar regiões diferentes não mede specular.** Ver acima: de raspão a parede inteira fica mais
escura por geometria de luz, e isso afoga o efeito. Fixar o ponto da superfície.

**2. O brilho especular só existe na linha de reflexão de uma luz.** Varrer ângulo a esmo dá quase
nada e leva à conclusão errada de que o mecanismo é inerte. Espelhar a luz no plano da parede e pôr
a câmera na direção resultante.

**3. Congelar a cena.** A cutscene continua rodando durante o teste: `set_process(false)` nas paredes
não basta, porque `ciclo_pintura` pode remostrar os personagens e um deles entrando em quadro depois
do quadro de referência vira uma diferença **permanente**. Isso produziu um "4,22% da parede nunca
converge" — idêntico em quatro configurações diferentes do shader, que era justamente a pista de que
não era o shader. Tirar Tio e Garotinha da árvore e parar `ciclo_pintura`.

Junto com a lição da G1 (comparar quadro com quadro depende do passo; comparar com o estado final,
não), são quatro maneiras de medir errado neste projeto. Todas custaram uma rodada.

### G3 — Cobertura com consequência ✅ **feito em 04/08/2026**

- `[x]` Shader de cópia + chamada em `iniciar_demao` (3.6) — mas **não** `R → B`, ver 5.3
- `[x]` Shader: fundo histórico em vez de `cor_anterior` chapada
- `[x]` `trajeto_rolo.gd`: números da carga + jitter (3.7)
- `[x]` Recalibrar `cobertura_min`/`cobertura_max` — **ganho visual baixo de propósito**, ver 5.3

**Entrega:** o critério de aceite nº 2 do overhaul (a 2ª demão cobre falha da 1ª) passa a ser
verificável por screenshot.

### 5.3 O que a G3 entregou de fato — 04/08/2026

A falha de cobertura **sobrevive à troca de demão** e só some quando o rolo passa por cima. Medido no
ponto de pior cobertura da 1ª demão: **0,1 de 255** de mudança no instante em que a demão troca,
contra **57,2** quando o rolo passa por cima. Na parede inteira, o salto na troca é de 1,2 de 255 na
média — antes disso ela trocava de cara inteira num frame.

> ⚠️ **Uma versão anterior desta seção publicou "0,0 de 255" e o número era de um build quebrado.**
> `guardar_historico` estava sendo chamada com os limiares lidos de
> `material.get_shader_parameter()`, que devolve **null** pra uniform que nunca foi setada
> explicitamente — o default escrito no `.gdshader` não conta. A chamada morria em silêncio no meu
> teste, o histórico nunca era escrito, e a costura media zero porque nada mudava. Ver a armadilha
> completa no `PROJETO.md` 3.3.

#### O histórico guarda a COBERTURA, não a máscara crua

3.6 propõe copiar `R → B` dentro da acumulada no começo de cada demão. Duas coisas impedem.

**Não dá pra copiar dentro da mesma textura.** Um blit que lê e escreve a mesma imagem é hazard de
leitura/escrita. Como `DrawableTexture2D` é `Texture2D`, ela serve de fonte pra outra — então virou
uma textura separada, 1,5 MB por parede.

**E o conteúdo não pode ser a máscara crua.** Duas tentativas, as duas medidas e descartadas:

| Guardando | O que quebrou |
|---|---|
| `acumulada.r` (depósito somado), cobertura da demão = `acum.r − hist.r` | A acumulada é RGBA8 com `blend_add` e **satura em 1**. Depois que a 1ª demão cobre um ponto, a 2ª e a 3ª depositam zero ali e **não aparecem** — a parede simplesmente parava de mudar. Pego pelo teste da mancha da G1, que ficou chapado em 0,648 do começo ao fim |
| `recente.g` (carga), com um par de limiares só pro histórico | Carga e depósito somado não se correspondem ponto a ponto: onde duas passadas se sobrepõem o depósito soma, mas a carga (escrita com `blend_mix`) é ~a da última. **Nenhum par de limiares casa as duas** — tentei resolver por quantis, com a inversa fechada do `smoothstep`, e o salto na troca ficou em 8,9 de 255 na média e **130 no pior ponto** |

O que funciona é guardar **o mesmo número que o shader mostrou na tela**: `copia_cobertura.gdshader`
aplica o mesmo box e o mesmo `smoothstep` e soma o resultado no histórico. Aí a costura fecha por
construção, e é por isso que ela dá 0,1 de 255.

Os limiares moram em `parede_pintavel.gd` (`COBERTURA_MIN`/`COBERTURA_MAX`) e são **empurrados** pros
dois shaders. Não podem ser lidos de volta do material, e não podem ficar chumbados em dois
`.gdshader` diferentes — se divergirem, a costura reabre sem dar erro.

#### ⚠️ `cobertura_min` tem que ser zero ou positivo

Tentei um mínimo negativo pra suavizar a falha (a curva fica mais macia). **Carga zero passou a ler
como 68% coberto** — a cor nova aparecia na parede inteira no instante em que a demão começava, que é
precisamente o que a G3 existe pra impedir. O salto médio na troca pulou de 6 pra 16 de 255 e
entregou o erro. Com o mínimo preso em zero, quem controla a amplitude é só o máximo.

#### A marca do rolo virou passa-alta

Ela ainda tinha um centro guardado (`relevo - relevo_base`, herdado da G1). Como `relevo_base` é
remedido a cada demão, o termo saltava de +0,5 pra −0,5 na troca e **a parede inteira dava um pulo de
~15 de 255**. Agora é `relevo` menos a média local dele — os dois lados vêm da mesma textura no mesmo
instante, então é contínuo por construção, e não há centro pra errar. É o terceiro centro tentado
neste termo; o passa-alta é o primeiro que não tem um.

> A largura do borrão largo estava errada e isso só foi pego em 5.4 — ver lá.

#### ⚠️ A amplitude da falha está baixa de propósito, e destravar é da Fase E

`CONSUMO_POR_METRO` foi pros números físicos do plano (9 m por carga, carga caindo de 1,00 pra 0,37),
e a falha **existia** — mas nunca no valor que 3.7 pede.

O motivo não é gosto, é o trajeto. Uma carga dá 9 m e uma passada de altura inteira dá 3 m, então
**uma carga dura 3 passadas** e a carga cai 21% de uma passada pra vizinha. Com passadas de altura
inteira, qualquer variação por passada vira barra vertical de cima a baixo: a parede sai como código
de barras. Testei cobertura mínima de 42% (o número de 3.7) até 85% — **o padrão de listra não muda,
só o contraste dele.**

O W, as verticais curtas e o banquinho da Fase E quebram a passada de altura inteira, e é lá que a
falha vira mosqueado em vez de listra. É a terceira coisa desta fase G que depende de E, junto com o
bead (5.2) e o lap mark (3.8) — vale tratar as três como um pacote quando E chegar.

Em 5.4 a falha foi **desligada** (`cobertura_max` 0,16 → 0,10): mesmo na amplitude discreta ela ainda
saía como barra, e o Caio pegou na tela. O jitter de ±15% no tamanho da carga continua no lugar,
esperando E.

#### ✅ Reaberta na Fase E — até 0,20, e o teto tem explicação — 05/08/2026

A coreografia quebrou a passada de altura inteira, e a barra sumiu. A falha saiu de 0,10 (inerte)
pra **0,20**. Mas os 0,72 de 3.7 continuam inalcançáveis, e agora se sabe por quê — não é gosto nem
calibração:

**`rec.g` grava `carga × peso do carimbo`, e o peso cai nas bordas de cada passada.** Abrir a faixa
expõe a borda macia do carimbo ANTES de expor a carga. Por isso o que aparece ao subir o valor são
riscos brancos nas emendas entre passadas, e não "rolo secando":

| `cobertura_max` | na tela |
|---|---|
| 0,20 | variação suave, sem branco — **em vigor** |
| 0,25 | risco branco fino na ponta de cada W |
| 0,35 | manchas brancas grandes |
| 0,45 | manchão em ¼ da parede |

**O que consertaria:** um canal separado só pra carga, sem o peso do carimbo dentro — a máscara
acumulada tem B e A livres. Não foi feito nesta rodada; fica registrado como limite conhecido.

⚠️ **Duas métricas de máscara mentiram no caminho até aqui.** "O pior 1% cobre 0,44" aprovou 0,45,
que é o pior valor testado; "10,5% abaixo de 0,90 e nada abaixo de 0,50" aprovou 0,35, que na tela
tem mancha grande. O que a máscara não sabe é como aquela cobertura vira cor depois do shader
inteiro. Número que o jogador vê se decide **no quadro renderizado**.

**Também mudou o modelo da carga**, e isso valeu tanto quanto o teto. A queda era linear, então a
carga passava metade do percurso abaixo de 0,65 e **um terço da parede** saía falhado. Rolo de
verdade entrega filme parelho quase até o fim e aí despenca — a espuma segura por capilaridade.
Expoente 3 (`EXPOENTE_CARGA`) põe a carga em 0,92 na metade e só derruba nos últimos ~20%.

E `METROS_POR_CARGA` foi de 9,0 pra **18,5**: os 9,0 valiam pro trajeto antigo, que passava na parede
uma vez (106 m ÷ 12 cargas = 8,8). A coreografia passa 2,12× no mesmo lugar, então a MESMA tinta se
espalha por 224 m. O que é físico são as **12 cargas por parede** (1,5 m² por carga em 18 m²), não os
metros.

### 5.4 Três queixas do Caio na tela, e o que cada uma era — 04/08/2026

Ele jogou o resultado da G3 e trouxe três coisas. Nenhuma das três era a que eu teria chutado.

| O que ele viu | O que era |
|---|---|
| "quando uma nova demão vai começar, a textura da parede fica lisa" | **Duas causas somadas.** `suavidade_demao` multiplicava a marca do relevo **já na parede**, então a demão nova alisava retroativamente a camada de baixo num frame. E o `historico` é `blend_add`: depois de duas demãos ele satura em 1 e toda a falha lembrada some sozinha ao começar a 3ª |
| "a 1ª demão ficou com partes brancas, não parece o rolo ficando sem tinta" | Era o rolo ficando sem tinta — mas **não parece** porque a recarga é instantânea no meio de uma passada de altura inteira. O resultado é uma barra vertical com **a ponta quadrada**. E tinha um bug somando: a carga entrava **duas vezes** no canal (ver abaixo) |
| "a última demão devia ficar homogênea depois de secar" | `suavidade_demao = 1/(1+0,9n)` parava em **0,36** na 3ª demão: um terço da marca da 1ª ainda aparecia na parede acabada |

#### A carga entrava ao quadrado

`carimbo_recente.gdshader` usava `peso = carimbo.r * carga` como peso da mistura **e** gravava `carga`
no canal G. Estar nos dois lugares faz o canal convergir pro quadrado da carga: com o rolo no fundo
(0,30) o G ia pra ~0,15, e a falha saía com o dobro da profundidade que a física pede.

Medido antes: G médio **0,398** numa parede cuja carga média é ~0,685, com mínimo **0,000** no miolo.
Depois de tirar a carga do peso: médio **0,511**, mínimo **0,164**. `CARGA_TIPICA` foi de 0,627 pra
0,511 por causa disso.

#### O canto que o laço das passadas não alcançava

`_gerar_pontos` somava `PASSO_METROS` até estourar a largura, então o resto da divisão ficava sem
tinta — 2 cm numa parede de 6 m, uma faixa clara vertical no encontro das paredes. Agora o número de
passadas é `ceil(largura / PASSO)` e o passo efetivo é `largura / n`: primeira e última a meio passo
de cada canto, e o passo fica um pouco menor, o que só aumenta a sobreposição.

#### A suavidade da marca virou duas, e a última demão fecha em zero

O shader tem `suavidade_anterior` (quanto a marca aparece no que **já está** na parede) e
`suavidade_demao` (quanto vai aparecer **depois que esta demão cobrir**). O `mix` por `cobertura`
escolhe entre as duas, então o degrau entra **atrás do rolo** em vez de na parede inteira de uma vez.

E a curva virou `1 − numero/(total−1)`: 1,00 · 0,50 · **0,00**. A última demão apaga a marca do rolo
enquanto passa, que é a recompensa de ter pintado três vezes.

#### ⚠️ O passa-alta da marca estava comendo o próprio sinal

`relevo_largo` era um borrão de 3 taps espaçados de `passo * 7` — largura total **17 texels**. O sinal
que ele deveria preservar é a passada do rolo, de período `0,167 m × 146 px/m` = **24,3 texels**. Uma
média local mais estreita que o período do sinal **acompanha o sinal**, e o passa-alta subtrai
exatamente o que existia pra mostrar.

Medido na máscara, RMS da marca depois da 1ª demão, variando o fator:

| fator | largura | marca RMS | pico |
|---|---|---|---|
| 7 (era) | 17 texels | 0,0083 | 0,038 |
| 12 | 29 texels | 0,0121 | 0,043 |
| 20 | 49 texels | 0,0156 | 0,048 |
| **30** | **73 texels** | **0,0181** | **0,050** |
| 45 | 110 texels | 0,0172 | 0,048 |

30 (três períodos da passada) é o topo; de 45 pra cima o viés da borda começa a comer de volta. A
regra geral: **o borrão largo tem que ser ≥ 3× o período do que ele não pode apagar.**

#### Resultado

Listra vertical do rolo, RMS relativa do perfil por coluna, em por mil (piso de ruído do render ≈ 10):

| Momento | Antes | Depois |
|---|---|---|
| 1ª demão seca | 46,8 | 19,7 |
| 2ª demão começou | 46,0 | 18,2 |
| **salto na troca 1→2** | 1,1 médio / **31,6 pior** | 0,7 médio / **6,6 pior** |
| 2ª demão seca | 41,8 | 17,1 |
| 3ª demão começou | **6,9** (colapso de 83%) | 15,1 (queda de 11%) |
| **salto na troca 2→3** | 1,9 médio / **50,6 pior** | 0,7 médio / **5,5 pior** |
| 3ª demão seca | 10,9 | **10,0** (= o piso) |

Antes: as duas primeiras demãos eram dominadas pelas barras brancas, e o desenho todo desaparecia
num frame ao começar a 3ª. Depois: declínio monótono da 1ª à 3ª, terminando no piso de medição — a
parede acabada é homogênea.

> ⚠️ `mancha_offset` e `_sortear_molhadas()` usam `randf()` **sem semente**, então cada execução
> pinta com outro sorteio: as colunas "depois" variam ~10% de rodada pra rodada (medi 17,6 e 19,7 na
> mesma configuração). A diferença pro "antes" é grande demais pra ser isso, mas quem for comparar
> duas mudanças pequenas tem que semear primeiro.

A G1 foi re-verificada depois de tudo isso (`CARGA_TIPICA` mudou, e é divisor do termo de espessura):
razão 2,33 nas 12 combinações de parede × demão, com 0,9–2,0% no clamp.

#### ⚠️ Duas armadilhas de medição novas

**Contraste local pixel a pixel não mede textura neste jogo.** Com `use_debanding` ligado, o dither de
~1/255 domina a métrica: ela deu 0,7 em *toda* configuração testada e não mexeu nem quando as barras
brancas sumiram da tela. A marca do rolo é listra **vertical** — então média por coluna (o dither é
independente por pixel e morre na média), menos uma média móvel larga (mata o gradiente de luz), RMS
do resto. E **relativa ao brilho médio**, senão parede escura parece mais lisa só por ser escura.

**`adiantar(duracao_total())` não seca a parede toda.** `duracao_total()` usa `VARIACAO_CONCLUSAO`
(percentil 0,24), não `VARIACAO_MAX` (0,40): nos pontos mais lentos sobra `fracao` ≈ 0,75, onde
`k_mancha` ainda vale ~0,59. Medir "textura permanente" nesse quadro mede mancha de secagem junto.
Quem quiser o estado final de verdade tem que adiantar bem além — 3× resolve.

#### `relevo_base` estava morto

Sobrou da versão pré-passa-alta: `uniform float relevo_base` era declarado e **nunca lido** no
`fragment()`, e `_medir_relevo_base()` fazia um readback da máscara inteira mais ~6 mil `get_pixel`
no começo de cada demão pra alimentar ele. Removidos os três.

### 5.5 As listras verticais da parede — 04/08/2026

O Caio mandou print: lado esquerdo de cada parede com listras verticais, lado direito liso. **Duas
causas independentes, e nenhuma era o que eu teria chutado.**

#### Causa 1 — a luz do cômodo vizinho atravessava a parede

`comodo_vizinho.gd::_criar_luz` era `OmniLight3D` com `shadow_enabled = false` e `omni_range = 9`,
partindo de x = 6,6. Sem sombra, ela alcançava x = −2,4 — **quase o quarto inteiro**, e mais forte no
lado leste. Perfil de brilho da parede norte, em 8 faixas de oeste pra leste:

| | f1 | f2 | f3 | f4 | f5 | f6 | f7 | f8 |
|---|---|---|---|---|---|---|---|---|
| com o vazamento | 18,6 | 22,3 | 26,1 | 29,0 | 30,7 | 31,0 | 30,6 | 30,5 |
| sem | 18,6 | 22,2 | 25,5 | 27,4 | 27,5 | 25,6 | 22,6 | 19,0 |

Sem ela o perfil é **simétrico** — que é o que uma lâmpada no meio do teto deve fazer. Era o
vazamento que criava o lado claro, e por isso a listra só se via no lado escuro.

A saída é a que `cenario_externo.gd` já usava pro problema espelhado (luz de fora acendendo o
quarto): camada de render própria + `light_cull_mask`. Sombra resolveria também, mas custa, e não há
nada ali que precise de sombra.

De quebra, ficou medido que **`Sol`, `LuzJanela` e SSAO contribuem exatamente zero** na parede norte —
a única luz que chega nela é a lâmpada de teto.

#### Causa 2 — o lap mark estava aceso em 20,7% da parede

`PROJETO.md` §3.4 listava o lap como inerte, com "salto medido de 0,023 s contra limiar de 0,35".
Medindo a distribuição de verdade na máscara, com a mesma conta do shader:

| p50 | p90 | p99 | p99,9 | máximo |
|---|---|---|---|---|
| 0,143 | 0,546 | 0,959 | 1,148 | **1,250** |

O número do plano estava errado por **~25×**, e com limiar 0,35 um quinto da parede ficava marcado.
Como o lap segue a emenda entre passadas, o desenho dele é exatamente **listra vertical no
espaçamento do rolo**.

O limiar tem que ficar acima do intervalo entre passadas VIZINHAS, que num zigue-zague contínuo é
`janela_demao / n_passadas` = 8 / 36 = **0,222 s**. Duas passadas separadas por um quinto de segundo
não formam lap nenhum — lap de verdade é tinta que já começou a formar película, o que leva minutos.
Foi pra **1,5**, acima do máximo medido.

#### Resultado

Listra na banda de 10–60 px (a que o olho vê), relativa ao brilho:

| | antes | depois |
|---|---|---|
| shader da tinta | **0,64%** | **0,05%** |
| material chapado (piso de comparação) | 0,04% | 0,04% |

Ou seja: a parede pintada agora tem tanta listra quanto um `StandardMaterial3D` liso — ou seja,
nenhuma. E o degrau por faixa caiu de `0,517 · 0,435 · 0,317 · 0,256` no interior pra
`0,010 · 0,023 · 0,035 · 0,035`. G1 re-verificada: razão 2,33, clamp 0,6–1,2%.

#### ⚠️ A armadilha que fez isso levar seis rodadas

**RMS contra média móvel não isola listra — captura a curvatura do fundo junto.** Queda de lâmpada é
inverso do quadrado, e uma média móvel de 121 colunas não acompanha curva: o resíduo entra na conta
como se fosse defeito. O número subia junto com o brilho, então *nenhuma* mudança de luz parecia
resolver, e a comparação contra material chapado dizia "metade sobrevive sem a tinta" — tudo
artefato da métrica.

Listra pede **passa-banda**: média de 7 colunas menos média de 31, que deixa passar só período de ~10
a ~60 px. Trocada a métrica, o material chapado passou a mostrar **16× menos** listra que o shader, e
desligar um termo de cada vez achou o lap na primeira tentativa.

Segunda armadilha, já anotada mas repetida aqui de novo: **desligar termo que já vale zero dá
"idêntico" e não prova nada.** `forca_marca = 0` não mudou nada porque na 3ª demão
`suavidade_marca(2, 3)` já zera a marca. O mesmo com cobertura, que já fechava em 1,000. Três testes
seguidos deram "idêntico" e eu quase concluí que não era o shader.

### G4 — Depende da Fase E

- `[ ]` Lap mark relativo à secagem local em vez de absoluto em segundos (3.8) — só aparece com
  coreografia que revisita trechos
- `[ ]` Medir a duração real da coreografia e escrever em `duracao_pintura_segundos` (3.9)
- `[ ]` Subir `TEMPO_SECAGEM[RAPIDO]` pra ~120 s, senão a parede seca antes de terminar de ser
  pintada (3.9)
- `[ ]` `FRACAO_JA_PINTADA_ABERTURA` 0.65 → ~0.90 (3.9)

**Definição de pronto de cada G:** está no `PROJETO.md` §4, na lista "Ordem recomendada" — é lá que
mora a ordem de execução oficial, pra não haver duas versões dela.

### Custo

Dois samplers extras (a mancha é uma textura de 256×256 R8, ~65 KB por parede) e umas duas dúzias
de instruções ALU por fragmento. Uma blit de textura inteira por demão. Irrelevante — a Fase A já
mediu 0,022 ms por blit e 7 MB de VRAM pro sistema todo.

### O que dá pra testar sem jogar

Pouca coisa, e isso já está documentado: `execute_editor_script` não roda `await`, e carregar
shader dentro dele trava em silêncio. Vale o teste estrutural (a cena carrega sem erro) e depois o
único teste que importa — **gravar 60 s e assistir inteiro**, que já é item da Fase F.

Uma verificação numérica que vale a pena e é barata: printar `duracao_local` mínimo e máximo da
parede depois de uma demão. Se a razão entre eles não for pelo menos **1,5**, o campo não está
fazendo efeito e não adianta olhar a tela.

---

## 6. A proporção do quarto

### 6.1 O que está medido hoje

```
Quarto:  X ∈ [-3,5, +3,5] = 7,0 m      Z ∈ [-4,0, +2,0] = 6,0 m      Y ∈ [0, 3,0]
Centro do quarto: (0, -1)      Cadeira/câmera: (0, 1.2, -1) — no centro exato
```

| Parede | Área pintável | Máscara | Distância da câmera |
|---|---|---|---|
| Norte (a da tinta) | 7,0 × 3,0 = **21 m²** | 1022 × 438 | 3,0 m |
| Sul | 7,0 × 3,0 = **21 m²** | 1022 × 438 | 3,0 m |
| Leste (porta) | 6,0 × 3,0 = **18 m²** | 876 × 438 | 3,5 m |
| Oeste (janela) | 6,0 × 3,0 = **18 m²** | 876 × 438 | 3,5 m |

A câmera já está no centro. A diferença de 0,5 m na distância é pequena; **não é ela** que produz a
sensação relatada.

### 6.2 Por que a parede longe parece mais escura — não é a tinta

Isso já foi investigado em 02/08/2026 (a parede leste ficava mais escura) e a conclusão registrada
no `PROJETO.md` está certa: o material das 4 paredes é idêntico, quem varia é a luz que chega.
A correção da época (subir a lâmpada de 0,85 pra 1,1) tratou o sintoma. As causas são quatro:

**(a) A janela não está centrada na parede dela.** A parede oeste vai de Z = −4,0 a +2,0, então o
centro dela é **Z = −1**. A janela está em **Z = 0**. Está 1 m fora do centro, e dá pra ver isso
nos próprios tamanhos das peças: `ParedeOesteNorte` tem 3,15 m de comprimento e `ParedeOesteSul`
tem 1,15 m. Consequência direta na luz:

| Parede | Distância até a `LuzJanela` (−3,42, 1,4, 0) | Iluminância relativa (1/d²) |
|---|---|---|
| Sul | ~2,0 m | **100%** |
| Leste | ~6,9 m | ~8% |
| Norte | ~4,0 m | ~25% |

A parede norte — que é *a* parede do jogo, a que a garotinha encara — recebe **um quarto** da luz
de janela que a parede sul recebe. Essa é a maior fonte da assimetria.

**(b) `area_range = 7.0` e a parede leste está a 6,9 m.** Ela fica literalmente na borda do alcance
da luz. Já foi testado que mexer no `area_range` não resolve (está registrado); o motivo é que a
queda de 1/d² já matou a contribuição bem antes do corte.

**(c) Não existe luz indireta.** As paredes são iluminadas quase só por luz direta de duas fontes
quase pontuais, então a iluminância despenca com a distância. Cômodo real fica uniforme por causa de
**interreflexão** — e é justamente ela que não existe aqui (`SDFGI` foi descartado de propósito, e o
`LightmapGI` está no backlog).

**(d) A lâmpada está a 25 cm do teto** (y = 2,75, teto em 3,0). Isso produz um gradiente vertical
forte em todas as paredes: um ponto no alto recebe ~2,2× o que um ponto no rodapé recebe (1/d²
vezes o cosseno de incidência). Some com o SSAO (`radius 0.7`, `intensity 1.4`, `power 2.0`)
escurecendo o encontro parede/parede e parede/teto, e o canto oposto lido de esguelha fecha a
impressão de "aquela parede está na sombra".

### 6.3 Proposta — quarto quadrado, 6,0 × 6,0

**Encolher X de 7,0 pra 6,0**, mantendo Z como está. `X ∈ [−3,0, +3,0]`, `Z ∈ [−4,0, +2,0]`,
centro em `(0, −1)` — que é onde a cadeira e a câmera já estão.

Por que encolher X em vez de esticar Z:

- **Muda menos coisa.** Só as paredes leste e oeste andam meio metro pra dentro. Esticando Z pra 7 m
  seria preciso mexer no chão, no teto, no assoalho, nas peças norte/sul, na rua e no cômodo vizinho
- **Aproxima a parede leste da luz da janela** — de 6,9 m pra 5,9 m, que é o que 6.2(b) precisa
- **6 × 6 × 3 = 36 m² é um quarto grande; 7 × 7 seriam 49 m², que é salão.** O jogo se chama
  "quarto" na fala do próprio código

O que isso entrega:

- As **4 paredes ficam idênticas**: 18 m², máscara 876 × 438, mesmo enquadramento a 3,0 m da câmera
- **O rolo passa a andar na mesma velocidade nas quatro** — resolve 2.8 de graça, e com ele a
  diferença de depósito e de falha entre paredes
- Virar 90° na cadeira passa a dar exatamente a mesma composição, que é literalmente o que foi
  pedido ("algo igual em todos os lados")

### 6.4 Centrar a janela na parede

Mover a janela e a `LuzJanela` de `Z = 0` pra `Z = −1`. Passa a haver 2,15 m de parede de cada
lado dela, e a iluminância de janela nas paredes norte e sul se iguala:

| Parede | Distância à janela hoje | Depois |
|---|---|---|
| Norte | 4,0 m | **3,0 m** |
| Sul | 2,0 m | **3,0 m** |
| Leste | 6,9 m | **5,9 m** |

**Sobre a porta:** ela também está fora do centro da parede leste (vão em Z ∈ [−0,5, +0,5], centro
da parede em −1). Recomendo **deixar onde está**. Porta encostada mais pra um lado é o normal em
casa, e centrar as duas aberturas na mesma reta deixaria a garotinha sentada exatamente entre um
buraco e outro — simétrico demais, com cara de diagrama. A simetria que resolve a queixa é a das
**paredes**, e essa a janela centrada já entrega. Se você preferir centrar a porta também, é só
mudar dois transforms.

### 6.5 Luz — o que equaliza de verdade

Geometria simétrica ajuda, mas o que iguala parede com parede é luz indireta.

- `[ ]` **`LightmapGI`** — já está no backlog do `PROJETO.md` como candidato e **este é o momento
  natural dele**: ele trava a geometria, então tem que vir *depois* da mudança de proporção, não
  antes. ⚠️ **Armadilha a validar:** as paredes usam `ShaderMaterial` com albedo que muda a cada
  demão e a cada troca de cor. Se elas forem assadas como estáticas, o sangramento de cor fica
  congelado na cor errada. O arranjo certo é assar **piso, teto, props, móveis e cômodo vizinho como
  estáticos** e deixar **as 4 paredes como dinâmicas** (recebendo indireta pelas probes). Testar
  antes de investir tempo de bake
- `[x]` ~~**Baixar a lâmpada** de y = 2,75 pra ~2,35 e subir `omni_range` de 6,0 pra 7,0~~ — **já
  estava feito**: `quarto.tscn` tem `LuzLampada` em y = 2,35 com `omni_range = 7.0`. Item obsoleto
- `[x]` **Fechar o vazamento da luz do cômodo vizinho** (04/08/2026) — ela atravessava a parede leste
  e clareava o lado direito do quarto em até +11,5 níveis, e era isso que deixava o perfil das
  paredes assimétrico. Camada própria + `light_cull_mask`, igual ao `cenario_externo.gd`. Ver §5.5
- ⚠️ **Achatar a rampa NÃO resolve listra** — varrido e medido em 04/08/2026. `omni_range` até 20,
  `omni_attenuation` até 0,35 e `ENERGIA_AMBIENTE` até 0,32: o contraste borda-centro cai de 37,9%
  pra 24,3%, mas a listra relativa fica em 1,6–1,9% em todas as configurações. A listra era o lap
  mark, não a rampa (§5.5). Achatar continua valendo por gosto, não como conserto
- `[ ]` **Aliviar o SSAO**: `intensity` 1.4 → ~1.0 e `radius` 0.7 → ~0.5. Hoje o escurecimento de
  canto é forte o bastante pra ler como "sombra da parede", não como oclusão de quina
- `[ ]` **Se o `LightmapGI` não valer o tempo**, a alternativa barata é subir
  `ENERGIA_AMBIENTE` (0,16 → ~0,22) mantendo a cor dessaturada que já está lá. ⚠️ Foi
  exatamente isso que deixou o quarto "lavado" antes — mas na época havia névoa e não havia tonemap
  ACES. Vale re-testar; se lavar de novo, cai fora e fica só o `LightmapGI`

### 6.6 Lista fechada do que muda

Fechada de propósito — mudança de layout de quarto é o tipo de coisa que deixa um transform pra trás
e vira meia hora de caça a fresta de luz.

**`scripts/inicializar_quarto.gd`**

| Nó | Hoje | Depois |
|---|---|---|
| `ChaoQP` / `TetoQP` | `(7.0, 0.2, 6.0)` | `(6.0, 0.2, 6.0)` |
| `ParedeNorteSolida` / `ParedeSul` | `(7.0, 3.0, 0.2)` | `(6.0, 3.0, 0.2)` |
| `ParedeOesteNorte` | `(0.2, 3.0, 3.15)` | `(0.2, 3.0, 2.15)` |
| `ParedeOesteSul` | `(0.2, 3.0, 1.15)` | `(0.2, 3.0, 2.15)` |
| `ParedeOesteAcima` / `Abaixo` | z = 1.7 | igual (só o transform muda) |
| `ParedeLeste*` | — | tamanhos iguais |
| `_criar_assoalho_tabuas` | `x = -3.5`, `while x < 3.5`, `3.5 - x` | `±3.0` |
| `_criar_cadeira` | `(0, 0, -1)` | igual — vira o centro exato |

**`scenes/quarto.tscn` e `scenes/fundo_menu.tscn`** (os dois, sempre juntos)

| Nó | Hoje | Depois |
|---|---|---|
| `ParedeOeste*` (4 nós) | x = −3.5 | **−3.0** |
| `ParedeOesteNorte` | z = −2.425 | **−2.925** |
| `ParedeOesteSul` | z = 1.425 | **0.925** |
| `ParedeOesteAcima` / `Abaixo` | z = 0 | **−1.0** |
| `ParedeLeste*` (3 nós) | x = 3.5 | **3.0** |
| `Janela` | (−3.5, 1.4, 0) | **(−3.0, 1.4, −1)** |
| `LuzJanela` | (−3.42, 1.4, 0) | **(−2.92, 1.4, −1)** |
| `LuzLampada` / `Lampada` | y = 2.75 / 2.85 | **2.35 / 2.45** (6.5) |
| `Porta` | (3.46, 0, 0.5) | **(2.96, 0, 0.5)** |
| `CameraCutscene` | (−3.0, 2.2, 1.6) | **(−2.5, 2.2, 1.6)** — senão fica dentro da parede |
| `Garotinha` | (2.8, 0, 0.3) | **(2.3, 0, 0.3)** |
| `Camera3D` (cadeira) | (0, 1.2, −1) | igual ✅ |

**`scripts/props_quarto.gd`**

- `LIMITE_X`: 3.4 → **2.9**
- `_moldura_janela`: z 0 → **−1**
- Rodapés derivam de `LIMITE_X`, se ajustam sozinhos ✅

**`scripts/ciclo_pintura.gd`** — `VARREDURAS`, as quatro entradas viram `largura: 6.0`:

| Parede | `origem` | `eixo_u` | `de` → `para` |
|---|---|---|---|
| Leste | `(3.0, 3, 2)` | `(0,0,-6)` | `(2.3,0,1.6)` → `(2.3,0,-3.4)` |
| Norte | `(3.0, 3, -4)` | `(-6,0,0)` | `(2.3,0,-3.4)` → `(-2.3,0,-3.4)` |
| Oeste | `(-3.0, 3, -4)` | `(0,0,6)` | `(-2.3,0,-3.4)` → `(-2.3,0,1.4)` |
| Sul | `(-3.0, 3, 2)` | `(6,0,0)` | `(-2.3,0,1.4)` → `(2.3,0,1.4)` |

- `PONTO_PORTA_TIO`: `(3.0, 0, 0)` → **`(2.5, 0, 0)`**
- `PONTO_PORTA_GAROTINHA`: `(2.8, 0, 0.5)` → **`(2.3, 0, 0.5)`**
- `PONTO_PERTO_CADEIRA_TIO` e `PONTO_CADEIRA_GAROTINHA`: iguais ✅

**`scripts/comodo_vizinho.gd`** — ocupa `X ∈ [+3.6, +10.0]` → **`[+3.1, +9.5]`**. O Z tem que
continuar batendo com o do quarto, senão abre fresta de luz entre os cômodos (já está documentado).

**`scripts/cenario_externo.gd`** — a regra "nenhuma árvore em `Z ∈ [−2, +2]` a oeste" existe porque
o sol vem do oeste na horizontal e a copa picotava a mancha de luz no chão. Com a janela em Z = −1,
a faixa proibida vira **`Z ∈ [−3, +1]`**.

**Conferir depois:** `LuzJanela.area_range` (7,0 continua cobrindo os 5,9 m até a parede leste ✅) e
`omni_range` da lâmpada contra o canto de baixo mais distante (√(9+5,5+9) ≈ 4,9 m ✅).

### 6.7 Opcional — pé-direito de 3,0 pra 2,6 m

Não é necessário pra resolver a queixa, mas resolve duas outras coisas:

- Parede de 6 m de largura com 3 m de altura é 2:1, proporção de salão. **2,6 m é a altura
  residencial padrão** e faz o cômodo ler como quarto de casa
- **A Fase E fica honesta:** um homem de 1,8 m com rolo alcança ~2,3 m; com o banquinho que a Fase E
  já prevê, chega a 2,6 m sem esforço. Com teto de 3,0 m ele precisaria de escada de verdade — e
  "sem escada" é um limite de escopo explícito no `PLANO-OVERHAUL-TINTA.md`

Custo: mexe em mais lugares (altura das 9 peças, `eixo_v` das 4 varreduras, `altura` das máscaras,
Y da janela, Y da lâmpada, teto, moldura). **Recomendo fazer junto ou não fazer** — mudar a
proporção do quarto duas vezes custa dois re-bakes de `LightmapGI`.

**Não foi feito na G6.** O pé-direito continua em 3,0 m. A janela do momento pra decidir isso é
**antes da Fase E e antes de assar o `LightmapGI`** — depois disso o custo triplica.

---

### 6.8 O que a G6 entregou de fato — 03/08/2026

Todos os arquivos da lista fechada de 6.6 foram alterados, mais os quatro de 7.2/7.3. Medido em
runtime, com o jogo aberto:

| Parede | Área | Máscara | Distância da câmera |
|---|---|---|---|
| Leste | 18,0 m² | 876 × 438 | 3,00 m |
| Norte | 18,0 m² | 876 × 438 | 3,00 m |
| Oeste | 18,0 m² | 876 × 438 | 3,00 m |
| Sul | 18,0 m² | 876 × 438 | 3,00 m |

Câmera da cadeira em (0,00 · 1,20 · −1,00). As quatro distâncias iguais são o ponto inteiro da fase:
é o que faz "girar 90° quatro vezes" dar enquadramentos equivalentes (aceite 8).

**Fresta da porta — resolvida, e não do jeito previsto.** 7.2 propunha estreitar a folha. O que
resolveu foi o **batente do topo**: ele passou a ter 0,11 m de altura, centrado em y = 2,115, então
cobre a folga entre o topo da folha (2,075) e o topo do vão (2,10) **por fora**, sem depender de
tolerância de milímetro. A folha foi de 0,95 pra 0,97 de largura junto, por segurança lateral.
Fotografada de esguelha (o caso difícil — de frente a verga esconde sozinha) não há linha clara.

**Armadilha achada no caminho:** o teste de porta fechada precisa **forçar o fechamento**. A cutscene
de abertura roda no `_ready` do ciclo, então qualquer captura ingênua fotografa a porta aberta:

```gdscript
var pivo = porta.get_node("PivoFolha")
pivo.rotation_degrees.y = 0.0
porta.set("_aberta", false)
```

**Duas molduras viraram uma.** `props_quarto.gd::_moldura_porta` foi apagada. Ficou a de
`porta.gd::_criar_batentes`, porque é ela que conhece `LARGURA_FOLHA` e `ALTURA_FOLHA` e por isso
consegue dimensionar o batente pra fechar a fresta. A porta virou uma cena autocontida.

**O que não foi feito:** o pé-direito (6.7) e o `LightmapGI`. O bake fica pra depois de a Fase E
parar de mexer em geometria — mas a **geometria do quarto está travada a partir daqui**, que era a
razão de G6 vir primeiro na ordem.

---

## 7. Apresentação — nitidez, fresta da porta e tamanho da janela

Três coisas que não são sobre a tinta, mas que são a primeira impressão do jogo. Entram aqui porque
duas delas se encostam na parte 6: a fresta da porta se conserta junto com a porta andando meio metro
(6.6), e o serrilhamento tem tudo a ver com a resolução em que o jogo abre.

### 7.1 Serrilhamento — o que está ligado, e o que MSAA não resolve

Hoje o `project.godot` tem **uma linha só** de anti-aliasing:

```ini
[rendering]
anti_aliasing/quality/msaa_3d=2      ; 0=off, 1=2×, 2=4×, 3=8×  → está em 4×
```

Nenhuma outra opção de AA foi definida, então todas estão no padrão (desligadas). E MSAA 4× está
correto pro que ele faz — **mas ele só suaviza silhueta de geometria.** Ele amostra *cobertura*, não
*sombreamento*. Tudo que serrilha por causa de brilho ou de shader passa direto por ele, e é
justamente aí que este jogo tem problema:

**(a) Brilho especular em geometria fininha.** O quarto é feito de caixas pequenas vistas de raspão:

| Peça | Dimensão crítica | Onde está |
|---|---|---|
| Frestas do assoalho | **1,2 cm** | `inicializar_quarto.gd::_criar_assoalho_tabuas` |
| Barras da cruz da janela | 3,5 cm | `props_quarto.gd::_moldura_janela` |
| Barras das almofadas da porta | 3,5 cm | `porta.gd::_criar_almofadas` |
| Ripas do encosto da cadeira | 3,0 cm | `inicializar_quarto.gd::_criar_cadeira` |
| Maçaneta | haste de 2,8 cm, `metallic 0.9` / `roughness 0.35` | `porta.gd::_criar_macaneta` |

Uma fresta de 1,2 cm a 3 m de distância ocupa uma fração de pixel em 1152×648. MSAA suaviza a borda
dela; o que cintila é o **realce especular** aparecendo e sumindo entre frames conforme a câmera se
move. Isso é a fonte nº 1 de "sujeira" na imagem aqui.

**(b) O próprio shader da tinta.** Duas coisas:

- O lap mark faz **diferença finita de textura por pixel** (`textureSize` + 2 samples deslocados).
  Derivada de textura por pixel é gerador clássico de aliasing — e ela multiplica um `smoothstep`
  estreito, que amplifica qualquer variação de um texel
- A máscara tem 146 px/m. Na parede norte (7 m) vista de 3 m em 1152×648, o campo de visão cobre
  ~4,6 m em 1152 pixels → **~250 px de tela por metro**. Texel da máscara ≈ 0,6 pixel de tela: está
  **acima da frequência de Nyquist**, e o `filter_linear` sem mipmap não tem como filtrar isso.
  É daí que sai o cintilar na marca do rolo e o moiré nas faixas de 17 cm

**(c) Banding — não é serrilhamento, mas é o mesmo problema de "imagem suja".** A parede é um
gradiente lento de uma cor só ocupando meia tela, mudando ~0,5 valor de RGB por segundo. É o pior
caso possível pra quantização de 8 bits: aparecem faixas horizontais de cor chapada. Num jogo cujo
assunto **é** esse gradiente, isso importa mais aqui do que na maioria dos jogos.

**Configurações propostas** (todas em `project.godot`, mas mexer pelo editor — o cabeçalho do próprio
arquivo avisa que os parâmetros não são todos óbvios):

| Setting | Hoje | Proposto | Resolve |
|---|---|---|---|
| `rendering/anti_aliasing/quality/msaa_3d` | 2 (4×) | **3 (8×)** | silhueta — o que já funciona, melhor |
| `rendering/anti_aliasing/quality/use_debanding` | false | **true** | (c), e é o mais barato da lista |
| `rendering/scaling_3d/scale` | 1.0 | **1.5** | (a) e (b) — supersampling, a solução de força bruta |
| `rendering/scaling_3d/mode` | 0 (bilinear) | 0 ✅ | FSR é pra *upscale*; aqui é downsample |
| `rendering/anti_aliasing/quality/screen_space_aa` | 0 | **1 (FXAA)** | (a) e (b), se o supersampling não bastar |
| `rendering/anti_aliasing/quality/use_taa` | false | **testar** | (a) — ver ressalva abaixo |
| `rendering/anti_aliasing/quality/msaa_2d` | 0 | 2 (4×) **só se** a UI serrilhar | menus |

**O item que sozinho resolve quase tudo é o supersampling** (`scaling_3d/scale = 1.5`): renderiza a
1,5× e reduz. Ele é o único da lista que ataca (a) e (b) na raiz, porque resolve *sombreamento*, não
só cobertura. E este jogo tem orçamento de sobra pra isso — o quarto inteiro são algumas centenas de
triângulos, quatro paredes com shader e nenhuma física ativa. ⚠️ **Escolher entre supersampling e
MSAA 8×, não somar os dois**: MSAA 8× a 2880×1620 é caro à toa. Medir os dois caminhos e ficar com o
melhor:

- **Caminho A:** `scale 1.5` + `msaa_3d 2` (4×) + debanding
- **Caminho B:** `scale 1.0` + `msaa_3d 3` (8×) + FXAA + debanding

⚠️ **Ressalva do TAA:** ele é o melhor remédio pra cintilação especular, e este jogo é o caso quase
ideal (câmera parada, movimento lento, nenhuma partícula). Mas ele acumula frames — e a única coisa
que se move rápido aqui é a **frente do rolo**, que pode borrar. Testar especificamente isso; se
borrar, cair fora e ficar com supersampling + FXAA.

**Dois consertos de shader/material que vão junto** (baratos, e atacam a causa em vez do sintoma):

- `porta.gd::_criar_macaneta`: `roughness` **0.35 → 0.45**. Latão fosco continua lendo como latão e
  o realce para de cintilar. Mesma lição que já fez o normal map do teto sair
- `tinta_secando.gdshader`: atenuar `forca_marca` e o lap mark com a distância, usando `fwidth(uv)`
  como medida de quantos texels cabem num pixel. Onde um pixel cobre mais de um texel, a marca do
  rolo tem que sumir — é o que um mipmap faria se `DrawableTexture2D` tivesse um. Duas linhas

### 7.2 A fresta no topo da porta — a conta, e por que há duas molduras

Não é bug de render, é geometria. Medindo (`inicializar_quarto.gd`, `porta.gd`, `props_quarto.gd`):

| Peça | Faixa em Y | Arquivo |
|---|---|---|
| Vão da porta (base de `ParedeLesteAcima`) | topo em **2,10 m** | `inicializar_quarto.gd` |
| **Folha da porta** | 0,00 → **2,05 m** | `porta.gd::_criar_folha` |
| `BatenteTopo` | 2,09 → 2,15 m | `porta.gd::_criar_batentes` |
| Verga de `_moldura_porta` (a **outra** moldura) | 2,07 → 2,13 m | `props_quarto.gd::_moldura_porta` |

**A folha tem 2,05 m e o vão tem 2,10 m: sobram 5 cm abertos no topo.** O `BatenteTopo` começa só em
2,09, então ele tapa 1 cm — e a verga da outra moldura tapa de 2,07 pra cima, mas está 8,5 cm mais
pra dentro do quarto (x = 3,375 contra x = 3,46 da folha), então ela esconde a fresta de frente e
**deixa de esconder assim que a câmera sai do eixo**. Sobram 2 a 4 cm de vão livre atravessando o
metro inteiro de largura da porta.

E do outro lado tem luz: o `ComodoVizinho` tem lâmpada de teto própria. Por isso a fresta aparece
como uma **linha clara horizontal** em cima da porta fechada — que é exatamente a queixa.

Junto aparece a segunda coisa: **existem duas molduras de porta**, uma em `porta.gd::_criar_batentes`
(x ≈ 3,39–3,53) e outra em `props_quarto.gd::_moldura_porta` (x ≈ 3,375), com cores quase idênticas
(`0.35,0.22,0.13` × `0.38,0.24,0.14`). Hoje elas se sobrepõem e leem como uma moldura só meio grossa;
é geometria duplicada esperando pra brigar por z.

**Correção proposta:**

- `porta.gd::_criar_folha` — altura **2,05 → 2,075**, `position.y` **1,025 → 1,0495**.
  Folha em Y ∈ [0,012 · 2,087]: **1,2 cm de folga embaixo** (porta de verdade tem, é a passagem de ar)
  e **1,3 cm no topo**, que é o que uma dobradiça pede
- `porta.gd::_criar_batentes` — `BatenteTopo` altura **0,06 → 0,11** e `position.y` **2,12 → 2,115**.
  Passa a cobrir Y ∈ [2,06 · 2,17], montado a cavalo na verga: sobrepõe o topo da folha em 2,7 cm e
  a parede de cima em 7 cm. **Sem fresta possível**
- **Apagar `_moldura_porta` de `props_quarto.gd`** e tirar a chamada de `PropsQuarto.criar`. A
  moldura fica só em `porta.gd`, que é quem tem as medidas da folha — cena de porta autocontida
- Como a moldura restante fica mais rente à parede (sai 1 cm pra dentro do quarto, contra 2,5 cm da
  que sai), **engrossar os batentes de `0.14` pra `0.20` em X** pra a moldura continuar lendo como
  moldura. Valor a acertar no olho
- ⚠️ Fazer **junto** com o quarto de 6 × 6 (6.6): a `Porta` anda de x 3,46 pra 2,96 e `LIMITE_X` de
  3,4 pra 2,9. São os mesmos números, mexidos duas vezes se forem em rodadas separadas

**Verificação depois:** fechar a porta e olhar de baixo, do assento da cadeira (y = 1,2), e de
esguelha dos dois lados. Se ainda houver linha clara, o problema restante é a folga lateral (a folha
tem 0,95 m num vão de 1,00 m — 2,5 cm de cada lado, cobertos por 0,5 cm de sobreposição do batente,
que é pouco). Nesse caso, largura da folha **0,95 → 0,97**.

### 7.3 Tamanho da tela — o jogo abre a 1152×648 porque ninguém disse outra coisa

O `project.godot` **não define tamanho de janela**:

```ini
[display]
window/stretch/mode="canvas_items"
window/stretch/aspect="expand"
```

Só isso. Sem `window/size/viewport_width` / `viewport_height`, o Godot usa o padrão dele, que é
exatamente **1152×648**. Não é limite de nada — é o valor de fábrica que nunca foi trocado.

Detalhe importante do modo `canvas_items`: **o 3D já renderiza na resolução real da janela**, não na
resolução-base. A base só serve pra escalar a UI. Ou seja, janela maior = 3D mais nítido de verdade,
e isso por si só melhora bastante a percepção de serrilhamento de 7.1 (hoje a imagem é pequena *e*
serrilhada ao mesmo tempo).

**Opção A — mínima, recomendada agora:**

| Setting | Hoje | Proposto |
|---|---|---|
| `display/window/size/viewport_width` | ausente (1152) | **1152** — manter |
| `display/window/size/viewport_height` | ausente (648) | **648** — manter |
| `display/window/size/window_width_override` | ausente | **1600** |
| `display/window/size/window_height_override` | ausente | **900** |
| `display/window/size/resizable` | true (padrão) | true ✅ |

A janela abre a 1600×900 e continua redimensionável, a base de UI não muda, **e nada no
`theme_principal.tres` precisa ser revisto**. É o conserto de dois campos.

**Opção B — quando a Etapa 2 chegar:** subir a base pra **1920×1080**, que é o padrão de quem
publica na Steam e faz "1 unidade de UI = 1 pixel a 1080p". ⚠️ **Isso obriga a revisar os tamanhos de
fonte do `theme_principal.tres`** (multiplicar por ~1,6), porque com `canvas_items` a UI é desenhada
no espaço da base e escalada pro tamanho da janela: subindo a base sem mexer na fonte, o texto
encolhe na tela. Não vale fazer agora — o menu ainda vai mudar na Etapa 2 (logo, créditos, título).

**No editor:** rodar o jogo usa as configurações do projeto acima. Mas existe também
*Editor Settings → Run → Window Placement*, que é **por máquina e não versionado** — se depois de
mudar o projeto a janela continuar abrindo pequena, é lá que tem um override sobrando.

**E as Opções ganham o que faltava.** `opcoes.gd` hoje tem volume, tela cheia e idioma; tela cheia
usa `WINDOW_MODE_FULLSCREEN`, que no Godot 4 é *fullscreen sem borda* — a escolha certa pra um jogo
contemplativo, dá alt-tab sem engasgo. Falta:

- `[ ]` **Seletor de resolução** em janela (1280×720 / 1600×900 / 1920×1080), via
  `DisplayServer.window_set_size`, persistido no `config.cfg` junto dos outros
- `[ ]` Corrigir a volta da tela cheia: `_aplicar_tela_cheia()` hoje só troca o modo e **não devolve
  tamanho nenhum** ao voltar pra janela — ela volta pro que estiver na memória do sistema
- `[ ]` **Qualidade gráfica**, se o supersampling de 7.1 pesar em máquina fraca: um seletor de
  `scaling_3d/scale` (`Viewport.scaling_3d_scale` em runtime) com três degraus. Só se precisar —
  a disciplina do projeto é não adicionar opção por adicionar

### 7.4 Ordem

- `[x]` **G5 — Nitidez.** ✅ **feito em 03/08/2026.** Configurações de 7.1 medidas de verdade, mais
  os dois consertos de material/shader. Ver 7.5 — **o Caminho A do plano estava com o número errado**
- `[x]` **G6 — Porta e janela do jogo.** ✅ **feito em 03/08/2026.** Fresta (7.2, **junto com o
  quarto 6 × 6**) e tamanho de tela Opção A (7.3). Ver 6.8 pro que foi medido depois

---

### 7.5 O que a G5 entregou de fato — 03/08/2026

**Configuração final** (`project.godot`, seção `[rendering]`):

```ini
scaling_3d/scale=2.0                      ; NAO 1.5 — ver abaixo
anti_aliasing/quality/msaa_3d=2           ; 4x
anti_aliasing/quality/use_debanding=true
; FXAA, TAA e msaa_2d ficaram de fora, os tres medidos e reprovados
```

Mais `porta.gd::_criar_macaneta` com `roughness` 0,35 → 0,45 e a atenuação por `fwidth` no
`tinta_secando.gdshader`, os dois consertos que 7.1 pedia.

#### Como foi medido — e por que a primeira medição foi jogada fora

A primeira tentativa foi girar a câmera devagar e olhar a **segunda diferença temporal**
(`|I(n−1) − 2·I(n) + I(n+1)|`), que é o que cintilação faz com um sinal. **Não convergiu:** o mesmo
teste deu 3,96 e depois 5,29 pra configuração idêntica, e teve um outlier de 14,7. Pior, ela tem um
viés que invalida a comparação: **imagem mais nítida tem segunda diferença maior sob movimento sem
estar cintilando**, então a métrica premiava quem borra mais — foi por isso que FXAA "ganhou" nela.

O que funcionou é como AA se mede de verdade: renderizar a mesma pose com **supersampling 3× + MSAA
8×** (referência praticamente sem aliasing) e medir o erro de cada candidata contra ela. Aliasing
**é** a diferença pra imagem certa. Sem movimento, sem ruído de medição, e reprodutível. Três poses:
olho da cadeira, assoalho de raspão (as frestas de 1,2 cm no ângulo mais cruel) e parede pintada de
perto.

| Configuração | Erro médio | Pior pixel | Custo |
|---|---|---|---|
| Antes da G5 (MSAA 4×, mais nada) | 0,173 | 178 | 0,89 ms |
| Caminho A do plano — 1,5× + MSAA 4× | 0,143 | 127 | 1,25 ms |
| **2,0× + MSAA 4×** ✅ | **0,034** | 126 | 3,47 ms |
| Caminho B — MSAA 8× + FXAA | 0,241 | 232 | 0,86 ms |
| MSAA 8× sozinho | 0,148 | 126 | — |

Erro em níveis de 255. Custo medido a 1600 × 900 numa RTX 5070.

#### ⚠️ O plano pedia `scale = 1.5` e esse número está errado

**1,5× quase não serve** — 0,143 contra 0,173 de não fazer nada, uma melhora de 17% pra 40% de custo
a mais. **2,0× dá 0,034**, quatro vezes melhor.

O motivo é o filtro, não a quantidade de amostras: **o downsample do Godot é bilinear**. Em 2,0× os
quatro taps do bilinear caem simétricos entre os texels de origem, e ele vira uma **média de caixa
2 × 2 exata** — supersampling de verdade. Em 1,5× as amostras não alinham com a grade e sobra
aliasing, com o agravante de a fase do erro mudar conforme a câmera anda.

**Consequência prática: não trocar 2,0 por um valor "intermediário" pra economizar.** 1,75 não dá 87%
do benefício, dá quase nada. A escala é uma escolha binária aqui: 1,0 ou 2,0.

#### FXAA e TAA foram reprovados, não esquecidos

- **FXAA piorou a imagem** — erro 0,241, **pior que não fazer nada** (0,173), e o pior pixel saltou
  pra 232. Ele borra pra longe da verdade em vez de resolver detalhe: nas capturas, a linha fina da
  almofada da porta continuou pontilhada com FXAA e virou linha contínua com supersampling
- **TAA fantasmou e apagou a marca do rolo na parede.** A ressalva de 7.1 era sobre borrar a frente
  do rolo; o problema real foi maior — ele alisou a variação da parede inteira, que é **o assunto do
  jogo**. Mais um retângulo claro de ghosting no canto ao mover a câmera. Fora
- **MSAA 4× continua se pagando** mesmo por cima do supersampling: 0,105 sem ele contra 0,034 com,
  por 0,32 ms (10% do quadro). Não subir pra 8×: 4× já empata com a referência
- **`msaa_2d` fica em 0.** A UI do menu foi capturada e não serrilha — texto e cantos arredondados
  saem limpos, o 2D do Godot já resolve isso sozinho

#### Debanding — o aceite 13

Medido contando **linhas chapadas** numa faixa de 600 px da parede (linha inteira com um único valor
de 8 bits = faixa de banding): **236 de 600 linhas chapadas (39%) antes, 0 depois.** Contar tons
distintos não serve como medida — dá 15 nos dois casos, porque o dither espalha os pixels entre dois
níveis sem criar níveis novos.

#### Ressalva pra Etapa 3 (Steam)

`scale = 2.0` renderiza a **3200 × 1800**. Aqui sobra folga (288 fps), mas numa GPU integrada isso
pesa. **Antes da Steam, expor a escala como opção de qualidade** em `Opções` — é uma propriedade de
`Viewport` (`scaling_3d_scale`), trocável em runtime sem reiniciar. Não foi feito agora porque a
disciplina do projeto é não adicionar opção por adicionar (7.3).

---

## 8. Critérios de aceite

Testáveis, não subjetivos. Somam-se aos que já estão no `PLANO-OVERHAUL-TINTA.md` seção 7.

1. **A razão entre o `duracao_local` máximo e o mínimo de uma parede é ≥ 1,5.** Sem isso, nada do
   resto importa (é o teste barato descrito em G1)
2. Pausar no meio de uma demão em qualquer modo: a parede está **visivelmente manchada**, com
   fronteira irregular, não com gradiente uniforme
3. Pausar no fim: a mancha **sumiu** — a parede seca é uniforme
4. No modo Realista, dois screenshots com 20 min de diferença mostram **regiões diferentes** secas,
   não só a mesma parede um pouco mais escura
5. Movendo só a câmera (sem esperar), dá pra dizer **onde ainda está molhado** pelo brilho rasante
6. A 2ª demão cobre falha da 1ª, e a falha **só some quando o rolo passa por cima** — não no
   instante em que a demão começa
7. `secagem_concluida` dispara com no máximo **2% de folga** depois de a cor parar de mudar
8. Do centro do quarto, girar 90° quatro vezes dá **enquadramentos equivalentes** e brilho de parede
   comparável (medir RGB no mesmo ponto relativo das 4 paredes: variação ≤ 10%)
9. Zero warnings no build (convenção do projeto)
10. 60 fps com as 4 máscaras ativas e as texturas de mancha carregadas
11. **Porta fechada, vista do assento da cadeira e de esguelha dos dois lados: nenhuma linha clara
    no topo.** O cômodo vizinho tem lâmpada própria, então qualquer fresta aparece
12. **Girando a câmera devagar, nada cintila**: nem as frestas do assoalho, nem a maçaneta, nem a
    marca do rolo na parede
13. Parede no meio de uma demão, tela cheia: **nenhuma faixa de banding** no gradiente
14. O jogo **abre numa janela de 1600×900** e ela é redimensionável; a tela cheia liga e desliga
    devolvendo o mesmo tamanho de antes

---

## 9. O que NÃO fazer

Lista curta e explícita, porque a tentação em cada um destes é grande e todos brigam com a premissa.

- **Não adicionar partícula, vapor, gotejamento nem escorrido.** Tinta látex bem aplicada não
  escorre, e efeito de partícula num jogo cuja proposta é imobilidade vira ruído
- **Não somar ruído de shader "pra dar vida".** Já foi feito e já foi revertido (o `fbm` solto que a
  Fase B tirou, os normal maps do teto e das paredes). Toda variação proposta aqui é **derivada de
  algo** — espessura real, substrato, posição da janela. Se um dia parecer que falta variação, a
  resposta é olhar de onde ela **deveria** vir, não somar ruído
- **Não trazer o ciclo de dia e noite de volta**, nem "só uma luzinha mudando". A decisão de
  31/07/2026 está certa e vale em dobro agora: com a secagem virando um campo espacial, luz
  variando por baixo destruiria a leitura dela
- **Não colocar barra de progresso, porcentagem ou HUD de secagem.** O timer opcional já decidido
  (desligado por padrão) é o teto. A "última mancha a secar" de 3.1 é o indicador diegético, e é o
  suficiente
- **Não deixar `roughness` de molhado abaixo de ~0,35.** Já foi testado e revertido: reflete o céu
  procedural e quebra a parede em blocos. O ganho vai no `SPECULAR` rasante
- **Não fazer a mancha ser permanente.** Ela precisa nascer e morrer (`k_mancha`), senão a parede
  seca fica suja e a direção low-poly (superfície chapada, cor limpa) vai pro lixo
- **Não fazer o tempo de pintura variar por modo.** A duração vem da coreografia e é a mesma nos
  três; o modo controla só a secagem, como sempre controlou (3.9). Esticar a pintura no Realista põe
  o tio em câmera lenta
- **Não "consertar" o lap mark forçando ele a aparecer nos três modos.** É correto que ele só surja
  no Rápido — tinta que leva 2 h pra secar não faz lap mark (3.9)
- **Não usar `stretch/mode = "viewport"`** pra "melhorar performance". Ele congela o 3D na
  resolução-base e faz upscale — o oposto do que 7.1 e 7.3 querem. O modo `canvas_items` atual está
  certo
- **Não resolver serrilhamento com sharpen nem com blur de tela cheia.** Ambos existem no Godot e
  ambos trocam um artefato por outro; o que este jogo precisa é de amostras, não de filtro
- **Não tapar a fresta da porta com uma peça nova por cima.** Já há duas molduras sobrepostas
  (7.2) — uma terceira camada é o caminho pra briga de z. A folha e o batente têm que ter as medidas
  certas

---

## 10. Referências

Fontes já usadas no `PLANO-OVERHAUL-TINTA.md` seção 9 continuam valendo — em especial as três sobre
látex de verdade, que são a base da tabela de fases e da frase "splotchy and uneven" que este
documento trata como especificação.

Vale reler antes de implementar G1:

- [Lapping — Rodda Paint](https://www.roddapaint.com/problem-solver/lapping-interior/) — o critério
  físico do lap mark, que é o que 3.8 transforma em fórmula
- [Why is my paint streaky after drying — Mark's Painting](https://www.markspainting.com/blog/why-paint-streaky-after-drying)
  — as causas da mancha: espessura, absorção do substrato, corrente de ar. São exatamente os quatro
  termos do campo de 3.1
- [Interior paint drying time guide](https://facadecolorizer.com/us/blog/interior-paint-drying-time-guide-2026)
  — os tempos reais, úteis pra conferir se a duração da coreografia e a secagem dos 3 modos fecham
  entre si (3.9)

Novas, específicas desta rodada:

- [LightmapGI — docs Godot](https://docs.godotengine.org/en/stable/tutorials/3d/global_illumination/using_lightmap_gi.html)
  — em particular os modos de GI por objeto (`STATIC` × `DYNAMIC`), que é o que 6.5 depende
- [FastNoiseLite — class ref](https://docs.godotengine.org/en/4.7/classes/class_fastnoiselite.html)
  — a mancha de substrato de 3.1(b)
