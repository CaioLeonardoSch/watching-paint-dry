---
name: godot-camera
description: Padrões de câmera em Godot 4 — look livre em primeira pessoa, captura de mouse, clamp de pitch para evitar gimbal lock, movimento de personagem em primeira/terceira pessoa, FOV, projeção. Use quando a dúvida envolver Camera3D, rotação de câmera, input de mouse para olhar ao redor, ou trocar entre câmeras.
---

# Câmera em Godot 4

## Estado atual deste projeto

`scripts/camera_cadeira.gd` implementa uma câmera livre "sentada": olha em qualquer direção via
mouse, mas **não se move** (sem posição — é modo debug/observação, personagem sentado numa
cadeira). Padrão usado:

```gdscript
extends Camera3D

@export var sensibilidade: float = 0.002

var _rot_x: float = 0.0
var _rot_y: float = 0.0

func _ready() -> void:
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)

func _input(event: InputEvent) -> void:
	if not event is InputEventMouseMotion:
		return
	var delta_mouse: Vector2 = event.relative
	_rot_y -= delta_mouse.x * sensibilidade
	_rot_x -= delta_mouse.y * sensibilidade
	_rot_x = clamp(_rot_x, -deg_to_rad(89.0), deg_to_rad(89.0))
	rotation = Vector3(_rot_x, _rot_y, 0.0)
```

Pontos-chave desse padrão, generalizáveis para qualquer câmera look-livre em Godot 4:

- **Rotação por eixos separados (`_rot_x`, `_rot_y`) acumulados em variáveis próprias**, não lida
  direto de `rotation.x`/`rotation.y` a cada frame — evita drift de precisão e permite clamp limpo.
- **Clamp do pitch em ±89°, nunca ±90°.** Em exatamente 90° a câmera "engasga" (gimbal lock visual
  — right/up colapsam). Sempre deixar uma margem.
- **Yaw (`_rot_y`) sem clamp** — gira livremente 360°.
- **`rotation = Vector3(_rot_x, _rot_y, 0.0)` com Z sempre zero** — roll não é usado numa câmera de
  observação/primeira pessoa padrão. Se precisar de roll (ex: inclinação ao correr), esse é o eixo
  a mexer, separado de pitch/yaw.
- **Mouse capturado (`MOUSE_MODE_CAPTURED`) no `_ready()`**, com toggle para `MOUSE_MODE_VISIBLE`
  em `ui_cancel` (Esc) — padrão em `_unhandled_input`, não em `_input`, porque é uma ação de UI que
  não deve competir com outros handlers de input do jogo.

## Adicionar movimento de posição (se o projeto evoluir para isso)

Hoje a câmera não se move. Se precisar adicionar (ex: andar pelo quarto), duas abordagens comuns
em Godot 4:

1. **`CharacterBody3D` com `Camera3D` filha** — física real (colisão com paredes), preferível se
   o quarto ganhar mais interatividade. Usa `move_and_slide()` (sem argumentos — velocity é
   `self.velocity`, propriedade do nó, não parâmetro).
2. **`Camera3D` sozinha movida por `_process`/`_physics_process`** — mais simples, sem colisão,
   ok só para modo debug/spectator.

Direção do movimento relativa ao yaw da câmera:

```gdscript
var direcao := Vector3.ZERO
direcao.x = Input.get_axis("mover_esquerda", "mover_direita")
direcao.z = Input.get_axis("mover_frente", "mover_tras")
direcao = direcao.rotated(Vector3.UP, _rot_y).normalized()
```

## Erros comuns

- Usar `look_at()` toda frame junto com rotação manual por mouse — os dois métodos competem e a
  câmera "briga" com o mouse. Escolha um: ou `look_at` (câmera que persegue um alvo) ou rotação
  manual acumulada (câmera livre controlada pelo jogador). Não misturar no mesmo nó.
- Esquecer o clamp de pitch — sem ele, passar de 90° inverte o yaw (o mouse parece "inverter"
  sozinho), que é o sintoma clássico de gimbal lock nesse tipo de câmera.
- Rotacionar `Camera3D` como filha de um nó que também rotaciona (ex: corpo do personagem) sem
  decidir explicitamente qual eixo cada nó controla — normalmente o corpo controla yaw e a câmera
  (cabeça) controla pitch, para o corpo não inclinar ao olhar pra cima/baixo.
