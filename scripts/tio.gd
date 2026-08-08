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

## Medido no clipe dele (06/08/2026): o pé excursiona 0,429 m, e o ciclo dura
## 1,000 s. Ver `Personagem.metros_por_ciclo` pro raciocínio.
const METROS_POR_CICLO: float = 0.857

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
const ALTURA_BANQUINHO: float = 0.305

## Altura do punho, em repouso de trabalho. O cabo do rolo faz o resto do
## alcance — é por isso que ele pinta 3 m de parede sem escada.
const ALTURA_MAO: float = 1.18

## Quanto o corpo anda por segundo enquanto trabalha. Ele planta o pé uma vez
## por trecho, então isto é o passo lateral entre trechos, não caminhada.
const VELOCIDADE_LATERAL: float = 1.0

## Quão rápido ele sobe/desce do banquinho, em metros por segundo.
const VELOCIDADE_VERTICAL: float = 0.55

## Inclinação do torso, em graus, nos dois extremos de altura da parede.
##
## Antes o torso só se inclinava ao AGACHAR (`agacha * 14`), e o resto da parede
## era feito com o tronco na vertical — subir o rolo até 3 m e descer até o
## rodapé tinham exatamente o mesmo peso corporal: nenhum.
const INCLINACAO_NO_ALTO: float = -5.0
const INCLINACAO_NO_RODAPE: float = 14.0

## Quanto o torso ainda se inclina POR CAUSA DA PASSADA, além da altura. Subir o
## rolo é empurrar (corpo vai junto), descer é puxar (corpo volta) — e como isso
## troca de sinal a cada passada, é o que dá ritmo ao tronco.
const INCLINACAO_DA_PASSADA: float = 4.0

## Quão rápido torso e braço livre perseguem o alvo. A direção da passada vira
## ao contrário num único quadro no fim de cada traço; sem filtro o tronco daria
## um tranco a cada passada.
const SUAVIZACAO_POSTURA: float = 6.0

@onready var _anim_pernas: AnimationPlayer = $Modelo/AnimationPlayerPernas
@onready var _anim_braco: AnimationPlayer  = $Modelo/AnimationPlayerBraco

var _rolo: RoloPintura
var _ik_braco: TwoBoneIK3D
var _alvo_mao: Node3D
var _braco_livre: BracoLivreModifier

## Valores de postura já filtrados — ver SUAVIZACAO_POSTURA.
var _inclinacao_suave: float = 0.0
var _balanco_suave: float = 0.0
var _elevacao_suave: float = 0.0

## Pontos de partida dos gestos de parada, guardados quando a parada começa.
var _posto_de_molhar: Vector3 = Vector3.ZERO
var _pe_ao_mudar: Vector3 = Vector3.ZERO
var _banquinho_de: Vector3 = Vector3.ZERO
var _banquinho_para: Vector3 = Vector3.ZERO

## true enquanto ele atravessa o quarto com bandeja, lata e banquinho na mão.
var _carregando_mudanca: bool = false

var _trajeto: TrajetoRolo
var _parede_atual: ParedePintavel
var _props: PropsPintura

## Medidos do rest do esqueleto em `_medir_braco`, não chutados.
var _alcance_braco: float = 0.55
var _altura_ombro: float = 1.45


func _ready() -> void:
	super()  # sem isto a camada procedural e as IK das pernas não são achadas
	metros_por_ciclo = METROS_POR_CICLO
	_montar_clipes_sem_braco()
	_ligar_ferramentas()
	parar_locomocao()
	# ⚠️ `_process` fica LIGADO sempre: quem casa a cadência da perna com a
	# velocidade do corpo mora em `personagem.gd` e vale também quando ele só
	# está atravessando o quarto. Quem decide se há trajeto a seguir é o guarda
	# dentro de `_process`, não o `set_process`.


## Acha a IK do braço e o alvo dela, e monta o rolo. Mesmo motivo de
## `personagem.gd::ligar_rig` usar `find_child`: o nome da armadura muda por
## modelo, e `%NomeUnico` já resolveu pra `null` neste projeto.
func _ligar_ferramentas() -> void:
	var modelo: Node = get_node_or_null("Modelo")
	if modelo != null:
		_ik_braco = modelo.find_child("IKBracoDireito", true, false) as TwoBoneIK3D
		_alvo_mao = modelo.find_child("AlvoMaoDireita", true, false) as Node3D
		_montar_braco_livre(modelo)

	_medir_braco()

	_rolo = RoloPintura.new()
	_rolo.name = "Rolo"
	# filho do QUARTO, não do tio: ele é posicionado em mundo pelo trajeto, e
	# pendurá-lo no corpo faria a posição dele depender da rotação do tio
	add_child(_rolo)
	_rolo.top_level = true
	_rolo.hide()


## Pendura o modificador do braço esquerdo no esqueleto.
##
## Criado em código, e não no `.tscn`, porque o modelo é convertido do Blender:
## nó acrescentado à mão lá vira coisa a lembrar de repor a cada re-export. A
## posição na árvore não importa aqui — ordem de modifier só pesa entre nós que
## disputam osso, e este mexe no braço ESQUERDO, que nenhum outro toca.
func _montar_braco_livre(modelo: Node) -> void:
	var esqueleto := modelo.find_child("Skeleton3D", true, false) as Skeleton3D
	if esqueleto == null:
		return
	_braco_livre = BracoLivreModifier.new()
	_braco_livre.name = "BracoLivre"
	_braco_livre.active = false
	esqueleto.add_child(_braco_livre)


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


func player_locomocao() -> AnimationPlayer:
	return _anim_pernas


## `play` só quando o clipe muda de verdade. Chamar `play` do que já está
## tocando reinicia o blend todo quadro — e `_seguir_rolo` chamava isso a cada
## quadro em que ele estivesse andando.
func _tocar(clipe: String) -> void:
	if _anim_pernas.current_animation != clipe:
		_anim_pernas.play(clipe, BLEND_LOCOMOCAO)


func tocar_locomocao() -> void:
	_tocar("andar")


## Parado ele respira. O clipe existia desde a Fase D e **nunca era tocado** —
## a alternativa era `stop()`, que deixa o corpo congelado. Respiração é o que
## separa personagem de estátua com script (OVERHAUL §5.3).
##
## Pintando, toca a variante sem braço: aí quem manda no braço é a IK do rolo, e
## a respiração completa apagaria ela.
func parar_locomocao() -> void:
	_tocar(_clipe_parado())


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

	# ⚠️ `pintar_braco` VOLTOU a tocar aqui, e não é contradição com a IK.
	#
	# Ele estava parado (`_anim_braco.stop`) desde a Fase E, quando a IK assumiu
	# o braço direito — um clipe de 1,17 s guardado no modelo que nenhuma linha
	# de código tocava. Mas as pistas dele são `Ombro_D`, `Braco_D`,
	# `Antebraco_D` e `Ombro_E`, e a IK só reescreve as DUAS DO MEIO: ela gira
	# `Braco_D`/`Antebraco_D` pra mão chegar no alvo. Os dois OMBROS sobram pro
	# clipe. É de graça: o ombro direito trabalha (e a IK compensa, porque ela
	# resolve depois) e o esquerdo sai do rest.
	_anim_braco.play("pintar_braco", BLEND_LOCOMOCAO)
	_tocar(CLIPE_PARADO_PINTANDO)
	if _ik_braco != null:
		_ik_braco.active = true
	if _braco_livre != null:
		_braco_livre.active = true
	_rolo.show()

	# ⚠️ Se o trajeto COMEÇA numa faixa alta, a parada que buscaria o banquinho
	# já ficou pra trás e nunca vai disparar. É o caso da abertura, que pega o
	# tio em 92% da parede: ele aparecia de pé a 30 cm do chão com a madeira
	# largada do outro lado do trecho.
	if _props != null and trajeto.posicao_metros().y < TrajetoRolo.ALCANCE_TOPO:
		var largura_ini: float = maxf(parede.mascara.largura_m, 0.1)
		var u_ini: float = trajeto.centro_trecho(trajeto.posicao_metros().x) / largura_ini
		var sob_o_pe: Vector3 = _pe_no_trecho(parede, u_ini, 0.0)
		sob_o_pe.y = 0.0
		_props.mover_banquinho(sob_o_pe)

	if not trajeto.foi_molhar.is_connected(_ao_molhar):
		trajeto.foi_molhar.connect(_ao_molhar)
	if not trajeto.mudou_banquinho.is_connected(_ao_mudar_banquinho):
		trajeto.mudou_banquinho.connect(_ao_mudar_banquinho)
	if not trajeto.passada.is_connected(_ao_passada):
		trajeto.passada.connect(_ao_passada)
	await trajeto.terminou
	trajeto.foi_molhar.disconnect(_ao_molhar)
	trajeto.mudou_banquinho.disconnect(_ao_mudar_banquinho)
	trajeto.passada.disconnect(_ao_passada)

	if _ik_braco != null:
		_ik_braco.active = false
	if _braco_livre != null:
		_braco_livre.active = false
		_braco_livre.elevacao = 0.0
		_braco_livre.balanco = 0.0
	_anim_braco.stop(true)
	_rolo.hide()
	definir_agachamento(0.0)
	definir_inclinacao_torso(0.0)
	_inclinacao_suave = 0.0
	_balanco_suave = 0.0
	_elevacao_suave = 0.0
	position.y = 0.0
	_trajeto = null
	_parede_atual = null
	parar_locomocao()
	pintura_concluida.emit()


func _process(delta: float) -> void:
	super(delta)  # cadência da perna casada com a velocidade do corpo
	if _carregando_mudanca:
		_posicionar_carga()
		return
	if _trajeto == null or _parede_atual == null:
		return
	_seguir_rolo(delta)


## Um quadro de "estar pintando": onde o corpo vai, que postura faz, e onde o
## rolo e a mão ficam.
func _seguir_rolo(delta: float) -> void:
	# Durante as paradas quem manda no corpo é o gesto da parada. Os dois leem a
	# fração da parada direto do trajeto, sem Tween: Tween e relógio da parada
	# são dois donos do mesmo tempo, e qualquer diferença aparece como o gesto
	# terminando antes ou depois de o rolo voltar a andar.
	if _trajeto.na_bandeja:
		_molhando_o_rolo()
		return
	if _trajeto.mexendo_no_banquinho:
		_carregando_o_banquinho()
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

	_tocar(CLIPE_ANDAR_PINTANDO if andando else CLIPE_PARADO_PINTANDO)

	# ── postura: agacha no rodapé, e o torso acompanha altura E passada ──
	var agacha: float = 0.0
	if ponto_m.y > TrajetoRolo.ALCANCE_RODAPE:
		agacha = smoothstep(TrajetoRolo.ALCANCE_RODAPE, altura, ponto_m.y)
	definir_agachamento(agacha)

	var filtro: float = clampf(delta * SUAVIZACAO_POSTURA, 0.0, 1.0)
	var fracao_altura: float = clampf(ponto_m.y / altura, 0.0, 1.0)  # 0 = teto, 1 = chão
	var alvo_inclinacao: float = lerpf(INCLINACAO_NO_ALTO, INCLINACAO_NO_RODAPE, fracao_altura)
	# subir a passada é empurrar (o corpo vai junto), descer é puxar (ele volta)
	alvo_inclinacao -= _trajeto.direcao_atual.y * INCLINACAO_DA_PASSADA
	_inclinacao_suave = lerpf(_inclinacao_suave, alvo_inclinacao, filtro)
	definir_inclinacao_torso(_inclinacao_suave)

	# ── braço livre: contrapeso do braço que trabalha ──
	if _braco_livre != null:
		# esticar pro alto e agachar são as duas posturas em que ele sai do corpo
		var alvo_elevacao: float = maxf(1.0 - fracao_altura * 2.2, agacha * 0.8)
		var alvo_balanco: float = -_trajeto.direcao_atual.y
		_elevacao_suave = lerpf(_elevacao_suave, clampf(alvo_elevacao, 0.0, 1.0), filtro)
		_balanco_suave = lerpf(_balanco_suave, alvo_balanco, filtro)
		_braco_livre.elevacao = _elevacao_suave
		_braco_livre.balanco = _balanco_suave

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

	# a espuma escorre junto com a carga — é o mesmo número que faz a cobertura
	# falhar, então o que se vê no rolo e o que aparece na parede não divergem
	_rolo.definir_molhado(inverse_lerp(
		TrajetoRolo.CARGA_MINIMA, TrajetoRolo.CARGA_CHEIA, _trajeto.carga_atual))


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


## O gesto de molhar o rolo, quadro a quadro, dirigido pela fração da parada.
##
## Cinco tempos: andar até a bandeja, agachar, ESCORRER o rolo na rampa (vai e
## volta, que é como se tira o excesso), levantar, voltar pro posto. Antes disto
## o rolo só ficava pendurado na altura do quadril enquanto o corpo ia e vinha —
## a ida à bandeja acontecia, mas a tinta não saía de lugar nenhum.
func _molhando_o_rolo() -> void:
	var f: float = _trajeto.fracao_da_parada()
	var frente: Vector3 = -global_transform.basis.z

	# corpo: vai até a bandeja e volta pro posto
	var indo: float = _fase(f, 0.05, 0.32)
	var voltando: float = _fase(f, 0.72, 0.98)
	var na_bandeja: Vector3 = _props.ponto_de_molhar() if _props != null else _posto_de_molhar
	na_bandeja.y = 0.0
	var alvo: Vector3 = _posto_de_molhar.lerp(na_bandeja, indo).lerp(_posto_de_molhar, voltando)
	position.x = alvo.x
	position.z = alvo.z
	position.y = 0.0
	_tocar(CLIPE_ANDAR_PINTANDO if (indo < 1.0 or voltando > 0.0) else CLIPE_PARADO_PINTANDO)

	# quanto ele está debruçado sobre a bandeja
	var mergulho: float = _fase(f, 0.30, 0.42) - _fase(f, 0.62, 0.74)
	definir_agachamento(mergulho * 0.62)
	definir_inclinacao_torso(mergulho * 20.0)

	var descanso: Vector3 = global_position + frente * 0.30 + Vector3.UP * 0.62
	var ponto: Vector3 = descanso
	var direcao: Vector3 = frente
	if _props != null and mergulho > 0.001:
		# vai e volta na rampa: é isso que tira o excesso, não um mergulho seco
		var eixo: Vector3 = _props.eixo_da_bandeja()
		var poco: Vector3 = _props.ponto_da_tinta() + eixo * sin(f * TAU * 2.5) * 0.08
		ponto = descanso.lerp(poco, mergulho)
		direcao = eixo

	var mao_padrao: Vector3 = (global_position + frente * 0.18
		+ Vector3.UP * lerpf(ALTURA_MAO, 0.52, mergulho))
	var mao: Vector3 = _rolo.encostar(ponto, Vector3.UP, direcao, mao_padrao)
	if _alvo_mao != null:
		_alvo_mao.global_position = mao
	if _rolo != null:
		_rolo.definir_molhado(mergulho)

	if _trajeto.repondo_tinta():
		_despejando_a_lata(f)


## A lata sobe, tomba sobre a bandeja e volta pro chão. Acontece só na primeira
## ida à bandeja de cada parede (`TrajetoRolo.Parada.REPOR`) — é de lá que a
## tinta da bandeja vem, e sem isto o poço se reabastecia sozinho.
##
## Roda ANTES do mergulho na linha do tempo da parada, que é a ordem certa:
## primeiro enche a bandeja, depois escorre o rolo nela.
func _despejando_a_lata(f: float) -> void:
	var lata: Node3D = _props.lata
	var pousada: Vector3 = _props.posicao_da_lata()
	var erguida: float = _fase(f, 0.10, 0.24) - _fase(f, 0.40, 0.54)
	if erguida <= 0.001:
		lata.global_position = pousada
		lata.rotation.z = 0.0
		return

	var sobre_bandeja: Vector3 = _props.ponto_da_tinta() + Vector3.UP * 0.34
	lata.global_position = pousada.lerp(sobre_bandeja, erguida)
	# tomba no meio do gesto, não no caminho de subida
	lata.rotation.z = deg_to_rad(-118.0) * _fase(f, 0.22, 0.32) * (1.0 - _fase(f, 0.36, 0.44))


## Guarda de onde ele saiu, pra saber pra onde voltar. Quem conta o tempo é o
## trajeto — aqui só se registra o ponto de partida do gesto.
func _ao_molhar() -> void:
	pincelada.emit()
	_posto_de_molhar = position


## Vai buscar bandeja, lata e banquinho onde estiverem, carrega tudo até a
## parede nova e larga lá.
##
## Uma viagem só, com o rolo DENTRO da bandeja — é como se carrega de verdade, e
## é o que resolve ter três objetos e duas mãos. Antes `posicionar_para_parede`
## teletransportava os três, e a garotinha sentada via os objetos pularem de
## canto do quarto.
func levar_props(props: PropsPintura, destino: ParedePintavel) -> void:
	_props = props

	var buscar: Vector3 = props.ponto_de_molhar()
	buscar.y = 0.0
	await ir_ate(buscar, 1.4)
	await agachar_ate(0.5, 0.5)

	_carregando_mudanca = true
	_rolo.show()
	await agachar_ate(0.0, 0.4)

	# calcula o destino agora; os props continuam na mão até ele largar
	props.posicionar_para_parede(destino)
	var largar: Vector3 = props.ponto_de_molhar()
	largar.y = 0.0
	await ir_ate(largar, 1.8)
	await agachar_ate(0.5, 0.5)

	_carregando_mudanca = false
	props.posicionar_para_parede(destino)
	_rolo.hide()
	await agachar_ate(0.0, 0.4)


## Onde os três objetos ficam enquanto ele os carrega: bandeja e lata numa mão,
## banquinho na outra, rolo deitado dentro da bandeja.
func _posicionar_carga() -> void:
	if _props == null:
		return
	var lado: Vector3 = global_transform.basis.x
	var frente: Vector3 = -global_transform.basis.z
	var mao_bandeja: Vector3 = global_position - lado * 0.32 + frente * 0.12 + Vector3.UP * 0.72
	_props.bandeja.global_position = mao_bandeja
	_props.lata.global_position = mao_bandeja + frente * 0.02 + Vector3.UP * 0.03
	_props.banquinho.global_position = global_position + lado * 0.40 + Vector3.UP * 0.34
	if _rolo != null:
		_rolo.global_position = mao_bandeja + Vector3.UP * 0.07
		_rolo.global_basis = Basis(lado, frente, Vector3.UP)


## O gesto de buscar o banquinho e plantar no trecho novo, também dirigido pela
## fração da parada.
##
## Seis tempos: andar até onde a madeira ficou, agachar e pegar, carregar até o
## trecho novo, agachar e largar, levantar, subir em cima. Antes o banquinho era
## teletransportado pro pé dele a cada quadro em que a faixa alta estivesse
## sendo pintada — e ficava plantado ali quando ele descia, então ele atravessava
## a madeira com a canela ao agachar no rodapé.
func _carregando_o_banquinho() -> void:
	if _props == null:
		return
	var f: float = _trajeto.fracao_da_parada()
	var normal: Vector3 = _parede_atual.normal_interna()

	# ⚠️ 0,62 m, não 0,38: ele encara a parede o tempo todo, então o banquinho
	# fica À FRENTE dele. Com 0,38 a madeira caía entre as pernas — ele parecia
	# montado nela em vez de agachado pra pegar.
	var ao_lado_de: Vector3 = _banquinho_de + normal * 0.62
	var ao_lado_para: Vector3 = _banquinho_para + normal * 0.62
	ao_lado_de.y = 0.0
	ao_lado_para.y = 0.0

	# corpo: até a madeira, depois até o trecho novo
	var ate_madeira: float = _fase(f, 0.02, 0.26)
	var carregando: float = _fase(f, 0.40, 0.70)
	var pe: Vector3 = _pe_ao_mudar.lerp(ao_lado_de, ate_madeira).lerp(ao_lado_para, carregando)
	position.x = pe.x
	position.z = pe.z

	# abaixar pra pegar, abaixar pra largar
	var pegando: float = _fase(f, 0.26, 0.36) - _fase(f, 0.40, 0.48)
	var largando: float = _fase(f, 0.70, 0.78) - _fase(f, 0.80, 0.88)
	var curvado: float = maxf(pegando, largando)
	definir_agachamento(curvado * 0.55)
	definir_inclinacao_torso(curvado * 26.0)

	# sobe no banquinho só depois de ele estar no chão
	position.y = _fase(f, 0.88, 1.0) * ALTURA_BANQUINHO

	var andando: bool = (ate_madeira > 0.0 and ate_madeira < 1.0) or (carregando > 0.0 and carregando < 1.0)
	_tocar(CLIPE_ANDAR_PINTANDO if andando else CLIPE_PARADO_PINTANDO)

	# a madeira: no chão, na mão, no chão de novo
	var na_mao: float = _fase(f, 0.34, 0.42) - _fase(f, 0.74, 0.82)
	var lado: Vector3 = global_transform.basis.x
	var carregado: Vector3 = (global_position + lado * 0.42
		- global_transform.basis.z * 0.12 + Vector3.UP * 0.30)
	var no_chao: Vector3 = _banquinho_de.lerp(_banquinho_para, carregando)
	_props.mover_banquinho(no_chao.lerp(carregado, na_mao))

	# e o rolo fica pendurado na outra mão, apontando pro chão
	var frente: Vector3 = -global_transform.basis.z
	var ponto: Vector3 = global_position + frente * 0.22 + Vector3.UP * 0.42
	var mao: Vector3 = _rolo.encostar(ponto, Vector3.UP, frente,
		global_position + frente * 0.14 + Vector3.UP * 0.86)
	if _alvo_mao != null:
		_alvo_mao.global_position = mao


## Guarda de onde sai e pra onde vai a madeira. O trecho novo é o que o rolo vai
## atacar assim que a parada acabar — `centro_trecho` do ponto em que ele parou,
## que é o fim do bloco anterior, dentro do MESMO trecho.
func _ao_mudar_banquinho() -> void:
	if _props == null or _trajeto == null or _parede_atual == null:
		return
	var largura: float = maxf(_parede_atual.mascara.largura_m, 0.1)
	var u_posto: float = _trajeto.centro_trecho(_trajeto.posicao_metros().x) / largura
	_pe_ao_mudar = position
	_pe_ao_mudar.y = 0.0
	_banquinho_de = _props.banquinho.position
	_banquinho_de.y = 0.0
	_banquinho_para = _pe_no_trecho(_parede_atual, u_posto, 0.0)
	_banquinho_para.y = 0.0


## Rampa 0→1 entre dois instantes de uma parada. Existe pra os gestos serem
## escritos como uma linha do tempo legível em vez de `if` encadeado.
static func _fase(f: float, de: float, ate: float) -> float:
	return smoothstep(de, ate, f)
