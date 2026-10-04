extends Node
## Music (with crossfades) and pooled sound effects.

const MUSIC := {
	"menu": "res://assets/audio/music/menu_i_became_a_zombie.ogg",
	"day": "res://assets/audio/music/day_stumble_around.ogg",
	"night": "res://assets/audio/music/night_monstervania.ogg",
	"night2": "res://assets/audio/music/night_sinister_abode.ogg",
	"gameover": "res://assets/audio/music/gameover_last_fight.ogg",
}

## Each sound name maps to one or more variations that are picked at random.
const SFX := {
	"swing": ["swing_1", "swing_2"],
	"chop": ["chop_1", "chop_2", "chop_3", "chop_4"],
	"mine": ["mine_1", "mine_2", "mine_3"],
	"hit": ["hit_1", "hit_2", "hit_3"],
	"build": ["build_1", "build_2", "build_3"],
	"barricade_hit": ["barricade_hit_1", "barricade_hit_2", "barricade_hit_3"],
	"step": ["step_1", "step_2", "step_3"],
	"spike": ["spike_1", "spike_2", "spike_3"],
	"pickup": ["pickup_1", "pickup_2"],
	"scrap": ["scrap"],
	"empty": ["empty"],
	"reload": ["reload"],
	"hurt": ["hurt_1", "hurt_2"],
	"eat": ["eat"],
	"search_house": ["search_house"],
	"search_crate": ["search_crate"],
	"break": ["break"],
	"click": ["click"],
	"error": ["error"],
	"bell": ["bell_night"],
	"day_start": ["day_start"],
	"highscore": ["highscore"],
	"shot": ["shot"],
	"turret_shot": ["turret_shot"],
	"groan": ["groan_16", "groan_17", "groan_18", "groan_19", "groan_20", "groan_21"],
	"zattack": ["zattack_3", "zattack_5", "zattack_6", "zattack_7", "zattack_10", "zattack_11"],
	"zdie": ["zdie_1", "zdie_8", "zdie_9", "zdie_12", "zdie_15"],
}

const POOL_SIZE := 16

var _streams := {}
var _pool: Array[AudioStreamPlayer] = []
var _pool_i := 0
var _music_a: AudioStreamPlayer
var _music_b: AudioStreamPlayer
var _current_music := ""
var _last_play := {}
var listener_pos := Vector2.ZERO

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	if AudioServer.get_bus_index("Music") == -1:
		AudioServer.add_bus()
		AudioServer.set_bus_name(AudioServer.bus_count - 1, "Music")
		AudioServer.set_bus_send(AudioServer.bus_count - 1, "Master")
		AudioServer.add_bus()
		AudioServer.set_bus_name(AudioServer.bus_count - 1, "SFX")
		AudioServer.set_bus_send(AudioServer.bus_count - 1, "Master")
	_music_a = _make_music_player()
	_music_b = _make_music_player()
	for i in POOL_SIZE:
		var p := AudioStreamPlayer.new()
		p.bus = "SFX"
		add_child(p)
		_pool.append(p)
	for key in SFX:
		var list: Array = []
		for file in SFX[key]:
			var s = load("res://assets/audio/sfx/%s.ogg" % file)
			if s:
				list.append(s)
		_streams[key] = list
	apply_mute()

func _make_music_player() -> AudioStreamPlayer:
	var p := AudioStreamPlayer.new()
	p.bus = "Music"
	p.volume_db = -80
	add_child(p)
	return p

func apply_mute() -> void:
	AudioServer.set_bus_mute(0, Save.muted)
	AudioServer.set_bus_volume_db(AudioServer.get_bus_index("Music"), linear_to_db(Save.music_volume * 0.7))

func toggle_mute() -> void:
	Save.muted = not Save.muted
	Save.write()
	apply_mute()

## Temporary mute used while an advertisement is playing.
func set_ad_mute(on: bool) -> void:
	AudioServer.set_bus_mute(0, on or Save.muted)

func play_music(key: String, fade := 1.2) -> void:
	if key == _current_music:
		return
	_current_music = key
	var old := _music_a
	var new := _music_b
	_music_a = new
	_music_b = old
	var tw := create_tween().set_parallel(true)
	tw.tween_property(old, "volume_db", -60.0, fade)
	tw.chain().tween_callback(old.stop)
	if key == "" or not MUSIC.has(key):
		return
	var stream = load(MUSIC[key])
	if stream is AudioStreamOggVorbis:
		stream.loop = key != "gameover"
	new.stream = stream
	new.volume_db = -40.0
	new.play()
	var tw2 := create_tween()
	tw2.tween_property(new, "volume_db", 0.0, fade)

## Plays a sound. Pass a world position to get distance attenuation.
func play(key: String, volume_db := 0.0, pitch_var := 0.1, world_pos = null) -> void:
	if not _streams.has(key) or _streams[key].is_empty():
		return
	var now := Time.get_ticks_msec()
	# Avoid machine-gunning the same sound in a single frame burst.
	if _last_play.get(key, -1000) > now - 40:
		return
	_last_play[key] = now
	var vol := volume_db
	if world_pos != null:
		var d: float = (world_pos as Vector2).distance_to(listener_pos)
		if d > 320.0:
			return
		vol += -18.0 * clamp(d / 320.0, 0.0, 1.0)
	var p := _pool[_pool_i]
	_pool_i = (_pool_i + 1) % POOL_SIZE
	p.stream = _streams[key].pick_random()
	p.volume_db = vol
	p.pitch_scale = 1.0 + randf_range(-pitch_var, pitch_var)
	p.play()
