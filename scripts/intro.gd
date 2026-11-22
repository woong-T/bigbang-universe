extends Control
## 게임을 켜면 가장 먼저 나오는 인트로.
## 어둠 → 작은 한 점(특이점) → 점이 뜨거워지며 떨림 → 빅뱅(번쩍 + 충격파 + 불꽃) → 식어 가는 우주와 별 → 제목
## 그림 파일 없이 모두 코드로 그린다(_draw). 장면 길이와 문장은 아래 상수만 고치면 된다.
##
## 건너뛰기: 오른쪽 위 버튼, 또는 Esc / 스페이스 / 엔터.
## 끝나면 "화면을 눌러 시작하기"가 나오고, 누르면 메인 화면(타이틀)으로 넘어간다.

signal finished

## 끝난 뒤 넘어갈 장면. 테스트에서는 auto_change_scene 을 꺼서 장면을 바꾸지 않는다.
@export var next_scene := "res://scenes/main.tscn"
@export var auto_change_scene := true

const T_POINT := 3.0      # 한 점이 나타나는 때
const T_HEAT := 7.0       # 점이 뜨거워지며 떨리기 시작
const T_BANG := 10.5      # 빅뱅
const T_STARS := 14.0     # 별이 보이기 시작
const T_TITLE := 16.5     # 제목
const T_END := 19.5       # "눌러서 시작" 안내

## [시작, 끝, 문장]
const NARRATION := [
	[0.6, 3.4, "아무것도 없었어요.\n시간도, 공간도."],
	[3.8, 7.0, "그런데 아주 작은 한 점이 있었어요."],
	[7.3, 10.2, "상상할 수 없이 뜨겁고,\n빽빽하게 꽉 찬 점."],
	[11.6, 15.6, "138억 년 전,\n그 점이 터지며 우주가 태어났어요."],
]

## 빅뱅 직후 우주가 식어 가는 색: 하양 → 노랑 → 주황 → 보라 → 깊은 남색
const COOL_COLORS := [
	Color(1.0, 1.0, 1.0),
	Color(1.0, 0.86, 0.45),
	Color(1.0, 0.5, 0.2),
	Color(0.45, 0.18, 0.45),
	Color(0.043, 0.031, 0.086),
]
const SPARK_COLORS := [
	Color(1, 1, 1), Color(1, 0.92, 0.6), Color(1, 0.65, 0.3), Color(0.6, 0.85, 1), Color(1, 0.5, 0.7),
]

var t := 0.0
var _ending := false
var _rng := RandomNumberGenerator.new()
var _sparks: Array[Dictionary] = []    # 빅뱅 불꽃
var _inflow: Array[Dictionary] = []    # 빅뱅 전에 점으로 빨려 드는 빛
var _stars: Array[Dictionary] = []     # 식은 뒤 보이는 별
var _banged := false

var _narration: Label
var _title: Label
var _subtitle: Label
var _prompt: Label
var _skip: Button
var _fade: ColorRect


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	_rng.randomize()
	_build_ui()
	for i in 220:
		_stars.append({
			"dir": Vector2.from_angle(_rng.randf() * TAU),
			"r": pow(_rng.randf(), 0.6),   # 0~1, 화면 크기에 맞춰 늘림
			"size": _rng.randf_range(0.8, 2.4),
			"phase": _rng.randf() * TAU,
			"tint": [Color(1, 1, 1), Color(0.75, 0.85, 1), Color(1, 0.9, 0.75)][_rng.randi() % 3],
		})


func _build_ui() -> void:
	_narration = _make_label(30, Color(1, 1, 1))
	_narration.anchor_top = 0.62
	_narration.anchor_bottom = 0.82

	_title = _make_label(64, Color(1, 0.93, 0.8))
	_title.text = "빅뱅 유니버스"
	_title.anchor_top = 0.30
	_title.anchor_bottom = 0.42

	_subtitle = _make_label(24, Color(1, 1, 1, 0.75))
	_subtitle.text = "이제, 그 우주를 당신이 만들어요."
	_subtitle.anchor_top = 0.42
	_subtitle.anchor_bottom = 0.48

	_prompt = _make_label(22, Color(1, 0.85, 0.6))
	_prompt.text = "화면을 눌러 시작하기"
	_prompt.anchor_top = 0.80
	_prompt.anchor_bottom = 0.86

	_skip = Button.new()
	_skip.text = "건너뛰기 ▶▶"
	_skip.flat = true
	_skip.focus_mode = Control.FOCUS_NONE
	_skip.add_theme_font_size_override("font_size", 20)
	_skip.add_theme_color_override("font_color", Color(1, 1, 1, 0.55))
	_skip.add_theme_color_override("font_hover_color", Color(1, 1, 1, 0.9))
	_skip.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	_skip.offset_left = -190
	_skip.offset_top = 24
	_skip.offset_right = -20
	_skip.offset_bottom = 72
	_skip.pressed.connect(skip)
	add_child(_skip)

	_fade = ColorRect.new()
	_fade.color = Color(0, 0, 0, 0)
	_fade.set_anchors_preset(Control.PRESET_FULL_RECT)
	_fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_fade)


func _make_label(font_size: int, color: Color) -> Label:
	var l := Label.new()
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.anchor_left = 0.0
	l.anchor_right = 1.0
	l.offset_left = 32
	l.offset_right = -32
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	l.add_theme_font_size_override("font_size", font_size)
	l.add_theme_color_override("font_color", color)
	l.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.6))
	l.add_theme_constant_override("shadow_offset_y", 2)
	l.modulate.a = 0.0
	add_child(l)
	return l


# ---------- 흐름 ----------

func _process(delta: float) -> void:
	advance(delta)


## 시간을 delta 초만큼 앞으로 보낸다. 테스트에서 직접 불러 빨리 감기 할 수 있다.
func advance(delta: float) -> void:
	t += delta
	if not _banged and t >= T_BANG:
		_bang()
	if t > T_POINT and t < T_BANG:
		_spawn_inflow(delta)
	_update_particles(delta)
	_update_labels()
	queue_redraw()


func is_waiting_for_tap() -> bool:
	return t >= T_END and not _ending


## 건너뛰기 버튼이나 키로 바로 메인 화면으로.
func skip() -> void:
	_finish()


func _gui_input(event: InputEvent) -> void:
	var tapped: bool = (event is InputEventMouseButton and event.pressed) or (event is InputEventScreenTouch and event.pressed)
	if tapped and is_waiting_for_tap():
		accept_event()
		_finish()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel") or event.is_action_pressed("ui_accept"):
		get_viewport().set_input_as_handled()
		_finish()


func _finish() -> void:
	if _ending:
		return
	_ending = true
	_skip.disabled = true
	var tw := create_tween()
	tw.tween_property(_fade, "color:a", 1.0, 0.6)
	tw.tween_callback(func():
		finished.emit()
		if auto_change_scene and is_inside_tree():
			get_tree().change_scene_to_file(next_scene))


# ---------- 입자 ----------

func _bang() -> void:
	_banged = true
	_inflow.clear()
	for i in 520:
		var speed := _rng.randf_range(80, 1100) * (1.0 if _rng.randf() < 0.8 else 1.6)
		_sparks.append({
			"pos": Vector2.ZERO,
			"vel": Vector2.from_angle(_rng.randf() * TAU) * speed,
			"life": _rng.randf_range(1.6, 4.0),
			"age": 0.0,
			"size": _rng.randf_range(1.5, 4.5),
			"color": SPARK_COLORS[_rng.randi() % SPARK_COLORS.size()],
		})


func _spawn_inflow(delta: float) -> void:
	var heat := clampf((t - T_POINT) / (T_BANG - T_POINT), 0.0, 1.0)
	var count := int(heat * heat * 90.0 * delta + _rng.randf())
	var reach := maxf(size.x, size.y) * 0.6
	for i in count:
		var dir := Vector2.from_angle(_rng.randf() * TAU)
		_inflow.append({
			"pos": dir * _rng.randf_range(reach * 0.5, reach),
			"speed": _rng.randf_range(120, 260) * (1.0 + heat * 2.0),
		})


func _update_particles(delta: float) -> void:
	for p in _sparks:
		p.age += delta
		p.pos += p.vel * delta
		p.vel *= pow(0.35, delta)   # 점점 느려짐(우주가 팽창하며 식는 느낌)
	_sparks = _sparks.filter(func(p): return p.age < p.life)

	for p in _inflow:
		var d: float = p.pos.length()
		var step: float = minf(p.speed * delta, d)
		p.pos -= p.pos.normalized() * step if d > 0.0 else Vector2.ZERO
	_inflow = _inflow.filter(func(p): return p.pos.length() > 6.0)


# ---------- 글자 ----------

func _update_labels() -> void:
	var line := ""
	var a := 0.0
	for n in NARRATION:
		if t >= n[0] and t <= n[1]:
			line = n[2]
			a = minf(_ramp(t, n[0], 0.7), 1.0 - _ramp(t, n[1] - 0.7, 0.7))
	if line != "":
		_narration.text = line
	_narration.modulate.a = a

	_title.modulate.a = _ramp(t, T_TITLE, 1.5)
	_subtitle.modulate.a = _ramp(t, T_TITLE + 1.2, 1.2)
	_prompt.modulate.a = 0.0 if t < T_END else 0.45 + 0.45 * sin((t - T_END) * 3.0)
	_skip.visible = t < T_END and not _ending


## from 부터 length 초 동안 0 → 1
static func _ramp(x: float, from: float, length: float) -> float:
	return clampf((x - from) / length, 0.0, 1.0)


# ---------- 그리기 ----------

func _draw() -> void:
	var center := size * Vector2(0.5, 0.42)
	var shake := _shake_amount()
	var offset := Vector2(_rng.randf_range(-1, 1), _rng.randf_range(-1, 1)) * shake

	draw_rect(Rect2(Vector2.ZERO, size), _background_color())
	draw_set_transform(center + offset)

	if _banged:
		_draw_stars()
		_draw_fireball()
		_draw_shockwave()
		for p in _sparks:
			var k: float = p.age / p.life
			var c: Color = p.color
			c.a = (1.0 - k) * (1.0 - k)
			draw_circle(p.pos, p.size * (1.0 - 0.5 * k), c)
	else:
		for p in _inflow:
			var c := Color(1, 0.9, 0.7, clampf(1.0 - p.pos.length() / 500.0, 0.0, 1.0) * 0.8)
			draw_line(p.pos, p.pos * 0.94, c, 2.0)
		_draw_singularity()

	draw_set_transform(Vector2.ZERO)

	# 빅뱅 순간 화면 전체가 번쩍
	if _banged:
		var flash := exp(-(t - T_BANG) * 2.2)
		draw_rect(Rect2(Vector2.ZERO, size), Color(1, 1, 1, clampf(flash, 0.0, 1.0)))


func _shake_amount() -> float:
	if t > T_HEAT and t < T_BANG:
		return pow((t - T_HEAT) / (T_BANG - T_HEAT), 2.0) * 10.0
	if t >= T_BANG:
		return 26.0 * exp(-(t - T_BANG) * 2.5)
	return 0.0


func _background_color() -> Color:
	if not _banged:
		return Color(0, 0, 0)
	var e := t - T_BANG
	var k := clampf(e / 4.5, 0.0, 1.0) * (COOL_COLORS.size() - 1)
	var i := mini(int(k), COOL_COLORS.size() - 2)
	var c: Color = COOL_COLORS[i].lerp(COOL_COLORS[i + 1], k - i)
	# 빛이 퍼진 뒤에는 배경이 어두워져 별이 잘 보이게
	return c.darkened(0.7 * _ramp(e, 0.3, 2.5))


## 작게 맥동하는 한 점. 시간이 지날수록 밝고 커진다.
func _draw_singularity() -> void:
	if t < T_POINT:
		return
	var appear := _ramp(t, T_POINT, 1.5)
	var heat := _ramp(t, T_HEAT, T_BANG - T_HEAT)
	var pulse := 1.0 + (0.15 + heat * 0.35) * sin(t * (4.0 + heat * 22.0))
	var core := (2.0 + heat * 6.0) * pulse
	var glow := Color(1, 0.75 + 0.25 * heat, 0.5 + 0.5 * heat)
	for i in range(16, 0, -1):
		var r := core * (1.0 + i * (0.6 + heat * 0.9))
		var c := glow
		c.a = appear * 0.035 * (1.0 + heat)
		draw_circle(Vector2.ZERO, r, c)
	draw_circle(Vector2.ZERO, core, Color(1, 1, 1, appear))


## 빅뱅 중심의 뜨거운 불덩이. 퍼지면서 식어 사라진다.
func _draw_fireball() -> void:
	var e := t - T_BANG
	var fade := exp(-e * 0.7)
	if fade < 0.01:
		return
	var radius := 60.0 + e * 260.0
	var c: Color = COOL_COLORS[1].lerp(COOL_COLORS[2], clampf(e / 2.5, 0.0, 1.0))
	for i in range(10, 0, -1):
		var cc := c
		cc.a = fade * 0.06
		draw_circle(Vector2.ZERO, radius * i / 10.0, cc)


func _draw_shockwave() -> void:
	var e := t - T_BANG
	var maxr := size.length()
	for k in 2:
		var ee := e - k * 0.25
		if ee <= 0.0:
			continue
		var r := ee * 900.0 * (1.0 - 0.25 * k)
		if r > maxr:
			continue
		var a := clampf(1.0 - r / maxr, 0.0, 1.0) * (0.9 - 0.4 * k)
		draw_arc(Vector2.ZERO, r, 0.0, TAU, 96, Color(1, 0.95, 0.85, a), 10.0 - k * 4.0, true)


## 식어 가는 우주에 하나둘 보이는 별. 아주 천천히 바깥으로 퍼진다(팽창).
func _draw_stars() -> void:
	var appear := _ramp(t, T_STARS - 1.5, 3.0)
	if appear <= 0.0:
		return
	var spread := size.length() * 0.6 * (1.0 + (t - T_STARS) * 0.012)
	for s in _stars:
		var twinkle := 0.6 + 0.4 * sin(t * 2.0 + s.phase)
		var c: Color = s.tint
		c.a = appear * twinkle
		draw_circle(s.dir * s.r * spread, s.size, c)
