shader_type spatial;

uniform float num_taboas    : hint_range(2.0, 60.0) = 14.0;
uniform float largura_junta : hint_range(0.0, 0.3)  = 0.05;
uniform float forca_relevo  : hint_range(0.0, 3.0)  = 1.0;
uniform vec4  cor_clara     : source_color = vec4(0.62, 0.47, 0.32, 1.0);
uniform vec4  cor_escura    : source_color = vec4(0.40, 0.28, 0.18, 1.0);

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float ruido(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	float a = hash(i);
	float b = hash(i + vec2(1.0, 0.0));
	float c = hash(i + vec2(0.0, 1.0));
	float d = hash(i + vec2(1.0, 1.0));
	vec2 u = f * f * (3.0 - 2.0 * f);
	return mix(a, b, u.x) + (c - a) * u.y * (1.0 - u.x) + (d - b) * u.x * u.y;
}

// Campo de altura do assoalho: sulco fundo entre tábuas + veio da madeira
// esticado no comprimento + poros finos. É daqui que sai o normal map.
float altura(vec2 uv) {
	float posicao_taboa = uv.y * num_taboas;
	float indice_taboa  = floor(posicao_taboa);
	float frac_taboa    = fract(posicao_taboa);

	// Sulco entre tábuas — vai a zero na junta, 1.0 no meio da tábua
	float junta = smoothstep(0.0, largura_junta, frac_taboa)
	            * smoothstep(0.0, largura_junta, 1.0 - frac_taboa);

	// Veio: ruído bem esticado em X (fibra corre no comprimento da tábua).
	// Deslocado por tábua pra cada uma ter desenho próprio.
	float veio = ruido(vec2(uv.x * 8.0, indice_taboa * 13.7 + uv.y * 40.0));

	// Poro fino por cima, dá a micro-irregularidade da madeira
	float poro = ruido(uv * vec2(120.0, 220.0));

	return junta * (0.75 + veio * 0.2 + poro * 0.05);
}

void fragment() {
	// Cada tábua é uma faixa ao longo de UV.y; UV.x corre no comprimento da tábua.
	float posicao_taboa = UV.y * num_taboas;
	float indice_taboa   = floor(posicao_taboa);
	float frac_taboa     = fract(posicao_taboa);

	// Tom de madeira varia por tábua, como pranchas de lotes diferentes.
	float tom = hash(vec2(indice_taboa, 1.0));
	vec3 cor_base = mix(cor_escura.rgb, cor_clara.rgb, tom);

	// Veio longitudinal — agora contínuo (ruído), não listra dura por célula
	float veio = ruido(vec2(UV.x * 8.0, indice_taboa * 13.7 + UV.y * 40.0));
	cor_base *= 0.85 + veio * 0.3;

	// Junta escura entre tábuas (borda de cada faixa).
	float junta = smoothstep(0.0, largura_junta, frac_taboa)
	            * smoothstep(0.0, largura_junta, 1.0 - frac_taboa);
	cor_base *= mix(0.4, 1.0, junta);

	// Normal map por diferença finita do campo de altura — luz passa a pegar
	// no sulco entre tábuas e no veio, em vez de bater num plano liso.
	vec2 passo = vec2(0.0015, 0.0015);
	float h_centro = altura(UV);
	float dx = altura(UV + vec2(passo.x, 0.0)) - h_centro;
	float dy = altura(UV + vec2(0.0, passo.y)) - h_centro;
	NORMAL_MAP = normalize(vec3(-dx * forca_relevo * 40.0, -dy * forca_relevo * 40.0, 1.0)) * 0.5 + 0.5;

	ALBEDO    = cor_base;
	// Verniz gasto: um pouco mais brilhoso no meio da tábua, fosco na junta
	ROUGHNESS = mix(0.85, mix(0.45, 0.7, hash(vec2(indice_taboa, 2.0))), junta);
	METALLIC  = 0.0;
	SPECULAR  = 0.4;
}
