extends RefCounted
class_name MateriaisProcedurais

# ─────────────────────────────────────────────
#  MATERIAIS PROCEDURAIS — helpers compartilhados
#
#  Extraído de inicializar_quarto.gd (usado ali e em cenario_externo.gd).
#  Gera textura de ruído + material com variação de tom via NoiseTexture2D,
#  sem depender de nenhuma imagem externa.
#
#  Normal map procedural (criar_normal_ruido) é o que dá relevo de verdade —
#  sem ele o ruído só pinta manchas claras/escuras numa superfície lisa e
#  fica com cara de chuvisco de TV, não de reboco/madeira.
# ─────────────────────────────────────────────

static func criar_textura_ruido(frequencia: float, tamanho: int = 512) -> NoiseTexture2D:
	var ruido := FastNoiseLite.new()
	ruido.noise_type = FastNoiseLite.TYPE_PERLIN
	ruido.frequency  = frequencia
	ruido.fractal_octaves = 3

	var textura := NoiseTexture2D.new()
	textura.width     = tamanho
	textura.height    = tamanho
	textura.seamless  = true
	textura.normalize = true
	textura.noise     = ruido
	return textura


## Normal map derivado de ruído — `forca` controla o quanto o relevo salta
## (0.5 = sutil tipo reboco fino, 4.0 = bem marcado tipo casca de árvore).
static func criar_normal_ruido(frequencia: float, forca: float = 2.0, tamanho: int = 512) -> NoiseTexture2D:
	var ruido := FastNoiseLite.new()
	ruido.noise_type      = FastNoiseLite.TYPE_SIMPLEX
	ruido.frequency       = frequencia
	ruido.fractal_octaves = 4

	var textura := NoiseTexture2D.new()
	textura.width         = tamanho
	textura.height        = tamanho
	textura.seamless      = true
	textura.as_normal_map = true
	textura.bump_strength = forca
	textura.noise         = ruido
	return textura


static func criar_material_texturizado(
	cor: Color,
	aspereza: float,
	ruido: NoiseTexture2D,
	escala_uv: Vector3,
	normal: NoiseTexture2D = null,
	forca_normal: float = 1.0
) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = cor
	mat.roughness    = aspereza

	# UV triplanar: BoxMesh não tem UVs contínuos entre faces,
	# então o ruído é projetado no espaço do mundo pra não esticar/repetir feio.
	mat.uv1_triplanar = true
	mat.uv1_scale     = escala_uv

	# Textura de detalhe (ruído) multiplicada sobre a cor base,
	# dá variação de tom tipo reboco/madeira sem precisar de imagem externa.
	mat.detail_enabled    = true
	mat.detail_albedo     = ruido
	mat.detail_blend_mode = BaseMaterial3D.BLEND_MODE_MUL
	mat.detail_uv_layer   = BaseMaterial3D.DETAIL_UV_1

	# Mesmo ruído também varia a aspereza — evita look "plástico" uniforme
	mat.roughness_texture = ruido

	# Relevo de verdade: a luz reage à superfície irregular em vez de bater
	# num plano liso pintado de manchinha.
	if normal:
		mat.normal_enabled = true
		mat.normal_texture = normal
		mat.normal_scale   = forca_normal

	return mat
