# Watching Paint Dry — Contexto do Projeto

Projeto pessoal de aprendizado de Godot 4, sem compromisso de shipping. O objetivo é aprender a
engine construindo uma cena 3D concreta e pequena — não seguindo tutoriais abstratos — e explorar
até onde a ideia de "assistir tinta secar" pode virar mecânica de jogo de verdade.

Este projeto tem o sistema de skills de gamedev instalado em `.agents/skills/` (router + skills
especializadas). Para "como fazer X em Godot" (câmera, shaders, nodes, áudio, etc.), use esse
sistema normalmente. Este arquivo cobre o que é específico deste projeto e não está em nenhuma skill.

Também existe `_godot_skills_staging/` — um conjunto menor e mais antigo de skills de Godot,
escrito com referências diretas a este projeto (scripts, estado atual). Não é usado pelo router;
mantido à parte por decisão explícita, não é duplicata a ser removida.

Para contexto de **premissa, tom e direção criativa** do jogo (o que ele é, pra onde pode ir, e
com que disciplina de escopo) — não implementação técnica —, ver `CONCEITO-DO-JOGO.md` na raiz.
Leia antes de propor ou implementar qualquer mecânica nova.

## Stack

- Godot **4.7**, renderer Forward Plus
- Física: **Jolt Physics**
- Driver: **D3D12** no Windows
- Entry point: `res://scenes/menu_principal.tscn` (menu) → `res://scenes/quarto.tscn` (jogo)

## Estado atual

Já tem um loop narrativo de verdade, não é mais só "olhar ao redor" (Fases 1, 2 e 3 do plano de
evolução entregues e aprovadas — roadmap original completo). Existe:

- **Menu + modos de jogo + save + conquistas** (Fase 3) — `estado_jogo.gd` é o primeiro autoload
  do projeto (singleton `EstadoJogo`), guarda modo ativo e `DadosSalvos` (`Resource` tipado salvo
  em `user://save.tres`). Menu inicial (`menu_principal.gd`/`.tscn`) oferece Jogar (com seletor de
  modo Rápido/Normal/Realista) ou Continuar (se existe save), mais visualizador de conquistas.
  `tinta_secando.gd` e `ciclo_dia_noite.gd` se autoconfiguram a partir do modo ativo em `_ready()`
  (tempo de secagem e duração do dia mudam de escala real por modo — Rápido é o valor de teste de
  antes, Realista é literalmente 2h/demão e dia de 24h). Retomar de save pula a cutscene de abertura
  inteira e mostra as paredes já secas (`tinta_secando.gd::forcar_seco()`). Menu de pausa
  (`menu_pausa.gd`, ESC) pausa a árvore de verdade (`get_tree().paused`); `camera_cadeira.gd` não
  processa mais ESC sozinha. Conquistas (`conquistas.gd`, texto fixo, 10 no total) disparam ao
  completar o ciclo de 3 demãos de uma cor (`EstadoJogo.registrar_ciclo_completo`), com toast
  (`conquista_toast.gd`) e persistência entre sessões

- **Loop narrativo da tinta** (`ciclo_pintura.gd`) — um tio (`tio.gd`/`tio.tscn`) pinta as 4
  paredes do quarto em rodadas coordenadas (3 demãos cada, cor ficando mais saturada a cada
  rodada), dando uma **volta completa** no quarto: Leste, Norte, Oeste, Sul — da direita pra
  esquerda do ponto de vista da garotinha sentada. Ele pinta **andando**
  (`tio.gd::pintar_varrendo`), e a frente de tinta no shader avança junto com ele, então a cor nova
  vai cobrindo a antiga aos poucos. Uma garotinha (`garotinha.gd`/`garotinha.tscn`) entra, senta na
  cadeira e a câmera vira a visão em 1ª pessoa dela (`camera_cadeira.gd::ativar()`); depois da 3ª
  demão, uma UI
  (`dialogo_pintura.gd`) pergunta se ela gostou da cor — "gostei" encerra o ciclo, "trocar" abre
  uma paleta (`cor_tinta.gd` + `.tres` em `resources/cores/`) e reinicia tudo com a cor nova. Azul
  é a cor inicial da abertura (fora da rotação de conquista); vermelho/laranja/amarelo/verde/
  violeta/rosa são as 6 que batem com as conquistas de cor. A paleta mostrada nunca inclui a cor
  atual da parede — sempre "as outras 6", pra dar pra passar por todas as cores com o tempo
- Personagens são bonecos placeholder geométricos (cápsulas/esfera, sem asset externo, sem rig),
  animados com `Tween` — condiz com o resto do projeto (tudo procedural, zero import)
- Câmera de cutscene (`CameraCutscene`) cobre a abertura antes da garotinha sentar; câmera da
  cadeira só ativa depois disso (`ativar()`), gate por `current` no processamento de input. Na
  abertura o tio está terminando a parede **norte** (a que a garotinha vai encarar — é a única que
  enquadra bem); as outras 3 já chegam pintadas, em estágios diferentes de secagem
- Porta de verdade (`porta.gd`/`porta.tscn`) — folha com maçaneta de latão dos dois lados e
  batentes fixos; abre e fecha por `Tween` toda vez que alguém entra ou sai. Quem gira é o
  `PivoFolha`, não a raiz — os batentes são irmãos dele e ficam parados. `ciclo_pintura.gd` é quem
  orquestra (`_tio_entra`/`_tio_sai`/`_garotinha_entra_e_senta`), então `tio.gd`/`garotinha.gd`
  continuam sem saber que porta existe
- Cadeira de madeira em `(0, 0, -1)`, virada pro norte, montada em `inicializar_quarto.gd`
- Ciclo de dia e noite (`ciclo_dia_noite.gd`) — sol e lua giram em lados opostos do céu, cor da luz
  e do céu (`ProceduralSkyMaterial` + nuvens via `sky_cover` com alfa por `color_ramp`) seguem
  `Gradient`s montados em código com paradas densas perto do nascer/pôr do sol; lua sem sombra
  (custo de sombra dobrado não valia a pena); um dia dura `duracao_dia_segundos`, vindo do modo
  de jogo ativo
- Todas as 4 paredes secam tinta (`tinta_secando.gd` + `shaders/tinta_secando.gdshader`) — a
  tinta **não cai de uma vez**: uma frente de pintura varre a parede no sentido em que o tio anda
  (eixo/início/fim de varredura em espaço de mundo), e cada ponto começa a secar no instante em que
  a frente passa por ele. A onda de secagem também arrasta no mesmo sentido
  (`atraso_direcional_secagem`, espelhado na const `ATRASO_DIRECIONAL` do `.gd` — os dois precisam
  bater, senão a parede é dada como pronta antes da ponta final secar). Ruído fbm só torce a borda
  da frente e quebra a onda; molhado é um pouco mais brilhoso, seco é mais fosco
- Cenário externo pela janela (`cenario_externo.gd`) — jardim, 3 árvores, rua e uma casa do outro
  lado, tudo primitivas (`BoxMesh`/`CylinderMesh`/`SphereMesh`/`PrismMesh`) a `X < -3.5`
- Som ambiente sintetizado em código, sem nenhum arquivo de áudio (`som_ambiente.gd` via
  `AudioStreamGenerator`, ruído marrom modulado; `som_pincelada.gd` via `AudioStreamWAV` gerado uma
  vez, tocado a cada pincelada do tio)
- Assoalho procedural (`shaders/assoalho.gdshader`) — tábuas com tom e veio variando por hash,
  juntas escuras entre elas, e `NORMAL_MAP` derivado de um campo de altura por diferença finita
  (sulco entre tábuas, veio, poro), pra luz pegar no relevo em vez de bater num plano liso
- Paredes/chão com material texturizado por ruído triplanar (evita esticar/repetir textura
  em BoxMesh, que não tem UV contínuo entre faces) + normal map procedural — helper compartilhado
  em `materiais_procedurais.gd` (`criar_textura_ruido` e `criar_normal_ruido`, usados por
  `inicializar_quarto.gd`, `cenario_externo.gd` e `porta.gd`)
- **Teto é liso de propósito** — sem normal map e sem textura de detalhe. É superfície grande,
  plana e iluminada de raspão pela lâmpada, então qualquer micro-relevo que na parede fica sutil
  ali vira rabisco bem visível. Gesso pintado é liso mesmo
- Geração de toda a geometria (meshes + materiais) é **em código**, via `inicializar_quarto.gd` (e
  `cenario_externo.gd` pro cenário externo), rodando em `_ready()` — não em recursos inline no
  `.tscn`

## Layout do quarto (fonte da verdade)

```
Quarto:  X ∈ [-3.5, +3.5],  Z ∈ [-4.0, +2.0]

Norte (-Z) = FRENTE  → parede sólida com tinta secando (ParedeNorteSolida)
Sul   (+Z) = ATRÁS   → parede fechada (ParedeSul)
Oeste (-X) = ESQUERDA → janela (com vidro translúcido/refração)
Leste (+X) = DIREITA  → porta (folha com maçaneta, abre e fecha)
```

As 4 paredes são pintáveis, mas cada uma é picada em vários `MeshInstance3D` (acima/abaixo da
janela, dos lados da porta). Por isso o shader da tinta usa **posição de mundo**, não `UV` — com
UV o desenho reinicia em cada bloco e aparecem linhas retas nas emendas. Ordem do circuito de
pintura (`ciclo_pintura.gd::VARREDURAS`): Leste, Norte, Oeste, Sul.

Câmera da cadeira fica perto do centro, olhando para o norte por padrão — mas só fica ativa depois
da abertura (garotinha sentar); antes disso quem está ativa é a `CameraCutscene`, num canto,
enquadrando parede+porta+cadeira. Lâmpada de teto com luz própria (`LuzLampada`) complementa o sol,
a lua e a luz de ambiente noturna (`LuzNoite`).

**Isso já mudou de layout antes** (a versão anterior era em L, com puxadinho a sudoeste). O
`.tscn` e o `inicializar_quarto.gd` acima são a fonte da verdade atual — não assuma o layout
antigo em L se ele aparecer em alguma conversa ou documento antigo.

## Convenções deste projeto

- **GDScript, comentários e nomes de variáveis/nós em português brasileiro**, informal — mesmo
  registro usado nos outros projetos de design (tamanduá, sapo)
- **`.tscn` não leva `[sub_resource]` de mesh inline.** O parser de cena do Godot 4 é estrito e
  esses recursos inline causam erro ao salvar/reabrir. Padrão adotado: o `.tscn` declara só
  estrutura de nós + referência a scripts externos; meshes e materiais são atribuídos em runtime
  por `inicializar_quarto.gd` (via `_ready()`), ou manualmente no Inspector quando for algo pontual
- Scripts que dependem de mesh gerado em runtime usam `call_deferred` pra esperar o mesh existir
  antes de aplicar material (ver `tinta_secando.gd::_setup`)
- Texturas/materiais preferem **geração procedural via shader ou ruído** a texturas externas —
  não há pasta de assets de imagem no projeto ainda. O mesmo vale pra áudio: nada de `.wav`/`.ogg`,
  tudo sintetizado em código
- **Warnings são tratados como erro.** Duas armadilhas que já quebraram build aqui:
  `var x := max(a, b)` falha ("inferred from Variant") — usar `maxi()`/`maxf()` ou anotar o tipo;
  e passar `dicionario["chave"]` direto pra parâmetro tipado dispara `UNSAFE_CALL_ARGUMENT` —
  extrair numa variável tipada antes
- Referências entre nós usam caminho relativo (`$"../Nome"`), **não** `%NomeUnico` — nome único já
  resolveu pra `null` sem motivo claro neste projeto mais de uma vez

## Para onde isso foi (direção escolhida)

A pasta se chama "watching paint dry" de propósito — nasceu como piada sobre tédio. A direção foi
decidida: virou um loop narrativo (tio pinta, garotinha assiste secar, decide se gosta da cor ou
troca) em vez de puramente contemplativo/screensaver. Plano de evolução em fases, ver histórico de
conversa e `skills-lock.json`/commits pra detalhe — as 3 fases do roadmap original estão entregues:
Fase 1 (loop narrativo), Fase 2 (ambientação: dia/noite rico, cenário externo, som), Fase 3 (menu,
modos de jogo rápido/normal/realista, save, conquistas). Próximos passos, se houver, são escopo
novo — não assumir mais nada sem confirmar antes, mesma disciplina de sempre.

Continua seguindo a mesma disciplina de escopo dos outros projetos de design pessoais (tamanduá,
sapo): enxuto, finito, sem mecânica adicionada só por adicionar — mudanças de escopo maiores
(como decidir essa direção) passam por confirmação explícita antes de implementar, não são
assumidas sozinhas.

## Coisas que já foram tentadas e descartadas ou revertidas

- Layout em L com puxadinho — trocado pelo retangular atual
- Tinta molhada com `roughness` bem baixo (quase espelho) — refletia o céu processual e quebrava a
  parede em blocos visíveis. Molhado agora é só um pouco mais brilhoso que seco
- Normal map no teto — virava rabisco agressivo sob a luz rasante da lâmpada (ver acima)
- Textura de nuvem reusando `criar_textura_ruido` — sem alfa variando dava um véu uniforme, não
  nuvem. Precisa de `color_ramp` controlando alfa (ver `ciclo_dia_noite.gd::_criar_textura_nuvens`)
- Frente de pintura com borda estreita — lia como régua vertical e denunciava o polígono da
  parede. Borda larga + ruído em duas escalas resolveu
