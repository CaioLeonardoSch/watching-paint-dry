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
## enquadramento perto da janela, pra empurrar a borda do plano pra longe do
## que a janela enquadra (era a névoa que escondia a borda; ela saiu porque
## encobria o quarto inteiro — ver ambiente_dia.gd::_configurar_ambiente).
const ALCANCE_JARDIM: float = 220.0

## Camada de render só do cenário externo. Serve pra uma luz de preenchimento
## acender as fachadas sem tocar no quarto — ver _criar_preenchimento_externo.
const CAMADA_EXTERNA: int = 1 << 1


func _ready() -> void:
	_criar_jardim()
	# NENHUMA árvore no eixo da janela. A que ficava em (X-2.2, Z+0.3) estava
	# bem na frente do vão e picotava a luz do sol no chão do quarto — a mancha
	# saía rendilhada de sombra de copa, parecendo defeito de render. As que
	# sobraram estão fora do cone da janela, então a luz entra limpa e a vista
	# continua tendo árvore.
	_criar_arvore(Vector3(PAREDE_OESTE_X - 3.0, 0.0, -4.6), 0.8)
	_criar_arvore(Vector3(PAREDE_OESTE_X - 5.5, 0.0, 4.4), 1.15)
	_criar_rua()
	_criar_vizinhanca()
	_criar_decoracao_distante()
	_criar_preenchimento_externo()


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
	# Comprida o bastante (em Z) pra sair dos dois lados do enquadramento da
	# janela: rua que termina à vista lê como cenário de teatro.
	box.size = Vector3(3.0, 0.05, 90.0)
	rua.mesh = box
	rua.position = Vector3(PAREDE_OESTE_X - 8.5, 0.02, 0.0)  # levemente acima do jardim, evita z-fighting

	# Asfalto: granulado fino, sem brilho
	var ruido_rua  := MateriaisProcedurais.criar_textura_ruido(0.6, 256)
	var normal_rua := MateriaisProcedurais.criar_normal_ruido(4.0, 1.5, 256)
	var mat := MateriaisProcedurais.criar_material_texturizado(
		Color(0.15, 0.15, 0.16), 0.98, ruido_rua, Vector3(3.0, 3.0, 3.0), normal_rua, 0.8)
	rua.set_surface_override_material(0, mat)

	# Calçadas dos dois lados — é a faixa clara ladeando o asfalto que faz a
	# rua ler como rua de bairro, e não como uma fita preta no gramado.
	var ruido_calcada := MateriaisProcedurais.criar_textura_ruido(0.5, 256)
	var mat_calcada := MateriaisProcedurais.criar_material_texturizado(
		Color(0.62, 0.61, 0.58), 0.95, ruido_calcada, Vector3(3.0, 3.0, 3.0))
	for dx in [1.9, -1.9]:
		var calcada := MeshInstance3D.new()
		add_child(calcada)
		var box_calcada := BoxMesh.new()
		box_calcada.size = Vector3(0.8, 0.12, 90.0)
		calcada.mesh     = box_calcada
		calcada.position = Vector3(PAREDE_OESTE_X - 8.5 + dx, 0.06, 0.0)
		calcada.set_surface_override_material(0, mat_calcada)


## Fila de casas do outro lado da rua + vizinhos do lado de cá, fora do cone
## da janela. Variação de cor, telhado e escala vem de seed fixa: sem ela as
## casas viram cópias idênticas e a rua denuncia o loop.
func _criar_vizinhanca() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 8801

	var cores_corpo: Array[Color] = [
		Color(0.75, 0.65, 0.50),   # reboco cru
		Color(0.82, 0.78, 0.70),   # bege claro
		Color(0.66, 0.70, 0.66),   # verde acinzentado
		Color(0.80, 0.72, 0.66),   # terracota lavado
		Color(0.72, 0.74, 0.80),   # azul acinzentado
	]
	var cores_telhado: Array[Color] = [
		Color(0.40, 0.22, 0.18),   # telha de barro
		Color(0.30, 0.26, 0.26),   # fibrocimento escuro
		Color(0.46, 0.28, 0.20),   # barro mais claro
	]

	# Do outro lado da rua, alinhadas pela calçada
	for z in [-27.0, -18.0, -9.0, 0.0, 9.0, 18.0, 27.0]:
		_criar_casa(
			Vector3(PAREDE_OESTE_X - 11.5 - rng.randf_range(0.0, 1.2), 0.0, z),
			cores_corpo[rng.randi() % cores_corpo.size()],
			cores_telhado[rng.randi() % cores_telhado.size()],
			rng.randf_range(0.85, 1.15))

	# Vizinhos do lado de cá — só nas pontas, longe do que a janela enquadra
	for z in [-21.0, 17.0]:
		_criar_casa(
			Vector3(PAREDE_OESTE_X - 4.0, 0.0, z),
			cores_corpo[rng.randi() % cores_corpo.size()],
			cores_telhado[rng.randi() % cores_telhado.size()],
			rng.randf_range(0.9, 1.1))

	# Árvores da calçada, ritmadas — o alinhamento é o que dá "rua" em vez de
	# "árvores jogadas no gramado".
	# Nenhuma em Z ∈ [-2, +2]: o sol vem do oeste na horizontal, então árvore
	# nessa faixa volta a rendilhar a luz no chão do quarto.
	for z in [-24.0, -13.0, -6.0, 11.0, 22.0]:
		_criar_arvore(Vector3(PAREDE_OESTE_X - 6.2, 0.0, z), rng.randf_range(0.8, 1.1))


func _criar_casa(
	pos: Vector3,
	cor_corpo: Color = Color(0.75, 0.65, 0.5),
	cor_telhado: Color = Color(0.4, 0.22, 0.18),
	escala: float = 1.0
) -> void:
	var casa := Node3D.new()
	add_child(casa)
	casa.position = pos
	casa.scale    = Vector3.ONE * escala

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
		cor_corpo, 0.9, ruido_corpo, Vector3(2.0, 2.0, 2.0), normal_corpo, 1.0)
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
		cor_telhado, 0.85, ruido_telhado, Vector3(2.0, 2.0, 6.0), normal_telhado, 1.5)
	telhado.set_surface_override_material(0, mat_telhado)

	_criar_janelas_casa(casa)


## Janelas e porta da fachada voltada pra cá (+X, o lado da rua).
##
## O vidro é OPACO de propósito: painel escuro chapado, sem transparência.
## Vidro de verdade aqui só entregaria que a casa é uma caixa vazia por dentro
## — janela de casa vista da rua é um retângulo escuro refletindo céu, e é
## exatamente essa leitura que serve.
func _criar_janelas_casa(casa: Node3D) -> void:
	var x: float = 2.51   # rente à face +X do corpo (5.0 de largura)
	var mat_moldura := _material_liso(Color(0.90, 0.88, 0.84), 0.7)
	var mat_vidro   := _material_liso(Color(0.16, 0.20, 0.26), 0.15)
	mat_vidro.metallic          = 0.25
	mat_vidro.metallic_specular = 0.8

	for z in [-1.7, 1.7]:
		_caixa_casa(casa, Vector3(0.06, 1.1, 1.3), Vector3(x, 1.6, z), mat_moldura)
		_caixa_casa(casa, Vector3(0.04, 0.94, 1.14), Vector3(x + 0.02, 1.6, z), mat_vidro)
		# cruz da janela, igual à do quarto
		_caixa_casa(casa, Vector3(0.06, 0.05, 1.14), Vector3(x + 0.03, 1.6, z), mat_moldura)
		_caixa_casa(casa, Vector3(0.06, 0.94, 0.05), Vector3(x + 0.03, 1.6, z), mat_moldura)

	# Porta da frente, entre as duas janelas
	_caixa_casa(casa, Vector3(0.06, 2.1, 0.95), Vector3(x, 1.05, 0.0), mat_moldura)
	_caixa_casa(casa, Vector3(0.05, 1.98, 0.84), Vector3(x + 0.02, 1.0, 0.0),
		_material_liso(Color(0.34, 0.20, 0.14), 0.6))


func _caixa_casa(pai: Node3D, tamanho: Vector3, pos: Vector3, mat: Material) -> void:
	var no := MeshInstance3D.new()
	pai.add_child(no)
	var box := BoxMesh.new()
	box.size    = tamanho
	no.mesh     = box
	no.position = pos
	no.set_surface_override_material(0, mat)


## Material chapado, sem ruído nem normal — pra peça pequena vista de longe o
## detalhe procedural só vira sujeira.
func _material_liso(cor: Color, aspereza: float) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = cor
	mat.roughness    = aspereza
	return mat


## Luz de preenchimento SÓ do lado de fora.
##
## O sol vem do oeste (é o que faz a luz entrar pela janela), então tudo que a
## janela enquadra está de costas pra ele: as fachadas da vizinhança ficavam
## chapadas de cinza, só com a luz ambiente. Esta luz vem do leste, fraca e sem
## sombra, e só acende o que está na CAMADA_EXTERNA — o quarto continua com a
## iluminação que tem, senão o problema de parede lavada voltava pela janela.
func _criar_preenchimento_externo() -> void:
	for no in _todos_meshes(self):
		no.layers |= CAMADA_EXTERNA

	var luz := DirectionalLight3D.new()
	add_child(luz)
	luz.rotation_degrees = Vector3(-35.0, 100.0, 0.0)
	luz.light_color      = Color(0.86, 0.90, 1.0)  # frio: é céu, não sol
	luz.light_energy     = 0.55
	luz.shadow_enabled   = false
	luz.light_cull_mask  = CAMADA_EXTERNA


func _todos_meshes(raiz: Node) -> Array[MeshInstance3D]:
	var achados: Array[MeshInstance3D] = []
	for filho in raiz.get_children():
		if filho is MeshInstance3D:
			achados.append(filho)
		achados.append_array(_todos_meshes(filho))
	return achados


## Espalha mais árvores e casas em profundidade variável (além do grupo
## próximo da janela), pra quebrar a sensação de vazio até onde a vista alcança.
## Seed fixa — decoração, não precisa variar entre execuções.
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
