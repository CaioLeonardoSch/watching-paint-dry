extends Node3D

# ─────────────────────────────────────────────
#  INICIALIZADOR DO QUARTO
#
#  Quarto:  X ∈ [-3.5, +3.5],  Z ∈ [-4.0, +2.0]
#
#  Norte (-Z) = FRENTE  → parede com tinta
#  Sul  (+Z)  = ATRÁS
#  Oeste (-X) = ESQUERDA → janela
#  Leste (+X) = DIREITA  → porta
# ─────────────────────────────────────────────

func _ready() -> void:
	_criar_meshes()
	_criar_janela()
	_criar_lampada()
	_criar_cadeira()
	_criar_assoalho_tabuas()
	PropsQuarto.criar(self)


func _criar_meshes() -> void:
	var meshes := {
		# Chão e teto
		"ChaoQP":             Vector3(7.0, 0.2, 6.0),
		"TetoQP":             Vector3(7.0, 0.2, 6.0),
		# Parede Norte — inteira coberta pela tinta
		"ParedeNorteSolida":  Vector3(7.0, 3.0, 0.2),  # X∈[-3.5,+3.5]
		# Parede Sul (atrás, fechada)
		"ParedeSul":          Vector3(7.0, 3.0, 0.2),
		# Parede Oeste — janela (4 peças ao redor da abertura)
		"ParedeOesteNorte":   Vector3(0.2, 3.0, 3.0),  # Z∈[-4.0,-1.0]
		"ParedeOesteSul":     Vector3(0.2, 3.0, 1.0),  # Z∈[+1.0,+2.0]
		"ParedeOesteAcima":   Vector3(0.2, 1.0, 2.0),  # Z∈[-1.0,+1.0], Y∈[2.0,3.0]
		"ParedeOesteAbaixo":  Vector3(0.2, 0.8, 2.0),  # Z∈[-1.0,+1.0], Y∈[0.0,0.8]
		# Parede Leste — porta (3 peças ao redor da abertura)
		"ParedeLesteNorte":   Vector3(0.2, 3.0, 3.5),  # Z∈[-4.0,-0.5]
		"ParedeLesteSul":     Vector3(0.2, 3.0, 1.5),  # Z∈[+0.5,+2.0]
		"ParedeLesteAcima":   Vector3(0.2, 0.9, 1.0),  # Z∈[-0.5,+0.5], Y∈[2.1,3.0]
	}

	# Fase C tirou o reboco com ruído triplanar + normal map procedural que ficava
	# aqui: as 9 paredes recebem o material da tinta (parede_pintavel.gd), então
	# ele já era código morto — e a direção low-poly pede superfície limpa, não
	# micro-relevo fingido, que só denuncia a face plana quando a luz raspa.
	var mat_teto := _criar_material_teto()

	var nos_teto  := ["TetoQP"]
	# material gerenciado por parede_pintavel.gd (a parede inteira é pintável)
	var nos_tinta := [
		"ParedeNorteSolida", "ParedeSul",
		"ParedeOesteNorte", "ParedeOesteSul", "ParedeOesteAcima", "ParedeOesteAbaixo",
		"ParedeLesteNorte", "ParedeLesteSul", "ParedeLesteAcima",
	]

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
	var x: float = -3.5
	while x < 3.5:
		var largura: float = minf(LARGURA_TABUA, 3.5 - x)
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


func _criar_janela() -> void:
	var janela := get_node_or_null("Janela")
	if janela == null:
		push_warning("Nó Janela não encontrado")
		return

	var box := BoxMesh.new()
	box.size = Vector3(0.05, 1.2, 2.0)
	janela.mesh = box

	var mat := StandardMaterial3D.new()
	mat.transparency       = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.albedo_color       = Color(0.75, 0.88, 1.0, 0.18)
	mat.roughness          = 0.0
	mat.metallic_specular  = 1.0
	mat.refraction_enabled = true
	mat.refraction_scale   = 0.02
	mat.cull_mode          = BaseMaterial3D.CULL_DISABLED

	janela.set_surface_override_material(0, mat)


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
## virada pro norte (pra parede da tinta). Assento + encosto + 4 pernas,
## tudo primitiva, madeira com veio (mesmo tratamento da porta).
func _criar_cadeira() -> void:
	var cadeira := Node3D.new()
	cadeira.name = "Cadeira"
	add_child(cadeira)
	cadeira.position = Vector3(0, 0, -1.0)

	var ruido  := MateriaisProcedurais.criar_textura_ruido(0.35, 256)
	var normal := MateriaisProcedurais.criar_normal_ruido(1.6, 1.8, 256)
	var mat    := MateriaisProcedurais.criar_material_texturizado(
		Color(0.38, 0.24, 0.14), 0.7, ruido, Vector3(4.0, 4.0, 4.0), normal, 0.8)

	var alt_assento: float = 0.45
	var meia_largura: float = 0.21

	_peca_cadeira(cadeira, mat, Vector3(0.46, 0.05, 0.44), Vector3(0, alt_assento, 0))

	# Encosto: painel inclinado, atrás (lado sul, +Z) — garota olha pro norte
	var encosto := _peca_cadeira(cadeira, mat, Vector3(0.44, 0.5, 0.05), Vector3(0, alt_assento + 0.28, 0.2))
	encosto.rotation_degrees.x = -8.0

	# Travessa horizontal do encosto, dá cara de cadeira de madeira mesmo
	_peca_cadeira(cadeira, mat, Vector3(0.44, 0.07, 0.06), Vector3(0, alt_assento + 0.52, 0.23))

	var eixos_x: Array[float] = [-meia_largura, meia_largura]
	var eixos_z: Array[float] = [-0.19, 0.19]
	for dx in eixos_x:
		for dz in eixos_z:
			_peca_cadeira(cadeira, mat, Vector3(0.05, alt_assento, 0.05), Vector3(dx, alt_assento * 0.5, dz))


func _peca_cadeira(pai: Node3D, mat: Material, tamanho: Vector3, pos: Vector3) -> MeshInstance3D:
	var peca := MeshInstance3D.new()
	pai.add_child(peca)
	var box := BoxMesh.new()
	box.size      = tamanho
	peca.mesh     = box
	peca.position = pos
	peca.set_surface_override_material(0, mat)
	return peca
