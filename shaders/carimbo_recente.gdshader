shader_type texture_blit;
render_mode blend_mix;

// ─────────────────────────────────────────────
//  CARIMBO — camada RECENTE (R instante, G carga do rolo)
//
//  blend_mix porque estes dois NÃO somam: o que vale é o valor mais recente.
//  O alfa da saída vira o peso da substituição — onde o rolo passou forte, o
//  instante novo domina; onde passou de raspão, mistura com o que estava lá.
//  Isso é o que gera lap mark: a borda entre "passou agora" e "passou faz
//  tempo" fica com um degrau no canal R, e o shader da parede lê esse degrau.
//
//  ATENÇÃO: o bloco é blit(), NÃO fragment().
// ─────────────────────────────────────────────

uniform sampler2D carimbo : hint_blit_source0;

uniform float angulo = 0.0;
uniform vec2  escala_bbox = vec2(1.0); // retângulo inteiro / tamanho do carimbo
uniform vec2  desloc_sub = vec2(0.0);  // posição sub-pixel dentro do retângulo
uniform float carga = 1.0;
uniform float instante = 0.0;  // 0-1, normalizado na janela da demão

void blit() {
	vec2 c = (UV - vec2(0.5) - desloc_sub) * escala_bbox;
	float s = sin(-angulo);
	float co = cos(-angulo);
	vec2 r = vec2(c.x * co - c.y * s, c.x * s + c.y * co) + vec2(0.5);

	if (r.x < 0.0 || r.x > 1.0 || r.y < 0.0 || r.y > 1.0) {
		COLOR0 = vec4(0.0);
	} else {
		// Peso da substituição = QUANTO DO ROLO encostou aqui, e só isso.
		//
		// ⚠️ A carga NÃO entra no peso. Ela já é o valor gravado em G, e estar
		// nos dois lugares fazia o canal andar com o QUADRADO da carga: com o
		// rolo no fundo (0,30) o G convergia pra ~0,15, e a falha de cobertura
		// saía com o dobro da profundidade que a física pedia. Medido antes de
		// tirar: G médio 0,398 numa parede cuja carga média é 0,685.
		//
		// G guarda a carga e serve de marcador de "passei aqui nesta demão" —
		// é zerado no início de cada demão e o shader da parede lê isso como
		// cobertura da camada atual. Com o peso puramente geométrico, ele
		// converge pra carga de verdade, que é o que o nome dele promete.
		float peso = texture(carimbo, r).r;
		COLOR0 = vec4(instante, carga, 0.0, peso);
	}
}
