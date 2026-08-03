shader_type spatial;

// ─────────────────────────────────────────────
//  TINTA SECANDO — lida da máscara do rolo
//
//  A versão antiga deduzia "quando fui pintado" projetando a posição num
//  eixo de varredura. Isso limitava a frente de pintura a uma linha reta
//  atravessando a parede, e tornava impossível falha de cobertura,
//  sobreposição e lap mark (ver PLANO-OVERHAUL-TINTA.md 1.1).
//
//  Agora cada ponto lê o histórico do que o rolo de fato fez ali:
//    acumulada  R = cobertura (0-1)   G = espessura (nº de passadas)
//    recente    R = instante 0-1      G = carga do rolo naquela hora
//
//  A parede é picada em vários MeshInstance3D (por causa das aberturas de
//  janela e porta), então o UV da máscara NÃO vem do UV do mesh — vem da
//  posição de mundo projetada no plano da parede. Assim as peças amostram
//  uma máscara contínua, sem costura, e a geometria fica intacta.
// ─────────────────────────────────────────────

uniform sampler2D mascara_acumulada : filter_linear, repeat_disable;
uniform sampler2D mascara_recente   : filter_linear, repeat_disable;

uniform vec4 cor_anterior : source_color = vec4(0.93, 0.92, 0.90, 1.0);  // o que já estava na parede
// Molhada é MAIS CLARA que a seca: o ligante da látex é branco leitoso
// enquanto tem água e fica transparente ao secar (ver cor_tinta.gd).
uniform vec4 cor_molhada  : source_color = vec4(0.44, 0.57, 0.76, 1.0);
uniform vec4 cor_seca     : source_color = vec4(0.38, 0.51, 0.74, 1.0);

// Plano da parede em espaço de mundo: canto de origem + os dois eixos, cada
// um com o comprimento do lado. Ver mapeamento em tinta_secando.gd.
uniform vec3 origem_parede = vec3(0.0);
uniform vec3 eixo_u = vec3(1.0, 0.0, 0.0);
uniform vec3 eixo_v = vec3(0.0, 1.0, 0.0);

uniform float tempo_decorrido = 0.0;   // segundos desde o começo desta demão
uniform float janela_demao    = 8.0;   // quanto dura a pintura (desnormaliza o instante)
uniform float duracao_secagem = 60.0;  // quanto um ponto de espessura normal leva pra secar

// Quanto a espessura atrasa a secagem. É daqui que sai a fase manchada: onde
// o rolo passou duas vezes a camada é mais grossa e seca depois, então a
// mancha desenha o que ele realmente pintou em vez de ruído solto.
uniform float atraso_por_espessura = 0.55;

uniform float limiar_lap = 0.35;  // segundos de diferença que já marcam lap

// Quanto a marca do rolo aparece. Cai a cada demão (ver iniciar_demao): a
// primeira camada sobre reboco cru mostra bastante variação, a terceira já
// está quase lisa — que é como parede pintada de verdade se comporta.
uniform float suavidade_demao = 1.0;
uniform float forca_marca = 0.09;

// Faixa da carga gravada que conta como "coberto". A máscara recente é escrita
// com blend_mix, então o valor converge pra ALGO ABAIXO da carga real do rolo
// (cada carimbo mistura parcialmente, e as bordas pesam pouco). Normalizar
// pela carga cheia deixava um quarto da cor de baixo aparecendo e a parede
// saía lavada. O limiar baixo faz uma passada de rolo já cobrir de verdade.
uniform float cobertura_min = 0.03;
uniform float cobertura_max = 0.45;

varying vec3 pos_mundo;


void vertex() {
	pos_mundo = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}


// Projeta a posição de mundo no plano da parede, devolvendo UV 0-1.
vec2 uv_da_parede(vec3 p) {
	vec3 rel = p - origem_parede;
	return vec2(
		dot(rel, eixo_u) / dot(eixo_u, eixo_u),
		dot(rel, eixo_v) / dot(eixo_v, eixo_v));
}


void fragment() {
	vec2 uv = uv_da_parede(pos_mundo);

	vec2 acum = texture(mascara_acumulada, uv).rg;
	vec2 rec  = texture(mascara_recente, uv).rg;

	// A acumulada atravessa as demãos: é o relevo real da parede, quantas
	// camadas passaram por cada ponto. A recente é limpa a cada demão, então
	// a carga (G) vira o marcador de "o rolo passou aqui NESTA demão".
	float relevo    = acum.g;
	float cobertura = smoothstep(cobertura_min, cobertura_max, rec.g);
	float instante  = rec.r * janela_demao;   // volta pra segundos

	// ── Quanto esta camada já secou ────────────────────────────────
	// Camada grossa demora mais. Como a espessura varia ponto a ponto, a
	// parede seca desigual — que é exatamente o que tinta de verdade faz.
	float dt = tempo_decorrido - instante;
	float duracao_local = duracao_secagem * (1.0 + relevo * atraso_por_espessura);
	float fracao = clamp(dt / max(duracao_local, 0.001), 0.0, 1.0);

	// ── As fases da secagem (ver plano 3.4) ────────────────────────
	// O detalhe que quase ninguém acerta: o BRILHO some antes de a COR mudar.
	// Tinta látex perde o brilho de molhada no "flash off", bem antes de
	// clarear. Por isso são duas curvas diferentes, não um crossfade só.
	float seco_brilho = smoothstep(0.02, 0.30, fracao);
	float seco_cor    = smoothstep(0.22, 0.95, fracao);

	// ── Lap mark ───────────────────────────────────────────────────
	// Onde pincelada nova encostou em tinta já secando, fica uma linha. Isso
	// é um degrau no instante: dois pontos vizinhos pintados em momentos bem
	// distantes. Sai de graça do gradiente da máscara recente.
	vec2 texel = 1.0 / vec2(textureSize(mascara_recente, 0));
	float r_dx = texture(mascara_recente, uv + vec2(texel.x, 0.0)).r - rec.r;
	float r_dy = texture(mascara_recente, uv + vec2(0.0, texel.y)).r - rec.r;
	float salto = length(vec2(r_dx, r_dy)) * janela_demao;
	float lap = smoothstep(limiar_lap, limiar_lap * 2.0, salto) * cobertura;

	// ── Cor ────────────────────────────────────────────────────────
	// Látex seca MAIS ESCURO que molhado: o véu leitoso do ligante some e
	// sobra o pigmento. Quem monta as duas cores é cor_tinta.gd — aqui é só
	// a travessia de uma pra outra.
	vec3 cor_nova = mix(cor_molhada.rgb, cor_seca.rgb, seco_cor);

	// A lap mark é uma faixa levemente mais densa/escura de tinta
	cor_nova = mix(cor_nova, cor_nova * 0.94, lap);

	// A marca do rolo modula as DUAS cores, não só a nova. É o que impede a
	// parede de virar cor chapada no instante em que uma demão começa: a
	// camada de baixo continua exibindo o relevo que ela deixou.
	// `relevo` só aparece depois de secar — tinta molhada escorre e nivela.
	float marca = (relevo - 0.5) * forca_marca * suavidade_demao;
	vec3 base_anterior = cor_anterior.rgb * (1.0 - marca);
	cor_nova *= (1.0 - marca * seco_cor);

	// `cobertura` entra onde antes havia um smoothstep de borda. A diferença
	// é tudo: "meio pintado" agora é falha de cobertura de verdade, que
	// sobrevive à secagem e só some quando a próxima demão passa por cima.
	ALBEDO = mix(base_anterior, cor_nova, cobertura);

	// ── Superfície ─────────────────────────────────────────────────
	// Molhado NÃO é espelho: roughness baixo demais reflete o céu procedural
	// e quebra a parede em blocos visíveis (já testado e revertido antes).
	float rug_pintada = mix(0.45, 0.9, seco_brilho);
	ROUGHNESS = mix(0.92, rug_pintada, cobertura);
	ROUGHNESS = mix(ROUGHNESS, ROUGHNESS * 0.93, lap);  // lap mark brilha um pouco mais
	METALLIC  = 0.0;                                     // tinta não é metal
	SPECULAR  = mix(0.3, mix(0.38, 0.3, seco_brilho), cobertura);
}
