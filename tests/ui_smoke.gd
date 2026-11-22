extends Node
## 메인 화면을 띄우고 버튼을 무작위로 눌러 몇 판을 끝까지 진행해 본다(화면 코드 오류 확인용).
## 실행: godot --headless res://tests/ui_smoke.tscn

const GAMES := 30


func _ready() -> void:
	var main: Control = load("res://scenes/main.tscn").instantiate()
	add_child(main)
	await get_tree().process_frame
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	var finished := 0
	var steps := 0
	while finished < GAMES and steps < 5000:
		steps += 1
		await get_tree().process_frame
		var buttons: Array = main.get_node("%Content").get_children().filter(
			func(n): return n is Button and not n.is_queued_for_deletion())
		if buttons.is_empty():
			continue
		var texts: Array = buttons.map(func(b): return b.text)
		if texts.has("다시 만들기 →"):
			finished += 1
			buttons[texts.find("다시 만들기 →")].pressed.emit()
		else:
			buttons[rng.randi_range(0, buttons.size() - 1)].pressed.emit()
	print("UI 스모크: %d판 완료 (%d번 클릭)" % [finished, steps])
	get_tree().quit(0 if finished == GAMES else 1)
