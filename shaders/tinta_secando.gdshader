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

// ── Campo de secagem (Fase G1) ─────────────────────────────────────────
// Antes daqui a parede inteira secava dentro de 0,4 s de diferença: a única
// variação era a espessura, comparada com 1.0 quando ela vive perto de 0,033.
// Agora quatro coisas empurram o tempo LOCAL de secagem pra cima ou pra baixo,
// e é da soma delas que sai a fase manchada.

// Mancha do campo, canal R centrado em 0,5. Lida duas vezes: uma fixa (o
// substrato, mesmo reboco em todas as demãos) e uma deslocada por demão.
uniform sampler2D mancha_secagem : filter_linear, repeat_disable;
uniform float mancha_escala = 0.6667;
uniform vec2  mancha_offset = vec2(0.0);

// Carga típica na máscara recente depois de uma passada. Medido: 0,627.
// É daqui que sai a espessura DESTA demão — não do acumulador. Ver fragment().
uniform float carga_tipica = 0.627;

// Relevo médio já na parede antes desta demão. É MEDIDO por parede_pintavel.gd,
// não estimado: o acumulador é absoluto e chega em 0,50 quando o jogo retoma de
// um save. Sem descontar, o termo saturaria o clamp na parede toda.
uniform float relevo_base = 0.0;
// Depósito médio de UMA demão no acumulador. Medido: 0,033 (pico 0,043).
uniform float espessura_demao = 0.033;
// Teto da variação. Não é higiene, é contrato: com ele duracao_total() no
// GDScript deixa de ser chute e passa a bater com o pior caso do shader.
uniform float variacao_max = 0.40;

uniform vec3  pos_janela     = vec3(0.0);
uniform float altura_parede  = 3.0;
uniform float largura_parede = 6.0;

// Soma estatística ≈ ±0,30, pico limitado a ±0,40 pelo clamp.
const float PESO_ESPESSURA = 0.45;
const float PESO_SUBSTRATO = 0.28;
const float PESO_DEMAO     = 0.16;
const float PESO_AMBIENTE  = 0.18;

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

	vec2 tam_mascara = vec2(textureSize(mascara_recente, 0));
	vec2 texel = 1.0 / tam_mascara;

	// A acumulada atravessa as demãos: é o relevo real da parede, quantas
	// camadas passaram por cada ponto. A recente é limpa a cada demão, então
	// a carga (G) vira o marcador de "o rolo passou aqui NESTA demão".
	float relevo = acum.g;

	// Máscara recente suavizada, pra alimentar o tempo de secagem.
	//
	// A recente é escrita com blend_mix a cada meia faixa do rolo, e mix NÃO é
	// partição da unidade (o carimbo triangular só soma constante com
	// blend_add). Sobra um ripple no período do carimbo, ~3,6 texels, nos DOIS
	// canais. Antes da G1 ele sumia dentro do smoothstep saturado da cobertura;
	// agora que instante e espessura entram direto no tempo local de secagem,
	// ele aparece como um pente horizontal fino atravessando a parede — lê como
	// defeito de renderização, não como tinta.
	//
	// Média 3×3 espaçada de 3 texels apaga o pente e preserva o que interessa:
	// a carga cai ao longo de cada passada (o rolo vai esvaziando) e o instante
	// anda de uma passada pra outra, e essas duas coisas variam na escala de
	// 20 cm, não de 2 mm. Suavizar o R junto é obrigatório — só o G deixava
	// metade do pente na tela, porque `instante` carrega o mesmo ripple.
	vec2 rec_suave = vec2(0.0);
	for (int i = -1; i <= 1; i++) {
		for (int j = -1; j <= 1; j++) {
			rec_suave += texture(mascara_recente,
				uv + vec2(float(i), float(j)) * texel * 3.0).rg;
		}
	}
	rec_suave /= 9.0;

	float cobertura = smoothstep(cobertura_min, cobertura_max, rec_suave.g);
	float instante  = rec_suave.r * janela_demao;   // volta pra segundos
	float carga_suave = rec_suave.g;

	// ── Campo de secagem — quanto ESTE ponto demora ────────────────
	vec2 uv_mancha = uv * mancha_escala;
	float m_substrato = texture(mancha_secagem, uv_mancha).r * 2.0 - 1.0;
	float m_demao     = texture(mancha_secagem, uv_mancha + mancha_offset).r * 2.0 - 1.0;

	// (a) Espessura RELATIVA — e da máscara RECENTE, não da acumulada.
	//
	// O que atrasa a secagem é o filme MOLHADO desta demão, e é a recente que
	// guarda isso (ela é limpa a cada demão). Usar a acumulada empilhava o
	// relevo das demãos velhas neste termo, e a dispersão da secagem CRESCIA a
	// cada camada — medido, 1,53 na 1ª demão e 2,07 na 3ª. É o contrário do
	// certo: a 3ª demão é a mais lisa, porque cai sobre substrato já selado.
	//
	// Que a 3ª demão demore mais que a 1ª também é real, mas entra como fator
	// explícito e uniforme em `duracao_secagem`, não como efeito colateral de
	// um acumulador crescendo.
	float esp_rel = carga_suave / max(carga_tipica, 1e-4) - 1.0;

	// (b) Ambiente — a única contribuição direcional, e a que faz a região seca
	// virar uma FRONTEIRA atravessando a parede em vez de manchas soltas.
	// Perto da janela há corrente de ar e mais calor, então seca antes; ar
	// quente sobe e o filme escorre pra baixo, então a base seca depois; canto
	// é ar parado. Os três em 0-1, "0 = seca primeiro".
	float f_janela = 1.0 - exp(-distance(pos_mundo, pos_janela) / 3.0);
	float f_altura = 1.0 - clamp(pos_mundo.y / altura_parede, 0.0, 1.0);
	float f_canto  = 1.0 - smoothstep(0.0, 0.6, min(uv.x, 1.0 - uv.x) * largura_parede);
	float ambiente = ((f_janela + f_altura + f_canto) / 3.0) * 2.0 - 1.0;

	// Efeito colateral mantido de propósito: o campo é determinístico, então a
	// ÚLTIMA mancha a secar é sempre o mesmo lugar — o canto de baixo mais longe
	// da janela. O jogador aprende isso sozinho e ganha um ponto pra onde olhar
	// quando quiser saber se acabou. É um ritual, não um HUD.
	float variacao = clamp(
		  esp_rel     * PESO_ESPESSURA
		+ m_substrato * PESO_SUBSTRATO
		+ m_demao     * PESO_DEMAO
		+ ambiente    * PESO_AMBIENTE,
		-variacao_max, variacao_max);

	float dt = tempo_decorrido - instante;
	float duracao_local = duracao_secagem * (1.0 + variacao);
	float fracao = clamp(dt / max(duracao_local, 0.001), 0.0, 1.0);

	// ── As fases da secagem (ver plano 3.4) ────────────────────────
	// O detalhe que quase ninguém acerta: o BRILHO some antes de a COR mudar.
	// Tinta látex perde o brilho de molhada no "flash off", bem antes de
	// clarear. Por isso são duas curvas diferentes, não um crossfade só.
	float seco_brilho = smoothstep(0.02, 0.30, fracao);
	float seco_cor    = smoothstep(0.22, 0.95, fracao);

	// A mancha é um EVENTO com começo e fim, não um ruído permanente. Molhada, a
	// parede é lisa (o filme ainda nivela); seca, é uniforme; no meio, fica de
	// nuvem. Quem só olhar antes e depois não vê mancha nenhuma — que é o que
	// tinta de verdade faz, e é o que dá vontade de ficar olhando o meio.
	float k_mancha = smoothstep(0.10, 0.40, fracao)
		* (1.0 - smoothstep(0.62, 0.92, fracao));
	float mancha = m_substrato * 0.64 + m_demao * 0.36;

	// ── Nitidez: quantos texels da máscara cabem num pixel ─────────
	// A máscara tem ~146 px/m e o `DrawableTexture2D` NÃO tem mipmap, então
	// `filter_linear` não filtra nada quando o pixel fica maior que o texel —
	// e aí a marca do rolo cintila e as faixas de 17 cm fazem moiré. `fwidth`
	// mede a derivada do UV por pixel, que é exatamente a conta de Nyquist.
	// Onde um pixel cobre mais de um texel, o detalhe some. É o que um mipmap
	// faria; como não temos um, apagamos o detalhe na mão (Fase G5).
	float texels_por_pixel = length(fwidth(uv) * tam_mascara);
	float nitidez = clamp(1.0 / max(texels_por_pixel, 0.001), 0.0, 1.0);

	// ── Lap mark ───────────────────────────────────────────────────
	// Onde pincelada nova encostou em tinta já secando, fica uma linha. Isso
	// é um degrau no instante: dois pontos vizinhos pintados em momentos bem
	// distantes. Sai de graça do gradiente da máscara recente.
	float r_dx = texture(mascara_recente, uv + vec2(texel.x, 0.0)).r - rec.r;
	float r_dy = texture(mascara_recente, uv + vec2(0.0, texel.y)).r - rec.r;
	float salto = length(vec2(r_dx, r_dy)) * janela_demao;
	// A diferença finita acima é derivada de textura por pixel multiplicando um
	// smoothstep estreito — gerador clássico de aliasing. `nitidez` desliga ela
	// justamente onde ela não teria como estar certa.
	float lap = smoothstep(limiar_lap, limiar_lap * 2.0, salto) * cobertura * nitidez;

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
	//
	// Aqui SIM é a acumulada: a marca é o relevo que ficou, de todas as demãos.
	// Mas relativa à base medida, não a `relevo - 0.5`. O 0,5 era um centro
	// chumbado que só batia por acidente, porque `preencher_coberta` grava
	// G=0,5 — numa parede pintada do zero o relevo vale ~0,033 e o termo virava
	// um escurecimento chapado de -0,47. Era essa a origem do "números inertes"
	// anotado na Fase B: o desvio real (±0,005) sumia ao lado do erro de centro.
	float relevo_rel = (relevo - relevo_base) / max(espessura_demao, 1e-4) - 0.5;
	float marca = relevo_rel * forca_marca * suavidade_demao * nitidez;
	vec3 base_anterior = cor_anterior.rgb * (1.0 - marca);
	cor_nova *= (1.0 - marca * seco_cor);

	// Manchado de tinta secando é mais diferença de BRILHO que de cor — por
	// isso aqui a cor leva metade do peso que a rugosidade leva lá embaixo.
	cor_nova *= 1.0 + mancha * 0.07 * k_mancha;

	// `cobertura` entra onde antes havia um smoothstep de borda. A diferença
	// é tudo: "meio pintado" agora é falha de cobertura de verdade, que
	// sobrevive à secagem e só some quando a próxima demão passa por cima.
	ALBEDO = mix(base_anterior, cor_nova, cobertura);

	// ── Superfície ─────────────────────────────────────────────────
	// Molhado NÃO é espelho: roughness baixo demais reflete o céu procedural
	// e quebra a parede em blocos visíveis (já testado e revertido antes).
	float rug_pintada = mix(0.45, 0.9, seco_brilho);
	ROUGHNESS = mix(0.92, rug_pintada, cobertura);
	// O peso da mancha vai pro brilho, o dobro do que foi pra cor: é assim que
	// parede secando se parece de perto. Atenuado por `nitidez` pelo mesmo
	// motivo do lap mark — de longe o pixel cobre manchas demais pra resolver.
	ROUGHNESS += mancha * 0.14 * k_mancha * cobertura * nitidez;
	ROUGHNESS = clamp(ROUGHNESS, 0.05, 1.0);
	ROUGHNESS = mix(ROUGHNESS, ROUGHNESS * 0.93, lap);  // lap mark brilha um pouco mais
	METALLIC  = 0.0;                                     // tinta não é metal
	SPECULAR  = mix(0.3, mix(0.38, 0.3, seco_brilho), cobertura);
}
