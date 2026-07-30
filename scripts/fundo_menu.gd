extends "res://scripts/inicializar_quarto.gd"

# ─────────────────────────────────────────────
#  FUNDO DO MENU — versão só-visual do quarto
#
#  Herda a geometria de inicializar_quarto.gd (chão, teto, paredes, janela,
#  lâmpada, cadeira — tudo estático, sem _process nenhum). Sem tinta_secando,
#  sem personagens, sem ciclo dia/noite: é um instantâneo bonito do quarto,
#  não a simulação rodando. As paredes "de tinta" (que o script base deixa
#  sem material, já que normalmente tinta_secando.gd cuida disso) recebem
#  aqui a cor azul já seca, pra parecer o jogo de verdade e não uma sala vazia.
# ─────────────────────────────────────────────

const PAREDES_TINTA: Array[String] = [
	"ParedeNorteSolida", "ParedeSul",
	"ParedeOesteNorte", "ParedeOesteSul", "ParedeOesteAcima", "ParedeOesteAbaixo",
	"ParedeLesteNorte", "ParedeLesteSul", "ParedeLesteAcima",
]


func _ready() -> void:
	super._ready()
	_pintar_paredes()


func _pintar_paredes() -> void:
	var cor := load("res://resources/cores/azul.tres") as CorTinta
	if not cor or cor.variantes_secas.is_empty():
		return

	var ruido  := MateriaisProcedurais.criar_textura_ruido(0.1, 512)
	var normal := MateriaisProcedurais.criar_normal_ruido(0.4, 0.6, 512)
	var mat := MateriaisProcedurais.criar_material_texturizado(
		cor.variantes_secas[-1], 0.55, ruido, Vector3(2.0, 2.0, 2.0), normal, 0.4)

	for nome in PAREDES_TINTA:
		var no := get_node_or_null(nome)
		if no:
			no.set_surface_override_material(0, mat)
