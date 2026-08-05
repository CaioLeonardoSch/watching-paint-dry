extends Personagem
class_name Tio

# ─────────────────────────────────────────────
#  TIO — personagem que pinta a parede
#
#  Modelo rigado no Blender (res://models/tio_modelo.tscn, 19 ossos + IK — ver
#  PLANO-OVERHAUL-TINTA.md §5). Locomoção (virar antes de andar, atravessar a
#  porta) mora em `personagem.gd`; aqui fica só o que é do tio.
#
#  Dois `AnimationPlayer` no modelo, um pras pernas e um pro braço, porque
#  `pintar_varrendo()` toca os dois ao mesmo tempo.
# ─────────────────────────────────────────────

signal pintura_concluida
signal pincelada  ## emitido a cada passada de braço — som conecta nisso

const DURACAO_PINCELADA: float = 1.1666667  ## duração real do clipe pintar_braco

## ⚠️ `andar` e `pintar_braco` **compartilham osso**, e por isso existe
## `andar_pintando`.
##
## O `PROJETO.md` diz que os dois clipes não têm osso em comum — era verdade no
## rig de 7 ossos, onde o braço era um osso só e a caminhada não o tocava. No rig
## de 19 a caminhada balança os braços (`Ombro_D`, `Braco_D`, `Ombro_E`,
## `Braco_E`) e `pintar_braco` comanda `Ombro_D`, `Braco_D`, `Antebraco_D` e
## `Ombro_E`. Dois `AnimationPlayer` escrevendo no mesmo osso não misturam: quem
## processa por último ganha, e o resultado depende da ordem dos nós.
##
## A saída é uma variante de `andar` **sem nenhuma pista de braço**, montada em
## runtime. Assim os papéis ficam separados por construção: as pernas andam, o
## braço pinta, e ninguém disputa osso.
const OSSOS_DO_BRACO: PackedStringArray = [
	"Ombro_D", "Braco_D", "Antebraco_D", "Mao_D",
	"Ombro_E", "Braco_E", "Antebraco_E", "Mao_E",
]

const CLIPE_ANDAR_PINTANDO: String = "andar_pintando"
const CLIPE_PARADO_PINTANDO: String = "parado_pintando"

## Clipes que precisam de uma versão sem braço, e o nome que ela recebe.
##
## ⚠️ `parado_respirando` entrou na lista na Fase E, pelo mesmo motivo do
## `andar`: **o clipe de idle também mexe no braço**, e enquanto ele toca a IK
## do rolo não aparece na tela — o tio fica com o braço pendurado ao lado do
## corpo enquanto o rolo pinta sozinho lá em cima. Medido: com o clipe parado, o
## alvo da IK muda 35.876 pixels de silhueta; com ele tocando, nada.
const CLIPES_SEM_BRACO: Dictionary = {
	"andar": CLIPE_ANDAR_PINTANDO,
	"parado_respirando": CLIPE_PARADO_PINTANDO,
}

# ── Fase E: o corpo seguindo o trajeto do rolo ───────────────────────────

## Do centro do corpo até a face da parede quando ele está pintando.
const DISTANCIA_PAREDE: float = 0.66

## Ganho de altura ao subir no banquinho. **Tem que bater com
## `PropsPintura.ALTURA_BANQUINHO`**, senão ele flutua ou enterra o pé.
const ALTURA_BANQUINHO: float = 0.30

## Altura do punho, em repouso de trabalho. O cabo do rolo faz o resto do
## alcance — é por isso que ele pinta 3 m de parede sem escada.
const ALTURA_MAO: float = 1.18

## Quanto o corpo anda por segundo enquanto trabalha. Ele planta o pé uma vez
## por trecho, então isto é o passo lateral entre trechos, não caminhada.
const VELOCIDADE_LATERAL: float = 1.0

## Quão rápido ele sobe/desce do banquinho, em metros por segundo.
const VELOCIDADE_VERTICAL: float = 0.55

@onready var _anim_pernas: AnimationPlayer = $Modelo/AnimationPlayerPernas
@onready var _anim_braco: AnimationPlayer  = $Modelo/AnimationPlayerBraco

var _rolo: RoloPintura
var _ik_braco: TwoBoneIK3D
var _alvo_mao: Node3D

var _trajeto: TrajetoRolo
var _parede_atual: ParedePintavel
var _props: PropsPintura

## Medidos do rest do esqueleto em `_medir_braco`, não chutados.
var _alcance_braco: float = 0.55
var _altura_ombro: float = 1.45


func _ready() -> void:
	super()  # sem isto a camada procedural e as IK das pernas não são achadas
	_montar_clipes_sem_braco()
	_ligar_ferramentas()
	parar_locomocao()
	set_process(false)


## Acha a IK do braço e o alvo dela, e monta o rolo. Mesmo motivo de
## `personagem.gd::ligar_rig` usar `find_child`: o nome da armadura muda por
## modelo, e `%NomeUnico` já resolveu pra `null` neste projeto.
func _ligar_ferramentas() -> void:
	var modelo: Node = get_node_or_null("Modelo")
	if modelo != null:
		_ik_braco = modelo.find_child("IKBracoDireito", true, false) as TwoBoneIK3D
		_alvo_mao = modelo.find_child("AlvoMaoDireita", true, false) as Node3D

	_medir_braco()

	_rolo = RoloPintura.new()
	_rolo.name = "Rolo"
	# filho do QUARTO, não do tio: ele é posicionado em mundo pelo trajeto, e
	# pendurá-lo no corpo faria a posição dele depender da rotação do tio
	add_child(_rolo)
	_rolo.top_level = true
	_rolo.hide()


func definir_props(props: PropsPintura) -> void:
	_props = props


## Alcance do braço e altura do ombro, tirados do REST do esqueleto.
##
## Ler rest é legítimo — ele é dado do rig, não saída de modifier (que o
## Skeleton3D restaura e por isso não dá pra ler de volta, ver PROJETO.md §3.3).
## Sem este número o alvo da mão ia parar fora do alcance e a IK parava onde
## dava, deixando o rolo boiando a 40 cm da mão.
func _medir_braco() -> void:
	var modelo: Node = get_node_or_null("Modelo")
	if modelo == null:
		return
	var esqueleto := modelo.find_child("Skeleton3D", true, false) as Skeleton3D
	if esqueleto == null:
		return

	var i_ombro: int = esqueleto.find_bone("Ombro_D")
	var i_antebraco: int = esqueleto.find_bone("Antebraco_D")
	var i_mao: int = esqueleto.find_bone("Mao_D")
	if i_ombro < 0 or i_antebraco < 0 or i_mao < 0:
		return

	# comprimento do braço = distância que o cotovelo e o punho ficam do pai
	_alcance_braco = (esqueleto.get_bone_rest(i_antebraco).origin.length()
		+ esqueleto.get_bone_rest(i_mao).origin.length())
	_altura_ombro = esqueleto.get_bone_global_rest(i_ombro).origin.y


## Clona cada clipe de CLIPES_SEM_BRACO sem as pistas de braço.
##
## Os dois `AnimationPlayer` compartilham a MESMA `AnimationLibrary`, então
## acrescentar aqui vale pros dois — e por isso o clipe original é duplicado em
## vez de editado no lugar.
func _montar_clipes_sem_braco() -> void:
	var lib: AnimationLibrary = _anim_pernas.get_animation_library("")
	if lib == null:
		push_warning("Tio: biblioteca de animação não encontrada — o rig mudou?")
		return

	for original in CLIPES_SEM_BRACO:
		var nome_origem: String = original
		var nome_novo: String = CLIPES_SEM_BRACO[nome_origem]
		if not lib.has_animation(nome_origem):
			push_warning("Tio: clipe '%s' não encontrado — o rig mudou?" % nome_origem)
			continue
		if lib.has_animation(nome_novo):
			continue

		var clipe: Animation = lib.get_animation(nome_origem).duplicate(true)
		# de trás pra frente: remover pista renumera as seguintes
		for i in range(clipe.get_track_count() - 1, -1, -1):
			var caminho: NodePath = clipe.track_get_path(i)
			if caminho.get_subname_count() == 0:
				continue
			if OSSOS_DO_BRACO.has(String(caminho.get_subname(0))):
				clipe.remove_track(i)
		lib.add_animation(nome_novo, clipe)


func tocar_locomocao() -> void:
	_anim_pernas.play("andar")


## Parado ele respira. O clipe existia desde a Fase D e **nunca era tocado** —
## a alternativa era `stop()`, que deixa o corpo congelado. Respiração é o que
## separa personagem de estátua com script (OVERHAUL §5.3).
##
## Pintando, toca a variante sem braço: aí quem manda no braço é a IK do rolo, e
## a respiração completa apagaria ela.
func parar_locomocao() -> void:
	_anim_pernas.play(_clipe_parado())


func _clipe_parado() -> String:
	return CLIPE_PARADO_PINTANDO if _trajeto != null else "parado_respirando"


## O som segue a passada de verdade, não um timer. Ver TrajetoRolo::passada.
func _ao_passada() -> void:
	pincelada.emit()


## Vira pra encarar a parede e espera terminar.
##
## Separado de `pintar_varrendo` de propósito: quem chama dispara o trajeto do
## rolo ANTES de esperar a caminhada, então um giro dentro de `pintar_varrendo`
## deixaria o rolo andando meio segundo com o tio parado. Ver ciclo_pintura.gd.
func encarar_parede(angulo_y_graus: float) -> void:
	await girar_para(deg_to_rad(angulo_y_graus))


## Onde ele fica de pé pra trabalhar um ponto do trajeto. Serve pra posicionar
## antes de mostrar (a abertura pega ele no meio do serviço).
func posto_de_trabalho(trajeto: TrajetoRolo, parede: ParedePintavel, fracao: float) -> Vector3:
	var largura: float = maxf(parede.mascara.largura_m, 0.1)
	var u_m: float = clampf(fracao, 0.0, 1.0) * largura
	return _pe_no_trecho(parede, trajeto.centro_trecho(u_m) / largura, 0.0)


## Pinta seguindo o trajeto do rolo até ele terminar a parede.
##
## É o coração da Fase E. O corpo não tem coreografia própria: posição, altura e
## postura são **lidas do rolo** a cada quadro. Antes eram duas animações com a
## mesma duração torcendo pra continuarem juntas; qualquer diferença de ritmo
## descolava o braço da tinta, e não havia como notar sem pausar o jogo.
func acompanhar_trajeto(trajeto: TrajetoRolo, parede: ParedePintavel, angulo_y: float) -> void:
	await encarar_parede(angulo_y)

	_trajeto = trajeto
	_parede_atual = parede
	# o braço agora é IK atrás do rolo, não clipe — os dois no mesmo osso e
	# quem processa por último ganharia
	_anim_braco.stop(true)
	_anim_pernas.play(CLIPE_PARADO_PINTANDO)
	if _ik_braco != null:
		_ik_braco.active = true
	_rolo.show()

	if not trajeto.foi_molhar.is_connected(_ao_molhar):
		trajeto.foi_molhar.connect(_ao_molhar)
	if not trajeto.passada.is_connected(_ao_passada):
		trajeto.passada.connect(_ao_passada)
	set_process(true)
	await trajeto.terminou
	set_process(false)
	trajeto.foi_molhar.disconnect(_ao_molhar)
	trajeto.passada.disconnect(_ao_passada)

	if _ik_braco != null:
		_ik_braco.active = false
	_rolo.hide()
	definir_agachamento(0.0)
	definir_inclinacao_torso(0.0)
	position.y = 0.0
	_trajeto = null
	_parede_atual = null
	parar_locomocao()
	pintura_concluida.emit()


func _process(delta: float) -> void:
	if _trajeto == null or _parede_atual == null:
		return
	_seguir_rolo(delta)


## Um quadro de "estar pintando": onde o corpo vai, que postura faz, e onde o
## rolo e a mão ficam.
func _seguir_rolo(delta: float) -> void:
	# Indo molhar quem manda no corpo é o Tween de `_ao_molhar` — dois donos
	# escrevendo `position` no mesmo quadro brigam, e o resultado é o do último.
	if _trajeto.na_bandeja:
		_molhando_o_rolo()
		return

	var largura: float = maxf(_parede_atual.mascara.largura_m, 0.1)
	var altura: float = maxf(_parede_atual.mascara.altura_m, 0.1)
	var ponto_m: Vector2 = _trajeto.posicao_metros()
	var normal: Vector3 = _parede_atual.normal_interna()

	# ── corpo: um posto por trecho, e altura conforme o banquinho ──
	var no_banquinho: bool = ponto_m.y < TrajetoRolo.ALCANCE_TOPO
	var u_posto: float = _trajeto.centro_trecho(ponto_m.x) / largura
	var alvo_pe: Vector3 = _pe_no_trecho(_parede_atual, u_posto,
		ALTURA_BANQUINHO if no_banquinho else 0.0)

	var plano_agora := Vector3(position.x, 0.0, position.z)
	var plano_alvo := Vector3(alvo_pe.x, 0.0, alvo_pe.z)
	var andando: bool = plano_agora.distance_to(plano_alvo) > 0.02
	plano_agora = plano_agora.move_toward(plano_alvo, VELOCIDADE_LATERAL * delta)
	position.x = plano_agora.x
	position.z = plano_agora.z
	position.y = move_toward(position.y, alvo_pe.y, VELOCIDADE_VERTICAL * delta)

	if andando:
		_anim_pernas.play(CLIPE_ANDAR_PINTANDO)
	elif _anim_pernas.current_animation != CLIPE_PARADO_PINTANDO:
		_anim_pernas.play(CLIPE_PARADO_PINTANDO)

	# banquinho embaixo do pé, não do outro lado da parede
	if _props != null and no_banquinho:
		_props.mover_banquinho(Vector3(alvo_pe.x, 0.0, alvo_pe.z))

	# ── postura: agacha no rodapé, inclina o torso acompanhando o braço ──
	var agacha: float = 0.0
	if ponto_m.y > TrajetoRolo.ALCANCE_RODAPE:
		agacha = smoothstep(TrajetoRolo.ALCANCE_RODAPE, altura, ponto_m.y)
	definir_agachamento(agacha)
	definir_inclinacao_torso(agacha * 14.0)

	# ── rolo e mão: o rolo vai onde o trajeto disse, a mão vai atrás dele ──
	var uv: Vector2 = _trajeto.posicao_atual
	var ponto_parede: Vector3 = _parede_atual.ponto_mundo(uv)
	var d2: Vector2 = _trajeto.direcao_atual
	var direcao: Vector3 = (_parede_atual.eixo_u.normalized() * d2.x
		+ _parede_atual.eixo_v.normalized() * d2.y)
	# viajando entre blocos ele tira o rolo da parede — é o mesmo afastamento
	# que faz a máscara não ganhar risca de viagem (ver TrajetoRolo::no_ar)
	if _trajeto.no_ar:
		ponto_parede += normal * 0.10

	# A mão vai o mais perto do rolo que o braço permitir, e o cabo estica o
	# resto. Sem o limite de alcance, o alvo caía fora e a IK parava no meio do
	# caminho — o rolo ficava boiando longe da mão.
	var ombro: Vector3 = global_position + Vector3.UP * (_altura_ombro - agacha * 0.30)
	var desejada: Vector3 = ponto_parede + normal * 0.20 - Vector3.UP * 0.10
	var do_ombro: Vector3 = desejada - ombro
	var mao_alvo: Vector3 = ombro + do_ombro.limit_length(_alcance_braco * 0.95)

	var mao: Vector3 = _rolo.encostar(ponto_parede, normal, direcao, mao_alvo)
	if _alvo_mao != null:
		_alvo_mao.global_position = mao


## Ponto do chão em frente à parede, no trecho `u_frac`, já afastado o quanto o
## corpo precisa. `altura` é o que o banquinho acrescenta.
func _pe_no_trecho(parede: ParedePintavel, u_frac: float, altura: float) -> Vector3:
	var base: Vector3 = parede.ponto_mundo(Vector2(u_frac, 1.0))
	base += parede.normal_interna() * DISTANCIA_PAREDE
	base.y = altura
	return base


## A cor da tinta que está sendo passada — rolo e bandeja acompanham, senão ele
## molha em azul e passa vermelho na parede.
func definir_cor_tinta(cor: Color) -> void:
	if _rolo != null:
		_rolo.definir_cor(cor)


## Enquanto ele vai à bandeja o rolo desce pra frente do corpo, na altura da
## mão — em vez de ficar plantado no último ponto da parede.
func _molhando_o_rolo() -> void:
	var frente: Vector3 = -global_transform.basis.z
	var ponto: Vector3 = global_position + frente * 0.30 + Vector3.UP * 0.55
	var mao: Vector3 = _rolo.encostar(ponto, Vector3.UP, frente,
		global_position + Vector3.UP * ALTURA_MAO + frente * 0.18)
	if _alvo_mao != null:
		_alvo_mao.global_position = mao


## Ele sai da parede e vai molhar o rolo. A pausa quem conta é o trajeto; aqui
## é só o corpo indo até a bandeja e voltando dentro dessa janela.
func _ao_molhar() -> void:
	if _props == null or _trajeto == null:
		return
	var volta: Vector3 = position
	var ida: Vector3 = _props.ponto_de_molhar()
	ida.y = 0.0
	var meio: float = TrajetoRolo.DURACAO_BANDEJA * 0.5

	pincelada.emit()
	definir_agachamento(0.0)
	definir_inclinacao_torso(0.0)
	_anim_pernas.play(CLIPE_ANDAR_PINTANDO)
	var tw := create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tw.tween_property(self, "position", ida, meio * 0.8)
	tw.tween_interval(meio * 0.4)
	tw.tween_property(self, "position", volta, meio * 0.8)
