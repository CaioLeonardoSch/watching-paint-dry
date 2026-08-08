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

const PAREDE_OESTE_X: float = -3.0  # plano da parede com a janela (6 × 6, ver G6)


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


## Árvore. **Modelo de terceiro desde 08/08/2026** (ver `CREDITOS.md`) — antes
## era um cilindro com três esferas em cima e material procedural com normal map.
##
## O modelo tem 5,0 m em `escala` 1,0, quase o mesmo da versão procedural (~4,5),
## então as escalas que os chamadores já passavam continuam valendo.
func _criar_arvore(pos: Vector3, escala: float = 1.0) -> void:
	var cena: PackedScene = load("res://models/arvore_pinheiro.glb")
	var arvore: Node3D = cena.instantiate()
	add_child(arvore)
	arvore.position = pos
	arvore.scale    = Vector3.ONE * escala
	# Giro derivado da POSIÇÃO, não de um RNG: 17 árvores do mesmo modelo em fila
	# viram padrão visível, e um gerador com estado amarraria o resultado à ordem
	# das chamadas. Assim cada árvore tem sempre o mesmo giro, independente de
	# quem criou primeiro.
	arvore.rotation.y = _giro_do_lugar(pos)
	_tingir(arvore, Color(1.0, 1.0, 1.0).lerp(
		Color(0.82, 1.0, 0.78), _ruido_do_lugar(pos, 31.7)))


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

	# Tons de fachada, agora como MULTIPLICADOR do albedo do modelo (ver
	# `_criar_casa`), não como cor chapada. Todos perto do branco de propósito:
	# o que se quer é uma rua onde nenhuma casa é igual à vizinha, não cinco
	# casas de cores diferentes — isso viraria fileira de casinha de brinquedo.
	var tons: Array[Color] = [
		Color(1.00, 0.97, 0.92),   # puxa pro creme
		Color(0.93, 0.96, 1.00),   # puxa pro frio
		Color(0.97, 1.00, 0.94),   # puxa pro verde
		Color(1.00, 0.94, 0.90),   # puxa pro terracota
		Color(0.95, 0.94, 0.97),   # levemente lavada
	]

	# Do outro lado da rua, alinhadas pela calçada
	for z in [-27.0, -18.0, -9.0, 0.0, 9.0, 18.0, 27.0]:
		_criar_casa(
			Vector3(PAREDE_OESTE_X - 11.5 - rng.randf_range(0.0, 1.2), 0.0, z),
			tons[rng.randi() % tons.size()],
			rng.randf_range(0.85, 1.15))

	# Vizinhos do lado de cá — só nas pontas, longe do que a janela enquadra
	for z in [-21.0, 17.0]:
		_criar_casa(
			Vector3(PAREDE_OESTE_X - 4.0, 0.0, z),
			tons[rng.randi() % tons.size()],
			rng.randf_range(0.9, 1.1))

	# Árvores da calçada, ritmadas — o alinhamento é o que dá "rua" em vez de
	# "árvores jogadas no gramado".
	# Nenhuma em Z ∈ [-3, +1]: a janela agora e centrada em Z = -1, e o sol vem
	# do oeste na horizontal, então árvore
	# nessa faixa volta a rendilhar a luz no chão do quarto.
	for z in [-24.0, -13.0, -6.0, 11.0, 22.0]:
		_criar_arvore(Vector3(PAREDE_OESTE_X - 6.2, 0.0, z), rng.randf_range(0.8, 1.1))


## Casa da vizinhança. **Modelo de terceiro desde 08/08/2026** (ver
## `CREDITOS.md`) — antes era caixa + prisma de telhado + janelas de caixinha,
## tudo com material procedural.
##
## `tom` multiplica o albedo do modelo inteiro. Não é capricho: a versão
## procedural sorteava cor de corpo E de telhado justamente porque **casa
## repetida entrega o loop da rua na hora**, e trocar por um modelo único
## reabriria esse buraco. Multiplicar perto do branco desloca o tom sem destruir
## a paleta que o autor pintou.
##
## A fachada (porta e varanda) sai do Blender virada pro −Z. Aqui ela é girada
## pra olhar o +X, que é o lado da rua e o lado de onde a janela do quarto vê.
func _criar_casa(pos: Vector3, tom: Color = Color.WHITE, escala: float = 1.0) -> void:
	var cena: PackedScene = load("res://models/casa_vizinha.glb")
	var casa: Node3D = cena.instantiate()
	add_child(casa)
	casa.position = pos
	casa.scale    = Vector3.ONE * escala
	# −Z do nó apontando pro +X do mundo, mais um desvio pequeno derivado do lugar:
	# fila de casas perfeitamente alinhada também lê como cópia.
	casa.rotation.y = PI * 0.5 + (_ruido_do_lugar(pos, 57.3) - 0.5) * 0.16
	_tingir(casa, tom)


## Pseudoaleatório determinístico a partir de um ponto do mundo, em 0-1.
##
## Substitui passar um `RandomNumberGenerator` por toda a cadeia de criação. A
## vantagem não é economia de código: com RNG, o valor de cada peça depende da
## ORDEM em que ela foi criada, então mexer numa lista embaralha a decoração
## inteira. Assim cada lugar tem sempre o mesmo sorteio.
static func _ruido_do_lugar(pos: Vector3, semente: float) -> float:
	return fposmod(sin(pos.x * 12.9898 + pos.z * 78.233 + semente) * 43758.5453, 1.0)


static func _giro_do_lugar(pos: Vector3) -> float:
	return _ruido_do_lugar(pos, 4.7) * TAU


## Multiplica o albedo de todas as superfícies de um galho da árvore de nós.
##
## Duplica o material por instância — sem isso, tingir uma casa tingiria todas,
## porque o `.glb` compartilha o mesmo recurso entre as instâncias. São ~11 casas
## e ~17 árvores, então o custo de não compartilhar material é irrelevante aqui.
func _tingir(raiz: Node, tom: Color) -> void:
	if tom == Color.WHITE:
		return
	for no in _todos_meshes(raiz):
		var malha: Mesh = no.mesh
		if malha == null:
			continue
		for i in malha.get_surface_count():
			var base: Material = malha.surface_get_material(i)
			if base == null:
				continue
			var copia: StandardMaterial3D = base.duplicate() as StandardMaterial3D
			if copia == null:
				continue
			copia.albedo_color = copia.albedo_color * tom
			no.set_surface_override_material(i, copia)


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

	_criar_casa(Vector3(PAREDE_OESTE_X - 35.0, 0.0, -18.0), Color(0.96, 0.97, 1.00), 1.05)
	_criar_casa(Vector3(PAREDE_OESTE_X - 55.0, 0.0, 22.0), Color(1.00, 0.96, 0.93), 0.95)
