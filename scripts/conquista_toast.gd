extends CanvasLayer

# ─────────────────────────────────────────────
#  TOAST DE CONQUISTA — avisinho que aparece quando desbloqueia uma
#
#  Não modal (mouse_filter ignore, não mexe em modo de mouse) — não briga
#  com dialogo_pintura.gd nem menu_pausa.gd por causa disso. Enfileira ids
#  e mostra um de cada vez.
# ─────────────────────────────────────────────

const DURACAO_FADE: float = 0.4
const DURACAO_ESPERA: float = 2.5

@onready var _painel: Control = $PanelContainer
@onready var _label: Label    = $PanelContainer/Label

var _fila: Array[String] = []
var _mostrando: bool = false


func _ready() -> void:
	_painel.mouse_filter = Control.MOUSE_FILTER_IGNORE  # CanvasLayer não tem mouse_filter, o filho tem
	_painel.modulate.a = 0.0
	EstadoJogo.conquista_desbloqueada.connect(_enfileirar)


func _enfileirar(id: String) -> void:
	_fila.append(id)
	if not _mostrando:
		_mostrar_proxima()


func _mostrar_proxima() -> void:
	if _fila.is_empty():
		_mostrando = false
		return

	_mostrando = true
	var id: String = _fila.pop_front()
	_label.text = "Conquista desbloqueada:\n%s" % Conquistas.TEXTOS.get(id, id)

	var tw := create_tween()
	tw.tween_property(_painel, "modulate:a", 1.0, DURACAO_FADE)
	tw.tween_interval(DURACAO_ESPERA)
	tw.tween_property(_painel, "modulate:a", 0.0, DURACAO_FADE)
	await tw.finished

	_mostrar_proxima()
