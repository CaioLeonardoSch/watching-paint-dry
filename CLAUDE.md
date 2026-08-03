# Watching Paint Dry

Jogo pequeno em Godot 4.7: um quarto onde um tio pinta as paredes e uma garotinha senta pra ver a
tinta secar. A piada é o tédio; a aposta é que observar algo mudar devagar seja relaxante.

## Comece por aqui

**Leia `PROJETO.md` (raiz) antes de propor ou implementar qualquer coisa.** Ele tem premissa,
convenções, estado real do jogo, o que já foi descartado e a ordem das etapas. Este arquivo é só o
roteador — de propósito não carrega o plano inteiro em toda sessão.

| Documento | Ler quando |
|---|---|
| **`PROJETO.md`** | Sempre. Comece pela seção 0 (mapa e vocabulário) |
| `PLANO-OVERHAUL-TINTA.md` | Antes de mexer em tinta, parede, rig ou animação de personagem |
| `PLANO-SECAGEM-E-QUARTO.md` | Antes de mexer em shader de tinta, coordenada de parede, luz ou `project.godot` |

## Vocabulário — não confundir

- **Etapa 1/2/3** = os blocos até a Steam (miolo → conteúdo → loja).
- **Fase A…G** = os passos dentro da Etapa 1. É o que está em andamento.
- **Fase 1/2/3** = o roadmap ORIGINAL, concluído e aposentado. Só aparece em texto histórico.
  ⚠️ "Fase 1.2" é o rig antigo de 7 ossos — **não** é a Fase D.

## Antes de escrever código

- **Warning é erro neste projeto.** Duas armadilhas que já quebraram build: `var x := max(a, b)`
  (usar `maxi`/`maxf` ou anotar o tipo) e passar `dicionario["chave"]` direto pra parâmetro tipado
  (extrair numa variável tipada antes).
- **GDScript, comentários e nomes em português brasileiro**, informal.
- **Nada de `%NomeUnico`** — usar caminho relativo (`$"../Nome"`). Nome único já resolveu pra `null`
  sem motivo claro aqui mais de uma vez.
- **`.tscn` não leva `[sub_resource]` de mesh inline** — mesh e material são atribuídos em runtime.
- O resto das convenções e das armadilhas (Blender→Godot, Godot MCP, localização) está em
  `PROJETO.md` seção 2. **Elas já custaram uma rodada cada; repetir é o desperdício mais caro aqui.**

## Antes de propor uma melhoria

Conferir `PROJETO.md` seção 3.6 (*Coisas já tentadas e descartadas ou revertidas*). Ciclo de dia e
noite, normal map nas paredes, tinta molhada espelhada e outras ideias "óbvias" já foram
implementadas, testadas e revertidas por bom motivo.

Mudança de escopo passa por **confirmação explícita** do Caio. Nunca assumir sozinho — o projeto é
deliberadamente pequeno ("bem besta", nas palavras dele) e entregável.
