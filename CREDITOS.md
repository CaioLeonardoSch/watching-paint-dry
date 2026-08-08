# Créditos de terceiros

Assets de terceiros usados no **Watching Paint Dry**, com autor e licença.

⚠️ **Este arquivo é obrigação legal, não cortesia.** Toda licença Creative Commons listada aqui exige
atribuição *visível para o jogador* — não basta o arquivo existir no repositório. Antes da Steam,
este conteúdo precisa aparecer também **dentro do jogo** (tela de créditos no menu). Ver pendências
no fim.

Um asset só entra na lista quando entra no jogo de verdade. Coisa baixada e descartada na avaliação
não é listada — se voltar atrás, listar junto.

## Modelos 3D

### Cadeira da garotinha

- **Old Wooden Chair Low-poly** — 304 faces
- Autor: **MaX3Dd**
- Licença: **CC Attribution 4.0** (CC BY 4.0)
- Fonte: https://sketchfab.com/models/2a61dd227db34fa4b400fb6bccb34937
- Onde: a cadeira em `PONTO_CADEIRA_GAROTINHA`, substituindo as primitivas de
  `inicializar_quarto.gd::_criar_cadeira()`

### Escada do tio

- **Small step ladder** — 1856 faces
- Autor: **1-3D.com**
- Licença: ⚠️ **CC Attribution-ShareAlike 4.0** (CC BY-SA 4.0)
- Fonte: https://sketchfab.com/models/430f5651a39c46258abb30a22f7b5634
- Onde: o banquinho que o tio carrega e sobe (`props_pintura.gd`)

⚠️ **A cláusula ShareAlike é diferente das outras e precisa de decisão consciente.** Usar o modelo
como está exige só atribuição. Mas **qualquer modificação** dele — remodelar, decimar, trocar o
material pra combinar com a direção de arte — vira obra derivada, e a derivada tem que ser
distribuída sob CC BY-SA também. Isso não abre o código do jogo nem os outros assets, mas obriga a
oferecer *aquele modelo modificado* sob a mesma licença. Se isso não for aceitável, trocar por um
equivalente CC BY puro antes de mexer nele.

### Casa vizinha (vista pela janela)

- **Small Low Poly House** — 2012 faces
- Autor: **MrAeterna**
- Licença: **CC Attribution 4.0** (CC BY 4.0)
- Fonte: https://sketchfab.com/models/b3a6cff40d02411e8cf35ca18eb14f02
- Onde: `cenario_externo.gd`

### Árvore (vista pela janela)

- **Stylized Pine Tree** — 939 faces
- Autor: **Batuhan13**
- Licença: **CC Attribution 4.0** (CC BY 4.0)
- Fonte: https://sketchfab.com/models/deadcadc915545a7b4701dbe6eb419e8
- Onde: `cenario_externo.gd`

## Licenças que este projeto NÃO aceita

Registrado porque já apareceu na busca e é fácil pegar por engano:

- **CC Attribution-NonCommercial** (e qualquer variante `-NC`) — o jogo vai pra Steam, ou seja é uso
  comercial. Proibido, sem exceção. Apareceu em resultados bons de cerca e de árvore
- **Sketchfab "Free Standard"** — não é Creative Commons; é a licença própria do Sketchfab, com
  restrições diferentes de redistribuição. Ler caso a caso antes de usar

## Pendências antes da Steam

- [ ] Tela de créditos no menu principal exibindo o conteúdo deste arquivo (a atribuição CC precisa
      chegar no jogador, não parar no repositório)
- [ ] Decidir o caso da escada: manter CC BY-SA sem modificar, ou trocar por CC BY puro
- [ ] Traduzir a tela de créditos? **Não.** Nome de autor e nome de licença não se traduzem —
      só o texto ao redor, se houver
