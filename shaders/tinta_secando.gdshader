shader_type spatial;

// ─────────────────────────────────────────────
//  TINTA SECANDO — com frente de pintura progressiva
//
//  A tinta não aparece de uma vez: uma "frente" varre a parede no sentido em
//  que o tio anda, e cada ponto só recebe a cor nova quando a frente passa
//  por ele. O relógio de secagem daquele ponto começa nesse mesmo instante,
//  então o começo da parede está mais seco que o fim — escalonado de graça,
//  sem precisar de vários materiais.
//
//  tempo_decorrido é o único valor que anda a cada frame (vindo do GDScript);
//  o resto é configuração de uma demão.
// ─────────────────────────────────────────────

uniform vec4 cor_anterior : source_color = vec4(0.9, 0.9, 0.88, 1.0);  // o que já estava na parede
uniform vec4 cor_molhada  : source_color = vec4(0.18, 0.38, 0.72, 1.0);
uniform vec4 cor_seca     : source_color = vec4(0.38, 0.58, 0.88, 1.0);

// Eixo/extensão da varredura, em espaço de mundo. A frente anda de
// `inicio_varredura` até `fim_varredura` projetados em `eixo_varredura`.
uniform vec3  eixo_varredura     = vec3(1.0, 0.0, 0.0);
uniform float inicio_varredura   = 0.0;
uniform float fim_varredura      = 1.0;

uniform float tempo_decorrido    = 0.0;   // segundos desde o começo desta demão
uniform float duracao_varredura  = 1.0;   // quanto o tio leva pra cruzar a parede
uniform float duracao_secagem    = 60.0;  // quanto um ponto leva pra secar

// Quanto a secagem "arrasta" no mesmo sentido da pintura. Sem isso a varredura
// (segundos) é curta demais perto da secagem (minutos/horas) e a parede acaba
// secando praticamente toda junta — perde a leitura de direita pra esquerda.
uniform float atraso_direcional_secagem = 0.6;

varying vec3 pos_mundo;
varying vec3 normal_mundo;

void vertex() {
	pos_mundo    = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	normal_mundo = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
}

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	float a = hash(i);
	float b = hash(i + vec2(1.0, 0.0));
	float c = hash(i + vec2(0.0, 1.0));
	float d = hash(i + vec2(1.0, 1.0));
	vec2 u = f * f * (3.0 - 2.0 * f);
	return mix(a, b, u.x) + (c - a) * u.y * (1.0 - u.x) + (d - b) * u.x * u.y;
}

// Rotaciona cada oitava ~37° — sem isso, a soma de oitavas alinhadas na mesma
// grade cria linhas retas visíveis (artefato clássico de value noise em bloco).
const mat2 ROTACAO_OITAVA = mat2(vec2(0.8, 0.6), vec2(-0.6, 0.8));

float fbm(vec2 p) {
	float valor    = 0.0;
	float amplitude = 0.5;
	float total    = 0.0;
	for (int i = 0; i < 4; i++) {
		valor    += amplitude * noise(p);
		total    += amplitude;
		p         = ROTACAO_OITAVA * p * 2.0;
		amplitude *= 0.5;
	}
	return valor / total;  // normalizado de volta pra ~0..1
}

// Projeta a posição de mundo nos 2 eixos da face (o eixo dominante da normal
// vira o descartado) — coordenada contínua ao longo de toda a parede,
// independente de em quantos MeshInstance3D ela foi picada.
vec2 coord_parede(vec3 p, vec3 n) {
	vec3 an = abs(n);
	if (an.x > an.y && an.x > an.z) {
		return p.zy;   // parede leste/oeste
	}
	if (an.z > an.y) {
		return p.xy;   // parede norte/sul
	}
	return p.xz;       // chão/teto
}

// Marca de rolo: fibras na direção da rolada + granulado. Campo de altura.
float altura_rolo(vec2 c) {
	return fbm(vec2(c.x * 4.5, c.y * 0.9)) * 0.6 + fbm(c * 2.5) * 0.4;
}

void fragment() {
	vec2 coord = coord_parede(pos_mundo, normal_mundo);

	// ── Onde a frente de pintura está em relação a este ponto ──────────
	float extensao = fim_varredura - inicio_varredura;
	float u = clamp((dot(pos_mundo, normalize(eixo_varredura)) - inicio_varredura) / extensao, 0.0, 1.0);

	// Instante (em segundos desde o início da demão) em que a frente passou
	// aqui. Duas escalas de ruído torcem a borda: uma larga (ondula a linha
	// inteira) e uma fina (esfarela a beirada). Sem isso a frente lê como uma
	// régua vertical, que é o que denunciava o polígono da parede.
	float t_pintado = u * duracao_varredura;
	t_pintado += (fbm(coord * 0.35) - 0.5) * 0.55 * duracao_varredura;
	t_pintado += (fbm(coord * 1.8)  - 0.5) * 0.18 * duracao_varredura;

	float dt = tempo_decorrido - t_pintado;   // tempo desde a pincelada aqui

	// Borda bem larga: tinta fresca de rolo não tem contorno, tem degradê.
	float largura_borda = max(0.30 * duracao_varredura, 0.25);
	float pintado = smoothstep(-largura_borda, largura_borda, dt);

	// ── Secagem: também caminha da direita pra esquerda ────────────────
	// Além de começar mais tarde onde foi pintado depois, o relógio de
	// secagem em si é atrasado proporcionalmente a `u` — assim a onda de
	// secagem repete o mesmo sentido do rolo, em vez de virar mancha solta.
	float dt_seco = dt - u * duracao_secagem * atraso_direcional_secagem;
	float fracao  = clamp(dt_seco / duracao_secagem, 0.0, 1.0);

	// Ruído só quebra a borda da onda; não domina mais o desenho.
	float mancha     = fbm(coord * 0.4) * 0.5 + 0.25;
	float local_seco = smoothstep(mancha - 0.28, mancha + 0.28, fracao);

	vec3 cor_nova = mix(cor_molhada.rgb, cor_seca.rgb, local_seco);
	ALBEDO = mix(cor_anterior.rgb, cor_nova, pintado);

	// Molhado NÃO é espelho — roughness baixo refletia o céu e quebrava a
	// parede em blocos. Faixa estreita também evita banda de brilho na frente.
	float rug_nova = mix(0.55, 0.9, local_seco);
	ROUGHNESS = mix(0.92, rug_nova, pintado);
	METALLIC  = 0.0;                                    // tinta não é metal
	SPECULAR  = mix(0.3, mix(0.38, 0.3, local_seco), pintado);

	// Micro-variação — nem seca nem molhada fica perfeitamente lisa
	ROUGHNESS += (hash(coord * 8.0) - 0.5) * 0.03;

	// Relevo de rolo quase imperceptível: parede pintada é lisa de perto.
	// Exagerar aqui vira "rasurado" e realça a faceta da geometria.
	float forca = mix(0.6, 1.0, local_seco) * pintado;
	float passo = 0.02;
	float h     = altura_rolo(coord);
	float dx    = altura_rolo(coord + vec2(passo, 0.0)) - h;
	float dy    = altura_rolo(coord + vec2(0.0, passo)) - h;
	NORMAL_MAP  = normalize(vec3(-dx * forca * 1.2, -dy * forca * 1.2, 1.0)) * 0.5 + 0.5;
}
