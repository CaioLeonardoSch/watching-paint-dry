extends MeshInstance3D

# ─────────────────────────────────────────────
#  TINTA SECANDO NA PAREDE
#
#  Vai no nó ParedeNorteSolida.
#  Usa call_deferred pra garantir que o mesh já foi criado
#  pelo inicializar_quarto.gd antes de aplicar o material.
# ─────────────────────────────────────────────

@export var tempo_secagem_segundos: float = 600.0
@export var cor_molhada: Color = Color(0.18, 0.38, 0.72)
@export var cor_seca:    Color = Color(0.38, 0.58, 0.88)

var _tempo_atual: float = 0.0
var _material: ShaderMaterial


func _ready() -> void:
	# Adia a criação do material para depois que o mesh for atribuído
	call_deferred("_setup")


func _setup() -> void:
	_criar_material()
	_atualizar_material(0.0)


func _process(delta: float) -> void:
	if _tempo_atual >= tempo_secagem_segundos:
		return

	_tempo_atual += delta
	var fracao: float = clamp(_tempo_atual / tempo_secagem_segundos, 0.0, 1.0)
	_atualizar_material(fracao)


func _criar_material() -> void:
	_material = ShaderMaterial.new()

	var shader := Shader.new()
	shader.code = """
shader_type spatial;

uniform float fracao_seca : hint_range(0.0, 1.0) = 0.0;
uniform vec4  cor_atual   : source_color = vec4(0.2, 0.4, 0.8, 1.0);

void fragment() {
	ALBEDO    = cor_atual.rgb;
	ROUGHNESS = mix(0.05, 0.85, fracao_seca);
	METALLIC  = mix(0.2,  0.0,  fracao_seca);

	// Frente de secagem com variação de UV — bordas secam antes
	float noise = fract(sin(dot(UV * 8.0, vec2(127.1, 311.7))) * 43758.5453);
	float borda  = smoothstep(fracao_seca - 0.15, fracao_seca + 0.15, noise);
	ROUGHNESS = mix(ROUGHNESS * 0.6, ROUGHNESS, borda);
}
"""
	_material.shader = shader
	set_surface_override_material(0, _material)


func _atualizar_material(fracao: float) -> void:
	if not _material:
		return
	var cor_atual: Color = cor_molhada.lerp(cor_seca, fracao)
	_material.set_shader_parameter("fracao_seca", fracao)
	_material.set_shader_parameter("cor_atual",   cor_atual)


func resetar() -> void:
	_tempo_atual = 0.0
	_atualizar_material(0.0)


func get_fracao_seca() -> float:
	return clamp(_tempo_atual / tempo_secagem_segundos, 0.0, 1.0)
