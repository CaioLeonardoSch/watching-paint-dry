shader_type texture_blit;
render_mode blend_add;

// ─────────────────────────────────────────────
//  HISTÓRICO DE COBERTURA (Fase G3)
//
//  Soma no histórico a cobertura que a demão que acabou de terminar mostrou na
//  tela. Roda uma vez por demão, antes de a máscara recente ser limpa.
//
//  Por que guardar a COBERTURA já calculada, e não a máscara crua:
//
//  1. Se guardasse o acumulador de depósito (`acumulada.r`), a conta do
//     depósito desta demão seria `acumulada.r - historico.r`. Só que a
//     acumulada é RGBA8 com blend_add e **satura em 1**: depois que a 1ª demão
//     cobre um ponto, a 2ª e a 3ª depositam zero ali e simplesmente não
//     aparecem. Testado — a parede parava de mudar.
//
//  2. Guardando o mesmo número que o shader da parede mostrou, a costura entre
//     demãos fecha por construção: no instante em que a demão troca, o fundo
//     passa a ser exatamente o que estava na tela. Medido: o salto médio da
//     parede na troca é de 1,0 de 255.
//
//  blend_add porque cobertura não diminui — se a 1ª demão cobriu bem um ponto,
//  ele continua coberto mesmo que a 2ª passe magra ali. Satura em 1 sozinho, e
//  aqui saturar é o comportamento certo: coberto é coberto.
//
//  ATENÇÃO: o bloco é blit(), NÃO fragment() (ver PLANO-OVERHAUL-TINTA.md 3.7).
// ─────────────────────────────────────────────

uniform sampler2D fonte : hint_blit_source0;

// Mesmo box do carimbo que o shader da parede usa. Tem que ser o MESMO filtro e
// os MESMOS limiares, senão a costura reabre por diferença de suavização.
uniform vec2  passo = vec2(0.001);
uniform float cobertura_min = 0.0;
uniform float cobertura_max = 0.21;

void blit() {
	float s = 0.0;
	for (int i = -1; i <= 1; i++) {
		for (int j = -1; j <= 1; j++) {
			s += texture(fonte, UV + vec2(float(i), float(j)) * passo).g;
		}
	}
	COLOR0 = vec4(smoothstep(cobertura_min, cobertura_max, s / 9.0), 0.0, 0.0, 0.0);
}
