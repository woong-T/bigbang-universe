extends Node
## 인트로를 띄우고 빨리 감아 끝까지 돌려 본다(그리기·글자 코드 오류 확인용).
## 1) 처음부터 끝까지 재생 → 화면 누르기 → finished 신호
## 2) 중간에 건너뛰기 → finished 신호
## 실행: godot --headless --path . res://tests/intro_smoke.tscn

var _ok := true


func _ready() -> void:
	var probe: Control = load("res://scenes/intro.tscn").instantiate()
	if not probe.has_method("advance"):
		push_error("인트로 스크립트를 불러오지 못했어요")
		get_tree().quit(1)
		return
	probe.free()
	await _run_full()
	await _run_skip()
	print("인트로 스모크: " + ("통과" if _ok else "실패"))
	get_tree().quit(0 if _ok else 1)


func _make_intro() -> Control:
	var intro: Control = load("res://scenes/intro.tscn").instantiate()
	intro.auto_change_scene = false
	intro.set_process(false)   # 시간은 테스트가 직접 넘긴다
	add_child(intro)
	return intro


func _run_full() -> void:
	var intro := _make_intro()
	var done := [false]
	intro.finished.connect(func(): done[0] = true)
	var saw_sparks := false
	while not intro.is_waiting_for_tap():
		intro.advance(1.0 / 30.0)
		saw_sparks = saw_sparks or not intro._sparks.is_empty()
		await get_tree().process_frame
	_check(saw_sparks, "빅뱅 불꽃이 생겨야 해요")
	var tap := InputEventMouseButton.new()
	tap.button_index = MOUSE_BUTTON_LEFT
	tap.pressed = true
	intro._gui_input(tap)
	await _wait_for(done)
	_check(done[0], "끝까지 본 뒤 화면을 누르면 끝나야 해요")
	intro.queue_free()


func _run_skip() -> void:
	var intro := _make_intro()
	var done := [false]
	intro.finished.connect(func(): done[0] = true)
	for i in 60:
		intro.advance(1.0 / 30.0)
	intro.skip()
	await _wait_for(done)
	_check(done[0], "건너뛰기를 누르면 바로 끝나야 해요")
	intro.queue_free()


func _wait_for(flag: Array) -> void:
	for i in 300:
		if flag[0]:
			return
		await get_tree().create_timer(0.02).timeout


func _check(cond: bool, msg: String) -> void:
	if not cond:
		_ok = false
		push_error(msg)
