class_name Universe
extends RefCounted
## 한 판 동안의 우주 상태와 규칙.
## 화면(UI)과 분리되어 있어서 테스트나 다른 화면에서도 그대로 쓸 수 있다.
##
## 상태 값(state): D 밀도, F 밀도 요동, M 물질, C 헬륨 비율, DM 암흑물질,
##                L 암흑에너지(미는 힘), LIFE 무거운 원소, age 우주 나이(10억 년)
## 플래그(flags): noinf, lowinf, multi, other, weak, anti, meta, vac, hhiggs, hot, open, small, bhfirst, steady, stat ...

var state: Dictionary = {}
var flags: Dictionary = {}
var sages: Array[String] = []
var path: Array = []  # [{era, text}] 지나온 선택 기록
var events_used: Array[String] = []
var seed_name := ""
var stage_index := 0
var rng := RandomNumberGenerator.new()


func _init(random_seed: int = -1) -> void:
	if random_seed >= 0:
		rng.seed = random_seed
	else:
		rng.randomize()
	var r: Dictionary = GameData.rules
	state = r.initial_state.duplicate(true)
	apply_effects(r.get("initial_random", []))


# ---------- 효과 ----------

## choice 하나를 적용한다. 결과 문장과 바뀌기 전 상태를 돌려준다.
func apply_choice(choice: Dictionary, era_label: String) -> Dictionary:
	var before := state.duplicate()
	var result_text: String = choice.get("result", "")
	if choice.has("dice"):
		var roll := rng.randf()
		var acc := 0.0
		for outcome in choice.dice:
			acc += float(outcome.chance)
			if roll < acc:
				apply_effects(outcome.effects)
				result_text = outcome.result
				break
	else:
		apply_effects(choice.get("effects", []))
	clamp_state(GameData.rules.clamp_keys)
	var new_sage := false
	if choice.has("sage") and not sages.has(choice.sage):
		sages.append(choice.sage)
		new_sage = true
	path.append({"era": era_label, "text": choice.text})
	return {"before": before, "result": result_text, "new_sage": new_sage}


func apply_seed(seed: Dictionary) -> void:
	apply_effects(seed.get("effects", []))
	clamp_state(GameData.rules.seed_clamp_keys)
	seed_name = seed.name


func apply_effects(effects: Array) -> void:
	for e in effects:
		var key: String = e.get("key", "")
		match e.op:
			"add":
				state[key] = state[key] + e.value
			"add_random":
				state[key] = state[key] + rng.randf_range(e.min, e.max)
			"set":
				state[key] = e.value
			"scale_from":
				state[key] = e.center + (state[key] - e.center) * e.factor
			"move_toward":
				state[key] = state[key] + (e.target - state[key]) * e.amount
			"flag":
				flags[e.flag] = true
			_:
				push_warning("모르는 효과: %s" % e.op)


func clamp_state(keys: Array) -> void:
	var r: Dictionary = GameData.rules
	for k in keys:
		state[k] = clampf(state[k], r.clamp_min, r.clamp_max)


# ---------- 조건 ----------

## JSON 조건식을 검사한다. null 은 항상 참.
## {all:[...]}, {any:[...]}, {flag:"x"}, {not_flag:"x"}, {not_sage:"id"}, {key:"D", op:">=", value:50}
func check(cond: Variant) -> bool:
	if cond == null:
		return true
	var c: Dictionary = cond
	if c.has("all"):
		for x in c.all:
			if not check(x):
				return false
		return true
	if c.has("any"):
		for x in c.any:
			if check(x):
				return true
		return false
	if c.has("flag"):
		return flags.get(c.flag, false)
	if c.has("not_flag"):
		return not flags.get(c.not_flag, false)
	if c.has("not_sage"):
		return not sages.has(c.not_sage)
	var v: float = state.get(c.key, 0.0)
	match c.op:
		">=": return v >= c.value
		"<=": return v <= c.value
		">": return v > c.value
		"<": return v < c.value
		"==": return is_equal_approx(v, c.value)
	push_warning("모르는 비교 연산: %s" % c.op)
	return false


# ---------- 진행 ----------

func current_stage() -> Dictionary:
	return GameData.stages[stage_index]


func is_last_stage() -> bool:
	return stage_index >= GameData.stages.size() - 1


## 상태에 따라 바뀌는 시대 설명/시간을 반영한 사본.
func stage_view() -> Dictionary:
	var x: Dictionary = current_stage().duplicate()
	var replaced := false
	for v in x.get("desc_variants", []):
		if not check(v.when):
			continue
		match v.mode:
			"prefix":
				if not replaced:
					x.desc = v.text + x.desc
					replaced = true
			"replace":
				if not replaced:
					x.desc = v.text
					if v.has("time"):
						x.time = v.time
					replaced = true
			"suffix":
				x.desc += v.text
	return x


## 지금 시대에서 우주가 끝나 버렸는지. 끝났으면 {ending, text}, 아니면 빈 사전.
func check_early_stop() -> Dictionary:
	for s in GameData.rules.early_stops:
		if stage_index >= s.stages[0] and stage_index <= s.stages[1] and check(s.when):
			return {"ending": s.ending, "text": s.text}
	return {}


func roll_vacuum_decay() -> bool:
	var v: Dictionary = GameData.rules.vacuum_decay
	if flags.get(v.flag, false) and stage_index >= v.from_stage and rng.randf() < v.chance:
		path.append({"era": "사건", "text": "진공 붕괴"})
		return true
	return false


## 시대가 끝난 뒤 돌발 사건을 하나 고른다. 없으면 빈 사전.
func roll_event() -> Dictionary:
	var r: Dictionary = GameData.rules.events
	if events_used.size() >= r.max_per_run:
		return {}
	var pool: Array = []
	for e in GameData.events:
		if _has_index(e.after_stages, stage_index) and not events_used.has(e.id) and check(e.get("condition")):
			pool.append(e)
	if pool.is_empty():
		return {}
	var forced: Variant = null
	for e in pool:
		if e.get("forced", false):
			forced = e
			break
	var behind := events_used.size() < int((stage_index + 1) / float(r.catch_up_every_stages))
	if forced == null and not behind and rng.randf() > r.base_chance:
		return {}
	var picked: Dictionary = forced if forced != null else pool[rng.randi_range(0, pool.size() - 1)]
	events_used.append(picked.id)
	return picked


## JSON 숫자는 float 로 읽히므로 int 로 맞춰 비교한다.
static func _has_index(list: Array, i: int) -> bool:
	for x in list:
		if int(x) == i:
			return true
	return false


func advance() -> void:
	stage_index += 1


# ---------- 엔딩 ----------

func pick_ending(forced_id: String = "") -> Dictionary:
	if forced_id != "":
		return GameData.ending_by_id(forced_id)
	for e in GameData.endings:
		if check(e.when):
			return e
	return GameData.endings.back()


func ending_story(ending: Dictionary) -> String:
	var s: Dictionary = ending.story
	var text: String = s.get("prefix", "")
	if s.get("use_diffs", false):
		var d := diffs()
		text += (", ".join(d) + s.diffs_suffix) if not d.is_empty() else s.no_diffs
	else:
		var body: String = s.get("default", "")
		for v in s.get("variants", []):
			if check(v.when):
				body = v.text
				break
		text += body
	return text + s.get("suffix", "")


## "미지의 우주"에서 우리 우주와 다른 점 문구들.
func diffs() -> Array[String]:
	var out: Array[String] = []
	for d in GameData.ending_diffs:
		if check(d.when):
			out.append(d.text)
	if not out.is_empty() and out[-1].ends_with("고"):
		out[-1] = out[-1].left(-1) + "는"
	return out
