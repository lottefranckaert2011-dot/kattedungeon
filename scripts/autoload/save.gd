extends Node
## Persistent data: highscore, best night and settings.

const PATH := "user://zombie_dorp.cfg"

var best_score: int = 0
var best_night: int = 0
var best_area: int = 1
var muted: bool = false
var music_volume: float = 0.8
var tutorial_done: bool = false

func _ready() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(PATH) == OK:
		best_score = cfg.get_value("score", "best", 0)
		best_night = cfg.get_value("score", "night", 0)
		best_area = cfg.get_value("score", "area", 1)
		muted = cfg.get_value("settings", "muted", false)
		music_volume = cfg.get_value("settings", "music", 0.8)
		tutorial_done = cfg.get_value("settings", "tutorial", false)

func write() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("score", "best", best_score)
	cfg.set_value("score", "night", best_night)
	cfg.set_value("score", "area", best_area)
	cfg.set_value("settings", "muted", muted)
	cfg.set_value("settings", "music", music_volume)
	cfg.set_value("settings", "tutorial", tutorial_done)
	cfg.save(PATH)

## Returns true when this is a new highscore.
func submit(score: int, night: int) -> bool:
	var is_new := score > best_score
	best_score = max(best_score, score)
	best_night = max(best_night, night)
	write()
	return is_new


# ---------------------------------------------------------------- the current run
# Saved every morning and after driving to a new area. Deleted when you die.

const RUN_PATH := "user://zombie_dorp_run.json"

func has_run() -> bool:
	return FileAccess.file_exists(RUN_PATH)

func save_run(data: Dictionary) -> void:
	var f := FileAccess.open(RUN_PATH, FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify(data))

func load_run() -> Dictionary:
	if not has_run():
		return {}
	var f := FileAccess.open(RUN_PATH, FileAccess.READ)
	if f == null:
		return {}
	var d = JSON.parse_string(f.get_as_text())
	return d if d is Dictionary else {}

func clear_run() -> void:
	if has_run():
		DirAccess.remove_absolute(RUN_PATH)
