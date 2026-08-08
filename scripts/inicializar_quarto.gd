extends Node3D

# ─────────────────────────────────────────────
#  INICIALIZADOR DO QUARTO
#
#  Quarto:  X ∈ [-3.0, +3.0],  Z ∈ [-4.0, +2.0]  — 6 × 6 m
#
#  Norte (-Z) = FRENTE  → parede com tinta
#  Sul  (+Z)  = ATRÁS
#  Oeste (-X) = ESQUERDA → janela (centrada em Z = -1)
#  Leste (+X) = DIREITA  → porta
#
#  QUADRADO DE PROPÓSITO (Fase G6). Era 7 × 6, e a assimetria tinha
#  consequência medível: as paredes norte/sul tinham 21 m² contra 18 m² das
#  outras, o rolo andava 17% mais rápido nelas (mesma duração, trajeto maior),
#  e a janela fora de centro deixava a parede norte — a que a garotinha encara
#  — recebendo um quarto da luz que a sul recebia. Agora as 4 são idênticas:
#  18 m², mesma máscara, todas a 3,0 m da câmera da cadeira.
# ─────────────────────────────────────────────

## Meia-largura do quarto. As paredes leste/oeste ficam em ±LIMITE_X.
const LIMITE_X: float = 3.0

func _ready() -> void:
	_criar_meshes()
	_criar_janela()
	_criar_lampada()
	_criar_cadeira()
	_criar_assoalho_tabuas()
	PropsQuarto.criar(self)


func _criar_meshes() -> void:
	var meshes := {
		# Chão e teto — 6 × 6 (era 7 × 6)
		"ChaoQP":             Vector3(6.0, 0.2, 6.0),
		"TetoQP":             Vector3(6.0, 0.2, 6.0),
		# Parede Norte — inteira coberta pela tinta
		"ParedeNorteSolida":  Vector3(6.0, 3.0, 0.2),  # X∈[-3.0,+3.0]
		# Parede Sul (atrás, fechada)
		"ParedeSul":          Vector3(6.0, 3.0, 0.2),
		# Parede Oeste — janela CENTRADA no vão da parede: Z∈[-1.85,-0.15],
		# ou seja 1.7 de largura em torno de Z = -1, que é o centro da parede.
		# Antes ela estava em Z = 0, 1 m fora do centro — e isso deixava a
		# parede norte recebendo ~1/4 da luz de janela que a sul recebia.
		"ParedeOesteNorte":   Vector3(0.2, 3.0, 2.15), # Z∈[-4.0,-1.85]
		"ParedeOesteSul":     Vector3(0.2, 3.0, 2.15), # Z∈[-0.15,+2.0]
		"ParedeOesteAcima":   Vector3(0.2, 1.0, 1.7),  # Z∈[-1.85,-0.15], Y∈[2.0,3.0]
		"ParedeOesteAbaixo":  Vector3(0.2, 0.8, 1.7),  # Z∈[-1.85,-0.15], Y∈[0.0,0.8]
		# Parede Leste — porta (3 peças ao redor da abertura). A porta fica
		# fora do centro de propósito: casa tem porta encostada num lado, e
		# centrar as duas aberturas na mesma reta daria cara de diagrama.
		"ParedeLesteNorte":   Vector3(0.2, 3.0, 3.5),  # Z∈[-4.0,-0.5]
		"ParedeLesteSul":     Vector3(0.2, 3.0, 1.5),  # Z∈[+0.5,+2.0]
		"ParedeLesteAcima":   Vector3(0.2, 0.9, 1.0),  # Z∈[-0.5,+0.5], Y∈[2.1,3.0]
	}

	# Fase C tirou o reboco com ruído triplanar + normal map procedural que ficava
	# aqui: as 9 paredes recebem o material da tinta (parede_pintavel.gd), então
	# ele já era código morto — e a direção low-poly pede superfície limpa, não
	# micro-relevo fingido, que só denuncia a face plana quando a luz raspa.
	var mat_teto := _criar_material_teto()

	var nos_teto := ["TetoQP"]

	# As 9 peças de parede NÃO recebem material aqui — quem manda nelas é
	# `parede_pintavel.gd`, que aplica o material da tinta por parede inteira
	# (ParedeNorteSolida, ParedeSul, as 4 de ParedeOeste* e as 3 de ParedeLeste*).
	# Isto era uma lista de nomes que ninguém lia; virou comentário, que é o que
	# ela sempre foi.

	for nome in meshes:
		var no := get_node_or_null(nome)
		if no == null:
			push_warning("Nó não encontrado: " + nome)
			continue

		var box := BoxMesh.new()
		box.size = meshes[nome]
		no.mesh  = box

		# o chão recebe material em _criar_assoalho_tabuas (vira contrapiso)
		if nome in nos_teto:
			no.set_surface_override_material(0, mat_teto)


## Teto de gesso: liso de propósito. Sem normal map e sem textura de detalhe —
## qualquer ruído aqui vira "rabisco" bem visível, porque o teto é uma
## superfície grande, plana e iluminada de raspão pela lâmpada, o que exagera
## qualquer micro-relevo. Gesso pintado é liso mesmo.
func _criar_material_teto() -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.92, 0.91, 0.88)
	mat.roughness    = 0.95
	return mat


## Assoalho de tábuas como GEOMETRIA, não como normal map.
##
## Fase C do overhaul: o `assoalho.gdshader` desenhava tábua, junta e relevo
## por diferença finita numa superfície plana. Em low-poly isso é trabalho
## errado — a estética quer forma e cor chapada, e relevo fingido em superfície
## plana entrega o truque assim que a luz bate de raspão (foi o mesmo motivo de
## o normal map do teto ter saído). Cada tábua vira um quad com altura e tom
## próprios; a junta é a fresta entre elas, de verdade.
func _criar_assoalho_tabuas() -> void:
	var chao := get_node_or_null("ChaoQP")
	if chao == null:
		return
	# O plano antigo continua visível como CONTRAPISO, escuro, por baixo das
	# tábuas. Escondê-lo abre buraco: as frestas entre tábuas passam a dar no
	# vazio e a luz do exterior vaza por elas.
	var mat_base := StandardMaterial3D.new()
	mat_base.albedo_color = Color(0.16, 0.12, 0.09)
	mat_base.roughness    = 0.95
	chao.set_surface_override_material(0, mat_base)

	var raiz := Node3D.new()
	raiz.name = "Assoalho"
	add_child(raiz)

	var rng := RandomNumberGenerator.new()
	rng.seed = 20260730  # decoração: fixa, pra não mudar entre execuções

	const LARGURA_TABUA: float = 0.22
	const FRESTA: float = 0.012
	var x: float = -LIMITE_X
	while x < LIMITE_X:
		var largura: float = minf(LARGURA_TABUA, LIMITE_X - x)
		if largura < 0.02:
			break

		var tabua := MeshInstance3D.new()
		raiz.add_child(tabua)
		var box := BoxMesh.new()
		# altura levemente irregular: assoalho velho não é perfeitamente plano
		var altura: float = 0.05 + rng.randf() * 0.012
		box.size = Vector3(largura - FRESTA, altura, 6.0)
		tabua.mesh = box
		tabua.position = Vector3(x + largura * 0.5, -altura * 0.5 + 0.004, -1.0)

		# tom por tábua — é o que dá vida sem custar textura (vertex color é o
		# caminho canônico de low-poly, e aqui a peça inteira faz o papel)
		var tom: float = 0.86 + rng.randf() * 0.28
		var mat := StandardMaterial3D.new()
		mat.albedo_color = Color(0.52 * tom, 0.35 * tom, 0.21 * tom)
		mat.roughness    = 0.72 + rng.randf() * 0.12
		tabua.set_surface_override_material(0, mat)

		x += largura


## Janela: dois painéis de vidro em vez de um bloco só.
##
## A moldura (props_quarto.gd) tem travessa central, então um vidro inteiro
## atravessando ela ficava incoerente. Também saiu a refração: ela entortava o
## cenário lá fora e chamava atenção pro vidro, quando o que interessa é o que
## se vê através dele. Vidro de casa é quase invisível — o que o denuncia é o
## reflexo de raspão, não distorção.
func _criar_janela() -> void:
	var janela := get_node_or_null("Janela")
	if janela == null:
		push_warning("Nó Janela não encontrado")
		return

	var mat := StandardMaterial3D.new()
	mat.transparency      = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.albedo_color      = Color(0.80, 0.90, 0.98, 0.10)
	mat.roughness         = 0.04
	mat.metallic_specular = 0.85
	mat.cull_mode         = BaseMaterial3D.CULL_DISABLED
	# Não recebe sombra: vidro sombreado lê como sujeira/fosco
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_PER_PIXEL

	# O nó da cena vira só o suporte; os painéis entram como filhos.
	janela.mesh = null

	# Quatro vidros, um por quadrante da cruz da moldura (props_quarto.gd).
	var altura_painel: float = 0.54
	var largura_painel: float = 0.78
	for dy in [-0.30, 0.30]:
		for dz in [-0.41, 0.41]:
			var painel := MeshInstance3D.new()
			janela.add_child(painel)
			var box := BoxMesh.new()
			box.size        = Vector3(0.02, altura_painel, largura_painel)
			painel.mesh     = box
			painel.position = Vector3(0, dy, dz)
			painel.set_surface_override_material(0, mat)


func _criar_lampada() -> void:
	var lampada := get_node_or_null("Lampada")
	if lampada == null:
		push_warning("Nó Lampada não encontrado")
		return

	var cone := CylinderMesh.new()
	cone.top_radius    = 0.05
	cone.bottom_radius = 0.22
	cone.height        = 0.3
	lampada.mesh = cone

	var mat := StandardMaterial3D.new()
	mat.albedo_color               = Color(0.92, 0.88, 0.8)
	mat.roughness                  = 0.5
	mat.emission_enabled           = true
	mat.emission                   = Color(1.0, 0.9, 0.7)
	mat.emission_energy_multiplier = 1.5

	lampada.set_surface_override_material(0, mat)


## Cadeira onde a garotinha senta, em PONTO_CADEIRA_GAROTINHA (0, 0, -1),
## virada pro norte (pra parede da tinta).
##
## **Modelo de terceiro desde 08/08/2026** (ver `CREDITOS.md`) — antes eram 15
## caixas primitivas montando assento, montantes, ripas, pernas e travessas. Ela
## fica no meio da tela o jogo inteiro, então é onde um modelo de verdade rende
## mais por peça trocada.
##
## O `.glb` já sai do Blender com a base em Y = 0, centrado em X/Z e com o
## ENCOSTO no +Z — ou seja, quem senta nela olha pro norte, que é onde está a
## parede da tinta. Por isso aqui não há rotação nenhuma.
##
## ⚠️ **O assento dele está a 0,492 m, não nos 0,45 das primitivas.** Quem
## depende disso é `garotinha.gd` — `ALTURA_ASSENTO`, `AGACHAMENTO_SENTADA` e
## `PES_SENTADA` — e os quatro números PRECISAM continuar batendo, senão ela
## senta no ar ou afunda na madeira. Trocando a cadeira de novo: medir o assento
## no Blender (faces viradas pra cima, a de maior área) e propagar os três.
func _criar_cadeira() -> void:
	var cena: PackedScene = load("res://models/cadeira_madeira.glb")
	var cadeira: Node3D = cena.instantiate()
	cadeira.name = "Cadeira"
	add_child(cadeira)
	cadeira.position = Vector3(0, 0, -1.0)
