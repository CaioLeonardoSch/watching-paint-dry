extends Node3D

# ─────────────────────────────────────────────
#  CENÁRIO EXTERNO — visto pela janela (parede oeste, X=-3.5)
#
#  Jardim + árvore + rua + casa do outro lado da rua. Tudo primitivas
#  (BoxMesh/CylinderMesh/SphereMesh/PrismMesh) + material procedural via
#  MateriaisProcedurais — sem nenhuma imagem externa, mesmo espírito do
#  resto do quarto. Sensação de "bairro residencial" simples, não perto o
#  bastante pra dar clipping na janela, longe o bastante pra caber na cena.
#
#  Tudo criado em código (não há nós pré-existentes no .tscn pra isso,
#  ao contrário do quarto principal) — mais simples pra um cenário
#  autocontido com várias peças pequenas.
# ─────────────────────────────────────────────

const PAREDE_OESTE_X: float = -3.5  # plano da parede com a janela


## Alcance do jardim em X, além da parede — bem maior que o necessário pro
## enquadramento perto da janela, pra empurrar a borda do plano pra dentro
## da névoa (ver quarto.tscn::Environment e ambiente_dia.gd).
const ALCANCE_JARDIM: float = 220.0


func _ready() -> void:
	_criar_jardim()
	# Uma perto e centrada na janela (visível de propósito), outras duas
	# espalhadas pelo jardim só pra não ficar tão vazio.
	_criar_arvore(Vector3(PAREDE_OESTE_X - 2.2, 0.0, 0.3), 1.0)
	_criar_arvore(Vector3(PAREDE_OESTE_X - 3.0, 0.0, -3.2), 0.8)
	_criar_arvore(Vector3(PAREDE_OESTE_X - 5.5, 0.0, 3.0), 1.15)
	_criar_rua()
	_criar_casa(Vector3(PAREDE_OESTE_X - 11.5, 0.0, 0.0))
	_criar_decoracao_distante()


func _criar_jardim() -> void:
	var chao := MeshInstance3D.new()
	add_child(chao)

	var box := BoxMesh.new()
	box.size = Vector3(ALCANCE_JARDIM, 0.2, ALCANCE_JARDIM)
	chao.mesh = box
	chao.position = Vector3(PAREDE_OESTE_X - ALCANCE_JARDIM * 0.5, -0.1, 0.0)

	# Grama: relevo bem alto e de frequência alta — moitinha irregular, não tapete
	var ruido  := MateriaisProcedurais.criar_textura_ruido(0.08, 512)
	var normal := MateriaisProcedurais.criar_normal_ruido(2.5, 3.0, 512)
	var mat    := MateriaisProcedurais.criar_material_texturizado(
		Color(0.32, 0.5, 0.28), 0.95, ruido, Vector3(4.0, 4.0, 4.0), normal, 1.4)
	chao.set_surface_override_material(0, mat)


func _criar_arvore(pos: Vector3, escala: float = 1.0) -> void:
	var arvore := Node3D.new()
	add_child(arvore)
	arvore.position = pos

	var tronco := MeshInstance3D.new()
	arvore.add_child(tronco)
	var cilindro := CylinderMesh.new()
	cilindro.top_radius    = 0.15 * escala
	cilindro.bottom_radius = 0.22 * escala
	cilindro.height        = 3.0 * escala
	tronco.mesh     = cilindro
	tronco.position = Vector3(0, 1.5 * escala, 0)

	# Casca de árvore: relevo forte, sulcos verticais (UV esticada em Y)
	var ruido_tronco  := MateriaisProcedurais.criar_textura_ruido(0.3, 256)
	var normal_tronco := MateriaisProcedurais.criar_normal_ruido(1.8, 4.0, 256)
	var mat_tronco    := MateriaisProcedurais.criar_material_texturizado(
		Color(0.35, 0.24, 0.15), 0.95, ruido_tronco, Vector3(1.0, 4.0, 1.0), normal_tronco, 2.0)
	tronco.set_surface_override_material(0, mat_tronco)

	# Copa: 3 esferas sobrepostas, deslocadas — evita cara de "bolinha única".
	# Deslocamento máximo (offset + raio) fica bem dentro do tronco pra não
	# vazar pra fora do pé da árvore quando ela está perto de alguma parede.
	# Folhagem: relevo alto quebra a silhueta lisa de esfera
	var ruido_copa  := MateriaisProcedurais.criar_textura_ruido(0.5, 256)
	var normal_copa := MateriaisProcedurais.criar_normal_ruido(3.5, 3.5, 256)
	var mat_copa    := MateriaisProcedurais.criar_material_texturizado(
		Color(0.25, 0.45, 0.22), 0.9, ruido_copa, Vector3(1.5, 1.5, 1.5), normal_copa, 1.8)
	var pontos_copa: Array[Vector3] = [
		Vector3(0, 3.5, 0) * escala,
		Vector3(0.35, 3.2, 0.25) * escala,
		Vector3(-0.3, 3.3, -0.25) * escala,
	]
	var raios_copa: Array[float] = [1.0 * escala, 0.75 * escala, 0.7 * escala]
	for i in pontos_copa.size():
		var folha := MeshInstance3D.new()
		arvore.add_child(folha)
		var esfera := SphereMesh.new()
		esfera.radius = raios_copa[i]
		esfera.height = raios_copa[i] * 2.0
		folha.mesh     = esfera
		folha.position = pontos_copa[i]
		folha.set_surface_override_material(0, mat_copa)


func _criar_rua() -> void:
	var rua := MeshInstance3D.new()
	add_child(rua)

	var box := BoxMesh.new()
	box.size = Vector3(3.0, 0.05, 16.0)
	rua.mesh = box
	rua.position = Vector3(PAREDE_OESTE_X - 8.5, 0.02, 0.0)  # levemente acima do jardim, evita z-fighting

	# Asfalto: granulado fino, sem brilho
	var ruido_rua  := MateriaisProcedurais.criar_textura_ruido(0.6, 256)
	var normal_rua := MateriaisProcedurais.criar_normal_ruido(4.0, 1.5, 256)
	var mat := MateriaisProcedurais.criar_material_texturizado(
		Color(0.15, 0.15, 0.16), 0.98, ruido_rua, Vector3(3.0, 3.0, 3.0), normal_rua, 0.8)
	rua.set_surface_override_material(0, mat)


func _criar_casa(pos: Vector3) -> void:
	var casa := Node3D.new()
	add_child(casa)
	casa.position = pos

	var corpo := MeshInstance3D.new()
	casa.add_child(corpo)
	var box := BoxMesh.new()
	box.size = Vector3(5.0, 3.0, 6.0)
	corpo.mesh     = box
	corpo.position = Vector3(0, 1.5, 0)

	# Reboco externo da casa — grão médio, mais grosso que parede interna
	var ruido_corpo  := MateriaisProcedurais.criar_textura_ruido(0.1, 512)
	var normal_corpo := MateriaisProcedurais.criar_normal_ruido(1.6, 2.0, 512)
	var mat_corpo    := MateriaisProcedurais.criar_material_texturizado(
		Color(0.75, 0.65, 0.5), 0.9, ruido_corpo, Vector3(2.0, 2.0, 2.0), normal_corpo, 1.0)
	corpo.set_surface_override_material(0, mat_corpo)

	var telhado := MeshInstance3D.new()
	casa.add_child(telhado)
	var prisma := PrismMesh.new()
	prisma.size          = Vector3(5.4, 1.6, 6.4)
	prisma.left_to_right = 0.5  # cume centrado
	telhado.mesh     = prisma
	telhado.position = Vector3(0, 3.8, 0)

	# Telha: relevo forte e direcional (UV apertada em Z sugere as ondas)
	var ruido_telhado  := MateriaisProcedurais.criar_textura_ruido(0.4, 256)
	var normal_telhado := MateriaisProcedurais.criar_normal_ruido(2.2, 3.0, 256)
	var mat_telhado    := MateriaisProcedurais.criar_material_texturizado(
		Color(0.4, 0.22, 0.18), 0.85, ruido_telhado, Vector3(2.0, 2.0, 6.0), normal_telhado, 1.5)
	telhado.set_surface_override_material(0, mat_telhado)


## Espalha mais árvores e casas em profundidade variável (além do grupo
## próximo da janela), pra quebrar a sensação de vazio antes da névoa cobrir
## o resto. Seed fixa — decoração, não precisa variar entre execuções.
func _criar_decoracao_distante() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 4477

	for i in range(10):
		var x: float = PAREDE_OESTE_X - rng.randf_range(20.0, ALCANCE_JARDIM - 15.0)
		var z: float = rng.randf_range(-80.0, 80.0)
		var escala: float = rng.randf_range(0.7, 1.3)
		_criar_arvore(Vector3(x, 0.0, z), escala)

	_criar_casa(Vector3(PAREDE_OESTE_X - 35.0, 0.0, -18.0))
	_criar_casa(Vector3(PAREDE_OESTE_X - 55.0, 0.0, 22.0))
