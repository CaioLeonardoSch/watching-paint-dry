extends Node

# ─────────────────────────────────────────────
#  OPÇÕES — autoload (singleton "Opcoes")
#
#  Configuração técnica (volume, tela cheia), separada do save de progresso
#  (EstadoJogo/DadosSalvos) — persiste em user://config.cfg via ConfigFile.
#  Aplica no _ready(), antes do menu aparecer.
# ─────────────────────────────────────────────

const CAMINHO_CONFIG: String = "user://config.cfg"
const SECAO: String = "opcoes"

var volume: float = 1.0
var tela_cheia: bool = false


func _ready() -> void:
	_carregar()
	_aplicar_volume()
	_aplicar_tela_cheia()


func definir_volume(valor: float) -> void:
	volume = valor
	_aplicar_volume()
	_salvar()


func definir_tela_cheia(ativo: bool) -> void:
	tela_cheia = ativo
	_aplicar_tela_cheia()
	_salvar()


func _aplicar_volume() -> void:
	var indice_bus: int = AudioServer.get_bus_index("Master")
	AudioServer.set_bus_volume_db(indice_bus, linear_to_db(maxf(volume, 0.0001)))


func _aplicar_tela_cheia() -> void:
	var modo: int = DisplayServer.WINDOW_MODE_FULLSCREEN if tela_cheia else DisplayServer.WINDOW_MODE_WINDOWED
	DisplayServer.window_set_mode(modo)


func _salvar() -> void:
	var config := ConfigFile.new()
	config.set_value(SECAO, "volume", volume)
	config.set_value(SECAO, "tela_cheia", tela_cheia)
	config.save(CAMINHO_CONFIG)


func _carregar() -> void:
	var config := ConfigFile.new()
	if config.load(CAMINHO_CONFIG) != OK:
		return
	volume = config.get_value(SECAO, "volume", volume)
	tela_cheia = config.get_value(SECAO, "tela_cheia", tela_cheia)
