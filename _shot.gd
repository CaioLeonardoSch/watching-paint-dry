extends SceneTree

# TEMPORARIO — captura screenshot do quarto pra avaliar iluminacao. Apagar depois.

func _initialize() -> void:
	_rodar()


func _rodar() -> void:
	var cena: Node = load("res://scenes/quarto.tscn").instantiate()
	root.add_child(cena)
	var segundos := float(OS.get_environment("SHOT_T"))
	if segundos <= 0.0:
		segundos = 4.0
	var t := 0.0
	while t < segundos:
		await process_frame
		t += 1.0 / 60.0
	await process_frame
	var img := root.get_texture().get_image()
	img.save_png(OS.get_environment("SHOT_OUT"))
	quit()
