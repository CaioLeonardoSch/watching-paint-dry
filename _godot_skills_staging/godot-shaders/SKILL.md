---
name: godot-shaders
description: Shaders spatial em Godot 4 (.gdshader) — ruído procedural, fbm, hash noise, projeção triplanar, uniforms com hint_range/source_color, ALBEDO/ROUGHNESS/METALLIC no fragment(). Use quando a dúvida envolver materiais, shaders, texturização procedural, ou StandardMaterial3D vs ShaderMaterial.
---

# Shaders em Godot 4 (spatial)

## Estado atual deste projeto

Dois shaders existem hoje, ambos `shader_type spatial`, ambos procedurais (sem textura externa):

- `shaders/tinta_secando.gdshader` — parede secando em manchas
- `shaders/assoalho.gdshader` — tábuas de madeira com veio e junta

Além disso, paredes/teto usam `StandardMaterial3D` com `detail_albedo` + ruído em vez de shader
customizado (ver `scripts/inicializar_quarto.gd::_criar_material_texturizado`) — para variação
simples de tom, `StandardMaterial3D` com textura de ruído triplanar já resolve sem precisar
escrever `.gdshader`. Só escreva shader customizado quando a lógica não cabe nos parâmetros
prontos do material padrão (é o caso da tinta, que precisa de lógica de mistura por fração/tempo).

## Ruído procedural feito à mão (hash + noise + fbm)

Os shaders deste projeto não usam textura de ruído (`NoiseTexture2D`) — geram ruído direto no
shader com hash determinístico, porque é mais barato e não depende de import de recurso:

```glsl
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
	vec2 u = f * f * (3.0 - 2.0 * f);  // smoothstep de interpolação
	return mix(a, b, u.x) + (c - a) * u.y * (1.0 - u.x) + (d - b) * u.x * u.y;
}

float fbm(vec2 p) {
	float valor = 0.0;
	float amplitude = 0.5;
	for (int i = 0; i < 3; i++) {
		valor += amplitude * noise(p);
		p *= 2.0;
		amplitude *= 0.5;
	}
	return valor;
}
```

`fbm` (fractal brownian motion) soma várias oitavas de `noise` em frequências crescentes e
amplitudes decrescentes — é o que dá aspecto de "mancha orgânica" em vez de padrão repetitivo.
3 oitavas é suficiente para escala de parede; mais que isso é custo extra sem ganho visual
perceptível a essa distância de câmera.

**Padrão "campo de instantes"** usado em `tinta_secando.gdshader` para animar algo que se espalha
de forma não-uniforme: cada texel recebe um valor de ruído fixo (`mancha`, calculado uma vez a
partir de UV) que funciona como "o instante em que esse ponto specific muda de estado". Um
parâmetro global de progresso (`fracao_seca`, atualizado por script) é comparado contra esse campo
com `smoothstep`:

```glsl
float mancha     = fbm(UV * 6.0);
float local_seco = smoothstep(mancha - 0.12, mancha + 0.12, fracao_seca);
```

Isso é reutilizável para qualquer efeito de "frente de propagação irregular" — queimando,
enferrujando, crescendo, derretendo — sem precisar de simulação real, só um campo de ruído estático
e um scalar de progresso.

## Projeção triplanar (para evitar esticar textura em BoxMesh)

`BoxMesh` não tem UV contínuo entre as 6 faces — textura aplicada via UV normal estica ou repete
de forma inconsistente entre elas. Duas soluções usadas neste projeto:

1. **Via `StandardMaterial3D`**, sem escrever shader: `mat.uv1_triplanar = true` +
   `mat.uv1_scale = Vector3(...)`. É a projeção da própria textura no espaço do mundo (usa a
   normal de cada face pra escolher entre projeção XY/XZ/YZ). Cobre a maioria dos casos.
2. **Via shader customizado com `UV` por struct de tábua** (caso do assoalho): quando o padrão não
   é "textura genérica" mas algo estruturado (tábuas em faixas), é mais simples projetar
   manualmente no `fragment()` a partir de `UV.y` / `UV.x` do que tentar forçar triplanar a
   respeitar uma estrutura de tábuas.

Regra prática: se o padrão é ruído/textura solta → `uv1_triplanar` no material padrão. Se o
padrão tem estrutura própria (tábuas, tijolos, uma direção "certa") → shader customizado com UV
manual.

## Uniforms — convenções

```glsl
uniform float fracao_seca : hint_range(0.0, 1.0) = 0.0;
uniform vec4  cor_molhada : source_color = vec4(0.18, 0.38, 0.72, 1.0);
```

- `hint_range(min, max)` em floats que representam fração/progresso — aparece como slider no
  Inspector e documenta o intervalo válido pra quem for mexer depois.
- `source_color` em qualquer `vec4`/`vec3` que representa cor — sem isso o Inspector mostra os
  componentes como números crus em vez de color picker, e a cor não passa por correção de
  espaço de cor corretamente.
- Setar uniforms do lado do script: `material.set_shader_parameter("nome", valor)` — nome deve
  bater exatamente com o do shader (case-sensitive).

## `fragment()` — saídas principais para material PBR simples

```glsl
ALBEDO    = cor.rgb;              // cor base
ROUGHNESS = valor_0_a_1;          // 0 = espelhado, 1 = totalmente fosco
METALLIC  = valor_0_a_1;          // 0 = dielétrico (madeira, tinta, pele), 1 = metal puro
```

Neste projeto, `ROUGHNESS` e `METALLIC` também variam por máscara (não são constantes) — molhado
é mais brilhoso (`roughness` baixo, leve `metallic`), seco é fosco. Reaproveitável: qualquer
material que muda de estado físico (molhado/seco, limpo/sujo, novo/desgastado) deveria variar
roughness/metallic junto com albedo, não só a cor — é o que vende "material" e não só "cor
diferente".

## Erros comuns

- Esquecer `shader_type spatial;` na primeira linha (obrigatório, sem `;` no fim do arquivo isso
  quebra o parse).
- Usar `COLOR` em vez de `ALBEDO` num shader spatial (`COLOR` é de shaders `canvas_item`/2D).
- Aplicar `ShaderMaterial` num surface que ainda não tem mesh atribuído — o Godot não reclama na
  hora, mas o material simplesmente não aparece. Ver skill `godot-nodes` sobre `call_deferred`
  para esse cenário (mesh gerado em runtime).
- Ruído com frequência alta demais (`UV * 60.0` ou mais) sem levar em conta a escala real do
  triplanar/UV — testar sempre olhando a superfície de perto e de longe.
