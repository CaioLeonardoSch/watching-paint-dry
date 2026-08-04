shader_type texture_blit;
render_mode blend_add;

// ─────────────────────────────────────────────
//  CARIMBO — camada ACUMULADA (R cobertura, G espessura)
//
//  blend_add porque as duas coisas somam: passar de novo no mesmo lugar
//  cobre mais e engrossa a camada. A cobertura satura em 1 sozinha (clamp
//  do RGBA8), que é exatamente o comportamento desejado — depois de cobrir,
//  cobrir mais não muda nada. A espessura continua contando.
//
//  ATENÇÃO: o bloco é blit(), NÃO fragment(). fragment() compila em silêncio
//  e nunca executa (ver PLANO-OVERHAUL-TINTA.md 3.7).
// ─────────────────────────────────────────────

uniform sampler2D carimbo : hint_blit_source0;

uniform float angulo = 0.0;            // rotação do rolo, em radianos
uniform vec2  escala_bbox = vec2(1.0); // retângulo inteiro / tamanho do carimbo
uniform vec2  desloc_sub = vec2(0.0);  // posição sub-pixel dentro do retângulo
uniform float carga = 1.0;             // quanta tinta o rolo tem (0-1)
// Quanto uma passada engrossa. Bem baixo de propósito: a faixa do rolo é
// varrida por vários carimbos (um a cada 2,5 cm numa faixa de 5 cm), então
// cada ponto acumula bastante. A espessura é o que atrasa a secagem local —
// se ela variar demais entre o meio da passada e a borda de sobreposição, a
// parede seca listrada e fica com cara de código de barras.
uniform float ganho_espessura = 0.035;

// Margem de depósito acima do necessário pra cobrir. O perfil do carimbo soma
// exatamente 1.0 ao longo do traço (é triangular de propósito), então sem esta
// folga a cobertura ficaria igual à carga do rolo — e qualquer queda de carga
// viraria falha bem visível. Com a folga, rolo cheio satura e só rolo baixo
// deixa marca, que é o comportamento certo.
uniform float ganho_deposito = 1.18;

void blit() {
	// UV está no espaço do retângulo de destino (o bbox do carimbo girado).
	// Desfaz a rotação pra amostrar o carimbo no espaço dele.
	vec2 c = (UV - vec2(0.5) - desloc_sub) * escala_bbox;
	float s = sin(-angulo);
	float co = cos(-angulo);
	vec2 r = vec2(c.x * co - c.y * s, c.x * s + c.y * co) + vec2(0.5);

	// fora do carimbo não deposita nada
	if (r.x < 0.0 || r.x > 1.0 || r.y < 0.0 || r.y > 1.0) {
		COLOR0 = vec4(0.0);
	} else {
		float deposito = texture(carimbo, r).r * carga * ganho_deposito;
		COLOR0 = vec4(deposito, deposito * ganho_espessura, 0.0, 0.0);
	}
}
