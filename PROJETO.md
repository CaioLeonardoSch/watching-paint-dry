# Watching Paint Dry — Projeto

Documento único do projeto. Substitui `CLAUDE.md` (que virou só um ponteiro pra cá, de propósito —
não é carregado automaticamente em toda sessão), `CONCEITO-DO-JOGO.md` e `PLANO-EVOLUCAO-STEAM.md`.

Estrutura fixa, conteúdo que evolui:

1. **Porquê** — premissa, tom, direção criativa. Muda raramente.
2. **Como** — stack técnico, convenções, ferramentas disponíveis (skills, MCPs, addons). Atualiza
   conforme configuramos coisas novas.
3. **O que já foi feito** — estado atual do jogo, sistema por sistema. Atualiza conforme
   implementamos.
4. **O que fazer agora** — plano de ação com checkboxes. Atualiza conforme avançamos e decidimos
   passos novos.

Leia a seção 1 quando a dúvida for "por que isso existe"/"isso faz sentido pro jogo". Leia a seção
2 antes de mexer em código, pra saber convenções e o que já está disponível pra usar. Leia a seção 3
pra saber o que já existe antes de propor algo. A seção 4 é o backlog ativo — mantenha os checkboxes
atualizados conforme os itens forem concluídos ou surgirem novos.

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
  antes de aplicar material (ver `tinta_secando.gd::_setup`)
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
- `[ ]` **Figma MCP** — pra desenhar telas de UI/menu visualmente antes de virar código Godot.
  Ainda não configurado.
- `[ ]` **Blender MCP** — só necessário se decidirmos sair de cápsula geométrica pra modelo 3D
  rigado. Decisão ainda pendente (ver seção 4, item de animação de personagens) — mas não é mais
  bloqueada por convenção do projeto, já que asset externo passou a ser opção válida.
- `[ ]` **GodotSteam** — GDExtension pra Steamworks (achievements, etc.). Vem mais pra frente,
  junto da integração Steam.
- `[ ]` **ProtonScatter** (addon Godot, Asset Library) — espalha árvores/props em regra. Candidato
  pro mundo externo.
- `[ ]` **Dialogue Manager** (addon Godot, Asset Library) — editor de diálogo não-linear. Só entra
  se o diálogo da garotinha crescer além do "gostei"/"trocar" atual.

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
  violeta/rosa são as 6 que batem com as conquistas de cor. Personagens são bonecos placeholder
  geométricos (cápsulas/esfera, sem asset externo, sem rig), animados com `Tween`
- **Fase 2 — ambientação:** ciclo de dia e noite (`ciclo_dia_noite.gd`) — sol e lua giram em lados
  opostos, cor da luz/céu seguem `Gradient`s com paradas densas perto do nascer/pôr do sol, nuvens
  via `sky_cover` com alfa por `color_ramp`; cenário externo pela janela (`cenario_externo.gd`) —
  jardim, 3 árvores, rua e uma casa, tudo primitivas; som ambiente sintetizado
  (`som_ambiente.gd`/`som_pincelada.gd`, sem nenhum arquivo de áudio)
- **Fase 3 — menu, modos, save, conquistas:** `estado_jogo.gd` é o autoload `EstadoJogo`, guarda
  modo ativo e `DadosSalvos` salvo em `user://save.tres`. Menu inicial oferece Jogar (seletor de
  modo Rápido/Normal/Realista) ou Continuar, mais visualizador de conquistas. `tinta_secando.gd` e
  `ciclo_dia_noite.gd` se autoconfiguram a partir do modo ativo (tempo de secagem e duração do dia
  mudam por modo — Realista é 2h/demão e dia de 24h). Menu de pausa (ESC) pausa a árvore de
  verdade (`get_tree().paused`). Conquistas (`conquistas.gd`, 10 no total, texto fixo) disparam ao
  completar ciclo de 3 demãos de uma cor, com toast e persistência entre sessões
- **Refinamento pós-roadmap:** porta de verdade (`porta.gd`/`porta.tscn`) com maçaneta de latão,
  abre/fecha por `Tween`, orquestrada por `ciclo_pintura.gd`; cadeira de madeira em `(0, 0, -1)`;
  assoalho procedural (`shaders/assoalho.gdshader`) com tábuas, juntas e normal map por diferença
  finita; paredes/chão com textura triplanar + normal procedural (`materiais_procedurais.gd`); teto
  liso de propósito (sem normal map — luz rasante da lâmpada vira rabisco); tinta com frente de
  pintura que varre a parede no sentido em que o tio anda, com atraso direcional na secagem

### Layout do quarto (fonte da verdade)

```
Quarto:  X ∈ [-3.5, +3.5],  Z ∈ [-4.0, +2.0]

Norte (-Z) = FRENTE  → parede sólida com tinta secando (ParedeNorteSolida)
Sul   (+Z) = ATRÁS   → parede fechada (ParedeSul)
Oeste (-X) = ESQUERDA → janela (com vidro translúcido/refração)
Leste (+X) = DIREITA  → porta (folha com maçaneta, abre e fecha)
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
- Tinta molhada com `roughness` bem baixo (quase espelho) — refletia o céu processual e quebrava a
  parede em blocos visíveis. Molhado agora é só um pouco mais brilhoso que seco
- Normal map no teto — virava rabisco agressivo sob a luz rasante da lâmpada
- Textura de nuvem reusando `criar_textura_ruido` sem alfa variando — dava véu uniforme, não nuvem.
  Precisou de `color_ramp` controlando alfa
- Frente de pintura com borda estreita — lia como régua vertical e denunciava o polígono da parede.
  Borda larga + ruído em duas escalas resolveu

### Ideia levantada, ainda não implementada

Pendurar um rodo/rolo na mão do tio — já que a frente de tinta no shader é sincronizada com a
posição dele, bastaria o mesh; o desenho na parede já acompanharia.

---

## 4. O que fazer agora

Plano de polish rumo à Steam, em 4 fases. Fases 0 e 1 acontecem no Cowork (comigo). Fase 2 é
handoff pro Claude Code. Fase 3 mistura as duas. Prioridade das 3 frentes de polish (já decidida):
**menu/UI → animação de personagens → mundo externo**. Deliberadamente fora desta rodada: base
técnica de exportação Steam antes da Fase 3, trilha sonora, localização, título definitivo.

### Fase 0 — Setup das ferramentas

- `[x]` Godot MCP instalado (`addons/godot_mcp/` + permissões em `.claude/settings.local.json`)
- `[ ]` Criar conta Figma e instalar o MCP server oficial (remoto, pra começar)
- `[ ]` Blender MCP — só se a Fase 1.2 decidir por modelo rigado
- `[ ]` `ProtonScatter` — instalar quando chegar na Fase 1.3
- `[ ]` `Dialogue Manager` — só se a Fase 1.1/1.2 decidir expandir diálogo
- `[ ]` GodotSteam — deixar pra perto da Fase 3 (requer conta Steamworks, taxa única de US$100)

### Fase 1 — Decisões de Design/UX/Assets

**1.1 Menu e UI** (prioridade 1)
- `[ ]` Wireframe no Figma — pulado, foi direto pra código (Figma MCP nunca chegou a ser configurado)
- `[x]` Paleta de cor/fonte/estilo — `resources/ui/theme_principal.tres`, tons madeira/tinta,
  aplicado globalmente via `project.godot::[gui]`
- `[x]` Transição entre painéis — crossfade curto (`DURACAO_FADE = 0.15`) em
  `menu_principal.gd`/`menu_pausa.gd`/`dialogo_pintura.gd`, substituindo `show()`/`hide()` seco
- `[x]` Tela de Opções — `opcoes.gd` (autoload `Opcoes`, persiste em `user://config.cfg`) +
  `painel_opcoes.gd`/`.tscn`, reusado no menu principal e no menu de pausa. Conteúdo hoje é volume
  **mestre** (não separado por música/SFX — não existe trilha/música ainda, então não fazia
  sentido separar) e tela cheia

**1.2 Animação de personagens** (prioridade 2)
- `[ ]` Decisão principal: manter procedural (pivô de quadril por perna + Tween, mesmo esquema dos
  braços) ou migrar pra modelo rigado via Blender? Procedural é mais rápido e barato de iterar;
  Blender é mais rico visualmente mas exige o workflow
  Blender MCP → `.glb` → import Godot → re-testar câmera/colisão. Nenhuma das duas quebra convenção
  do projeto — asset externo já é opção válida
- `[ ]` Se procedural: especificar ângulo do pivô e timing sincronizado com
  `ir_ate()`/`pintar_varrendo()`
- `[ ]` Se Blender: listar o que precisa ser modelado e o nível de rig necessário

**1.3 Mundo externo** (prioridade 3)
- `[x]` Nova escala do jardim — 20×16 → 220×220 (`cenario_externo.gd::ALCANCE_JARDIM`). Não usou
  `ProtonScatter`, espalhamento manual por `RandomNumberGenerator` com seed fixa (mais simples pro
  volume de props envolvido, addon ficou sem necessidade)
- `[x]` Névoa: cor por hora do dia — `Environment.fog_light_color` acompanha o mesmo gradiente de
  horizonte do céu em `ciclo_dia_noite.gd::_atualizar_luz`
- `[x]` Mais casas — 2 casas + 10 árvores extras em profundidade variável
  (`cenario_externo.gd::_criar_decoracao_distante`), seed fixa (4477)

**1.4 Branding pra loja Steam** (relevante aqui, decisão adiada no geral)
- `[ ]` Título definitivo — "Watching Paint Dry" fica irônico ou vira nome de loja de verdade?
- `[ ]` Ícone, capa e screenshots (podem nascer do que sair do Figma na 1.1)

### Fase 2 — Codificação (Claude Code)

- `[ ]` Depois de cada subseção da Fase 1 fechada, atualizar a seção 3 deste documento
  ("O que já foi feito") e passar a decisão como prompt pro Claude Code
- `[ ]` Ordem sugerida: 1.1 → 1.2 → 1.3
- `[ ]` Lembrar as armadilhas da seção 2 (warnings como erro, `.tscn` sem mesh inline, caminho
  relativo em vez de `%NomeUnico`)
- `[ ]` Com Godot MCP configurado, o Claude Code lê erros do editor direto — fecha o loop de teste
  sem precisar colar stack trace manualmente

### Fase 3 — Integração Steam

- `[ ]` Criar conta Steamworks (Steam Direct, US$100, só perto do fim)
- `[ ]` Criar `export_presets.cfg` (não existe ainda) — presets Windows/Linux/Mac
- `[ ]` Integrar GodotSteam: inicialização básica da API
- `[ ]` Ligar conquistas existentes (`estado_jogo.gd`/`conquistas.gd`, hoje só locais em
  `user://save.tres`) à API de conquistas da Steam
- `[ ]` Página de loja com o branding da 1.4
- `[ ]` Build de depósito e primeiro upload (branch de teste antes de público)

### Backlog — adiado, não é desta rodada

- Trilha sonora (hoje só ambiente sintetizado + som de pincelada)
- Localização (hoje só PT-BR)
