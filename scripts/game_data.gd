extends Node
## data/*.json 을 한 번 읽어 두는 전역 저장소 (오토로드 이름: GameData).
## 게임 내용(시대, 선택지, 사건, 엔딩, 학자 카드)은 모두 JSON 에 있고,
## 코드는 그걸 읽어서 돌리기만 한다.

const DATA_DIR := "res://data/"

var stages: Array = []
var events: Array = []
var endings: Array = []
var ending_diffs: Array = []
var gauges: Array = []
var seeds: Array = []
var sages: Dictionary = {}  # id -> {name, year, desc}
var rules: Dictionary = {}


func _ready() -> void:
	stages = _load("stages")
	events = _load("events")
	var e: Dictionary = _load("endings")
	endings = e.get("list", [])
	ending_diffs = e.get("diffs", [])
	gauges = _load("gauges")
	seeds = _load("seeds")
	rules = _load("rules")
	for s in _load("sages"):
		sages[s.id] = s


func _load(name: String) -> Variant:
	var path := DATA_DIR + name + ".json"
	var text := FileAccess.get_file_as_string(path)
	if text.is_empty():
		push_error("데이터 파일을 읽지 못했어요: " + path)
		return {}
	var data: Variant = JSON.parse_string(text)
	if data == null:
		push_error("JSON 형식이 잘못됐어요: " + path)
		return {}
	return data


func ending_by_id(id: String) -> Dictionary:
	for e in endings:
		if e.id == id:
			return e
	return {}


func event_by_id(id: String) -> Dictionary:
	for e in events:
		if e.id == id:
			return e
	return {}
