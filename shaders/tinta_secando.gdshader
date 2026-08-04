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
// Cobertura congelada no fim da demão anterior (Fase G3). É o que transforma
// "meio pintado" em falha com HISTÓRIA: ela sobrevive à troca de demão e só
// some quando o rolo passa por cima.
uniform sampler2D mascara_historico : filter_linear, repeat_disable;

uniform vec4 cor_anterior : source_color = vec4(0.93, 0.92, 0.90, 1.0);  // a demão de baixo
// O reboco, embaixo de tudo. Antes da G3 o fundo era só `cor_anterior` chapada,
// então uma falha da 1ª demão sumia no frame em que a 2ª começava.
uniform vec4 cor_crua : source_color = vec4(0.93, 0.92, 0.90, 1.0);
// Molhada é MAIS CLARA que a seca: o ligante da látex é branco leitoso
// enquanto tem água e fica transparente ao secar (ver cor_tinta.gd).
uniform vec4 cor_molhada  : source_color = vec4(0.44, 0.57, 0.76, 1.0);
// Meio da travessia: cor cheia, ainda sem o aprofundamento final (Fase G2).
uniform vec4 cor_meio     : source_color = vec4(0.42, 0.56, 0.81, 1.0);
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
// Período do ripple do carimbo, em texels da máscara. Vem de
// `MascaraTinta.passo_carimbo_texels()`, não é escolhido aqui.
uniform float passo_carimbo_texels = 3.65;

uniform sampler2D mancha_secagem : filter_linear, repeat_disable;
uniform float mancha_escala = 0.6667;
uniform vec2  mancha_offset = vec2(0.0);

// Carga típica na máscara recente depois de uma passada. Medido: 0,511.
// É daqui que sai a espessura DESTA demão — não do acumulador. Ver fragment().
uniform float carga_tipica = 0.511;

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

// Quanto a queda de cobertura na borda de baixo vira bead. A cobertura cai de
// ~0,6 pra 0 ao longo da borda, e o gradiente é medido num passo de carimbo.
uniform float escala_bead = 3.0;

// Quanto a marca do rolo aparece. Cai a cada demão (ver iniciar_demao): a
// primeira camada sobre reboco cru mostra bastante variação, a última fecha
// lisa — que é como parede pintada de verdade se comporta.
//
// ⚠️ São DOIS valores, e isso não é redundância. `suavidade_anterior` é o
// quanto a marca aparece no que JÁ ESTÁ na parede; `suavidade_demao` é o quanto
// ela vai aparecer depois que ESTA demão cobrir. Com um valor só, o degrau
// entre as duas era aplicado na parede inteira no frame em que a demão trocava
// — e a parede alisava de uma vez, antes de o rolo encostar nela. Agora o
// degrau entra junto com `cobertura`, ou seja, atrás do rolo.
uniform float suavidade_anterior = 1.0;
uniform float suavidade_demao = 1.0;
uniform float forca_marca = 0.09;

// Faixa da carga gravada que conta como "coberto".
//
// ⚠️ `cobertura_min` tem que ser **zero ou positivo**, e isso não é estética.
// Carga zero PRECISA dar cobertura zero: com um mínimo negativo (que eu tentei,
// pra suavizar a falha), um ponto onde o rolo nunca passou já lia como 68%
// coberto — a cor nova aparecia na parede inteira no instante em que a demão
// começava, que é exatamente o que a G3 existe pra impedir. O salto médio da
// parede na troca pulou de 6 pra 16 de 255 e me entregou o erro.
//
// Com o mínimo preso em zero, quem controla o quanto a falha aparece é só o
// máximo: menor = satura antes = falha mais discreta. Percentis medidos de
// `rec_suave.g` no miolo das 4 paredes: pior 0,140 · p01 0,249 · p05 0,294 ·
// mediana 0,506 · p90 0,719.
//
// ⚠️ **A FALHA POR CARGA ESTÁ DESLIGADA (0,10 < 0,140) — reabrir na Fase E.**
//
// A tabela de SECAGEM §3.7 pede 42% de cobertura no fim de uma carga. Testado:
// fica horrível, e o problema não é a amplitude, é o TRAJETO. Uma carga dá 9 m
// e uma passada de altura inteira dá 3 m, então **uma carga dura 3 passadas**, e
// a recarga é instantânea no meio de uma delas. O resultado na tela é uma barra
// vertical de uma passada de largura com a **ponta quadrada** no ponto da
// recarga: lê como risco de estilete, não como rolo secando. Testei de 42% a
// 85% de cobertura mínima — o padrão não muda, só o contraste dele.
//
// O W, as verticais curtas e o banquinho da Fase E quebram a passada de altura
// inteira, e é lá que a falha vira mosqueado em vez de barra. Aí este par abre.
// (A mesma dependência que o plano já anota pro lap mark em §3.8.)
//
// Quem mexer aqui tem que mexer no mesmo par em `copia_cobertura.gdshader` —
// ou melhor, deixar `parede_pintavel.gd` passar os dois, que é o que ele faz.
uniform float cobertura_min = 0.0;
uniform float cobertura_max = 0.10;

varying vec3 pos_mundo;


void vertex() {
	pos_mundo = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}


// Máscara recente sem o carimbo.
//
// As máscaras são escritas a cada meia faixa do rolo. Na recente isso é
// blend_mix, e mix NÃO é partição da unidade (só o blend_add da acumulada é,
// que é o motivo do perfil triangular do carimbo). Sobra um ripple no período
// do carimbo nos dois canais: R (instante) anda um degrau por carimbo, G
// (carga) ondula.
//
// Box filtro de largura EXATAMENTE igual ao período tem um zero nessa
// frequência. Três taps espaçados de passo/3 dão largura total = passo.
vec2 rec_liso(vec2 uv, vec2 passo) {
	vec2 s = vec2(0.0);
	for (int i = -1; i <= 1; i++) {
		for (int j = -1; j <= 1; j++) {
			s += texture(mascara_recente, uv + vec2(float(i), float(j)) * passo).rg;
		}
	}
	return s / 9.0;
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

	vec2 tam_mascara = vec2(textureSize(mascara_recente, 0));
	vec2 texel = 1.0 / tam_mascara;

	// ── Tirar o carimbo do rolo de cima da parede ──────────────────
	// Preserva o que interessa: a carga cai ao longo de cada passada e o
	// instante anda de uma passada pra outra, e as duas variam na escala de
	// 20 cm, não de 2 mm. Ver rec_liso().
	vec2 passo = texel * (passo_carimbo_texels / 3.0);
	vec2 rec_suave = rec_liso(uv, passo);

	// A acumulada é blend_add com carimbo triangular, que É partição da unidade
	// — mas só aproximadamente, porque `carimbar_traco` arredonda o número de
	// passos pra cima. Sobra um resto, e o mesmo box resolve.
	float relevo = 0.0;
	// E um borrão bem mais largo do relevo, que serve de média local dele — é o
	// que faz a marca do rolo virar passa-alta (ver `marca_base` lá embaixo).
	//
	// ⚠️ A largura NÃO é livre. O sinal que a marca quer mostrar é a passada do
	// rolo, cujo período é 0,167 m × 146 px/m = **24,3 texels**. O borrão largo
	// tem que ser bem MAIOR que isso, senão ele acompanha o próprio sinal e o
	// passa-alta subtrai o que deveria preservar. Estava em 7 (17 texels, MENOR
	// que o período) e cancelava metade da marca: RMS medida 0,0083 contra
	// 0,0181 em 30. De 30 pra cima o ganho para e o viés de borda começa.
	float relevo_largo = 0.0;
	for (int i = -1; i <= 1; i++) {
		for (int j = -1; j <= 1; j++) {
			vec2 desloc = vec2(float(i), float(j));
			relevo       += texture(mascara_acumulada, uv + desloc * passo).g;
			relevo_largo += texture(mascara_acumulada, uv + desloc * passo * 30.0).g;
		}
	}
	relevo /= 9.0;
	relevo_largo /= 9.0;

	// ── Cobertura, e ela tem história (Fase G3) ────────────────────
	//
	// A desta demão sai da máscara recente, que é limpa a cada demão. A das
	// anteriores já vem PRONTA no histórico: `copia_cobertura.gdshader` grava lá
	// este mesmo número no fim de cada demão, em vez de uma máscara crua.
	//
	// Assim a costura fecha por construção — no instante em que a demão troca, a
	// cobertura nova zera e o fundo vira exatamente o que estava na tela. Medido:
	// o salto médio da parede na troca é 1,0 de 255 (era 8,9, com pico de 130).
	float cobertura    = smoothstep(cobertura_min, cobertura_max, rec_suave.g);
	float cob_anterior = min(texture(mascara_historico, uv).r, 1.0);

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

	// ── As fases da secagem, cada uma com sua curva (Fase G2) ──────
	// O detalhe que quase ninguém acerta: o BRILHO some antes de a COR mudar.
	// Tinta látex perde o brilho de molhada no "flash off", bem antes de
	// clarear. E a cor não muda de uma vez: primeiro o ligante branco leitoso
	// fica transparente e a cor SATURA, depois o filme consolida e o valor CAI.
	// Quatro grandezas, quatro curvas — não dois crossfades dividindo o
	// trabalho de quatro coisas diferentes.
	//
	// ⚠️ As faixas são mais estreitas que as de SECAGEM §3.2 (0,05–0,55 e
	// 0,38–0,95). Com as largas, no meio da secagem as DUAS curvas estavam em
	// região plana ao mesmo tempo — pouca inclinação, e a mancha da G1 perdia
	// metade do contraste (pico medido caiu de 2,61 pra 1,44). A inclinação no
	// meio é o que converte variação de `fracao` em variação de cor, que é como
	// a mancha aparece. `k_valor` fechar em 0,85 e não 0,95 também encurta a
	// cauda: o fim da curva é plano e só adiava a conclusão.
	// FIM_DA_COR em parede_pintavel.gd espelha o 0,85 e os dois PRECISAM bater.
	float k_brilho = smoothstep(0.02, 0.28, fracao);
	float k_sat    = smoothstep(0.05, 0.48, fracao);
	float k_valor  = smoothstep(0.34, 0.85, fracao);

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
	//
	// ⚠️ Tem que ser derivada do campo LISO, e num passo de um período de
	// carimbo. A versão texel a texel sobre a máscara crua media a coisa errada:
	// `instante` anda um degrau a cada carimbo, então o lap disparava em TODO
	// carimbo e desenhava um tracinho horizontal — a parede inteira ficava com
	// cara de tecido. Isso ficava escondido enquanto o resto do shader não
	// dependia de `instante`; a G1 destapou.
	//
	// Um lap de verdade é um degrau de segundos entre duas PASSADAS vizinhas,
	// que é o que sobrevive a um passo desse tamanho. O degrau de quantização
	// entre dois carimbos da mesma passada não sobrevive, que é o ponto.
	vec2 passo_lap = texel * passo_carimbo_texels;
	vec2 vizinho_x = rec_liso(uv + vec2(passo_lap.x, 0.0), passo);
	vec2 vizinho_y = rec_liso(uv + vec2(0.0, passo_lap.y), passo);
	float r_dx = vizinho_x.r - rec_suave.r;
	float r_dy = vizinho_y.r - rec_suave.r;
	float salto = length(vec2(r_dx, r_dy)) * janela_demao;
	// A diferença finita acima é derivada de textura por pixel multiplicando um
	// smoothstep estreito — gerador clássico de aliasing. `nitidez` desliga ela
	// justamente onde ela não teria como estar certa.
	float lap = smoothstep(limiar_lap, limiar_lap * 2.0, salto) * cobertura * nitidez;

	// ── Bead da borda viva (Fase G2) ───────────────────────────────
	// Tinta recém-passada escorre e engrossa na parte de baixo da borda
	// molhada. É um detalhe de dois centímetros que dura três segundos, e é o
	// que faz a pintura parecer líquida em vez de decalque.
	//
	// Sai do gradiente vertical da COBERTURA, não do instante como o plano
	// sugeria: o gradiente do instante traz de volta o pente do carimbo que o
	// lap acabou de perder. E é mais fiel — o bead é gravidade agindo na borda
	// do filme, que é uma borda de tinta, não uma borda de "quando foi pintado".
	//
	// `v` cresce PRA BAIXO (ver parede_pintavel.gd::configurar), então a borda
	// de baixo é onde a cobertura cai indo pra +v: gradiente negativo.
	float bead = clamp(-(vizinho_y.g - rec_suave.g) * escala_bead, 0.0, 1.0)
		* (1.0 - smoothstep(0.0, 0.06, fracao))   // só enquanto está molhada
		* nitidez;

	// ── Cor ────────────────────────────────────────────────────────
	// Látex seca MAIS ESCURO que molhado: o véu leitoso do ligante some e
	// sobra o pigmento. Quem monta as três cores é cor_tinta.gd.
	//
	// DOIS mixes, não um. Um `mix` só de molhada pra seca é uma reta no espaço
	// RGB, e essa reta passa perto do cinza — lê como fade de vídeo. Saturar
	// primeiro e aprofundar depois põe um cotovelo no caminho, que é o que
	// parede de verdade faz.
	vec3 cor_nova = mix(cor_molhada.rgb, cor_meio.rgb, k_sat);
	cor_nova      = mix(cor_nova,        cor_seca.rgb, k_valor);

	// A lap mark é uma faixa levemente mais densa/escura de tinta
	cor_nova = mix(cor_nova, cor_nova * 0.94, lap);

	// A marca do rolo modula as DUAS cores, não só a nova. É o que impede a
	// parede de virar cor chapada no instante em que uma demão começa: a
	// camada de baixo continua exibindo o relevo que ela deixou.
	// `relevo` só aparece depois de secar — tinta molhada escorre e nivela.
	//
	// Aqui SIM é a acumulada: a marca é o relevo que ficou, de todas as demãos.
	//
	// E é um PASSA-ALTA — relevo menos a média local dele — não uma diferença
	// contra um centro guardado. Dois centros já deram errado aqui: `relevo -
	// 0.5` (chumbado, só batia porque `preencher_coberta` grava 0,5) e
	// `relevo - relevo_base` (medido, mas `relevo_base` é remedido a cada demão,
	// então o termo saltava de +0,5 pra -0,5 na troca e a parede inteira dava um
	// pulo de ~15 de 255 no instante em que a demão trocava).
	//
	// O passa-alta não tem centro pra errar: os dois lados vêm da mesma textura
	// no mesmo instante, então ele é contínuo por construção. E é o que a marca
	// do rolo é de verdade — variação local de espessura, não desvio de uma
	// média histórica.
	//
	// E a atenuação por demão é aplicada DEPOIS de separar as duas camadas: o
	// relevo é o mesmo (é a mesma parede), o que muda é quanto dele cada lado do
	// `mix` deixa ver. Demão nova não alisa o que ela ainda não cobriu.
	float relevo_rel = (relevo - relevo_largo) / max(espessura_demao, 1e-4);
	float marca_base = relevo_rel * forca_marca * nitidez;
	float marca_anterior = marca_base * suavidade_anterior;
	float marca_nova     = marca_base * suavidade_demao;

	// Onde a demão anterior falhou, o reboco continua aparecendo — e continua
	// aparecendo DURANTE esta demão, até o rolo passar por cima daquele ponto.
	// É isso que faz três demãos serem três acontecimentos, em vez de três
	// trocas de valor de saturação.
	vec3 base_anterior = mix(cor_crua.rgb, cor_anterior.rgb, cob_anterior)
		* (1.0 - marca_anterior);
	cor_nova *= (1.0 - marca_nova * k_valor);

	// Manchado de tinta secando é mais diferença de BRILHO que de cor — por
	// isso aqui a cor leva metade do peso que a rugosidade leva lá embaixo.
	cor_nova *= 1.0 + mancha * 0.07 * k_mancha;

	// O acúmulo do bead é mais denso, então mais escuro
	cor_nova *= 1.0 - bead * 0.06;

	// `cobertura` entra onde antes havia um smoothstep de borda. A diferença
	// é tudo: "meio pintado" agora é falha de cobertura de verdade, que
	// sobrevive à secagem e só some quando a próxima demão passa por cima.
	ALBEDO = mix(base_anterior, cor_nova, cobertura);

	// ── Superfície — o brilho é a informação (Fase G2) ─────────────
	//
	// Esta é a escala de segundos do jogo, e a única forma de agência que ele
	// pode ter: o jogador move a cabeça e descobre coisa. Pintor de verdade
	// confere a borda molhada exatamente assim, olhando a parede de raspão.
	//
	// ⚠️ Risco conhecido e JÁ REVERTIDO uma vez: roughness baixo demais faz a
	// parede refletir o céu procedural e quebrar em blocos visíveis (está no
	// PROJETO.md 3.6). Por isso o piso é 0.36 e não menos, e o ganho de molhado
	// vai no SPECULAR modulado pelo ângulo rasante — de frente a parede
	// continua fosca, e o brilho só aparece quando a câmera olha ao longo dela.
	// Mesmo efeito, sem o risco.
	//
	// NORMAL e VIEW estão os dois em espaço de visão no fragment() do Godot 4,
	// e VIEW aponta do fragmento pra câmera. Então dot = 1 é de frente e 0 é de
	// raspão; a potência 4 concentra o ganho nos ângulos bem rasantes.
	float rasante = pow(1.0 - clamp(dot(normalize(NORMAL), normalize(VIEW)), 0.0, 1.0), 4.0);
	float molhado = 1.0 - k_brilho;

	float rug_pintada = mix(0.36, 0.90, k_brilho);
	ROUGHNESS = mix(0.92, rug_pintada, cobertura);
	// O peso da mancha vai pro brilho, o dobro do que foi pra cor: é assim que
	// parede secando se parece de perto. Atenuado por `nitidez` pelo mesmo
	// motivo do lap mark — de longe o pixel cobre manchas demais pra resolver.
	ROUGHNESS += mancha * 0.14 * k_mancha * cobertura * nitidez;
	ROUGHNESS -= bead * 0.10;                            // o bead é mais liso
	ROUGHNESS = clamp(ROUGHNESS, 0.30, 1.0);             // piso duro, ver acima
	ROUGHNESS = mix(ROUGHNESS, ROUGHNESS * 0.93, lap);   // lap mark brilha um pouco mais
	METALLIC  = 0.0;                                     // tinta não é metal
	SPECULAR  = mix(0.30, 0.30 + 0.32 * molhado * (0.35 + 0.65 * rasante), cobertura);
}
