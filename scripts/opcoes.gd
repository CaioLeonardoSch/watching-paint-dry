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

## Idiomas suportados hoje (chave = locale do Godot, valor = chave de
## tradução do nome do idioma em resources/localizacao/textos.csv). Só
## pt_BR e en têm texto de verdade por enquanto — os outros caem no
## fallback (locale/fallback = pt_BR em project.godot) até traduzir.
const IDIOMAS: Dictionary = {
	"pt_BR": "IDIOMA_NOME_PT",
	"en":    "IDIOMA_NOME_EN",
	"es":    "IDIOMA_NOME_ES",
	"fr":    "IDIOMA_NOME_FR",
	"zh_CN": "IDIOMA_NOME_ZH",
	"ja":    "IDIOMA_NOME_JA",
	"de":    "IDIOMA_NOME_DE",
}

var volume: float = 1.0
var tela_cheia: bool = false
var idioma: String = "pt_BR"


func _ready() -> void:
	_carregar()
	_aplicar_volume()
	_aplicar_tela_cheia()
	_aplicar_idioma()


func definir_volume(valor: float) -> void:
	volume = valor
	_aplicar_volume()
	_salvar()


func definir_tela_cheia(ativo: bool) -> void:
	tela_cheia = ativo
	_aplicar_tela_cheia()
	_salvar()


func definir_idioma(codigo: String) -> void:
	if not IDIOMAS.has(codigo):
		return
	idioma = codigo
	_aplicar_idioma()
	_salvar()


func _aplicar_volume() -> void:
	var indice_bus: int = AudioServer.get_bus_index("Master")
	AudioServer.set_bus_volume_db(indice_bus, linear_to_db(maxf(volume, 0.0001)))


func _aplicar_tela_cheia() -> void:
	var modo: int = DisplayServer.WINDOW_MODE_FULLSCREEN if tela_cheia else DisplayServer.WINDOW_MODE_WINDOWED
	DisplayServer.window_set_mode(modo)


func _aplicar_idioma() -> void:
	TranslationServer.set_locale(idioma)


func _salvar() -> void:
	var config := ConfigFile.new()
	config.set_value(SECAO, "volume", volume)
	config.set_value(SECAO, "tela_cheia", tela_cheia)
	config.set_value(SECAO, "idioma", idioma)
	config.save(CAMINHO_CONFIG)


func _carregar() -> void:
	var config := ConfigFile.new()
	if config.load(CAMINHO_CONFIG) != OK:
		return
	volume = config.get_value(SECAO, "volume", volume)
	tela_cheia = config.get_value(SECAO, "tela_cheia", tela_cheia)
	idioma = config.get_value(SECAO, "idioma", idioma)
