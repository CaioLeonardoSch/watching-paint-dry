extends Node3D

# ─────────────────────────────────────────────
#  INICIALIZADOR DO QUARTO
#
#  Quarto principal:  X ∈ [-3.5, +3.5],  Z ∈ [-4.0, +2.0]
#  Puxadinho (NE):    X ∈ [+0.5, +3.5],  Z ∈ [-6.5, -4.0]
#
#  Norte (-Z) = FRENTE  → parede com tinta + abertura pro puxadinho
#  Sul  (+Z)  = ATRÁS
#  Oeste (-X) = ESQUERDA → janela
#  Leste (+X) = DIREITA  → porta + puxadinho
# ─────────────────────────────────────────────

func _ready() -> void:
	_criar_meshes()
	_criar_janela()
	_criar_porta()


func _criar_meshes() -> void:
	var meshes := {
		# Chão
		"ChaoQP":                   Vector3(7.0, 0.2, 6.0),
		"ChaoPX":                   Vector3(3.0, 0.2, 2.5),
		# Teto
		"TetoQP":                   Vector3(7.0, 0.2, 6.0),
		"TetoPX":                   Vector3(3.0, 0.2, 2.5),
		# Parede Norte
		"ParedeNorteSolida":        Vector3(4.0, 3.0, 0.2),  # X∈[-3.5,+0.5] com tinta
		"ParedeNorteAberturaAcima": Vector3(3.0, 0.9, 0.2),  # X∈[+0.5,+3.5], Y∈[2.1,3.0]
		# Parede Sul (atrás, fechada)
		"ParedeSul":                Vector3(7.0, 3.0, 0.2),
		# Parede Oeste — janela (4 peças ao redor da abertura)
		"ParedeOesteNorte":         Vector3(0.2, 3.0, 3.0),  # Z∈[-4.0,-1.0]
		"ParedeOesteSul":           Vector3(0.2, 3.0, 1.0),  # Z∈[+1.0,+2.0]
		"ParedeOesteAcima":         Vector3(0.2, 1.0, 2.0),  # Z∈[-1.0,+1.0], Y∈[2.0,3.0]
		"ParedeOesteAbaixo":        Vector3(0.2, 0.8, 2.0),  # Z∈[-1.0,+1.0], Y∈[0.0,0.8]
		# Parede Leste — porta (3 peças + extensão pro puxadinho)
		"ParedeLesteNorte":         Vector3(0.2, 3.0, 3.5),  # Z∈[-4.0,-0.5]
		"ParedeLesteSul":           Vector3(0.2, 3.0, 1.5),  # Z∈[+0.5,+2.0]
		"ParedeLesteAcima":         Vector3(0.2, 0.9, 1.0),  # Z∈[-0.5,+0.5], Y∈[2.1,3.0]
		"ParedeLestePX":            Vector3(0.2, 3.0, 2.5),  # Z∈[-6.5,-4.0]
		# Puxadinho
		"ParedeNortePX":            Vector3(3.0, 3.0, 0.2),  # Z=-6.5
		"ParedeInternaOeste":       Vector3(0.2, 3.0, 2.5),  # X=+0.5
	}

	var mat_parede := StandardMaterial3D.new()
	mat_parede.albedo_color = Color(0.85, 0.83, 0.78)
	mat_parede.roughness    = 0.9

	var mat_piso := StandardMaterial3D.new()
	mat_piso.albedo_color = Color(0.55, 0.42, 0.28)
	mat_piso.roughness    = 0.8

	var mat_teto := StandardMaterial3D.new()
	mat_teto.albedo_color = Color(0.92, 0.91, 0.88)
	mat_teto.roughness    = 0.95

	var nos_piso  := ["ChaoQP", "ChaoPX"]
	var nos_teto  := ["TetoQP", "TetoPX"]
	var nos_tinta := ["ParedeNorteSolida"]  # material gerenciado pelo tinta_secando.gd

	for nome in meshes:
		var no := get_node_or_null(nome)
		if no == null:
			push_warning("Nó não encontrado: " + nome)
			continue

		var box := BoxMesh.new()
		box.size = meshes[nome]
		no.mesh  = box

		if nome in nos_tinta:
			continue
		elif nome in nos_piso:
			no.set_surface_override_material(0, mat_piso)
		elif nome in nos_teto:
			no.set_surface_override_material(0, mat_teto)
		else:
			no.set_surface_override_material(0, mat_parede)


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


func _criar_porta() -> void:
	var porta := get_node_or_null("Porta")
	if porta == null:
		push_warning("Nó Porta não encontrado")
		return

	var box := BoxMesh.new()
	box.size = Vector3(0.08, 2.1, 1.0)
	porta.mesh = box

	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.45, 0.30, 0.18)
	mat.roughness    = 0.85

	porta.set_surface_override_material(0, mat)
