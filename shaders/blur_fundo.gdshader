shader_type canvas_item;

// ─────────────────────────────────────────────
//  BLUR DO FUNDO DO MENU
//
//  Box blur simples em 2 passadas (horizontal + vertical) somadas num só
//  fragment — suficiente pra desfocar o quarto atrás dos painéis sem
//  precisar de viewport extra. raio em unidades de UV (0..1).
// ─────────────────────────────────────────────

uniform float raio : hint_range(0.0, 0.03) = 0.010;
uniform int amostras : hint_range(1, 6) = 3;
uniform vec4 tingimento : source_color = vec4(0.0, 0.0, 0.0, 0.25);

void fragment() {
	vec4 soma = vec4(0.0);
	float peso_total = 0.0;
	float passo = raio / float(amostras);

	for (int x = -amostras; x <= amostras; x++) {
		for (int y = -amostras; y <= amostras; y++) {
			vec2 deslocamento = vec2(float(x), float(y)) * passo;
			soma += texture(TEXTURE, UV + deslocamento);
			peso_total += 1.0;
		}
	}

	vec4 cor_borrada = soma / peso_total;
	COLOR = vec4(mix(cor_borrada.rgb, tingimento.rgb, tingimento.a), cor_borrada.a);
}
