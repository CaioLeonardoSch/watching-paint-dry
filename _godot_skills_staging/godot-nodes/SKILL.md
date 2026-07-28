---
name: godot-nodes
description: Estrutura de cena e nós em Godot 4 — geração procedural de mesh/material via código no _ready(), call_deferred para esperar mesh existir, regras estritas do parser de .tscn (sem sub_resource de mesh inline), Unique Name (%Nome), organização da árvore de nós, sinais. Use quando a dúvida envolver .tscn, MeshInstance3D, ArrayMesh/SurfaceTool, ordem de inicialização, ou "por que meu material/mesh não aparece".
---

# Nós e cenas em Godot 4

## Regra crítica deste projeto: `.tscn` não leva mesh inline

O parser de cena do Godot 4 é estrito com `[sub_resource]` de mesh dentro de `.tscn` — recursos de
mesh definidos inline causam erro ao salvar/reabrir a cena (mais frequente quando o `.tscn` foi
editado por fora do editor, ou gerado por script/IA). Padrão adotado neste projeto:

- `.tscn` declara **só estrutura de nós** (`MeshInstance3D` sem mesh) **+ referência a scripts
  externos** (`ExtResource` do tipo `Script`).
- Mesh e material são atribuídos **em runtime**, por `inicializar_quarto.gd` rodando em
  `_ready()`, ou manualmente no Inspector quando é algo pontual/único.

Isso não é uma limitação a contornar — é o padrão recomendado quando geometria é gerada
proceduralmente. Só editar mesh via Inspector manualmente para casos que não valem o código (ex:
um objeto decorativo único, sem padrão reutilizável).

## Gerar geometria via código

Padrão usado (`inicializar_quarto.gd`): `_ready()` chama uma sequência de `_criar_*()`, cada uma
resolvendo o nó por nome (`get_node_or_null`) e atribuindo mesh + material:

```gdscript
func _ready() -> void:
	_criar_meshes()
	_criar_janela()
	_criar_porta()
	_criar_lampada()

func _criar_janela() -> void:
	var no := get_node_or_null("Janela")
	if no == null:
		push_warning("Nó Janela não encontrado")
		return
	var box := BoxMesh.new()
	box.size = Vector3(0.05, 1.2, 2.0)
	no.mesh = box
	no.set_surface_override_material(0, mat)
```

Pontos-chave:

- `get_node_or_null` + `push_warning` em vez de `get_node` direto — se o nó não existir na cena
  (renomeado, removido), o script avisa em vez de crashar com erro de null silenciosamente
  ignorado.
- `set_surface_override_material(0, mat)` para material por-instância, sem mexer no mesh
  compartilhado — importante quando o mesmo `BoxMesh`/geometria poderia ser reusado por múltiplos
  nós com materiais diferentes.
- Malhas simples (`BoxMesh`, `CylinderMesh`) resolvem a maior parte dos casos. Para geometria
  custom real (não primitiva), use `ArrayMesh` + `SurfaceTool` — fora do escopo do padrão atual do
  projeto, mas é o próximo degrau se precisar de formas não-primitivas.

## `call_deferred` para esperar mesh existir

Quando um script depende de um mesh que **outro script** atribui em `_ready()`, há uma corrida:
não há garantia de ordem entre os `_ready()` de nós irmãos/pais-filhos na mesma cena. Padrão usado
em `tinta_secando.gd`:

```gdscript
func _ready() -> void:
	# Adia a criação do material para depois que o mesh for atribuído
	call_deferred("_setup")

func _setup() -> void:
	_criar_material()
	_atualizar_material(0.0)
```

`call_deferred` empurra a chamada para o fim do frame atual (depois que todos os `_ready()` da
cena já rodaram) — suficiente quando a dependência é "outro `_ready()` já deve ter rodado", sem
precisar de sinal explícito. Se a dependência for mais complexa (esperar um recurso carregar
assincronamente, por exemplo), use `await` num sinal em vez de `call_deferred`.

Sintoma de quando isso falta: material aplicado a um `MeshInstance3D` sem mesh ainda simplesmente
não aparece, sem erro — porque `set_surface_override_material` num índice de surface que não
existe é silencioso.

## Unique Name (`%Nome`)

`ciclo_dia_noite.gd` referencia o `WorldEnvironment` assim:

```gdscript
@onready var _world_env: WorldEnvironment = %WorldEnvironment
```

Isso exige marcar o nó como "Access as Unique Name" no editor (ícone de %). Funciona
independentemente de onde o script estiver na árvore — não precisa de caminho relativo
(`$"../WorldEnvironment"`) nem de autoload. Prefira isso a autoload para referências dentro da
mesma cena; reserve autoload para estado que precisa sobreviver a troca de cena (não é o caso
deste projeto, que tem uma cena só).

## Sinais em Godot 4

Conectados como `Callable`, não string:

```gdscript
botao.pressed.connect(_on_botao_pressed)
# não: botao.connect("pressed", self, "_on_botao_pressed")  ← Godot 3
```

Para sinais customizados: `signal fracao_mudou(fracao: float)`, emitidos com
`fracao_mudou.emit(valor)`.

## Erros comuns

- Editar `.tscn` manualmente (fora do editor) e adicionar `[sub_resource type="ArrayMesh" ...]`
  ou similar — vai quebrar ao reabrir. Se precisar editar `.tscn` como texto, mexa só em
  `[node]`/`transform`/propriedades simples, nunca em recursos de mesh.
- Esquecer que `unique_name_in_owner=true` no `.tscn` é o que habilita `%Nome` — se copiar/colar
  um nó, essa flag pode não vir junto.
- Depender de ordem de `_ready()` entre nós sem `call_deferred`/sinal — funciona por acaso na
  maioria das vezes e quebra quando a árvore de nós muda de ordem.
