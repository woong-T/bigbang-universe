extends Control
## 최소 코어 루프 화면.
## 타이틀 → 씨앗 고르기 → [시대 선택 → 선택 결과 → (돌발 사건 → 사건 결과)] × 12 → 엔딩
## 지금은 기능 확인용 기본 UI 이고, 그림·연출은 나중에 장면(scene)별로 갈아 끼운다.

const KEYS := "ABCDE"

var u: Universe
var _pending_stop: Dictionary = {}

@onready var _box: VBoxContainer = %Content
@onready var _scroll: ScrollContainer = %Scroll


func _ready() -> void:
	show_title()


# ---------- 화면들 ----------

func show_title() -> void:
	_clear()
	_heading("빅뱅 유니버스", 44)
	_text("한 점에서 시작해 138억 년 뒤까지, 선택 하나하나로 나만의 우주를 만들어 보세요.")
	_text("시대 %d개 · 돌발 사건 %d개 · 결말 %d가지" % [GameData.stages.size(), GameData.events.size(), GameData.endings.size()], 18, Color(1, 1, 1, 0.6))
	_button("우주 만들기 시작 →", func():
		u = Universe.new()
		show_seed())


func show_seed() -> void:
	_clear()
	_eyebrow("시작하기 전에")
	_heading("어떤 씨앗에서 시작할까요?")
	for i in GameData.seeds.size():
		var s: Dictionary = GameData.seeds[i]
		_choice(KEYS[i], s.name, s.desc, func():
			u.apply_seed(s)
			show_stage())


func show_stage() -> void:
	var x := u.stage_view()
	_clear()
	_eyebrow("%d / %d · %s" % [u.stage_index + 1, GameData.stages.size(), x.short])
	_heading(x.era)
	_text("시간 %s · 온도 %s" % [x.time, x.temperature], 18, Color(1, 0.85, 0.6))
	_text(x.desc)
	_text("[b]%s[/b]  %s" % [x.term.word, x.term.meaning], 18, Color(1, 1, 1, 0.7))
	for i in x.choices.size():
		var c: Dictionary = x.choices[i]
		_choice(KEYS[i], c.text, c.get("subtitle", ""), func(): _on_stage_choice(c))
	_gauges()


func _on_stage_choice(c: Dictionary) -> void:
	var x := u.current_stage()
	var r := u.apply_choice(c, x.short)
	_pending_stop = u.check_early_stop()
	_clear()
	_eyebrow("%s · 선택 결과" % x.era)
	_heading(c.text)
	_text(r.result)
	_changes(r.before)
	_stop_note()
	_sage(c, r.new_sage)
	_gauges()
	var label := "이 우주의 결말 보기 →" if not _pending_stop.is_empty() else ("138억 년 뒤로 →" if u.is_last_stage() else "다음으로 →")
	_button(label, _after_stage)


func _after_stage() -> void:
	if not _pending_stop.is_empty():
		return show_ending(_pending_stop.ending)
	if u.is_last_stage():
		return show_ending()
	if u.roll_vacuum_decay():
		return show_vacuum()
	var e := u.roll_event()
	if not e.is_empty():
		return show_event(e)
	_next_stage()


func _next_stage() -> void:
	u.advance()
	show_stage()


func show_event(e: Dictionary) -> void:
	_clear()
	_eyebrow("돌발 사건")
	_heading(e.title)
	_text(e.desc)
	for i in e.choices.size():
		var c: Dictionary = e.choices[i]
		_choice("🎲" if e.get("dice", false) else KEYS[i], c.text, "", func(): _on_event_choice(e, c))


func _on_event_choice(e: Dictionary, c: Dictionary) -> void:
	var r := u.apply_choice(c, "사건")
	u.path[-1].text = e.title.trim_suffix("!")
	_pending_stop = u.check_early_stop()
	_clear()
	_eyebrow("돌발 사건 · 결과")
	_heading("주사위 결과" if e.get("dice", false) else c.text)
	_text(r.result)
	_changes(r.before)
	_stop_note()
	_sage(c, r.new_sage)
	_button("이 우주의 결말 보기 →" if not _pending_stop.is_empty() else "다음 시대로 →", func():
		if not _pending_stop.is_empty():
			show_ending(_pending_stop.ending)
		else:
			_next_stage())


func show_vacuum() -> void:
	_clear()
	_eyebrow("돌발 사건")
	_heading("진공 붕괴!")
	_text(GameData.rules.vacuum_decay.text)
	_button("이 우주의 결말 보기 →", func(): show_ending("vacuum"))


func show_ending(forced_id: String = "") -> void:
	var e := u.pick_ending(forced_id)
	_clear()
	_eyebrow("이 우주의 결말" + ("" if e.fate == "" else " · " + e.fate))
	_heading(e.name, 40, Color.html(e.color))
	_text(u.ending_story(e))
	_heading("지나온 길", 22)
	var lines := ["[b]씨앗[/b]  " + u.seed_name]
	for p in u.path:
		lines.append("[b]%s[/b]  %s" % [p.era, p.text])
	_text("\n".join(lines), 18, Color(1, 1, 1, 0.75))
	if not u.sages.is_empty():
		_heading("이번 판의 학자 카드 %d장" % u.sages.size(), 22)
		_text("카드를 누르면 학자가 어떤 주장을 했는지 볼 수 있어요.", 16, Color(1, 1, 1, 0.6))
		for id in u.sages:
			_sage_card(id)
	_gauges()
	_button("다시 만들기 →", func():
		u = Universe.new()
		show_seed())
	_button("처음 화면으로", show_title)


# ---------- 작은 UI 조각들 ----------

func _clear() -> void:
	for c in _box.get_children():
		c.queue_free()
	_scroll.scroll_vertical = 0


func _eyebrow(t: String) -> void:
	_text(t, 16, Color(1, 0.85, 0.6, 0.8))


func _heading(t: String, size := 32, color := Color.WHITE) -> void:
	var l := Label.new()
	l.text = t
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	_box.add_child(l)


func _text(t: String, size := 20, color := Color(1, 1, 1, 0.92)) -> void:
	var l := RichTextLabel.new()
	l.bbcode_enabled = true
	l.fit_content = true
	l.scroll_active = false
	l.text = t
	l.add_theme_font_size_override("normal_font_size", size)
	l.add_theme_font_size_override("bold_font_size", size)
	l.add_theme_color_override("default_color", color)
	_box.add_child(l)


func _button(t: String, cb: Callable) -> void:
	var b := Button.new()
	b.text = t
	b.custom_minimum_size.y = 64
	b.add_theme_font_size_override("font_size", 22)
	b.pressed.connect(cb)
	_box.add_child(b)


func _choice(key: String, title: String, sub: String, cb: Callable) -> void:
	var b := Button.new()
	b.text = "%s   %s%s" % [key, title, ("\n      " + sub) if sub != "" else ""]
	b.alignment = HORIZONTAL_ALIGNMENT_LEFT
	b.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	b.custom_minimum_size.y = 72
	b.add_theme_font_size_override("font_size", 20)
	b.pressed.connect(cb)
	_box.add_child(b)


func _gauge_value(g: Dictionary, s: Dictionary) -> float:
	return clampf(s[g.key] + g.get("display_offset", 0), 0, 100)


func _gauges() -> void:
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 16)
	for g in GameData.gauges:
		var v := _gauge_value(g, u.state)
		var ok: bool = v >= g.good_min and v <= g.good_max
		var l := Label.new()
		l.text = g.name
		l.custom_minimum_size.x = 140
		l.add_theme_font_size_override("font_size", 16)
		grid.add_child(l)
		var bar := ProgressBar.new()
		bar.value = v
		bar.show_percentage = false
		bar.custom_minimum_size = Vector2(0, 14)
		bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		bar.modulate = Color(0.55, 0.95, 0.8) if ok else Color(1, 0.6, 0.45)
		grid.add_child(bar)
	_box.add_child(grid)


func _changes(before: Dictionary) -> void:
	var parts: Array[String] = []
	for g in GameData.gauges:
		var a := _gauge_value(g, before)
		var b := _gauge_value(g, u.state)
		var d := b - a
		if absf(d) < 1:
			continue
		var ch := "▲" if d > 0 else "▼"
		var n := 1 if absf(d) < 8 else (2 if absf(d) < 18 else 3)
		parts.append("%s %d → %d %s" % [g.name, roundi(a), roundi(b), ch.repeat(n)])
	_text("[b]우주가 이렇게 바뀌었어요[/b]\n" + ("\n".join(parts) if not parts.is_empty() else "눈에 띄는 변화는 없어요."), 18, Color(0.8, 0.9, 1))


func _stop_note() -> void:
	if not _pending_stop.is_empty():
		_text("[b]이 우주는 더 이어지지 않아요[/b]\n" + _pending_stop.text, 18, Color(1, 0.55, 0.55))


func _sage(c: Dictionary, is_new: bool) -> void:
	if not c.has("sage"):
		return
	_sage_card(c.sage, "새 학자 카드" if is_new else "학자 카드")


## 학자 카드 버튼. 누르면 아래에 그 학자가 어떤 주장을 했는지 펼쳐 보여 준다.
func _sage_card(id: String, label := "학자 카드") -> void:
	var s: Dictionary = GameData.sages.get(id, {})
	if s.is_empty():
		return
	var b := Button.new()
	b.text = "%s · %s (%s)\n%s\n눌러서 어떤 주장인지 보기 ▼" % [label, s.name, s.year, s.desc]
	b.alignment = HORIZONTAL_ALIGNMENT_LEFT
	b.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	b.custom_minimum_size.y = 72
	b.add_theme_font_size_override("font_size", 18)
	b.add_theme_color_override("font_color", Color(0.85, 0.8, 1))
	_box.add_child(b)
	_text("[b]이런 주장을 했어요[/b]\n%s\n\n%s\n\n[b]지금은?[/b] %s" % [s.get("claim", ""), s.get("theory", ""), s.get("verdict", "")], 18, Color(0.92, 0.9, 1))
	var detail: Control = _box.get_child(_box.get_child_count() - 1)
	detail.visible = false
	b.pressed.connect(func():
		detail.visible = not detail.visible
		b.text = b.text.trim_suffix("▼" if detail.visible else "▲") + ("▲" if detail.visible else "▼"))
