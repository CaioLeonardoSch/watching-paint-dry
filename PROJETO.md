# Watching Paint Dry — Projeto

Documento único do projeto. Substitui `CLAUDE.md` (que virou só um ponteiro pra cá, de propósito —
não é carregado automaticamente em toda sessão), `CONCEITO-DO-JOGO.md` e `PLANO-EVOLUCAO-STEAM.md`.

Estrutura fixa, conteúdo que evolui:

1. **Porquê** — premissa, tom, direção criativa. Muda raramente.
2. **Como** — stack técnico, convenções, ferramentas disponíveis (skills, MCPs, addons). Atualiza
   conforme configuramos coisas novas.
3. **O que já foi feito** — estado atual do jogo, sistema por sistema. Atualiza conforme
   implementamos.
4. **O que fazer agora** — as três etapas até a Steam, com checkboxes, mais o histórico das rodadas
   já fechadas. Atualiza conforme avançamos e decidimos passos novos.
5. **Backlog** — o que não está agendado em etapa nenhuma.

Leia a seção 1 quando a dúvida for "por que isso existe"/"isso faz sentido pro jogo". Leia a seção
2 antes de mexer em código, pra saber convenções e o que já está disponível pra usar. Leia a seção 3
pra saber o que já existe antes de propor algo. A seção 4 é o backlog ativo — mantenha os checkboxes
atualizados conforme os itens forem concluídos ou surgirem novos.

O overhaul do miolo (tinta, parede, animação) tem documento próprio, **`PLANO-OVERHAUL-TINTA.md`**,
pra não inflar este. Quando ele fechar, o que sobreviver vira parágrafo na seção 3 daqui e aquele
arquivo pode morrer.

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

### Stack técnico

- Godot **4.7**, renderer Forward Plus
- Física: **Jolt Physics**
- Driver: **D3D12** no Windows
- Entry point: `res://scenes/menu_principal.tscn` (menu) → `res://scenes/quarto.tscn` (jogo)

### Convenções deste projeto

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

### Sistema de skills de gamedev

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

### Ferramentas externas — status de configuração

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

### Estado atual do jogo

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
  externo") — era ela a maior parte do véu — e vieram luzes menos fortes
  (`LuzJanela` 1.9→1.5, `LuzLampada` 1.2→0.85) e ambiente mais fraco e menos leitoso
  (`ambiente_dia.gd`: 0.24→0.14, cor 0.80,0.83,0.88→0.66,0.72,0.84)
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

### Layout do quarto (fonte da verdade)

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

### Coisas já tentadas e descartadas ou revertidas

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

### Ideia levantada, ainda não implementada

Pendurar um rolo na mão do tio. Com a máscara, o rolo e o desenho já são a mesma coisa
(`trajeto_rolo.gd::posicao_atual`) — falta só o mesh e prendê-lo na mão, o que casa com o rig da
Fase D.

---

## 4. O que fazer agora

Três etapas até "entregável na Steam", em ordem. Cada uma fecha antes da seguinte começar — a
ordem não é arbitrária: não adianta fazer screenshot de loja antes de o jogo estar com a cara
final, nem traduzir texto que ainda pode mudar.

| Etapa | O que é | Estado |
|---|---|---|
| **1. Overhaul do miolo** | Parede, tinta, secagem, animação do tio | Em andamento — A, B, C feitas; **faltam D, E, F** |
| **2. Fechamento de conteúdo** | Branding/logo, créditos, tradução dos 5 idiomas pendentes | Não começou (depende da 1 pro visual final) |
| **3. Steam** | `export_presets`, GodotSteam, conquistas, página de loja, build | Não começou |

### Etapa 1 — Overhaul do miolo (em andamento)

Plano completo em **`PLANO-OVERHAUL-TINTA.md`** (documento próprio, pra não inflar este). A tinta
deixou de ser função da posição no shader e virou uma **máscara carimbada pelo trajeto real do
rolo**; o tio ganha rig com cotovelo/joelho/coluna e **IK nativa do Godot 4.6+**; direção de arte
virou **low-poly assumida**. As duas peças de engine que viabilizam isso (`DrawableTexture2D` no 4.7
e o retorno da IK no 4.6) chegaram depois deste projeto ser arquitetado.

- `[x]` **Fase A** — spike técnica: `DrawableTexture2D` confirmado, API real levantada contra o
  compilador (a documentação oficial do 4.7 está errada sobre `texture_blit`)
- `[x]` **Fase B** — máscara de tinta. `tinta_secando.gd` aposentado, virou `parede_pintavel.gd`
- `[x]` **Fase C** — low-poly: assoalho em geometria, props, normal maps fora, SSAO/MSAA,
  `AreaLight3D`. Junto saiu o ciclo de dia e noite (ver "descartados" na seção 3)
- `[ ]` **Fase D** — rig de 19 ossos + IK. **É a fase mais cara e destrava a E**: hoje o braço tem
  1 osso e o tio não consegue agachar nem esticar, só girar o ombro
- `[ ]` **Fase E** — coreografia (W, verticais, banquinho, rodapé, bandeja). Pacing **já decidido**:
  ritmo honesto nas demãos, abertura acelerada (volta completa de 3-5 min)
- `[ ]` **Fase F** — refino: som do rolo casado com a velocidade real da mão (hoje é timer fixo de
  1,16 s, desligado do movimento), e o teste que importa — gravar 60 s e assistir inteiro

Reabre a antiga Fase 1.2 (rig de 7 ossos não sustenta agachar/esticar) e adiciona uma frente de
material/shader que o roadmap original não previa.

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
  Etapa 1 fechar

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
- `[ ]` Wireframe no Figma — pulado, foi direto pra código (Figma MCP nunca chegou a ser configurado)
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
- `[ ]` Opções — usuário confirmou que o conteúdo básico atual (volume mestre + tela cheia) já
  serve por enquanto, nada extra a fazer aqui nesta rodada
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
