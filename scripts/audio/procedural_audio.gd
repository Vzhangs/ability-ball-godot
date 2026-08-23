class_name ProceduralBattleAudio
extends Node

const SAMPLE_RATE := 44100.0
const MAX_VOICES := 14
const GENERATOR_BUFFER_LENGTH := 0.05
const AUDIO_PROCESS_PRIORITY := 100
const OUTPUT_GAIN_DB := 15.0
const PROCEDURAL_BASE_VOLUME_DB := -7.0
const DIRECT_EVENT_POLYPHONY := 4
const DIRECT_EVENT_KINDS := [
	&"wall_impact",
	&"fighter_death",
	&"web_attach",
	&"web_trigger",
	&"sniper_aim",
	&"sniper_fire",
	&"sniper_pierce",
	&"sniper_hit",
	&"sniper_wall_split",
]

var _player: AudioStreamPlayer
var _playback: AudioStreamGeneratorPlayback
var _voices: Array[Dictionary] = []
var _noise := RandomNumberGenerator.new()
var _sample_streams: Dictionary = {}
var _sample_gain_db: Dictionary = {}
var _sample_looped: Dictionary = {}
var _sample_players: Dictionary = {}
var _direct_streams: Dictionary = {}
var _direct_players: Dictionary = {}
var _looped_samples_paused := false

func configure_samples(samples: Dictionary) -> void:
	stop_all_looped_sample_events()
	_sample_streams.clear()
	_sample_gain_db.clear()
	_sample_looped.clear()
	for event_kind in samples:
		var sample_spec = samples[event_kind]
		if sample_spec is Dictionary:
			var stream = sample_spec.get("stream")
			var gain_db = sample_spec.get("gain_db")
			var looped = sample_spec.get("loop", false)
			if (
				not stream is AudioStream
				or not (gain_db is int or gain_db is float)
				or not looped is bool
			):
				continue
			_sample_streams[String(event_kind)] = stream
			_sample_gain_db[String(event_kind)] = float(gain_db)
			_sample_looped[String(event_kind)] = bool(looped)

func _ready() -> void:
	process_priority = AUDIO_PROCESS_PRIORITY
	if DisplayServer.get_name() == "headless":
		set_process(false)
		return
	_noise.seed = 20260815
	for event_kind: StringName in DIRECT_EVENT_KINDS:
		var direct_stream := _render_profile_stream(event_profile(String(event_kind), 1.0))
		_direct_streams[event_kind] = direct_stream
		_ensure_direct_player(event_kind, direct_stream)
	var generator := AudioStreamGenerator.new()
	generator.mix_rate = SAMPLE_RATE
	generator.buffer_length = GENERATOR_BUFFER_LENGTH
	_player = AudioStreamPlayer.new()
	_player.stream = generator
	_player.volume_db = output_volume_db(PROCEDURAL_BASE_VOLUME_DB)
	add_child(_player)
	_player.play()
	_playback = _player.get_stream_playback() as AudioStreamGeneratorPlayback
	set_process(true)

func _exit_tree() -> void:
	shutdown()

func shutdown() -> void:
	set_process(false)
	_voices.clear()
	for player in _direct_players.values():
		if player is AudioStreamPlayer:
			player.stop()
	_direct_players.clear()
	_direct_streams.clear()
	for player in _sample_players.values():
		if player is AudioStreamPlayer:
			player.stop()
	_sample_players.clear()
	_sample_looped.clear()
	_looped_samples_paused = false
	_playback = null
	if _player != null:
		_player.stop()
		_player.stream = null

func play_event(kind: String, strength: float = 1.0) -> void:
	if _sample_streams.has(kind):
		if sample_event_loops(kind) and strength <= 0.0:
			stop_sample_event(kind)
			return
		_play_sample_event(kind, strength)
		return
	if uses_direct_playback(kind):
		_play_direct_event(kind, strength)
		return
	var voice := event_profile(kind, strength)
	if voice.is_empty():
		return
	_voices.append(voice)
	while _voices.size() > MAX_VOICES:
		_voices.pop_front()

func event_profile(kind: String, strength: float = 1.0) -> Dictionary:
	var voice := {
		"age": 0.0,
		"duration": 0.13,
		"frequency": 180.0,
		"frequency_end": 72.0,
		"phase": 0.0,
		"strength": clampf(strength, 0.0, 1.0),
		"wave": "sine",
		"noise": 0.0,
		"attack": 0.0,
		"transient": 0.0,
		"transient_duration": 0.012,
	}
	match kind:
		"impact":
			voice["duration"] = 0.16
			voice["frequency"] = 145.0
			voice["frequency_end"] = 58.0
			voice["noise"] = 0.2
		"body_impact":
			voice["duration"] = 0.14
			voice["frequency"] = 230.0
			voice["frequency_end"] = 72.0
			voice["phase"] = PI * 0.5
			voice["wave"] = "triangle"
			voice["noise"] = 0.12
			voice["attack"] = 0.001
			voice["transient"] = 0.52
			voice["transient_duration"] = 0.009
		"wall_impact":
			voice["duration"] = 0.14
			voice["frequency"] = 112.0
			voice["frequency_end"] = 48.0
			voice["phase"] = PI * 0.5
			voice["wave"] = "sine"
			voice["noise"] = 0.08
			voice["attack"] = 0.0004
			voice["transient"] = 0.08
			voice["transient_duration"] = 0.009
		"volley":
			voice["duration"] = 0.13
			voice["frequency"] = 235.0
			voice["frequency_end"] = 82.0
			voice["wave"] = "square"
			voice["noise"] = 0.16
		"projectile_hit":
			voice["duration"] = 0.085
			voice["frequency"] = 760.0
			voice["frequency_end"] = 225.0
			voice["wave"] = "triangle"
			voice["noise"] = 0.24
			voice["attack"] = 0.0008
			voice["transient"] = 0.22
			voice["transient_duration"] = 0.006
		"split":
			voice["duration"] = 0.24
			voice["frequency"] = 255.0
			voice["frequency_end"] = 710.0
			voice["wave"] = "triangle"
			voice["noise"] = 0.035
		"clone_impact":
			voice["duration"] = 0.085
			voice["frequency"] = 360.0
			voice["frequency_end"] = 130.0
			voice["phase"] = PI * 0.5
			voice["wave"] = "triangle"
			voice["noise"] = 0.12
			voice["attack"] = 0.001
			voice["transient"] = 0.3
			voice["transient_duration"] = 0.007
		"ram_impact":
			voice["duration"] = 0.15
			voice["frequency"] = 205.0
			voice["frequency_end"] = 60.0
			voice["wave"] = "saw"
			voice["noise"] = 0.16
			voice["attack"] = 0.001
			voice["transient"] = 0.45
			voice["transient_duration"] = 0.01
		"judgment":
			voice["duration"] = 0.28
			voice["frequency"] = 880.0
			voice["frequency_end"] = 420.0
			voice["wave"] = "square"
			voice["noise"] = 0.04
		"track":
			voice["duration"] = 0.09
			voice["frequency"] = 96.0
			voice["frequency_end"] = 70.0
			voice["wave"] = "triangle"
			voice["noise"] = 0.13
		"blood":
			voice["duration"] = 0.34
			voice["frequency"] = 310.0
			voice["frequency_end"] = 82.0
			voice["wave"] = "saw"
			voice["noise"] = 0.09
		"blade_slash":
			voice["duration"] = 0.17
			voice["frequency"] = 1860.0
			voice["frequency_end"] = 410.0
			voice["wave"] = "saw"
			voice["noise"] = 0.075
			voice["attack"] = 0.0006
			voice["transient"] = 0.34
			voice["transient_duration"] = 0.005
		"wind_cast":
			voice["duration"] = 0.38
			voice["frequency"] = 540.0
			voice["frequency_end"] = 1320.0
			voice["wave"] = "triangle"
			voice["noise"] = 0.14
			voice["attack"] = 0.012
			voice["transient"] = 0.16
			voice["transient_duration"] = 0.016
		"wind_absorb":
			voice["duration"] = 0.12
			voice["frequency"] = 1480.0
			voice["frequency_end"] = 245.0
			voice["wave"] = "square"
			voice["noise"] = 0.21
			voice["attack"] = 0.0008
			voice["transient"] = 0.28
			voice["transient_duration"] = 0.006
		"psychic_pulse":
			voice["duration"] = 0.44
			voice["frequency"] = 285.0
			voice["frequency_end"] = 1380.0
			voice["wave"] = "triangle"
			voice["noise"] = 0.065
			voice["attack"] = 0.01
			voice["transient"] = 0.12
			voice["transient_duration"] = 0.018
		"web_attach":
			voice["duration"] = 0.24
			voice["frequency"] = 420.0
			voice["frequency_end"] = 1160.0
			voice["wave"] = "triangle"
			voice["noise"] = 0.055
			voice["attack"] = 0.0005
			voice["transient"] = 0.36
			voice["transient_duration"] = 0.009
		"web_trigger":
			voice["duration"] = 0.19
			voice["frequency"] = 1350.0
			voice["frequency_end"] = 190.0
			voice["wave"] = "triangle"
			voice["noise"] = 0.18
			voice["attack"] = 0.0004
			voice["transient"] = 0.48
			voice["transient_duration"] = 0.008
		"sniper_aim":
			voice["duration"] = 0.46
			voice["frequency"] = 430.0
			voice["frequency_end"] = 1380.0
			voice["wave"] = "triangle"
			voice["noise"] = 0.035
			voice["attack"] = 0.004
			voice["transient"] = 0.12
			voice["transient_duration"] = 0.012
		"sniper_fire":
			voice["duration"] = 0.24
			voice["frequency"] = 168.0
			voice["frequency_end"] = 42.0
			voice["wave"] = "saw"
			voice["noise"] = 0.34
			voice["attack"] = 0.0003
			voice["transient"] = 0.94
			voice["transient_duration"] = 0.006
		"sniper_pierce":
			voice["duration"] = 0.11
			voice["frequency"] = 1280.0
			voice["frequency_end"] = 260.0
			voice["wave"] = "triangle"
			voice["noise"] = 0.19
			voice["attack"] = 0.0004
			voice["transient"] = 0.48
			voice["transient_duration"] = 0.005
		"sniper_hit":
			voice["duration"] = 0.30
			voice["frequency"] = 315.0
			voice["frequency_end"] = 54.0
			voice["wave"] = "square"
			voice["noise"] = 0.27
			voice["attack"] = 0.0004
			voice["transient"] = 0.82
			voice["transient_duration"] = 0.009
		"sniper_wall_split":
			voice["duration"] = 0.25
			voice["frequency"] = 390.0
			voice["frequency_end"] = 1560.0
			voice["wave"] = "triangle"
			voice["noise"] = 0.16
			voice["attack"] = 0.0005
			voice["transient"] = 0.62
			voice["transient_duration"] = 0.007
		"fighter_death":
			voice["duration"] = 0.62
			voice["frequency"] = 138.0
			voice["frequency_end"] = 31.0
			voice["phase"] = PI * 0.5
			voice["wave"] = "triangle"
			voice["noise"] = 0.28
			voice["attack"] = 0.0004
			voice["transient"] = 0.86
			voice["transient_duration"] = 0.028
		_:
			return {}
	return voice

func supports_event(kind: String) -> bool:
	return _sample_streams.has(kind) or kind in [
		"impact",
		"body_impact",
		"wall_impact",
		"volley",
		"projectile_hit",
		"split",
		"clone_impact",
		"ram_impact",
		"judgment",
		"track",
		"blood",
		"blade_slash",
		"wind_cast",
		"wind_absorb",
		"psychic_pulse",
		"web_attach",
		"web_trigger",
		"sniper_aim",
		"sniper_fire",
		"sniper_pierce",
		"sniper_hit",
		"sniper_wall_split",
		"fighter_death",
	]

func has_sample_event(kind: String) -> bool:
	return _sample_streams.has(kind)

func uses_direct_playback(kind: String) -> bool:
	return StringName(kind) in DIRECT_EVENT_KINDS

func sample_event_duration(kind: String) -> float:
	var stream = _sample_streams.get(kind)
	return stream.get_length() if stream is AudioStream else 0.0

func sample_event_gain_db(kind: String) -> float:
	return float(_sample_gain_db.get(kind, 0.0))

func sample_event_loops(kind: String) -> bool:
	return bool(_sample_looped.get(kind, false))

func sample_output_volume_db(kind: String, strength: float) -> float:
	return output_volume_db(
		linear_to_db(lerpf(0.72, 1.0, clampf(strength, 0.0, 1.0)))
	) + sample_event_gain_db(kind)

func _play_sample_event(kind: String, strength: float) -> void:
	if DisplayServer.get_name() == "headless" or not is_inside_tree():
		return
	var looped := sample_event_loops(kind)
	var player := _sample_players.get(kind) as AudioStreamPlayer
	if player == null:
		player = AudioStreamPlayer.new()
		player.stream = _sample_playback_stream(kind)
		player.max_polyphony = 1 if looped else 4
		add_child(player)
		_sample_players[kind] = player
	player.volume_db = sample_output_volume_db(kind, strength)
	if looped and player.playing:
		player.stream_paused = _looped_samples_paused
		return
	player.play()
	if looped:
		player.stream_paused = _looped_samples_paused

func stop_sample_event(kind: String) -> void:
	if not sample_event_loops(kind):
		return
	var player := _sample_players.get(kind) as AudioStreamPlayer
	if player == null:
		return
	player.stream_paused = false
	player.stop()

func stop_all_looped_sample_events() -> void:
	for kind in _sample_looped:
		if bool(_sample_looped[kind]):
			stop_sample_event(String(kind))
	_looped_samples_paused = false

func set_looped_sample_events_paused(value: bool) -> void:
	_looped_samples_paused = value
	for kind in _sample_looped:
		if not bool(_sample_looped[kind]):
			continue
		var player := _sample_players.get(kind) as AudioStreamPlayer
		if player != null and (player.playing or player.stream_paused):
			player.stream_paused = value

func _sample_playback_stream(kind: String) -> AudioStream:
	var source := _sample_streams[kind] as AudioStream
	if not sample_event_loops(kind):
		return source
	var playback_stream := source.duplicate() as AudioStream
	if _has_property(playback_stream, &"loop"):
		playback_stream.set("loop", true)
	elif _has_property(playback_stream, &"loop_mode"):
		playback_stream.set("loop_mode", 1)
	return playback_stream

func _has_property(object: Object, property_name: StringName) -> bool:
	for property in object.get_property_list():
		if StringName(property["name"]) == property_name:
			return true
	return false

func _play_direct_event(kind: String, strength: float) -> void:
	if DisplayServer.get_name() == "headless" or not is_inside_tree():
		return
	var event_key := StringName(kind)
	var stream = _direct_streams.get(event_key)
	if not stream is AudioStreamWAV:
		stream = _render_profile_stream(event_profile(kind, 1.0))
		_direct_streams[event_key] = stream
	var player := _ensure_direct_player(event_key, stream)
	player.volume_db = output_volume_db(PROCEDURAL_BASE_VOLUME_DB) + linear_to_db(
		maxf(0.0001, clampf(strength, 0.0, 1.0))
	)
	player.play()

func _ensure_direct_player(event_key: StringName, stream: AudioStreamWAV) -> AudioStreamPlayer:
	var player := _direct_players.get(event_key) as AudioStreamPlayer
	if player == null:
		player = AudioStreamPlayer.new()
		player.stream = stream
		player.max_polyphony = DIRECT_EVENT_POLYPHONY
		add_child(player)
		_direct_players[event_key] = player
	return player

func _render_profile_stream(profile: Dictionary) -> AudioStreamWAV:
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = int(SAMPLE_RATE)
	stream.stereo = true
	if profile.is_empty():
		return stream
	var duration := float(profile["duration"])
	var frame_count := maxi(1, ceili(duration * SAMPLE_RATE))
	var pcm := PackedByteArray()
	pcm.resize(frame_count * 4)
	var phase := float(profile["phase"])
	var direct_noise := RandomNumberGenerator.new()
	direct_noise.seed = 20260818
	for frame in range(frame_count):
		var age := float(frame) / SAMPLE_RATE
		var progress := age / duration
		var frequency := lerpf(float(profile["frequency"]), float(profile["frequency_end"]), progress)
		var wave := _wave_value(String(profile["wave"]), phase)
		var attack_duration := float(profile["attack"])
		var envelope := sin(progress * PI) * exp(-progress * 2.25)
		if attack_duration > 0.0:
			envelope = minf(1.0, age / attack_duration) * exp(-progress * 3.4)
		wave = lerpf(wave, direct_noise.randf_range(-1.0, 1.0), float(profile["noise"]))
		var transient_envelope := exp(
			-age / maxf(1.0 / SAMPLE_RATE, float(profile["transient_duration"]))
		)
		var transient := (
			direct_noise.randf_range(-1.0, 1.0)
			* float(profile["transient"])
			* transient_envelope
		)
		var mixed := tanh((wave * envelope + transient) * 0.48)
		var sample := roundi(clampf(mixed, -1.0, 1.0) * 32767.0)
		pcm.encode_s16(frame * 4, sample)
		pcm.encode_s16(frame * 4 + 2, sample)
		phase = fmod(phase + TAU * frequency / SAMPLE_RATE, TAU)
	stream.data = pcm
	return stream

static func output_volume_db(base_volume_db: float) -> float:
	return base_volume_db + OUTPUT_GAIN_DB

func _process(_delta: float) -> void:
	if _playback == null:
		return
	var frames := _playback.get_frames_available()
	for _frame in range(frames):
		var mixed := 0.0
		for index in range(_voices.size() - 1, -1, -1):
			var voice := _voices[index]
			var age: float = voice["age"]
			var duration: float = voice["duration"]
			if age >= duration:
				_voices.remove_at(index)
				continue
			var progress := age / duration
			var frequency := lerpf(float(voice["frequency"]), float(voice["frequency_end"]), progress)
			var phase: float = voice["phase"]
			var wave := _wave_value(String(voice["wave"]), phase)
			var attack_duration: float = voice["attack"]
			var envelope := sin(progress * PI) * exp(-progress * 2.25)
			if attack_duration > 0.0:
				var attack_gain := minf(1.0, age / attack_duration)
				envelope = attack_gain * exp(-progress * 3.4)
			var noise_amount: float = voice["noise"]
			wave = lerpf(wave, _noise.randf_range(-1.0, 1.0), noise_amount)
			var transient_duration: float = voice["transient_duration"]
			var transient_envelope := exp(-age / maxf(1.0 / SAMPLE_RATE, transient_duration))
			var transient := _noise.randf_range(-1.0, 1.0) * float(voice["transient"]) * transient_envelope
			mixed += (wave * envelope + transient) * float(voice["strength"]) * 0.48
			voice["phase"] = fmod(phase + TAU * frequency / SAMPLE_RATE, TAU)
			voice["age"] = age + 1.0 / SAMPLE_RATE
			_voices[index] = voice
		mixed = tanh(mixed)
		_playback.push_frame(Vector2(mixed, mixed))

func _wave_value(kind: String, phase: float) -> float:
	match kind:
		"square":
			return 1.0 if sin(phase) >= 0.0 else -1.0
		"triangle":
			return asin(sin(phase)) * 2.0 / PI
		"saw":
			return 2.0 * (phase / TAU) - 1.0
		_:
			return sin(phase)
