---
name: godot
description: Ponto de entrada para dúvidas de desenvolvimento em Godot 4 neste projeto — "como fazer X em Godot", GDScript, estrutura de cena, convenções gerais do engine. Use esta skill primeiro para decidir se o assunto cai numa skill mais específica (godot-camera, godot-shaders, godot-nodes, godot-audio) ou se é uma dúvida geral de GDScript/engine que pode ser respondida direto aqui. Não usar para decisões de design de jogo (isso é conversa de projeto, não engine) nem para C#/outras linguagens — o projeto é 100% GDScript.
---

# Godot 4 — router de skills

Este projeto (Watching Paint Dry) usa Godot **4.7**, renderer **Forward Plus**, física **Jolt**,
driver **D3D12** no Windows. Veja `CLAUDE.md` na raiz do projeto para contexto específico (layout
do quarto, convenções de nomenclatura, estado atual da cena) — essa skill cobre engine em geral,
não decisões deste projeto específico.

## Como decidir qual skill usar

| Assunto | Skill |
|---|---|
| Câmera (look, movimento, FOV, projeção, input de mouse/teclado) | `godot-camera` |
| Shaders (`.gdshader`), materiais, ruído procedural, triplanar, PBR | `godot-shaders` |
| Estrutura de cena, `.tscn`, geração de nós/mesh via código, sinais, autoloads | `godot-nodes` |
| Áudio (buses, players 2D/3D, atenuação, música) | `godot-audio` |
| Qualquer outra coisa (matemática de `Vector3`/`Transform3D`, física Jolt, input, física de personagem, exportar variáveis, `_process` vs `_physics_process`, etc.) | Responder direto usando este documento + conhecimento geral de Godot 4.7 |

Se a dúvida cruza mais de um tema (ex: "shader que reage a um `Area3D`"), leia as skills
relevantes e combine — elas não são mutuamente exclusivas.

## Convenções gerais deste projeto (valem para qualquer skill)

- **GDScript apenas.** Comentários e nomes de variáveis/nós em **português brasileiro**, registro
  informal.
- **Geração procedural em código, não assets externos.** Não existe pasta de imagens/texturas no
  projeto; ruído (`FastNoiseLite`, `NoiseTexture2D`) e shaders geram a variação visual.
- **Static typing quando dá.** Os scripts existentes tipam variáveis e retornos (`var x: float`,
  `func f() -> void`) — siga o padrão ao escrever código novo.
- **Um script por responsabilidade, indo direto no nó que ele controla** (`extends Camera3D`,
  `extends MeshInstance3D`, `extends DirectionalLight3D`), em vez de um controller central.

## Erros comuns em Godot 4 (vindos de outras versões ou de outros engines)

- `KinematicBody` não existe mais — é `CharacterBody3D` com `move_and_slide()` sem argumentos
  (a velocity é uma propriedade do nó, não parâmetro).
- Sinais são conectados como `Callable`: `no.pressed.connect(_on_pressed)`, não mais como string.
- `onready var` virou `@onready var`; `export var` virou `@export var`. Anotações com `@` no
  início da linha, não no fim.
- `yield()` não existe mais — é `await`.
- Autoload continua existindo (Project Settings → Autoload) mas não é a única forma de estado
  global; para cenas pequenas como esta, prefira `%NomeUnico` (Unique Name) a autoload.

## Quando a dúvida não é sobre engine

Se a pergunta for sobre **o que construir** (mecânica, próxima feature, direção de design), isso
não é escopo desta skill — é conversa de projeto normal, usando o contexto do `CLAUDE.md`.
