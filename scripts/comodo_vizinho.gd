extends Node3D

# ─────────────────────────────────────────────
#  CÔMODO VIZINHO — o que se vê quando a porta abre (parede leste, X=+3.5)
#
#  Antes daqui a porta abria pro vazio: fundo preto, sem chão, denunciando
#  que o quarto é uma caixa solta no espaço. Este cômodo existe SÓ pra ser
#  visto pelo vão da porta, de longe e de raspão — por isso é uma sala/cozinha
#  sugerida (piso frio, parede amarelo-clara, bancada, geladeira), não um
#  cômodo jogável. Nada aqui tem colisão nem _process.
#
#  Ocupa X ∈ [+3.6, +10.0], Z ∈ [-4.0, +2.0] — o Z bate com o do quarto de
#  propósito: a parede leste do quarto já fecha esse lado, então não sobra
#  fresta de luz entre os dois cômodos.
#
#  Tudo em código, como cenario_externo.gd (a cena não tem nós pré-criados
#  pra isso).
# ─────────────────────────────────────────────

const PAREDE_LESTE_X: float = 3.5   # plano da parede com a porta
const FUNDO_X: float = 10.0         # parede oposta
const Z_NORTE: float = -4.0
const Z_SUL: float = 2.0
const ALTURA: float = 3.0

const COR_PAREDE: Color = Color(0.94, 0.89, 0.66)   # amarelo clarinho
const COR_TETO: Color = Color(0.92, 0.91, 0.88)     # mesmo gesso do quarto

## Piso frio: porcelanato claro, 60×60 com rejunte fino. Igual ao assoalho do
## quarto, a junta é fresta de VERDADE entre peças — em low-poly, geometria
## lê melhor que normal map fingido (ver inicializar_quarto.gd).
const LADO_PISO: float = 0.6
const REJUNTE: float = 0.008


func _ready() -> void:
	_criar_piso()
	_criar_paredes()
	_criar_luz()
	_criar_bancada()
	_criar_geladeira()


func _criar_piso() -> void:
	# Contrapiso por baixo — sem ele as frestas do porcelanato dão no vazio
	# (mesmo motivo do contrapiso do assoalho do quarto). Cinza de rejunte, não
	# preto: o vão entre peças é fino, e escuro demais ele vira grade preta.
	var base := _caixa(
		Vector3(FUNDO_X - PAREDE_LESTE_X, 0.2, Z_SUL - Z_NORTE),
		Vector3((PAREDE_LESTE_X + FUNDO_X) * 0.5, -0.1, (Z_NORTE + Z_SUL) * 0.5),
		_material(Color(0.55, 0.53, 0.50), 0.95))
	base.name = "Contrapiso"

	var rng := RandomNumberGenerator.new()
	rng.seed = 20260801  # decoração: fixa, pra não mudar entre execuções

	var raiz := Node3D.new()
	raiz.name = "Porcelanato"
	add_child(raiz)

	var x: float = PAREDE_LESTE_X + 0.1
	while x < FUNDO_X:
		var z: float = Z_NORTE
		while z < Z_SUL:
			var lx: float = minf(LADO_PISO, FUNDO_X - x)
			var lz: float = minf(LADO_PISO, Z_SUL - z)
			if lx < 0.05 or lz < 0.05:
				z += LADO_PISO
				continue

			# Porcelanato é quase uniforme; a variação é mínima, só o bastante
			# pra o piso não ler como um plano chapado só.
			var tom: float = 0.97 + rng.randf() * 0.06
			var mat := _material(Color(0.80, 0.78, 0.74) * tom, 0.25)
			mat.metallic_specular = 0.6  # piso frio reflete a luz do teto

			var peca := MeshInstance3D.new()
			raiz.add_child(peca)
			var box := BoxMesh.new()
			box.size = Vector3(lx - REJUNTE, 0.04, lz - REJUNTE)
			peca.mesh = box
			peca.position = Vector3(x + lx * 0.5, -0.02, z + lz * 0.5)
			peca.set_surface_override_material(0, mat)

			z += LADO_PISO
		x += LADO_PISO


func _criar_paredes() -> void:
	var mat := _material(COR_PAREDE, 0.9)
	var largura: float = FUNDO_X - PAREDE_LESTE_X
	var profundidade: float = Z_SUL - Z_NORTE
	var meio_x: float = (PAREDE_LESTE_X + FUNDO_X) * 0.5
	var meio_z: float = (Z_NORTE + Z_SUL) * 0.5

	# Fundo (X = FUNDO_X) e as duas laterais. O lado do quarto já está fechado
	# pela parede leste dele, então não tem parede aqui.
	_caixa(Vector3(0.2, ALTURA, profundidade),
		Vector3(FUNDO_X, ALTURA * 0.5, meio_z), mat).name = "ParedeFundo"
	_caixa(Vector3(largura, ALTURA, 0.2),
		Vector3(meio_x, ALTURA * 0.5, Z_NORTE), mat).name = "ParedeNorte"
	_caixa(Vector3(largura, ALTURA, 0.2),
		Vector3(meio_x, ALTURA * 0.5, Z_SUL), mat).name = "ParedeSul"

	# Teto: sem ele o sol entraria por cima e o cômodo viraria pátio.
	_caixa(Vector3(largura, 0.2, profundidade),
		Vector3(meio_x, ALTURA + 0.1, meio_z), _material(COR_TETO, 0.95)).name = "Teto"

	# Rodapé, do mesmo tom do teto — é ele que dá o "isto é um cômodo" no
	# vislumbre rápido pelo vão da porta.
	var mat_rodape := _material(Color(0.88, 0.87, 0.84), 0.8)
	_caixa(Vector3(0.06, 0.12, profundidade),
		Vector3(FUNDO_X - 0.13, 0.06, meio_z), mat_rodape).name = "RodapeFundo"
	for z in [Z_NORTE + 0.13, Z_SUL - 0.13]:
		_caixa(Vector3(largura, 0.12, 0.06),
			Vector3(meio_x, 0.06, z), mat_rodape).name = "Rodape"


## Luz de teto do cômodo vizinho: mais fria e mais fraca que a lâmpada do
## quarto, pra o vão da porta ler como "outro ambiente" e não como extensão
## deste. Sem sombra — nada aqui é observado de perto, e sombra custa.
func _criar_luz() -> void:
	var luz := OmniLight3D.new()
	add_child(luz)
	luz.position       = Vector3(6.6, 2.7, -0.8)
	luz.light_color    = Color(1.0, 0.95, 0.86)
	luz.light_energy   = 1.6
	luz.omni_range     = 9.0
	luz.shadow_enabled = false

	var plafon := _caixa(Vector3(0.5, 0.08, 0.5), Vector3(6.6, 2.9, -0.8),
		_material(Color(0.95, 0.93, 0.88), 0.5))
	plafon.name = "Plafon"
	var mat_plafon := plafon.get_surface_override_material(0) as StandardMaterial3D
	mat_plafon.emission_enabled           = true
	mat_plafon.emission                   = Color(1.0, 0.95, 0.85)
	mat_plafon.emission_energy_multiplier = 1.2


## Bancada de cozinha encostada na parede do fundo: corpo claro + tampo de
## granito escuro. É o contraste do tampo que faz a silhueta ler como bancada.
func _criar_bancada() -> void:
	var mat_corpo := _material(Color(0.86, 0.84, 0.80), 0.6)
	var mat_tampo := _material(Color(0.22, 0.21, 0.23), 0.35)

	_caixa(Vector3(0.62, 0.86, 2.6), Vector3(FUNDO_X - 0.45, 0.43, -0.6), mat_corpo).name = "Bancada"
	_caixa(Vector3(0.68, 0.05, 2.66), Vector3(FUNDO_X - 0.45, 0.885, -0.6), mat_tampo).name = "Tampo"
	# Armário aéreo — preenche o vazio da parede acima da bancada
	_caixa(Vector3(0.35, 0.7, 2.0), Vector3(FUNDO_X - 0.32, 1.95, -0.6), mat_corpo).name = "ArmarioAereo"


## Geladeira: a silhueta que sozinha já diz "cozinha" no vislumbre pela porta.
func _criar_geladeira() -> void:
	var mat := _material(Color(0.78, 0.79, 0.81), 0.35)
	mat.metallic = 0.4
	var corpo := _caixa(Vector3(0.7, 1.75, 0.72), Vector3(FUNDO_X - 0.5, 0.875, 1.2), mat)
	corpo.name = "Geladeira"
	# Fresta entre freezer e refrigerador — quebra o bloco liso
	_caixa(Vector3(0.72, 0.02, 0.74), Vector3(FUNDO_X - 0.5, 1.25, 1.2),
		_material(Color(0.55, 0.56, 0.58), 0.5)).name = "FrestaGeladeira"


func _caixa(tamanho: Vector3, pos: Vector3, mat: Material) -> MeshInstance3D:
	var no := MeshInstance3D.new()
	add_child(no)
	var box := BoxMesh.new()
	box.size    = tamanho
	no.mesh     = box
	no.position = pos
	no.set_surface_override_material(0, mat)
	return no


func _material(cor: Color, aspereza: float) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = cor
	mat.roughness    = aspereza
	return mat
