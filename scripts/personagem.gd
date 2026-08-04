extends Node3D
class_name Personagem

# ─────────────────────────────────────────────
#  PERSONAGEM — a locomoção que o tio e a garotinha têm em comum
#
#  Existe porque as duas queixas de locomoção da Fase D (OVERHAUL §5.7) valem
#  pros dois: virar o corpo antes de andar, e atravessar a porta em vez de
#  materializar dentro do quarto. Antes cada script tinha o seu `ir_ate` com o
#  mesmo Tween de `position` — e nenhum dos dois tocava em `rotation`, então o
#  personagem deslizava de lado com o clipe `andar` tocando como se fosse pra
#  frente.
#
#  O que é de cada um continua em `tio.gd`/`garotinha.gd`: o tio tem dois
#  `AnimationPlayer` (pernas e braço tocam junto), a garotinha tem um só.
# ─────────────────────────────────────────────

signal chegou
signal saiu

## Quão rápido ele gira no lugar, em radianos por segundo. Meia volta leva
## ~0,5 s. **O giro acontece ANTES do deslocamento, não junto** — quem gira
## enquanto translada faz curva de carro, não de pessoa.
const VELOCIDADE_GIRO: float = 6.0

## Abaixo disto não vale girar: a direção de um passo curto é ruído numérico, e
## girar por causa dela faz o corpo tremer no lugar.
const DESLOCAMENTO_MINIMO: float = 0.05

## Onde o personagem espera, fora do quarto.
##
## A parede leste tem a face interna em X = 2,9 e o cômodo vizinho começa em
## X = 3,6 — então 4,2 põe ele **dentro do vizinho**, que é modelado e
## iluminado. É isso que deixa ele sumir por oclusão da parede em vez de por
## `hide()`. O vão da porta é Z ∈ [−0,5, +0,5], então a travessia é em Z = 0.
const PONTO_FORA_DA_PORTA: Vector3 = Vector3(4.2, 0.0, 0.0)

## Logo do lado de dentro do vão, alinhado com ele. A caminhada porta-adentro é
## sempre em dois trechos (vão primeiro, destino depois) pra ele atravessar a
## abertura de frente em vez de rasgar o batente na diagonal.
const PONTO_VAO_DA_PORTA: Vector3 = Vector3(2.5, 0.0, 0.0)


var _postura: PosturaModifier
var _ik_pernas: Array[TwoBoneIK3D] = []
var _alvos_pe: Array[Node3D] = []
var _pes_repouso: Array[Vector3] = []


func _ready() -> void:
	ligar_rig()


## Acha a camada procedural e as IK das pernas dentro do modelo.
##
## `find_child` em vez de caminho fixo porque a armadura tem nome diferente em
## cada modelo (`Tio2_Armature` × `Garotinha2_Armature`) — e em vez de
## `%NomeUnico`, que já resolveu pra `null` sem motivo claro neste projeto.
func ligar_rig() -> void:
	var modelo: Node = get_node_or_null("Modelo")
	if modelo == null:
		return
	_postura = modelo.find_child("Postura", true, false) as PosturaModifier
	for nome in ["IKPernaDireita", "IKPernaEsquerda"]:
		var ik := modelo.find_child(nome, true, false) as TwoBoneIK3D
		if ik != null:
			_ik_pernas.append(ik)
	for nome in ["AlvoPeDireito", "AlvoPeEsquerdo"]:
		var alvo := modelo.find_child(nome, true, false) as Node3D
		if alvo != null:
			_alvos_pe.append(alvo)
			_pes_repouso.append(alvo.position)


## Move os alvos dos pés a partir do repouso. É o que separa AGACHAR de SENTAR:
## agachado os pés ficam embaixo do quadril, sentado eles vão pra frente (e pra
## cima, porque criança em cadeira de adulto não alcança o chão).
##
## Sem mexer nos alvos, sentar sairia como cócoras.
func definir_pose_pes(deslocamento: Vector3) -> void:
	for i in _alvos_pe.size():
		_alvos_pe[i].position = _pes_repouso[i] + deslocamento


## 0 = em pé, 1 = agachado no fundo.
##
## Liga a IK das pernas junto, e essa é a parte que importa: sem ela o quadril
## desce e **os pés atravessam o assoalho**. Desliga de volta em pé porque com a
## IK ativa os alvos dos pés estão fixos no corpo, e aí ela pregaria os pés no
## lugar por cima do clipe `andar`.
func definir_agachamento(fracao: float) -> void:
	if _postura == null:
		return
	_postura.agachamento = clampf(fracao, 0.0, 1.0)
	var de_pe: bool = _postura.agachamento <= 0.001
	for ik in _ik_pernas:
		ik.active = not de_pe


## Peso do corpo acompanhando o braço. Graus, positivo = pra frente.
func definir_inclinacao_torso(graus: float) -> void:
	if _postura != null:
		_postura.inclinacao_torso = graus


## Agacha (ou levanta) interpolado — senão lê como troca de pose, não como
## esforço, que é justamente o que a camada procedural existe pra evitar.
func agachar_ate(fracao: float, duracao: float = 0.8) -> void:
	if _postura == null:
		return
	var tw := create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tw.tween_method(definir_agachamento, _postura.agachamento,
		clampf(fracao, 0.0, 1.0), duracao)
	await tw.finished


## Ângulo em Y que deixa o personagem OLHANDO na direção `direcao`.
##
## O modelo nasce olhando pra −Z (padrão do Godot), então depois de girar θ a
## frente dele é `(−sin θ, 0, −cos θ)`. Igualando a `direcao`: θ = atan2(−x, −z).
## É a mesma convenção dos ângulos tabelados em `ciclo_pintura.gd::VARREDURAS`
## — conferido: os −90° de lá olham pra +X, que é onde está a parede leste.
static func angulo_para(direcao: Vector3) -> float:
	return atan2(-direcao.x, -direcao.z)


## Gira no lugar até `angulo_alvo` (radianos), em velocidade constante.
##
## `lerp_angle` de propósito: ele resolve o caminho curto sozinho, senão virar
## de 359° pra 1° dá a volta inteira. E é interpolado, nunca setado direto —
## `rotation.y` trocado num frame lê como teleporte de orientação.
func girar_para(angulo_alvo: float) -> void:
	var de: float = rotation.y
	var volta: float = absf(wrapf(angulo_alvo - de, -PI, PI))
	if volta < 0.02:
		return
	var tw := create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tw.tween_method(_aplicar_giro.bind(de, angulo_alvo), 0.0, 1.0, volta / VELOCIDADE_GIRO)
	await tw.finished


func _aplicar_giro(fracao: float, de: float, ate: float) -> void:
	rotation.y = lerp_angle(de, ate, fracao)


## Anda em linha reta até `destino` (posição local), devagar — combina com o tom
## "jogo lento" do projeto. Vira o corpo pra direção da caminhada primeiro.
##
## Não emite sinal sozinho; quem chama decide o que emitir.
func ir_ate(destino: Vector3, duracao: float = 3.0) -> void:
	var direcao: Vector3 = destino - position
	direcao.y = 0.0
	if direcao.length() > DESLOCAMENTO_MINIMO:
		# os pés já se arrastam durante o pivô — parado ele viraria feito torre
		tocar_locomocao()
		await girar_para(angulo_para(direcao))

	tocar_locomocao()
	var tw := create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tw.tween_property(self, "position", destino, duracao)
	await tw.finished
	parar_locomocao()


## Põe o personagem do lado de fora, já olhando pro vão, e o torna visível.
##
## Chamar **antes de abrir a porta**: com a folha fechada ele fica ocluído, e aí
## o `show()` não é visto. É o que substitui o `position = ponto_entrada` +
## `show()` que acontecia dentro do quarto, na frente do jogador.
func posicionar_fora() -> void:
	position = PONTO_FORA_DA_PORTA
	rotation.y = angulo_para(PONTO_VAO_DA_PORTA - PONTO_FORA_DA_PORTA)
	show()
	parar_locomocao()


## Atravessa o vão andando e segue até `destino`.
func entrar_pela_porta(destino: Vector3, duracao: float = 2.5) -> void:
	if not visible:
		posicionar_fora()
	await ir_ate(PONTO_VAO_DA_PORTA, duracao * 0.45)
	await ir_ate(destino, duracao * 0.55)
	chegou.emit()


## Anda até o vão, atravessa, e só então some — do lado de fora, atrás da
## parede. Antes isto terminava com `hide()` na soleira: ele evaporava na porta.
func sair_pela_porta(duracao: float = 2.5) -> void:
	await ir_ate(PONTO_VAO_DA_PORTA, duracao * 0.55)
	await ir_ate(PONTO_FORA_DA_PORTA, duracao * 0.45)
	hide()
	saiu.emit()


## Ganchos — quem tem `AnimationPlayer` sobrescreve. Ficam vazios aqui porque a
## locomoção não precisa saber quantos players o personagem tem.
func tocar_locomocao() -> void:
	pass


func parar_locomocao() -> void:
	pass
