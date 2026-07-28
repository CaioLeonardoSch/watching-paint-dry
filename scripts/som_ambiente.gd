extends AudioStreamPlayer

# ─────────────────────────────────────────────
#  SOM AMBIENTE — "ar do quarto" sintetizado em código
#
#  Sem nenhum arquivo de áudio: AudioStreamGenerator gera os frames em
#  tempo real, ruído marrom (integrador com vazamento) modulado por um
#  seno bem lento, pra não soar como um chiado estático parado.
# ─────────────────────────────────────────────

const MIX_RATE: float           = 22050.0
const BUFFER_SEGUNDOS: float    = 0.5
const PERIODO_RESPIRACAO: float = 20.0  # segundos, ciclo lento de volume

@export_range(0.0, 0.3) var volume_relativo: float = 0.05  # amplitude linear, bem baixo

var _playback: AudioStreamGeneratorPlayback
var _marrom: float = 0.0
var _tempo: float = 0.0


func _ready() -> void:
	_garantir_bus_ambiente()
	bus = "Ambiente"

	var gerador := AudioStreamGenerator.new()
	gerador.mix_rate     = MIX_RATE
	gerador.buffer_length = BUFFER_SEGUNDOS
	stream = gerador

	play()
	_playback = get_stream_playback() as AudioStreamGeneratorPlayback


func _garantir_bus_ambiente() -> void:
	if AudioServer.get_bus_index("Ambiente") != -1:
		return
	AudioServer.add_bus()
	var indice := AudioServer.get_bus_count() - 1
	AudioServer.set_bus_name(indice, "Ambiente")
	AudioServer.set_bus_send(indice, "Master")


func _process(delta: float) -> void:
	if not _playback:
		return

	_tempo += delta
	# "Respiração": volume sobe e desce bem devagar, entre 20% e 100% do relativo
	var respiracao: float = 0.6 + 0.4 * sin(_tempo * TAU / PERIODO_RESPIRACAO)
	var amplitude: float  = volume_relativo * respiracao

	var frames_disponiveis: int = _playback.get_frames_available()
	for i in frames_disponiveis:
		_marrom = clamp((_marrom + 0.02 * randf_range(-1.0, 1.0)) * 0.98, -1.0, 1.0)
		var amostra: float = _marrom * amplitude
		_playback.push_frame(Vector2(amostra, amostra))
