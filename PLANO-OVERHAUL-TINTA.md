# Plano de Overhaul — A Tinta Secando

Documento de planejamento da rodada "overhaul do miolo": parede, tinta, secagem e animação do tio.
É o que as pessoas vão ficar olhando, então é onde vale gastar o esforço.

Complementa o `PROJETO.md` (que continua sendo o documento-mãe). Quando este plano fechar, o que
sobreviver vira parágrafo na seção 3 do `PROJETO.md` e este arquivo pode morrer.

> ⚠️ **Leia isto antes de confiar nas Fases B e C como "concluídas" (02/08/2026).**
> A arquitetura da Fase B está certa e é a base de tudo, mas uma auditoria dos números mostrou que
> **três dos quatro recursos que ela existia pra permitir estão inertes**: falha de cobertura (a
> carga do rolo nunca desce de 0,82, e o limiar do shader satura em 0,45), lap mark (o salto medido
> é 0,023 s contra um limiar de 0,35 s) e a mancha de espessura (0,7% de variação no tempo de
> secagem — a parede inteira seca dentro de 0,4 segundo). Além disso, `ESPESSURA_TIPICA` está ~7×
> alta e produz 18% de espera morta por demão em todos os modos.
> O conserto é **calibração e um canal de textura**, não reescrita — e está em
> **`PLANO-SECAGEM-E-QUARTO.md`**, que é a **Fase G** e não depende de D nem de E.
> Os critérios de aceite 2 e 5 da seção 7 deste documento **não são alcançáveis** sem ela.

**Decisões já tomadas com o Caio (30/07/2026):**

1. Direção de arte: **estética low-poly assumida** — poucos polígonos de propósito, facetado como
   escolha, cores chapadas, luz suave
2. Superfície pintável: **só as 4 paredes, do rodapé ao alto** — "teto" é o topo da parede, "chão"
   é o rodapé
3. Rig: **refazer no Blender + IK nativa do Godot**
4. Ferramenta: **rolo + bandeja + molhar a tinta + banquinho pra alcançar o alto**

---

## 1. Diagnóstico — por que hoje está amador

Não é falta de polimento. São duas decisões estruturais que limitam o teto do que dá pra alcançar.

### 1.1 A tinta é uma função da posição, não um histórico

`shaders/tinta_secando.gdshader`, linha 99:

```glsl
float u = clamp((dot(pos_mundo, normalize(eixo_varredura)) - inicio_varredura) / extensao, 0.0, 1.0);
float t_pintado = u * duracao_varredura;
```

Cada pixel da parede pergunta "onde eu estou no eixo?" e deduz sozinho quando foi pintado. O ruído
em duas escalas (linhas 106-107) torce a borda pra ela não ler como régua — e resolve *parcialmente*,
tanto que já está documentado como aprendizado no `PROJETO.md`. Mas é maquiagem sobre um problema
estrutural: **a frente de pintura só pode ser uma linha atravessando a parede numa direção**.

O que é impossível de representar nesse modelo, por construção:

- pincelada diagonal, em W, em zigue-zague
- ele pintar o alto de um trecho, descer, e depois voltar pro rodapé do mesmo trecho
- falha de cobertura (lugar onde passou de leve e a cor antiga transparece)
- sobreposição (lugar onde passou duas vezes, mais grosso, seca depois)
- lap mark (a linha que aparece quando pincelada nova encosta em tinta que já começou a secar)
- a 2ª demão de fato cobrir as falhas da 1ª — hoje as 3 demãos só mudam a saturação

Esse último ponto é o mais grave pro jogo: **o loop de 3 demãos não tem consequência visual real**.

### 1.2 O braço tem 1 osso, sem cotovelo

`PROJETO.md`, Fase 1.2: rig de 7 ossos, "sem cotovelo/pulso (braço é 1 osso só)". Os clipes são
`andar` (pernas, ~25° alternado) e `pintar_braco` (braço direito, -0.9 a 0.1 rad).

Sem cotovelo, punho, joelho ou coluna, o tio literalmente **não tem articulação pra esticar pro alto
nem pra agachar**. Ele só consegue girar o ombro. Nenhuma quantidade de keyframe conserta isso.

E `pintar_varrendo()` toca os dois clipes em loop com timer fixo (`DURACAO_PINCELADA = 1.1666667`)
enquanto um Tween arrasta o corpo em linha reta a velocidade constante. O braço balança, o corpo
desliza, a tinta aparece — três coisas em paralelo que não conversam. É por isso que parece fake:
não há relação causal entre o braço e a tinta, só sincronia de duração.

### 1.3 A parede finge textura que a estética não pede

`inicializar_quarto.gd` monta as paredes com `BoxMesh` + triplanar noise + normal map procedural
(reboco fino, força 0.6). O shader ainda soma um `NORMAL_MAP` de "relevo de rolo" por diferença
finita (linhas 141-146). São três camadas de micro-detalhe fake numa direção de arte que decidiu ser
low-poly. Isso briga: low-poly quer superfície limpa e luz boa, não bump procedural.

O `PROJETO.md` já registra que normal map no teto virou rabisco e teve que sair. Mesma causa.

### 1.4 A boa notícia

As duas peças que faltavam chegaram na engine **depois** que este projeto foi arquitetado:

- **Godot 4.6 trouxe IK de volta pro 3D**: `TwoBoneIK3D`, `FABRIK3D`, `CCDIK3D`, `SplineIK3D`, mais
  `LookAtModifier3D` e `LimitAngularVelocityModifier3D` — todos como `SkeletonModifier3D` empilháveis
  ([anúncio oficial](https://godotengine.org/article/inverse-kinematics-returns-to-godot-4-6/))
- **Godot 4.7 tem `DrawableTexture2D`**: desenhar numa textura em runtime sem a cerimônia de
  `SubViewport` ([docs](https://docs.godotengine.org/en/4.7/tutorials/rendering/drawable_textures.html),
  [class ref](https://docs.godotengine.org/en/4.7/classes/class_drawabletexture2d.html))

O projeto já está no 4.7. Dá pra usar os dois hoje.

---

## 2. A ideia central — trajeto do rolo como fonte única da verdade

Uma coisa só governa tudo: **a curva que o rolo percorre**.

```
                    Trajeto do rolo
                (uma sequência de pontos
                 na superfície da parede)
                          │
            ┌─────────────┴─────────────┐
            ▼                           ▼
    Alvo de IK da mão            Carimbo na máscara
    (Node3D que o braço          (blit do rastro do
     persegue via TwoBoneIK3D)    rolo numa textura)
            │                           │
            ▼                           ▼
    O corpo obedece:             Textura RGBA por parede:
    agacha, estica, sobe         R cobertura, G instante,
    no banquinho, inclina        B espessura, A carga
            │                           │
            └─────────────┬─────────────┘
                          ▼
              Shader lê a máscara em vez
              de calcular uma varredura
                          ▼
              A tinta seca exatamente
              onde e quando ele pintou
```

O ganho não é só visual. É que **a coerência deixa de ser responsabilidade de quem escreve o código**.
Hoje, se alguém mudar `duracao_pintura_segundos` sem mudar o Tween, o rolo descola do desenho. Com
uma fonte única, descolar vira impossível por construção.

---

## 3. Spec da máscara de tinta

### 3.1 Formato

> ⚠️ **A Fase A mudou isto.** Os 4 canais abaixo continuam sendo o modelo mental certo, mas não
> cabem numa textura só: cada par quer um modo de blend diferente. Viraram **duas texturas RG por
> parede** — ver 3.7 pro layout final e o porquê.

Uma textura por parede, a **146 px/m** — resolução de sobra pra ver a marca do rolo (que tem 23 cm),
e ~7 MB no total, irrelevante.

⚠️ **O "1024×448 padronizado" que este parágrafo propunha não foi implementado assim.** O código
(`mascara_tinta.gd::PIXELS_POR_METRO`) calcula o tamanho **por parede**, então hoje as paredes de
7 m ficam em 1022 × 438 e as de 6 m em 876 × 438. Isso deixa de ser uma diferença quando o quarto
virar 6 × 6 (Fase G6): as quatro passam a ser 876 × 438 iguais.

| Canal | Guarda | Pra quê |
|---|---|---|
| **R** | Cobertura, 0-1 | Quanto de tinta chegou aqui. `< 1` = a cor de baixo transparece. É isso que faz a 2ª demão ter função |
| **G** | Instante da pincelada, normalizado na demão | Quando o rolo passou aqui. Substitui o `t_pintado` calculado do shader atual |
| **B** | Espessura acumulada (nº de passadas) | Onde passou 2× fica mais grosso: mais brilhoso, seca depois, e é o que gera a mancha de secagem |
| **A** | Carga do rolo no momento | Rolo cheio deposita liso; rolo quase seco deixa falha e estria. Livre pra ser cortado se não render |

**8 bits no G bastam:** uma demão de parede leva dezenas de segundos, 256 passos dão resolução de
~0,1 s. Não confundir com o tempo de secagem (que pode ser 2h no modo Realista) — esse continua
sendo um `float` uniform no shader, não vai pra textura.

### 3.2 O carimbo

O rolo real tem ~23 cm de largura e uma faixa de contato de ~5 cm. Em 146 px/m isso dá **34×7 px**.
O carimbo é uma textura pequena (64×32) com:

- borda macia nos dois eixos (tinta de rolo não tem contorno)
- fibras longitudinais leves (a marca característica do rolo)
- queda de opacidade nas pontas (as bordas do rolo depositam menos)

A cada frame de física, interpolar entre a posição anterior e a atual do rolo e carimbar N vezes ao
longo do segmento — senão em velocidade alta o rastro sai pontilhado.

### 3.3 Como o shader lê

Substitui o bloco de varredura inteiro (linhas 97-124 do shader atual). Com o layout de duas
texturas de 3.7, são dois samplers em vez de um:

```glsl
vec2 acum = texture(mascara_acumulada, UV).rg;  // R cobertura, G espessura
vec2 rec  = texture(mascara_recente, UV).rg;    // R instante,  G carga

float cobertura  = acum.r;
float espessura  = acum.g;
float instante   = rec.r * janela_demao;     // segundos desde o início da demão

float dt = tempo_decorrido - instante;
// camada mais grossa demora mais pra secar — é daqui que sai a mancha
float duracao_local = duracao_secagem * (1.0 + espessura * 0.35);
float fracao = clamp(dt / duracao_local, 0.0, 1.0);
```

E a cor:

```glsl
vec3 cor_nova = mix(cor_molhada.rgb, cor_seca.rgb, curva_secagem(fracao));
ALBEDO = mix(cor_anterior.rgb, cor_nova, cobertura);
```

Repare que `cobertura` entrou onde antes estava `pintado` (um smoothstep de borda). A diferença é
tudo: agora "meio pintado" não é uma borda de transição, é **falha de cobertura de verdade**, que
persiste depois de secar e só some quando a próxima demão passa por cima.

### 3.4 As fases da secagem

> ⚠️ **CORREÇÃO IMPORTANTE (02/08/2026) — esta seção estava com o sentido da cor INVERTIDO.**
> O texto original dizia "látex seca mais claro que molhado" e mandava manter o código como estava.
> **Está errado, e foi corrigido no código:** o ligante da látex é branco leitoso enquanto tem água
> e fica transparente ao secar, então **tinta seca MAIS ESCURA e MAIS SATURADA**. Molhada é mais
> clara e leitosa. O que engana é o brilho da superfície molhada.
>
> A linha da tabela abaixo que diz "Molhada → cor mais escura e saturada" também está invertida.
> A implementação correta está em `cor_tinta.gd` (`COR_LEITOSA` + `VEU_MOLHADO`) e no cabeçalho
> dele, que documenta a pesquisa. **Não reverter.**
>
> As **frações da tabela continuam válidas** e são a referência das curvas do shader.

Da pesquisa sobre tinta látex de verdade
([Rodda](https://www.roddapaint.com/problem-solver/lapping-interior/),
[Mark's Painting](https://www.markspainting.com/blog/why-paint-streaky-after-drying),
[SISU](https://sisupainting.com/tips-for-achieving-a-smooth-finish-with-latex-paint/)):

| Fração | Fase | O que muda |
|---|---|---|
| 0 – 0.03 | Molhada | Cor mais escura e saturada, brilho alto, borda viva com bead na parte de baixo do traço |
| 0.03 – 0.25 | Flash off | **O brilho some primeiro, antes da cor mudar.** Detalhe que quase ninguém acerta |
| 0.25 – 0.60 | Toque seco | Cor clareia; fica **manchada e desigual** — a camada fina seca antes da grossa |
| 0.60 – 1.00 | Seca | Uniformiza, fosco, marca do rolo assentada |
| depois | Cura | Fora do escopo (ou é exatamente o que o modo Realista representa) |

Dois pontos importantes:

- ~~**Látex seca mais claro que molhado.**~~ **INVERTIDO — ver o aviso no topo desta seção.** Látex
  seca **mais escuro e mais saturado**; molhado é mais claro e leitoso. As cores citadas aqui
  (`cor_molhada` 0.18/0.38/0.72, `cor_seca` 0.38/0.58/0.88) **não existem mais**: desde 02/08/2026
  cada `.tres` tem só `cor_alvo`, e demão/molhado saem de curva em `cor_tinta.gd`.
- **A fase manchada é o ouro.** "While the paint is drying it will look splotchy and uneven" —
  isso é o que faz a secagem parecer real em vez de um crossfade.
  ⚠️ **Mas a aposta de "sai de graça da espessura" NÃO se confirmou.** Medido em 02/08/2026: a
  espessura varia entre 0,037 e 0,048 dentro de uma demão, o que dá **0,7% de diferença no tempo de
  secagem** — a parede inteira seca dentro de 0,4 segundo. E a variação que sobra é **periódica**
  (as faixas de sobreposição ficam exatamente a 17 cm), então amplificá-la daria listra, não mancha.
  A mancha precisa de mais fontes: **substrato, corrente de ar e altura**, além da espessura. É a
  **Fase G1**, em `PLANO-SECAGEM-E-QUARTO.md` §3.1.
  *(O `fbm(coord * 0.4)` citado na versão original deste parágrafo já não existe — saiu na Fase B.)*

### 3.5 Lap marks

Onde uma pincelada nova encosta em tinta que já começou a secar, fica uma linha permanente. Na
máscara isso é um gradiente do instante (canal R da textura *recente*, ver 3.7):

```glsl
float r_dx = texture(mascara_recente, UV + vec2(px, 0.0)).r - rec.r;
float r_dy = texture(mascara_recente, UV + vec2(0.0, py)).r - rec.r;
float salto = length(vec2(r_dx, r_dy)) * janela_demao;
float lap = smoothstep(limiar_lap, limiar_lap * 2.0, salto);  // sobe o brilho local
```

Quatro linhas, dois samples extras, e é fisicamente correto — a linha aparece exatamente onde ele
demorou pra voltar. Se ele pintar rápido e sobrepor direito, não aparece. Se der uma volta e voltar
tarde, aparece. É o tipo de detalhe que ninguém consegue nomear mas todo mundo sente.

### 3.6 Riscos e alternativa — ✅ resolvido na Fase A

Era a pergunta que travava tudo: `blit_rect` aceita **rotação** do carimbo? Que **modos de blend**
oferece? Ambas respondidas — rotação se faz no shader, blend é nativo (`blend_add`). Ver 3.7.

**`DrawableTexture2D` está confirmado. O plano B do `SubViewport` não é mais necessário.** Fica
como registro caso algo mude:
[splat map em runtime](https://alfredbaudisch.com/godot-engine/godot-engine-in-game-splat-map-texture-painting-dirt-removal-effect/)
([repo](https://github.com/alfredbaudisch/GodotRuntimeTextureSplatMapPainting)) e o addon
[GPU Texture Painter](https://github.com/maantho/gpu-texture-painter) (overkill pra 4 quads).

**Isso é a Fase A do plano de execução: 1 sessão descartável só pra decidir isso.**

### 3.7 A API real do `DrawableTexture2D` — resultado da Fase A

> Esta seção substitui as suposições de 3.1 e 3.6. **A documentação oficial do 4.7 está errada**
> sobre esse shader: ela descreve o bloco como `fragment()` e cita built-ins que o compilador
> rejeita. O que está aqui foi levantado por força bruta contra o compilador do 4.7.1 e testado
> rodando de verdade numa RTX 5070.

**Assinatura:**

```gdscript
setup(width, height, format, color, use_mipmaps)
blit_rect(Rect2i rect, Texture2D source, Color modulate, int mipmap, Material material)
blit_rect_multi(Rect2i rect, Array sources, Array extra_targets, Color modulate, int mipmap, Material material)
```

**O shader:**

```glsl
shader_type texture_blit;
render_mode blend_add;                       // mix | add | sub | mul | disabled

uniform sampler2D fonte : hint_blit_source0; // ...source1, source2, source3

void blit() {                                // é blit(), NÃO fragment()
    COLOR0 = vec4(...);                      // COLOR1..COLOR3 = extra_targets
}
```

| Item | Situação |
|---|---|
| Bloco | **`blit()`**. `fragment()` é aceito silenciosamente e **nunca executa** — armadilha séria de depuração |
| Entradas | `UV`, `FRAGCOORD`, `MODULATE`, `TIME` |
| Saídas | `COLOR0` a `COLOR3` (as extras vão pros `extra_targets`) |
| Rotação | **Não existe na API** — mas se faz no shader girando o `UV`. Confirmado a 45° |
| Blend | `blend_add` acumula linear (0.25 → 0.50 → 0.75); `blend_mix` faz alpha blend; `blend_disabled` sobrescreve |
| Ler o destino | **Proibido** — `ERROR: Cannot use self as a source`. Ping-pong entre duas texturas funciona |
| Multi-alvo | `blit_rect_multi` escreve em várias texturas num blit só, **mas o `render_mode` é compartilhado** |
| Custo | 0,022 ms por blit (CPU). 240 blits = 5,2 ms |

**A consequência que muda o design:** `render_mode` é por shader, não por canal — e os 4 canais de
3.1 querem blends diferentes. Cobertura e espessura querem **somar**; instante e carga querem ser
**substituídos pelo mais recente**. Numa textura RGBA só, é impossível.

Então a máscara vira **duas texturas por parede**, cada uma com seu blend:

| Textura | `render_mode` | R | G |
|---|---|---|---|
| **Acumulada** | `blend_add` | Cobertura (satura em 1) | Espessura (nº de passadas) |
| **Recente** | `blend_mix` | Instante da pincelada | Carga do rolo |

Na acumulada o alfa do carimbo vira quantidade depositada; na recente vira peso da substituição —
onde o rolo passou forte, o instante novo domina; onde passou de raspão, mistura com o antigo.
Testado: cobertura 0.6 → 1.0 saturando, espessura 0.15 → 0.30 contando passadas, instante puxando
0.12 → 0.53 na direção do valor novo.

Custo: 2 blits por carimbo (0,044 ms), 8 texturas RG8 em vez de 4 RGBA8 — mesma VRAM.

O `blit_rect_multi` não ajuda aqui justamente porque compartilha o blend, mas fica anotado pra
quando dois alvos quiserem o mesmo modo.

### 3.8 Impacto no save

`tinta_secando.gd::forcar_seco()` hoje empurra o relógio pro fim. Com máscara, vira: preencher a
textura inteira com `R=1, G=0, B=0.5` e deixar `_tempo_decorrido` no fim. Duas linhas, sem
complicação — a máscara **não precisa ser serializada**, porque o save só guarda "cor X, demão N" e
o estado visual de um save retomado é sempre "tudo seco".

---

## 4. Spec da direção de arte low-poly

A tensão a resolver: você pediu low-poly assumido **e** tinta secando bem realista. Isso não é
contradição, é a identidade do jogo — **tudo é simples, menos a coisa que você foi convidado a
observar**. A parede é um quad. A tinta nela é a camada mais cuidada do projeto inteiro. Esse
contraste é a piada e a tese ao mesmo tempo.

### 4.1 O que sai

- Normal map procedural das paredes (`criar_normal_ruido(0.9, 1.2)` em `inicializar_quarto.gd`)
- Textura de detalhe triplanar de ruído nas paredes
- `NORMAL_MAP` de "relevo de rolo" no shader (linhas 141-146)
- `ROUGHNESS += (hash(coord * 8.0) - 0.5) * 0.03` — micro-variação que ninguém vê

Tudo isso é micro-detalhe fake que existia pra disfarçar superfície chapada. Numa estética low-poly
superfície chapada é a proposta, não o problema.

### 4.2 O que entra

- **Sombreamento flat (facetado).** Normais por face, não interpoladas. Nas primitivas geradas em
  runtime isso precisa ser explícito.
- **Cor chapada + variação por vértice.** [Vertex color é o caminho canônico de low-poly](https://www.tripo3d.ai/blog/explore/smart-mesh-vertex-color-workflows-for-low-poly-meshes)
  — variação de tom sem custo de textura, e AO assado no vértice nos cantos.
- **Assoalho vira tábuas de verdade.** O `assoalho.gdshader` desenha tábuas com normal map por
  diferença finita. Em low-poly, tábuas devem ser **geometria**: quads separados, com micro-variação
  de altura e ângulo, cada um com seu tom. Lê infinitamente melhor e mata um shader.
- **Props que fazem um quarto ler como quarto.** É aqui que low-poly ganha ou perde: rodapé,
  moldura na porta e na janela, interruptor, tomada, uma rachadura no reboco. Todos com 20-60
  polígonos. Um quarto low-poly bem povoado vence um quarto realista vazio, sempre.
- **Paleta fechada.** Escolher 8-10 cores base e não sair delas. É o que dá coesão e é o que
  distingue low-poly bonito de low-poly acidental.

### 4.3 Luz

O [consenso de low-poly em Godot](https://godotforums.org/d/21876-light-and-environment-setup-for-3d-low-poly-style-game):
ambiente alto, uma direcional forte, MSAA ligado.

- `ambient_light` vindo do céu, **dessaturado** — ele incide em tudo por igual, inclusive nas faces
  internas do quarto, então a cor cheia do céu pinta o cômodo inteiro (`ambiente_dia.gd`)
- Direcional pela janela como fonte principal, sombra suave
- 4.7 tem **`AreaLight3D`** — usado no vão da janela, é ele que carrega a luz de dia; o direcional
  ficou fraco, só desenhando o recorte
- **MSAA 4x** em `project.godot` — em low-poly a silhueta *é* o desenho, serrilhado destrói
- SSAO sutil, só pra escurecer canto e o encontro parede/chão
- **Não usar SDFGI** — o ruído dele briga com superfície chapada

Nota: `LightmapGI` daria o melhor resultado num quarto estático e **passou a ser viável** — o ciclo
de dia e noite foi removido (31/07/2026) e a iluminação agora é fixa. Candidato pra depois, se
valer o tempo de bake.

**Referências de direção:** [A Short Hike](https://store.steampowered.com/app/1055540/A_Short_Hike/)
(luz quente, low-poly que não parece pobre), [Dorfromantik](https://store.steampowered.com/app/1455840/Dorfromantik/)
(paleta e coesão), [Cloud Gardens](https://store.steampowered.com/app/1372320/Cloud_Gardens/) (o mais
próximo em espírito: diorama pequeno, contemplativo, poucas formas).

---

## 5. Spec da animação

### 5.0 Decisões da Fase D (01/08/2026) — LEIA ANTES DE RETOMAR

Confirmadas com o usuário antes de começar. Se esta fase for retomada em outra sessão, o estado de
execução está em **5.9**, no fim desta seção. ⚠️ **Ler também `PROJETO.md` §3.7** — há uma
ambiguidade não resolvida sobre qual rig está de fato no jogo, com a checagem exata pra rodar antes
de tocar em qualquer coisa de personagem.

| Questão | Decisão | Consequência |
|---|---|---|
| Como resolver cotovelo/joelho | **Malha contínua com weight paint suave** | Escolhido contra a recomendação (boneco articulado seria mais barato). Os corpos **precisam ser remodelados**: as cápsulas atuais são cilindro + 2 esferas sem loop nenhum no meio, e sem loops a malha não dobra — ela quebra |
| Rig da garotinha | **Simplificado** | Só pernas, coluna e cabeça. Sem IK de braço: ela só anda e senta, e o corpo é escondido quando a câmera vira 1ª pessoa |
| Mãos e pés | **Mão simples + pé chato** | Uma caixa achatada em cada ponta. A mão importa pro rolo ficar preso de forma crível; o pé, pra assentar no chão em vez de flutuar |

**O que a descoberta técnica mudou:** o mesh do tio hoje tem **16 ilhas geometricamente separadas**
(5 cápsulas × 3 peças + 1 esfera). É por isso que peso 1.0 nunca rasgou nada — não há nada contínuo
pra rasgar. Com malha contínua isso deixa de valer, e o weight paint passa a ser trabalho de
verdade.

**Abordagem de modelagem escolhida: Skin Modifier.** Em vez de tentar costurar cilindros, o corpo é
desenhado como um "esqueleto de arame" (vértices + arestas seguindo a pose do rig), e o
`SKIN` modifier gera a malha contínua em volta, com raio ajustável por vértice. Depois é aplicado e
o peso vem do **auto-weight do Blender** (`parent_set(type='ARMATURE_AUTO')`, heat map), que é bem
mais confiável que pintar peso na mão via script. Vantagens: topologia contínua de graça, poucos
polígonos, e o arame usa exatamente as mesmas coordenadas do rig.

### 5.1 Rig novo

Refazer em `res://models/fonte_blender/personagens.blend` (o arquivo-fonte já existe). Manter as
medidas atuais — a AABB bate com a colisão e as câmeras, e o `PROJETO.md` documenta que isso foi
validado. Só a hierarquia de ossos muda.

```
Quadril (raiz, y=0.85)
├── Coluna_01 → Coluna_02          (torso inclina e torce — hoje é rígido)
│   ├── Pescoço → Cabeça           (pro LookAtModifier3D)
│   ├── Ombro_E → Braço_E → Antebraço_E → Mão_E
│   └── Ombro_D → Braço_D → Antebraço_D → Mão_D → [attach: Rolo]
├── Coxa_E → Canela_E → Pé_E
└── Coxa_D → Canela_D → Pé_D
```

~19 ossos. Ainda enxuto, mas com **tudo que a IK precisa**: cotovelo pro braço, joelho pra perna,
coluna pro peso do corpo.

**A garotinha NÃO usa esta hierarquia inteira** (decisão 5.0): fica com Quadril → Coluna → Cabeça +
as duas pernas, sem braços com IK. Escala `ESCALA_CRIANCA` 0.78 nas medidas do tio.

As três armadilhas de pipeline já documentadas no histórico do `PROJETO.md` valem igual: ordem do
`keyframe_insert`, `export_optimize_animation_size=False`, e converter `ImporterMeshInstance3D` →
`MeshInstance3D`. Mais o bônus: conferir `location` da armadura antes de exportar.

#### Coordenadas do esqueleto de arame (metros, Z pra cima no Blender)

Derivadas da geometria atual pra AABB não mudar (tio: 1.8 m de altura, centrado em X=0). **Esta
tabela é a fonte da verdade** — o arame do Skin e as cabeças de osso usam os mesmos pontos.

| Ponto | Tio (x, y, z) | Observação |
|---|---|---|
| Quadril | (0, 0, 0.85) | raiz; topo da perna / base do torso |
| Coluna_01 | (0, 0, 1.05) | |
| Coluna_02 | (0, 0, 1.35) | altura do ombro |
| Pescoço | (0, 0, 1.48) | |
| Cabeça (topo) | (0, 0, 1.80) | bate com o topo da AABB atual |
| Ombro E/D | (∓0.28, 0, 1.35) | mesmo ponto do pivô de braço antigo |
| Cotovelo E/D | (∓0.31, 0, 1.10) | **novo** — não existia no rig de 7 ossos |
| Mão E/D | (∓0.33, 0, 0.86) | ponta do braço; ponto de attach do rolo (direita) |
| Coxa E/D | (∓0.12, 0, 0.85) | |
| Joelho E/D | (∓0.12, 0, 0.45) | **novo** |
| Pé E/D | (∓0.12, 0.06, 0.02) | levemente à frente, assenta no chão |

Raios do Skin (por vértice): quadril/torso ~0.20, ombro 0.09, cotovelo 0.075, mão 0.06,
coxa 0.11, joelho 0.09, pé 0.07, pescoço 0.06, cabeça 0.15.

### 5.2 Stack de modificadores no Godot

Na ordem (`SkeletonModifier3D` processa de cima pra baixo na árvore):

1. **`TwoBoneIK3D`** — braço direito (Braço_D → Antebraço_D → Mão_D), target = `AlvoRolo` (Node3D
   movido pelo trajeto). Este é o modificador que faz tudo funcionar.
2. **`TwoBoneIK3D`** × 2 — pernas, targets travados no chão ou no banquinho. Sem isso, quando o
   quadril desce pra ele agachar, os pés atravessam o assoalho.
3. **`LookAtModifier3D`** — cabeça olhando pro ponto que está sendo pintado. Barato, e vende a
   intenção mais que qualquer outra coisa: um personagem que olha pro que faz parece consciente.
4. **`LimitAngularVelocityModifier3D`** — na mão, pra amortecer solavanco quando o alvo pula entre
   trechos.
5. Opcional: **`BoneConstraint3D`** no punho, mantendo o rolo paralelo à parede independente do
   ângulo do braço.

### 5.3 Clipes autorais (o que a IK não faz)

IK resolve "onde a mão está". Não resolve personalidade. Ainda precisa de clipes de verdade:

| Clipe | Loop | Papel |
|---|---|---|
| `parado_respirando` | sim | Idle. **Respiração é o que separa "personagem" de "estátua com script"** |
| `andar` | sim | Já existe, refazer no rig novo |
| `molhar_rolo` | não | Agacha, mergulha na bandeja, escorre 2-3× na rampa. O beat de ritmo |
| `subir_banquinho` / `descer_banquinho` | não | Transição de altura, com peso |
| `agachar_base` | pose | Pose base pro rodapé — a IK ajusta a altura exata |
| `esticar_base` | pose | Pose base pro alto — idem |
| `pausa_admira` | não | Para, meio passo atrás, olha o serviço, coça a nuca. **O beat que faz ele parecer gente** |

### 5.4 Camada procedural

Por cima dos clipes, em código:

- **Altura do quadril em função da altura do alvo.** Uma curva de 3 pontos: alvo baixo → quadril
  desce e joelhos dobram; alvo alto → estica e sobe o calcanhar. Isso é o que faz agachar e esticar
  parecerem esforço, não uma pose trocada.
- **Inclinação do torso na direção da pincelada.** Peso do corpo acompanhando o braço.
- **Cabeça via `LookAtModifier3D`**, com um pouco de atraso.

### 5.5 O trajeto do rolo — a coreografia

Isto é o coração do overhaul. Em vez de "anda de A até B", a pintura de uma parede é uma sequência
de trechos de ~1 m de largura. Cada trecho:

1. **W** — sobe na diagonal, desce reto, sobe na diagonal, desce reto. É a
   [técnica real de pintor](https://www.thisoldhouse.com/painting/how-to-roll-paint-onto-a-wall):
   o W deposita a tinta em quantidade
2. **Verticais** — passadas retas adjacentes preenchendo o W. É o que espalha e uniformiza
3. **Banquinho** — sobe, faz o topo do trecho, desce
4. **Rodapé** — agacha, faz a faixa de baixo com traços curtos e cuidadosos
5. **Bandeja** — a cada 2-3 trechos, vai molhar o rolo (o canal A da máscara vai caindo até lá, e a
   falha de cobertura aparece sozinha — motivação diegética perfeita)
6. Anda ~0,8 m pro lado e repete

Isso entrega, de uma vez só, exatamente o que foi pedido: diagonais, verticais, agachar, esticar,
subir em coisa, molhar tinta. **E cada um desses movimentos deixa a marca correspondente na parede**,
porque é a mesma curva que alimenta o carimbo.

### 5.6 Consequência de pacing — ✅ DECIDIDO (01/08/2026)

> **Decisão do usuário: ritmo honesto nas demãos, abertura acelerada.** É a sugestão do fim desta
> seção. Na prática: `FRACAO_JA_PINTADA_ABERTURA` sobe pra ~0.9 (o tio está quase terminando quando
> o jogo abre, então a cutscene não cansa antes de o jogador comprar o tom), e as demãos seguintes
> passam a durar o que a coreografia real leva — volta completa de 3 a 5 minutos.
>
> Isso obriga a recalibrar `duracao_pintura_segundos` e os tempos de secagem dos 3 modos: hoje o
> modo Rápido seca em 60 s, o que ficaria mais curto que a própria pintura da parede.

Hoje: `duracao_pintura_segundos = 8.0`, uma parede em 8 s andando reto, volta completa ~40 s.

Com a coreografia honesta: 7 m de parede ÷ 1 m por trecho = 7 trechos × (W + verticais + topo +
rodapé) ≈ **40-70 s por parede**, mais 2-3 idas à bandeja. **Volta completa: 3 a 5 minutos.**

Isso não é um efeito colateral, é uma mudança de ritmo do jogo. Duas leituras possíveis:

- **A favor:** um jogo chamado "Watching Paint Dry" que resolve uma parede em 8 segundos está com
  pressa. O ritmo lento *é* a proposta, e ver o serviço sendo feito com capricho é conteúdo, não
  espera.
- **Contra:** a abertura fica longa antes da garotinha sentar, e o jogador ainda não comprou o tom.

Sugestão: acelerar só a abertura (ele já está terminando, `FRACAO_JA_PINTADA_ABERTURA` sobe pra 0.9)
e deixar as demãos seguintes no ritmo honesto. **Confirmar antes de implementar.**

### 5.7 Locomoção: virar o corpo e parar de teleportar

Duas queixas do usuário (01/08/2026), ambas de locomoção. Entram na Fase D, passo 11b.

**A. O corpo tem que virar pra direção em que anda.** Hoje `ir_ate()` (em `tio.gd` e
`garotinha.gd`) só interpola `position` com Tween, sem tocar em `rotation`. O personagem desliza de
lado ou de costas, com o clipe `andar` tocando como se fosse pra frente. Quem escreve rotação hoje é
só `pintar_varrendo()`, e mesmo assim com um ângulo fixo por parede (`VARREDURAS[i]["angulo"]`).

O que fazer:
- Derivar o ângulo do próprio deslocamento (`atan2` sobre `para - de`), em vez de tabelar
- **Virar antes de sair andando**, não durante: girar no lugar e só então iniciar o Tween de posição
  (ou girar bem mais rápido que o deslocamento). Um personagem que gira enquanto translada faz curva
  de carro, não de pessoa
- Interpolar o giro, nunca setar direto — `rotation_degrees.y` trocado num frame lê como teleporte
  de orientação. `lerp_angle` resolve o problema do caminho curto (359° → 1°)
- Enquanto pinta, a regra é outra: aí ele encara a **parede**, não a direção do movimento (anda de
  lado rente à parede, que é como se pinta de verdade)

**B. Ninguém pode teleportar.** Hoje há três saltos:
- `entrar_pela_porta()` faz `position = ponto_entrada` e `show()` — ele materializa dentro do quarto
- `sair_pela_porta()` termina com `hide()` — ele evapora na porta
- `entrar_e_sentar()` faz um Tween curto de Y (`position.y - 0.15`) e `hide()` — ela afunda no chão
  e some, em vez de sentar

O que fazer:
- Entrada/saída viram caminhada de verdade **atravessando o vão da porta**: começar do lado de fora
  (X além de 3.5), andar até dentro, e o inverso pra sair. A porta já abre e fecha
  (`porta.gd`), então o timing existe — falta o personagem percorrer o caminho
- Como o corredor externo não é modelado, basta um trecho curto além do vão: some por oclusão da
  parede, não por `hide()`. Só esconder de fato quando estiver fora do campo de visão
- **Sentar precisa virar clipe de osso** (`sentar`, ver 5.3). Hoje é deslocamento em Y + `hide()`,
  que foi aceitável enquanto o rig não tinha joelho — agora tem. A garotinha deve dobrar quadril e
  joelhos até assentar na cadeira, e o corpo **continuar visível** enquanto a câmera não cortar
- Rever a ordem em `ciclo_pintura.gd::_garotinha_entra_e_senta()`: hoje `camera_cadeira.ativar()` só
  roda depois de `sentou`, então dá pra manter o corpo visível durante a descida inteira

Cuidado: `_retomar_de_save()` esconde os dois de propósito (`_tio.hide()`, `_garotinha.hide()`) —
ali o teleporte é intencional, porque o jogador chega com tudo já pronto. Não confundir com os
saltos acima.

### 5.9 Estado de execução da Fase D — atualizar a cada passo

> Existe porque a Fase D é longa e provavelmente atravessa mais de uma sessão. **Quem retomar deve
> ler 5.0 (decisões), a tabela de coordenadas em 5.1, e este quadro.**

| # | Passo | Estado |
|---|---|---|
| 1 | Decisões com o usuário (5.0) | ✅ |
| 2 | Coordenadas do arame definidas (5.1) | ✅ |
| 3 | Corpo do tio via Skin modifier | ✅ `Tio2`, 590 verts / 588 polys |
| 4 | Armadura de 19 ossos no tio | ✅ `Tio2_Armature` |
| 5 | Auto-weight + teste de dobra (cotovelo/joelho) | ✅ **passou — não rasga** |
| 6 | Corpo + rig simplificado da garotinha | ✅ 13 ossos, 494 verts |
| 7 | Export `.glb` das duas (com as armadilhas de export) | ✅ |
| 8 | Regerar `*_modelo.tscn` no Godot (`GLTFDocument` + converter `ImporterMeshInstance3D`) | ✅ |
| 9 | Stack de `SkeletonModifier3D` (ver 5.2) | ✅ IK do braço e das pernas + `LookAtModifier3D`, todos com `active = false` até a Fase E ligar |
| 10 | Clipes base (ver 5.3) | ✅ parcial — `andar`, `parado_respirando`, `pintar_braco`. Faltam os que dependem de props (`molhar_rolo`, banquinho), que são Fase E |
| 11 | Camada procedural: altura do quadril, inclinação do torso (5.4) | ⬜ |
| 11b | **Virar o corpo na direção do movimento** (ver 5.7) | ⬜ |
| 12 | Religar `tio.gd`/`garotinha.gd` e re-testar câmeras/colisão | ⬜ |

**Estado do `.blend` (salvo):** convivem os dois — `Tio`/`Tio_Armature` (7 ossos, é o que está no
jogo hoje) e `Tio2`/`Tio2_Armature` (19 ossos, novo). A garotinha ainda só tem a versão antiga. Só
trocar quando o novo estiver validado no Godot.

**Armadilhas do Skin modifier** (custaram uma rodada cada):
- Ele deixa **vértices soltos** nas junções de ombro (sem face nenhuma). Passam despercebidos até
  alguém contar ilhas e achar "3 ilhas" onde deveria haver 1. Remover com bmesh, filtrando
  `len(v.link_faces) == 0`
- Precisa de **um vértice marcado como raiz** (`skin_vertices[0].data[i].use_root = True`), senão
  a malha sai errada. Usar o quadril
- **Subsurf encolhe a malha** (é aproximação, puxa pra dentro): o corpo saiu com 1,72 m em vez de
  1,80 e os pés 5 cm acima do chão. Como a AABB precisa bater com a colisão e as câmeras, o passo
  final é reescalar a malha pra `Z ∈ [0, 1.80]` explicitamente
- Coxas a ±0,12 com raio 0,105 quase se tocam e a perna vira um bloco só — afastadas pra ±0,15 e
  afinadas pra 0,098

**Weight paint:** `parent_set(type='ARMATURE_AUTO')` (heat map do Blender) resolveu sozinho, sem
pintura manual. Testado com cotovelo a −75°, joelho a −70°, coluna e cabeça inclinadas: a malha
dobra contínua, sem rasgar. Era o risco que a decisão 5.0 assumiu, e ele não se materializou.

**Mais duas armadilhas, do export:**
- **`material.diffuse_color` NÃO exporta pro glTF.** Ele é só preview de viewport. O exportador lê o
  **Principled BSDF** dos nodes, então é preciso `use_nodes = True` e escrever em
  `nodes["Principled BSDF"].inputs["Base Color"]`. Sintoma: personagem chega branco no Godot mesmo
  com material "colorido" no Blender. Conferir no `.glb` bruto:
  `json.materials[].pbrMetallicRoughness.baseColorFactor`
- **`materials.clear()` zera o `material_index` de todas as faces.** Se a atribuição de face por
  região já tiver sido feita, ela se perde e tudo volta pro slot 0 — reatribuir depois de mexer nos
  slots

### Sentido de rotação dos ossos — o tio pintava as próprias costas

Achado pelo usuário olhando o Blender. Os ossos de braço e perna apontam **pra baixo** (−Z na
armadura), e rotação **positiva** em X é que leva a ponta pra frente (+Y): girar (0,0,−1) por +90°
em X dá (0,+1,0). O clipe `pintar_braco` estava com valores negativos, então o braço ia pra trás —
o tio fazia o gesto de pintar virado pro lado oposto da parede.

Regra pra lembrar na Fase E, ao animar qualquer membro: **+X leva o membro pra frente do
personagem, −X leva pra trás.** Vale pra `Braco_*`, `Antebraco_*`, `Coxa_*` e `Canela_*`.

**Como conferir rápido:** `arm.matrix_world @ pose_bones["Mao_D"].head` no frame de maior extensão
do clipe. Se o Y der negativo, o braço está indo pras costas. O pé serve de referência: a ponta de
`Pe_D` aponta pra +Y, então mão e pé têm que ter Y do mesmo sinal.

### Visualizar no Blender: silenciar as NLA tracks

Com as 3 tracks ativas, o Blender **soma** as ações (`andar` + `pintar_braco` +
`parado_respirando`) e mostra uma pose combinada que não existe em lugar nenhum do jogo — foi o que
deu a impressão de que o tronco estava invertido em relação às pernas. Deixar `track.mute = True`
pra trabalhar; **religar antes de exportar**, porque track silenciada não exporta a animação.

No `.blend` os dois personagens ficam sobrepostos na origem. Para trabalhar, deslocar
`Garotinha2_Armature.location.x`; **zerar antes de exportar** (armadura deslocada vaza pro `.glb`).

### Armadilhas do `TwoBoneIK3D` — as duas que mais custam tempo

**1. O pole node é OBRIGATÓRIO.** Sem ele a IK roda e não faz absolutamente nada — sem erro, sem
warning, sem exceção. A classe herda de `IKModifier3D`, e a documentação diz numa linha só: *"This
IKModifier3D requires a pole target"*. O pole é o nó que define o plano da dobra (pra onde o
cotovelo/joelho aponta). Configurar com `set_pole_node(indice, caminho)`.

**2. `get_bone_global_pose()` NÃO reflete os modificadores.** Este é o que engana de verdade: depois
de configurar tudo certo, os getters de pose continuam devolvendo a pose de repouso, como se a IK
estivesse morta. Ela está funcionando — o resultado só aparece no que é renderizado. **A única
verificação confiável é visual (renderizar e olhar).** Perdi várias rodadas achando que a IK estava
quebrada por causa disso, inclusive testando `FABRIK3D`, cadeias diferentes, `use_virtual_end`,
`extend_end_bone` e os dois `modifier_callback_mode_process`.

Diagnóstico útil: o sinal `modification_processed` do modificador dispara a cada frame mesmo quando
nada muda — serve pra confirmar que ele *está sendo processado*, separando "não roda" de "roda e
não altera".

A API é por índice, como o `texture_blit` da Fase A — `setting_count` e depois
`set_root_bone_name(i, ...)`, `set_middle_bone_name(i, ...)`, `set_end_bone_name(i, ...)`,
`set_target_node(i, ...)`, `set_pole_node(i, ...)`. Um mesmo nó atende várias cadeias (as duas
pernas usam um `TwoBoneIK3D` só, com `setting_count = 2`).

**Cor por região:** com malha contínua não existe mais "uma peça, um material". A divisão
pele/roupa é feita por `material_index` **por face**, escolhida por critério geométrico (faixa de Z
e distância do eixo). Tentei primeiro derivar dos pesos do auto-weight, mas ele espalha influência
demais no torso e a proporção saía errada (a garotinha ficou 468 de 492 faces em pele).

**Antes de mexer no Blender:** ele abre sempre com cena nova, então é preciso abrir
`models/fonte_blender/personagens.blend` e clicar "Start Server" no painel BlenderMCP (tecla N).

**Regra de segurança:** o `.blend` atual tem os personagens que **estão no jogo hoje e funcionam**.
Não sobrescrever até o rig novo passar no teste de dobra (passo 5) — trabalhar em objetos com nome
novo (`Tio2`, `Tio2_Armature`) e só então substituir.

---

## 6. Ordem de execução

### Fase A — Spike técnica ✅ CONCLUÍDA (30/07/2026)

- `[x]` Carimbar um retângulo **rotacionado** — funciona
- `[x]` Verificar modos de blend — existem e acumulam
- `[x]` **Decisão: fica `DrawableTexture2D`.** Não precisa do plano B (`SubViewport`)
- `[x]` Medir custo — 0,022 ms por blit (CPU), 7 MB de VRAM

**Ver seção 3.8 pra API real e o que ela obriga a mudar no design da máscara.**

### Fase B — Máscara de tinta ✅ CONCLUÍDA (30/07/2026)

- `[x]` ~~Geometria da parede com UV limpo~~ — **não foi preciso mexer na geometria.** O plano
  supunha transformar cada parede num quad, mas isso quebraria as aberturas de janela e porta (que
  são justamente o motivo de as paredes serem picadas em 9 peças). Em vez disso o UV da máscara vem
  da **posição de mundo projetada no plano da parede** (`origem_parede`/`eixo_u`/`eixo_v` no
  shader). As peças emendam sem costura e a geometria ficou intacta
- `[x]` `mascara_tinta.gd` — as 2 texturas por parede + `carimbar()`, com posicionamento sub-pixel
- `[x]` Os 2 shaders `texture_blit` (`carimbo_acumulado`, `carimbo_recente`), bloco `blit()`
- `[x]` Carimbo procedural do rolo (borda macia, fibras longitudinais, queda nas pontas)
- `[x]` `tinta_secando.gdshader` reescrito lendo as duas máscaras — sumiu o bloco de varredura
- `[x]` Curva de secagem com brilho e cor em curvas separadas (o "flash off": brilho some antes de
  a cor mudar), mancha saindo da espessura real
- `[x]` Lap marks pelo gradiente do instante
- `[x]` `forcar_seco()` vira `preencher_coberta()` na máscara
- `[x]` **Testado sem personagem**, com alvo scriptado (`trajeto_rolo.gd`)
- `[x]` Performance: 920 fps no pior caso com as 4 máscaras ativas (critério pedia 60)

**Refatoração que veio junto:** `tinta_secando.gd` (que era por `MeshInstance3D`) foi aposentado e
virou `parede_pintavel.gd` (um nó por parede). A máscara é por parede, não por pedaço — o rolo não
sabe que a parede foi picada em 9 meshes. As peças agora são só geometria compartilhando material.

**Quatro armadilhas encontradas, todas com a mesma raiz — o rastro é feito de carimbos discretos,
e qualquer irregularidade no espaçamento vira padrão visível que lê como bug de renderização:**

1. **Passo entre passadas em fração, não em metros.** `0.055` de uma parede de 7 m dá 38 cm, mas o
   rolo tem 23 cm — sobrava parede crua entre as passadas. O trajeto passou a trabalhar em metros
   (que também resolve UV não ser isotrópico numa parede 7×3)
2. **Espaçamento de carimbo dependente do fatiamento.** Carimbar "das duas pontas de cada pedaço
   recebido" fazia o trecho animado (fatiado por frame) depositar mais que o instantâneo (fatiado
   por segmento) — dava pra ver a emenda. Agora os carimbos caem em posições **absolutas** ao longo
   do trajeto
3. **Perfil do carimbo `smoothstep` na faixa de contato.** Carimbos espaçados de meia-faixa só somam
   constante se o perfil for **triangular** (partição da unidade); com `smoothstep` a soma ondula e
   aparece um ripple regular atravessado
4. **`blit_rect` só aceita `Rect2i`.** O rolo anda em passos fracionários de pixel, então arredondar
   a posição gerava moiré. A saída foi arredondar o retângulo e mandar o resto fracionário como
   uniform (`desloc_sub`), deixando o shader deslocar o carimbo dentro dele

Bônus: as fibras do carimbo estavam indexadas pela faixa de contato em vez do eixo do rolo, o que
desenhava estrias atravessadas em vez de longitudinais.

### Fase C — Direção de arte low-poly (30/07/2026)

- `[x]` Tirar normal maps e ruído triplanar das paredes — já era código morto depois da Fase B
  (as 9 peças passaram a receber o material da tinta), então saiu junto com o `mat_parede`
- `[ ]` Normais flat nas primitivas geradas em runtime — `BoxMesh` já é facetado por natureza; as
  esferas/cápsulas que faltam são dos personagens, que a **Fase D vai refazer de qualquer jeito**.
  Deixado pra lá de propósito pra não fazer o trabalho duas vezes
- `[x]` Assoalho virou tábuas de **geometria** (uma peça por tábua, altura e tom próprios, fresta
  de verdade entre elas). `assoalho.gdshader` aposentado e apagado
- `[x]` Props: rodapé nas 4 paredes, moldura de janela com travessa e peitoril, batente de porta,
  interruptor, tomada — `props_quarto.gd`
- `[x]` Paleta fechada — constantes no topo de `props_quarto.gd`
- `[x]` Luz: ambiente **dessaturada** (era o que deixava o quarto laranja), SSAO, MSAA 4x
- `[x]` `AreaLight3D` na janela (`LuzJanela`). O sol direcional caiu de 2.5 pra 1.4: ele desenhava um
  retângulo de borda dura e cor estourada na parede, que lia como decalque em vez de luz. Agora quem
  carrega a iluminação de dia é a luz de área, que dá a penumbra macia que direcional nenhuma dá — e
  o direcional só marca o recorte.
  ⚠️ *"cor e energia seguindo o ciclo do dia" saiu daqui: o ciclo foi removido em 31/07/2026 e a luz
  é fixa. Valores em vigor em `PROJETO.md` §3.1.*
- `[x]` SDFGI conferido, está desligado

**Ciclo de dia e noite removido (31/07/2026), a pedido do usuário.** Depois de a luz ambiente ser
corrigida, o problema que sobrou não era de implementação e sim de proposta: num jogo cujo assunto é
uma parede secando devagar, a luz mudando por baixo compete com a única coisa que deveria estar
mudando. Amanhecer e entardecer eram os piores — tingiam o quarto inteiro e a tinta azul chegava a
ler como roxa. `ciclo_dia_noite.gd` deu lugar a `ambiente_dia.gd`: luz fixa de meio da tarde,
configurada uma vez em `_ready()`, sem `_process`. Saíram junto os nós `Lua` e `LuzNoite` e a tabela
`ModoJogo.DURACAO_DIA` — o modo de jogo agora só controla o tempo de secagem.

**A correção de luz que o usuário pediu:** `env.ambient_light_color` recebia a cor crua do horizonte.
Como luz ambiente incide em tudo por igual, inclusive nas faces internas do quarto, o pôr do sol
deixava o cômodo inteiro laranja — dava a impressão de que a luz atravessava as paredes. Agora a
ambiente é dessaturada (`lerp` pra um cinza-azulado) e mais fraca.
⚠️ *A frase original terminava falando da névoa manter a cor cheia. **A névoa foi removida em
01/08/2026** (`ambiente_dia.gd` força `fog_enabled = false`): mesmo com `fog_depth_begin` fora do
quarto, ela deixava um véu leitoso que era metade do "lavado" reclamado.*

**Bug achado pelo usuário — a divisão vertical no meio da parede na abertura:** `pintar_instantaneo`
gravava **instante fixo = 0** no trecho já pintado, enquanto o trecho animado gravava instante
proporcional ao progresso. Como a abertura pinta a parede norte em duas etapas (65% de uma vez, 35%
em cena), isso criava um degrau de até uma janela de demão inteira no relógio de secagem bem no meio
da parede: metade começava a secar junta, a outra metade escalonada. Os dois modos agora derivam o
instante da mesma coisa — a posição ao longo do trajeto.

Junto: o escalonamento de secagem entre as paredes da abertura era grande demais (uma volta inteira
+ 18% da secagem por parede), e o quarto abria com as quatro paredes em estágios visivelmente
diferentes — parecia tinta de cores diferentes, não a mesma demão. Encurtado, porque a leitura que
interessa no começo é uma só: primeira mão de tinta sobre reboco, igual nas quatro.

**Armadilhas de posicionamento** (as duas custaram uma rodada cada):
- Props colados no *centro* da parede ficam enterrados nela. As paredes são `BoxMesh` de 0.2 de
  espessura centrados em ±3.5 / −4.0 / +2.0, então a face interna está 0.1 pra dentro:
  X = ±3.4, Z = −3.9 / +1.9
- Esconder o piso antigo debaixo das tábuas abre buraco — as frestas passam a dar no vazio e a luz
  do exterior vaza por elas. Ele continua visível, escuro, como contrapiso

### Fase D — Rig novo + IK 🟡 ~10 DE 12 PASSOS

> ⚠️ **Esta lista estava toda desmarcada e contradizia o quadro de execução de 5.9, que registra 10
> passos concluídos.** Corrigido em 03/08/2026. **A fonte da verdade é a tabela de 5.9** — esta aqui
> é só o resumo. Antes de retomar, rodar a checagem de `PROJETO.md` §3.7 (há ambiguidade sobre qual
> rig está de fato no jogo).

- `[x]` Rig de 19 ossos no Blender, medidas preservadas — via **Skin modifier** (`Tio2`, 590 verts;
  garotinha simplificada em 13 ossos, 494 verts)
- `[x]` Weight paint — `parent_set(type='ARMATURE_AUTO')` resolveu sozinho. **Teste de dobra passou**
  (cotovelo a −75°, joelho a −70°): a malha não rasga. Era o risco que a decisão 5.0 assumiu
- `[x]` Export com as armadilhas conhecidas — e duas novas achadas (`diffuse_color` não exporta,
  `materials.clear()` zera `material_index`), documentadas em 5.9
- `[x]` Stack de `SkeletonModifier3D` no Godot — IK do braço e das pernas + `LookAtModifier3D`,
  **todos com `active = false`** até a Fase E ligar
- `[x]` Clipes base — **parcial**: `andar`, `parado_respirando`, `pintar_braco` prontos. Faltam os
  que dependem de props (`molhar_rolo`, banquinho), que são **Fase E** por definição
- `[ ]` **Camada procedural**: altura do quadril em função da altura do alvo, inclinação do torso
  (5.4). É o que faz agachar e esticar parecerem esforço em vez de pose trocada
- `[ ]` **Virar o corpo na direção do movimento e parar de teleportar** (5.7) — hoje `ir_ate()` só
  interpola `position`, e entrar/sair pela porta é `position =` + `show()`/`hide()`
- `[ ]` **Religar `tio.gd`/`garotinha.gd`** ao rig novo e re-testar câmeras e colisão
- `[ ]` `pausa_admira` — pode escorregar pra Fase F sem prejuízo

### Fase E — Coreografia

- `[ ]` `trajeto_rolo.gd` — gera a sequência (W, verticais, topo, rodapé, bandeja)
- `[ ]` Liga trajeto → `AlvoRolo` (IK) **e** → `mascara_tinta.carimbar()`
- `[ ]` Props: rolo na mão, bandeja no chão, banquinho, lata de tinta
- `[ ]` Refatorar `ciclo_pintura.gd` — `VARREDURAS` (eixo/início/fim) vira definição de superfície,
  não de trajeto
- `[x]` Pacing decidido (ver 5.6): **ritmo honesto nas demãos, abertura acelerada**
- `[ ]` Aplicar: `FRACAO_JA_PINTADA_ABERTURA` pra ~0.9 e `duracao_pintura_segundos` pro tempo real
  da coreografia
- `[ ]` Recalibrar o tempo de secagem dos 3 modos — com a pintura durando minutos, o modo Rápido
  (60 s) secaria antes de a parede terminar de ser pintada

### Fase G — Secagem natural + proporção do quarto

Documento próprio: **`PLANO-SECAGEM-E-QUARTO.md`**. Não depende de D nem de E (só o item 3.9 de lá
depende), então pode ser feita antes delas — e provavelmente deveria, porque é ela que faz a Fase B
entregar o que prometeu.

- `[ ]` **G1** — campo de secagem (espessura relativa + mancha de substrato + mancha da demão +
  janela/altura/canto). É o item de maior retorno do documento inteiro
- `[ ]` **G2** — cor (saturação antes de valor, véu 0.55 → 0.32) e brilho rasante
- `[ ]` **G3** — cobertura com história (canal B da acumulada), carga do rolo com números físicos
- `[ ]` **G4** — lap mark relativo e tempo de pintura por modo ⚠️ depende da Fase E
- `[ ]` **Quarto 6 × 6** e janela centrada (seção 6 de lá) — precede o `LightmapGI`, que trava a
  geometria
- `[ ]` **G5** — nitidez: supersampling/MSAA/debanding + os dois consertos de material e shader
  (seção 7.1 de lá). MSAA sozinho não pega cintilar especular nem aliasing de shader
- `[ ]` **G6** — fresta no topo da porta (a folha tem 5 cm a menos que o vão) e tamanho da janela do
  jogo (seção 7.2 e 7.3 de lá). O item mais barato de todo o plano

### Fase F — Refino e verificação

- `[ ]` Som do rolo casado com a velocidade real da mão — hoje `pincelada` é timer fixo de 1.16 s,
  desligado do movimento
- `[ ]` Som de molhar o rolo na bandeja (beat novo, merece som próprio)
- `[ ]` **Passo e porta** (decidido 01/08/2026). Só esses dois: respiração e assoalho rangendo foram
  descartados de propósito, pra não encher o ambiente de ruído num jogo cujo assunto é silêncio.
  - Passo casado com o clipe `andar` — o pé toca o chão duas vezes por ciclo, então o som sai
    nesses instantes, não em timer. Vale pros dois personagens (a garotinha pisa mais leve e mais
    rápido; mesmo som com pitch mais alto e volume menor resolve)
  - Porta: um som ao começar a abrir e outro ao bater no batente. `porta.gd` já tem `abrir()` e
    `fechar()` com os sinais `abriu`/`fechou`, e o `fechar()` usa ease-in de propósito (acelera até
    bater) — o baque casa naturalmente com o fim do Tween
- `[ ]` **O tio olhar pra garotinha** (decidido 01/08/2026). O `LookAtModifier3D` já está montado
  no `tio_modelo.tscn` (`OlharCabeca`, `active = false`) apontando pro nó `AlvoOlhar`. Basta mover o
  alvo pra cabeça dela e ligar o modificador em dois momentos: quando ela entra e senta, e de novo
  antes de ele sair pela porta. É o que separa "dois bonecos no mesmo cômodo" de "um tio e uma
  sobrinha" — e a relação entre os dois é metade da premissa do jogo.
  Cuidado: `influence` já está em 0.75 pra cabeça não travar 100% no alvo (fica robótico), e é bom
  interpolar o `active` via `influence` em vez de ligar seco
- `[ ]` **Gravar 60 s de gameplay e assistir do começo ao fim.** É o único teste que importa aqui:
  se der vontade de continuar olhando, funcionou
- `[ ]` Rodar nos 3 modos, conferir que a secagem fecha em todos
- `[ ]` Testar save/retomada com a máscara

---

## 7. Critérios de aceite

Testáveis, não subjetivos. **A coluna "quem entrega" foi acrescentada em 03/08/2026** — dois destes
critérios estavam impossíveis de alcançar com o que a Fase B implementou (ver `PROJETO.md` §3.4), e
passaram a ter dono explícito. Os critérios das Fases G estão em `PLANO-SECAGEM-E-QUARTO.md` §8.

| # | Critério | Quem entrega |
|---|---|---|
| 1 | Pausar durante a pintura: **a tinta corresponde exatamente ao que o rolo tocou**, incluindo o formato do W e a falha onde passou de leve | Fase E (W) + G3 (falha) |
| 2 | A 2ª demão **visivelmente cobre falhas** da 1ª — comparar screenshot antes/depois | **G3** (hoje impossível: `cor_anterior` é cor chapada) |
| 3 | Existe pelo menos um momento em que ele **olha pro que está pintando** e a cabeça acompanha | Fase F (`LookAtModifier3D` já montado) |
| 4 | Ele **agacha** pro rodapé e **sobe no banquinho** pro topo, e os pés não atravessam nada | Fase D (camada procedural) + E |
| 5 | Durante a secagem a parede fica **manchada** numa fase intermediária | **G1** — ⚠️ o critério original dizia "e a mancha coincide com onde ele passou duas vezes". **Isso não se sustenta**: a espessura sozinha dá 0,7% de variação e é periódica. A mancha passa a vir de espessura **+ substrato + ar + altura** |
| 6 | Nenhum normal map procedural sobrou nas paredes | ✅ Fase C |
| 7 | Zero warnings no build (warning é erro neste projeto) | todas |
| 8 | Roda a 60 fps com as 4 máscaras ativas | todas |

---

## 8. Riscos

| Risco | Mitigação |
|---|---|
| ~~`DrawableTexture2D` não suporta rotação ou blend~~ | ✅ **Eliminado na Fase A.** Rotação no shader, `blend_add` nativo, 0,022 ms/blit |
| A doc oficial do `texture_blit` está errada (diz `fragment()`, cita built-ins que não existem) | 3.7 tem a API real, levantada contra o compilador. **`fragment()` compila e nunca roda** — se a máscara sair em branco, é o primeiro lugar pra olhar |
| Rig novo quebra `tio.tscn` / `garotinha.tscn` | Preservar medidas e AABB. As duas cenas instanciam `*_modelo.tscn`, o ponto de troca é único |
| Pacing muda demais (5.6) | Decisão explícita antes da Fase E, não descoberta depois |
| Geometria de parede precisa de UV — mexe em `inicializar_quarto.gd`, que hoje monta tudo com `BoxMesh` | Fazer na Fase B, isolado, com o resto do jogo ainda funcionando |
| Escopo inflando (é um jogo "bem besta", de propósito) | Teto explícito: **as 4 paredes, um rolo, uma bandeja, um banquinho**. Sem escada, sem pincel de canto, sem fita crepe |
| Weight paint agora precisa de blend real nas articulações | Cotovelo e joelho dobrando com peso 1.0 rasga a malha. Passo próprio na Fase D |

---

## 9. Referências

**Técnica (Godot)**

- [DrawableTextures — docs 4.7](https://docs.godotengine.org/en/4.7/tutorials/rendering/drawable_textures.html) · [class ref](https://docs.godotengine.org/en/4.7/classes/class_drawabletexture2d.html)
- [Inverse Kinematics Returns to Godot 4.6](https://godotengine.org/article/inverse-kinematics-returns-to-godot-4-6/) — o mapa dos modificadores, com demos baixáveis
- [SkeletonModifier3D](https://docs.godotengine.org/en/4.4/classes/class_skeletonmodifier3d.html) · [LookAtModifier3D](https://docs.godotengine.org/en/4.4/classes/class_lookatmodifier3d.html)
- [Runtime splat map painting](https://alfredbaudisch.com/godot-engine/godot-engine-in-game-splat-map-texture-painting-dirt-removal-effect/) ([repo](https://github.com/alfredbaudisch/GodotRuntimeTextureSplatMapPainting)) — o plano B, com código
- [GPU Texture Painter](https://github.com/maantho/gpu-texture-painter) — addon completo, provavelmente overkill
- [Using a SubViewport as a texture](https://docs.godotengine.org/en/4.4/tutorials/shaders/using_viewport_as_texture.html)

**Tinta de verdade**

- [Lapping — Rodda Paint](https://www.roddapaint.com/problem-solver/lapping-interior/) — o que é lap mark e por que acontece
- [Why is my paint streaky after drying — Mark's Painting](https://www.markspainting.com/blog/why-paint-streaky-after-drying)
- [Smooth finish with latex — SISU](https://sisupainting.com/tips-for-achieving-a-smooth-finish-with-latex-paint/)
- [Interior paint drying time guide](https://facadecolorizer.com/us/blog/interior-paint-drying-time-guide-2026) — os tempos reais, úteis pra calibrar o modo Realista

**Técnica de pintura (referência de animação)**

- [How to roll-paint a wall — This Old House](https://www.thisoldhouse.com/painting/how-to-roll-paint-onto-a-wall) ([vídeo](https://www.youtube.com/watch?v=xIGO2BepvWE))
- [Painting walls using a roller — Bill Nunn](https://www.youtube.com/watch?v=-I543gX1Lo8) — pintor profissional, corpo inteiro em quadro
- [Here's how we roll walls (2026)](https://www.youtube.com/watch?v=hYJfXj9hfwI)
- [Paint like a pro — Resene](https://www.youtube.com/watch?v=c_Ne9khYeRo)
- [Extension poles e áreas difíceis](https://www.painterssolutions.com/blogs/painters-news/using-extension-poles-and-tools-for-hard-to-reach-areas)

**Low-poly**

- [Vertex color workflows pra low-poly](https://www.tripo3d.ai/blog/explore/smart-mesh-vertex-color-workflows-for-low-poly-meshes)
- [Low poly 3D art style — guia](https://www.tripo3d.ai/blog/explore/low-poly-3d-art-style-guide)
- [Setup de luz e ambiente pra low-poly em Godot](https://godotforums.org/d/21876-light-and-environment-setup-for-3d-low-poly-style-game)
- Direção: [A Short Hike](https://store.steampowered.com/app/1055540/A_Short_Hike/) · [Dorfromantik](https://store.steampowered.com/app/1455840/Dorfromantik/) · [Cloud Gardens](https://store.steampowered.com/app/1372320/Cloud_Gardens/)

**Props (se não valer modelar)**

- [Paint roller and bucket — Sketchfab](https://sketchfab.com/3d-models/paint-roller-and-bucket-1e24a10f91bd433d9918a44b1ea75141)
- [Paint roller (ex-Google Poly) — Sketchfab](https://sketchfab.com/3d-models/paint-roller-from-poly-by-google-6a1a1a0bef1145e6a9ff5893dc384745)

Ressalva: rolo, bandeja e banquinho low-poly são 20 minutos no Blender cada, e ficam mais coesos com
a paleta do que asset baixado. Os links ficam como referência de proporção.
