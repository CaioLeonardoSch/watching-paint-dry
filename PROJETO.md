# Watching Paint Dry — Projeto

Documento-mãe do projeto. Substitui `CONCEITO-DO-JOGO.md` e `PLANO-EVOLUCAO-STEAM.md` (apagados).
`CLAUDE.md` é só o roteador pra cá, de propósito — assim o plano de ação, que só cresce, não é
carregado em toda sessão.

---

## 0. Como usar estes documentos

### 0.1 Vocabulário — três palavras que já se confundiram

Este projeto usa "etapa" e "fase" com significados **diferentes e não intercambiáveis**. Ler errado
faz alguém refazer trabalho pronto.

| Palavra | O que é | Onde mora |
|---|---|---|
| **Etapa 1, 2, 3** | Os três grandes blocos até publicar na Steam: miolo → conteúdo → loja | Seção 4 deste arquivo |
| **Fase A … G** | Os passos **dentro da Etapa 1** (o overhaul do miolo) | `PLANO-OVERHAUL-TINTA.md` §6 e `PLANO-SECAGEM-E-QUARTO.md` |
| **Fase 1, 2, 3** ⚠️ | O **roadmap ORIGINAL**, concluído e aposentado. Só aparece em texto histórico | Seção 3 deste arquivo |

⚠️ **"Fase 1.2" é o rig antigo de 7 ossos, do roadmap original — NÃO é a Fase D.** Sempre que uma
fase for citada com letra (D, E, F, G) é o overhaul atual; com número, é história.

### 0.2 Mapa dos documentos

| Arquivo | O que tem | Quando ler |
|---|---|---|
| `CLAUDE.md` | Roteador de 30 linhas | Carregado sozinho toda sessão |
| **`PROJETO.md`** (este) | Premissa, convenções, estado atual, ordem das etapas, backlog | **Sempre, antes de qualquer coisa** |
| `PLANO-OVERHAUL-TINTA.md` | Spec técnica das Fases A–F: máscara de tinta, direção low-poly, rig + IK, coreografia | Antes de mexer em tinta, parede, rig ou animação |
| `PLANO-SECAGEM-E-QUARTO.md` | Spec das Fases G1–G6: campo de secagem, quarto 6 × 6, nitidez, porta, resolução | Antes de mexer em shader de tinta, coordenada de parede ou `project.godot` |

Os dois planos são **descartáveis por construção**: quando uma fase fecha, o que sobreviver dela
vira parágrafo na seção 3 daqui e o texto de planejamento morre. `PROJETO.md` é o único permanente.

### 0.3 Estrutura deste arquivo

| Seção | Conteúdo | Leia quando |
|---|---|---|
| 1. **Porquê** | Premissa, tom, disciplina de escopo | A dúvida for "isso faz sentido pro jogo?" |
| 2. **Como** | Stack, convenções, armadilhas conhecidas, ferramentas | **Antes de escrever qualquer linha de código** |
| 3. **O que já foi feito** | Estado real do jogo, sistema por sistema, e o que já foi descartado | Antes de propor qualquer coisa — evita reinventar e evita repetir erro já revertido |
| 4. **O que fazer agora** | As 3 etapas, com dependências e checkboxes | É o backlog ativo. **Manter os checkboxes em dia** |
| 5. **Backlog** | O que não está agendado em etapa nenhuma | Ao decidir escopo |

### 0.4 Regra de ouro pra quem for executar

1. Ler seção 2 (convenções) e seção 3 (estado atual) **antes** de propor. Metade das armadilhas
   deste projeto já foi paga uma vez e está documentada — repeti-las é o desperdício mais caro aqui.
2. Conferir a **seção 3.6 (Coisas já tentadas e descartadas)** antes de sugerir qualquer melhoria
   visual. Várias ideias "óbvias" já foram implementadas, testadas e revertidas por bom motivo.
3. **Mudança de escopo passa por confirmação explícita.** Nunca assumir sozinho.
4. Ao terminar um passo, **atualizar o checkbox e escrever o porquê**, não só o quê. Este projeto se
   apoia no registro das decisões; um `[x]` sem explicação perde metade do valor.

---

## 1. Porquê

"Watching paint dry" é expressão em inglês pra tédio absoluto — a coisa mais entediante possível de
se assistir. O projeto nasceu como piada nesse sentido: literalmente um quarto onde a única coisa
que acontece é tinta secando numa parede. Mas a piada tem uma virada séria em aberto — observar algo
mudar lentamente, sem pressa, sem objetivo, pode ser genuinamente relaxante em vez de entediante. É
essa segunda leitura que o projeto está explorando, sem compromisso de chegar lá.

A direção foi decidida e implementada em fases: já **é** um loop de jogo, não só exercício de
aprendizado de engine. Um tio pinta as 4 paredes do quarto em rodadas (3 demãos cada), dando uma
volta completa pelo quarto e pintando enquanto anda; uma garotinha entra e senta pra assistir secar
(a câmera vira a visão dela), e ao final o tio pergunta se ela gostou da cor — pode manter ou trocar
por uma nova, o que reinicia o ciclo. Acabou sendo um meio-termo entre duas ideias esboçadas
originalmente (cuidar de várias tintas secando em paralelo vs. puramente contemplativo/screensaver),
embalado numa moldura narrativa que nenhuma das duas previa — decisão consciente, confirmada
explicitamente antes de cada fase.

**Espírito e disciplina de escopo:** este projeto é parte de um conjunto de projetos de design
pessoais (junto com um jogo de tamanduá e um de sapo/rã), todos com o mesmo espírito — jogos
relaxantes, sem pressão, loop de observação/manutenção em vez de ação. A disciplina vale aqui como
nos outros: **enxuto, finito, sem mecânica adicionada só por adicionar**. Mudanças de escopo maiores
passam por confirmação explícita antes de implementar, nunca são assumidas sozinhas.

**Nova decisão (rodada atual):** depois do roadmap original e de uma rodada de refinamento item a
item, o usuário definiu um objetivo novo e concreto — transformar o projeto num jogo pequeno,
barato e **"bem besta"** de propósito, sem ambição de escopo grande, mas entregável de verdade numa
loja (Steam). Isso muda o que "pronto" significa: não é mais só "a mecânica funciona", é "isso
passaria como produto simples, sem parecer protótipo". Confirmado explicitamente pelo usuário, mesma
disciplina de sempre.

---

## 2. Como — stack, convenções e ferramentas disponíveis

### 2.1 Stack técnico

- Godot **4.7**, renderer Forward Plus
- Física: **Jolt Physics**
- Driver: **D3D12** no Windows
- Entry point: `res://scenes/menu_principal.tscn` (menu) → `res://scenes/quarto.tscn` (jogo)

### 2.2 Convenções deste projeto

- **GDScript, comentários e nomes de variáveis/nós em português brasileiro**, informal — mesmo
  registro usado nos outros projetos de design (tamanduá, sapo)
- **`.tscn` não leva `[sub_resource]` de mesh inline.** O parser de cena do Godot 4 é estrito e
  esses recursos inline causam erro ao salvar/reabrir. Padrão adotado: o `.tscn` declara só
  estrutura de nós + referência a scripts externos; meshes e materiais são atribuídos em runtime
  (via `_ready()`), ou manualmente no Inspector quando for algo pontual
- Scripts que dependem de mesh gerado em runtime usam `call_deferred` pra esperar o mesh existir
  antes de aplicar material (ver `parede_pintavel.gd::aplicar_em`)
- Até aqui, texturas/materiais e áudio foram feitos por **geração procedural via shader/ruído e
  síntese em código** — não por escolha permanente, mas porque era o suficiente até agora. **Asset
  externo (textura, modelo 3D, áudio gravado) não é mais proibido**: jogo de verdade usa esse tipo
  de coisa, e a decisão de ir procedural ou externo passa a ser por item, pesando esforço vs.
  ganho — não uma regra geral do projeto
- **Warnings são tratados como erro.** Duas armadilhas que já quebraram build aqui:
  `var x := max(a, b)` falha ("inferred from Variant") — usar `maxi()`/`maxf()` ou anotar o tipo;
  e passar `dicionario["chave"]` direto pra parâmetro tipado dispara `UNSAFE_CALL_ARGUMENT` —
  extrair numa variável tipada antes
- Referências entre nós usam caminho relativo (`$"../Nome"`), **não** `%NomeUnico` — nome único já
  resolveu pra `null` sem motivo claro neste projeto mais de uma vez
- **Pipeline Blender → Godot** (modelos rigados, `res://models/`): três armadilhas reais de
  keyframe/export/import documentadas no histórico da seção 4 — ordem de `keyframe_insert` vs.
  `frame_set`, `export_optimize_animation_size` quebrando loops perfeitos, e
  `GLTFDocument.generate_scene()` deixando `ImporterMeshInstance3D` em vez de `MeshInstance3D`.
  Ler antes de mexer em modelo/animação de personagem de novo
- `execute_editor_script` do Godot MCP tem regex ingênua pra `print()`: qualquer parêntese
  aninhado dentro do `print(...)` (ex: `print(str(x))`, `print(a.metodo())`) quebra o parse do
  script gerado. Sempre extrair pra variável antes: `var t = str(x); print(t)`
- **`execute_editor_script` não suporta `await`** — qualquer `await` no código, mesmo sozinho
  (`await get_tree().process_frame`), quebra o parse (erro 43) do script que o addon gera por
  baixo. Também não dá pra testar em duas chamadas separadas: cada chamada roda num nó temporário
  que é destruído (`queue_free`) no fim dela mesma, então nada adicionado à árvore numa chamada
  sobrevive pra próxima. E carregamento de shader (`ShaderMaterial` + `load(".gdshader")`) dentro
  de uma chamada trava silenciosamente sem erro nenhum (suspeita: addon processa comando fora da
  main thread, e RenderingServer não gosta). Na prática: pra código que depende de `_ready()`
  rodar (construção procedural de geometria, por exemplo), só dá pra confiar em teste estrutural
  (a cena carrega sem erro) — o comportamento de verdade só se confirma jogando o jogo
- **Localização**: `resources/localizacao/textos.csv` (chave = texto PT-BR, colunas por idioma),
  importado pelo Godot como um `Translation` por idioma com conteúdo (hoje só `pt_BR` e `en` têm
  texto real — `es`/`fr`/`zh_CN`/`ja`/`de` existem como coluna vazia, sem tradução
  ainda). Registrado em `project.godot::[internationalization]`
  (`locale/translations` + `locale/fallback="pt_BR"`). UI estática (`text = "..."` no `.tscn`)
  traduz sozinha (Godot usa o próprio texto como chave); texto setado via código precisa de `tr()`
  explícito (ver `menu_principal.gd`, `dialogo_pintura.gd`, `conquista_toast.gd`) — não confiar só
  no auto-translate de propriedade pra string dinâmica. Trocar idioma: `Opcoes.definir_idioma(codigo)`
  (autoload, persiste em `config.cfg`, aplica `TranslationServer.set_locale`)

### 2.3 Sistema de skills de gamedev

- `.agents/skills/` — router + skills especializadas de Godot (câmera, shaders, nodes, áudio etc.),
  instaladas via `npx skills add gamedev-skills/awesome-gamedev-agent-skills` (registro em
  `skills-lock.json`). Uso normal pra "como fazer X em Godot"
- **6 skills adicionadas** numa sessão de planejamento (Cowork), do mesmo repo, cobrindo lacunas do
  polish atual: `steam-publish` (onboarding Steamworks, depots, loja, build/release — Fase 3),
  `godot-export` (export presets/templates, build por plataforma — pré-requisito da Fase 3),
  `game-ui-ux` (HUD/menus cross-engine: anchors, resolução — Fase 1.1), `dialogue-systems` (diálogo
  ramificado — só se a Fase 1.2 expandir o diálogo da garotinha), `procedural-gen` (ruído/RNG/seeds
  — reforça o que `materiais_procedurais.gd` já faz na unha) e `shader-programming` (conceitos de
  shader cross-engine, complementa `godot-shaders`)
- Instalar skill nova: `npx skills add gamedev-skills/awesome-gamedev-agent-skills -s <nome> --copy
  -y` — **atenção:** `-s` não aceita lista separada por vírgula, repita a flag por skill
  (`-s a -s b -s c`); e sem mais nada o comando espalha cópia pra ~70 pastas de ferramentas de IA
  que não existem neste ambiente (`.aider-desk/`, `.windsurf/`, etc.) — apague essas pastas depois,
  só `.agents/skills/` (versionado) e `.claude/skills/` (gitignorado, é a cópia que o Claude Code
  usa de verdade) devem sobrar

### 2.4 Ferramentas externas — status de configuração

Levantadas numa sessão de planejamento (Cowork), a configurar conforme formos usando. Atualize o
status `[ ]`/`[x]` conforme instalar cada uma.

- `[x]` **Godot MCP** — já configurado (`addons/godot_mcp/` no projeto + permissões em
  `.claude/settings.local.json` pra `mcp__godot-mcp__*`). Dá ao Claude acesso direto ao editor:
  ler cena atual, listar nós, propriedades, executar script no editor
- `[x]` **Blender MCP** — Blender 5.2.0 instalado via `winget` (`BlenderFoundation.Blender`),
  addon oficial (`ahujasid/blender-mcp`) instalado e ativado, servidor MCP registrado (`claude mcp
  add blender-mcp -s user -- uvx blender-mcp`, escopo `user`, mesmo padrão do `godot-mcp`), e
  "Start Server" já clicado no painel BlenderMCP dentro do Blender — conexão de ponta a ponta
  confirmada, pronta pra uso. **Atenção:** o Blender abre sempre com cena nova, então é preciso
  abrir `models/fonte_blender/personagens.blend` e clicar "Start Server" a cada sessão
- `[ ]` **GodotSteam** — GDExtension pra Steamworks (achievements, etc.). Entra na Etapa 3
- **Descartados, não precisaram existir:** *Figma MCP* (o menu foi direto pro código), *ProtonScatter*
  (espalhamento manual com seed fixa bastou pro volume de props) e *Dialogue Manager* (o diálogo
  continua sendo "gostei"/"trocar" — só entra se crescer, ver seção 5)

---

## 3. O que já foi feito

### 3.1 Estado atual do jogo

Já tem um loop narrativo de verdade, não é mais só "olhar ao redor". As 3 fases do roadmap original
estão **completas**, mais uma rodada de refinamento pós-roadmap:

- **Fase 1 — loop narrativo:** tio pinta as 4 paredes em rodadas coordenadas (3 demãos cada, cor
  ficando mais saturada a cada rodada), dando uma volta completa: Leste, Norte, Oeste, Sul. Ele
  pinta **andando** (`tio.gd::pintar_varrendo`), e a frente de tinta no shader avança junto com
  ele. Garotinha entra, senta, câmera vira 1ª pessoa dela (`camera_cadeira.gd::ativar()`); depois
  da 3ª demão, UI (`dialogo_pintura.gd`) pergunta se ela gostou — "gostei" encerra o ciclo,
  "trocar" abre paleta (`cor_tinta.gd` + `.tres` em `resources/cores/`) e reinicia com cor nova.
  Azul é a cor inicial da abertura (fora da rotação de conquista); vermelho/laranja/amarelo/verde/
  violeta/rosa são as 6 que batem com as conquistas de cor. Personagens têm modelo rigado (Blender,
  Fase 1.2 — ver seção 4), animados por `AnimationPlayer` (clipes `andar`/`pintar_braco`) em vez do
  boneco procedural original
- **Fase 2 — ambientação:** luz fixa de meio da tarde (`ambiente_dia.gd`) — o sol entra pela janela
  a 52° do horizonte, céu procedural com nuvens em `sky_cover` (alfa por `color_ramp`);
  cenário externo pela janela (`cenario_externo.gd`) — jardim, árvores, rua e casas, tudo
  primitivas; som ambiente sintetizado (`som_ambiente.gd`/`som_pincelada.gd`, sem arquivo de áudio).
  **O ciclo de dia e noite foi removido** (ver "descartados" abaixo).
  **Grade de cor:** o `Environment` do quarto usa tonemap ACES (`tonemap_mode = 3`,
  `tonemap_white = 6.0`) + `adjustment_*` leve (contraste 1.08, saturação 1.15). Sem tonemap
  (linear, o default) tudo acima de 1.0 grampeava em branco e o quarto ficava lavado, com a mesma
  cara de neblina que a comparação com a tela de título denunciou. Junto saiu a névoa (ver "Mundo
  externo") — era ela a maior parte do véu — e vieram luzes menos fortes.
  **Correção 02/08/2026 — a parede leste mais escura.** A parede da porta ficava visivelmente mais
  escura que as outras. **Não é a tinta:** o material das 4 paredes foi medido e é idêntico. É que
  a `LuzJanela` não alcança aquele lado (a parede está a ~6,9 m de uma luz de `area_range` 7), então
  lá só chega lâmpada + ambiente. Testado no jogo: **mexer no `area_range` não muda nada** — a queda
  de 1/d² já matou a contribuição antes do corte. Quem equilibra é a lâmpada.

  **Valores em vigor hoje** (conferidos no código, não confiar em valor citado em texto antigo):

  | Onde | Parâmetro | Valor |
  |---|---|---|
  | `ambiente_dia.gd` | `ENERGIA_SOL` | 1.4 |
  | `ambiente_dia.gd` | `ENERGIA_AMBIENTE` | 0.16 |
  | `ambiente_dia.gd` | `COR_AMBIENTE` | `(0.66, 0.72, 0.84)` — dessaturada de propósito |
  | `quarto.tscn` | `LuzJanela.light_energy` | 1.5 |
  | `quarto.tscn` | `LuzLampada.light_energy` | 1.1 |

  ⚠️ **Armadilha: o `Environment` do `quarto.tscn` tem `ambient_light_color` e
  `ambient_light_energy` gravados (0.72,0.75,0.82 e 0.22), mas eles são SOBRESCRITOS em runtime por
  `ambiente_dia.gd::_configurar_ambiente()`.** Editar esses dois campos pelo Inspector não produz
  efeito nenhum no jogo. Quem manda é o script.

  A causa estrutural continua sem conserto e tem dono: ver `PLANO-SECAGEM-E-QUARTO.md` §6.2 —
  a janela está 1 m fora do centro da parede dela, e não existe luz indireta no quarto
- **Fase 3 — menu, modos, save, conquistas:** `estado_jogo.gd` é o autoload `EstadoJogo`, guarda
  modo ativo e `DadosSalvos` salvo em `user://save.tres`. Menu inicial oferece Jogar (seletor de
  modo Rápido/Normal/Realista) ou Continuar, mais visualizador de conquistas. `parede_pintavel.gd`
  se autoconfigura a partir do modo ativo — desde a remoção do ciclo de dia, **o modo só controla o
  tempo de secagem** (Realista é 2h/demão). Menu de pausa (ESC) pausa a árvore de
  verdade (`get_tree().paused`). Conquistas (`conquistas.gd`, 10 no total, texto fixo) disparam ao
  completar ciclo de 3 demãos de uma cor, com toast e persistência entre sessões
- **Refinamento pós-roadmap:** porta de verdade (`porta.gd`/`porta.tscn`) com maçaneta de latão,
  abre/fecha por `Tween`, orquestrada por `ciclo_pintura.gd`; cadeira de madeira em `(0, 0, -1)`;
  teto liso de propósito (sem normal map — luz rasante da lâmpada vira rabisco)
- **Overhaul da tinta (Fases A/B do `PLANO-OVERHAUL-TINTA.md`):** a tinta deixou de ser calculada a
  partir da posição e passou a ser lida de uma **máscara do que o rolo tocou**
  (`mascara_tinta.gd` + `parede_pintavel.gd` + `trajeto_rolo.gd`, com `DrawableTexture2D` do 4.7).
  Isso é o que permite falha de cobertura, sobreposição mais grossa que seca depois, e lap mark —
  nada disso era representável no modelo anterior. `tinta_secando.gd` foi aposentado: a máscara é
  por **parede**, não por pedaço de mesh
- **Modelo de cor da tinta (02/08/2026, pesquisado antes de mexer):** cada `.tres` de
  `resources/cores/` tem agora **uma cor autoral só** — `cor_alvo`, a cor cheia. As demãos e o tom
  molhado saem de curva em `cor_tinta.gd`:
  - **cobertura acumulada 70% / 91% / 97%** sobre reboco cru (`#EDEBE6`) — converge, não é linear:
    cada demão cobre a maior parte do que ainda faltava, e a cor "de verdade" chega já na 2ª (é
    assim que fabricante formula tinta). A 3ª é acabamento, muda pouco **de propósito**
  - **molhada = seca daquela demão puxada 55% pro leitoso** (`#EDEDF0`), ou seja **mais clara** que
    a seca. Antes era o contrário e estava errado: o ligante da látex é branco leitoso com água e
    fica transparente ao secar, então tinta seca MAIS ESCURA — o brilho da superfície molhada é que
    engana pra "mais clara". O modelo antigo (molhado escuro → seco pálido) dava a leitura de
    "escureceu e depois lavou", que foi exatamente a queixa do usuário
  - o véu de 55% é **exagero deliberado**. Começou em 20% (fiel) e o usuário não conseguiu ver a
    tinta secando nem no modo Rápido. Medido no render, mesma parede e mesma luz: 20% movia ~4
    valores de RGB ao longo dos 60 s, 40% movia ~17, 55% move ~34 — de um lilás leitoso pro azul
    cheio, visível sem comparar print. A luz do quarto é baixa e comprime qualquer diferença
    pequena; como o jogo é literalmente assistir isso, o efeito precisa caber na tela. O estado
    FINAL não muda com o véu — muda só o caminho até ele
  - `ROUGHNESS` de tinta molhada foi de 0.55 pra 0.45, pelo mesmo motivo (o brilho de molhado
    precisa ser perceptível). Continua longe do "quase espelho" que já foi revertido antes
  - some `variantes_secas`/`cor_molhada_base`; quem precisa de cor pede `cor.seca(i)` /
    `cor.molhada(i)` / `cor.cor_alvo` (amostra da paleta em `dialogo_pintura.gd` usa a alvo)
- **Direção low-poly (Fase C):** assoalho virou geometria de tábuas (uma peça por tábua, tom e
  altura próprios; `assoalho.gdshader` apagado); props que dão leitura de quarto
  (`props_quarto.gd`: rodapé, moldura de janela, batente de porta, interruptor, tomada); normal map
  e ruído triplanar removidos das paredes; SSAO e MSAA 4x ligados; `AreaLight3D` no vão da janela
- **Janela redesenhada (01/08/2026)** — vão encurtado 15% em Z (2.0 → 1.7, mais quadrado) e
  travessa vertical somada à horizontal: cruz no meio, 4 vidros iguais, o desenho clássico. Antes
  era só uma divisória horizontal, o que deixava a janela comprida com cara de vitrine. Mexe em 4
  lugares que precisam andar juntos: `inicializar_quarto.gd` (tamanho das peças da parede oeste e
  os 4 painéis de vidro), `props_quarto.gd::_moldura_janela` (moldura + cruz), as transforms de
  `ParedeOesteNorte`/`Sul` em **`quarto.tscn` e `fundo_menu.tscn`**, e `LuzJanela.area_size`

### 3.2 Layout do quarto (fonte da verdade)

```
Quarto:  X ∈ [-3.5, +3.5],  Z ∈ [-4.0, +2.0]

Norte (-Z) = FRENTE  → parede sólida com tinta secando (ParedeNorteSolida)
Sul   (+Z) = ATRÁS   → parede fechada (ParedeSul)
Oeste (-X) = ESQUERDA → janela: vão Z ∈ [-0.85, +0.85], Y ∈ [0.8, 2.0], 4 vidros
Leste (+X) = DIREITA  → porta (folha com maçaneta, abre e fecha) → dá no ComodoVizinho
```

As 4 paredes são pintáveis, cada uma picada em vários `MeshInstance3D`. O shader da tinta usa
**posição de mundo**, não `UV` (com UV o desenho reinicia em cada bloco). Ordem do circuito de
pintura (`ciclo_pintura.gd::VARREDURAS`): Leste, Norte, Oeste, Sul.

Câmera da cadeira fica perto do centro, olhando pro norte, ativa só depois da abertura (garotinha
sentar); antes disso quem está ativa é a `CameraCutscene`, enquadrando parede+porta+cadeira.

**Isso já mudou de layout antes** (versão anterior em L, com puxadinho a sudoeste) — não assuma o
layout antigo se aparecer em conversa ou documento velho.

⚠️ **E vai mudar de novo, se a Fase G for em frente.** `PLANO-SECAGEM-E-QUARTO.md` seção 6 propõe
encolher X de 7,0 pra 6,0 m (quarto **6 × 6**, as 4 paredes idênticas) e centrar a janela na parede
oeste (Z = 0 → −1). Motivo: as paredes norte/sul têm 21 m² e as leste/oeste 18 m², o rolo anda 17%
mais rápido nas longas, e a janela fora do centro faz a parede norte receber ¼ da luz de janela que
a sul recebe — que é a causa medida da queixa de "sombra mais funda nas paredes distantes". A lista
fechada de arquivos e valores a mexer está na seção 6.6 daquele documento.

### 3.3 Mapa dos arquivos — quem é dono do quê

Pra não caçar. "Quero mexer em X" → o arquivo é este.

| Quero mexer em… | Arquivo |
|---|---|
| Como a tinta seca, cor, brilho, mancha | `shaders/tinta_secando.gdshader` |
| O que o rolo deposita na máscara | `shaders/carimbo_acumulado.gdshader` · `carimbo_recente.gdshader` |
| A máscara em si (texturas, carimbo do rolo) | `scripts/mascara_tinta.gd` |
| Uma parede como unidade de tinta (relógio, material, demão) | `scripts/parede_pintavel.gd` |
| O caminho que o rolo percorre | `scripts/trajeto_rolo.gd` |
| As cores da paleta e a curva de demãos | `scripts/cor_tinta.gd` + `resources/cores/*.tres` |
| A ordem da intro e do loop de demãos | `scripts/ciclo_pintura.gd` |
| Geometria estática do quarto (paredes, chão, teto, janela, cadeira, assoalho) | `scripts/inicializar_quarto.gd` |
| Rodapé, moldura de janela, batente, interruptor, tomada | `scripts/props_quarto.gd` |
| Porta (folha, maçaneta, batentes, abrir/fechar) | `scripts/porta.gd` + `scenes/porta.tscn` |
| Luz, céu, ambiente | `scripts/ambiente_dia.gd` (script do nó `Sol`) |
| O que se vê pela janela | `scripts/cenario_externo.gd` |
| O que se vê pela porta | `scripts/comodo_vizinho.gd` |
| Personagens (movimento, animação) | `scripts/tio.gd` · `garotinha.gd` + `models/*_modelo.tscn` |
| Câmera da cadeira | `scripts/camera_cadeira.gd` |
| Menu, pausa, opções, diálogo, toast | `menu_principal.gd` · `menu_pausa.gd` · `painel_opcoes.gd` · `dialogo_pintura.gd` · `conquista_toast.gd` |
| Save de progresso · modo de jogo | `estado_jogo.gd` (autoload) + `dados_salvos.gd` · `modo_jogo.gd` |
| Volume, tela cheia, idioma | `scripts/opcoes.gd` (autoload) |
| Conquistas | `scripts/conquistas.gd` |
| Som | `som_ambiente.gd` · `som_pincelada.gd` (sintetizados, sem arquivo de áudio) |

#### Pares que PRECISAM andar juntos

Cada um destes já se desencontrou ou está a um descuido de se desencontrar. **Mexeu num, confira o
outro na mesma sessão.**

| Se mexer em… | Confira também | Por quê |
|---|---|---|
| Qualquer geometria de parede/janela | **`quarto.tscn` E `fundo_menu.tscn`** | `fundo_menu.gd` herda `inicializar_quarto.gd`; a cena do menu tem transforms próprios que não são atualizados sozinhos |
| `parede_pintavel.gd::VARIACAO_MAX` | `tinta_secando.gdshader::variacao_max` | São o mesmo número em dois lugares — é o clamp do campo de secagem, e `duracao_total()` só é honesta porque ele existe |
| `parede_pintavel.gd::CARGA_TIPICA` e `ESPESSURA_DEMAO` | Carga e trajeto em `trajeto_rolo.gd` | São **medidos**, não escolhidos (0,627 e 0,033). Mexer na carga do rolo ou no trajeto desregula os dois. Remedir lendo a máscara de volta — receita em SECAGEM §5.1 |
| `tinta_secando.gdshader::cobertura_min/max` | `copia_cobertura.gdshader` | O histórico é gravado com o MESMO `smoothstep`, e é isso que fecha a costura entre demãos. A fonte da verdade é `parede_pintavel.gd::COBERTURA_MIN/MAX`, que **empurra** pros dois — não chumbar nos `.gdshader` |

**⚠️ `get_shader_parameter()` devolve `null` pra uniform que nunca foi setada.** O valor default
escrito no `.gdshader` **não conta** — ele só existe no shader, não no material. Ler um uniform de
volta pra passar adiante (`guardar_historico(material.get_shader_parameter("cobertura_min"), …)`)
estourou com *"Cannot convert argument 1 from Nil to float"* só quando o jogo rodou de verdade.
Se um número precisa ser compartilhado entre GDScript e shader, ele mora no **GDScript** e é
empurrado com `set_shader_parameter`.

**⚠️ Não filtrar a saída do Godot enquanto se testa.** `... | Select-Object -Last N` e
`| Select-String` no PowerShell **seguram a saída até o processo sair** e cortam as linhas do meio —
foi assim que o erro acima passou por vários testes seguidos sem eu ver. Pra rodar o jogo e ler tudo:

```powershell
Start-Process -FilePath "…\Godot….exe" -ArgumentList '--path','…','--script','…' `
  -RedirectStandardOutput saida.log -RedirectStandardError saida.err -Wait -NoNewWindow
```
| `ciclo_pintura.gd::COR_PAREDE_CRUA` | `cor_tinta.gd::COR_FUNDO_CRU` e o default de `cor_anterior` no shader | Três cópias do mesmo tom de reboco (`0.93, 0.92, 0.90`) |
| `mascara_tinta.gd::FAIXA_ROLO_M` | `trajeto_rolo.gd::PASSO_CARIMBO` | O perfil do carimbo é **triangular de base = 2 × passo** de propósito (partição da unidade). Quebrar essa razão faz a parede ganhar um ripple regular atravessado |
| `props_quarto.gd::LIMITE_X` / `LIMITE_Z_*` | Tamanhos em `inicializar_quarto.gd` e transforms no `.tscn` | Os props usam a **face interna** da parede (0,1 m pra dentro do centro), não o centro |
| Vão da janela | `inicializar_quarto.gd`, `props_quarto.gd::_moldura_janela`, transforms de `ParedeOeste*` nas **duas** cenas, e `LuzJanela.area_size` | Cinco lugares |
| `ciclo_pintura.gd::VARREDURAS` | Tamanho das paredes | `origem`/`eixo_u`/`eixo_v` definem o UV da máscara a partir da posição de mundo. Errar aqui não dá erro, só desalinha a tinta |

### 3.4 Onde o código NÃO faz o que o plano diz

Auditoria de 02/08/2026, feita lendo o código contra o `PLANO-OVERHAUL-TINTA.md`. **Registrar aqui
porque as duas fases envolvidas estão marcadas como concluídas e não estão.** Detalhe completo, com
as contas, em `PLANO-SECAGEM-E-QUARTO.md` §2.

| O que o plano diz que existe | O que o código faz | Fase que conserta |
|---|---|---|
| ~~Falha de cobertura por rolo descarregado~~ | ✅ **G3**: a carga cai de 1,00 pra 0,37 por carga e a falha aparece. Amplitude baixa até a Fase E | ~~G3~~ |
| Lap mark | Inerte — o salto medido é 0,023 s contra um limiar de 0,35 s | G4 |
| ~~Mancha de secagem vinda da espessura~~ | ✅ **G1**: campo de 4 termos, razão medida 2,27–2,33 (era 1,00) | ~~G1~~ |
| ~~A 2ª demão cobrir falha da 1ª~~ | ✅ **G3**: o fundo tem história; salto de 0,1 de 255 na troca contra 57 quando o rolo passa | ~~G3~~ |
| ~~`duracao_total()` corresponder ao que está na tela~~ | ✅ **G1**: espera morta 21% → 3,9%. `ESPESSURA_TIPICA` não estava 7× alta, estava **10× alta** — o depósito medido é 0,033, não 0,35 | ~~G1~~ |

**A arquitetura da Fase B está certa** — máscara, carimbos, UV por posição de mundo, brilho e cor em
curvas separadas. O que falta é calibração e um canal de textura. Não reescrever.

**Atualização de 03/08/2026 (G1):** as duas linhas riscadas caíram, e a lição vale pras que sobraram
— **os três "inertes" restantes são todos erro de escala, não de arquitetura.** No caso da mancha, a
causa era um centro chumbado (`relevo - 0.5`) que só batia porque `preencher_coberta` grava 0,5;
numa parede pintada do zero o termo virava um escurecimento chapado. Antes de mexer em G3 ou G4,
**medir o valor real lendo a máscara de volta** — foi o que resolveu aqui, e o número medido não
tinha nada a ver com o que estava no código.

### 3.5 Pendências conhecidas no código

Coisas pequenas achadas na auditoria, sem dono de fase. Baratas, e cada uma é uma pegadinha pra quem
for ler o código depois.

- `ciclo_pintura.gd::_duracao_secagem_padrao()` — **código morto**, nunca é chamado
- `trajeto_rolo.gd::CARGA_MINIMA` — **inalcançável**: o consumo máximo por carga é 0,182, então o
  piso de 0,80 nunca entra em ação
- ~~**Duas molduras de porta sobrepostas**~~ — ✅ **resolvido na Fase G6**: `props_quarto.gd::_moldura_porta`
  foi apagada, ficou a de `porta.gd::_criar_batentes`
- `quarto.tscn` grava `ambient_light_color`/`energy` no `Environment` que **`ambiente_dia.gd`
  sobrescreve em runtime** — editar pelo Inspector não faz nada (ver 3.1)
- ~~O rolo anda **17% mais rápido** nas paredes de 7 m que nas de 6 m~~ — ✅ **resolvido na Fase G6**:
  com o quarto quadrado as 4 varreduras têm a mesma largura, então a velocidade do rolo é a mesma

### 3.6 Coisas já tentadas e descartadas ou revertidas

- Layout em L com puxadinho — trocado pelo retangular atual
- **Ciclo de dia e noite** (`ciclo_dia_noite.gd`, removido em 31/07/2026) — girava sol e lua e
  interpolava cor de luz, céu, ambiente e névoa ao longo do dia. Saiu por decisão do usuário:
  atrapalhava mais do que ajudava. O jogo é observar uma parede secar devagar, e a luz mudando por
  baixo competia com a única coisa que deveria estar mudando; amanhecer e entardecer eram os piores,
  porque tingiam o quarto inteiro de laranja bem no meio da observação — e a tinta azul chegava a
  ler como roxa. Substituído por `ambiente_dia.gd`, luz fixa de meio da tarde. Junto saíram a `Lua`,
  a `LuzNoite` e o `ModoJogo.DURACAO_DIA`
- Tinta molhada com `roughness` bem baixo (quase espelho) — refletia o céu processual e quebrava a
  parede em blocos visíveis. Molhado agora é só um pouco mais brilhoso que seco
- Normal map no teto — virava rabisco agressivo sob a luz rasante da lâmpada
- Normal map e ruído triplanar nas paredes — saíram na Fase C: em low-poly, superfície chapada é a
  proposta, e micro-relevo fingido só denuncia a face plana quando a luz raspa
- Textura de nuvem reusando `criar_textura_ruido` sem alfa variando — dava véu uniforme, não nuvem.
  Precisou de `color_ramp` controlando alfa
- **Frente de pintura calculada por varredura** — a tinta deduzia "quando fui pintado" projetando a
  posição num eixo, o que limitava a pintura a uma linha reta atravessando a parede. Trocada pela
  máscara do rolo (Fase B). O ajuste antigo de borda larga + ruído em duas escalas era maquiagem
  sobre esse limite
- **FXAA** (Fase G5) — medido contra referência supersampleada e deu **pior que não fazer nada**
  (erro 0,241 contra 0,173). Ele borra pra longe da imagem certa em vez de resolver detalhe: a linha
  fina da almofada da porta continuava pontilhada com FXAA e virou contínua com supersampling
- **TAA** (Fase G5) — a ressalva prevista era borrar a frente do rolo; o problema real foi maior:
  **ele alisou a variação da parede inteira**, que é o assunto do jogo, mais ghosting no canto ao
  mover a câmera. Câmera parada e movimento lento não bastam pra salvar TAA quando o sinal que
  interessa é justamente uma textura de baixo contraste
- **`scaling_3d/scale = 1.5`** (Fase G5) — parece um meio-termo econômico e não é: dá 0,143 de erro
  contra 0,173 de não fazer nada. O downsample do Godot é bilinear e **só em 2,0× os quatro taps
  caem simétricos e viram média de caixa 2 × 2**. A escala é escolha binária: 1,0 ou 2,0

### 3.7 Estado do rig — ambíguo, conferir ANTES de continuar a Fase D

⚠️ **Dois trechos do `PLANO-OVERHAUL-TINTA.md` §5.9 se contradizem e ninguém resolveu:**

- O passo 8 está ✅ — "regerar `*_modelo.tscn` no Godot", o que sugere que o rig de **19 ossos já
  está no jogo**
- A nota do `.blend` logo abaixo diz que `Tio`/`Tio_Armature` (**7 ossos**) "é o que está no jogo
  hoje"
- E o passo 12 ("religar `tio.gd`/`garotinha.gd` e re-testar câmeras/colisão") continua ⬜

**Antes de mexer em qualquer coisa de personagem, rodar esta checagem e anotar o resultado aqui:**

1. Abrir `res://models/tio_modelo.tscn` e contar os ossos do `Skeleton3D`. **19 = rig novo em uso;
   7 = rig antigo.**
2. Conferir se existe `TwoBoneIK3D`/`LookAtModifier3D` na árvore (o passo 9 diz que sim, com
   `active = false`).
3. `grep` em `tio.gd` pelos nomes de osso e de clipe, pra ver se batem com o rig encontrado.

Sem isso, o risco concreto é **refazer o rig inteiro no Blender achando que a Fase D não começou** —
ela está em ~10 de 12 passos.

**O rolo na mão do tio** (ideia levantada antes) **não é item solto**: já é a Fase E ("Props: rolo na
mão, bandeja no chão, banquinho"). Com a máscara, o rolo e o desenho já são a mesma coisa
(`trajeto_rolo.gd::posicao_atual`) — falta o mesh, prendê-lo na mão e ligar o `TwoBoneIK3D` que o
passo 9 já deixou montado.

---

## 4. O que fazer agora

Três etapas até "entregável na Steam", em ordem. Cada uma fecha antes da seguinte começar — a
ordem não é arbitrária: não adianta fazer screenshot de loja antes de o jogo estar com a cara
final, nem traduzir texto que ainda pode mudar.

| Etapa | O que é | Estado |
|---|---|---|
| **1. Overhaul do miolo** | Parede, tinta, secagem, animação do tio, apresentação | Em andamento — ver quadro abaixo |
| **2. Fechamento de conteúdo** | Branding/logo, créditos, tradução dos 5 idiomas pendentes | Não começou (depende da 1 pro visual final) |
| **3. Steam** | `export_presets`, GodotSteam, conquistas, página de loja, build | Não começou |

### Etapa 1 — Overhaul do miolo (em andamento)

A tinta deixou de ser função da posição no shader e virou uma **máscara carimbada pelo trajeto real
do rolo**; o tio ganha rig com cotovelo/joelho/coluna e **IK nativa do Godot 4.6+**; a direção de
arte virou **low-poly assumida**. As duas peças de engine que viabilizam isso (`DrawableTexture2D`
no 4.7 e o retorno da IK no 4.6) chegaram depois deste projeto ser arquitetado.

Reabre a antiga **Fase 1.2** (o rig de 7 ossos não sustenta agachar nem esticar) e acrescenta uma
frente de material/shader que o roadmap original não previa.

#### Quadro das fases

| Fase | O que entrega | Depende de | Spec | Estado |
|---|---|---|---|---|
| **A** | Spike do `DrawableTexture2D` (a doc oficial do 4.7 está errada sobre `texture_blit`) | — | OVERHAUL §3.7, §6 | ✅ |
| **B** | Máscara de tinta — `tinta_secando.gd` virou `parede_pintavel.gd` | A | OVERHAUL §3, §6 | ✅ (os "números inertes" eram um centro chumbado — resolvido na G1) |
| **C** | Low-poly: assoalho em geometria, props, normal maps fora, SSAO/MSAA, `AreaLight3D` | — | OVERHAUL §4, §6 | ✅ |
| **D** | Rig de 19 ossos + IK (cotovelo, joelho, coluna) | — | OVERHAUL §5 | 🟡 **~10 de 12 passos** — ver 3.7, conferir antes |
| **E** | Coreografia: W, verticais, banquinho, rodapé, bandeja, rolo na mão | D, G6 | OVERHAUL §5.5, §6 | ⬜ |
| **F** | Refino: som do rolo casado com a mão, passo, porta, o tio olhar pra ela, gravar 60 s | D, E | OVERHAUL §6 | ⬜ |
| **G1** | **Campo de secagem** — a parede passa a secar desigual e a fase manchada existe | — | SECAGEM §3.1, §5, §5.1 | ✅ |
| **G2** | Cor (saturação antes de valor) e brilho rasante | G1 | SECAGEM §3.3, §3.4, §5.2 | ✅ (bead inerte até E) |
| **G3** | Cobertura com história — a 2ª demão passa a ter função | G1 | SECAGEM §3.6, §3.7, §5.3 | ✅ (amplitude baixa até E) |
| **G4** | Lap mark relativo e tempo de pintura por modo | E | SECAGEM §3.8, §3.9 | ⬜ |
| **G5** | **Nitidez** — supersampling, debanding, fim do cintilar | — | SECAGEM §7.1, §7.5 | ✅ |
| **G6** | **Quarto 6 × 6, janela centrada, fresta da porta, tamanho de tela** | — | SECAGEM §6, §7.2, §7.3 | ✅ |

`OVERHAUL` = `PLANO-OVERHAUL-TINTA.md` · `SECAGEM` = `PLANO-SECAGEM-E-QUARTO.md`

#### Ordem recomendada, com o motivo de cada posição

A ordem **não é obrigatória** onde não há dependência, mas esta é a que entrega valor mais cedo e
evita retrabalho. Cada item traz a definição de pronto — o que precisa ser verdade pra marcar `[x]`.

1. `[x]` **G6 — quarto 6 × 6, janela centrada, porta, tela.** ✅ *Primeiro porque trava geometria:*
   E escreve coreografia contra a largura das paredes, e o `LightmapGI` só pode ser assado depois
   que o quarto parar de mudar. Fazer isso depois de E significa reescrever E.
   **Pronto quando:** as 4 paredes têm 18 m², a câmera está a 3,0 m de todas, não há linha clara
   sobre a porta fechada, e o jogo abre em 1600 × 900 redimensionável.
   **Verificado:** as 4 paredes deram 18,0 m² e máscara 876 × 438 cada; da câmera da cadeira
   (0,00 · 1,20 · −1,00) a distância é 3,00 m para norte, sul, leste e oeste; a porta fechada
   fotografada de esguelha não tem linha clara nenhuma; a janela ficou centrada na parede oeste
   (z ∈ [−1,85 · −0,15]); o jogo abre em 1600 × 900. Nenhum erro no log.
   **De quebra:** havia **duas** molduras de porta sobrepostas — `props_quarto.gd::_moldura_porta` e
   `porta.gd::_criar_batentes`. Ficou a de `porta.gd`, que é quem conhece as medidas da folha e por
   isso consegue fechar a fresta do topo. Isso encerra a pendência anotada em 3.4.
2. `[x]` **G5 — nitidez.** ✅ *Barato e independente.* Vem cedo porque muda a impressão geral do jogo
   mais que qualquer outro item por unidade de esforço, e porque todo teste visual das fases
   seguintes fica mais fácil de julgar numa imagem limpa.
   **Pronto quando:** girando a câmera devagar nada cintila (frestas do assoalho, maçaneta, marca do
   rolo) e não há banding no gradiente da parede em tela cheia.
   **Verificado:** medindo o erro contra uma referência supersampleada 3×, a configuração escolhida
   (`scaling_3d/scale=2.0` + MSAA 4× + debanding) dá **0,034 contra 0,173 de antes** — 5× menos
   aliasing, a 288 fps. Banding: 39% das linhas da parede eram faixas chapadas, agora 0%.
   ⚠️ **O plano pedia `scale = 1.5` e o número estava errado** — 1,5× dá 0,143, quase nada, porque o
   downsample do Godot é bilinear e só em 2,0× ele vira média de caixa 2 × 2 de verdade. FXAA e TAA
   foram medidos e **reprovados** (FXAA fica pior que não fazer nada; TAA apaga a marca do rolo).
   Detalhe em SECAGEM §7.5.
3. `[x]` **G1 — campo de secagem.** ✅ *O item de maior retorno do projeto inteiro.* É o assunto do
   jogo. Hoje a parede toda seca dentro de 0,4 s de diferença e o modo Realista é duas horas de
   retângulo uniforme.
   **Pronto quando:** a razão entre o `duracao_local` máximo e o mínimo de uma parede é ≥ 1,5; a
   parede fica visivelmente manchada no meio da secagem e uniforme no fim.
   **Verificado:** razão **2,27–2,33** nas 4 paredes e nas 3 demãos, com só 0,1–0,3% da parede
   tocando o clamp. Isolando a mancha (render com e sem a textura), a contribuição dela vai de 0,00
   (molhada) a **0,86** no meio e volta a 0,00 (seca) — é um evento com começo e fim. Espera morta
   21% → 2,3% (o 2,3% veio depois, com o ajuste de curvas da G2).
   ⚠️ **Três números do plano estavam errados**, todos achados medindo: a espessura tem que vir da
   máscara **recente** (com a acumulada, a dispersão crescia a cada demão em vez de encolher), o
   `relevo_base` precisa ser **medido** por demão (o acumulador vale 0,5 vindo de save), e o anúncio
   de conclusão usa um **percentil**, não o teto do clamp. Detalhe em SECAGEM §5.1.
4. `[x]` **G2 — cor e brilho.** ✅ Depende de G1 (mesmo shader, e o véu só pode baixar depois que a
   estrutura existir).
   **Pronto quando:** dá pra dizer onde a parede ainda está molhada só movendo a câmera.
   **Verificado:** a aparência da parede molhada varia de 0,432 a 0,718 conforme a geometria de vista;
   a seca varia de 0,288 a 0,300. **22× mais sensível ao ângulo.** O véu caiu de 0,55 pra 0,32 e a
   secagem ficou **mais** visível, não menos: 47,4 valores de 255 de percurso contra ~34 de antes,
   porque agora a saturação e o valor somam em vez de a saturação fazer tudo. Cotovelo de 28%.
   De quebra, ajustar as curvas fechou a espera morta da G1 de 3,9% pra **2,3%** — dentro do aceite.
   ⚠️ **O bead está implementado e inerte até a Fase E** — ele é gravidade e precisa de borda de baixo
   no traço; o trajeto atual são passadas verticais de altura inteira. Anotado em SECAGEM §5.2 pra
   não virar mais um "número inerte" esquecido.
5. `[x]` **G3 — cobertura com história.** ✅ Fecha o que a Fase B prometeu e não entregou.
   **Pronto quando:** uma falha da 1ª demão continua visível durante a 2ª e some **quando o rolo
   passa por cima**, não no instante em que a demão começa.
   **Verificado:** no ponto de pior cobertura da 1ª demão, a mudança ao trocar de demão é **0,1 de
   255** contra **57,2** quando o rolo passa por cima; na parede inteira o salto médio é 1,2. E a
   falha da 1ª demão está lá na captura do começo da 2ª. A chave foi o histórico guardar
   **o valor de cobertura que o shader mostrou**, não a máscara crua — duas versões com máscara crua
   falharam, uma por saturação do acumulador (a 2ª e a 3ª demão paravam de aparecer) e outra por
   comparar grandezas diferentes (salto de 130 de 255 no pior ponto).
   ⚠️ **A amplitude da falha está baixa de propósito.** Com passadas de altura inteira, uma carga
   dura 3 passadas e qualquer variação vira barra vertical — testei de 42% a 85% de cobertura mínima
   e o padrão de listra não muda, só o contraste. Abre na Fase E. Ver SECAGEM §5.3.
6. `[ ]` **D — rig + IK.** ⚠️ **Conferir 3.7 antes de tocar em qualquer coisa** — ela está em ~10 de
   12 passos e o risco real é refazer o Blender inteiro à toa. Faltam a camada procedural (altura do
   quadril, inclinação do torso), virar o corpo na direção do movimento, e religar `tio.gd`.
   **Pronto quando:** o tio agacha e estica com os pés no chão, vira o corpo antes de andar, e
   ninguém teleporta na porta.
7. `[ ]` **E — coreografia.** Depende de D e de G6. É onde o rolo entra na mão e o trajeto vira W +
   verticais + banquinho + rodapé + bandeja.
   **Pronto quando:** pausando durante a pintura, a tinta na parede corresponde exatamente ao que o
   rolo tocou, incluindo o formato do W.
8. `[ ]` **G4 — lap mark relativo e tempo de pintura por modo.** Só faz sentido depois de E: com o
   zigue-zague atual, esticar a pintura pra 180 s é esticar a monotonia.
   **Pronto quando:** o lap mark aparece onde ele volta num trecho pintado minutos antes, e não
   aparece onde ele pinta seguido.
9. `[ ]` **F — refino e verificação.** Som do rolo casado com a velocidade real da mão (hoje é timer
   fixo de 1,16 s, desligado do movimento), som de passo e de porta, o tio olhar pra garotinha.
   **Pronto quando:** gravar 60 s, assistir inteiro e dar vontade de continuar olhando.
10. `[ ]` **`LightmapGI`** (ver "Candidato técnico" abaixo). Por último dentro da Etapa 1, porque
    trava a geometria de vez.

**Se só der pra fazer uma coisa:** G1. **Se só der pra fazer meia hora:** G6 item de tela + G5.

#### Features de jogo decididas em 01/08/2026

Saíram de uma rodada de sugestões. As duas últimas entraram na **Fase F**; a primeira é feature de
jogo e não pertence a fase nenhuma.

- `[ ]` **Timer da demão, opcional nas Opções.** Mostra quanto falta a demão atual terminar de
  secar, com liga/desliga na tela de Opções (junto de volume e tela cheia, em `opcoes.gd` —
  persiste em `user://config.cfg` como os outros). **Desligado por padrão**: num jogo cuja proposta
  é esperar sem pressa, contador na tela muda o tom, então quem quiser a informação escolhe tê-la.
  O dado já existe — `ParedePintavel.get_fracao_seca()` e `duracao_total()`.
  ⚠️ **Depende de G1**: hoje `duracao_total()` erra por ~18% (ver 3.4), então o timer mostraria um
  número que não corresponde à tela
- `[ ]` Som de passo e de porta — ver Fase F
- `[ ]` Tio olhar pra garotinha — ver Fase F

**Recusado explicitamente:** vida na janela (pássaro, folhas, gente passando na rua) e poeira na luz.
**Adiado:** opções mínimas de acessibilidade (sensibilidade de mouse, inverter eixo), a garotinha
ficar visível depois de sentar, e qualquer outro feedback de progresso além do timer.

### Etapa 2 — Fechamento de conteúdo

Depende da Etapa 1: logo e screenshots precisam do visual definitivo, e não vale traduzir texto que
ainda pode mudar.

- `[ ]` Título definitivo — "Watching Paint Dry" fica irônico ou vira nome de loja de verdade?
- `[ ]` Logo, ícone e capa — usuário vai procurar no Design do Claude
- `[ ]` Botão de créditos
- `[ ]` Traduzir de verdade `es`/`fr`/`zh_CN`/`ja`/`de` — hoje só existem como coluna vazia no
  `textos.csv` e caem no fallback pt-BR (a infraestrutura está pronta, falta o texto)
- `[ ]` Screenshots pra loja

### Etapa 3 — Steam

- `[ ]` Criar `export_presets.cfg` (não existe ainda) — presets Windows/Linux/Mac
- `[ ]` Criar conta Steamworks (Steam Direct, US$100)
- `[ ]` Integrar GodotSteam: inicialização básica da API
- `[ ]` Ligar as conquistas existentes (`conquistas.gd`, hoje só locais em `user://save.tres`) à API
  de conquistas da Steam
- `[ ]` Página de loja com o branding da Etapa 2
- `[ ]` Build de depósito e primeiro upload (branch de teste antes de público)

### Candidato técnico, sem etapa fixa

- `[ ]` **`LightmapGI`** — virou viável quando a luz deixou de ser dinâmica (ciclo de dia removido).
  Assa sombra e luz indireta numa textura: melhor qualidade e frame mais barato. **Trava a
  geometria** — mexer em parede ou props depois obriga re-bake, então faz sentido só depois da
  Etapa 1 fechar. **Ganhou dono:** é o item que de fato iguala a luz entre as 4 paredes (a falta de
  interreflexão é o que faz a parede longe parecer na sombra). Ver `PLANO-SECAGEM-E-QUARTO.md` 6.5,
  inclusive a armadilha de assar parede com `ShaderMaterial` de albedo que muda — as paredes têm que
  ficar como GI dinâmica, o resto do quarto como estático

### Histórico — rodadas já concluídas

Mantido pelo registro das decisões (por que cada coisa é como é), não como lista de tarefas.

#### Setup de ferramentas

- `[x]` Godot MCP instalado (`addons/godot_mcp/` + permissões em `.claude/settings.local.json`)
- `[x]` Blender MCP — instalado e conectado de ponta a ponta (ver detalhe na seção 2)
- Nunca foram necessários: **Figma MCP** (o menu foi direto pro código), **ProtonScatter** (o
  espalhamento manual com seed fixa bastou) e **Dialogue Manager** (o diálogo continua sendo
  "gostei"/"trocar"). **GodotSteam** fica pra Etapa 3

#### Polish de menu, UI e mundo externo

**Menu e UI**
- **Pulado** — wireframe no Figma. Foi direto pra código; o Figma MCP nunca chegou a ser configurado
  e não fez falta
- `[x]` Paleta de cor/fonte/estilo — `resources/ui/theme_principal.tres`, tons madeira/tinta,
  aplicado globalmente via `project.godot::[gui]`
- `[x]` Transição entre painéis — crossfade curto (`DURACAO_FADE = 0.15`) em
  `menu_principal.gd`/`menu_pausa.gd`/`dialogo_pintura.gd`, substituindo `show()`/`hide()` seco
- `[x]` Tela de Opções — `opcoes.gd` (autoload `Opcoes`, persiste em `user://config.cfg`) +
  `painel_opcoes.gd`/`.tscn`, reusado no menu principal e no menu de pausa. Conteúdo hoje é volume
  **mestre** (não separado por música/SFX — não existe trilha/música ainda, então não fazia
  sentido separar) e tela cheia

**Animação de personagens** — ⚠️ **superada pela Fase D do overhaul.** O rig de 7 ossos descrito
aqui não sustenta agachar nem esticar (braço de 1 osso só), então vai ser refeito com 19 ossos + IK.
O que continua valendo deste bloco: as medidas dos personagens, o pipeline Blender→Godot e as
armadilhas de export.

- `[x]` Decisão: modelo rigado via Blender — confirmado explicitamente, contra a recomendação
  inicial (procedural seria mais rápido/barato de iterar). Trade-off aceito conscientemente: mais
  trabalho de pipeline em troca de visual mais rico
- `[x]` Setup: Blender + Blender MCP instalados e conectados (ver Fase 0) — pronto pra modelar
- `[x]` Modelagem — os 2 personagens modelados no Blender (6 partes cada: torso, cabeça, 2 pernas,
  2 braços), silhueta validada por screenshot contra o placeholder:
  - Tio: torso (cápsula raio 0.22, altura 0.7), cabeça (esfera raio 0.15), 2 pernas (raio 0.12,
    altura 0.9), 2 braços (raio 0.08, altura 0.5, pivô no ombro em y=1.35). Roupa
    Color(0.32, 0.42, 0.52), pele Color(0.85, 0.68, 0.52)
  - Garotinha: medidas próprias de `garotinha.gd` (não é simples Tio×0.78 — proporção de criança,
    cabeça relativamente maior), vestido Color(0.85, 0.55, 0.62)
- `[x]` Rig — hierarquia de 7 ossos (raiz Quadril + 6), posições em Y recalculadas a partir da
  cápsulas em `tio.gd` (garotinha é a mesma hierarquia × `ESCALA_CRIANCA` 0.78). **Correção**: a
  versão anterior deste diagrama usava y=0.45 pro quadril — esse valor é o *centro* da cápsula da
  perna (`position` no código), não a altura do quadril. A perna (raio 0.12, altura 0.9, centro
  y=0.45) vai do chão até y=0.9, então o quadril de verdade fica em y≈0.85 (onde perna encontra a
  base do torso). Corrigido e já validado visualmente no Blender (modelo montado bate com o
  placeholder atual):
  ```
  Quadril (raiz, y=0.85 — topo da perna/base do torso)
  ├── Coluna (y=0.85 até y=1.35 — do quadril até a altura do ombro, bate com o pivô de braço atual)
  │   ├── Cabeça (y=1.35 até y=1.8 — ombro até o topo da cabeça atual)
  │   ├── Braço_Esquerdo (nasce em x=-0.28, y=1.35 — mesmo ponto do PivoBracoEsquerdo hoje)
  │   └── Braço_Direito (nasce em x=0.28, y=1.35 — mesmo ponto do PivoBracoDireito hoje)
  ├── Perna_Esquerda (nasce em x=-0.12, y=0.85, desce até y=0 — chão)
  └── Perna_Direita (nasce em x=0.12, y=0.85, desce até y=0 — chão)
  ```
  Sem coluna curvando (1 osso é suficiente, torso não se dobra hoje) e sem cotovelo/pulso (braço é
  1 osso só, mesmo nível de detalhe do pivô atual). Pele (skinning/weight paint) é peso 1.0 por
  vértice pro osso mais próximo — sem necessidade de blend entre ossos, as peças não se sobrepõem
- `[x]` Animações — `andar` (loop, pernas, ~25° alternado) e `pintar_braco` (loop, braço direito,
  -0.9 a 0.1 rad) exportadas como clipes reais do `AnimationPlayer`. `pintar_varrendo()` toca as
  duas ao mesmo tempo — decisão de blend resolvida com **dois `AnimationPlayer`** compartilhando a
  mesma `AnimationLibrary` (um só pra pernas, outro só pro braço); como os clipes não tocam osso
  em comum, não precisou de `AnimationTree`. `sentar` da garotinha continua sendo só o Tween de
  posição Y de sempre (não virou clipe — janela de visibilidade curta demais pra valer a pena)
- `[x]` Pipeline executado via Blender MCP + Godot MCP, direto por mim (Claude Code) nesta sessão.
  **Três armadilhas reais encontradas, documentadas aqui pra não repetir**:
  - **Ordem de `keyframe_insert` importa.** `bpy.context.scene.frame_set(frame)` chamado *depois*
    de setar o valor e *antes* do `keyframe_insert()` reavalia o depsgraph e reescreve o valor pro
    que já existia na curva (efeito: toda chave nova virava cópia da primeira). Correto é setar o
    valor e inserir com `frame=` explícito, sem tocar o frame atual da cena
  - **`export_optimize_animation_size` (Blender, default `true`) quebra loops perfeitos.** Quando a
    entrada e a saída do range voltam pro mesmo valor (caso de qualquer clipe cíclico), o otimizador
    às vezes descarta o meio e vira `STEP` com 2 chaves idênticas. Desligar
    (`export_optimize_animation_size=False`) no `export_scene.gltf`
  - **`GLTFDocument.generate_scene()` deixa `ImporterMeshInstance3D`, não `MeshInstance3D`.** É um
    nó só de editor, não renderiza em jogo de verdade — o import padrão (`.glb` direto, sem passar
    por `GLTFDocument` manual) já faz essa conversão sozinho. Ao gerar cena via `GLTFDocument`
    (necessário aqui pra plugar o segundo `AnimationPlayer`), converter manualmente: criar
    `MeshInstance3D`, copiar `mesh.get_mesh()` / `skin` / `skeleton_path→skeleton` / `layers`
  - Menor: um `Tio_Armature.location.x = -2.0` deixado no Blender (deslocado só pra abrir espaço de
    visualização ao lado da Garotinha) foi parar no `.glb` exportado e bagunçou a AABB do
    personagem — resetado antes do export final. Checar `location` do objeto armadura antes de
    exportar se ele foi movido durante a modelagem
- `[x]` Câmeras/colisão — não precisou mexer. AABB do modelo final bate exatamente com o
  placeholder antigo (Tio 1.8m de altura centrado em X=0, Garotinha idem em escala), porque as
  medidas de modelagem foram copiadas direto do código existente. Footprint espacial idêntico,
  câmera de cutscene/cadeira e colisão de porta/cadeira continuam válidas sem ajuste
- Arquivos gerados: `res://models/tio.glb`/`garotinha.glb` (export bruto do Blender, com as
  animações), `res://models/tio_modelo.tscn`/`garotinha_modelo.tscn` (cena Godot final, gerada via
  `GLTFDocument` + conversão manual de mesh — é isso que `tio.tscn`/`garotinha.tscn` instanciam,
  não o `.glb` direto), `res://models/fonte_blender/personagens.blend` (arquivo-fonte editável,
  os dois personagens rigados — abrir esse pra ajustar modelo/rig/animação no futuro em vez de
  remodelar do zero)

**Mundo externo**
- `[x]` Nova escala do jardim — 20×16 → 220×220 (`cenario_externo.gd::ALCANCE_JARDIM`). Não usou
  `ProtonScatter`, espalhamento manual por `RandomNumberGenerator` com seed fixa (mais simples pro
  volume de props envolvido, addon ficou sem necessidade)
- `[x]` Névoa — **removida** (01/08/2026). Existia pra esconder a borda do jardim; na prática o véu
  cobria o quarto inteiro, mesmo com `fog_depth_begin` de 10 m. Sem ela a vista pela janela continua
  legível (jardim de 220 m já é fundo suficiente) e o quarto para de parecer lavado.
  `ambiente_dia.gd::_configurar_ambiente` agora força `fog_enabled = false`
- `[x]` Mais casas — 2 casas + 10 árvores extras em profundidade variável
  (`cenario_externo.gd::_criar_decoracao_distante`), seed fixa (4477)
- `[x]` **Rua residencial** (01/08/2026) — asfalto de 16 m → 90 m em Z (rua que termina à vista lê
  como cenário de teatro), calçada dos dois lados, fila de 7 casas do outro lado espaçadas de 9 m +
  2 vizinhos do lado de cá, e árvores alinhadas na calçada (`cenario_externo.gd::_criar_vizinhanca`,
  seed 8801). `_criar_casa` virou paramétrica (cor de corpo, cor de telhado, escala) — sem variação
  a fila denuncia o loop
- `[x]` **Nenhuma árvore no eixo da janela** — a que ficava em `(X-2.2, Z+0.3)` picotava a luz do sol
  no chão do quarto: a mancha saía rendilhada de sombra de copa, com cara de defeito de render.
  Regra: nada em `Z ∈ [-2, +2]` a oeste, porque o sol vem do oeste na horizontal
- `[x]` **Sombra do sol com alcance curto** — `directional_shadow_max_distance` 100 (padrão) → 45 m
  (`ambiente_dia.gd::ALCANCE_SOMBRA`). O padrão espalhava o mapa por um jardim de 220 m e sobrava
  pouco texel perto da janela; era a outra metade da mancha de luz picotada
- `[x]` **Luz de preenchimento só do lado de fora** — o sol vem do oeste, então tudo que a janela
  enquadra está de costas pra ele e as fachadas ficavam chapadas de cinza. Uma `DirectionalLight3D`
  fraca vinda do leste, sem sombra, com `light_cull_mask` na `CAMADA_EXTERNA` (bit 2, aplicado a
  todo mesh de `cenario_externo.gd`) acende só a vizinhança. Ambiente global não serve pra isso:
  ele volta a lavar as paredes do quarto

- `[x]` **Janelas nas casas da vizinhança** — duas por fachada + porta da frente, com **vidro
  opaco** (painel escuro chapado, sem transparência). Vidro de verdade só entregaria que a casa é
  uma caixa vazia por dentro; da rua, janela é retângulo escuro refletindo céu
  (`cenario_externo.gd::_criar_janelas_casa`)

**Cômodo vizinho (o que se vê pela porta)**
- `[x]` `scripts/comodo_vizinho.gd` + nó `ComodoVizinho` em `quarto.tscn` (01/08/2026). Antes a porta
  abria pro vazio preto, denunciando que o quarto é uma caixa solta. É uma sala/cozinha *sugerida*,
  vista só de raspão pelo vão: piso frio de porcelanato 60×60 (peças de verdade + fresta de rejunte,
  igual ao assoalho — geometria em vez de normal map), parede amarelo-clara, rodapé, bancada com
  tampo escuro, armário aéreo e geladeira (é a silhueta da geladeira que faz ler "cozinha"). Luz de
  teto própria, mais fria e fraca que a do quarto, pra o vão ler como *outro* ambiente
- **Piso frio brigava por z** — a peça de porcelanato e o contrapiso tinham o topo no MESMO plano
  (`y = 0`), e o piso piscava manchas brancas conforme a câmera mexia. Corrigido com o mesmo
  `+0.004` do assoalho do quarto: a peça fica um fio acima do contrapiso
- Ocupa `X ∈ [+3.6, +10.0]`, `Z ∈ [-4.0, +2.0]` — o Z bate com o do quarto de propósito: a parede
  leste já fecha esse lado, então não sobra fresta de luz entre os dois cômodos. Sem colisão, sem
  `_process`, nada jogável

**Menu — save, idioma e fundo** (o que sobrou desta rodada — título, logo e créditos foram pra
Etapa 2)

- `[x]` **"Continuar" com save local** — já existia (não foi criado agora): `EstadoJogo`/
  `DadosSalvos` salvam em `user://save.tres`, botão só aparece com `EstadoJogo.existe_save()`
  (`menu_principal.gd`). Confirmado com o usuário que é isso mesmo que ele queria
- `[x]` **Fundo do menu**: cena do jogo borrada, câmera girando devagar. Decisão: cena dedicada
  leve (não o `quarto.tscn` de verdade rodando) — `scenes/fundo_menu.tscn` +
  `scripts/fundo_menu.gd` herda `inicializar_quarto.gd` via `extends
  "res://scripts/inicializar_quarto.gd"` (reusa toda a geometria estática: chão, teto, paredes,
  janela, lâmpada, cadeira — nada de `_process`, sem tinta/personagens/ciclo dia-noite), e pinta as
  paredes com a cor azul seca (senão ficam sem material, já que normalmente é
  `tinta_secando.gd` quem cuida disso). `camera_orbital_menu.gd` orbita devagar (2.5°/s, ~144s por
  volta, raio 2.3 pra não atravessar parede). Renderizado num `SubViewport` (960×540) dentro de
  `menu_principal.tscn`, com `shaders/blur_fundo.gdshader` (box blur + tingimento escuro) aplicado
  via `material` do `SubViewportContainer`
- `[x]` **Seletor de idioma**, canto superior direito do menu principal (`OptionButton`
  `SeletorIdioma`). Ver seção 2 pra detalhe do sistema de localização (arquitetura, armadilhas de
  teste, e o que falta traduzir)
- **Encerrado** — Opções. O usuário confirmou que o conteúdo básico (volume mestre + tela cheia) já
  serve. ⚠️ Isso mudou depois: a Fase **G6** acrescenta seletor de resolução e conserta a volta da
  tela cheia (ver `PLANO-SECAGEM-E-QUARTO.md` §7.3)
- `[x]` **Apagar save** — lixeira (`BotaoExcluirSave`, texto "🗑") do lado do "Continuar", só some
  se tiver save; abre `PainelConfirmarExclusao` (mesmo padrão de crossfade dos outros painéis) com
  Apagar/Cancelar. `EstadoJogo.apagar_save()` **preserva conquistas e histórico de cores vistas**
  (`conquistas_desbloqueadas`, `cores_completas_*`) — decisão não pedida explicitamente, mas
  pareceu o padrão mais são: "apagar save" normalmente significa "recomeçar a partida", não "perder
  progresso permanente". Se não for isso que o usuário quer, é só falar que muda

---

## 5. Backlog — fora das três etapas

Nada aqui está agendado. Entra só se sobrar fôlego depois da Etapa 3, ou se virar prioridade.

- **Trilha sonora** — hoje só ambiente sintetizado + som de pincelada, nenhum arquivo de áudio.
  Se entrar, a tela de Opções passa a precisar de volume separado por música/SFX (hoje é só mestre,
  justamente porque não há o que separar)
- **Diálogo além de "gostei"/"trocar"** — só então o addon `Dialogue Manager` faria sentido
- **Mais props e mobília** no quarto
