extends Node
## 무작위로 여러 판을 끝까지 자동 진행해서 규칙이 오류 없이 도는지, 어떤 결말이 나오는지 확인한다.
## 실행: godot --headless res://tests/simulate.tscn  (또는 에디터에서 이 장면을 F6 으로 실행)

const RUNS := 2000


func _ready() -> void:
	var counts := {}
	var rng := RandomNumberGenerator.new()
	rng.seed = 12345
	for i in RUNS:
		var u := Universe.new(i)
		u.apply_seed(GameData.seeds[rng.randi_range(0, GameData.seeds.size() - 1)])
		var ending_id := _play(u, rng)
		var e := u.pick_ending(ending_id)
		u.ending_story(e)  # 문장 조립이 오류 없이 되는지
		counts[e.id] = counts.get(e.id, 0) + 1
	print("== %d판 결과 ==" % RUNS)
	for e in GameData.endings:
		print("  %-8s %-14s %5d" % [e.id, e.name, counts.get(e.id, 0)])
	var missing := GameData.endings.filter(func(e): return not counts.has(e.id))
	print("나오지 않은 결말: ", missing.map(func(e): return e.id))
	get_tree().quit(0)


## 한 판 진행. 중간에 끝나면 강제 결말 id, 끝까지 가면 "" 를 돌려준다.
func _play(u: Universe, rng: RandomNumberGenerator) -> String:
	while true:
		var x := u.stage_view()
		u.apply_choice(x.choices[rng.randi_range(0, x.choices.size() - 1)], x.short)
		var stop := u.check_early_stop()
		if not stop.is_empty():
			return stop.ending
		if u.is_last_stage():
			return ""
		if u.roll_vacuum_decay():
			return "vacuum"
		var ev := u.roll_event()
		if not ev.is_empty():
			u.apply_choice(ev.choices[rng.randi_range(0, ev.choices.size() - 1)], "사건")
			stop = u.check_early_stop()
			if not stop.is_empty():
				return stop.ending
		u.advance()
	return ""
