extends AudioStreamPlayer3D

# ─────────────────────────────────────────────
#  SOM DE PINCELADA — "swish" curto gerado em código
#
#  Filho do Tio (tio.tscn). Escuta o sinal `pincelada` (emitido a cada
#  passada de braço em tio.gd::pintar_parede) e toca um AudioStreamWAV
#  gerado uma vez em _ready(), sem carregar nenhum arquivo de áudio.
# ─────────────────────────────────────────────

const MIX_RATE: int = 22050

@export_range(0.0, 1.0) var duracao_segundos: float = 0.4


func _ready() -> void:
	stream = _gerar_som_pincelada()

	var tio := get_parent() as Tio
	if tio:
		tio.pincelada.connect(_tocar)
	else:
		push_warning("SomPincelada esperava ser filho de um nó Tio")


func _tocar() -> void:
	pitch_scale = randf_range(0.92, 1.08)
	play()


func _gerar_som_pincelada() -> AudioStreamWAV:
	var total_amostras: int = int(duracao_segundos * MIX_RATE)
	var bytes := PackedByteArray()
	bytes.resize(total_amostras * 2)  # 16 bits = 2 bytes por amostra

	var ruido: float = 0.0
	for i in total_amostras:
		var t: float = float(i) / float(total_amostras)
		var envelope: float = sin(t * PI)  # sobe e desce ao longo da duração — "swish"
		ruido = (ruido + 0.15 * randf_range(-1.0, 1.0)) * 0.9  # ruído com passa-baixa simples
		var amostra: float = clamp(ruido * envelope * 0.6, -1.0, 1.0)
		bytes.encode_s16(i * 2, int(amostra * 32767.0))

	var wav := AudioStreamWAV.new()
	wav.format   = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = MIX_RATE
	wav.stereo   = false
	wav.data     = bytes
	return wav
