# Watching Paint Dry — do que se trata

Este documento existe para dar contexto de **premissa e tom**, não de implementação técnica —
para isso, ver `CLAUDE.md`. Leia este arquivo quando a dúvida for "por que isso existe" ou "isso
faz sentido pro jogo", não "como faço X em Godot".

## A piada que pode virar jogo de verdade

"Watching paint dry" é expressão em inglês pra tédio absoluto — a coisa mais entediante possível
de se assistir. O projeto nasceu como piada nesse sentido: literalmente um quarto onde a única
coisa que acontece é tinta secando numa parede. Mas a piada tem uma virada séria em aberto —
observar algo mudar lentamente, sem pressa, sem objetivo, pode ser genuinamente relaxante em vez
de entediante. É essa segunda leitura que o projeto está explorando, sem compromisso de chegar lá.

## Estado atual: virou loop narrativo de verdade

A direção foi decidida e implementada em fases: já **é** um loop de jogo, não só exercício de
aprendizado. Um tio pinta as 4 paredes do quarto em rodadas (3 demãos cada), dando uma volta
completa pelo quarto e pintando enquanto anda; uma garotinha entra e senta pra assistir secar (a
câmera vira a visão dela), e ao final o tio pergunta se ela gostou da cor — pode manter ou trocar
por uma nova, o que reinicia o ciclo.

O roadmap original de 3 fases está **completo**:

- **Fase 1** — o loop narrativo em si (tio, garotinha, demãos, pergunta de cor).
- **Fase 2** — ambientação: dia/noite com curva de cor rica e lua, cenário externo visível pela
  janela (casa, árvores, rua), som ambiente sintetizado em código.
- **Fase 3** — menu inicial e de pausa, modos de jogo (rápido/normal/realista, com o realista em
  escala de horas de verdade), save entre sessões, e 10 conquistas.

Depois disso veio uma rodada de **refinamento** (fora do roadmap, pedida item a item): texturas com
relevo procedural em quase tudo, porta com maçaneta que abre e fecha, cadeira, e a reescrita da
pintura pra ser uma varredura progressiva — a tinta aparece conforme o rolo passa e cada trecho já
começa a secar dali, em vez de a parede inteira mudar de cor de uma vez.

## Pra onde isso foi (direção escolhida)

Acabou sendo um meio-termo entre as duas ideias esboçadas originalmente: tem, sim, várias
"pinturas" acontecendo (as 4 paredes secam em rodadas coordenadas, parecido com a ideia de cuidar
de várias tintas secando), mas embaladas numa moldura narrativa (tio e garotinha, decisão de gostar
ou trocar de cor) que nenhuma das duas ideias originais previa — não é puramente "cuidar de timings
paralelos" nem puramente contemplativo/screensaver. Isso foi decisão consciente do usuário, não
acidente de implementação (confirmado explicitamente antes de cada fase, via perguntas de escopo).

## Espírito e disciplina de escopo

Este projeto é parte de um conjunto de projetos de design pessoais (junto com um jogo de
tamanduá e um de sapo/rã), todos com o mesmo espírito: jogos relaxantes, sem pressão, loop de
observação/manutenção em vez de ação. A mesma disciplina dos outros vale aqui: **enxuto, finito,
sem mecânica adicionada só por adicionar**. Nos outros projetos, mecânicas foram cortadas
deliberadamente por não melhorarem a experiência — a mesma vara de medir se aplica.

## O que isso significa na prática

- O escopo não está mais vazio — existe um jogo de verdade, com as 3 fases do roadmap entregues.
  Não tratar isso como só "aprendizado de engine": é razoável propor ajustes e polish dentro do
  que já foi construído.
- O roadmap acabou. **Qualquer coisa daqui pra frente é escopo novo** — confirmar antes de
  implementar, do mesmo jeito que foi feito em cada fase. O padrão que funcionou: perguntar (via
  `AskUserQuestion`/plan mode) o que exatamente cada item significa antes de escrever código,
  especialmente quando o pedido é grande ou ambíguo.
- Uma ideia já levantada e **ainda não implementada**: pendurar um rodo/rolo na mão do tio, já que
  a frente de tinta no shader é sincronizada com a posição dele — basta o mesh, o desenho na parede
  já acompanha.
- Não existe documento de design formal (ao contrário do tamanduá, que já tem um resumo compilado).
  Vale considerar criar um agora que há bastante substância implementada pra documentar.
